# WORK_STATUS / XRD Studio v0.2.0 implementation / 2026-10-29 JST

管理版: 1.7.0。今回の依頼は設計に加えてIgorの前提機能を含む独立ソフト実装の開始。

- Branch: codex/xrd-studio-v0.2.0。開始SHA: a48f5558a88ef40c8eeb690ff853082a5887f9f5。
- 新規実装先: xrd_studio_v0.2.0。旧Igor版と独立v0.1.0、未追跡v0.1.1を保持。
- 設計基準: XRD Workbench v1.2.3、52機能の設計v1.0.0。XRD専用。PXP直接読込は必須外。
- 今回: Qt UI、Wave相当の原値閲覧/作業コピー編集、カーソル/ズーム/軸書式、管理/Undo/保存/復旧、既存数値解析接続を先に動かす。Igor汎用の全コマンド互換実装ではない。
- 独立エンジンv0.1.0を再利用し、schema1読み込みとschema2新規保存を検証する。原測定/参照は変更しない。
- 基盤実装、41試験、schema1/2の別プロセス比較は完了。EXEはICU同梱衝突を修正して再検証中。設計検査の過去207項目をアプリ合格へ数えない。

---

# WORK_STATUS / XRD独立版設計 v1.0.0 / 2026-10-29 JST

管理版: 1.6.0。今回の設計を完了。本体実装は未着手。main未統合。

- Branch: codex/xrd-standalone-design-v0.2.0。開始SHA: fb0c031093659db9db2562753dd0a0bd34561e4e（Igor最新版 origin/codex/xrd-v1.2.3）。
- Scope: 現行XRD機能を基にIgor不要の単一ソフトを設計。ユーザー最新訂正によりXRDのみ。M-H/M-T統合は今回の対象外。Excelは任意入出力。
- 調査: 45本体IPF・604関数・14,632行。入口/起動/外部Peak AutoFind/保存・変更経路を確認し52機能へ整理。
- 成果: docs/xrd_standalone_design_v1.0.0に15ページPDF、編集用Markdown、根拠関数/行番号/本体ハッシュのJSON、静的検証記録、README。
- 判断: Python/PySide6 + NumPy/SciPy/Matplotlibを第一候補、自己完結.labx、任意XLSX、固定IDと参照版、図snapshotを設計。単一インストーラーと起動アプリを基本とし、portable EXEは別の配布評価とする。
- 再利用: 保存済み独立v0.1.0の8モジュールをremoteと照合。元素は部分文字列検索、横断比較は保存検査が同一Projectへ制限、type別カード/全証拠表/複数図等が不足。完成版と見なさない。
- 検証: 設計資料の207静的検査合格。全根拠関数と行番号、45本体ハッシュ、配布との正規化本文一致、8試作モジュール一致、PDF15ページのテキスト/余白/52IDを検査。全ページをPNGで目視確認。
- 未確認: 新アプリ実装、Igor実行、実測比較、クリーンPC、性能。記載した許容差/負荷/応答値は提案目標であり測定結果ではない。
- 保持: 既存開発checkoutの未追跡v0.1.1、旧Igor版、旧独立版、sources、利用者測定/参照/PXPには変更なし。既存Igorへ接続しない。
- 次: 設計を読み、文書・保存・試料ツリー・4段階画面・読込をつなぐ実装単位へ進む。実装開始時は新番号版と別のアプリ変更ブランチを使う。

---

# 以下は保持したIgor版の状態

# WORK_STATUS — v1.2.3 / 2026-10-29 JST

管理版: 1.5.1。修正・人工データ検証・配布完了。main未統合。

- Branch: codex/xrd-v1.2.3。開始SHA: 971cb8d (origin/codex/xrd-v1.2.2と一致)。新規実装先: xrd_workbench_v1.2.3。
- Scope: 操作中のウィンドウ寸法維持のみ。科学計算・保存schema・元測定/参照は変更しない。
- 再現: v1.2.2で最大化Workbenchからライブラリを開くとMDI最大化が新規パネルへ移り、Workbenchは通常寸法へ戻る。ライブラリ/管理/元素表の再表示は利用者調整寸法を初期値へ戻す。
- 実装: 補助パネルをIgorのfloating panelとして開き、MDIの最大化を移さない。更新前の座標・寸法を同じパネルへ復元し、構築終了時に_endfloat_で暗黙targetを解除。管理/作図の再レイアウトで固定MoveWindowを呼ばない。
- 実装補足: 補助パネル25作成箇所を統一。本体45 IPFのうち26変更（追加1）。作成直後にfixedSize=0を指定し、sizeLimitを持つ既存UIとも互換。管理操作のwindow path更新もfloatingを含める。
- 最終確認: Igor 9.05でサイズ247、配置/ステップ343、既存回帰102、閉鎖18、Undo/自動保存41、別プロセス実再読込12、合計763合格・失敗0。最新ログはtests/results_v123。全て今回実行した結果。
- 互換性: 模擬v1.2.2 PXPの185889項目を全比較。旧画面閉鎖hookによるuiActiveChild1件は旧版対照群と同じ。それ以外不変。新版初期化前後、別名保存・専用Igor再起動・再読込の185889項目は完全一致。
- 配布: ワークスペース直下xrd_workbench_v1.2.3/、ZIP/sha256。220ファイル、本体45 IPF、相対include73本、HTML参照/ZIP全バイトのSHA検証成功。ZIP SHA256=f31c5a1ada0f5e93016574d1908ecfab784f38440aac607a72b158338832c36b。
- 旧版保持: repo全ファイルのbaseline、配布v1.2.2 ZIPのSHAと全エントリを照合し不変。sources/利用者PXP/研究データ/既存Igorには変更なし。
- 未確認: 利用者実PXP、全DPI/モニター、実キーボード/マウスfocus、長時間。旧版/sources/既存Igorを変更しない。
- 制限: 補助画面は主画面の前に表示される。開いている間の更新で寸法を維持し、×後の新規表示は初期サイズ。図/表/ガイド新規表示や明示した図サイズ操作は従来どおり。hiddenな専用IgorはComputer Useへtargetを返さず、実入力は未実行。
- 次: 本branchをfetchし、TEST_RESULTS_v1.2.3とWORK_LOG末尾を読む。追加変更は新しい番号版から。旧版や今回配布を上書きしない。

# 保持した v1.2.2 記録

管理版: 1.4.1。状態: 今回のデバッグ・修正・模擬データ検証・配布完了。main未統合。

- レビュー: Draft PR #3 https://github.com/tomomatsu0127-dot/igor2/pull/3 （base=codex/xrd-v1.2.1）。
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
