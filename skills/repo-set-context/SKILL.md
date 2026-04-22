---
name: contexts
description: "Manage the user-level contexts.json manifest — create, validate, sync, and add context entries that describe your GitHub/Azure accounts."
---

Manage the user-level `contexts.json` manifest at `%USERPROFILE%\.claude\contexts.json` (Windows) / `$HOME/.claude/contexts.json` (Unix). The manifest declares every GitHub/Azure context you operate in; skills across the plugin ecosystem read it to resolve accounts, SSH aliases, Azure tenant IDs, and dev-settings sources without prompting.

## Important rules

Read and follow the rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

Read and follow the schema in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_contexts-schema.md`.

## Arguments

`$ARGUMENTS` — first token is the subcommand. Valid subcommands:

| Subcommand | Usage |
|------------|-------|
| `init` | Walk through creating or augmenting the manifest interactively |
| `check` | Validate the manifest against observable reality (read-only) |
| `sync` | Apply mutable reconciliation with explicit per-change confirmation |
| `add <name>` | Append a single new context entry interactively |

If `$ARGUMENTS` is empty or the subcommand is not one of the above, print:

```
Usage: /platform:contexts <subcommand>

  init          Create or augment the manifest interactively
  check         Validate manifest against observable reality (read-only)
  sync          Reconcile gh auth, SSH aliases, and remote URLs (with confirmation)
  add <name>    Append a new named context entry
```

And **stop**.

---

## Subcommand: `init`

Walk the user through defining or augmenting the `contexts.json` manifest. Existing entries are always preserved.

### Step 1 — Load existing manifest

Read the manifest if it exists. Parse the `contexts` array. If the file is absent or contains no entries, start with an empty array.

### Step 2 — Entry loop

Repeat until the user is done. For each iteration, present via `AskUserQuestion`:

```
Contexts manifest — entry #{n}

Current entries: <list names or "none">

Select an action:
```

Options:
1. Add a new context entry
2. Edit an existing entry (only if entries exist)
3. Done — save and exit
4. Cancel — discard all changes

If **Done** and no new entries were collected and the manifest already existed: confirm there is nothing new to save and exit.

If **Cancel**: discard all unsaved changes and stop.

### Step 3 — Collect context fields

For each new context, collect fields via `AskUserQuestion` one at a time. Every field except `name` and `path_globs` offers a "Skip" option.

| Field | Prompt |
|-------|--------|
| `name` | Short context identifier (required — no skip) |
| `path_globs` | One or more glob patterns for matching cwd (required — no skip; accept comma-separated list) |
| `github_org` | GitHub organisation slug (e.g. `Rise-4`) — skip if personal or ADO |
| `github_user` | GitHub personal account slug — skip if org or ADO |
| `ssh_alias` | SSH host alias from `~/.ssh/config` (e.g. `github-rise`) |
| `commit_email` | Git commit email for this context |
| `azure_tenant_id` | Azure / Entra tenant GUID |
| `azure_subscriptions` | Environment → subscription GUID pairs (accept as `qa=<guid>,prod=<guid>`) |
| `azure_env_file_prefix` | Prefix for local Azure env files (e.g. `rise-env`) |
| `dev_settings_repo` | Dev-settings repository name (e.g. `it--dev-settings`) |
| `dev_settings_owner` | Owner of the dev-settings repo |
| `dev_settings_admin` | Name of the platform admin |
| `ado_org_url` | Azure DevOps organisation URL |
| `app_template_path` | Absolute path to the local app template clone |

Validate:
- `name` must be non-empty and not already in the manifest (case-insensitive).
- `path_globs` must contain at least one non-empty pattern.
- `github_org` and `github_user` must not both be set — if the user provides both, explain the constraint and re-prompt.

### Step 4 — Save

Write the updated manifest to `%USERPROFILE%\.claude\contexts.json` (Windows) / `$HOME/.claude/contexts.json` (Unix). Show the user the final JSON before writing and ask for confirmation.

Print a summary of entries added or updated.

---

## Subcommand: `check`

Validate the manifest against observable reality. Makes **no changes**.

### Step 1 — Read manifest

If the manifest does not exist: report `No manifest found at <path>. Run /platform:contexts init to create one.` and stop.

Parse and validate structure. Report any schema errors (missing required fields, both `github_org` and `github_user` set, etc.).

### Step 2 — Per-context checks

For each context entry:

**Path glob existence**

For each pattern in `path_globs`, test whether the glob matches any existing directory on disk. Report patterns that match nothing as warnings (they may be intentional for future directories).

**SSH alias**

If `ssh_alias` is declared, check `~/.ssh/config` for a `Host <ssh_alias>` block:

```bash
grep -i "^Host <ssh_alias>" ~/.ssh/config
```

Report: found / not found.

**GitHub authentication**

If `github_org` or `github_user` is declared, run:

```bash
gh auth status
```

Report the authenticated users. Flag if the declared owner does not appear to be authenticated.

**Git commit identity**

If `commit_email` is declared, run:

```bash
git config --global user.email
```

Report whether a matching `includeIf` block exists in the global gitconfig. (A mismatch is a warning, not an error — context-switching may be handled by `includeIf`.)

### Step 3 — Report

Print a structured report grouped by context:

```
Contexts manifest check
───────────────────────

rise-qa
  path_globs:     C:/Workspace/Dev/Rise.Applications/**  [matches 12 dirs]
  ssh_alias:      github-rise  [found in ~/.ssh/config]
  gh auth:        Rise-4  [authenticated]
  commit_email:   gbrourhant@rise.fo  [includeIf present]

perso
  path_globs:     C:/Workspace/Dev/Perso.Applications/**  [matches 5 dirs]
  ssh_alias:      github-perso  [found in ~/.ssh/config]
  gh auth:        GBR-Perso-1  [authenticated]
  commit_email:   me@personal.example  [no includeIf — WARNING]
```

No changes are made.

---

## Subcommand: `sync`

Apply mutable reconciliation. Every proposed change is confirmed via `AskUserQuestion` before execution.

### Step 1 — Read manifest

Same as `check` Step 1.

### Step 2 — Assess gaps

For each context entry:

- **Missing `gh` authentication**: if `github_org` or `github_user` is declared and the corresponding account is not in `gh auth status` output → offer `gh auth login`.
- **Remote URL mismatch**: for any git repository under a matched `path_glob`, if the `ssh_alias` is declared but the origin URL does not use that alias → offer to rewrite the remote URL.

### Step 3 — Per-change confirmation

For each proposed change, present via `AskUserQuestion`:

```
Proposed change:
  <description of change>

Apply?
```

Options:
1. Apply this change
2. Skip this change
3. Cancel all remaining changes

Execute only confirmed changes.

### Step 4 — Summary

Print a table of changes applied vs skipped.

---

## Subcommand: `add <name>`

Append a single named context entry interactively.

Extract `<name>` from `$ARGUMENTS` (the token after `add`). If missing: print `Usage: /platform:contexts add <name>` and stop.

Load the existing manifest. If a context with the same name already exists: report it and ask whether to overwrite or abort.

Run **Step 3** from the `init` subcommand for the new entry, then **Step 4** (save with confirmation).
