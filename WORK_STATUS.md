# WORK_STATUS — v1.2.2 / 2026-10-29 JST

管理版: 1.4.1。状態: 今回のデバッグ・修正・模擬データ検証・配布完了。main未統合。

- 継続ブランチ: codex/xrd-v1.2.2。開始SHA: 3c74fca (最新取得のIgor v1.2.1)。実装先: xrd_workbench_v1.2.2。
- 修正: 最大化時に測定選択ボタン幅2076が再度2倍となるエラー200を修正。表示更新の二重呼出しと起動時の重複初期化を削減。
- 利用者追加方針: 再生成できる作業画面・図・表・生成ガイドを/K=1で作成し、閉じる確認を省略。トップレベル42作成箇所を統一。カーソル/画面・手編集図の保持を確認。既存画面は新版で開き直す。閉じた画面はF6/保存済み作図から再表示。解析Undoは保持、閉じる操作自体のUndoは未追加。
- 本体44 IPF中23変更。うち多数は/K=1フラグのみ。科学計算・保存schemaは変更なし。
- Igor 9.05最終: 配置343、既存回帰102、閉鎖/再表示18、Undo/自動保存41、計504合格・失敗0。全最終ログをtests/results_v122へ保持。
- 互換性: 模擬v1.2.1 PXPの185888項目はコード読込前後完全一致。XRD_Open後185889項目は旧版初期化の独立対照群と完全一致（初期値との差はliveBusy=0追加のみ）。別名保存・専用Igor再起動・再読込で185889項目完全一致。
- 性能: 20試料x2001点、5組。20回更新中央値1321.05→901.21ms、Open170.882→156.526ms。前者約32%減。状態/選択/警告は各2→1回、OpenのInit3→2回。実データ性能・長時間メモリは未測定。
- 配布: 利用者ワークスペース直下xrd_workbench_v1.2.2/とZIP/sha256。205ファイル、相対include70本、ZIP全ハッシュ照合成功。SHA256: 8d8b82d859117a7df367680fce8ac0187fdfdeab7ba513a309d6d3e7a25f5095.
- 保持: 元の配布v1.2.1は当時ZIPのSHAと186全ファイルを照合して不変。repo旧版の全ファイルもbaseline SHA一致。sources/利用者PXP/研究データへ変更なし。
- 未確認: 利用者実PXP、全DPI/モニター、長時間/大容量、旧パスを遮断した別PC、独自/採用済みProcedure。実際の×クリックはWindows GetCursorPosアクセス拒否0x80070005で未実行。標準/K=1とネイティブ閉鎖・再表示は確認済み。
- 再開: 本branchをfetchし、TEST_RESULTS_v1.2.2、CHANGED_FILES、WORK_LOG末尾を読む。新規番号版から追加修正する。今回の配布ZIPや旧版を上書きしない。

以下は保持した以前の記録です。

# v1.2.1 screen transition fix / 2026-10-27 JST

- Branch: codex/xrd-v1.2.1, base 93e92d001cf0df22d834bfb6cbb7fc3d80394966.
- Scope: Igor Workbench screen transitions only. New release xrd_workbench_v1.2.1.
- Reproduced: parent dimensions/maximize unchanged; XRD_ViewSync forces a DoUpdate while controls/graphs are still at baseline geometry, before XRD_RememberControls/XRD_ResizePanel.
- Plan: gate graph view synchronization during construction, synchronize after final layout. Schema/analysis unchanged.
- Implemented: invalidate XRDLayoutReady before rebuilding; skip XRD_ViewSync until final geometry; synchronize once after layout/cursors/Y-lock. Four application files changed including version tags.
- Native: 101 new assertions pass, 102 existing regression assertions pass. Known pre-existing maximize ModifyControl size warning 200 reproduced on old/new; not fixed in this scope.
- Local 173-file baseline is authoritative for distribution bytes; Git source content matches with 85 line-ending-only differences.
- Validation complete: preinit 185,811 identical; postinit 185,888 identical to unmodified-old initialization control; actual save/restart/reopen 185,888 identical.
- Delivered to user-specified workspace root: xrd_workbench_v1.2.1/ and ZIP (186 files, 68 local includes). ZIP SHA256=6fe743339308aea143cfae8efd6a5af1d060b181619919b7c17b70d4870ad057.
- Runtime/source change complete; user real PXP/all DPI and existing maximize size warning remain unverified/unresolved as documented. Main not merged. Resume this branch, read current reports; diagnostics remain local only.

# WORK_STATUS

管理版: 1.2.0 / 2026-10-27 JST

- 状態: v1.2.0の実装・模擬PXP互換性・最終回帰・ローカル配布作成を完了。main未統合。
- 継続ブランチ: codex/xrd-v1.2.0
- 基準SHA: f45dfb5（codex/safe-development-v1.0.0）
- 基準本体: xrd_workbench_v1.1.0。新規修正先: xrd_workbench_v1.2.0。
- 今回の範囲: Workbench更新時の縮小復帰、強い参照反射の確認、同定Y軸固定、操作メニューサイズ、単一の編集可能な凡例、比較対象の厳密選択、他Project同定済み試料の複製、入力欄の一方向連動、更新手順。
- 原因: XRD_Panelが毎回DoWindow/K→初期サイズNewPanel→RestorePanelState。XRD100_Zoomが局所強度でYを再設定。比較は編集試料を強制追加。凡例は複数Legendを新規作成。Popup本文は10ptの別設定。
- 元のv1.1.0、sources、原本測定・参照・利用者Experimentを変更しない。基準270ファイルのSHAをdocs/BASELINE_FOR_v1.2.0.jsonに保存。
- 実装: 画面と同じグラフの再利用、Y固定、単一凡例、読める操作メニュー、比較対象選択、コピー・入力連動を実装。
- 確認: Igor 9.05ネイティブ281項目で失敗0・実行時エラー0（本版102、実再読込12、管理61、欠損hkl57、Undo/保存41、格子8）。コピー6故障点の復元、空比較復帰、表拡大時の配置も確認。
- 互換性: 模擬v1.1.0 PXPをコピーして新版へ切替え、保存後に別プロセスで再読込。初期化前86,796項目すべて一致。初期化後86,828項目、想定した表示設定97件以外の差0。保存後の再起動で86,828項目すべて一致。旧版270ファイルのSHA一致。
- 性能: 同一模擬負荷の6回更新3組で親画面の再生成6→0回、更新中央値618→132ms。実環境の速度保証ではない。
- 配布: ワークスペース直下xrd_workbench_v1.2.0と同名ZIP。173ファイル、相対include67本とマニュアル参照を検査、ZIP内全ハッシュ一致。ZIP SHA256=5060ead927040743f9bbd0cb8aeba6ea61fbcd94885d218494d33e67068e359c。
- 検証手順の事故: 接続確認失敗時に既存Igorへ終了要求を送った。利用者へ告知・謝罪済み。その後、開始時と同じPID39124・起動日時のIgorが稼働中と確認した。原本上書きなし、未保存内容は未確認。以後の停止はこの実行で作成したPIDのみに限定。
- 次: 利用者は旧PXP/IPFを保持して別名PXPで新版へ切替え。今後の変更は本ブランチの最新SHAから再開。実データ・全DPI・長時間の確認は別途行う。
- 未確認: 利用者の実.pxp、全DPI・実マウス操作、長時間連続運転。
