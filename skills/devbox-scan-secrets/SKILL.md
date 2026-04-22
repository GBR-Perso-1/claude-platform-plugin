---
name: devbox-scan-secrets
description: "Audit the local dev machine for exposed secrets — credential files, private keys, Azure configs, and hardcoded tokens. Writes a CSV report to .claude/secret-audit-<date>.csv."
---

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Guardrails

- Never modify, delete, move, or rename any file.
- Never commit, stage, or push anything.
- Never print a full secret value. Verify agent output has applied Variant B redaction from `${CLAUDE_PLUGIN_ROOT}/skills/shared/_secret-redaction.md` before writing any CSV row.

## Arguments

```
/devbox-scan-secrets [path]
```

`$ARGUMENTS` is optional. If provided, it is an additional directory path to scan recursively. If empty, only the fixed high-risk locations are scanned.

---

### Phase 0 — Resolve scan scope

#### Step 0.1 — Resolve environment variables

Resolve `USERPROFILE` and `APPDATA` from the environment:

```bash
echo "$USERPROFILE"
echo "$APPDATA"
```

On Windows these are always set. If either is absent, skip that path and note the omission in the preflight output.

#### Step 0.2 — Build location list

Assemble the fixed high-risk locations:

| Path | Depth |
|------|-------|
| `$USERPROFILE/.azure/` | recursive |
| `$USERPROFILE/.ssh/` | recursive |
| `$USERPROFILE/.aws/` | recursive |
| `$APPDATA/` | shallow (top level only) |
| `$USERPROFILE/` root | shallow (files at root level only, no subdirectories) |

If `$ARGUMENTS` is non-empty:
- Validate the path exists. If it does not, stop:
  ```
  Path not found: <path>
  Provide a valid path or omit the argument to scan only the default high-risk locations.
  ```
- Append it to the location list with depth `recursive`.

#### Step 0.3 — Count files

Enumerate files across all locations respecting depth constraints. Count:
- Total files found
- Binary files (will be skipped by the agent)
- Scan-eligible files (total minus binary)

---

### Phase 1 — Preflight announcement

Print the scope table:

```
Secret Audit — Scope
──────────────────────────────────────────────
Fixed high-risk locations:
  $USERPROFILE/.azure/        (recursive)
  $USERPROFILE/.ssh/          (recursive)
  $USERPROFILE/.aws/          (recursive)
  $APPDATA/                   (one level deep)
  $USERPROFILE/ root          (non-recursive)

[If user path provided:]
  <path>                      (recursive)

Total files to inspect: <N>
Binary files (will be skipped): <B>
──────────────────────────────────────────────
```

Then use `AskUserQuestion`:

**Question**: "Proceed with the secret audit?"

Options:
1. `Proceed with scan` (Recommended)
2. `Cancel — abort scan`

If Cancel: print `Scan aborted. No files were read or written.` and stop.

---

### Phase 2 — Spawn scanner agent

Spawn `${CLAUDE_PLUGIN_ROOT}/agents/scanner-devbox.md`, passing:

```json
SCAN_PATHS: [ "<list of resolved absolute paths>" ]
DEPTH_CONSTRAINTS: { "<path>": "recursive|shallow", ... }
```

Wait for the agent to complete. Parse the `SCANNER_DEVBOX_OUTPUT_START … SCANNER_DEVBOX_OUTPUT_END` block from the agent's output.

---

### Phase 3 — Write CSV report

Determine today's date (`YYYY-MM-DD`). Compute the output path:

```
<cwd>/.claude/secret-audit-<YYYY-MM-DD>.csv
```

Create `.claude/` if it does not exist. Overwrite the file if it already exists.

Write the CSV header row:

```
severity,secret_type,file_path,line_number,pattern_matched,partial_value
```

For each finding from the agent output, write one CSV row. Quote all values. Use forward slashes in file paths.

Sort rows: Critical first, then High, Medium, Low.

Print: `Report written to: <absolute path>`

---

### Phase 4 — Terminal summary

Print a summary grouped by severity:

```
Secret Audit Summary — <YYYY-MM-DD>
──────────────────────────────────────────────
CRITICAL (<N>)
  <secret_type>       <count>

HIGH (<N>)
  <secret_type>       <count>

MEDIUM (<N>)
  <secret_type>       <count>

LOW (<N>)
  <secret_type>       <count>

──────────────────────────────────────────────
Total findings:        <N>
Files scanned:         <F>
Binary files skipped:  <B>

Report saved to: <absolute path>
```

If zero findings:

```
No secrets detected across <F> files scanned.
Binary files skipped: <B>

Report saved to: <absolute path>
```
