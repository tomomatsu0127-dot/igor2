# WORK_STATUS — v1.2.5 / 2026-10-30 JST

管理版: 1.7.1。修正・native/UI・実PXP保存再起動確認・指定PXP適用完了。main未統合。

- Branch: codex/xrd-v1.2.5。開始SHA: 2694482a48f43f8e88bf8869a50f58a9b2059d90 (v1.2.4)。実装先 xrd_workbench_v1.2.5。
- 依頼: プロジェクト名変更での停止、管理画面の関連操作、スクロール後の検出ピーク選択ずれ。利用者は現行Igor終了と現在のQS_v1.2.4への適用を明示許可。
- 再現: 現行IgorでMissingParametersDialogがfloating manager背後に隠れ入力待ち。取消で復帰。旧版の人工60ピークで35度を実クリックすると37度を選択。native callbackでevent4 row20/top15→top17→event4 row22/top17→top19と確認。
- 原因: v1.2.4のmodal guardは管理の改名/削除/復元をカバーせず。XRD100_SelectがListBox選択callback中にrowを変更し同じクリックのhit testをずらす。
- 修正: manager modal dispatchに共通guard、登録入力エラーにも既存guard。listからの選択だけ表示top rowを維持し、graphからの選択は従来の追従。
- 保持: 旧版全ファイルhash、利用者のディスク保存版・実メモリからの別名バックアップと旧依存一式を非公開ローカルへ保存。元測定/参照/sourcesへ変更なし。解析・schema変更なし。
- native: 新版26、既存同定・コピー102、管理core19のassertion合格（計147）。実UIで35度クリックとホイール後67度選択、改名/取消/不正名警告、削除No/Yes、空復元/実復元、日本語名、登録エラー、ファイル選択取消を確認。管理画面1枚、RTE=0。
- 実PXP: 最新メモリ状態のコピー589850項目を全比較。表示/自動保存案内のみの差分。元の最大化と寸法を保持して別名保存・専用Igor終了/再起動/再読込し、元との違いは案内文1件だけ。科学値・同定・参照・履歴・依存式不変。指定どおり現在の同名PXPへ適用し通常Igorで起動。原本/直前版/実メモリbackupと旧依存一式を保持。研究データは非公開。

# 保持した前版記録

# WORK_STATUS — v1.2.4 / 2026-10-29 JST

管理版: 1.6.1。修正・人工データ検証・配布完了。main未統合。

- Branch: codex/xrd-v1.2.4。開始SHA: fb0c031 (origin/codex/xrd-v1.2.3)。実装先: xrd_workbench_v1.2.4。
- Scope: プロジェクト追加・参照追加/追加確認で操作不能に見える問題。
- 原因: Igor 9.05で大きなfloating補助パネルがDoAlert/DoPromptを隠して応答待ちになる。さらに実操作ではDoWindow/Kが元のmanagerを残してmanager0が生成されることをnative WinListで確認。
- 実装: xrd_modal124で必要な入力/確認/フォルダ選択中だけvisibleなXRD floatingを退避して同じobjectを復帰。追加処理はcallback終了後に実行。manager/libraryの再構築前閉鎖にKillWindow/Zを使用。計算・schema不変。
- 変更: 本体46 IPF中8（追加1）。main/reference/library/tree110/v80_ui/modal124と表示版番号ui/ui120。旧版全ファイルSHAはdocs/BASELINE_FOR_v1.2.4.json。
- 最終native: 退避/復帰17、寸法247、既存同定・コピー等102、計366合格・失敗0。tests/results_v124。
- UI: 実クリックで旧版を再現。新版で入力・確定・取消・OK/No/Yes、参照フォルダ選択と4件取込。最終コードで追加後も再操作でき、nativeでmanagerが1枚だけ、RTE=0を確認。
- 互換性: 模擬v1.2.3 PXP185889項目が読込前後・初期化後・別名保存/終了/起動/再読込後すべて一致。利用者の原本・sources・旧版を変更しない。
- 未確認: 利用者実PXP、全DPI/モニター、長時間・大容量、独自Procedure、旧パス遮断環境。速度改善率は未測定。
- 配布: ワークスペース直下xrd_workbench_v1.2.4/、ZIP/sha256。229ファイル、本体46 IPF、相対include75本、HTML参照/全ZIPエントリSHA一致。ZIP SHA256=f65ad17ec2261303b9f8207b29de8fd702b892ed63041e67460d5eade86eb3cf。旧v1.2.3 repo baselineと旧配布ZIP全ファイルも不変。
- 再開: 本branchをfetchし本ファイルとWORK_LOG末尾、TEST_RESULTS_v1.2.4を読む。追加変更は次の番号版へ。mainへ統合しない。

# 保持した前版記録

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
