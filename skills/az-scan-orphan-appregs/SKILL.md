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

#### Classification logic

| Conditions | Classification |
|---|---|
| `sp_exists: false` | `confirmed_orphan` — nothing can authenticate with this registration |
| `sp_exists: true` AND `has_valid_creds: false` AND `guid_in_name: true` | `confirmed_orphan` — auto-generated, no usable credentials |
| `sp_exists: true` AND `has_valid_creds: false` AND `last_sign_in: null` | `likely_orphan` — no credentials, never signed in |
| `sp_exists: true` AND `has_valid_creds: false` AND `last_sign_in` older than 180 days | `likely_orphan` — credentials expired, inactive |
| `guid_in_name: true` AND `has_valid_creds: false` | `likely_orphan` — auto-generated name, no active credentials |
| `sp_exists: true` AND `has_valid_creds: true` AND `last_sign_in` within 180 days | `active` |
| Anything else not covered above | `likely_orphan` |

---

### Step 4 — Write report file

Write the results to `.claude/orphan-scan.json` relative to the repo root. Overwrite any previous scan.

The JSON structure must be:

```json
{
  "scanned_at": "<ISO 8601 timestamp>",
  "tenant_id": "<tenantId from preflight>",
  "subscription_id": "<subscriptionId from preflight>",
  "prefix_filter": "<prefix used>",
  "summary": {
    "total": 0,
    "confirmed_orphan": 0,
    "likely_orphan": 0,
    "active": 0
  },
  "apps": [
    {
      "name": "risekyribabibearqa03",
      "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "createdDateTime": "2026-04-16T10:00:00Z",
      "classification": "confirmed_orphan",
      "sp_exists": false,
      "has_valid_creds": false,
      "last_sign_in": null,
      "guid_in_name": false,
      "reason": "No service principal — cannot be used by any application or identity"
    }
  ]
}
```

Fill `reason` with a human-readable explanation matching the classification logic above.

---

### Step 5 — Print summary

Print a summary table grouped by classification:

```
Scan complete — <N> app registrations analysed.

CONFIRMED ORPHAN (<N>)
  risekyribabibearqa03          | no service principal
  Rise4-EstateHub-9673eb47-...  | auto-generated name, expired credentials

LIKELY ORPHAN (<N>)
  risekyribabibearqa01          | expired credentials, last sign-in > 180 days ago

ACTIVE (<N>)
  risekyribabibearqa04          | valid credentials, signed in recently

Report saved to: .claude/orphan-scan.json

Review the file, then run /purge-orphan-appregs to delete the orphans.
```

Do not delete anything. This skill is read-only.
