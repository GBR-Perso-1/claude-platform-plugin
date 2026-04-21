---
name: az-query
description: "Read-only Azure lookups (app registrations, groups, Key Vault, resources) using natural language. Supports tenant-based credential files and optional naming conventions."
---

Read-only Azure query skill. Resolves natural language queries into `az` CLI commands. Supports a naming convention file if present, otherwise treats queries literally.

## Important rules

Read and follow the rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## When invoked without arguments

If `$ARGUMENTS` is empty, print usage and stop:

```
**Azure Query (read-only)**

Look up Azure resources using natural language.

Usage:
  /infra-azure-query <natural language query>

Examples:
  /infra-azure-query client id for myapp frontend app reg
  /infra-azure-query redirect urls for myapp backend
  /infra-azure-query list secrets in myapp key vault
  /infra-azure-query groups assigned to myapp backend app roles
  /infra-azure-query what is the url of the myapp api
  /infra-azure-query list all app registrations for myapp

Environment:
  Defaults to prod. Add "qa" or "in qa" to query the QA environment instead.
  e.g. /infra-azure-query client id for myapp frontend in qa
```

Then stop and wait.

## Step 0: Credential check

**This is the very first check — run it before parsing the query or doing anything else.**

1. Determine the target environment from the user's query (default: `prod`). Look for keywords like "qa", "in qa", "on qa" to switch to `qa`.
2. Discover credential files for the target environment:
   ```bash
   ls "$USERPROFILE/.azure/"*"-credentials-<env>.ps1" 2>/dev/null
   ```
3. **No files found** — stop immediately and tell the user:
   ```
   No credential file found for environment: <env>

   Create %USERPROFILE%\.azure\<tenant>-credentials-<env>.ps1 with:

   $env:ARM_CLIENT_ID = "<Azure_Client_ID>"
   $env:ARM_CLIENT_SECRET = "<Azure_Client_Secret>"
   $env:ARM_TENANT_ID = "<Azure_Tenant_ID>"
   $env:ARM_SUBSCRIPTION_ID = "<Azure_Subscription_ID>"

   Where <tenant> is a short name for the Azure tenant (e.g. "rise", "perso").
   ```
   Do NOT proceed.

4. **Exactly one file found** — use it automatically. Extract the tenant name from the filename (the part before `-credentials-<env>.ps1`) and store it as `<tenant>`. Announce: `Using tenant: <tenant>`

5. **Multiple files found** — list them and ask the user which tenant to use via `AskUserQuestion`. Wait for the answer before proceeding.
## Credential loading

Once the credential file is resolved, parse and authenticate:

1. Extract the values (replace `<resolved-file>` with the full path of the selected credential file):
   ```bash
   ARM_CLIENT_ID=$(grep 'ARM_CLIENT_ID' "<resolved-file>" | sed 's/.*= *"//' | sed 's/".*//')
   ARM_CLIENT_SECRET=$(grep 'ARM_CLIENT_SECRET' "<resolved-file>" | sed 's/.*= *"//' | sed 's/".*//')
   ARM_TENANT_ID=$(grep 'ARM_TENANT_ID' "<resolved-file>" | sed 's/.*= *"//' | sed 's/".*//')
   ARM_SUBSCRIPTION_ID=$(grep 'ARM_SUBSCRIPTION_ID' "<resolved-file>" | sed 's/.*= *"//' | sed 's/".*//')
   ```
2. Log in with the service principal:
   ```bash
   az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" --output none 2>&1
   ```
   If login fails, show the error and stop.
3. Set the subscription:
   ```bash
   az account set --subscription "$ARM_SUBSCRIPTION_ID" 2>&1
   ```

## Naming convention

**Before processing any query**, check if a naming convention file exists at `${CLAUDE_PLUGIN_ROOT}/rules/infra-naming.md`.

- **If it exists**: read it in full (ignore the `paths:` frontmatter). Use it as the source of truth for constructing Azure resource names from natural language. Apply it dynamically — strip hyphens, lowercase everything, and assemble names using the format, purpose codes, and resource type codes defined in the file. Default index is `01`.
- **If it does not exist**: treat the user's query more literally. Attempt to resolve the resource name directly from the words given. If the name is ambiguous or unclear, ask the user to provide the exact Azure resource name.

If the user's query is ambiguous (could map to multiple resource types), ask them to clarify using `AskUserQuestion`.

## Query handling

Parse the user's natural language query to determine:
1. **What resource** — app registration, key vault, group, app service, etc.
2. **What project** — justifi, estateops, etc.
3. **What purpose** — frontend, backend, MCP, service client (if applicable)
4. **What info** — client ID, redirect URLs, secret names, group membership, etc.
5. **What environment** — prod (default) or qa

Then run the appropriate `az` commands. Below are the common patterns.

### App Registration lookups

**Find by display name:**
```bash
az ad app list --display-name "<resolved_name>" --query "[0]" -o json 2>&1
```

**Get specific fields:**
```bash
# Client ID and basic info
az ad app list --display-name "<resolved_name>" --query "[0].{displayName:displayName, clientId:appId, objectId:id, signInAudience:signInAudience}" -o table 2>&1

# Redirect URIs (SPA)
az ad app list --display-name "<resolved_name>" --query "[0].spa.redirectUris" -o json 2>&1

# Redirect URIs (Web)
az ad app list --display-name "<resolved_name>" --query "[0].web.redirectUris" -o json 2>&1

# API permissions / required resource access
az ad app list --display-name "<resolved_name>" --query "[0].requiredResourceAccess" -o json 2>&1

# Identifier URIs
az ad app list --display-name "<resolved_name>" --query "[0].identifierUris" -o json 2>&1

# App roles
az ad app list --display-name "<resolved_name>" --query "[0].appRoles" -o table 2>&1

# Full dump (when user asks for "everything" or "all info")
az ad app list --display-name "<resolved_name>" --query "[0]" -o json 2>&1
```

**List all app registrations for a project:**
```bash
az ad app list --filter "startswith(displayName, '<resolved-prefix>')" --query "[].{displayName:displayName, clientId:appId}" -o table 2>&1
```
Where `<resolved-prefix>` is the resolved name prefix for the project (e.g. from the naming convention file, or the project name the user provided directly).

### Key Vault lookups

**List secret names (not values — never show values):**
```bash
az keyvault secret list --vault-name "<resolved_name>" --query "[].{name:name, enabled:attributes.enabled, expires:attributes.expires}" -o table 2>&1
```

**NEVER retrieve secret values.** If the user asks for a secret value, refuse and explain this is a read-only lookup skill that does not expose secret values for security reasons.

### Group lookups

**List groups assigned to an app's roles:**
```bash
# First get the service principal object ID from the app's client ID
SP_OBJECT_ID=$(az ad sp list --filter "displayName eq '<resolved_app_reg_name>'" --query "[0].id" -o tsv 2>&1)

# Then list app role assignments
az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/appRoleAssignedTo" --query "value[].{principalDisplayName:principalDisplayName, principalType:principalType, appRoleId:appRoleId}" -o table 2>&1
```

**Search for a group by name:**
```bash
az ad group list --filter "startswith(displayName, '<search_term>')" --query "[].{displayName:displayName, objectId:id, description:description}" -o table 2>&1
```

**List group members:**
```bash
az ad group member list --group "<group_name_or_id>" --query "[].{displayName:displayName, userPrincipalName:userPrincipalName, objectId:id}" -o table 2>&1
```

### App Service / Static Web App lookups

**Get app service URL:**
```bash
az webapp show --name "<resolved_name>" --resource-group "<resolved_rg_name>" --query "{name:name, defaultHostName:defaultHostName, state:state, httpsOnly:httpsOnly}" -o table 2>&1
```

**Get static web app URL:**
```bash
az staticwebapp show --name "<resolved_name>" --resource-group "<resolved_rg_name>" --query "{name:name, defaultHostname:defaultHostname, customDomains:customDomains}" -o table 2>&1
```

### General resource lookups

If the query does not match a specific pattern above, try a general resource lookup:
```bash
az resource list --resource-group "<resolved_rg_name>" --query "[].{name:name, type:type, location:location}" -o table 2>&1
```

## Output

- Print results directly to console in a clean, readable format.
- Use tables where appropriate (az already formats with `-o table`).
- For single values (like a client ID), print it on its own line so it's easy to copy.
- Always show the resolved Azure resource name so the user can verify the mapping.
- If a resource is not found, say so clearly and suggest the user check the project name / purpose / environment.

**Output format:**

```
Azure Query — <ENV>
Resource: <resolved_name>

<results>
```

## Guardrails

- **Read-only.** This skill NEVER creates, updates, or deletes any Azure resource. It only reads.
- **Never show secret values.** Only list secret names, expiry dates, and enabled status.
- **Never modify app registrations** — no creating secrets, no changing redirect URIs, no updating permissions.
- **Never run destructive commands** — no `az ad app delete`, no `az keyvault secret purge`, nothing that mutates state.
- **Always log out after the query** — do NOT leave the service principal session active. Run `az logout --output none 2>&1` at the end. This is critical to avoid polluting the user's `az` session.
- **If a command fails**, show the error and suggest what might be wrong (wrong project name, missing permissions, resource doesn't exist in this environment).
- **If the query is ambiguous**, ask the user to clarify rather than guessing. Use `AskUserQuestion` with options when there are a small number of possibilities.
