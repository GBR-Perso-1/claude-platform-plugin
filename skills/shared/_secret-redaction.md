---
name: _secret-redaction
description: "Canonical secret redaction rules for all scanner artefacts. Defines partial-value display format and the absolute prohibition on logging full secret values."
---

# Secret Redaction Rules

All scanner artefacts must apply these rules without exception. Never log, print, or write a full secret value to any output, file, terminal message, or error.

## Redaction Variants

Two variants exist, each used by a different scanner family. Choose the one appropriate to your artefact.

### Variant A — Repository scanner (used by `scanner-secrets`)

| Condition | Display |
|---|---|
| Value length > 8 characters | `first4***last4` (first 4 chars + literal `***` + last 4 chars) |
| Value length ≤ 8 characters | `[REDACTED]` |
| Non-string secret (key file, PEM block, cert binary) | `[KEY FILE]` |

### Variant B — Dev-box scanner (used by `scanner-devbox` and `devbox-scan-secrets`)

| Condition | Display |
|---|---|
| Value length ≥ 10 characters | `first4***last4` (first 4 chars + literal `***` + last 4 chars) |
| Value length < 10 characters | `[SHORT]` |
| Non-string secret (key file, PEM block, cert binary) | `[KEY FILE]` |

## Worked Examples

| Input value | Variant A result | Variant B result |
|---|---|---|
| `abcdefghij` (10 chars) | `abcd***ghij` | `abcd***ghij` |
| `abc123` (6 chars) | `[REDACTED]` | `[SHORT]` |
| `~/.ssh/id_rsa` (whole file) | `[KEY FILE]` | `[KEY FILE]` |
| `-----BEGIN RSA PRIVATE KEY-----` (PEM header match) | `[KEY FILE]` | `[KEY FILE]` |

## Absolute Prohibition

- Never include a raw secret value in any CSV field, terminal print, error message, or log entry.
- If the value cannot be safely redacted (e.g. the extraction regex failed to isolate the value portion), write `[UNEXTRACTED]` rather than the raw match.
