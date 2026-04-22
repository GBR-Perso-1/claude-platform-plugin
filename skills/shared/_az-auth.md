# Azure Authentication

Include this section in any skill that needs `az` CLI access. Run it as the very first step before any other az command.

---

## Step 1 — Check current session

```bash
az account show --query "{name:name, tenantId:tenantId, subscriptionId:id, user:user.name}" -o json 2>/dev/null
```

**Success** — print the active context and require explicit confirmation before proceeding:

```
Currently connected to:
  Tenant:       <tenantId>
  Subscription: <name> (<subscriptionId>)
  User:         <user>

Confirm this is the correct tenant before continuing.
```

Use `AskUserQuestion`:
- `Yes — proceed on this tenant` → skip to done — proceed with the current az session
- `No — switch tenant` → continue to Step 2

Do NOT proceed until the user explicitly confirms. Never assume the active session is correct.

**Failure** (not logged in) → continue to Step 2 without prompting.

---

## Step 2 — Select target environment

Discover env files:

```bash
ls "$USERPROFILE/.azure/rise-env-"*.env 2>/dev/null
```

- **One file found** — announce it and ask the user to confirm via `AskUserQuestion`:
  ```
  Found environment file: rise-env-<name>.env
  Connect to this tenant?
  ```
  Options: `Yes — connect` / `Cancel`.
- **Multiple files found** — extract the label (the part between `rise-env-` and `.env`) from each filename, then ask the user which one to use via `AskUserQuestion`. Wait for the answer before continuing.
- **No files found** — stop and tell the user:
  ```
  Not connected to Azure and no environment file found.

  Create %USERPROFILE%\.azure\rise-env-<name>.env with:

    ARM_SUBSCRIPTION_ID=<Azure_Subscription_ID>
    ARM_TENANT_ID=<Azure_Tenant_ID>

  Where <name> is a short label for the tenant (e.g. "rise", "perso").
  Then re-run this skill.
  ```

---

## Step 3 — Login

Parse the selected `.env` file:

```bash
ARM_TENANT_ID=$(grep 'ARM_TENANT_ID' "<file>" | cut -d= -f2 | tr -d '[:space:]')
ARM_SUBSCRIPTION_ID=$(grep 'ARM_SUBSCRIPTION_ID' "<file>" | cut -d= -f2 | tr -d '[:space:]')
```

Run interactive login (no secret stored on disk — MFA/browser flow):

```bash
az login --tenant "$ARM_TENANT_ID" --output none 2>&1
az account set --subscription "$ARM_SUBSCRIPTION_ID" 2>&1
```

If either command fails, show the error and stop. Do NOT proceed.

Announce:

```
Connected to:
  Tenant:       <ARM_TENANT_ID>
  Subscription: <ARM_SUBSCRIPTION_ID>
```
