#!/bin/bash
# block-secret-access.sh — PreToolUse hook.
# Blocks Claude from reading secrets files and running secret-decryption /
# secret-store commands. Fires on Read, Edit, Write, NotebookEdit and Bash.
#
# Layered defence:
#   1. Read/Edit/Write/NotebookEdit -> check tool_input.file_path against
#      SECRET_PATH_PATTERNS, allowing matches in SECRET_EXEMPT_PATTERNS.
#   2. Bash -> check command against:
#      a. DECRYPT_PATTERNS — sops, gpg, age, vault, 1Password, Bitwarden,
#         pass, cloud KMS/secret-manager CLIs, kubectl secret/logs.
#      b. READ_CMD_PATTERN paired with any SECRET_PATH_PATTERN — catches
#         `cat .env`, `grep TOKEN secrets.yml`, `cp ~/.aws/credentials /tmp/x`
#         and similar shell-based bypasses of the file-access block.
#
# Exit 2 + stderr message signals a hard block back to Claude Code.

INPUT=$(cat)

block() {
    echo "BLOCKED (secret-guardrails): $1" >&2
    echo "Claude is not authorised to access secrets. If this is a legitimate need, ask the user to perform the action manually and share only what's required." >&2
    exit 2
}

# Fail closed if we can't parse the hook input — a malformed (or absent)
# JSON should never reach a security hook in normal operation; blocking on
# it is safer than silently allowing.
if [ -z "$INPUT" ]; then
    block "empty hook input — refusing to evaluate"
fi
if ! printf '%s' "$INPUT" | jq empty >/dev/null 2>&1; then
    block "malformed hook input — refusing to evaluate"
fi

TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

# ── Sensitive path patterns (extended-regex; matched against full path) ─────
SECRET_PATH_PATTERNS=(
    '(^|/)\.env(\.[a-zA-Z0-9_.-]+)?$'           # .env, .env.local, .env.production
    '(^|/).*[._-]?secrets?\.(ya?ml|json|toml|env)$'  # secrets.yml, app-secrets.json, foo_secret.yaml
    '(^|/)credentials(\.(ya?ml|json|toml))?$'   # credentials, credentials.json
    '(^|/)\.netrc$'
    '(^|/)\.npmrc$'
    '(^|/)\.pypirc$'
    '(^|/)\.pgpass$'
    '(^|/)\.envrc$'
    '(^|/)\.git-credentials$'
    '(^|/)kubeconfig$'
    '(^|/)\.kube/config$'
    '(^|/)\.aws/(credentials|config)$'
    '(^|/)\.docker/config\.json$'
    '(^|/)\.config/gcloud/'
    '(^|/)\.config/op/'
    '(^|/)\.ssh/'                                # everything in .ssh (see exemptions)
    '(^|/)\.gnupg/'
    '(^|/)config/master\.key$'
    '(^|/)config/credentials\.ya?ml\.enc$'
    '(^|/)master\.key$'
    '(^|/)wp-config\.php$'
    '\.(pem|key|pfx|p12|jks|keystore)$'         # certs & keystores
    '(^|/)id_(rsa|ed25519|ecdsa|dsa)$'          # SSH private keys at any depth
    '\.tfstate(\.backup)?$'
    '(^|/)(terraform|secrets|prod|production|staging)\.tfvars$'
    '\.auto\.tfvars$'
)

# ── Exemptions — these override SECRET_PATH_PATTERNS ────────────────────────
SECRET_EXEMPT_PATTERNS=(
    '\.env\.(example|sample|template|dist|test)$'
    '\.tfvars\.(example|sample|template)$'
    '(^|/)example\.tfvars$'
    '\.pub$'                                    # public keys
    '(^|/)known_hosts$'                         # not secret, just fingerprints
    '(^|/)authorized_keys$'                     # lists *public* keys
    '(^|/)\.ssh/config$'                        # ssh client config (non-secret)
)

is_secret_path() {
    local path="$1"
    [ -z "$path" ] && return 1
    for ex in "${SECRET_EXEMPT_PATTERNS[@]}"; do
        echo "$path" | grep -qE "$ex" && return 1
    done
    for p in "${SECRET_PATH_PATTERNS[@]}"; do
        echo "$path" | grep -qE "$p" && return 0
    done
    return 1
}

# ── Bash: decrypt / secret-store CLI patterns ───────────────────────────────
DECRYPT_PATTERNS=(
    'sops\s+(-d\b|--decrypt\b|decrypt\b|d\b|exec-env\b|exec-file\b)'
    'gpg\s+[^|]*(-d\b|--decrypt\b)'
    'age\s+[^|]*(-d\b|--decrypt\b)'
    '(^|[;&|]|\s)pass\s+(show|otp|edit|cp)\b'
    '(^|[;&|]|\s)op\s+(item|read|get|signin|inject|run)\b'
    '(^|[;&|]|\s)bw\s+(get|unlock|export)\b'
    'vault\s+(read|kv\s+get|login|operator\s+unseal)\b'
    'aws\s+secretsmanager\s+get-secret-value\b'
    'aws\s+ssm\s+get-parameter\s+[^|]*--with-decryption\b'
    'aws\s+kms\s+decrypt\b'
    'gcloud\s+secrets\s+versions\s+access\b'
    'gcloud\s+kms\s+decrypt\b'
    'az\s+keyvault\s+secret\s+show\b'
    'doppler\s+(secrets?\s+(get|download)|run)\b'
    'chamber\s+(exec|read|env)\b'
    'infisical\s+(secrets|run|export)\b'
    'kubectl\s+(get|describe)\s+secret(s)?\b'
    'kubectl\s+logs\b'                          # per user's CLAUDE.md
    'helm\s+get\s+values\b'                     # often dumps rendered secrets
)

# ── Bash: shell-read tools (cat, grep, editors, etc.) ───────────────────────
# A bare-word boundary regex; we look for these followed by any token,
# then separately check whether the command also touches a secret path.
READ_CMD_PATTERN='(^|[;&|`$(]|\s)(cat|less|more|head|tail|bat|view|nano|vim|vi|emacs|sed|awk|xxd|od|hexdump|strings|grep|rg|fgrep|egrep|dd|base64|openssl|cp|mv|tar|zip)(\s|$)'

case "$TOOL" in
    Read|Edit|Write|NotebookEdit)
        path=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')
        if is_secret_path "$path"; then
            block "tool '$TOOL' on '$path' — matches secret-path policy"
        fi
        ;;
    Bash)
        cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
        [ -z "$cmd" ] && exit 0

        # 1. Decrypt / secret-store commands
        for p in "${DECRYPT_PATTERNS[@]}"; do
            if echo "$cmd" | grep -qE "$p"; then
                block "command matches secret-access tool pattern '$p'"
            fi
        done

        # 2. Shell reads of secret files: tokenise the command and check each
        # token against is_secret_path (which already applies exemptions).
        if echo "$cmd" | grep -qE "$READ_CMD_PATTERN"; then
            while IFS= read -r token; do
                # Strip wrapping single/double quotes
                token="${token#\"}"; token="${token%\"}"
                token="${token#\'}"; token="${token%\'}"
                [ -z "$token" ] && continue
                if is_secret_path "$token"; then
                    block "shell-read references secret path '$token' in: $cmd"
                fi
            done < <(printf '%s\n' "$cmd" | tr -s '[:space:];&|()<>' '\n')
        fi
        ;;
esac

exit 0
