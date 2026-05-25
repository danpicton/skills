---
name: gripes-to-issues
description: Turn raw complaints, frustrations, or rough notes about a codebase or project into well-formed issues on GitHub, GitLab, or any other issue tracker. Use this skill whenever the user mentions problems, bugs, annoyances, things that are broken, things that need fixing, TODOs, or anything that sounds like it should be tracked — even if they don't say "create an issue". Examples: "this is annoying and needs fixing", "we should really sort out X", "a few things I've noticed", "can you file these as tickets", "turn these gripes into issues".
---

# Gripes to Issues

Turn raw complaints and rough notes into well-formed, actionable issues on the right tracker.

## Overview of the flow

1. **Collect** — gather the gripes from the conversation
2. **Discover** — find the issue tracker and check for any issue standards
3. **Draft** — transform gripes into well-formed issues
4. **Review** — confirm with the user before creating anything
5. **Create** — post to the tracker (or output as markdown if no integration is available)

Work through these stages in order. Don't ask questions you can answer yourself by looking at the repo.

---

## Stage 1: Collect gripes

Gripes are already in the conversation — extract them. They might be:
- Explicit complaints ("the login page is really slow")
- Vague frustrations ("X is just broken")
- Rough notes or a bullet list the user has pasted in
- Implicit issues noticed during a discussion

If the conversation contains multiple gripes, handle them all in one go. If nothing has been stated yet, ask the user to describe what's bothering them.

---

## Stage 2: Discover the tracker

### Find the tracker

In order of preference:

1. **Check the git remote** — run `git remote get-url origin` and infer the platform (GitHub, GitLab, etc.). For GitHub: `gh repo view --json url,name,owner` confirms access. For GitLab: `glab repo view`.
2. **Check for config files** — `.github/`, `.gitlab/`, `linear.json`, etc.
3. **Ask the user** — if none of the above works, ask where issues should go. If the project has no version control or no linked tracker, ask what platform they'd like to use (GitHub repo URL, Linear, Jira, or just markdown output).

### Check for issue standards

In this order — stop as soon as you find something useful:

1. **Issue templates** — look for `.github/ISSUE_TEMPLATE/` or `.gitlab/issue_templates/`. If templates exist, use them as the structure for drafting.
2. **Contributing guide** — check `CONTRIBUTING.md` or `.github/CONTRIBUTING.md` for issue creation guidance.
3. **Existing issues** — if the user asks, or if no templates/guidelines are found, fetch a few recent issues (`gh issue list --limit 5 --json title,body,labels`) to infer the project's conventions for titles, labels, and body format.
4. **Sensible defaults** — if nothing is found, use the default format defined below.

Tell the user briefly what you found: "Found issue templates — I'll use the bug report template for X and the feature request template for Y." or "No templates found — I'll use standard format."

---

## Stage 3: Draft issues

Transform each gripe into a well-formed issue. For each one:

### Classify the type

Pick the best fit:
- **bug** — something is broken or behaving incorrectly
- **feature** — new capability that doesn't exist yet
- **improvement** — something that works but could be better (performance, UX, code quality)
- **docs** — documentation is missing, wrong, or unclear
- **chore** — maintenance, dependencies, cleanup

### Default issue format

Use this when no template is found. Adapt it if templates or existing patterns suggest something different.

```
## Summary
[One or two sentences describing the problem or request. Be concrete — what is wrong or missing?]

## Detail
[Expand on the summary. For bugs: what happens vs what should happen. For features/improvements: why this matters and what success looks like. Keep it brief — enough for someone to understand and act on.]

## Acceptance criteria
- [ ] [Specific, testable condition that means this is done]
- [ ] [Another condition if needed]
```

For **bugs**, add:
```
## Steps to reproduce
1. [Step]
2. [Step]
```

### Title format

Aim for: `[type]: short imperative description`
Examples:
- `bug: login form clears on validation error`
- `improvement: reduce API response time on /search endpoint`
- `docs: add setup instructions for local dev`

Omit the `[type]:` prefix if existing issues don't use it.

### Labels

Suggest labels matching the issue type. If the repo has existing labels, use those (`gh label list`). Common defaults: `bug`, `enhancement`, `documentation`, `chore`.

### Grouping

If multiple gripes are clearly related (e.g., several UI complaints about the same form), ask the user whether to group them into one issue or keep them separate.

---

## Stage 4: Review with the user

Present all drafted issues as a numbered list. For each:
- Show the title, type, and a short summary
- Note any labels you'd apply

Example:
```
1. bug: login form clears on validation error
   Labels: bug
   Summary: Entering an invalid password wipes all fields, not just the password field.

2. improvement: search results load slowly on mobile
   Labels: enhancement
   Summary: /search takes 3–5s on mobile. Should aim for <1s.
```

Then ask:
- "Does this look right? Anything to add, merge, or drop?"
- "Should I search for duplicates before creating?" (offer this — don't do it without asking)

Wait for approval before proceeding.

### Optional: deduplication

If the user says yes to checking duplicates, search existing open issues:
```bash
gh issue list --state open --limit 50 --json number,title,body
```
Flag any that look like near-duplicates and let the user decide whether to proceed with a new issue or add context to the existing one.

---

## Stage 5: Create issues

### With `gh` (GitHub)

Create in sequence so you can reference issue numbers in related issues if needed:

```bash
gh issue create \
  --title "bug: login form clears on validation error" \
  --body "..." \
  --label "bug"
```

After each creation, report the issue number and URL.

### With `glab` (GitLab)

```bash
glab issue create --title "..." --description "..." --label "bug"
```

### No CLI available / markdown fallback

If neither `gh` nor `glab` is available, or the user prefers, output each issue as a markdown block they can paste:

```markdown
---
**Title:** bug: login form clears on validation error
**Labels:** bug

## Summary
...
```

---

## Things to watch for

- **Vague gripes need sharpening** — if a gripe is too vague to turn into an actionable issue ("everything about the auth flow is wrong"), ask clarifying questions until you have enough to write something specific and actionable. Don't stop at one question if the answer is still vague. Only move on to drafting once you could explain the problem clearly to someone who wasn't in this conversation.
- **Don't over-formalise** — the goal is useful, actionable issues, not perfect bureaucratic tickets. Err on the side of clear and concise over long and thorough.
- **One gripe ≠ always one issue** — a single gripe might surface two distinct problems. Use judgement and flag it if so.
- **Preserve the user's voice** — if the user described something vividly, keep that energy in the issue. Issues don't have to be dry.
