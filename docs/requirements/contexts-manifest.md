# Plugin Ecosystem — Contexts Manifest Evolution

## Vision

Skills across every Claude Code plugin stop hardcoding account names, org owners, template paths, and Azure IDs, and stop relying on whichever GitHub/Azure identity happens to be active. A single user-owned manifest declares the user's multi-account world once; every skill reads it through a shared resolution contract. Result: automated skill runs resolve context silently when signals agree, ask exactly once when they don't, and never embed a per-user constant in plugin source.

## Epics

### Epic 1: Contexts Manifest

**Goal**: Provide a single source of truth describing every GitHub/Azure context the user operates in, readable by any skill.

#### Requirements

- **REQ-1.1**: Manifest lives at `%USERPROFILE%\.claude\contexts.json`, user-level (not plugin-internal).
- **REQ-1.2**: Each context entry declares at minimum: a path glob for matching cwd, a short name (e.g. `rise`, `perso`), and any subset of: GitHub org, GitHub user, SSH alias, commit email, Azure tenant ID, Azure subscription IDs per environment, and a dev-settings source repo.
- **REQ-1.3**: Contexts are matched to cwd by first-match path glob.
- **REQ-1.4**: A missing or incomplete manifest is never fatal — skills fall back to the resolution contract (Epic 3).
- **REQ-1.5**: Only the user or the `/platform:contexts` skill writes to the manifest; no other skill modifies it silently.

#### Decisions & Assumptions

- The exact field set is user-extensible — contexts may declare fields not yet consumed by any skill, and skills read only the fields they care about.
- Tactical/ex-Mantu context values remain user homework; manifest supports any number of contexts.

---

### Epic 2: `/platform:contexts` Management Skill

**Goal**: Give the user a frictionless way to create, validate, and evolve the manifest, without making the skill a precondition for anything else.

#### Requirements

- **REQ-2.1**: `/platform:contexts init` creates the manifest when missing or augments it when incomplete, walking the user through each field per context.
- **REQ-2.2**: `/platform:contexts check` validates an existing manifest against observable reality: declared paths exist, SSH aliases resolve in `~/.ssh/config`, `gh` is authenticated for declared GitHub users, git commit identity through `includeIf` matches declared emails. Reports findings; makes no changes.
- **REQ-2.3**: `/platform:contexts sync` applies mutable reconciliation (e.g. ensures `gh` is logged in for each declared user, offers to rewrite stale origin URLs to match declared SSH aliases) with explicit per-change confirmation.
- **REQ-2.4**: `/platform:contexts add <name>` appends a new context interactively, preserving existing entries.
- **REQ-2.5**: The skill lives in the `platform` plugin.

#### Decisions & Assumptions

- No hard dependency on running the skill — manifest can be hand-authored.
- Subcommands may grow (e.g. `rename`, `remove`); above is the MVP.

---

### Epic 3: Context Resolution Contract

**Goal**: Every skill that needs context context resolves it identically, so behaviour is predictable and friction is deterministic.

#### Requirements

- **REQ-3.1**: Resolution order is fixed: **explicit argument → manifest lookup → inline ask**.
- **REQ-3.2**: An explicit context argument (e.g. `rise`, `Rise-4/<repo>`) short-circuits manifest and prompts.
- **REQ-3.3**: When cwd matches exactly one context in the manifest, that context is used with no prompt.
- **REQ-3.4**: When cwd matches no context — or the manifest is missing — the skill asks once via `AskUserQuestion` and offers to save the answer to the manifest.
- **REQ-3.5**: When signals disagree (e.g. cwd matches context A but the origin URL's owner matches context B), the skill reports the mismatch and asks — it never auto-rewrites.
- **REQ-3.6**: A resolved context answer is cached for the lifetime of a single skill invocation; skills never re-ask within the same run.
- **REQ-3.7**: Batch operations resolve per-item; mismatches across items either prompt per-item or collapse into a single batch-level confirmation when possible.

#### Decisions & Assumptions

- Cross-run caching only happens via the manifest itself, never in transient storage.
- "Ask and save" is always opt-in on the save step, never automatic.

---

### Epic 4: Retrofit Hardcoded Skills

**Goal**: Remove every per-user constant from plugin source — owner names, template paths, Azure IDs, dev-settings repo qualifier — and replace with manifest reads via the Epic 3 contract.

#### Requirements

- **REQ-4.1** `platform:repo-clone` — context argument stays; resolved values (`github-rise`, `GBR-Perso-1`, `Rise-4`, `dev.azure.com/Mantu`) come from manifest fields, not source.
- **REQ-4.2** `platform:security-scan` — drop `Rise-4` hardcode; accept `<context>/<repo>` or `<owner>/<repo>`; owner resolves via manifest when context is given.
- **REQ-4.3** `platform:plugin-commit` — batch iterates workspace folders and resolves each folder's context per Epic 3; pushes use the context's declared SSH alias/credential.
- **REQ-4.4** `dev-workflow:repo-commit` — before push, verifies origin URL matches the cwd's context; Option-3 ask on mismatch.
- **REQ-4.5** `dev-workflow:project-init`, `project-inject-dev-settings`, `project-migrate-dev-settings` — the unqualified `it--dev-settings` reference becomes `{context.dev_settings_repo}` from manifest.
- **REQ-4.6** `rise-dev-plugin:repo-scaffold` — hardcoded `Rise-4` owner becomes manifest-derived; context argument selects target org.
- **REQ-4.7** `rise-dev-plugin:migrate-workflows` — template source path (`C:\...\it--app-template`) becomes manifest-declared per context.
- **REQ-4.8** `rise-dev-plugin:migrate-terraform-auth` — Azure subscription IDs and tenant ID come from manifest, not source; env-file generation uses manifest values.
- **REQ-4.9** `dev-workflow:repo-terraform` — verifies the active Azure auth context matches the cwd's context before operating.

#### Decisions & Assumptions

- Each retrofit can ship independently once Epics 1–3 land.
- Skills remain functional for users without a manifest — fallback may include interactive prompts or the current hardcoded defaults until retrofit is complete.

---

## Priorities

| Priority | Epic / Requirement | Rationale |
| --- | --- | --- |
| 1 | Epic 1 (manifest format) | Every other epic depends on the file shape being settled |
| 2 | Epic 3 (resolution contract) | The shared protocol every skill will implement; designing it without retrofits is cheaper |
| 3 | Epic 2 (`/platform:contexts`) | Quality-of-life for onboarding; can ship after Epics 1+3 with a hand-written manifest in the interim |
| 4 | Epic 4 — REQ-4.1, 4.3, 4.4, 4.5 | Most-used skills, biggest daily friction reduction (clone, batch commit, commit, dev-settings) |
| 5 | Epic 4 — REQ-4.2, 4.6, 4.7, 4.8, 4.9 | Lower-frequency and Rise-specific retrofits |

## Out of Context

- **Environment setup** (SSH aliases per account, `includeIf` gitconfig blocks, gh keyring per account, removing `GH_TOKEN`) — separate requirements doc; reinforces this work but mechanically distinct.
- **Plugin-to-plugin dependency mechanism** — not needed; the manifest is a file convention, not a code dependency.
- **Defining the Tactical context's concrete values** — user homework; manifest supports it when known.
- **Bulk rewriting of existing repo origin URLs** — `/platform:contexts sync` may offer it per-repo with confirmation, not required for foundation.
