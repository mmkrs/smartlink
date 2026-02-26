# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Global distribution step in `setup.sh` and `setup.ps1`: generated files are now symlinked (or copied as fallback) to each tool's global config directory (`~/.config/opencode/`, `~/.claude/`, `~/.cursor/`)
- Symlink capability probe to detect whether the OS supports real symlinks; falls back to file copy on Windows without Developer Mode
- Safe backup logic: existing files at global targets are backed up with `.bak.YYYYMMDD-HHMMSS` before replacement
- Idempotent global step: skips files that already match (symlink target or file content)
- VS Code reminder printed at the end of setup (no global dir; requires `chat.agentFilesLocations` setting)

### Changed

- Refined changelog command wording: `/changelog` mode now reads "create or update" `[Unreleased]`

### Fixed

- Removed stale `.ruff_cache/` and `__pycache__/` entries from `.gitignore` (leftover from deleted Python setup)
