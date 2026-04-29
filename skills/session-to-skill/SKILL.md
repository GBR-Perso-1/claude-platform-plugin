---
name: session-to-skill
description: "Shadow the current session silently, then turn the meaningful steps into a generic, parameterised fix- or migrate- skill written to .claude/skills/<name>/SKILL.md in the current project."
---

## Important rules

Read and follow the rules in `../shared/_ux-rules.md`.

## Arguments

`$ARGUMENTS` is optional. If provided, treat it as a topic hint for the generated skill name (e.g. `auth-middleware`). If absent, derive the topic from the session work.

---

### Phase 1 — Start shadowing

### Step 1.1 — Collect intent

Ask the user via `AskUserQuestion`:

> "What are you about to do? (One sentence — this becomes the generated skill's description.)"

Wait for the answer. Store it as SESSION_INTENT.

### Step 1.2 — Announce shadow mode

Print exactly:

```
Session → Skill — shadowing started.
Intent: <SESSION_INTENT>

Work as normal. When you are done, type exactly:

  stop shadowing

That exact phrase is the only way to end the session and generate the skill.
I will stay silent until then.
```

Stay silent. Do **not** interrupt, comment on, or assist with the user's work unless they directly address you.

---

### Phase 2 — Trigger

Wait. Trigger Phase 3 **only** when the user sends a message whose entire content (case-insensitive, leading/trailing whitespace stripped) is exactly:

- `stop shadowing`

Any other message — including messages that contain these words as part of a sentence — must not trigger Phase 3.

---

### Phase 3 — Distil

### Step 3.1 — Build raw action list

Review the full conversation from the moment Phase 1 completed to now. For each assistant turn, record:

- Tool calls made (file reads, writes, bash commands, searches).
- Files created or modified.
- Commands run and their outcomes.
- Decisions stated by the user or made by the assistant.

### Step 3.2 — Filter noise

Remove from the list:

- File reads that led to no subsequent action (dead-end exploration).
- Failed commands immediately retried with a corrected version — keep only the successful variant.
- Duplicate steps with identical effect.
- Intermediate debug or diagnostic commands whose output was not used in a decision.

### Step 3.3 — Determine task type and name

Inspect the filtered list and SESSION_INTENT:

- Dominant pattern is **correcting a bug, fixing a recurring issue, or patching a defect** → type: `fix`, name: `fix-<topic>`
- Dominant pattern is **upgrading, moving, migrating, or modernising code** → type: `migrate`, name: `migrate-<topic>`
- Neither clearly dominant → default to `fix-<topic>`

Derive `<topic>` from SESSION_INTENT and the filtered list: 2–4 words, lowercase, hyphenated, no project-specific names. If `$ARGUMENTS` was supplied, use it as the topic directly.

Store as SKILL_NAME.

### Step 3.4 — Identify placeholders

Walk the filtered list. For every value specific to the current project (file paths, component names, module names, configuration keys, package names, environment names, class names), replace it with a `{{PLACEHOLDER_NAME}}` token using UPPER_SNAKE_CASE inside `{{ }}`.

Common examples:
- File or directory paths: `{{TARGET_FILE}}`, `{{SOURCE_DIR}}`
- Module or component names: `{{MODULE_NAME}}`, `{{COMPONENT_NAME}}`
- Package or dependency names: `{{PACKAGE_NAME}}`, `{{PACKAGE_VERSION}}`
- Configuration keys: `{{CONFIG_KEY}}`
- Environment or service names: `{{SERVICE_NAME}}`

Produce a PLACEHOLDER_LIST (each entry: token name + brief description of what the consumer must substitute).

### Step 3.5 — Write skill file

Determine the output path:

- Current working directory of the consumer project = `cwd`.
- Output path: `<cwd>/.claude/skills/<SKILL_NAME>/SKILL.md`

Create the directory `<cwd>/.claude/skills/<SKILL_NAME>/` if it does not exist.

Write the file with this structure:

```
---
name: <SKILL_NAME>
description: <one-sentence description derived from SESSION_INTENT>
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

<Numbered, actionable steps derived from the filtered action list.
Each step must be unambiguous and executable by another Claude instance on a different project.
Use imperative voice. Merge steps always performed consecutively into a single step.>

## Verification

<1–3 bullet points describing how to confirm the skill ran correctly.
Omit this section entirely if not determinable from the session.>
```

---

### Phase 4 — Report

After writing the file, print:

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

Then ask via `AskUserQuestion`:

> "Would you like to adjust anything in the generated skill?"

Options:
1. No — skill is good as written *(Recommended)*
2. Yes — I'll describe what to change

If the user selects option 2, wait for their description, apply the edits to the skill file, and re-print the Report block with a brief summary of what changed.
