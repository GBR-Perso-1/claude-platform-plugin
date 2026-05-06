---
name: session-to-skill
description: "Retroactively distil a completed piece of work from the current session into a reusable fix- or migrate- skill. Accepts a natural-language direction to scope which part of the session to capture."
---

## Important rules

Read and follow the rules in `../shared/_ux-rules.md`.

## Arguments

`$ARGUMENTS` is optional. If provided, treat it as the direction hint (free-text description of what to capture and optionally where in the session the relevant work began). If absent, collect it interactively in Phase 1.

---

### Phase 1 — Direction Intake

#### Step 1.1 — Read or collect direction

If `$ARGUMENTS` is non-empty: store its value as DIRECTION. Skip to Step 1.2.

If `$ARGUMENTS` is empty: ask via `AskUserQuestion`:

> "What would you like to distil into a skill?"
>
> Describe what you did — include:
> - The topic or problem you solved (this scopes what gets captured).
> - Optionally, a phrase or message from the conversation where the relevant work began (e.g. "from when I started migrating the auth middleware"). If not provided, the full session is scanned.

Accept the user's free-text answer. Store it as DIRECTION.

#### Step 1.2 — Parse direction

Analyse DIRECTION to extract two values:

- **TOPIC**: the subject matter / task the user wants to capture. This drives relevance filtering and eventual skill naming.
- **START_HINT**: an optional phrase the user mentioned as the start point. If DIRECTION contains temporal language ("from when", "starting from", "after I said", "when we began") followed by a description, extract that description as START_HINT. If no such language is present, set START_HINT to `null`.

Print a brief interpretation line (not an `AskUserQuestion` — just inline output):

```
Direction understood.
Topic: <TOPIC>
Scan from: <START_HINT if non-null, otherwise "beginning of session">
```

---

### Phase 2 — Session Scan and Relevance Filter

#### Step 2.1 — Locate the start boundary

If START_HINT is non-null: scan backward through the conversation history to find the earliest message (user or assistant) whose content most closely matches the START_HINT phrase. That message marks the start of the relevant window.

If no message is a reasonable match, print:

```
No clear match found for the start hint: "<START_HINT>"
Falling back to the full session.
```

and proceed with the full session as the window.

If the user's START_HINT references content that is no longer visible in context (evicted due to session length), surface this explicitly:

```
Warning: the start hint "<START_HINT>" may refer to content that has been evicted from the context window.
The distillation may be incomplete. Proceeding with the earliest visible content.
```

If START_HINT is null: the window is the entire conversation from the first message.

#### Step 2.2 — Build the raw action list

Within the identified window, review every assistant turn and record:

- Tool calls made (file reads, writes, bash commands, searches).
- Files created or modified.
- Commands run and their outcomes.
- Decisions stated by the user or made by the assistant.

This is the RAW_LIST.

#### Step 2.3 — Classify each step

For each item in RAW_LIST, classify it against TOPIC:

| Category | Definition |
|---|---|
| **In scope** | Clearly relevant to TOPIC — directly advances the stated task or solves the stated problem. |
| **Out of scope** | Clearly irrelevant to TOPIC — exploratory detour, unrelated side task, or noise. Apply the same noise filter as `session-to-skill`: remove dead-end reads, failed commands immediately retried, duplicate steps, and unused diagnostic output. |
| **Ambiguous** | Could plausibly be in or out of scope — threshold is qualitative. Flag these. |

Store as: IN_SCOPE_STEPS, OUT_OF_SCOPE_STEPS, AMBIGUOUS_STEPS.

#### Step 2.4 — Ambiguity gate

If AMBIGUOUS_STEPS is empty: proceed directly to Phase 3.

If AMBIGUOUS_STEPS is non-empty: present them to the user via a single `AskUserQuestion`. In the question text, list each ambiguous step with: its number, a one-line description of what it did, and why it is ambiguous relative to TOPIC.

> "The following steps are ambiguous — they may or may not relate to '<TOPIC>'. Review each and decide."
>
> [numbered list: step number, description, reason for ambiguity]
>
> How would you like to handle these?

Options:
1. Include all ambiguous steps *(add to in-scope)*
2. Exclude all ambiguous steps *(add to out-of-scope)*
3. Decide step by step
4. Other *(describe changes)*

- **Option 1**: move all AMBIGUOUS_STEPS into IN_SCOPE_STEPS. Proceed to Phase 3.
- **Option 2**: move all AMBIGUOUS_STEPS into OUT_OF_SCOPE_STEPS. Proceed to Phase 3.
- **Option 3**: for each ambiguous step in sequence, ask via `AskUserQuestion`: "Step <N>: <description> — Include this step?" Options: Include / Exclude. Move each step accordingly. After all steps are resolved, proceed to Phase 3.
- **Option 4 (Other)**: accept the user's free-text description, apply it to move steps accordingly, then proceed to Phase 3.

After the gate resolves: FILTERED_STEPS = IN_SCOPE_STEPS.

---

### Phase 3 — Distil

#### Step 3.1 — Determine task type and name

Inspect FILTERED_STEPS and DIRECTION:

- Dominant pattern is **correcting a bug, fixing a recurring issue, or patching a defect** → type: `fix`, name: `fix-<topic>`
- Dominant pattern is **upgrading, moving, migrating, or modernising code** → type: `migrate`, name: `migrate-<topic>`
- Neither clearly dominant → default to `fix-<topic>`

Derive `<topic>` from DIRECTION and FILTERED_STEPS: 2–4 words, lowercase, hyphenated, no project-specific names. If `$ARGUMENTS` was a single hyphenated slug (e.g. `auth-middleware`), use it as the topic directly.

Store as SKILL_NAME.

#### Step 3.2 — Identify placeholders

Walk FILTERED_STEPS. For every value specific to the current project (file paths, component names, module names, configuration keys, package names, environment names, class names), replace it with a `{{PLACEHOLDER_NAME}}` token using UPPER_SNAKE_CASE inside `{{ }}`.

Common examples:
- File or directory paths: `{{TARGET_FILE}}`, `{{SOURCE_DIR}}`
- Module or component names: `{{MODULE_NAME}}`, `{{COMPONENT_NAME}}`
- Package or dependency names: `{{PACKAGE_NAME}}`, `{{PACKAGE_VERSION}}`
- Configuration keys: `{{CONFIG_KEY}}`
- Environment or service names: `{{SERVICE_NAME}}`

Produce a PLACEHOLDER_LIST (each entry: token name + brief description).

#### Step 3.3 — Resolve destination

**Probe plugin repos.** Check which of the following directories exist on disk:

| Label | Path |
|---|---|
| `platform` | `C:\Workspace\Dev\Perso.Applications\claude-platform-plugin` |
| `dev-workflow` | `C:\Workspace\Dev\Perso.Applications\claude-dev-workflow-plugin` |
| `rise` | `C:\Workspace\Dev\Rise.Applications\it--claude-rise-plugin` |

Build the list of available destinations from those confirmed to exist. Always append:

| Label | Path |
|---|---|
| `project` | `<cwd>/.claude/skills` |

**Question A — Destination** (`AskUserQuestion`):

> "Where should the skill be saved?"
>
> [numbered list of confirmed-on-disk plugin paths + project]

**Question B — Skill name** (`AskUserQuestion`):

> "Confirm or override the skill name."
>
> Options:
>   1. Keep `<SKILL_NAME>` (Recommended)
>   2. Use a different name (type via Other)

Update SKILL_NAME if overridden. Set SKILL_DEST to the `skills/` path for the chosen destination.

Output path:
- Plugin destination: `<SKILL_DEST>/<SKILL_NAME>/SKILL.md`
- Project destination: `<cwd>/.claude/skills/<SKILL_NAME>/SKILL.md`

#### Step 3.4 — Write skill file

Create the directory if it does not exist. Write:

```
---
name: <SKILL_NAME>
description: <one-sentence description derived from DIRECTION>
---

## Context

<1–2 sentences describing the problem this skill solves and when to use it.>

## Prerequisites

<Bulleted list of tools, dependencies, or setup the consumer needs.
Omit this section entirely if none.>

## Placeholders

Before running this skill, substitute all `{{PLACEHOLDER}}` tokens:

| Placeholder | Description |
|---|---|
| {{PLACEHOLDER_NAME}} | <what the consumer must provide> |

<!-- Omit this section entirely if no placeholders were identified. -->

## Steps

<Numbered, actionable steps derived from FILTERED_STEPS.
Each step must be unambiguous and executable by another Claude instance on a different project.
Use imperative voice. Merge consecutive steps into a single step where appropriate.>

## Verification

<1–3 bullet points describing how to confirm the skill ran correctly.
Omit if not determinable from the session.>
```

---

### Phase 4 — Report

Print after writing the file:

```
Skill written.

Name:  <SKILL_NAME>
Path:  <absolute path to written file>

Steps captured (<N>):
  1. <step summary>
  2. ...

Placeholders (<N>):
  - {{PLACEHOLDER_NAME}} — <description>
```

(If no placeholders: print `No placeholders — skill is self-contained.`)

Ask via `AskUserQuestion`:

> "Would you like to adjust anything in the generated skill?"

Options:
1. No — skill is good as written *(Recommended)*
2. Yes — I'll describe what to change

If option 2: wait for description, apply edits, re-print the Report block with a summary of changes, then re-present the same question.

---

### Phase 5 — Commit (plugin destinations only)

Skip entirely if the user chose `project` in Step 3.3.

PLUGIN_REPO_ROOT reference:

| Destination | PLUGIN_REPO_ROOT |
|---|---|
| `platform` | `C:\Workspace\Dev\Perso.Applications\claude-platform-plugin` |
| `dev-workflow` | `C:\Workspace\Dev\Perso.Applications\claude-dev-workflow-plugin` |
| `rise` | `C:\Workspace\Dev\Rise.Applications\it--claude-rise-plugin` |

Ask via `AskUserQuestion`:

> "Do you want to commit and push this skill to the plugin repo now?"

Options:
1. Yes — commit and push *(Recommended)*
2. No — I'll commit manually later

If **No**:

```
Skill saved. When ready to commit, run:
  /dev-workflow:plugin-commit <actual PLUGIN_REPO_ROOT value>
```

Then stop.

If **Yes**: check whether `C:\Workspace\Dev\Perso.Applications\claude-dev-workflow-plugin` exists on disk. If not:

```
The dev-workflow plugin repo was not found on disk. Install it to enable auto-commit:

  claude plugin install dev-workflow

Then run manually: /dev-workflow:plugin-commit <actual PLUGIN_REPO_ROOT value>
```

Then stop.

If available: invoke `/dev-workflow:plugin-commit <PLUGIN_REPO_ROOT>`.
