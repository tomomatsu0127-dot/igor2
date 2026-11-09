# WORK_LOG

## 2026-11-08 / Baseline checkpoint

- Reviewed source, design, safety and compatibility skills.
- User prioritizes folder and graph management; arrows remain an optional feature.
- Imported unchanged v2.1.2 baseline into dedicated MH branch based on empty main. No XRD release modified.
- Raw measurements and original Experiments were not imported or altered.

## Implementation checkpoint
- Added stable identities, logical tree, per-graph native snapshots with two alternating generations, source bindings, save hook and an optional endpoint editor (default off).
- Main plotting algorithms, legend layout and axis calculations preserved. Legacy panel adds a management entry.
- Native manager, restart and compatibility fixtures pass; 31 existing records / 115 semantic field groups unchanged at three boundaries; legacy PNG output pixel-identical.
- Continuing edge cases, individual legacy regression suites, real-input validation and packaging. No main merge or installation.

## 2026-11-08 / Validation and delivery

- Final suites: manager 53, edge cases 20, duplicate ownership 5, existing figures 82, axes 21, reference defaults 25, four real inputs 20, fresh-process reopen 14, migration 3, migrated restart 3. Total 246, no final failed assertions.
- Legacy compatibility fixture includes raw/converted numeric waves, NaN, 3D dimensions, labels/scales/units/Notes, text waves, formula dependencies, scalar/string metadata and an unrelated folder. Three boundaries preserve all 31 existing records and 115 semantic field groups.
- Fresh-process reopen verified through a per-process identity token before opening only test copies. Only newly created process IDs were closed. Temporary old-IPF and original-input copies were unavailable during reopen; user originals were never moved.
- Final rendered comparison found antialias gray-level differences at text edges (max17/255), with identical white/black geometry and otherwise identical native graph commands. The comparator now records this observed distinction rather than falsely asserting complete old/new pixel equality. Initialized/restarted PNGs are bytewise in pixel content equal.
- Fixed a final source-edit regression where a graph snapshot base variable lost its initializer; reran the native manager, edges, restart and existing-figure tests. Preserved development failure logs privately; did not count them as passes.
- Exported synthetic manager/graph previews. Published test logs have test-directory paths generalized; detailed real measurements and logs remain outside the public repository and release.
- Added exact-byte Git attributes for the baseline dependency set, and checksums for the release. No main merge, deployment or modification to synced source releases.

## Distribution verification

- Delivered 32 files, ZIP 149804 bytes. Every ZIP entry matches the release source bytes.
- ZIP SHA256: 0ed38f06d21f71a2b84b4b7a6675efbbc4cf7bf867034564db62870dfc15d1ef
- Original baseline bytes and staged Git blobs match the baseline hash manifest. Release Git blobs match the delivered checksum manifest.

## 2026-11-09 / v2.3.0 investigation

- User authorized folder select/clear, sample numbers/composition parsing, new-import-only review, VSM filter, UI cleanup, five-minute autosave and measured optimization.
- Base 9809855; retained complete v2.2.0. New branch codex/mh-v2.3.0 and version directory.
- Identified per-row Redimension tree rebuild, per-checkbox full tree scan with linear ID lookup, and repeated snapshot writes as candidates; will benchmark before/after.
- Interpret batch naming screen as showing only newly added measurements. All-folder check includes descendants; also provide folder clear and global clear. Autosave writes separate recovery copies rather than replacing the original Experiment.

## 2026-11-09 / v2.3.0 implementation and validation

- Added metadata and recovery modules and kept manager schema 1, stable dataset/graph UIDs, original Wave paths, labels of existing samples, and manually edited graph legends. Metadata is additive and populated from original source paths.
- Added folder-wise checks and global clear, sample number column and graph provenance, per-import review/move, and VSM file filtering with a second extension check before file access. Existing format implementations were compared with v2.2.0, allowing only version strings.
- Benchmarked the release and baseline on 1,000 synthetic rows. Profiling the first prototype found per-row global Wave lookups expensive. Bound Wave references once, grouped dataset rows by folder and changed individual checkbox handling to touch only the relevant ancestor rows. New median 3.56 ms full tree and 0.54 ms individual check, versus 16.37 and 59.58 ms respectively.
- Added a five-minute idle native timer and two separate recovery generations. A real timer fired after 300.007 s; opened recovery copies resume saving into a new series. Verified original recovery bytes remain unchanged.
- Final evidence: 266 native assertions; packed experiment and separate process reopen; legacy manager tables, 115 data field groups, native graph command and render comparison. One initial figure-suite run lacked a fixture at its expected sibling path; reran with the fixture in the correct test layout. Only passing final runs are distributed.
- Updated versioned release docs, checksums and synthetic previews. Published no actual measurements, private Experiments or local test paths. No merge to main.

## 2026-11-09 / v2.4.0 investigation

- User requested contextual management, deletion and VSM replacement, disposable graphs with PNG export and preserved manager size, performance verification, and deployment to the desktop Experiment.
- Branch baseline 15662fc. Private desktop copy contains 32 measurements, eight folders and nine archived graphs. Saved MH data and archive contents will be compared before and after migration.
- Reproduced native Igor Windows MDI restoring a maximized manager when a standard graph is opened. Testing floating graph hosting and native close behavior.

## 2026-11-09 / v2.4.0 implementation, validation and deployment

- Kept Wave paths and identifiers through VSM replacement and row ordering. Logical folder deletion promotes children with a collision check. Separate source-file deletion requests confirmation in the app.
- Used native floating hosts to keep the Windows MDI manager maximized. Verified standard plot dimensions, normal and floating PNG export, live archive overlay, silent close, and dependency-aware deletion. Igor 9 uses /K=1 and may serialize open preview windows through native PXP saving. Igor 10 uses /K=4.
- Removed per-plot archive writes for new plots. Bulk check finds descendants per folder once and all-clear writes the check column in one operation. Same-workload median 37.2→11.3 ms and 27.5→7.2 ms respectively.
- Compared 401 persisted MH records and 1,766 field groups on a private desktop copy with no changes. Validated in fresh processes before and after atomic desktop replacement. Exact original PXP kept as a separate backup. No real measurement files altered or committed.

## 2026-11-09 / v2.5.0
- Start from c6d31c1. Shared Experiment figure settings, typographic minus, R.T. and single-box legends based on the three reference images.
- Captured a private copy of the current desktop Experiment. Previous release remains versioned.

## 2026-11-09 / v2.5.0 validation and deployment

- Switched figure settings to a draft/commit workflow independent of the selected figure. Native text measurement sets compact tab stops in one annotation. Right-arrow legend rows are ordered by curve endpoint height.
- Passed 20 figure, 21 axis and 3 reopen checks in Igor 9.05. The right and top arrow samples were visually checked after PNG export. A private copy of a legacy archived graph reopened using the shared settings.
- Validated the current desktop Experiment before replacement, with 276 existing records and 1,284 field groups unchanged. Reopened in a separate process and confirmed maximized graph overlay. Kept the original bytes as the v2.4.0 backup.
