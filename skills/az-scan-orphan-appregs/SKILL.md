---
name: az-scan-orphan-appregs
description: Scan an Azure tenant for potentially orphaned Entra ID app registrations. Classifies each app as Confirmed orphan, Likely orphan, or Active, then writes a JSON report to .claude/orphan-scan.json for review or deletion via /purge-orphan-appregs.
---

## Instructions

Scan the current Azure tenant for orphaned app registrations and write a report file.

`$ARGUMENTS` is optional. If provided, use it as the display-name prefix filter. Default: `rise`.

---

### Step 1 — Preflight

Verify az CLI is available and authenticated:

```powershell
az account show --query "{name:name, tenantId:tenantId, subscriptionId:id}" -o json
```

If this fails, halt:
```
az CLI is not authenticated. Run: az login
```

Print the active account name, tenant ID, and subscription ID so the user can confirm they are in the correct tenant before proceeding.

---

### Step 2 — List app registrations

Determine the prefix: use `$ARGUMENTS` if non-empty, otherwise `rise`.

```powershell
az ad app list --filter "startswith(displayName,'<prefix>')" `
  --query "[].{name:displayName, appId:appId, createdDateTime:createdDateTime}" `
  -o json
```

If the result is empty, report:
```
No app registrations found with prefix '<prefix>'. Nothing to scan.
```
And exit cleanly.

Print: `Found <N> app registrations to analyse.`

---

### Step 3 — Classify each app registration

For each app registration, run the following checks. Process them one at a time (do not parallelise — az CLI rate limits apply).

#### Check A — Service principal existence

```powershell
az ad sp show --id <appId> -o json 2>&1
```

- **Exit code non-zero / "does not exist"** → no service principal. Mark `sp_exists: false`.
- **Success** → parse `signInActivity.lastSignInDateTime` if present. Mark `sp_exists: true`, `last_sign_in: <value or null>`.

#### Check B — Valid credentials

```powershell
az ad app credential list --id <appId> -o json
```

- Parse the list. For each credential, check `endDateTime` against today's date.
- If the list is empty OR all credentials are expired → `has_valid_creds: false`.
- If at least one credential has a future `endDateTime` → `has_valid_creds: true`.

#### Check C — GUID in display name

Check whether the display name matches the pattern: contains a segment that looks like a UUID (8-4-4-4-12 hex characters, e.g. `Rise4-EstateHub-9673eb47-1239-4edc-a725-dc80c55d1128`).

- `guid_in_name: true` if a UUID-shaped segment is found in the name.
- `guid_in_name: false` otherwise.

#### Check D — QA environment suffix

Check whether the display name ends with `qa` followed by one or more digits (case-insensitive), e.g. `qa01`, `qa02`, `qa03`.

- `qa_suffix: true` if the name matches `.*qa\d+$` (case-insensitive).
- `qa_suffix: false` otherwise.

These registrations are provisioned by Terraform as part of QA environment scaffolding. They may have no credentials or sign-in history yet still be legitimate — a human must review them before any deletion.

#### Classification logic

> **Note on `signInActivity`:** `az ad sp show` only returns `signInActivity` on tenants with Entra ID P1/P2 and sufficient audit-log permissions. When unavailable, `last_sign_in` is `null` for all apps — this means "data not available", not "never used". Valid credentials are the primary signal of active use; absent sign-in data must not be treated as evidence of inactivity.

Evaluate rules in order — first match wins.

| Conditions | Classification |
|---|---|
| `sp_exists: false` AND `qa_suffix: false` | `confirmed_orphan` — nothing can authenticate with this registration |
| `sp_exists: true` AND `has_valid_creds: false` AND `guid_in_name: true` AND `qa_suffix: false` | `confirmed_orphan` — auto-generated name, no usable credentials |
| `sp_exists: true` AND `has_valid_creds: true` | `active` — live credentials indicate intentional use; sign-in data may be unavailable |
| `sp_exists: true` AND `has_valid_creds: true` AND `last_sign_in` within 180 days | `active` — valid credentials, recently used |
| `qa_suffix: true` | `unlikely_orphan` — Terraform-managed QA environment; legitimate even without credentials or sign-in history |
| `sp_exists: true` AND `has_valid_creds: false` AND `last_sign_in` older than 180 days | `likely_orphan` — credentials expired and confirmed inactive |
| `sp_exists: true` AND `has_valid_creds: false` AND `last_sign_in: null` | `likely_orphan` — no credentials and no sign-in history |
| Anything else not covered above | `likely_orphan` |

---

### Step 4 — Write report files

Write two files to `.claude/` relative to the repo root. Overwrite any previous scan.

Each app entry uses this structure:

```json
{
  "name": "risekyribabibearqa03",
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "createdDateTime": "2026-04-16T10:00:00Z",
  "classification": "confirmed_orphan",
  "sp_exists": false,
  "has_valid_creds": false,
  "last_sign_in": null,
  "guid_in_name": false,
  "qa_suffix": false,
  "reason": "No service principal — cannot be used by any application or identity"
}
```

Fill `reason` with a human-readable explanation matching the classification logic above.

#### File 1 — `.claude/orphan-scan-confirmed.json` (confirmed orphans — input for purge skill)

Contains only `confirmed_orphan` apps. The user may also move entries from the review file into this file before running the purge skill.

```json
{
  "scanned_at": "<ISO 8601 timestamp>",
  "tenant_id": "<tenantId from preflight>",
  "subscription_id": "<subscriptionId from preflight>",
  "prefix_filter": "<prefix used>",
  "note": "These registrations are confirmed orphans. You may also move entries from orphan-scan-review.json into this file. Run /purge-orphan-appregs to delete.",
  "summary": {
    "total": 0,
    "confirmed_orphan": 0
  },
  "apps": [ ]
}
```

#### File 2 — `.claude/orphan-scan-review.json` (needs human review)

Contains only `likely_orphan` and `unlikely_orphan` apps, sorted so `unlikely_orphan` entries appear first.

```json
{
  "scanned_at": "<ISO 8601 timestamp>",
  "tenant_id": "<tenantId from preflight>",
  "subscription_id": "<subscriptionId from preflight>",
  "prefix_filter": "<prefix used>",
  "note": "Review these registrations. Move any confirmed orphans into orphan-scan-confirmed.json, then run /purge-orphan-appregs. unlikely_orphan entries are Terraform-managed QA environments and are probably legitimate.",
  "summary": {
    "total": 0,
    "likely_orphan": 0,
    "unlikely_orphan": 0
  },
  "apps": [ ]
}
```

---

### Step 5 — Print summary

Print a summary table grouped by classification:

```
Scan complete — <N> app registrations analysed.

CONFIRMED ORPHAN (<N>)
  risekyribabibearqa03               | no service principal
  Rise4-EstateHub-9673eb47-...       | auto-generated name, no usable credentials

LIKELY ORPHAN (<N>)
  riseestatehubbeardev09             | no credentials and no sign-in history

UNLIKELY ORPHAN (<N>) — Terraform QA environments, probably legitimate
  riseairfarebearqa01                | QA suffix, no credentials — likely Terraform-managed
  riseestatehubbearqa01              | QA suffix, no credentials — likely Terraform-managed

ACTIVE (<N>)
  riseappdevbeappregdev01            | valid credentials

Reports saved to:
  .claude/orphan-scan-confirmed.json (confirmed orphans — input for /purge-orphan-appregs)
  .claude/orphan-scan-review.json    (likely + unlikely orphans — needs review)

Next steps:
  1. Review orphan-scan-review.json and move any additional orphans into orphan-scan-confirmed.json.
  2. Run /purge-orphan-appregs to delete everything in orphan-scan-confirmed.json.
```

Do not delete anything. This skill is read-only.
