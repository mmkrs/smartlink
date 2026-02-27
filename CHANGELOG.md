# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.0.4] - 2026-02-27

### Added

- `web-researcher` agent (`pack/shared/agents/web-researcher.md`): deep web research subagent that performs iterative multi-layered searches (broad exploration → deep dive → synthesis) and returns a structured answer with cited sources
- `/resolve-conflicts` command (`pack/shared/commands/resolve-conflicts.md`): AI-assisted merge conflict resolution supporting both merge and rebase modes; auto-detects the default branch, reads conflict markers, applies the most sensible resolution strategy, and stages results
- `pack/shared/mcp.json`: new canonical MCP server source file; define all MCP servers once (SearXNG pre-configured); `setup` reads this file and generates per-tool configs automatically
- MCP config generation in `setup.sh` and `setup.ps1`: produces per-tool project-level configs (`.mcp.json` for Claude Code, `.cursor/mcp.json` for Cursor, `.vscode/mcp.json` for VS Code Copilot) and deploys globally — merges `mcpServers` into `~/.claude.json`, symlinks to `~/.cursor/mcp.json` and VS Code's user dir, and merges the `mcp` key into `~/.config/opencode/opencode.json`
- Generated MCP config files (`.mcp.json`, `.vscode/mcp.json`) added to `.gitignore`

## [0.0.3] - 2026-02-27

### Added

- Global distribution step in `setup.sh` and `setup.ps1`: generated files are now symlinked (or copied as fallback) to each tool's global config directory (`~/.config/opencode/`, `~/.claude/`, `~/.cursor/`)
- Symlink capability probe to detect whether the OS supports real symlinks; falls back to file copy on Windows without Developer Mode
- Safe backup logic: existing files at global targets are backed up with `.bak.YYYYMMDD-HHMMSS` before replacement
- Idempotent global step: skips files that already match (symlink target or file content)
- VS Code reminder printed at the end of setup (no global dir; requires `chat.agentFilesLocations` setting)
- `/commit` command: proposes a commit message from staged changes in `short`, `normal`, or `verbose` format following conventional commit conventions
- `/documentation` command: analyses staged changes and updates affected documentation files (`README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `docs/`, etc.)

### Changed

- `/changelog` command: clarified mode descriptions (`create or update [Unreleased]`) and removed stale commit-message options from the output spec (that responsibility now lives in `/commit`)

### Fixed

- Removed stale `.ruff_cache/` and `__pycache__/` entries from `.gitignore` (leftover from deleted Python setup)
