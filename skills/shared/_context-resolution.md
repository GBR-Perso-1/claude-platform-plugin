## Context Resolution Contract

> **Maintenance note**: This file is the **source of truth** for the context resolution contract. Verbatim copies exist in `dev-workflow` and `rise-dev-plugin`; keep all three in sync when this file changes.

Every skill that needs to identify the active GitHub/Azure context must follow this contract in order, without deviation.

---

### R.1 — Explicit Argument (short-circuit)

If the skill received an explicit context argument (e.g. a context name like `rise-qa`, or a literal `<owner>/<repo>` form):

- Use it directly. Do **not** consult the manifest or ask the user.
- A literal `<owner>/<repo>` bypasses context resolution entirely — the owner and repo are known.
- A context name is looked up in the manifest (see R.2 lookup). If not found as a context name, treat it as a literal owner value and proceed.

---

### R.2 — Manifest Lookup

Read the manifest from:

- **Windows**: `%USERPROFILE%\.claude\contexts.json`
- **Unix / macOS**: `$HOME/.claude/contexts.json`

If the manifest is missing or unreadable, skip to R.4.

Parse the `contexts` array. Evaluate entries **in order**. For each entry, test whether the current working directory matches any pattern in `path_globs` (first-match wins — see glob semantics in `_contexts-schema.md`).

- **One match found**: use that context. Proceed to R.3.
- **No match found**: skip to R.4.

---

### R.3 — Signal Consistency Check

After resolving a context from the manifest (R.2), verify that observable signals agree:

1. Read the git remote origin URL of the current repository (`git remote get-url origin`).
2. Extract the owner from the URL.
3. Compare it against the resolved context's `github_org` or `github_user`.

**If they match**: proceed silently with the resolved context.

**If they do not match**: report the mismatch to the user and ask via `AskUserQuestion`:

```
Context mismatch detected:
  Manifest match: <context-name> (owner: <manifest-owner>)
  git remote origin owner: <remote-owner>

Which context should be used?
```

Options:
1. Use manifest context `<context-name>` (owner: `<manifest-owner>`)
2. Resolve by remote owner (`<remote-owner>`) — look up matching context or enter inline
3. Cancel

**Never auto-resolve a mismatch.** Always ask.

> ADO-backed contexts (those with `ado_org_url` and no `github_org`/`github_user`) skip this check — the comparison is not applicable.

---

### R.4 — Inline Ask

No manifest match was found (or the manifest is absent). Ask the user once via `AskUserQuestion`:

```
No manifest context matched the current directory.

Which context applies to this repository?
```

Options: list all `name` values from the manifest (if the manifest exists and has entries), plus a free-text "Enter manually" option.

After the user provides an answer:

1. Use the answered context for this invocation.
2. Offer to save it to the manifest (opt-in only):

```
Save this as the context for paths matching <cwd-pattern> in your manifest?
```

Options:
1. Yes — save to manifest (Recommended)
2. No — use for this run only

Saving appends a new context entry with at minimum `name` and `path_globs` (derived from the cwd). The user is shown the entry before it is written.

---

### R.5 — Cache for Invocation Lifetime

Once a context is resolved (via any of R.1–R.4), **cache it for the remainder of this skill invocation**. Do not re-resolve or re-ask within the same run.

---

### Batch Operations (REQ-3.7)

When a skill operates on multiple items (e.g. multiple repositories in a workspace):

1. Resolve context **per item** using R.1–R.4 above, treating each item's directory as the cwd for that item.
2. **Group by context** for the confirmation prompt — present all items sharing the same context together in one `AskUserQuestion`, not one prompt per item.
3. Items with mismatched or unresolvable contexts are surfaced as a separate group for the user to address.
