# Rise Engineering Rules — Evolution Requirements

## Vision

Provide Rise developers with a built-in security scanning capability that identifies secrets, vulnerabilities, and exposure risks across any Rise repository — giving teams confidence that their code is safe before it reaches production, without leaving the Claude Code workflow.

## Epics

### Epic 1: Security Scan Skill

**Goal**: Developers can scan any Rise repository for security issues and receive a detailed, actionable report — inline in the conversation — without modifying any code.

#### Requirements

- **REQ-1.1**: The plugin shall provide a `/security-scan` skill that orchestrates a security scan and produces a read-only report.
- **REQ-1.2**: The skill shall delegate scanning to three specialised agents, spawned in parallel:
  - **Secrets agent** — scans for committed secrets (API keys, passwords, tokens, connection strings, private keys) and git history secrets (credentials committed then removed but still in git history).
  - **Injection agent** — scans for injection vulnerabilities (SQL injection, XSS, command injection, and other input-based attack vectors), including data flow tracing in deep mode.
  - **Exposure agent** — scans for context-dependent exposure risks (e.g. secrets bundled into client-side builds, sensitive config shipped to production frontends).
- **REQ-1.3**: The skill shall merge findings from all three agents into a single unified report, deduplicated and sorted by severity.
- **REQ-1.4**: The skill shall support two input modes:
  - **Local** — scan a folder on disk, respecting `.gitignore` (skip build output, `node_modules`, etc.)
  - **Remote** — scan a Rise-4 organisation GitHub repo, cloned via `gh` CLI using the user's existing authentication.
- **REQ-1.5**: The skill shall be tech-agnostic — it must work across any tech stack (C#/.NET, TypeScript/Vue, Python, Terraform, etc.) without requiring stack-specific configuration.
- **REQ-1.6**: The skill shall support two depth modifiers:
  - **Surface** — fast pattern matching for the most critical and obvious issues; should complete quickly for a typical Rise repo. All three agents run but with reduced scope.
  - **Deep** — thorough coverage of all files and patterns, git history scanning (secrets agent), data flow tracing (injection agent), and build/deployment context analysis (exposure agent).
- **REQ-1.7**: Each finding shall be classified by severity: **Critical**, **High**, **Medium**, or **Low**.
- **REQ-1.8**: Each finding shall include a confidence indicator (**high**, **medium**, or **low**) to help the user triage potential false positives.
- **REQ-1.9**: Each finding shall include full context: file path, line number, description of the issue, why it matters (impact), and a hint on how to fix it.
- **REQ-1.10**: The report shall be delivered inline in the conversation.
- **REQ-1.11**: Actual secret values found in the scan shall always be redacted in the report output (e.g. `AKIA************MPLE`) to prevent accidental exposure in conversation logs.
- **REQ-1.12**: The skill shall never modify source code — it is purely diagnostic.

#### Decisions & Assumptions

- The skill follows the same orchestration pattern as `/app-implement` — one skill coordinating specialised agents in parallel.
- All three agents run in both surface and deep modes — the depth modifier controls scope within each agent, not which agents run.
- The surface/deep distinction is primarily about coverage and speed, not accuracy — surface is a fast subset, deep is comprehensive.
- Semantic analysis (data flow tracing) in deep mode is best-effort — only included where confidence is high enough to avoid excessive false positives.
- Git history scanning is part of deep mode only (secrets agent) — surface mode scans the current state of the code.
- Remote mode is restricted to Rise-4 organisation repos — no arbitrary public repo scanning.
- No time or scope limits on deep mode — it runs until complete. If this proves problematic in practice, limits can be added later.

## Priorities

| Priority | Epic / Requirement | Rationale |
| -------- | ------------------ | --------- |
| 1 | REQ-1.2 — Secrets agent | Highest-impact, most common security issue; covers committed secrets + git history |
| 2 | REQ-1.2 — Injection agent | Direct attack vector with production impact |
| 3 | REQ-1.2 — Exposure agent | Context-dependent but critical when present |
| 4 | REQ-1.3 — Report merging | Unified report is the user-facing deliverable |
| 5 | REQ-1.4b — Remote mode | Enables audit workflows; local mode is the primary use case |

## Out of Scope

- **Code modification or auto-fixes** — the skill is read-only; fixing is the developer's responsibility.
- **Dependency vulnerability scanning** — covered by existing tooling (`npm audit`, `dotnet list package --vulnerable`).
- **Runtime / infrastructure security** — no scanning of deployed environments, network config, or cloud IAM.
- **Penetration testing** — no active exploitation or dynamic analysis.
- **Non-Rise repositories** — remote mode is restricted to the Rise-4 GitHub organisation.
- **Configurable severity / confidence thresholds** — all findings are reported; filtering is the user's responsibility for now.
