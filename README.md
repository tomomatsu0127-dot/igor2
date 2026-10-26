# Igor2 / XRDWorkbench

開発環境・管理基盤 v1.0.0。まず [WORK_STATUS.md](WORK_STATUS.md) を読んでください。

本体の正本化候補は `xrd_workbench_v1.1.0/` です。2026-10-26にローカル版を無改変で取り込みました。採用済みのmainリリースを意味しません。旧版の記述・試験結果も原本どおり保持しています。

- 開発ルール: [AGENTS.md](AGENTS.md)
- 履歴と試験: [WORK_LOG.md](WORK_LOG.md)
- [依存調査](docs/DEPENDENCY_AUDIT_v1.0.0.md) / [Igor 9.05検証手順](docs/IGOR905_VALIDATION_v1.0.0.md) / [次のチャットから再開](docs/RESUME_GUIDE_v1.0.0.md)
- [今回の検証結果と未確認](docs/VALIDATION_RESULTS_v1.0.0.md)
- Skills: `.agents/skills/` の Safe Update / Data Compatibility / Performance Debug。Codexで3件とも検出・有効化を確認済み。
- 管理基盤の確認: `python tools/verify_environment_v1.0.0.py`（標準ライブラリのみ、読取専用）。Igor実機試験とは別です。
- 作業は `codex/safe-development-v1.0.0` で継続し、mainへ直接pushしません。
- 実験・研究データ・バックアップはこのrepoへ保存しません。
