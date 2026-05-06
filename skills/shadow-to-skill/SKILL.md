---
name: shadow-to-skill
description: "Shadow the current session silently, then turn the meaningful steps into a generic, parameterised fix- or migrate- skill. Before writing, asks where the skill should live (platform / dev-workflow / rise plugin, or current project) and confirms the skill name."
---

## Important rules

Read and follow the rules in `../shared/_ux-rules.md`.

## Arguments

`$ARGUMENTS` is optional. If provided, treat it as a topic hint for the generated skill name (e.g. `auth-middleware`). If absent, derive the topic from the session work.

---

### Phase 1 — Start shadowing

#### Step 1.1 — Collect intent

Ask the user via `AskUserQuestion`:

> "What are you about to do? (One sentence — this becomes the generated skill's description.)"

Wait for the answer. Store it as SESSION_INTENT.

#### Step 1.2 — Announce shadow mode

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

#### Step 3.1 — Build raw action list

Review the full conversation from the moment Phase 1 completed to now. For each assistant turn, record:

- Tool calls made (file reads, writes, bash commands, searches).
- Files created or modified.
- Commands run and their outcomes.
- Decisions stated by the user or made by the assistant.

#### Step 3.2 — Filter noise

Remove from the list:

- File reads that led to no subsequent action (dead-end exploration).
- Failed commands immediately retried with a corrected version — keep only the successful variant.
- Duplicate steps with identical effect.
- Intermediate debug or diagnostic commands whose output was not used in a decision.

#### Step 3.3 — Determine task type and name

Inspect the filtered list and SESSION_INTENT:

- Dominant pattern is **correcting a bug, fixing a recurring issue, or patching a defect** → type: `fix`, name: `fix-<topic>`
- Dominant pattern is **upgrading, moving, migrating, or modernising code** → type: `migrate`, name: `migrate-<topic>`
- Neither clearly dominant → default to `fix-<topic>`

Derive `<topic>` from SESSION_INTENT and the filtered list: 2–4 words, lowercase, hyphenated, no project-specific names. If `$ARGUMENTS` was supplied, use it as the topic directly.

Store as SKILL_NAME.

#### Step 3.4 — Identify placeholders

Walk the filtered list. For every value specific to the current project (file paths, component names, module names, configuration keys, package names, environment names, class names), replace it with a `{{PLACEHOLDER_NAME}}` token using UPPER_SNAKE_CASE inside `{{ }}`.

Common examples:

- File or directory paths: `{{TARGET_FILE}}`, `{{SOURCE_DIR}}`
- Module or component names: `{{MODULE_NAME}}`, `{{COMPONENT_NAME}}`
- Package or dependency names: `{{PACKAGE_NAME}}`, `{{PACKAGE_VERSION}}`
- Configuration keys: `{{CONFIG_KEY}}`
- Environment or service names: `{{SERVICE_NAME}}`

Produce a PLACEHOLDER_LIST (each entry: token name + brief description of what the consumer must substitute).

#### Step 3.5 — Resolve destination

**Probe plugin repos.** Check which of the following directories exist on disk:

| Label          | Path                                                             |
| -------------- | ---------------------------------------------------------------- |
| `platform`     | `C:\Workspace\Dev\Perso.Applications\claude-platform-plugin`     |
| `dev-workflow` | `C:\Workspace\Dev\Perso.Applications\claude-dev-workflow-plugin` |
| `rise`         | `C:\Workspace\Dev\Rise.Applications\it--claude-rise-plugin`      |

Build a list of _available_ destinations — only include an entry if its directory exists. Always append:

| Label     | Path                   |
| --------- | ---------------------- |
| `project` | `<cwd>/.claude/skills` |

**Ask the user** via two sequential `AskUserQuestion` calls:

**Question A — Destination**: present the available destinations as a numbered list. Only show destinations whose directories were confirmed to exist in the probe step above. Always include `project`. For example:

> "Where should the skill be saved?"
>
> Options (only those confirmed on disk):
> N. `<label>` — `<resolved skills/ path>`
> ...
> N. `project` — `<cwd>/.claude/skills`

**Question B — Skill name**: after the user selects a destination, present:

> "Confirm or override the skill name."
>
> Options:
>
> 1. Keep `<SKILL_NAME>` (Recommended)
> 2. Use a different name (type via Other)

Accept the user's answer and:

- Update SKILL_NAME if they provided an override name.
- Set SKILL_DEST to the `skills/` path that matches their chosen destination.

If the user picks `platform`, `dev-workflow`, or `rise`, the final output path is `<SKILL_DEST>/<SKILL_NAME>/SKILL.md` (no `.claude/` prefix — these are plugin skill directories).
If the user picks `project`, the final output path is `<cwd>/.claude/skills/<SKILL_NAME>/SKILL.md`.

#### Step 3.6 — Write skill file

Create the directory `<SKILL_DEST>/<SKILL_NAME>/` (or `<cwd>/.claude/skills/<SKILL_NAME>/` for `project`) if it does not exist.

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

1. No — skill is good as written _(Recommended)_
2. Yes — I'll describe what to change

If the user selects option 2, wait for their description, apply the edits to the skill file, and re-print the Report block with a brief summary of what changed.

After re-printing the Report block, re-present the same `AskUserQuestion` so the user can make further adjustments or confirm they are satisfied.

---

### Phase 5 — Commit (plugin destinations only)

Skip this phase entirely if the user chose `project` as destination in Step 3.5.

PLUGIN_REPO_ROOT is the repo root directory already resolved in Step 3.5 for the chosen destination — use the value determined there. Do not re-derive it. Reference:

| Destination    | PLUGIN_REPO_ROOT                                                 |
| -------------- | ---------------------------------------------------------------- |
| `platform`     | `C:\Workspace\Dev\Perso.Applications\claude-platform-plugin`     |
| `dev-workflow` | `C:\Workspace\Dev\Perso.Applications\claude-dev-workflow-plugin` |
| `rise`         | `C:\Workspace\Dev\Rise.Applications\it--claude-rise-plugin`      |

**Ask** via `AskUserQuestion`:

> "Do you want to commit and push this skill to the plugin repo now?"

Options:

1. Yes — commit and push _(Recommended)_
2. No — I'll commit manually later

If the user picks **No**, print (substituting the actual resolved PLUGIN_REPO_ROOT path):

```
Skill saved. When ready to commit, run:
  /dev-workflow:plugin-commit <actual PLUGIN_REPO_ROOT value>
```

Then stop.

If the user picks **Yes**:

**Availability check**: if the `dev-workflow` plugin repo (`C:\Workspace\Dev\Perso.Applications\claude-dev-workflow-plugin`) was confirmed to exist during the Step 3.5 disk probe, treat `dev-workflow:plugin-commit` as available. If it was not found on disk, print:

```
The dev-workflow plugin repo was not found on disk. Install it to enable auto-commit:

  claude plugin install dev-workflow

Then run manually: /dev-workflow:plugin-commit <actual PLUGIN_REPO_ROOT value>
```

Then stop.

If `dev-workflow:plugin-commit` **is** available, invoke it with PLUGIN_REPO_ROOT as the argument — where PLUGIN_REPO_ROOT is the repo root (parent of `skills/`) that was resolved in Step 3.5:

Run the skill as: `/dev-workflow:plugin-commit <PLUGIN_REPO_ROOT>`
