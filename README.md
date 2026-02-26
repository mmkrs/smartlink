# Smartlink Prompt Pack

Single-source setup for:
- commands (slash prompts)
- subagents

No skills in this version.
No Python required.

## Canonical sources (only files to maintain)

- `pack/shared/commands/changelog.md`
- `pack/shared/agents/frontend-ui.md`

## Subagent frontmatter convention

Use one canonical header with:
- `common.*` for shared defaults
- `opencode.*` for OpenCode
- `claude.*` for Claude Code
- `cursor.*` for Cursor
- `vscode.*` for VS Code Copilot

The first canonical subagent (`pack/shared/agents/frontend-ui.md`) includes a commented catalog of supported keys.

## Command frontmatter convention

Use one canonical header with:
- `common.*` for shared defaults
- `opencode.*` for OpenCode command frontmatter
- `claude.*` for Claude command/skill frontmatter
- `cursor.*` for Cursor command notes (markdown-only command files)
- `vscode.*` for VS Code prompt file frontmatter

The first canonical command (`pack/shared/commands/changelog.md`) includes a commented catalog with examples per parameter.

Example keys:
- `common.model: inherit`
- `opencode.mode: subagent`
- `claude.tools: Read, Glob, Grep, Bash`
- `cursor.readonly: true`
- `vscode.user-invokable: false`

You can add pass-through keys with:
- `opencode.extra.<field>`
- `claude.extra.<field>`
- `cursor.extra.<field>`
- `vscode.extra.<field>`

## Generate tool-specific files

Linux/macOS/WSL:

```bash
./setup.sh
```

Windows:

```bat
setup.cmd
```

Direct PowerShell (optional):

```powershell
.\setup.ps1
```

## Generated outputs

Commands:
- `.claude/commands/changelog.md`
- `.cursor/commands/changelog.md`
- `.opencode/commands/changelog.md`
- `.github/prompts/changelog.prompt.md`

Subagents:
- `.claude/agents/frontend-ui.md`
- `.cursor/agents/frontend-ui.md`
- `.opencode/agents/frontend-ui.md`
- `.github/agents/frontend-ui.agent.md`

## Isolation notes

- OpenCode uses `.opencode/*`.
- Claude Code uses `.claude/*`.
- Cursor uses `.cursor/*` and can also read `.claude/agents` for compatibility.
- VS Code uses `.github/*` and can also detect `.claude/agents` for compatibility.

Because of those compatibility paths, Cursor/VS Code may see `.claude/agents` too.
The generated files are kept consistent to avoid drift.
