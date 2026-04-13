---
name: repo-clone
description: "Clone a single monorepo and set up the workspace folder."
---

## Important rules

Read and follow the rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Arguments

- `$ARGUMENTS` is **mandatory**. Format: `<repo-name> <scope> [target-folder]`
  - `<repo-name>` — exact repository name (e.g., `wealth-pilot`)
  - `<scope>` — one of: `rise`, `perso`, `mantu`
  - `[target-folder]` — optional destination folder. Defaults to `./<repo-name>` (standard `git clone` behavior).

If `$ARGUMENTS` is empty or missing required parts, respond with:

> Please provide at least 2 arguments: `/repo-clone <repo-name> <scope> [target-folder]`
>
> - **repo-name**: exact repo name (e.g., `wealth-pilot`)
> - **scope**: `rise`, `perso`, or `mantu`
> - **target-folder** _(optional)_: destination folder (defaults to `./<repo-name>`)

And **stop**.

## Scope Configuration

### `rise` — GitHub org (SSH)

- **Clone URL**: `git@github-rise:Rise-4/<repo-name>.git`

### `perso` — GitHub user (SSH)

- **Clone URL**: `git@github-perso:GBR-Perso-1/<repo-name>.git`

### `mantu` — Azure DevOps (HTTPS)

- **Discovery**: Use `az repos list --org https://dev.azure.com/Mantu --query "[?name=='<repo-name>'].{name:name, project:project.name, remoteUrl:remoteUrl}" -o json`
  - If the above requires a `--project`, first list all projects: `az devops project list --org https://dev.azure.com/Mantu -o json` then search each project for the matching repo.
- **Clone URL**: use the `remoteUrl` returned by the API directly.

## Process

### 1. Verify the repo exists

#### For `rise` and `perso` scopes

```bash
git ls-remote <clone-url> HEAD &>/dev/null && echo "EXISTS" || echo "NOT_FOUND"
```

#### For `mantu` scope

Run the `az repos list` query above.

#### Show result and confirm

> Found repository `<repo-name>` in `<scope>`:
>
> | Repository   | Clone destination |
> | ------------ | ----------------- |
> | wealth-pilot | ./wealth-pilot/   |
>
> Proceed with clone?

**Wait for user confirmation.**

### 2. Clone the repo

If `target-folder` was provided:

```bash
mkdir -p "$(dirname "<target-folder>")"
git clone <clone-url> "<target-folder>"
```

If `target-folder` was **not** provided (default behavior):

```bash
git clone <clone-url>
```

### 3. Output summary

```
| Repository     | Status | Path                  |
|----------------|--------|-----------------------|
| wealth-pilot   | cloned | ./wealth-pilot/       |
```

## Error handling

- If the repo is not found, tell the user and suggest checking the repo name, scope, or SSH config (`github-rise` / `github-perso` hosts).
- If clone fails with `Permission denied (publickey)`, suggest checking SSH keys and `~/.ssh/config` for the correct host alias.
- If `az` CLI is not logged in, prompt the user to run `az login`.
