---
paths:
  - "**/infra/*.tf"
  - "**/infra/*.tfvars"
  - "**/infra/**/*.tf"
  - "**/infra/**/*.tfvars"
---

# Azure Resource Naming Convention

**This is mandatory.** Every Azure resource name MUST follow this convention. No exceptions.

## Format

```
<prefix><project><purpose><resourceType><environment><uniqueIdentifier>
```

All names are **lowercase**, no hyphens, no underscores.

## Prefix

The prefix identifies the **organisation or context** that owns the resources — it is not related to the Azure tenant or subscription. It is defined per project.

**How to determine the prefix:**
1. Check `project-context.md` (or `.claude/project-context.md`) for a `naming_prefix` or `prefix` field.
2. If not defined there, check if existing resources in the codebase (`.tf`, `.tfvars`) establish a consistent prefix.
3. If still unknown, ask the user before creating or naming any resource.

Common values: `rise` (Rise Applications), `ekla` (personal/ekla projects). Any short lowercase string is valid.

**Never assume the prefix.** If you are unsure, ask.

## Components

| Component          | Description                         | Constraint                                                    |
| ------------------ | ----------------------------------- | ------------------------------------------------------------- |
| `<prefix>`         | Organisation/context identifier     | Determined per project (see above)                            |
| `project`          | Project name                        | 12-char max                                                   |
| `purpose`          | Optional specificity qualifier      | `project` + `purpose` combined ≤ 12 chars                     |
| `resourceType`     | Shorthand code from the table below | Must exist in the table                                       |
| `environment`      | Environment                         | `dev`, `qa`, `prod`                                           |
| `uniqueIdentifier` | Two-digit sequential number         | e.g. `01`, `02`                                               |

### Purpose values

| Code  | Meaning                                                                                                 |
| ----- | ------------------------------------------------------------------------------------------------------- |
| `fe`  | Frontend                                                                                                |
| `be`  | Backend                                                                                                 |
| `mcp` | MCP server                                                                                              |
| `sc`  | Service client (standalone identity — not tied to a specific fe/be, acts as its own security principal) |

Omit `purpose` when not needed.

### Shared services

For common/shared services, use project name `share` → e.g. `<prefix>sharergprod01`.

## Resource Type Shorthand Codes

| Resource                       | Code    |
| ------------------------------ | ------- |
| Resource Group                 | `rg`    |
| App Service                    | `api`   |
| Static Web App                 | `app`   |
| Database                       | `db`    |
| Database Server                | `dbsrv` |
| Function App                   | `fa`    |
| Service Plan                   | `sp`    |
| Storage Account                | `sa`    |
| Application Insight            | `ai`    |
| Application Registration       | `ar`    |
| Key Vault                      | `kv`    |
| Container Registry             | `cr`    |
| User-Assigned Managed Identity | `id`    |
| Container Apps Environment     | `caenv` |
| Container App                  | `ca`    |

## Examples

Using prefix `rise`:
- Resource Group: `risesandboxrgprod01`
- App Registration (Frontend): `risesandboxfearprod01`
- App Registration (Backend): `risesandboxbearprod01`
- Service Client (n8n): `risen8nscarprod01`

Using prefix `ekla`:
- Resource Group: `eklasandboxrgprod01`
- App Registration (Frontend): `eklasandboxfearprod01`

## When a resource type is missing

**If the Azure resource you are creating does not have a shorthand code in the table above, you MUST stop and tell the user.** Do not invent a code. Ask the user to define one following these rules:

- 2–6 characters, clearly representing the resource (e.g. `eh` for Event Hub, `cosmos` for Cosmos DB)
- Must be unique within the table
- Must be easy to understand

Once agreed, the user will update this convention.
