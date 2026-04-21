---
name: az-purge-orphan-appregs
description: "DESTRUCTIVE. Reads the orphan scan report produced by /scan-orphan-appregs and permanently deletes the listed app registrations from Entra ID. Always shows a full deletion list and requires explicit confirmation before touching anything."
---

## Instructions

Delete orphaned Entra ID app registrations identified by a previous `/scan-orphan-appregs` run.

`$ARGUMENTS` is optional. If provided, treat it as the path to the scan JSON file. Default: `.claude/orphan-scan.json` relative to the repo root.

---

### Step 1 — Preflight

#### 1a — Verify az CLI

```powershell
az account show --query "{name:name, tenantId:tenantId, subscriptionId:id}" -o json
```

If this fails, halt:
```
az CLI is not authenticated. Run: az login
```

Print the active account name and tenant ID. The user must verify this matches the tenant they scanned.

#### 1b — Load scan file

Read the file at the path determined above. If it does not exist, halt:

```
Scan file not found: <path>
Run /scan-orphan-appregs first to generate it.
```

Parse the JSON. Extract:
- `scanned_at` — when the scan was run
- `tenant_id` — the tenant that was scanned
- `apps` — filtered to `classification: "confirmed_orphan"` or `classification: "likely_orphan"` only

Active apps are never included in deletion candidates.

#### 1c — Verify tenant match

Compare the `tenant_id` from the scan file against the `tenantId` returned by `az account show`.

If they do not match, halt with a hard error:

```
TENANT MISMATCH — ABORTING.
  Scan was performed against tenant: <scan tenant_id>
  Currently authenticated tenant:   <current tenantId>

Switch to the correct tenant before running this skill:
  az login --tenant <scan tenant_id>
```

This check is mandatory. Never proceed with a tenant mismatch.

#### 1d — Staleness warning

If `scanned_at` is more than 24 hours ago, print a warning (do not halt):

```
⚠ The scan file is <N> hours old (scanned at <scanned_at>).
  App registration state may have changed since the scan.
  Consider re-running /scan-orphan-appregs for an up-to-date picture.
```

---

### Step 2 — Display deletion list

If there are zero deletion candidates, print:

```
No orphans in scan file. Nothing to delete.
```

And exit cleanly.

Otherwise, print the full deletion list grouped by classification. Use clear formatting:

```
⚠ DESTRUCTIVE OPERATION — PERMANENT DELETION ⚠

The following Entra ID app registrations will be PERMANENTLY DELETED.
This cannot be undone.

Scan file:  .claude/orphan-scan.json
Scanned at: <scanned_at>
Tenant:     <tenant_id>

CONFIRMED ORPHANS (<N>) — will be deleted:
  1. risekyribabibearqa03
       App ID:  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
       Created: 2026-04-16
       Reason:  No service principal — cannot be used by any application or identity

  2. Rise4-EstateHub-9673eb47-1239-4edc-a725-dc80c55d1128
       App ID:  yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
       Created: 2025-03-25
       Reason:  Auto-generated name, expired credentials, no service principal

LIKELY ORPHANS (<N>) — will be deleted:
  3. risekyribabibearqa01
       App ID:  zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz
       Created: 2025-06-05
       Reason:  Expired credentials, last sign-in > 180 days ago

Total to delete: <N>
Active registrations in scan: <N> — these will NOT be touched.
```

---

### Step 3 — Confirmation gate

Use `AskUserQuestion` with the following question:

**Question**: "You are about to permanently delete <N> Entra ID app registrations from tenant <tenant_id>. This cannot be undone. Proceed?"

**Options**:
1. `Delete all <N> listed registrations` — proceeds with deletion
2. `Delete confirmed orphans only (<N>)` — skips likely orphans, deletes only confirmed ones
3. `Cancel — do not delete anything` — exits immediately

If the user selects Cancel, print:
```
Purge cancelled. No registrations were deleted.
```
And exit.

---

### Step 4 — Delete

Based on the user's choice, build the list of app IDs to delete (all orphans, or confirmed only).

For each app ID, run:

```powershell
az ad app delete --id <appId>
```

For each registration, print one of:
```
✓ Deleted: <name> (<appId>)
```
or:
```
✗ Failed:  <name> (<appId>)
  Error: <error message from az>
```

Continue through all registrations regardless of individual failures — do not abort on a single failure.

---

### Step 5 — Final report

```
Purge complete.

  Deleted:  <N>
  Failed:   <N>
  Skipped:  <N> (active — untouched)

<If any failures>:
  The following registrations could not be deleted:
    - <name> (<appId>): <reason>

  Retry manually:
    az ad app delete --id <appId>
```

If all deletions succeeded, also print:

```
You can safely delete the scan file:
  .claude/orphan-scan.json
```
