---
name: igor-safe-update
description: Safely investigate and implement an authorized Igor Pro or XRDWorkbench update while preserving existing behavior and saved experiment data. Use for IPF fixes, version updates, or update review; do not expand a documentation-only task into a code change.
---

# Safe Update

Skill version: 1.0.0

Read the repository AGENTS.md, WORK_STATUS.md and latest WORK_LOG.md. Establish the GitHub branch/commit, target release directory, reported symptom, expected behavior and permitted change scope before editing. Identify a code cause; distinguish evidence from guesses. If the requested scope is investigation or environment setup, report discovered defects without implementing fixes.

Keep the existing release, source measurements, references, .pxp and backups intact. Work on a branch and a new versioned release directory when changing the application. Save the original dependency set and record its hashes. Never open and overwrite a user's original Experiment to test an update.

Inspect the entrypoint, include graph, external procedure/library dependencies, startup/migration functions and persistent write sites. Updating an IPF file can change functions invoked by hooks, SetFormula and deferred Execute/P callbacks. Loading a panel can migrate/rebuild data. A packed .pxp may still reference standalone procedures; saving it alone is not proof of self-containment.

Make the smallest authorized fix and record affected callers. When persistent state might be affected, use the repository's Data Compatibility skill or its SKILL.md and the real data comparison procedure. Keep old/new procedure versions out of the same Igor process during compilation.

Validate only what is necessary for the change: compile in an isolated Igor instance, exercise the reported operation and relevant existing behavior, then save under a fresh filename and restart/reopen for persistence-sensitive changes. Check raw data, assignments and references. Static checks cannot substitute for Igor execution. Label unrun checks 未確認.

At each investigation/implementation/validation boundary, update WORK_STATUS and append decisions, files, tests and next actions to WORK_LOG; commit and push the working branch. Preserve incomplete work as a checkpoint, never publish it directly to main. Report files, branch/SHA, verified behavior and remaining risks. User authorization still determines whether to merge or deploy.
