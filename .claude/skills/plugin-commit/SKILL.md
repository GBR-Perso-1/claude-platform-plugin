---
name: plugin-commit
description: "Intelligently bump the plugin version based on changes, commit with a meaningful message, and push to main."
---

Analyse the changes in this plugin repo, determine the correct semantic version bump, commit, and push to main.

## Steps

### 1. Gather context

Run these in parallel:

```bash
git diff HEAD --stat
git status --short
git log --oneline -5
```

Read `.claude-plugin/plugin.json` to get the current version.

### 2. Ask for the commit message

Use `AskUserQuestion` to ask:

> "What changed? (used as the commit message)"

Free-text input. This is the human summary of the work done.

### 3. Determine the version bump

Analyse the diff stat + commit message together. Apply this logic:

| Bump | When |
|---|---|
| **major** | A skill or agent was **renamed or removed** (breaking change for consumers). Triggered by: deleted `SKILL.md`, renamed directory, removed agent file. |
| **minor** | A **new skill, agent, or rule** was added. Triggered by: new `SKILL.md`, new agent file, new rule file. |
| **patch** | **Fixes or improvements** to existing skills/agents/rules. Triggered by: edits to existing files only, no additions or deletions of skill entry points. |

If the commit message contains words like `breaking`, `remove`, `rename` → lean major.
If it contains `add`, `new`, `introduce` → lean minor.
If it contains `fix`, `update`, `improve`, `tweak`, `refactor`, `docs` → lean patch.

Compute the new version from the current one (e.g. `1.2.0`):
- major → `2.0.0`
- minor → `1.3.0`
- patch → `1.2.1`

### 4. Confirm with the user

Use `AskUserQuestion` to present:

> "Proposed bump: **{bump_type}** → `{old_version}` → `{new_version}`
> Reason: {one sentence explaining why this bump type was chosen}"

Options:
- "Looks right — commit and push (Recommended)"
- "Patch instead"
- "Minor instead"
- "Major instead"

If the user picks an override, recompute the new version accordingly.

### 5. Update version in both manifest files

Edit in place:
- `.claude-plugin/plugin.json` — `version` field
- `.claude-plugin/marketplace.json` — `version` inside the plugins array

### 6. Commit

```bash
git add -A
git commit -m "<user commit message>

chore: bump version to <new-version>"
```

### 7. Push

```bash
git push origin main
```

### 8. Summary

Output:

```
Released: <new-version>  (<bump-type> bump)
Commit:   <commit message>
Pushed to: main

To update in consumer projects:
  claude plugin update <plugin-name>
```
