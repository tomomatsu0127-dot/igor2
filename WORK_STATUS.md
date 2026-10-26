# WORK_STATUS

管理版: 1.0.0 / 2026-10-26 JST

- 状態: 開発基盤整備・静的検証・GitHubからの復元検証完了。実.pxpの互換性確認待ち。main未統合。
- Repository: https://github.com/tomomatsu0127-dot/igor2
- 継続ブランチ: `codex/safe-development-v1.0.0`
- Draft PR: https://github.com/tomomatsu0127-dot/igor2/pull/1
- 開始main SHA: `2c30ceffde11c4013bf496fced92f7da6d68ee49`
- 本体候補: `xrd_workbench_v1.1.0/`（利用者許可によりローカルv1.1.0から無改変取り込み）
- 対象: 管理文書、依存調査、3 Skills、静的検証・再開手順。本体ロジック/UI/データ構造の修正は対象外。
- 現在の問題: GitHubのigor2は.gitkeepのみ。別XRDはHTML/Python版でIPFなし。ローカルv1.1.0をブランチ上の正本化候補とする。
- 実.pxp: ユーザーはバックアップ済みと申告。実体・パス・採取値は未検証。Gitへ取り込まない。

## 完了した作業

- GitHubの両repoのmain/ブランチ/releaseを確認。IPFの不在を確認。
- igor2のmainから継続ブランチを作成。
- 本体候補の無改変取り込みとハッシュ一覧作成。
- AGENTS / STATUS / LOGを作成。
- 依存調査とIgor 9.05用の実機比較手順、再開手順を作成。
- Safe Update / Data Compatibility / Performance Debugをrepoとユーザー用に配置。3件ともCodexが検出し有効（docs/SKILL_DISCOVERY_v1.0.0.json）。
- 全270ファイルのSHA-256保持、相対include63本、文書/Skills/リンク検査を実施。
- checkpoint 2 `4da023ee4bbfeec5159c371754f6746ba2d75d8b` をGitHubから新しいcheckoutへ取得し、905検査エラー0・cleanを確認。独立cloneでIPF改変を検出する失敗試験も成功。
- Draft PR #1を作成。最終チェックポイントSHAは本ファイルを含む `git log -1` またはPRの最新commitで取得する。

## 残りと次の操作

1. 継続branchをfetchし、本書・LOG・AGENTSを読む。未push変更とremoteのSHAを確認する。
2. 利用者の実.pxpと、その時点の旧IPF一式を特定する。原本ではなく新規の検証コピーを作る。
3. `docs/IGOR905_VALIDATION_v1.0.0.md` に従い、Igor 9.05で旧版基準→候補更新→別名保存→終了/再起動→再読込を比較する。両root、同定index/UID、参照revision、hkl欠損/Unknown、履歴・図を含める。
4. 旧IPF/元測定/参照フォルダに到達できない別検証環境で外部依存試験を行う。原本の移動・削除は不要。
5. 未確認が解消してからPRレビュー・main採用を判断する。現時点では本体候補の互換性は未確認なので、Draftのまま継続する。

## 未解決事項（コードは変更していない）

- 実.pxpのProcedureが外部参照か採用済みか、独自Procedure/共有Waveの依存は未確認。
- 相対includeはIgor/User Filesを先行探索するため別版混入の実機棚卸しが必要。
- 本体版・project version・schemaVersionの意味が混在し、起動時移行/再構築に注意が必要。
- 自動保存は3世代循環。既存の不変バックアップと旧IPF一式を保持する。
- 実機での性能計測とSkillsを使った実デバッグは未実施。今回は仕組み・構文・検出の確認まで。

再開時は最初にremoteをfetchし、本ファイルとログの新しい記録を確認する。チェックポイントのSHAは `git log -1` とremote branchで取得する。
