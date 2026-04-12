# Platform — Claude Code Plugin

This repository is a Claude Code plugin providing AI-assisted platform tooling — repo management, Azure provisioning, security scanning, and environment monitoring.

## Plugin Structure

- `skills/` — skills as `<name>/SKILL.md` + shared docs in `skills/shared/`
- `hooks/` — `hooks.json` + `log-instructions-loaded.sh`
- `.claude-plugin/plugin.json` — plugin manifest

## How It Works

1. Install the plugin (user-level or project-level).
2. Skills become available as slash commands.
3. The `InstructionsLoaded` hook logs which instruction files are loaded to `.claude/instructions-loaded.log`.

## Development

When editing this repo, you are editing the plugin source. Changes here affect all consumers.

- Skills reference shared docs via `${CLAUDE_PLUGIN_ROOT}/skills/shared/`.
- Test skill changes by running them in a consumer project after updating the plugin.
