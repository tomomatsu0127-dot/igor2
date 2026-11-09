# WORK_STATUS

2026-11-09 JST / MH VSM Analyzer v2.4.0

- Branch codex/mh-v2.4.0, base 15662fcdcea850311a8f72b05a20961d66c5bc35.
- Added context menus, sibling order, folder promotion on delete, distinct measurement and disk-file deletion, and VSM replacement in place. Open plots using a removed measurement close while unrelated references block deletion.
- New plots use silent native close, PNG export with source stem, and no manager archive. A maximized manager keeps its rectangle when a native graph opens in a floating host. Older archives remain readable and deletable.
- Igor Pro 9.05: 160 assertions passed across management, figure, axis, default and reopen suites. Desktop migration comparison found 0 differences across 401 records and 1,766 field groups. Verified the installed IPF from a new process using a copy of the upgraded Experiment.
- 1,000 datasets and 10 folders: median folder bulk checks 37.2 to 11.3 ms and global clear 27.5 to 7.2 ms.
- Applied to desktop QS-MH.pxp with an exact v2.3.0 PXP backup. Research data and deployment files are excluded from the repository. No merge to main.
