---
name: qa-check
description: Run QA validation on the latest implemented slice
opencode.agent: studio-orchestrator
---
Validate the latest implementation.

Process:
- Read `AGENTS.md` at the project root and reload project anchors.
- Delegate to `qa-review` to run available tests, build checks, and scope verification against the approved slice.
- Collect the QA verdict: PASS, FIX, or BLOCKED.
- If PASS, confirm the slice is complete and summarize the next safe slice.
- If FIX, list the specific issues that need correction before proceeding.
- If BLOCKED, explain the blocker and recommend how to unblock.
