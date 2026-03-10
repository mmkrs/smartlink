---
name: proposal-review
description: Run architect and advisor reviews on the current proposal
opencode.agent: studio-orchestrator
---
Review the current proposal before implementation.

Process:
- Read `AGENTS.md` at the project root and reload project anchors.
- Delegate to `architect-review` first: check architecture fit, scope discipline, phase boundaries, and dependency direction.
- Then delegate to `advisor-review`: check risks, ambiguity, sequencing, and whether proceeding is safe.
- Collect both verdicts.
- If both pass, summarize the approved scope and confirm the proposal is ready for implementation.
- If either returns ADJUST or STOP/REVISE, summarize what needs to change before implementation can proceed.
- Do not start implementation from this command.
