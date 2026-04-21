# Follow-up Tasks

Tasks deferred from completed requirement work, to be picked up in a later pass.

---

## From: contexts-manifest.md (2026-04-17)

### FU-1: Refactor `project-init` to delegate to `/project-inject-dev-settings`

**Origin**: Identified during the contexts-manifest plan review. The `project-init` skill currently embeds a full copy of the `project-inject-dev-settings` injection flow with an explicit maintenance note (line 209 of the current `SKILL.md`) warning that both copies must be kept in sync.

**Scope**: Out of the contexts-manifest retrofit scope (which is about removing hardcoded per-user values, not restructuring orchestration).

**Task**: Replace the embedded injection copy inside `project-init` with a delegation pattern (invoke `/project-inject-dev-settings` as part of the bootstrap flow), removing the duplication entirely. Remove the maintenance note once the embed is gone.

**Plugin**: `dev-workflow`
**Skill**: `project-init/SKILL.md`
**Related**: `project-inject-dev-settings/SKILL.md`

---

### FU-2: Lower-priority retrofits (REQ-4.2, REQ-4.9)

**Origin**: Deferred from the initial foundation pass per the priorities table.

**Task**:
- `platform:security-scan` — drop `Rise-4` hardcode; accept `<context>/<repo>` or `<owner>/<repo>` (REQ-4.2)
- `dev-workflow:repo-terraform` — verify active Azure auth context matches cwd context before operating (REQ-4.9)

---

### FU-3: Cross-plugin shared doc drift check

**Origin**: Risk 1 in the contexts-manifest plan. `_context-resolution.md` is duplicated between `claude-platform-plugin` and `claude-dev-workflow-plugin`; the platform copy is the source of truth.

**Task**: Add a consistency check to the `plugin-commit` skill that compares checksums of the two copies and flags drift before commit.

**Plugin**: `platform`
**Skill**: `plugin-commit/SKILL.md`
