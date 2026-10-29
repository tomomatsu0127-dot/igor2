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
