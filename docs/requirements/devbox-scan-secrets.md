# Platform Plugin — Evolution Requirements

## Vision

Add a `/devbox-scan-secrets` skill that audits a developer's machine for exposed secrets as part of a security hardening and clean-up process. Unlike `/security-scan` (which reviews code in a git repository), this skill targets the local filesystem — credential files, private keys, Azure configs, and tokens scattered across well-known dev-box locations. It produces a machine-readable CSV report for structured remediation tracking.

## Epics

### Epic 1: devbox-scan-secrets skill

**Goal**: Give a developer a fast, structured inventory of secrets remaining on their machine, so they can prioritise what to rotate or delete during a hardening exercise.

#### Requirements

- **REQ-1.1**: The skill is invoked as `/devbox-scan-secrets [path]`. The `path` argument is optional.
- **REQ-1.2**: Regardless of whether a path is provided, the skill always scans a fixed set of known high-risk locations: `%USERPROFILE%\.azure\`, `%USERPROFILE%\.ssh\`, `%USERPROFILE%\.aws\`, `%APPDATA%\`, and the root of `%USERPROFILE%` (non-recursive for the root level). These are scanned in addition to, not instead of, any user-provided path.
- **REQ-1.3**: If a path argument is given, that folder is scanned recursively in full, combined with the high-risk locations above.
- **REQ-1.4**: The skill detects the following secret categories:
  - **Azure / cloud credentials** — files matching `*-credentials-*.ps1`, `rise-env-*.env`, Terraform state files; patterns like `ARM_CLIENT_SECRET`, `ARM_CLIENT_ID`, `subscription_id` assigned to a value.
  - **Credential files** — `.env`, `.json`, `.yaml`, `.toml` files containing patterns for API keys, connection strings, tokens, or passwords assigned to a value.
  - **Private keys & certificates** — files with extensions `.pem`, `.pfx`, `.key`, `.p12`; files containing `BEGIN RSA PRIVATE KEY`, `BEGIN EC PRIVATE KEY`, `BEGIN OPENSSH PRIVATE KEY`.
  - **Tokens in scripts** — hardcoded token or password patterns inside `.ps1`, `.sh`, `.py`, `.ts`, `.js` files.
- **REQ-1.5**: The skill never reads or logs the full value of a secret. Partial values shown in output use the format `first4***last4`. If a value is shorter than 10 characters, show `[SHORT]` instead.
- **REQ-1.6**: The skill writes a CSV file to `.claude/secret-audit-<YYYY-MM-DD>.csv` in the current working directory. If a file with the same name already exists, it is overwritten. The CSV has these columns:

  | Column | Description |
  |---|---|
  | `severity` | Critical / High / Medium / Low |
  | `secret_type` | Human-readable category (e.g. "Azure Service Principal", "SSH Private Key", "API Token") |
  | `file_path` | Absolute path to the file containing the finding |
  | `line_number` | Line number of the match (blank if whole-file match, e.g. a `.pem` file) |
  | `pattern_matched` | The key name or pattern that triggered the match (e.g. `ARM_CLIENT_SECRET`, `BEGIN RSA PRIVATE KEY`) |
  | `partial_value` | Redacted value in `first4***last4` format, or `[SHORT]` / `[KEY FILE]` for non-string secrets |

- **REQ-1.7**: After writing the CSV, the skill prints a terminal summary grouped by severity, showing counts per secret type and the total. It also prints the full path of the saved CSV.
- **REQ-1.8**: The skill is strictly read-only. It never modifies, deletes, or moves any file.
- **REQ-1.9**: Before scanning, the skill announces which locations it will scan (high-risk dirs + any user-provided path) and the total number of files it will inspect, so the user can abort if the scope is unexpected.
- **REQ-1.10**: Binary files (`.exe`, `.dll`, `.zip`, image formats) are skipped entirely and noted in the summary as "N binary files skipped".

#### Decisions & Assumptions

- `.claude/secret-audit-<date>.csv` is consistent with where `/az-scan-orphan-appregs` saves its reports. If `.claude/` does not exist in the current directory, the skill creates it.
- Terraform state files (`.tfstate`) are classified as Critical because they frequently contain plaintext secrets even when other tooling considers them managed.
- The skill does not attempt to distinguish between secrets that are "intentionally stored" (e.g. the `rise-env-*.env` files the team deliberately uses) vs accidental leaks — that judgement is left to the human reviewing the CSV.
- `%APPDATA%` is scanned one level deep only (not fully recursive) to avoid excessive noise from application internals.

## Priorities

| Priority | Epic / Requirement | Rationale |
|---|---|---|
| 1 | REQ-1.2, REQ-1.3 — scope definition | Wrong scope = useless scan |
| 2 | REQ-1.4 — secret detection categories | Core value of the skill |
| 3 | REQ-1.6 — CSV output | Primary deliverable |
| 4 | REQ-1.5 — redaction | Security hygiene of the report itself |
| 5 | REQ-1.9 — preflight announcement | User trust and auditability |

## Out of Scope

- Remediation actions (deleting files, rotating keys) — the skill reports only.
- Integration with Linear or ticketing systems — deferred.
- Scanning remote machines or network shares.
- Git history scanning (already covered by `/security-scan`).
