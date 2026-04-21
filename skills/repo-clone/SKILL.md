---
name: repo-clone
description: "Clone a single monorepo and set up the workspace folder."
---

## Important rules

Read and follow the rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

Read and follow the context resolution contract in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_context-resolution.md`.

## Arguments

- `$ARGUMENTS` is **mandatory**. Format: `<repo-name> <context> [target-folder]`
  - `<repo-name>` — exact repository name (e.g., `wealth-pilot`)
  - `<context>` — context name matching a manifest entry (e.g. `rise-qa`, `perso`), or a literal `<owner>/<repo-name>` form to bypass resolution entirely.
  - `[target-folder]` — optional destination folder. Defaults to `./<repo-name>` (standard `git clone` behaviour).

If `$ARGUMENTS` is empty or missing required parts, respond with:

> Please provide at least 2 arguments: `/repo-clone <repo-name> <context> [target-folder]`
>
> - **repo-name**: exact repo name (e.g., `wealth-pilot`)
> - **context**: context name from your manifest (e.g. `rise-qa`, `perso`) or literal `<owner>/<repo>` form
> - **target-folder** _(optional)_: destination folder (defaults to `./<repo-name>`)

And **stop**.

## Context Resolution

Apply the resolution contract (R.1–R.5) to derive the active context object from the `<context>` argument:

- **Literal `<owner>/<repo>` form**: short-circuits resolution — owner and repo are taken as provided. Skip to clone.
- **Context name**: look up in manifest. If found, use that context's `ssh_alias`, `github_org`/`github_user`, or `ado_org_url`. If not found as a context name, treat it as a literal owner.
- **No argument / no manifest match**: fall back to R.4 inline ask.

From the resolved context, derive:

| Context field | Clone behaviour |
|---------------|-----------------|
| `ssh_alias` + `github_org` | SSH clone: `git@<ssh_alias>:<github_org>/<repo-name>.git` |
| `ssh_alias` + `github_user` | SSH clone: `git@<ssh_alias>:<github_user>/<repo-name>.git` |
| `ado_org_url` (no github fields) | ADO discovery then HTTPS clone (see ADO section below) |

Fallback when manifest is absent or context cannot be resolved: ask the user inline for the clone strategy.

## GitHub Clone (SSH)

**Clone URL**: `git@<ssh_alias>:<github_org_or_user>/<repo-name>.git`

Verify the repo exists before cloning:

```bash
git ls-remote <clone-url> HEAD &>/dev/null && echo "EXISTS" || echo "NOT_FOUND"
```

## Azure DevOps Clone (HTTPS)

**Discovery**: Use `az repos list --org <ado_org_url> --query "[?name=='<repo-name>'].{name:name, project:project.name, remoteUrl:remoteUrl}" -o json`

- If the above requires a `--project`, first list all projects: `az devops project list --org <ado_org_url> -o json` then search each project for the matching repo.

**Clone URL**: use the `remoteUrl` returned by the API directly.

## Process

### 1. Verify the repo exists

Run the appropriate existence check above (GitHub or ADO).

#### Show result and confirm

> Found repository `<repo-name>` in context `<context-name>`:
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

If `target-folder` was **not** provided (default behaviour):

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

- If the repo is not found, tell the user and suggest checking the repo name, context, or SSH config (the `ssh_alias` declared in the manifest).
- If clone fails with `Permission denied (publickey)`, suggest checking SSH keys and `~/.ssh/config` for the correct host alias.
- If `az` CLI is not logged in, prompt the user to run `az login`.
- If the manifest is missing or the context cannot be resolved, offer to run `/platform:contexts init`.
