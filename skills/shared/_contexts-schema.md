## Contexts Manifest — Schema Reference

This document is the **source of truth** for the `contexts.json` manifest format. All skills and shared docs in this plugin ecosystem that reference the manifest must conform to this schema.

---

### Manifest Location

| Platform | Path |
|----------|------|
| Windows  | `%USERPROFILE%\.claude\contexts.json` |
| Unix / macOS | `$HOME/.claude/contexts.json` |

The file belongs to the user and is not managed by any plugin. Skills may offer to write to it via explicit opt-in (`AskUserQuestion`) but never silently.

---

### Top-Level Shape

```json
{
  "contexts": [
    { ... },
    { ... }
  ]
}
```

The `contexts` array is ordered. The first entry whose `path_globs` matches the current working directory wins (first-match semantics — see Resolution Rules below).

---

### Context Entry Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | **Yes** | Short identifier (e.g. `rise-qa`, `perso`, `mantu`). Used in skill prompts and as the explicit context argument. |
| `path_globs` | string[] | **Yes** | One or more glob patterns matched against the current working directory. First-match wins across all contexts. |
| `github_org` | string | No | GitHub organisation slug (e.g. `Rise-4`). Mutually exclusive with `github_user`. |
| `github_user` | string | No | GitHub personal account slug (e.g. `GBR-Perso-1`). Mutually exclusive with `github_org`. |
| `ssh_alias` | string | No | SSH host alias declared in `~/.ssh/config` (e.g. `github-rise`, `github-perso`). Used to compose SSH clone URLs and verify push remotes. |
| `commit_email` | string | No | Git commit email for this context. Skills may verify it matches `git config user.email` via an `includeIf` block. |
| `azure_tenant_id` | string | No | Azure / Entra tenant GUID for this context. |
| `azure_subscriptions` | object | No | Map of environment name → Azure subscription GUID (e.g. `{ "qa": "<guid>", "prod": "<guid>" }`). |
| `azure_env_file_prefix` | string | No | Prefix for local Azure env files (e.g. `rise-env`). Used by Terraform auth skills. |
| `dev_settings_repo` | string | No | Repository name of the private dev-settings source (e.g. `it--dev-settings`). |
| `dev_settings_owner` | string | No | GitHub owner of the dev-settings repo (org or user slug). Combined with `dev_settings_repo` to form `<owner>/<repo>`. |
| `dev_settings_admin` | string | No | Display name of the person who administers the dev-settings repo. Used in instructions to developers. |
| `ado_org_url` | string | No | Azure DevOps organisation URL (e.g. `https://dev.azure.com/Mantu`). Presence (combined with absence of `github_org`/`github_user`) signals ADO-backed context. |
| `app_template_path` | string | No | Absolute path to the local clone of the application template repo (e.g. `C:\Workspace\Dev\Rise.Applications\it--app-template`). |

Fields not listed here are silently ignored by skills. The manifest is user-extensible.

---

### Resolution Rules

1. **`github_org` and `github_user` are mutually exclusive.** A context must declare at most one. Declaring both is a schema error — skills must report it and fall back to inline ask.
2. **ADO-backed context**: a context that declares `ado_org_url` and does **not** declare `github_org` or `github_user` is treated as Azure DevOps–backed. Skills use `ado_org_url` for repository discovery and clone URLs.
3. **First-match path_globs wins**: the `contexts` array is evaluated in order. The first context whose `path_globs` array contains a pattern matching the cwd is the resolved context. No further entries are evaluated.

---

### Glob Matching Semantics

- `**` matches any number of path segments recursively (e.g. `C:/Workspace/Dev/Rise.Applications/**` matches any subdirectory of `Rise.Applications`).
- `*` matches any sequence of characters within a single path segment.
- Matching is **case-insensitive on Windows** and case-sensitive on Unix/macOS.
- Patterns are matched against the **full absolute path** of the current working directory.

**Examples:**

| Pattern | Matches |
|---------|---------|
| `C:/Workspace/Dev/Rise.Applications/**` | Any directory under `Rise.Applications\` |
| `C:/Workspace/Dev/Perso.Applications/**` | Any directory under `Perso.Applications\` |
| `/home/user/work/rise/**` | Any directory under `~/work/rise/` (Unix) |
| `C:/Workspace/Dev/Rise.Applications/it--*` | Only immediate children starting with `it--` |

---

### Multi-Tenant Note

If your organisation's environments span multiple Azure tenants, declare **one context entry per tenant** rather than one per organisation. For example, if QA runs in one tenant and production in another:

```json
{ "name": "rise-qa",   "azure_tenant_id": "<qa-tenant-guid>",   "azure_subscriptions": { "qa": "<qa-subscription-guid>" } }
{ "name": "rise-prod", "azure_tenant_id": "<prod-tenant-guid>", "azure_subscriptions": { "prod": "<prod-subscription-guid>" } }
```

Each context's `azure_subscriptions` map contains only the subscriptions within that tenant. Skills that need to target a specific environment must resolve the correct context first.

---

### Example Manifest

```json
{
  "contexts": [
    {
      "name": "rise-qa",
      "path_globs": ["C:/Workspace/Dev/Rise.Applications/**"],
      "github_org": "Rise-4",
      "ssh_alias": "github-rise",
      "commit_email": "you@yourdomain.com",
      "azure_tenant_id": "<qa-tenant-guid>",
      "azure_subscriptions": {
        "qa": "<qa-subscription-guid>"
      },
      "azure_env_file_prefix": "rise-env",
      "dev_settings_repo": "it--dev-settings",
      "dev_settings_owner": "Rise-4",
      "dev_settings_admin": "<admin-display-name>",
      "app_template_path": "C:/Workspace/Dev/Rise.Applications/it--app-template"
    },
    {
      "name": "rise-prod",
      "path_globs": ["C:/Workspace/Dev/Rise.Applications/**"],
      "github_org": "Rise-4",
      "ssh_alias": "github-rise",
      "commit_email": "you@yourdomain.com",
      "azure_tenant_id": "<prod-tenant-guid>",
      "azure_subscriptions": {
        "prod": "<prod-subscription-guid>"
      },
      "azure_env_file_prefix": "rise-env",
      "dev_settings_repo": "it--dev-settings",
      "dev_settings_owner": "Rise-4",
      "dev_settings_admin": "<admin-display-name>",
      "app_template_path": "C:/Workspace/Dev/Rise.Applications/it--app-template"
    },
    {
      "name": "perso",
      "path_globs": ["C:/Workspace/Dev/Perso.Applications/**"],
      "github_user": "GBR-Perso-1",
      "ssh_alias": "github-perso",
      "commit_email": "me@personal.example"
    },
    {
      "name": "mantu",
      "path_globs": ["C:/Workspace/Dev/Mantu.Applications/**"],
      "ado_org_url": "https://dev.azure.com/Mantu",
      "commit_email": "g.brourhant@mantu.com"
    }
  ]
}
```

> **Note on `rise-qa` / `rise-prod`**: both entries share the same `path_globs`. The first match (`rise-qa`) is returned when the skill does a cwd-based lookup. Skills that need to target production must receive an explicit context argument or ask the user to disambiguate.
