# Session Distil — Evolution Requirements

## Vision

Add a retroactive companion to `session-to-skill`: a skill the user invokes *after* completing work, provides a natural-language direction, and receives a generically reusable skill distilled from the relevant portion of the session — without any prospective shadowing or trigger-phrase ceremony.

---

## Epics

### Epic 1: Retroactive session-to-skill (new skill)

**Goal**: Allow a user who has finished a piece of work to package it into a reusable skill immediately, without having started shadowing in advance.

#### Requirements

- **REQ-1.1**: The skill must be a standalone skill separate from `session-to-skill`. It must not modify the prospective skill's behaviour.

- **REQ-1.2**: On invocation, the skill must accept a natural-language **direction** that serves two purposes: (a) scope — what topic or task to capture, and (b) optional start point — where in the session the relevant work began (e.g. *"from the Azure investigation onwards"*). If no start point is provided, the full session is scanned.

- **REQ-1.3**: The skill must scan the conversation history bounded by the direction's start point (or the full session if none), then automatically filter it to steps relevant to the direction. Steps whose relevance is ambiguous must be flagged explicitly for the user to accept or discard before the skill is written.

- **REQ-1.4**: The skill must produce a `fix-<topic>` or `migrate-<topic>` skill file using the same output structure as `session-to-skill` Phase 3 (filtered steps → placeholder identification → file write).

- **REQ-1.5**: The destination resolution and commit flow (Phase 3.5 and Phase 5 of `session-to-skill`) must behave identically to the prospective skill: probe available plugin repos, ask the user where to save, confirm or override the skill name, then optionally commit and push.

#### Decisions & Assumptions

- The direction hint is free-text; no structured format is enforced. The skill interprets it using the same judgement it would apply to a session intent statement.
- "Ambiguous" means steps that could plausibly be in or out of scope given the direction — the threshold is qualitative, not algorithmic.
- Output types are limited to `fix-` and `migrate-` for now, consistent with `session-to-skill`. Broader types are explicitly deferred.

---

## Priorities

| Priority | Requirement | Rationale |
|---|---|---|
| 1 | REQ-1.2 — direction + start point | Core differentiator from the prospective skill |
| 2 | REQ-1.3 — auto-filter with ambiguity flag | Keeps the flow fast while remaining trustworthy |
| 3 | REQ-1.1 — standalone skill | Avoids polluting the prospective skill's contract |
| 4 | REQ-1.4 / REQ-1.5 — output + commit | Shared with existing skill; lower risk |

---

## Out of Scope

- Modifying `session-to-skill` in any way.
- Supporting output types beyond `fix-` and `migrate-`.
- Structured syntax for the direction hint (e.g. flags or a form).
- Multi-session capture (across separate Claude Code conversations).
