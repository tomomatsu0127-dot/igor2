# WORK_STATUS

2026-11-09 JST / MH VSM Analyzer v2.3.0

- Branch: codex/mh-v2.3.0, baseline 9809855a9d1863f070231712a7e3a04a2817f264. Baseline release's 32 file checksums verified unchanged.
- Implemented recursive folder check/clear, global clear, .VSM-only file picker, independent sample number and composition, new-import-only edit/move review, and five-minute rotating recovery copies. Arrow editing stays opt-in.
- Igor 9.05 build 56551: 266 native assertions passed. The idle timer saved at 300.007 seconds. Recovery reopening was isolated and did not overwrite the opened recovery file.
- v2.2.0 compatibility: 31 records and 115 field groups plus 9 manager fields unchanged at each boundary; persisted graph commands unchanged except identity hook. Existing plot settings and old measurement data were retained.
- Synthetic 1,000-measurement benchmark: tree refresh median 16.37 to 3.56 ms; individual checkbox median 59.58 to 0.54 ms. No persistent manager Wave growth across repeated refresh.
- Release: mh_vsm_analyzer_v2.3.0. README and TEST_RESULTS include switching procedure and tested scope. Real user Experiment not modified. No installation, no main merge.
