# WORK_LOG

管理版: 1.0.0。日時はJST。古い記録を消さず追記する。

## 2026-10-26 / checkpoint 1: baseline and recovery records

- 開始: igor2 main `2c30ceffde11c4013bf496fced92f7da6d68ee49`、XRD main `98d1d0268905f0a4d3e0cdd5bf44c020432aaa45`。
- 確認: 各repoの全branch一覧はmainのみ、releaseは0件、再帰treeはtruncated=false。igor2=.gitkeepのみ、XRD=HTML/Python版、両方IPFなし。
- 判断: 空のigor2へ管理基盤を作成。ユーザーがローカルv1.1.0の専用ブランチへの取り込みを許可したため、無改変で正本化候補として保存する。別XRDや元データを削除する必要はない。
- 変更: AGENTS.md、WORK_STATUS.md、WORK_LOG.md、README.md、.gitignore、.gitattributes、候補本体、原本とのSHA-256一覧。
- 確認: コピー時に全ファイルをbyte単位SHA-256照合。実行数は後続検証記録へ記載する。
- 未確認: 利用者の実.pxp、Igor 9.05上での更新・再起動、本体のmain採用。過去同梱の試験結果は参考記録。
- 次: 依存調査、Skills、管理基盤の検証を進める。

## 2026-10-26 / checkpoint 2: dependency evidence and skills

- checkpoint 1のGitHub保存SHA: `c3655396600a8118598d192dc9e3284c21a6a137`。remote一致確認済み。
- 変更: docsの依存報告、Igor実機試験手順、再開手順、3 SkillsとUI metadata、読取専用の管理基盤検査スクリプト。
- 判断: .pxp保存だけで外部IPFが不要とは判断しない。初期化による移行・参照追加走査・2系統rootと内部の参照index対応を保持対象として記録した。アプリのバグ修正やデータ構造変更は行わない。
- 根拠: 本体コードとIgor 9付属Manual II-16/25、III-400–401、IV-166–167、AdoptFiles V-23–24。Web公式仕様も照合。Web PDF取得はtimeoutしたが、インストール済みIgor 9 Manualをローカルで読み確認できた。
- 静的確認: 初回902項目エラー0、原本270ファイル完全一致、相対include63本（本体40本+試験23本）すべて存在、標準Peak AutoFind v5.15の存在を確認。
- Skills: quick_validate.pyで3件合格。最初はPyYAML不足、次にWindowsの既定cp932読込で失敗した。検証用scratchへPyYAMLを導入し、Python -X utf8で解消。既存のシステムSkillやPython環境は変更していない。
- 認識: 当地Codexのapp-server skills/list（read-only、agent実行なし）で3件ともrepo/user scopeでenabled=true、エラー0。repoと公式の~/.agents/skillsへ配置。試験で作成した従来~/.codex/skillsの重複コピーは内容一致を検査して除去した。結果はdocs/SKILL_DISCOVERY_v1.0.0.json。SKILL.md本文の明示読込も確認した。
- 初回commitでGit author未設定のエラーが出たため、接続済みアカウントのnoreply identityをrepo-localに設定してcommit/pushを完了した。global設定は変更していない。
- 未確認: 実Igor 9.05での実行、利用者.pxpの保存/再起動/同定一致、Skillsの実機デバッグでの有効性。構文・検出・指示本文を確認したことと実機機能保証を区別する。
- 次: GitHubからの新規checkout復元検証、改変検出試験、最終記録とDraft PR。

## 2026-10-26 / checkpoint 3: verified resumption and draft review

- checkpoint 2の保存SHA: `4da023ee4bbfeec5159c371754f6746ba2d75d8b`。
- 復元試験: GitHubから新規cloneしたtmp/igor2_resume_check_v1で同じSHA、git status clean、管理基盤検査905項目エラー0を確認。元IPFの改行・encodingを含む270ファイルを保持したまま再開可能。
- 失敗検出試験: 別clone tmp/igor2_negative_check_v1のxrd_main.ipfにだけ検証用コメントを追加し、検査がBaseline changed/size changedと終了コード1を返すことを確認。意図した失敗のため、この試験cloneは継続開発に使わない。
- 変更: STATUSを次回の実.pxp検証待ちへ更新。VALIDATION_RESULTSを追加し、READMEからリンク。
- 最終静的検査: 906項目、エラー0。3 Skillsの構文/検出はcheckpoint 2で合格、原本とアプリコードは以後変更なし。git diff --check合格。
- GitHub: Draft PR #1 https://github.com/tomomatsu0127-dot/igor2/pull/1 を作成してチャットに添付。作業区切りごとにbranchへ保存。mainの開始SHAは保持。
- 判断: 開発基盤の整備は完了。正本化候補のmain採用と実.pxp互換性保証は別の未完了事項。ユーザーの「GitHubの中身を全部消してよい」は許可として受け取ったが、作業に不要な削除は行わず、別XRDの既存実装も保持した。
- 次: AGENTS/STATUS/LOGを読んで継続branchを取得し、Igor 9.05で利用者の複製.pxpの基準採取と更新・保存・再起動比較を実施する。現在のチェックポイントSHAはgit log -1またはPR最新commitから取得する。

## 2026-10-27 / v1.2.0 investigation checkpoint

- 基準: fetch後、safe-development branchのHEAD/remoteがf45dfb5で一致。mainへは反映しない。新しいcodex/xrd-v1.2.0へ分岐。
- Skills: Safe Update、Data Compatibility、Performance Debugを明示読込。調査対象と上書き禁止を確認。
- 原因: XRD_Panelの毎回の初期サイズ再生成、ZoomのY再計算、比較への編集試料強制追加、別Legend列、Popup本文の別フォント設定をコードで確認。
- 方針: 解析ロジックを置換せず、画面の再利用・表示設定を分離する。参照の主/第2強度反射を全測定範囲で照合し、他相との重なりを一致として扱った上で採用前に確認。
- 他Projectからの追加は元を保持した同定済み試料の複製とし、新しい測定UIDを与える。参照ライブラリは共通のまま保持。
- 検証: まだ新版本体の実行確認なし。旧本体の全ファイルSHAを保存した。これから最小修正、別Igor実行、PXP実再起動比較。

## 2026-10-27 / v1.2.0 implementation checkpoint

- 変更: xrd_ui120/reference120/transfer120を追加。親フレームを残して必要内容だけ更新し、同じ画面の操作はグラフも再利用。Y固定をUndoの操作として記録しない。
- 変更: 主・第2反射の確認（範囲外除外、他相と重なる登録ピークは一致）、採用前の確認と常設表示。凡例をネイティブ1ボックスへまとめ、共通フォントとマウス用スライダーを追加。
- 変更: 比較選択をProjectごとに保存し編集試料の強制追加を廃止。他Projectの同定済み試料は新UIDで複製、元を保持。入力は番号→表示名→組成、表示名から組成だけへ反映。
- 検証: Igor 9.05の単体96項目で失敗0。コピーの故障復元・欠損hkl・Unknownも確認。6回更新の3組でフレーム再生成6→0、中央値617.655→132.356ms。
- 互換性: 全項目TSVを旧版コピー、新コード初期化前後、別名PXP保存・別プロセス再起動後で比較。86,796項目採取、解析・保存データ28,886項目は一致。初版検証で表示Yの既定値変更がUndoを1件消費したため、表示基準だけ更新し再試験で解消した。全変更差分はUIと既存初期化でのリスト末尾整形に限る。
- 注意: TSVは日本語を含むバイト列をパーセント符号化し、出力時の文字コード変換を避けた。過去試験の数値を今回の合格数に加えない。
- 事故: 検証helperの接続確認失敗時finallyにQuitがあり、既存Igorへ終了要求を送ってしまった。利用者へ告知済み。原本ファイルへの上書きはしていないが未保存状態の保持は未確認。helperは起動したPIDだけ停止するよう修正し、一意な接続マーカー確認前にはExperimentを開かない。
- 次: 空比較から復帰するケース、保存後の設定/複製結果、既存機能回帰、マニュアル2種、ZIP/マニフェスト、最終checkpoint。

## 2026-10-27 / v1.2.0 final validation and local distribution

- 実装checkpoint: 114273f。最終変更は空比較→再選択の復帰、コピー失敗時の内部依存解除、表示名再フォーカスでの組成保護、表専用モードの警告/リスト配置、登録画面下端の余裕。追加の画面構築フラグ案は回帰を起こしたため撤回し、採用していない。
- 試験の不具合: 旧管理試験が存在しないAssignments:hを参照していた。正しい保存列refPeakIndexへ試験だけ訂正。本版のコピー試験でもhklは共有参照の反射行を通して検証するよう訂正。保存schemaを変えた対応ではない。
- コピーの失敗注入で、内部の別名Wave依存があるとKillDataFolder/Zだけでは撤去できないことを確認した。新しく作成したコピーに限って依存式を解除し、厳密なKillDataFolderで撤去。全6mutationで半端な試料が残らず、ロック解除と元データの保持を確認。
- Igor 9.05最終実行: 本版102、別プロセス実再読込12、管理61、欠損hkl57、Undo/自動保存41、格子8。計281項目合格、失敗0、実行時エラー0。旧版から持ち越したログを計上しない。
- 完全比較: 新しいcompat_1831940809に旧PXPをコピーし、初期化前86,796記録全一致。初期化後86,828記録の97差分はUI/比較設定・既存文字列末尾整形・Y表示基準のみ。別名保存後に専用Igorを終了・起動して再読込、86,828記録全一致。Raw/Processed/Peaks/Assignments/参照UID/revision/hkl/Registry/格子履歴/Undo/保存図を含む。比較helperは差分を明示し想定外の差を失敗にする。最初の期待値112は実際の17桁表示112.00000000000001へ訂正した。
- 目視: 同定3試料、警告・表・大きい操作ボタン、単一の2列凡例、登録画面の順序と下端をIgor画像で確認。GUI操作そのものを全部実マウスで行ったとは報告しない。
- 性能: 同一模擬負荷の6回更新3組。旧681.832/602.512/617.655ms、新172.452/114.886/132.356ms、フレーム再生成6→0。実環境での速度保証ではない。
- 文書: 初心者向けと更新向けHTML、README、変更ファイル、検証結果、今回だけのログを作成。旧図の手編集を勝手に再生成しないこと、コピーは独立・管理バックアップ扱いであることを記載。
- 配布: 直下xrd_workbench_v1.2.0とZIP。173ファイル、IPF44、相対include67本、マニュアル参照正常。元測定・参照、ユーザーPXPや試験PXP・大きいTSVは含めない。ZIP展開内容の全SHA一致。SHA256=5060ead927040743f9bbd0cb8aeba6ea61fbcd94885d218494d33e67068e359c。旧版270ファイルは基準SHA一致。CRLFを意図的に保持しているためgitの差分空白検査はcr-at-eolで実施し合格。
- 事故の追加確認: 既存Igor PID39124、起動日時2026-10-26 17:59:01、タイトルQSが引き続き稼働していることを確認。終了要求を送った誤りは撤回できないが、アプリが閉じた・未保存状態が失われたと断定しない。helperは専用PID以外を停止せず、接続マーカー確認前はPXPを開かない。
- 未確認: 利用者の実PXP、全DPI/モニター移動、実マウスの全操作、長時間運転、採用済み/独自Procedure付きPXP、旧パス完全遮断環境。mainへ統合しない。
- 次: 最終checkpointをcodex/xrd-v1.2.0へpushし、ローカルZIPと更新ガイドを渡す。

## 2026-10-27 / v1.2.0 delivery checkpoint

- 5058d7dをcodex/xrd-v1.2.0へpush済み。mainは変更していない。配布ZIPは前項SHAと一致。
- 差分の空白検査補足: コード・文書はcr-at-eolで合格。Igorの故障注入結果Printには空のエラー文字列を表す末尾空白が6行あり、出力を保持したため全ログを含める検査はその6行を報告する。コードの不具合・試験失敗ではない。コード・文書だけを対象にした最終検査は合格。
- 利用者へ渡すもの: ワークスペース直下のZIP、更新HTML、初心者HTML、変更ファイル/試験結果。次の開発は本branchの最新SHAを取得して再開する。


## 2026-10-27 / v1.2.1 investigation

- Isolated branch/checkout from latest Igor branch; standalone working changes untouched.
- Baseline hashes recorded. Instrumented copied v1.2.0 in diagnostics only. Igor 9.05 /I probe: 1867x926 restored and 1924x987 maximized remained identical through rebuild (RTE=0).
- Cause: XRD_DrawMeasurementGraph/DrawPeakFocus -> XRD_ViewSync -> DoUpdate before final layout. Controls and graph constructed with baseline coordinates, then enlarged by XRD_ResizePanel.
- No user Experiment/active Igor instance was opened, saved or closed.


## 2026-10-27 / v1.2.1 implementation checkpoint

- User specified workspace root source. All 173 local files match Git content; 85 differ only by CRLF/LF. New release copies unchanged local bytes; LOCAL_BASELINE_FOR_v1.2.1 records original hashes.
- Four application files: xrd_ui (invalidate geometry before clear + final ViewSync), xrd_v51 (do not force update until layout ready), xrd_main/ui120 (1.2.1 version). No schema or algorithm changes.
- Native new assertions 101 pass. Existing v120 regression 102 pass, failures=0, no runtime error. Initial attempts had a test syntax error then missing external missing_hkl120 fixture; fixed harness, not application. Failed attempts retained locally.
- Paint probe old: width166 at panel1867; new: width455 at panel1867. Final geometry is used on first forced update.
- Existing maximize ModifyControl;Size out of range (200) reproduced identically old/new (12 transitions). Not attributed to this patch; recorded as separate unresolved issue.
- Full synthetic PXP comparison: preinit 185811 records identical, save/restart 185888 identical. Postinit changes under review against identical old-version initialization control.


## 2026-10-27 / v1.2.1 validation and delivery

- Compatibility control finished: initial 185811 records unchanged by loading new procedures; after initialization 185888 records exactly match independent v1.2.0 initialization of the same synthetic PXP. 180 initial cache changes are identical under old/new. Save/restart/reopen 185888 records exactly match. No scientific data changes.
- Baseline new test on original v1.2.0 fails the unfinished-layout protection as expected (and the intentionally new version check). Existing ModifyControl size warning 200 is identical on old/new; not introduced by this patch. Detailed old/new logs retained in results_v121.
- Packaged user local-source bytes, with 4 changed production IPFs and updated docs/new evidence. 186 files, 44 production IPFs, 68 relative include edges verified. HTML links/anchors checked. Original local 173 file hashes remain identical. ZIP every entry hash matched output directory.
- User workspace root receives xrd_workbench_v1.2.1/, xrd_workbench_v1.2.1.zip and .sha256. ZIP 1071225 bytes, SHA256 6fe743339308aea143cfae8efd6a5af1d060b181619919b7c17b70d4870ad057.
- No original user Experiment or sources modified. Dedicated /I processes only. No main merge. Real PXP, full DPI/monitors and animation frame-by-frame recording remain untested.
- Resume branch codex/xrd-v1.2.1; report final SHA from git. Change is complete within requested scope.

## 2026-10-29 / v1.2.2 investigation

- Latest remote Igor branch codex/xrd-v1.2.1 at 3c74fca confirmed with fetch and GitHub branch inventory. Standalone untracked changes preserved.
- Reused clean tracked checkout, new branch codex/xrd-v1.2.2, new release from delivered local bytes; complete baseline hashes retained.
- Auditing resize, deferred updates, entrypoints, autosave and include dependencies. Instrumentation restricted to scratch. No user data or existing Igor instance touched.

## 2026-10-29 / v1.2.2 implementation

- Instrumented old code identifies measurementLabel as the only generic resize error: 2076*2=4152 width, native error 200, 15 reproductions. Chooser uses final panel dimensions before RememberControls; XRD110_Layout already handles its final placement. Skip redundant generic scaling for this control.
- Call graph confirms XRD81_RefreshPeaks already updates status/chooser/warning/Y/live; return after its threshold binding in RefreshPanel. Removed second XRD_Init in XRD_Open new-window path (first Init remains). No algorithm/schema changes.
- Production files: xrd_main/ui/ui120/v44. Version 1.2.2. Native verification pending.

## 2026-10-29 / user close-policy addition

- User requested no close warning for regenerable windows/graphs. Use native /K=1 on XRD-owned top-level panel/graph/table/guide creation. No global Igor preference change and no Experiment close/save override. Existing managed plot kill hook retains native edits; normalize older stored graph recreation Display flags to /K=1 during replay.
- Analysis Ctrl+Z remains the existing analysis history; this change does not imply that Ctrl+Z restores a closed window. Workbench F6 and saved plot recipes are the reopen paths to verify.
- Performance measurement before close-policy changes: 20 synthetic measurements x2001 points, 5 timed runs after warmup. Refresh status/chooser/warning calls each 2->1, Init new-window Open 3->2. Timings retained in scratch; verification harness initial compile mistakes corrected (parameter declarations must precede instrumentation, globals need NVAR). Failed attempts not counted as passes.

## 2026-10-29 / native verification checkpoint

- Native layout matrix passes without errors, inherited v120 regression 102 passes, close/reopen lifecycle 18 passes. /K=1 verified in WinRecreation. Workbench close captures cursors before child destruction; managed plot kill hook captures manual annotation and replay retains it.
- Initial attempted DoIgorMenu File/Close cannot run from a function (native 627); test was corrected to lifecycle KillWindow plus /K flag check. Actual UI X close remains to verify.
- Compatibility source is prior synthetic validated v1.2.1 updated.pxp. Initial helper CloseProc waits of 150ms were too short; increasing to 2s lets old procedure close before new one is opened. No old/new code co-compiles in the successful run. Failed attempts retained only in scratch.
- Successful full compare: 185888 records unchanged before init. XRD_Open adds only UI:liveBusy=0; 185889 records identical after fresh save/process restart/reopen. Raw/Processed, assignments/Unknown/missing hkl, libraries/revisions, UIDs, history, formula metadata included. Old-version initialization control running.

## 2026-10-29 / v1.2.2 final validation and delivery

- 最終コード: 配置343、既存回帰102、閉鎖・再表示18、Undo/自動保存41=504合格、失敗0。原値・科学処理とUndoを保持し、自動保存の予定時刻/3世代/失敗復元も確認。
- 互換性: v1.2.1模擬PXP185888記録はコード読込前後全一致。起動後185889記録は旧版の独立対照群と全一致。別名保存後に専用PIDを終了・再起動・再読込し185889記録全一致。初期との差1件は既存Open経路のUI:liveBusy=0追加のみ。
- 実UI: 専用Igor PID13608、UI122Isolated=1221029のみを起動して試行。AXで対象画面は確認できたが、画像は黒く、Raise操作はGetCursorPosアクセス拒否0x80070005で入力前に拒否。×実クリックは未確認と明示した。専用PID/起動引数を照合して当該プロセスだけ停止。利用者Igorへ入力・接続・終了要求なし。
- 配布baselineの区別: 初期BASELINE_FORはrepo旧版全体のSHA。配布旧版はrepoの履歴ファイルを一部含まない186ファイルのため、当時ZIP SHA6fe743...と全エントリの一致からLOCAL_BASELINE_FORも独立採取。旧版を変更して差を解消していない。最初のpackage試行は履歴ファイル不存在で停止し、二つのbaselineを区別する検証へ訂正。
- 最終配布: 205ファイル、本体44 IPF、相対include70本、HTML参照/anchor成功、ZIP内全ファイルのSHA一致。ZIP1199567 bytes、SHA256=8d8b82d859117a7df367680fce8ac0187fdfdeab7ba513a309d6d3e7a25f5095。利用者ワークスペース直下へ新規v1.2.2ディレクトリとZIP/sha256。sourcesと原本は保持。
- 変更23 IPFの多くはネイティブ/K=1のみ。mainへ統合しない。実PXP・全DPI・実クリック・長時間/メモリ・別PCは未確認。次は本branchから新番号版で進める。

## 2026-10-29 / v1.2.2 review checkpoint

- 配布・検証checkpoint37ffa58をpushしremote一致。Draft PR #3 https://github.com/tomomatsu0127-dot/igor2/pull/3 をcodex/xrd-v1.2.1向けに作成し、チャットへ添付。main未変更。
- 利用者へはv1.2.2 ZIP、更新手順、検証結果を渡す。既存同定を保持して新番号版から再開。

## 2026-10-29 / v1.2.3 investigation and implementation checkpoint

- GitHub fetchでIgor最新版v1.2.2 / 971cb8dを確認。別作業のあるdevelopment checkoutを保持し、cleanなtmp/xrd-v1.2.1 checkoutでcodex/xrd-v1.2.3へ分岐。diagnosticsの未追跡資料も保持。
- Safe UpdateとData Compatibilityを読込。入口include/startup/既存UI保存処理を確認し、旧版全ファイルのSHAをBASELINE_FOR_v1.2.3へ採取。
- 原因をIgor 9.05で再現: MDI最大化が新規補助パネルへ移る、再作成時の初期寸法復帰、管理/作図controlsの固定MoveWindow。文字変更単独では寸法不変だったため、この処理は変更しない。
- 実装: 新規v1.2.3へ補助パネル/FLT=1、更新時geometry引継ぎと_endfloat_解除。科学処理・保存schemaは変更しない。native probeでWorkbench最大化とサイズが不変、library/manager/elementsのサイズ/位置不変を確認。
- 試験helperの引数不足、caseの同一行構文、Print内root変数直接参照を検出し訂正。失敗・timeoutはscratch保持、合格へ算入しない。独立起動したPID以外へ終了要求を送らない。
- 次: 回帰、操作matrix、模擬PXP再起動比較と配布。実PXP/全DPI/実focus操作は未確認。main未統合。

## 2026-10-29 / v1.2.3 final validation and delivery

- 初期checkpoint92d64d6をpush済み。最終ではfloating panelを作成直後にfixedSize=0へ設定し、既存libraryの選択時layout/sizeLimitとの衝突を解消。これが残すRTEで後続の管理backupが失敗することを回帰で検出した。計算処理は変更しない。
- 管理のWindowPathsは通常graph/panelに加えてfloating panelも捕捉し、改名時のXRDData等を保持。nativeで更新・復元を確認。図・プロジェクト画面のcontrols再配置から固定MoveWindowを除去し、作図の初回サイズはNewPanelへ移した。
- 最終Igor 9.05: 寸法247、配置/切替343、既存102、閉鎖18、Undo/自動保存41、別プロセスPXP再読込12、計763合格・失敗0。人工データ。途中の構文誤り/fixture不足待機/初期fixedSize不具合は最終合格へ混ぜない。
- 互換性: 模擬v1.2.2 PXPの185889項目をdump。画面閉鎖hookのuiActiveChildがXRDWorkbench#Pattern→XRDWorkbenchとなる1件は旧版対照群でも同一。新版の読込/初期化後は旧版対照群と完全一致。別名保存後に専用Igorを終了・起動し185889項目すべて一致。旧版からの科学値/UID/revision/Assignments/Undo/依存式の差なし。補助画面を保存した総合試験PXPも新プロセスで再読込し12項目合格。
- Computer Use skillを読込しsky.list_appsを使用したが、hidden/UNATTENDEDの専用Igorはtargetable windowを返さなかった。UI入力は実行せず、ネイティブcallbackとIgor生成画像の確認に限定。実マウス/キーボードfocus、全DPI、実PXP、長時間は未確認。
- 配布: 利用者ワークスペース直下xrd_workbench_v1.2.3、ZIP、sha256へ新規出力。220ファイル、本体45 IPF、相対include73本、HTMLリンクとanchor正常、全ZIPエントリのSHA一致。ZIP1230883 bytes / SHA256=f31c5a1ada0f5e93016574d1908ecfab784f38440aac607a72b158338832c36b。
- 旧v1.2.2 repo全ファイルはbaseline SHA一致。旧配布ZIPのSHA8d8b82...と全エントリも不変。sources、原本測定/参照、利用者PXPに触れていない。専用PID以外へ終了要求なし。
- 補助パネルは前面表示。開いたままの更新は寸法・位置保持、×後の新規表示は初期寸法。図/表/ガイドの新規表示・明示サイズ操作まで固定する仕様ではない。main未統合。次は本branchをfetchして追加変更を新しい番号版へ作成する。

## 2026-10-29 / v1.2.4 investigation and implementation

- fetchでIgor最新codex/xrd-v1.2.3 fb0c031を確認。既存checkoutの未追跡diagnosticsを保持し、codex/xrd-v1.2.4へ分岐。旧版全バイトSHAを保存、新番号版を複製。
- Safe Update、Performance Debug、Data Compatibility、Computer Useを読込。Igor専用PID以外へ終了要求なし。最初のUI起動は/UNATTENDEDなしでCOM同一性検査に失敗、データを開かず中止。以後/UNATTENDED + Visible=1 +固有マーカー確認で専用Igorへ接続。
- 旧版を実クリックして確認: XRDLibraryのscanReferencesはDoAlertDialog/OKを作成するが、大きなfloatingパネルの背後に隠れて見えない。accessibilityで確認待ちを検出。元フォルダ未設定の空Experimentでも再現するため大量データ処理ではない。公式NewPanel仕様にもfloatingのfocus衝突注意あり: https://docs.wavemetrics.com/igorpro/commands/newpanel
- 修正は入力/確認/フォルダ選択の短い間だけXRD所有floatingパネルを隠して復帰。サイズ維持の仕様とパネルの下書きは保持。計算とschemaは変更しない。修正後のnative/UI/互換性試験はこれから。

## 2026-10-29 / v1.2.4 native and UI investigation follow-up

- 実クリックで隠れたDoAlertを再現。ダイアログ表示中のvisibleなXRD floatingだけをSetWindow hide=1/2で退避する方式をnative17項目で確認。DoWindow/HIDEではfloatの表示状態が正しく変化しないことを途中試験で検出し、GetWindow hide / SetWindow hideへ訂正。
- DoPromptへby-reference文字列を直接渡すとIgor compilerがPossible bugを返すためローカルdraftで入力し、確定したときだけ返却する。試験のsum式・KillWindow引数列・Printのglobal直接参照の不正を訂正。失敗試行は合格に算入しない。
- UI: 参照追加のNo、Yes→フォルダ選択→同梱サンプル4参照の取込成功、元フォルダ未設定のOK、プロジェクト名入力・確定・Cancelと復帰を確認。
- 追加後の再操作でXRDProjectManager0が残ることを検出。callbackからの直接再構築をExecute/Pへ回し、成功return=0を明示。さらにnative WinListでDoWindow/Kがfloating managerを残すこと、KillWindow/Zなら同じウィンドウを閉鎖できることを実証。管理・ライブラリ再構築の閉鎖をKillWindow/Zへ限定変更。プロジェクト追加全体も退避/復帰で囲み取消/例外で復帰する。
- 中間264項目はPASS。最終コードの再実行とPXP再起動はこれから。regressionはmissing_hkl120.txtを出力先にも必要とするため初回が入力待ちとなり専用PID26076/marker1303637002だけ停止。fixture配置後に再実行する。利用者Igor/原本は操作していない。

## 2026-10-29 / v1.2.4 final verification

- 最終コードで退避/復帰17、サイズ247、同定/コピー等回帰102=366項目PASS、FAIL0。COMログはappendで重複出力するため、最終command実行区間だけを採取した。regressionは出力先にmissing_hkl120.txtを配置した未使用のregression_finalで再実行し102PASS。
- 最終UI: 専用PID6524/token1629522534で実クリックによる追加、確定、次の追加のCancelを確認。native WinListは成功後もCancel後もXRDProjectManager;のみ、RTE=0。ライブラリも1枚だけ。DoWindow/KからKillWindow/Zへの変更で重複を解消した。専用COM objectを保持するworkerによりUI後のnative状態も同一プロセスへ照会できた。
- UI前工程で参照追加No/Yes、フォルダ選択、同梱4参照の取込、フォルダ未設定のOK、プロジェクト文字列の入力も確認。全体の入れ子退避・例外復帰・cancel時の非変更を保持。
- 互換性: validated synthetic v1.2.3 updated.pxpをcopyし、新版読込前/後・初期化後・別名保存して専用process終了/起動/再読込後の185889項目が全一致。今回のデータ変更0。比較JSONを保存、実研究データをGitへ含めない。
- 未確認は利用者実PXP/全DPI/長時間等。計算処理とschemaは無変更。次は版付き配布とSHA照合・commit/push。

## 2026-10-29 / v1.2.4 delivery

- 配布: workspace直下xrd_workbench_v1.2.4/とZIP/sha256。229ファイル、46本体IPF、75相対include、HTMLリンク/anchor正常、ZIP全エントリSHA一致。1249033 bytes、SHA256=f65ad17ec2261303b9f8207b29de8fd702b892ed63041e67460d5eade86eb3cf。
- 旧v1.2.3 repo全ファイルをBASELINE_FORと照合し不変。旧配布ZIPのSHA f31c5a...と全エントリも不変。sources/利用者原本/既存Igorへ変更なし。専用UIも終了済み。
- 差分の空白検査はコード・文書で合格。native出力Error=0とCOPY_FAULTの空エラー欄の末尾空白はログ原文として保持し、結果ログを除外した検査と区別した。
- 完成版をcodex/xrd-v1.2.4へcommit/push。main未統合。利用者実PXP/全DPI/長時間等は未確認。ダイアログ自体のOSレベル故障注入は未実行。

## 2026-10-30 / v1.2.5 investigation and implementation

- 上記2件を現行UI/旧版人工fixtureで再現。選択ずれはevent4中のrow変更で2行移動するnative traceにより原因確定。公式WMListboxAction/ListBox仕様も照合: https://docs.wavemetrics.com/igorpro/programming/structures/wmlistboxaction , https://docs.wavemetrics.com/igorpro/commands/listbox 。
- 既存コード・GitHub最新2694482から新branch、新番号版を作成。旧版のbaseline hashを保存。
- 利用者の名前変更入力待ちをCancel/Escapeで解除し、GetActiveObjectでExperiment名を照合して現メモリの非公開バックアップを保存後、明示許可により元PIDのみ終了。最初のCreateObjectは新規Untitledへ接続したため、その空backupは不採用（ユーザーデータの代替にしない）。
- 本体: xrd_modal125を追加し管理の改名/移行/削除/復元をguard。登録画面6エラーとrecovery guardにも既存Alert wrapper。xrd_view100にpreserveScroll任意引数を追加しpeakList callbackのみ指定。graph選択・解析・schemaは既存のまま。版番号main/ui/ui120更新。
- これから新版nativeと実UI、現データの全フィールド・保存再起動、配布と現PXP適用を実施。未確認結果を合格と扱わない。

## 2026-10-30 / v1.2.5 native and UI checkpoint

- native: 新版26項目PASS。既存同定/コピー/比較/入力連動102項目PASS。管理core19項目PASS（初回runnerがPASS文言の「no runtime error」を誤検出したため先頭FAIL/RUNTIME行だけを検出するよう修正し再確認）。
- 初回の新試験でsum(abs(wave-expression))がIgor compiler非対応だったため全要素の明示比較へ変更。最初の既存回帰はrunnerのframe寸法未設定でlarge-sizeの1項目のみ失敗。既存CLIと同じ1920x1080のframe条件を設定し102すべて再合格。アプリ側のサイズ処理は変更していない。
- UI実操作: 旧版35度→37度、新版35度→35度。ホイールでtop48へ移動後67度がrow52として選択されtop48不変。native event4/2も同一row20/top15を確認。
- UI管理: 日本語への改名確定と確認ダイアログ、取消、不正名警告、削除No/Yes、復元対象なし通知と実復元を確認。固定UID、Raw/Peaks保持。管理画面は1枚、RTE=0。
- 追加監査: 登録入力エラー6か所と測定ファイル選択もguard。取消後の下書き保持を確認。
- 計測用probeに破棄通知でもXRD_Dataを参照する誤りがあり、最後のproject削除時にnull string通知を発生させた。製品callbackでは破棄通知を無視しており計測コード由来。通知を除去後の復元・登録検証は正常、製品へprobeを含めない。
- 実研究データはコピー上で旧版基準を採取中。科学値をrepoへ含めず、最後に現在の同名PXPへ反映する。実データ比較・再起動はまだ未完了。

## 2026-10-30 / v1.2.5 actual Experiment validation and deployment

- 実メモリから保管した複製を旧版でload/compileし589850項目を基準採取。旧画面閉鎖/新版読込直後の差3件はUI:left/top/maximized、初期化後差6件はUI:left/top/maximized/width/heightとRecovery:messageのみ。解析/科学値の差0。
- 検証用hidden Igorが画面状態を通常寸法として捕捉したため、元の寸法・位置・最大化設定を戻し、実ウィンドウも最大化して新規PXPへ保存。専用PID停止→起動→再読込→全項目再採取。589850項目のうち原本との違いはRecovery:messageのみ。UI設定も元値と一致。native compile/RTE=0。
- Save時のIgor診断CopyDimLabelToCStringは旧版以前の履歴にも存在する。RTE=0で保存され、ラベル/Note/式を含む全項目の再読込比較で保持を確認。原因修正は今回の範囲に含めない。
- 元ディスクファイルのSHAが作業前と変わっていないことを確認した上で、利用者が指定した既存同名PXPへ検証済み内容をコピー。適用ファイルと検証PXPのSHA一致を確認。起動時のデータ保管先も保持。旧PXP/IPF、元測定/参照、sourcesに不要な変更なし。現在ファイルへの反映は利用者の明示依頼による。
- source production47 IPFはDesktop展開先とbyte hash一致。旧v1.2.4全ファイルは基準hash一致。研究データ・個別比較JSON/TSVをGitへ追加しない。main未統合。追加変更なし。
- 最終実QSの通常起動後にも、利用者が停止を報告したプロジェクトの選択→名前変更入力画面が前面表示→Escape取消→管理画面復帰を実クリック確認。名前・研究データは変更せず、通常Igorは開いたまま残す。
- 配布: ワークスペース直下xrd_workbench_v1.2.5/とZIP/sha256。更新済みDesktop依存一式の文書も同期。原本.pxp・研究データは配布ZIP/リポジトリへ含めない。新規ZIP全エントリのbyte一致とinclude存在を確認。

## 2026-11-04 v1.2.6 実装チェックポイント
比較の除外・順序・表示設定と既存Wave名再利用を実装中。開始045748d、branch codex/xrd-v1.2.6。対象と原因・次操作はWORK_STATUS v1.8.0。新規実装のnative検証は未実行。旧版と実QSのbackup保持。

## 2026-11-04 v1.2.6 実装と検証チェックポイント
30 native + 新プロセス再読込4 + 既存同定/コピー102合格。除外/並替/反映/標準トレース編集を実UI確認。表の文字残りを空文字初期化、chem下付き数字をtraceでASCIIへ、可変サイズ配置と元projectへ適用するcontextを追加。実QS stageを保存（RTE=0）、元の比較4試料と順序に復帰。基準975914項目と初期化前はUI位置4件のみ。最終source確認は新プロセスへ。実QS互換・配布/同名適用は未完。

## 2026-11-04 v1.2.6 完了

比較の除外/全解除/上下移動・表示設定と、既存登録Waveを用いた読みやすいライブ比較を完了。新moduleと既存6本の最小変更。最終162 native assertion合格（30+4+102+26）、実UIの除外/反映/チェック追加解除/取消/トレース編集を確認。

実QS全値基準975914、初期化後979941。差分を全て分類し科学値/UID/同定/SharedLibrary/履歴/metadata/formula/既存作図は不変。専用Igorを実終了して別名保存の新版PXPを新プロセス再読込し979941項目を全比較、画面状態6件以外は完全一致。元の比較4試料/順序を保持した。詳細TSVと研究データは非公開、公開は集計のみ。保存時の既存CopyDimLabelToCString出力に対してlabel含む全照合を実施し保持を確認。

元Desktop QS_v1.2.4.pxpは元backupとのhash一致を確認してから、検証済みv1.2.6コピーへ置換。通常Igorで開き、タイトルv1.2.6、新比較設定をボタンから開く/取消、最大化を確認しCtrl+Sで表示状態も保存。更新前PXP、旧IPF依存一式、stage/verifiedをDesktopの番号付きbackupへ保管。同フォルダ内新版48 IPFが実際の外部参照先なので保持案内も配置。QS.pxpとsources/元データには変更なし。

251ファイル、48本体IPF、相対include79本、ZIP全バイトSHA照合成功。配布SHA=d816ee1023249997bc61b7d138663c96fd407a5e03740a2e3318a646ff57412e。旧版全ファイルもSHA一致。未確認は全DPI/モニター・長時間・旧パス遮断移設・全独自Procedure。main未統合。再開はcodex/xrd-v1.2.6とTEST_RESULTS_v1.2.6、WORK_STATUS管理版1.8.2。

## 2026-11-04 v1.2.7 実装チェックポイント
測定番号順、project UID順、登録終了、5%の初期値と変更UI、組成→表示名連動、plain textのproject追加、未同定ピーク巡回を実装。開始8af5113、branch codex/xrd-v1.2.7。既存plot/比較順・科学値を保持。compile/v125選択管理26合格、新試験実行中。最新38MB QS/依存backupとread-only基準採取済み。調査・判断と次操作はWORK_STATUS管理版1.9.0。実PXP互換・UI・適用は未完。

## 2026-11-04 v1.2.7 native/UI確認
新43 + 新プロセス再読込6 + 既存102 + 比較30 + 選択/管理26 + native検出13 = 220合格。実UIで番号入力→Tab組成→Tab表示名自動反映、登録成功終了、引用符なしproject作成、project上移動選択保持、初期値5%保存を確認。入力はComputer UseのUnicode type_textがIgor編集で反映されないためキー操作で確認。試験中の外部source変更でcompile前通知を出したが再compile後正常。native detector初回はfixture_v070指定にnoisy_*がなくファイル選択待ちとなったためown専用PIDだけ停止し、正しいfixture_v060で13合格。COM marker不一致の別試験起動はdata読込前に中止。製品コードに診断を残さない。
追加完了後の比較横軸0..0を実UIで確認。主図再構築後のXRD_SyncSideRangeで20..70へ復帰するため登録完了の最後に同期を追加、native43に範囲一致の回帰を追加。空projectで無題Newボタンが生成される原因は存在しないdetectorSettingsの部分変更だった。明示title/procと無効化、空headerの案内を追加しnative確認。
実QSは2189758項目をread-only採取（complex Wave 0）。高速helper127と旧helper120は人工値/Unicode/metadataのTSV全byte一致。実QSの前後/保存再起動照合・同名適用は未完。

## 2026-11-04 v1.2.7 実QS互換・最終検証完了

最終43+6+102+30+26+13=220 native合格。最後のUI変更後も既存102/30/26/13を再実行。final runner初回のnested PowerShellがcommandの引用符を落としたため、同じPowerShell内でscriptを直接呼び出す形に修正し全再合格。公開ログは最後の成功runのみ、失敗試行はscratchに保持。

実QSの2189758項目を基準に両Workbench全値/metadata/UID/科学revision/履歴を比較。新版初期化前差4 UI、初期化後2189760差15（prefs2/UI11/active子画面と案内2）。科学差0。別名保存→専用PID終了→新プロセス再読込の2189760項目は差9（UI8/active子画面1）だけ。CopyDimLabelToCString出力に対して全label含め保存再読込比較し保持確認。研究データ/詳細TSVはrepo外。

新manual/README/比較採用理由を作成、既存初心者/更新ガイドも新仕様へ。旧251ファイル全SHA一致、最新49 productionと実依存先のbyte一致、相対include83本、配布267ファイル/ZIP全byte確認。ZIP SHA256=7f5a83723e784752100d126c50a3dcce6859e7dfa82f910a8391575845aa1166。次は同名Desktop QSへ明示依頼どおり適用し通常UI確認。main未統合。

## 2026-11-04 v1.2.7 Desktop適用完了

Desktopの最新QS_v1.2.4.pxpと更新前backupのhash一致、他Igorなしを確認してから検証済みQSへ同名適用。49本体IPFを含む新版一式をDesktopの番号付き更新フォルダへ配置。通常Igor 9.05 64-bitで起動しタイトルv1.2.7、測定chooser054→055→057、ピーク初期値5%を実画面で確認。設定確認は取消し、主画面最大化でCtrl+S保存。利用者のQSは開いたままにした。旧QS.pxpと更新前PXP/旧依存は保持。適用先の保存後hashはprivate deployment.jsonへ記録。

新規初期値5%は今後追加する測定と標準presetに使い、既存測定条件を保持。登録とproject入力の操作確認は人工データで実施し、実QSで試験用測定やprojectを追加していない。220 native合格、実QS全値の保存再起動比較で科学差0という検証結果は上記のとおり。全DPI/モニター、長時間、旧パス遮断の別PC移設、全独自Procedureは未確認。WORK_STATUS管理版1.9.3、変更記録のみを追加commit/pushしmain未統合で完了。

## 2026-11-04 v1.2.8 性能調査開始

ユーザーが同定画面を中心とする軽量化を依頼、最終600測定を想定。開始cda2df5からcodex/xrd-v1.2.8へ、新番号一式を複製。現行Igorなし、最新40MB QSの独立backupと旧IPF依存一式を保持しhash一致。現行24測定/85参照の選択+live描画334–457msを実測。全測定を正規化する比較パス取得とchooser/upgradeの全件処理を調査。実QS基準TSV、600件人工workload、旧新の同条件計測へ。初期測定と次操作はWORK_STATUS管理版1.10.0。未更新。

## 2026-11-04 v1.2.8 性能修正とnative確認

全件Ensureを比較/listing経路から除き、同projectのstep変更で全Upgradeを繰り返さず、chooserの未使用sortとpreviewのEvidence重複を除去。600合成測定/比較5/85参照のmedian選択2804.88→156.721ms、更新7229.25→261.063ms。120選択でwarm後global Wave数17257→17257。候補等10選択の共通29185項目が等価。新12+既存43/26/30/102/13=226 native合格。実QS全互換・再起動・UI・同名適用は未完。

環境診断はSTATUS1.10.1。既存試験のscratch専用missing_hkl120 fixture未準備でファイル選択待ちになったown test PIDだけ停止し、汎用fixtureと再現可能なrunner準備を追加して102再合格。PowerShell COM/Print試験記述も修正。製品に診断や試験用データは残さない。

## 2026-11-04 v1.2.8 最終互換・配布・Desktop適用

実QS全2358888項目を更新前/新コード初期化前後/別名保存/own専用Igor終了→新PID実再読込で照合。初期化後の差14はUI10/表示範囲3/active子画面と案内1、再起動後の差1はactive子画面のみ、科学差0。実10選択19451項目の候補/根拠/Preview/元ピーク/Assignments完全一致。既存CopyDimLabelToCString保存出力はRTE=0で全metadata含め保持確認。実選択median309.882→174.096ms。600合成/比較5でmedian2804.88→156.721ms、更新7229.25→261.063ms。native226合格。

初回差替えで画面終了とCloseProcを続けて予約した直後Igorがucrtbase.dll/c0000409終了。元QSは未変更。新PIDで画面終了→旧entrypoint終了→新版読込を別々に実行すると正常、保存と実再読込にも成功。Igor内部原因は未確定、製品に根拠のない回避変更を追加していない。

旧267ファイルSHA一致、新49本体IPFの実依存先とのbyte一致、284配布ファイル、相対include84、HTMLリンク19、ZIP全byte検査成功。ZIP SHA256=188d24f11856453f7c715af9e9db98955c1b5c498de1ae71570f71c2f19ed2f1。元Desktop同名QSと最新backupのhash一致、他Igorなしを確認して検証済みコピーへ同名適用。旧QS.pxpと更新前PXP/旧依存を保持。実コードはDesktop番号更新フォルダを参照するため保持案内を配置、研究データは非公開。

通常Igorを起動しQS_v1.2.4タイトルとprocess応答を確認、開いたまま。Computer Useの通常Igor捕捉は壁紙、activationがfailed to activate captured window。現在windowを再取得した1回の再試行も同じため入力を停止。通常UI最終クリック/追加Ctrl+Sは未確認として区別し、コピー上で保存し再起動照合済みのPXPを適用したことを報告する。長時間/全DPI/600曲線同時表示/別PC/全独自Procedureも未確認。WORK_STATUS1.10.2、main未統合、同branchへ完了記録をpushする。

## 2026-11-05 v1.2.9 凡例/図寸法 調査チェックポイント

開始1d52584、codex/xrd-v1.2.9。原因と許可範囲はWORK_STATUS1.11.0。旧版284ファイルhash保持、新版に表示のみ最小変更。添付手作業PXPを私的コピーで参照、利用者本体へ適用しない。実機検証へ。

## 2026-11-05 v1.2.9 実装/native検証チェックポイント

新18+別プロセス再読込5+既存比較30/同定コピー102/検出13=168合格。添付手作業PXPの複製からint_M_type_003等と単純凡例を確認、元ファイル不変。Unicode実寸で列幅を短縮し共通フォント1回、原表示名を保持。新規図draftのみ一度16x12cmへ、保存済みrecipe不変。固定サイズでの表示pixel丸めと余白の計測順の修正をnative確認。実QS最新保存コピーと旧依存をprivate保管、全値比較へ。STATUS1.11.1。

## 2026-11-05 v1.2.9 最終互換・配布確認

実QSの基準2481476項目、新コード初期化前差1 active子画面、初期化後2481477項目差4（同画面/作図下書きwidth/height/figureDefaults129）、科学差0。別名保存・own専用PID終了・新プロセス再起動/再読込で2481477項目すべて一致。利用者QSと手作業PXPの原本hash不変。詳細はprivate、研究データ非公開。新18+実再読込5+既存30/102/13=168合格。旧284ファイルhash不変。新49本体IPF・7変更、ZIP/全byte検証、更新案内/結果/画像を同梱。STATUS1.11.2、main未統合、作業中QSへ適用なし。最終branch pushへ。

配布検査: 296ファイル、49本体IPF、相対include85本、ZIP全エントリbyte一致。ZIP SHA256=5ac32ad8016c9f7dc16706b418814e95f5b34cf40e52cb9a34c72ad54fd5816f。元の合成fixture comment_header.tsvだけを許可し、実データTSVとPXPは除外した。初回package検査が既存の合成TSVも拒否したため、既知fixtureを明示許可して再実行し成功。配布ZIPに研究データなし。

## 2026-11-05 v1.2.9 build2 同名QS更新適用

ユーザーが更新適用を依頼。開始be126c5、Igorなし、Desktop QSは前検証の基準hashと一致。タイトル旧版表示のみ2 moduleを修正したbuild2を独立作成。元v129一式/ZIP保持。Desktop新番号folderに元PXP/旧依存と新版一式を保管し、コピー上の新版画面構築/設定値/compileを確認。2481476→2481477全項目比較でUI/案内12差だけ、科学差0。別名保存RTE0、own専用Igor終了→新プロセス実再読込の2481477全項目差0。dump helper除去済み。適用直前の原本hash/他Igorなしを確認して同名QSへ配置。通常Igor PID29924起動、QSタイトル/応答確認、開いたまま。通常UI capture壁紙/activate失敗、再取得1回再試行同じで入力中止、通常COM ActiveObjectも非公開。最終クリック/追加Ctrl+S未確認。詳細private、公開集計はDEPLOYMENT_v1.2.9_build2、STATUS1.11.3。branchへ記録をpush、main未統合。

## 2026-11-06 v1.3.0 実装と初期native確認

管理版: 1.12.0。実装済み・検証中。利用中Experimentへは未適用、main未統合。

- Branch: codex/xrd-v1.3.0。開始SHA fe8236e295c3d5455486257f45838b03553f2222。実装先 xrd_workbench_v1.3.0。
- 対象: 外部Windowsアプリを覆う補助パネル、登録UI/ファイル先頭番号、検出ピーク位置と選択拡大、格子画面の参照棒/比較図、共通相設定の同一窓化、使用相の凡例順、作図一覧のスクロール、未完了作図の警告。配布ZIPと利用中QSへの適用、削除候補の集約まで依頼済み。
- 原因: 全補助パネルが/FLT=1で/FLTH未指定。拡大・グラフ選択とSideCompareの条件がstep3限定。検出は平滑化後の山位置を最近傍点へ登録。StylePanelが対象変更のたびにKill/NewPanel。凡例候補がStyleTargetsの全参照fallbackを利用。PlotSelectionTableとSaveDraftが未完了を排除。ツリー再構築時にスクロール行を復元していない。
- 変更: Igor9の/FLTH=1、raw近傍最大点と描画専用強度、step1拡大幅、step4比較と参照棒抑制、相設定の既存窓再利用、assignment由来の凡例候補、途中作図の確認と保存、参照TXTの明記格子定数を比較/履歴へ。原計測・既存ピーク/同定の自動変更なし。
- 基準: 旧版298ファイルSHAをdocs/BASELINE_FOR_v1.3.0.jsonへ。実QS/旧依存はDesktop Igor2_XRD内の非公開バックアップへ複製。実データはGitHub非公開。
- 確認: Igor9.05で新版compile成功。新規27項目合格。旧試験結果は今回の合格数へ算入しない。
- 次: 検出/作図/保存の関連回帰、実QSの全値比較、別プロセス保存再読込、画面確認、配布/適用、旧版のGitHub保存/利用参照検査と削除候補集約。
- 未確認: 実QS互換性と新起動、外部アプリ切替の実操作、全DPI/長時間。通常Igor PID31264は終了しない。
- 検証系: COMの既存接続は専用インスタンスを特定できず、研究データの読込を中止。/IのCLI専用プロセスとITX後続コマンドへ移行。検証系のC::パス誤変換を修正してcompile成功。利用中Igorは終了していない。


## 2026-11-06 v1.3.0 最終確認・配布・適用・整理

管理版: 1.12.2。実装・配布・利用中QSへの適用・旧配布物集約を完了。main未統合。

- Branch codex/xrd-v1.3.0、開始fe8236e295c3d5455486257f45838b03553f2222、実装先xrd_workbench_v1.3.0。旧版298ファイルSHA不変。
- 依頼範囲を実装: Igor外で隠れる補助パネル（/FLTH=1）、不要な登録/一覧ボタン削除、先頭通し番号自動検出、検出ピークのraw頂点補正/曲線上の描画、測定ピーククリック拡大、格子画面の参照棒抑制と比較図、参照TXT明記の格子定数比較、相設定の同一窓、使用相だけの凡例順、長い作図一覧のスクロール保持、未完了作図と警告。
- 既存ピーク/同定を起動時に移動しない。Ctrl+Aの独自割当なし、標準Ctrl+Iを利用。参照セル値がない場合は未収録。PDF抽出/推定値による補完は追加していない。
- Native127合格/失敗0: 新32・選択26・比較30・凡例18・格子8・標準検出13。Igor9.05 64-bit。合成のみ公開、実データは非公開。
- 実QSライブコピー: 基準3652393→初期化後3652388項目。初期化前3/後102差はUIと保存案内のみ、科学差0。別名保存→検証専用プロセス終了→新プロセス実再読込、3652388項目で表示状態2差、科学差0。検証helperを保存PXPから除去。原本上書き/通常Igor終了なし。
- 切替直前のライブコピーも3652393項目が基準と完全一致。元/切替前コピーのnative再現マクロも完全一致。現行PXPはDesktop/Igor2_XRD/QS_v1.3.0.pxp、実参照はruntime/xrd_workbench_v1.3.0。通常PID31264を維持してLoadExperiment/compile/参照先/保存RTE0を確認、開いたまま。
- 配布: Desktop/Igor2_XRD/配布/xrd_workbench_v1.3.0.zip、1,467,465 bytes、312ファイル、50本体IPF、相対include88。ZIP内全byte検査成功、研究データなし。SHA256=1e0b3e3f8a749b27ea30bdb098986e13de641927ce125f878c06f8247dc46cae。
- 整理: GitHub確認commit51d48f4の旧v1.1.0～1.2.9 build2と一致する34配布物をDesktop/Igor2_XRD/削除候補_旧配布版_20261106へ移動。改行差は正規化、生成pycacheのみ例外。元の場所/対応版は非公開manifestへ。元測定/参照/実験/自動保存/更新前backupは対象外。v1.0.0以前はGitHub未確認で保持。整理後に新版PXP再読込RTE0。
- 元ディスクQSは更新backupへ原バイトのまま保管し、同階層へ対応旧依存を複製。ライブコピー/独立旧版/検証TSVもprivate。sourcesおよび既存development/tmpの他作業へ変更なし。
- 未確認: Windows実クリックによる外部アプリ切替（Computer Use捕捉が壁紙、activate_window timeout）、全DPI/全モニター、長時間、旧絶対パスを遮断した別PC、全独自Procedure。APIで新版の利用中参照先と保存/応答は確認。
- 再開: 本branchをfetchし、本記録・WORK_LOG・TEST_RESULTS_v1.3.0を読む。現行runtimeとPXPを原本として保護し、次版を新ディレクトリで作る。


## 2026-11-09 v1.3.1 調査

GitHub上のXRD最新版 bf0c637 とDesktop v1.3.0を確認。重複番号、復元可能な削除、浮動パネル、作図呼出し時の全件初期化を調査。対象と未確認はWORK_STATUS 1.13.0。

## 2026-11-09 v1.3.1 実装チェックポイント

再測定の読込事前検証・トランザクション・対象別完全削除、通常ウィンドウへの変更、作図ウィンドウ呼出し時の全件初期化省略を実装。Igor 9.05で本体compile、MDIサイズ縮小を再現。実測・回帰・互換性・適用は検証中。

## 2026-11-09 v1.3.1 検証・適用

合成実験で差し替え・対象限定完全削除・外部グラフによる使用中の復元・新旧図の前面切替・画面矩形保持を確認。途中試験の旧データ読取には誤った三列fixtureを指定していたため測定XYで再試験。復元後の再描画にPatternがない場合、GetAxisのRTEが次のバックアップに残ることを再現し、画面がある場合にだけ軸を取得するよう修正。最終114 native合格、完全削除後の別プロセス再読込を含む。保存時にIgorのCopyDimLabelToCString診断が出る場合もRTE0、全値・ラベルの再読込照合で科学差なし。新しい自動保存を基準に実QS照合。更新版PXPを別名配置し、通常利用で新版を開いたまま。状態・性能・配布集計はWORK_STATUS管理版1.13.2。

## 2026-11-09 v1.3.2 調査

開始987102e。画面を開くときの表示崩れと削除ボタンの配置、組成注記の描画時書式を調査。STATUS 1.14.0。

## 2026-11-09 v1.3.2 実装

小さいIgor作業領域で参照ライブラリを再表示すると内容が縮み右側が切れることを再現。画面内に収まる補助ウィンドウとスクロール可能な内容領域を分離。最大化からの切替は一度のMoveWindowにし、完全削除を操作枠内に配置。新規作図とライブ反映の注記で斜体x、等号前後の半角スペース、U+2212を使用。入力と保存済み図の手編集は保持。実QS適用前。

## 2026-11-09 v1.3.2 検証・適用

旧版のライブラリ内容幅1180→535と完全削除の枠外8を再現。新版はライブラリ内容幅1180を保持し、通常およびコンパクト時に枠内へ。注記の最初の試験はAnnotationInfoがエスケープを付加する既定オプションで比較していたため、元の注記を取得するオプションで再確認して合格。実QSの更新・再起動後の全項目を照合して科学差0。利用版を別名で起動し、ショートカットを更新。STATUS 1.14.2。

## 2026-11-09 v1.4.0 調査

開始7687180。相と晶系の選択、複数プロジェクトの測定、横軸の表入力、一括格子計算について利用者回答を確認。単独計算の既存式を作業領域指定で共用する。STATUS 1.15.0。

## 2026-11-09 v1.4.0 実装

相と晶系、現プロジェクト＋任意の他プロジェクト、横軸の表入力を統合。単独計算の手順を別作業領域で共用し、履歴と図のスナップショットを保存。合成データの既知a/c、保存・再起動、測定の完全削除との連動を確認。作図の負号とウィンドウ挙動は維持。実QSの互換性照合と配布・適用は進行中。

## 2026-11-09 v1.4.0 検証・適用

一括計算の合成a/c、横軸の入力・並べ替え、他プロジェクト、図の再読込と完全削除、既存の単独六方晶・立方晶回帰を確認。旧テストを単独指定した際は共通試験手順を含まず実行できなかったため、正しいincludeで再実行し合格。実QSの更新・再起動後の測定、同定、参照、格子履歴、図に科学差なし。別名PXPを配置し通常Igorを開いた状態。STATUS 1.15.2。

## 2026-11-09 v1.4.1 調査

開始a28fec5。旧版は横軸の幅/3から目盛りを決め、両端に余白を付加。凡例と右軸ラベルはIgorの既定方向。参照値はカード内の値のみ、画像名はウィンドウ内部名。ライブコピーに対象図の存在を確認。

## 2026-11-09 v1.4.1 実装

横軸の実範囲と目盛り、同色の左右矢印と軸ラベル、参照値の自動取得・手入力、画像既定名を実装。旧保存図を新書式に複製する操作を追加。Igor 9.05の合成68項目合格。STATUS 1.16.1。

## 2026-11-09 v1.4.1 検証・適用

同名参照カードJSONを追加で読み込み、実際の図の参照値を破線で表示。左右の矢印は曲線と重なりにくい位置へ調整。Igor 9.05で69項目合格。最新保存のコピーを照合し、元の図と測定・同定・格子計算を保持。新書式の図とPNGを別保存し、通常Igorで開き、右クリック保存の既定名を確認。STATUS 1.16.2。

## 2026-11-10 v1.4.2 調査

開始0a52369。対象なしShowInfoと前面ウィンドウに依存するWorkbenchの操作欄を確認。系列図矢印は軸変更後の自動再配置と手調整を設計。実験コピー保全、独立Igorで旧版の計測を開始。STATUS 1.17.0。
