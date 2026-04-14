# Security Scan — Evolution Requirements

## Vision

Add a `/security-scan` skill to the plugin that scans any Rise repository
for secrets, injection vulnerabilities, and exposure risks. It produces a
unified, read-only report using three specialised agents running in parallel.
Scan depth is configurable, with hard limits in place to keep cost predictable
and prevent runaway token usage on large repos.

---

## Epics

### Epic 1: Core Scanning

**Goal**: Detect the three main classes of security risk using dedicated
agents, merged into a single ranked report.

#### Requirements

- **REQ-1.1**: Three scanner agents run in parallel — secrets, injection,
  exposure — each producing findings in a standard format
  (agent, severity, confidence, file, line, title, description, impact, fix).
- **REQ-1.2**: The orchestrating skill merges all findings, deduplicates by
  file + line (keeping the higher severity entry, noting both agent sources),
  and sorts by severity (Critical → High → Medium → Low) then confidence.
- **REQ-1.3**: The unified report renders inline with a summary table,
  per-severity finding tables, and an agent coverage section.
- **REQ-1.4**: Secret values are always redacted before any finding is emitted
  (first 4 + `***` + last 4 for values > 8 chars; `[REDACTED]` otherwise).
- **REQ-1.5**: Agents are read-only — no file modifications, no commits,
  no staging, no pushes.

#### Decisions & Assumptions

- Finding schema is conveyed via agent prompt instructions; no shared schema
  file needed in a markdown-only plugin.
- Colour assignments: red (secrets), orange (injection), magenta (exposure).

---

### Epic 2: Scan Modes

**Goal**: Two modes — surface for speed, deep for thoroughness — with an
honest scope for each given the tools available (Grep, Read, Bash, Glob).

#### Requirements

- **REQ-2.1**: Surface mode scans a focused set of high-risk files
  (controllers, API handlers, `.env` files, build configs) using
  highest-signal patterns only. It reports the matching line plus minimal
  surrounding context.
- **REQ-2.2**: Deep mode scans all tracked files (excluding binary and vendor
  directories) using a broader set of pattern variants. For every file with a
  hit, the agent reads the full file to confirm the finding and reduce false
  positives.
- **REQ-2.3**: Deep mode extends injection scanning beyond controllers to
  middleware, utilities, and shared services.
- **REQ-2.4**: Deep mode extends exposure scanning to all DTO and response
  model files, checking for sensitive field names and over-exposed properties.
- **REQ-2.5**: Deep mode cross-references config file hits against
  `.gitignore` — a secret in an ignored file is flagged at lower severity.
- **REQ-2.6**: No git history scanning in either mode — only the current
  working tree is inspected.

#### Decisions & Assumptions

- Deep mode is enhanced pattern matching with richer context, not static
  analysis or taint tracing. Findings reflect pattern confidence, not
  proven exploitability.
- "Data flow tracing" and "DTO composition chain tracing" are explicitly out
  of scope — both require AST-level tooling not available here.

---

### Epic 3: Safeguards and Limits

**Goal**: Prevent runaway token usage and make cost predictable regardless
of repo size or contents.

#### Requirements

- **REQ-3.1 — File count guard**: Before scanning, count tracked files via
  `git ls-files | wc -l`. Apply per-mode thresholds:
  - Surface: warn at >500 files; hard stop at >2,000 files.
  - Deep: warn at >200 files; hard stop at >1,000 files.
  - Hard stop surfaces a clear message directing the user to surface mode or
    a subdirectory target.
- **REQ-3.2 — Remote repo size check**: Before `gh repo clone`, fetch disk
  usage via `gh repo view --json diskUsage`. Refuse to clone if the repo
  exceeds 150 MB.
- **REQ-3.3 — Per-agent findings cap**: Each agent caps its output at 50
  findings, ranked by severity then confidence. If truncated, the agent notes
  the total count of findings not shown.
- **REQ-3.4 — Grep result volume guard**: If a single pattern match returns
  >100 lines, the agent retains the first 20 + last 5 results for that
  pattern and records the total match count.
- **REQ-3.5 — Pattern count cap**: Each agent runs a fixed maximum number of
  grep commands — 20 patterns in surface mode, 35 in deep mode.

#### Decisions & Assumptions

- REQ-3.1 and REQ-3.3 are the highest-priority guards — they cover the two
  most common runaway scenarios.
- Thresholds are starting points; they can be tuned after real-world usage.

---

## Priorities

| Priority | Requirement | Rationale |
|----------|-------------|-----------|
| 1 | REQ-1.1 – REQ-1.5 (core scan) | Foundation — nothing else works without it |
| 2 | REQ-2.1, REQ-2.2 (surface + deep modes) | Core value proposition |
| 3 | REQ-3.1, REQ-3.3 (file count + findings cap) | Most important cost guards |
| 4 | REQ-2.3 – REQ-2.6 (deep mode extensions) | Incremental depth improvements |
| 5 | REQ-3.2, REQ-3.4, REQ-3.5 (remaining guards) | Belt-and-braces limits |

---

## Out of Scope

- Git history scanning (removed — unbounded cost, no clear limit strategy).
- Data flow / taint analysis (requires AST tooling not available).
- DTO composition chain tracing (requires type system awareness).
- Auto-remediation — scan is diagnostic only.
- Scanning repos outside the Rise-4 GitHub org in remote mode.
