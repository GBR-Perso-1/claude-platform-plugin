## UX rules for all rise skills

### Confirmation gates

Whenever a command requires user confirmation before proceeding (commit, push, PR creation, applying changes, etc.):

- **ALWAYS** use `AskUserQuestion` with interactive selectable options — never use plain text prompts like "Shall I proceed?".
- Group related confirmations into a **single question** when possible (e.g. all repos in one prompt, not one per repo).
- Include a recommended option first (e.g. "Commit and push all (Recommended)").
- The user can always select "Other" to provide custom input (e.g. revise a message, pick specific repos, or decline).
- Present the details (commit messages, PR titles, file lists, etc.) in the **question text**, then keep options short and actionable.
