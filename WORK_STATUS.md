# WORK_STATUS

2026-11-08 JST / MH VSM Analyzer v2.2.0

- Branch: codex/mh-v2.2.0. Original main: 2c30ceffde11c4013bf496fced92f7da6d68ee49. MH baseline checkpoint: 8454c94.
- Implemented logical folder tree, rename/move, destination import, stable dataset/graph identity, graph provenance and native edited-state restore. Optional arrow endpoint editor defaults off.
- Retained v2.1.2 baseline and original measurement files. Plot layout/axis implementation bodies unchanged (27 functions).
- Native Igor 9.05 build 56551, 96 dpi: 246 assertions passed, zero final failures. Independent process restart and old-IPF/source-VSM-unavailable copies tested.
- Compatibility: 31 pre-existing records, 115 semantic field groups at each of three boundaries, zero differences. Native graph commands differ only by managed UID and hook additions.
- Image comparison: exact white/black geometry masks; old/new text edge antialias intensities differ up to 17/255. Initialized/restarted output is pixel-identical. Do not claim exact old/new pixel equality.
- Original user's Experiment not tested or overwritten. All mouse interactions, all DPI, long-running/large datasets, physical external moves, PDF/EPS and clean-PC behavior remain unverified.
- New release folder: mh_vsm_analyzer_v2.2.0. README and TEST_RESULTS describe usage, optional arrows and scope. Main not merged; no automatic installation into Igor.
