---
name: plugin-commit
description: "Scan every Claude plugin repo in a VS Code workspace, bump each one that has changes, and commit + push — one batch confirmation, one commit per repo."
---

Walk each folder in a VS Code `.code-workspace` file, find the plugin repos that have uncommitted changes, auto-detect the right semver bump for each, confirm once, then commit + push every repo independently.

## Important rules

Read and follow the rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

Read and follow the context resolution contract in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_context-resolution.md`.

## Arguments

- `$ARGUMENTS` (optional): path to a `.code-workspace` file.
- Default if empty: ask the user via `AskUserQuestion` to enter the workspace file path. Do **not** use any hardcoded default path.

## Steps

### 1. Discover plugin repos

Read the workspace file. It is JSONC (trailing commas allowed) — parse tolerantly or extract `"path"` entries via regex. Resolve every `path` relative to the workspace file's directory to an absolute path.

For each resolved folder, keep it only if **both**:
- `.git/` exists (it's a git repo), and
- `.claude-plugin/plugin.json` exists (it's a Claude plugin).

### 2. Inspect each plugin repo

For each kept folder, run in parallel across folders (one set of commands per folder):

```bash
git -C "<folder>" status --short
git -C "<folder>" diff HEAD --stat
git -C "<folder>" remote get-url origin
```

Read `<folder>/.claude-plugin/plugin.json` to get the current `version`.

**Skip repos where `git status --short` is empty** — nothing to commit there.

**Context resolution per repo (R.2–R.3)**

For each dirty repo, apply the context resolution contract using the repo folder as the effective cwd:

1. Look up the folder path against `path_globs` in the manifest (R.2).
2. If a context is resolved and it declares `ssh_alias`, verify that the push remote URL uses that alias (i.e. the origin URL contains `git@<ssh_alias>:`).
   - **Match**: proceed silently.
   - **Mismatch**: record a mismatch for this repo — it will be surfaced in the batch confirmation (Step 4) as a warning. Do not auto-rewrite the remote.
3. If no context matches (no manifest or no path_glob match), proceed without a context check for that repo.

### 3. Auto-detect bump + commit message per dirty repo

For each dirty plugin repo, from the file list in `git status --short`:

**Bump type:**
| Bump | Trigger |
|---|---|
| **major** | Any deleted `SKILL.md`, deleted agent file, or renamed skill/agent directory. |
| **minor** | Any new `SKILL.md`, new agent file, or new rule file (and no deletions/renames). |
| **patch** | Only modifications to existing files. |

**Commit message** (one short line):
- Exactly one new skill → `Add <name> skill`
- Exactly one removed skill → `Remove <name> skill`
- Exactly one edited skill dir → `Update <name> skill`
- Multiple skills touched → `Update skills` / `Add skills: <a>, <b>` / mixed → concise umbrella
- Non-skill changes only (rules, agents, manifests, docs) → describe in the same spirit (`Update rules`, `Add <name> agent`, etc.)

Prefer concrete names over generic verbs. Keep under ~60 chars.

**New version:**
- major → `X.0.0` (X+1)
- minor → `X.Y+1.0`
- patch → `X.Y.Z+1`

### 4. Batch confirm (single prompt)

If no dirty plugin repos: print `No plugin repos have changes. Nothing to do.` and stop.

Otherwise use `AskUserQuestion`. Put the full plan in the **question text** as a table. Group repos by resolved context. Surface any remote URL mismatches as warnings in the question text. For example:

```
Found N plugin repo(s) with changes:

Context: rise-qa (ssh_alias: github-rise)
  repo                          bump     old → new     message
  ----------------------------- -------- ------------- ---------------------------
  it--claude-rise-plugin        patch    1.1.0 → 1.1.1 Update migrate-workflows skill

Context: perso (ssh_alias: github-perso)
  repo                          bump     old → new     message
  ----------------------------- -------- ------------- ---------------------------
  claude-platform-plugin        minor    1.2.0 → 1.3.0 Add plugin-commit skill

⚠ Remote URL mismatch (N repo(s)):
  <repo>: origin uses <actual-alias> but manifest declares <expected-alias>
  These repos will be pushed as-is — fix remotes manually if needed.

Commit and push each independently on `main`?
```

Options:
- "Commit and push all (Recommended)" — proceed
- "Cancel" — abort, make no changes

(Users can always pick "Other" to override — e.g. to skip a repo or edit a message. If they do, apply their override before proceeding.)

### 5. Apply per repo

For each confirmed repo, sequentially:

1. Edit `.claude-plugin/plugin.json` → set `version` to new version.
2. Edit `.claude-plugin/marketplace.json` → set the matching plugin's `version` to new version.
3. Commit:
   ```bash
   git -C "<folder>" add -A
   git -C "<folder>" commit -m "<message>

   chore: bump version to <new-version>"
   ```
4. Push:
   ```bash
   git -C "<folder>" push origin main
   ```

If any step fails in a repo, report the failure and continue with the remaining repos — don't abort the whole batch.

### 6. Summary

Print one table:

```
Released:
  repo                          version    bump     status
  ----------------------------- ---------- -------- -----------
  claude-platform-plugin        1.3.0      minor    pushed
  it--claude-rise-plugin        1.1.1      patch    pushed
  ...
```

Use `failed: <reason>` in the status column for any repo that didn't complete.
