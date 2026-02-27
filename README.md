# Smartlink Prompt Pack

Single-source management for commands (slash prompts), subagents, and MCP servers across 4 AI tools simultaneously: **Claude Code**, **Cursor**, **OpenCode**, and **VS Code Copilot**.

Everything is defined once in `pack/shared/`. Running `setup` generates and deploys tool-specific files both locally (project-level) and globally (user-level).

## Canonical sources (only files to maintain)

**Commands:**
- `pack/shared/commands/changelog.md`
- `pack/shared/commands/commit.md`
- `pack/shared/commands/documentation.md`
- `pack/shared/commands/resolve-conflicts.md`

**Agents:**
- `pack/shared/agents/frontend-ui.md`
- `pack/shared/agents/web-researcher.md`

**MCP servers:**
- `pack/shared/mcp.json`

## Run setup

Linux/macOS/WSL (requires `python3` for MCP generation):

```bash
./setup.sh
```

Windows:

```bat
setup.cmd
```

Direct PowerShell:

```powershell
.\setup.ps1
```

## Generated project-level outputs

Commands (4 tools × 4 commands):
- `.claude/commands/<name>.md`
- `.cursor/commands/<name>.md`
- `.opencode/commands/<name>.md`
- `.github/prompts/<name>.prompt.md`

Agents (4 tools × 2 agents):
- `.claude/agents/<name>.md`
- `.cursor/agents/<name>.md`
- `.opencode/agents/<name>.md`
- `.github/agents/<name>.agent.md`

MCP configs (project-level):
- `.mcp.json` — Claude Code format (`mcpServers`)
- `.cursor/mcp.json` — Cursor format (`mcpServers`)
- `.vscode/mcp.json` — VS Code format (`servers`)

All generated files are gitignored. Only `pack/shared/` is committed.

## Global deployment (done by setup)

Setup also deploys/symlinks globally so every project on the machine gets the agents, commands, and MCP servers automatically:

| Tool | Commands | Agents | MCP |
|---|---|---|---|
| Claude Code | `~/.claude/commands/` | `~/.claude/agents/` | `~/.claude.json` → `mcpServers` key |
| Cursor | `~/.cursor/commands/` | `~/.cursor/agents/` | `~/.cursor/mcp.json` |
| OpenCode | `~/.config/opencode/commands/` | `~/.config/opencode/agents/` | `~/.config/opencode/opencode.json` → `mcp` key |
| VS Code | *(no global path)* | *(no global path)* | `%APPDATA%/Code/User/mcp.json` (Win) / `~/Library/Application Support/Code/User/mcp.json` (macOS) / `~/.config/Code/User/mcp.json` (Linux) |

For VS Code global prompts/agents (no fixed directory), add to `settings.json`:
```json
"chat.agentFilesLocations": { "/path/to/smartlink/.github": true }
```

## Frontmatter convention

Both commands and agents use a single canonical `.md` file with a namespaced frontmatter header.

**Namespace prefixes:**
- `common.<field>` — shared fallback for all tools
- `claude.<field>` — Claude Code override
- `cursor.<field>` — Cursor override
- `opencode.<field>` — OpenCode override
- `vscode.<field>` — VS Code Copilot override
- `<tool>.extra.<field>` — free pass-through (forwarded as-is)

**Example agent header:**
```yaml
---
name: my-agent
description: Does something useful
claude.model: haiku
claude.maxTurns: 20
claude.mcpServers: ["searxng"]
opencode.model: anthropic/claude-haiku-4-20250514
opencode.mode: subagent
cursor.model: fast
cursor.readonly: true
vscode.tools: ['fetch','search']
vscode.model: ['Claude Sonnet 4.5']
---
```

See `pack/shared/agents/frontend-ui.md` for a full commented catalog of supported agent keys per tool.
See `pack/shared/commands/changelog.md` for a full commented catalog of supported command keys per tool.

## MCP servers

### Canonical format (`pack/shared/mcp.json`)

Each server entry needs a `type` field to select the transport:

| `type` | Use case | Required fields |
|---|---|---|
| `stdio` | Local program launched as a subprocess | `command`, `args` |
| `http` | Remote server — streamable HTTP (recommended) | `url` |
| `sse` | Remote server — legacy Server-Sent Events | `url` |

> **Type inference:** if `type` is omitted, `stdio` is assumed when `command` is present, `http` when only `url` is present.

**Local server (stdio):**
```json
{
  "my-server": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "my-mcp-package"],
    "env": { "API_KEY": "secret" }
  }
}
```

**Remote server (HTTP):**
```json
{
  "github": {
    "type": "http",
    "url": "https://api.githubcopilot.com/mcp/",
    "headers": { "Authorization": "Bearer ${GITHUB_TOKEN}" }
  }
}
```

### How setup transforms the canonical format

**stdio servers — what each tool receives:**

| Field | Claude Code | Cursor | VS Code | OpenCode |
|---|---|---|---|---|
| `type` | omitted | omitted | omitted | `"local"` (required) |
| `command` | string `"npx"` | string `"npx"` | string `"npx"` | **array** `["npx", "-y", "pkg"]` |
| env key | `env` | `env` | `env` | `environment` |
| root key | `mcpServers` | `mcpServers` | `servers` | `mcp` (inside `opencode.json`) |

**remote servers (`http` / `sse`) — what each tool receives:**

| Field | Claude Code | Cursor | VS Code | OpenCode |
|---|---|---|---|---|
| `type` | `"http"` or `"sse"` | **omitted** (auto-detected) | `"http"` or `"sse"` | `"remote"` (always, regardless of transport) |
| `url` | `url` | `url` | `url` | `url` |
| headers | `headers` | `headers` | `headers` | `headers` |
| root key | `mcpServers` | `mcpServers` | `servers` | `mcp` (inside `opencode.json`) |

### Variable interpolation in `headers` / `env`

Values are copied verbatim — setup does **not** rewrite them. Use the syntax of the tool you target:

| Tool | Syntax | Example |
|---|---|---|
| Claude Code | `${VAR}` or `${VAR:-default}` | `"Bearer ${GITHUB_TOKEN}"` |
| Cursor | `${env:VAR}` | `"Bearer ${env:GITHUB_TOKEN}"` |
| OpenCode | `{env:VAR}` (no `$`) | `"Bearer {env:GITHUB_TOKEN}"` |
| VS Code | `${input:id}` (prompted) or `${VAR}` | `"Bearer ${input:token}"` |

If a server is consumed by multiple tools, use a plain env var name (`$TOKEN`, no tool prefix) and set it in your shell — all tools will inherit it from the environment.

### Tool-specific features (manual override after setup)

The canonical format covers stdio and HTTP/SSE. These tool-specific fields are not generated — edit the generated file after running setup if you need them:

| Feature | Tool | Field to add inside the server entry |
|---|---|---|
| OAuth pre-registered client | Claude Code | `"oauth": { "clientId": "…", "callbackPort": 8080 }` |
| OAuth static credentials | Cursor | `"auth": { "CLIENT_ID": "…", "CLIENT_SECRET": "…", "scopes": ["read"] }` |
| OAuth dynamic/pre-registered | OpenCode | `"oauth": {}` · set `"oauth": false` to disable |
| Load env from a `.env` file | Cursor, VS Code | `"envFile": "${workspaceFolder}/.env"` |
| Disable a server at startup | OpenCode | `"enabled": false` |
| Tool-call timeout | OpenCode | `"timeout": 10000` (ms) |
| Prompted secrets (stored) | VS Code | `"inputs"` array at root of `mcp.json` |
