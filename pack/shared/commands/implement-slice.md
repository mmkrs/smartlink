---
name: implement-slice
description: Delegate an approved slice to lead-dev for implementation
opencode.agent: studio-orchestrator
---
Implement the current approved slice.

Process:
- Read `AGENTS.md` at the project root and reload project anchors.
- Confirm that the current slice has passed proposal review (architect-review and advisor-review).
- If no reviewed proposal exists, stop and ask the user to run `/proposal-review` first.
- Delegate implementation to `lead-dev` with the approved scope.
- After implementation completes, delegate to `qa-review` for validation.
- Summarize the result: what was implemented, what was validated, and what the next slice should be.
