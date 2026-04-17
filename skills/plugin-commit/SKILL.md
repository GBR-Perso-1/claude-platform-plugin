---
name: plugin-commit
description: "Scan every Claude plugin repo in a VS Code workspace, bump each one that has changes, and commit + push — one batch confirmation, one commit per repo."
---

Walk each folder in a VS Code `.code-workspace` file, find the plugin repos that have uncommitted changes, auto-detect the right semver bump for each, confirm once, then commit + push every repo independently.

## Important rules

Read and follow the rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Arguments

- `$ARGUMENTS` (optional): path to a `.code-workspace` file.
- Default if empty: `C:\Workspace\Dev\Code.Workspace\claude-plugin.code-workspace`.

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
```

Read `<folder>/.claude-plugin/plugin.json` to get the current `version`.

**Skip repos where `git status --short` is empty** — nothing to commit there.

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

Otherwise use `AskUserQuestion`. Put the full plan in the **question text** as a table, e.g.:

```
Found N plugin repo(s) with changes:

  repo                          bump     old → new     message
  ----------------------------- -------- ------------- ---------------------------
  claude-platform-plugin        minor    1.2.0 → 1.3.0 Add plugin-commit skill
  it--claude-rise-plugin        patch    1.1.0 → 1.1.1 Update migrate-workflows skill
  ...

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
