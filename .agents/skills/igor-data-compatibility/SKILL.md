---
name: igor-data-compatibility
description: Audit and validate Igor Pro Wave, Data Folder, and XRDWorkbench identification compatibility across code updates, schema migrations, saving and reopening. Use when persisted assignments or experiment data must survive a change.
---

# Data Compatibility

Skill version: 1.0.0

Read repository status and determine old/new code commits, Igor version, schema version and the actual Experiment being tested. Do not infer schema from release filenames. Use only copies; keep an independent original .pxp and its matching IPF dependency set. User research data must remain outside the public repository.

Before calling initialization or showing a panel, inspect startup/migration code and capture a baseline. For each Data Folder and Wave record full path, numeric/text type, dimensions, data, scale/units, dimension labels, Note and formula, plus relevant scalar/string variables. Compare all values, treating corresponding NaNs as missing values. A total, point count or CRC alone does not prove semantic equivalence.

For XRDWorkbench inspect both root:Packages:Workbench and root:Packages:XRDWorkbench. Preserve Raw/Processed, Peaks and peak IDs, Assignments (peakID/refIndex/refPeakIndex/shift/mode/created), the SharedLibrary scientific data and refUID/revisionUID, Registry and project/measurement UIDs, lattice history, Undo/Redo and saved plots. Check Unknown (refIndex=0) and missing hkl explicitly. References are part of assignment meaning, not disposable display caches. Include inactive projects and deleted-but-retained records when present.

Compare baseline → updated code before/after initialization → fresh-name .pxp save → close the isolated Igor instance → restart and reopen. LoadData in the same process is not an equivalent persistence test. Expected migration changes need an explicit mapping and justification; compare stable IDs/content where paths legitimately change. Formula dependencies and graph traces must resolve after reopening.

Verify external file behavior separately: standalone procedures/include files, shared waves, original measurement/reference files and symbolic paths. An offline test must prevent access to the old absolute paths, preferably on another test environment using copies. Moving or deleting user originals is unnecessary. Adopt Files is an optional packaging choice with a changed code-update workflow, not a blanket fix.

If present, follow docs/IGOR905_VALIDATION_v1.0.0.md and docs/DEPENDENCY_AUDIT_v1.0.0.md. If actual Igor/.pxp cannot be tested, deliver a field-by-field comparison plan and mark runtime compatibility 未確認. Do not change the schema or silently repair data during an audit. Record evidence, unexpected differences and next action in WORK_LOG/WORK_STATUS; keep unresolved compatibility work off main.
