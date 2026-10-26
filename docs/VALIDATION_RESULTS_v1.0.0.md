# 開発基盤 検証結果 v1.0.0

2026-10-26 JST / Windows / Codex desktop。今回はアプリケーションの実行試験ではなく、保存・配布・再開の基盤を検証した。

| 項目 | 結果 | 根拠 |
|---|---|---|
| 元フォルダとのコピー一致 | 合格 | 270ファイルのバイト数とSHA-256一致。docs/BASELINE_MANIFEST_v1.0.0.json |
| GitHub保存後の再取得 | 合格 | checkpoint 2 (4da023ee4bbfeec5159c371754f6746ba2d75d8b) をネットワーク経由で新規cloneし、905項目エラー0、git status clean |
| 相対include | 合格 | 本体40本と試験23本、合計63本すべてファイル存在。実Igorの探索先競合は未確認 |
| 標準外部include | 存在確認 | Peak AutoFind v5.15をIgor 9インストール内で確認。製品コードは転載しない |
| Skills構文 | 合格 | skill-creatorのquick_validate.pyで3件合格。PyYAML 6.0.3をscratchへ導入しPython -X utf8で実行 |
| Skills認識 | 合格 | ローカルCodex app-server skills/listの再走査で、3件ともscope=repo/user・enabled=true、エラー0。docs/SKILL_DISCOVERY_v1.0.0.json |
| Skills使用準備 | 合格 | SKILL.md本文を明示読込して今回の調査・範囲制御・未確認の区別へ適用。実Igor上の修正能力の試験とは別 |
| 改変検出 | 合格 | 独立した試験cloneのxrd_main.ipfだけにコメントを加え、検査がSHA/サイズ不一致と終了コード1を返すことを確認。原本・本番checkoutは変更せず |
| 実験データの追跡禁止 | 合格 | 追跡対象にpxp/uxp/ibw等なし、.gitignoreで保護 |
| 文書リンク・git差分 | 合格 | 相対リンク検査、git diff --check |
| main保護運用 | 合格 | 専用branchとDraft PR #1のみ。mainへのpush/mergeは実施せず。サーバー側branch protectionは開始時未設定のため、これは運用規約であり強制設定ではない |

最終管理文書追加後の検査結果はWORK_LOGのcheckpoint 3に記載する。過去の本体同梱TEST_RESULTSの326合格を今回の合格数に含めていない。

## 未確認

- 利用者の.pxp実体・バックアップ内容とProcedure保存状態。
- Igor Pro 9.05でのコンパイル、更新前後の全同定値比較、別名保存後の終了・再起動・再読込。
- 元IPF/測定/参照へ到達できない別環境での実.pxpの動作。
- 独自Procedureの文字列パス、共有Wave、長時間・大量データ・メモリ/描画/再計算性能。
- デスクトップのSkill選択UIでの手操作。機械検出とenabled値は確認済み。

具体的な次の試験はdocs/IGOR905_VALIDATION_v1.0.0.md。合格確認前にmainへ統合しない。
