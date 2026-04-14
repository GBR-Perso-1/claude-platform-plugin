# Security Scan — Architecture Plan

**Status**: Approved pending user confirmation
**Requirements**: `docs/requirements/security-scan.md`

---

## Overview

The `/security-scan` skill follows the same parallel-agent orchestration pattern established by `/app-implement`. It introduces one new skill (`skills/security-scan/SKILL.md`) and three new specialised read-only agent definitions (`agents/scanner-secrets.md`, `agents/scanner-injection.md`, `agents/scanner-exposure.md`). The skill parses depth and target arguments, handles local vs remote mode (including `gh` clone for remote repos), spawns the three scanner agents in parallel, then merges and presents a single unified report. No changes to plugin infrastructure are required — new files slot directly into the existing `skills/` and `agents/` directories and the plugin auto-discovers them.

---

## Finding Schema (Convention)

Used in agent output text to exchange structured results between agents and the orchestrating skill.

Fields: `agent`, `severity`, `confidence`, `file`, `line`, `title`, `description`, `impact`, `fix`.

---

## File Changes

### Step 1: `agents/scanner-secrets.md`

New read-only agent.
- Frontmatter: `name: scanner-secrets`, `tools: Glob, Grep, Read, Bash`, `model: sonnet`, `color: red`
- Scans for committed secrets (API keys, connection strings, tokens, private keys, passwords)
- Deep mode only: git history via `git grep` across all commits
- Redacts all secret values (first 4 + `***` + last 4 for values > 8 chars; `[REDACTED]` otherwise)

**Phases**:
1. Resolve scope — `git ls-files` for tracked repos, `Glob` with manual exclusions (`node_modules`, `bin`, `obj`, `dist`, `.git`) as fallback
2. Pattern scanning (both modes):
   - Generic: `password`, `passwd`, `secret`, `api_key`, `apikey`, `private_key`, `access_token`, `auth_token`, `bearer`
   - Format-specific: AWS access key `AKIA[0-9A-Z]{16}`, connection string keywords (`Server=`, `Data Source=`, `AccountKey=`), PEM headers
   - Terraform/config: variables set directly (not via `var.`), `.env` files with real values
   - Surface: highest-signal patterns only, skip binary files
   - Deep: all patterns + broader heuristics + binary inspection
3. Git history scan (deep only): `git grep` across `git log --all` commits; flag secrets in history but removed from HEAD
4. Redaction rule applied before any finding is emitted
5. Report findings in standard format block

### Step 2: `agents/scanner-injection.md`

New read-only agent.
- Frontmatter: `name: scanner-injection`, `tools: Glob, Grep, Read, Bash`, `model: sonnet`, `color: orange`

**Phases**:
1. Resolve scope (same as secrets agent)
2. Pattern scanning:
   - SQL injection: raw string concatenation into SQL, `string.Format` with SQL keywords, `+` operator adjacent to SQL keywords
   - Command injection: `subprocess.run`, `os.system`, `exec(`, `Process.Start` with user-controlled strings; `shell=True` in Python
   - XSS: `innerHTML =`, `v-html`, `dangerouslySetInnerHTML`, `.html(` with non-static values; missing `@Html.Encode` in Razor
   - LDAP/XML/Path injection: path traversal (`../`, `..\\`), `XmlDocument.Load` with user input
   - Surface: highest-risk patterns in controllers/API handlers/DB access files
   - Deep: data flow tracing from input entry points through to sinks, full call chain reporting
3. Report findings

### Step 3: `agents/scanner-exposure.md`

New read-only agent.
- Frontmatter: `name: scanner-exposure`, `tools: Glob, Grep, Read, Bash`, `model: sonnet`, `color: magenta`

**Phases**:
1. Resolve scope and identify context boundaries — examine build configs (`vite.config.ts`, `webpack.config.js`, `.env`, `.env.production`), API response DTOs, frontend import chains
2. Exposure pattern scanning:
   - Client-side bundle leaks: `import.meta.env.VITE_` keys with secret names, `process.env` in browser bundles
   - API over-exposure: DTO fields exposing internal IDs, hashed passwords, PII
   - Config shipped to frontend: `appsettings.json` values surfaced via BFF without filtering
   - CORS misconfiguration: wildcard `*` on authenticated endpoints
   - Debug/dev flags in production configs: `OfflineAuthBypass`, verbose error details
   - Surface: obvious exposures only
   - Deep: DTO composition chain tracing, CI/CD workflow file secret echoes, build artefact inspection
3. Report findings

### Step 4: `skills/security-scan/SKILL.md`

Main orchestrating skill.

**Frontmatter**:
```yaml
---
name: security-scan
description: Scan a Rise repository for secrets, injection vulnerabilities, and exposure risks. Produces a read-only unified security report.
---
```

**Arguments**:
```
/security-scan [depth] [target]

depth:   "surface" (default) | "deep"
target:  omitted (current directory) | path/to/folder | org/repo-name (remote)
```

Parsing rules:
- Empty: `surface` + current directory
- First token is `surface`/`deep`: that's depth, rest is target
- Otherwise: `surface`, all tokens = target
- Target matching `[a-z0-9_-]+--[a-z0-9_-]+` or `org/repo`: remote mode
- Otherwise: local mode

**Phase 0 — Preflight**:
1. Echo parsed args to user
2. Local mode: verify target exists
3. Remote mode: verify `gh --version`, verify `gh auth status`, enforce Rise-4 org prefix, `gh repo clone Rise-4/<name> /tmp/security-scan-<name>-<timestamp>`
4. Detect tech stacks for agent hints

**Phase 1 — Parallel scan**:
5. Spawn all three scanner agents in parallel with scan root, depth, stack hint
6. Wait for all three, collect structured result blocks

**Phase 2 — Merge and report**:
7. Collect all findings
8. Dedupe by file + line (keep higher severity, note both agent sources)
9. Sort: severity (Critical → High → Medium → Low), then confidence (high → medium → low)
10. Render unified report inline

**Phase 3 — Cleanup** (remote only):
11. `rm -rf /tmp/security-scan-<name>-<timestamp>`

**Report Format**:

```markdown
# Security Scan Report

**Target**: <path or repo name>
**Mode**: Surface / Deep
**Scanned**: <timestamp>
**Agents**: Secrets, Injection, Exposure

## Summary

| Severity | Count |
|----------|-------|
| Critical | {n} |
| High     | {n} |
| Medium   | {n} |
| Low      | {n} |

**Total findings**: {n}
**Overall risk**: Critical / High / Medium / Low / Clean

## Findings

### Critical
| # | Agent | File | Line | Title | Confidence | Impact | Fix |

### High
### Medium
### Low

## Agent Coverage

| Agent    | Files Scanned | Findings | Status |

## Notes

- Secret values are redacted.
- Confidence indicators: High / Medium / Low.
- Diagnostic only — no code modified.
```

**Guardrails**:
- Never modify source files
- Never commit, push, or stage
- Never echo unredacted secret values
- Remote scan only for Rise-4 org repos

---

## Implementation Order

1. `agents/scanner-secrets.md` — establishes canonical finding format
2. `agents/scanner-injection.md` — follows established pattern
3. `agents/scanner-exposure.md` — follows established pattern
4. `skills/security-scan/SKILL.md` — orchestrator references all three agents

---

## Test Strategy

**Skill invocation**:
- `/security-scan` (no args) → surface, cwd
- `/security-scan deep` → deep, cwd
- `/security-scan fi--castellan` → remote clone + scan + cleanup
- Non-Rise-4 repo → refusal with message
- Missing path → early exit
- No `gh` CLI → graceful stop

**Agent behaviour** (seeded test directory):
- Fake AWS key in `.env`
- Raw SQL concatenation in C#
- `v-html` with bound variable in Vue
- `vite.config.ts` exposing `SECRET_KEY`
- Surface scan: verify all three agents find their respective issues; secrets are redacted
- Deep scan with git history containing removed secret: verify historical finding

**Report format**:
- Critical sorted before lower severities
- Dedupe keeps higher-severity entry with both agent sources noted
- Redaction works for 8-char and 4-char secrets

**Guardrails**:
- Uncommitted changes unaffected by scan
- Temp dir removed after remote scan

---

## Design Decisions

- **Three separate agents**: matches `/app-implement` pattern; enables parallel execution and independent iteration
- **Native Claude tools only** (`Grep`, `Read`, `Bash`): no external dependencies like trufflehog/semgrep
- **`git ls-files` for scope**: reliable `.gitignore` respect
- **Schema via prompt instructions**: no shared schema file for markdown-only plugin
- **Hardcoded Rise-4 prefix**: prevents accidental arbitrary repo scans
- **Dedupe by file+line**: simple deterministic key, preserves agent traceability
- **Colour assignments**: red (secrets, highest risk), orange (injection), magenta (exposure)

---

## Risks & Open Questions

- **Grep result volume in deep mode**: agent instructions include truncation/batching strategy
- **Git history on large repos**: use targeted `git grep` across `git log --all` commits, not `git log -p`
- **`gh` auth scope**: preflight notes required `repo` read scope
- **Parallel agent spawning**: verified pattern from `/app-implement`; sequential fallback documented
- **Injection false positives**: confidence downgraded to `low` for test files and docs
- **Exposure stack detection**: agent documents what it could not determine about context boundaries
- **Version bump**: after merge, run `/eng-plugin-commit` to bump version (required for consumer access)
