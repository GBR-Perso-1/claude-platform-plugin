---
name: eng-plugin-commit
description: "Bump the plugin version, commit all changes, and push to main. Use after editing skills, agents, or rules to publish a new version."
---

Bump the plugin version, commit all staged and unstaged changes, and push to main.

## Steps

### 1. Read current version

Read `.claude-plugin/plugin.json` and extract the current `version` field.

### 2. Compute next version

Increment the **patch** number (e.g. `1.1.0` → `1.1.1`, `1.0.0` → `1.0.1`).

### 3. Update version in both manifest files

- `.claude-plugin/plugin.json` — update `version`
- `.claude-plugin/marketplace.json` — update `version` inside the plugins array

### 4. Stage all changes

```bash
git add -A
```

### 5. Commit

```bash
git commit -m "chore: bump version to <new-version>"
```

### 6. Confirm and push

Show the user:

- New version
- List of files committed (`git diff HEAD~1 --name-only`)
- Target branch (`main`)

Use `AskUserQuestion` with options:

- "Push to main (Recommended)"
- "Don't push — I'll push manually"

On confirmation:

```bash
git push origin main
```

### 7. Summary

```
Released: <new-version>
Pushed to: main

Run in consumer projects to get the update:
  claude plugin update platform
```
