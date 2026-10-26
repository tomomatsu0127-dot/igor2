---
name: igor-performance-debug
description: Investigate Igor Pro or XRDWorkbench latency, unnecessary processing, Wave memory growth, redraws and repeated recalculation using measurements and code evidence. Use for performance diagnosis; optimize only within the user's authorized scope.
---

# Performance Debug

Skill version: 1.0.0

Establish a reproducible action, workload (projects, waves, points and references), Igor version and code commit. Distinguish first-run import/migration/compilation from repeated steady-state operations. Use synthetic or copied data in a separate Igor instance; preserve baseline numerical results and .pxp.

Trace the action through control/window hooks, queued Execute/P callbacks, background autosave tasks, dirty/revision flags, table rebuilds, dependency formulas and drawing. Search related callers before proposing a change. In XRDWorkbench useful starting terms include XRD_RequestLive, XRD_UpgradeProject, XRD80_LibraryChanged, SetFormula, DoUpdate, DuplicateDataFolder, Make/O, Redimension and XRD_SaveRecovery. An occurrence is a candidate, not proof of a bottleneck.

Use Igor-supported timing/profiling tools available in the target version. Record repeated elapsed measurements with warm/cold conditions, memory/Wave counts before/after and whether the UI is drawing. Identify whether the cost is I/O, copying, scanning, recalculation or rendering. A growing memory estimate alone is not proof of a leak; determine which persistent or free objects survive each operation. Account for Undo, recovery snapshots, reference revisions and plot caches intentionally retained.

Check for recursive callback/update chains, redundant table rebuilds, unchanged inputs triggering full scans, autosave contention and full-data duplicates. SetFormula recalculation order can affect correctness; suppressing DoUpdate or redraws without checking numerical and graph behavior is unsafe. Do not disable autosave, clear Undo/history or remove reference revisions as a performance shortcut.

For a diagnosis-only request, return ranked evidence, measurement limits and recommended next investigation without modifying application code. For an authorized optimization, make the smallest measured change and verify output equivalence with Data Compatibility, UI behavior and save/restart/reopen where affected. Compare timing under the same workload; report variance and untested cases rather than claiming improvement from static reading.

Record the reproduction, measurements, cause, files and next actions in WORK_STATUS/WORK_LOG and checkpoint to the working branch. Mark measurements and Igor tests not performed as 未確認.
