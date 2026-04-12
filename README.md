# Platform — Claude Code Plugin

Claude Code plugin providing AI-assisted platform tooling — repo management, Azure provisioning, security scanning, and environment monitoring.

## What's included

| Component  | Items                                                                                                      |
| ---------- | ---------------------------------------------------------------------------------------------------------- |
| **Skills** | _(coming soon)_ `repo-clone`, `azure-provision-user`, `git-security-scan`, `azure-monitor`, `azure-health` |
| **Hooks**  | `InstructionsLoaded` — logs loaded instruction files to `.claude/instructions-loaded.log`                  |

---

## Installation

### Prerequisites

- [Claude Code](https://code.claude.com) installed

### Step 1 — Register the marketplace

Add the following to your **user-level** settings file at `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "gbr-perso": {
      "source": {
        "source": "settings",
        "name": "gbr-perso",
        "owner": {
          "name": "Brourhant Guillaume"
        },
        "plugins": [
          {
            "name": "platform",
            "source": {
              "source": "url",
              "url": "https://github.com/azuregbr/claude-platform-plugin.git"
            },
            "description": "Platform tooling — clone repos, provision Azure users, security scanning, Azure monitoring and health helpers.",
            "version": "1.0.0"
          }
        ]
      }
    }
  }
}
```

### Step 2 — Install the plugin

```powershell
claude plugin install platform@gbr-perso --scope user
```

### Step 3 — Reload plugins

```
/reload-plugins
```

---

## Updating the plugin

```powershell
claude plugin update platform@gbr-perso
```

---

## Local development

```powershell
claude --plugin-dir "C:/Workspace/Dev/Perso.Applications/claude-platform-plugin"
```
