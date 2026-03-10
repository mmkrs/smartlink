---
name: studio-start
description: Bootstrap the shared OpenCode studio on the current project
opencode.agent: studio-orchestrator
---
Start the studio for the current project.

Process:
- Read `AGENTS.md` at the project root.
- Reload the project anchors listed in `AGENTS.md` before planning.
- Determine the current development phase from project anchors, prioritizing `docs/PHASE_PLAN.md` and repository state.
- Summarize the active constraints, the first safe slice, and which subagents you will use.
- Do not implement code yet unless the user explicitly asks you to proceed past planning.
