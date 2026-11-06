# WORK_STATUS — v1.3.0 / 2026-11-06 JST

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

# 保持した前工程記録

# WORK_STATUS — v1.2.9 build2 / 2026-11-05 JST

管理版: 1.11.3。Desktop同名QSへ更新適用完了、通常Igorを開いた状態。main未統合。

- Branch codex/xrd-v1.2.9、開始be126c5、適用版xrd_workbench_v1.2.9_build2。
- 依頼「更新もやって」。開始時Igorなし、Desktopの保存版は前工程の基準hashと一致。新番号更新folderに元PXP/旧284依存ファイルを保管。
- build2: 旧画面タイトルv1.2.8をv1.2.9へ訂正、xrd_ui/ui120の文字列のみ。元v1.2.9配布は保持。処理試験168は前工程の結果、今回build2の実compile/実QS保存再起動照合は別の実施結果。
- 実参照先: Desktop/QS_update_v1.2.9_20261105_170241/xrd_workbench_v1.2.9_build2。
- 検証: 新規初期値453.543307/340.157480 pt、画面構築RTE0。元2481476→2481477、UI/案内12差だけ、科学差0。別名保存RTE0、own PID停止→新プロセス実再読込の2481477全項目差0。dump helperは保存前に閉じ、再読込で未参照確認。
- 適用: 元QSとbackupのhash一致、他Igorなしを再確認し検証済みコピーへ同名適用。旧QS.pxp保持。通常Igor PID29924、QS_v1.2.4タイトル/応答を確認、開いたまま。
- 通常UI: 画面捕捉は壁紙、activationがfailed to activate captured window。現在windowの再取得/1回再試行も同じため入力中止。通常COM ActiveObjectも非公開。通常画面最終クリック/追加Ctrl+Sは未確認。PXPの保存再起動は専用コピーで完了済み。
- 公開集計: docs/DEPLOYMENT_v1.2.9_build2.md/json。研究データ・詳細TSV・PXPは非公開。更新folderは実IPF参照先なので残す。
- 次: 本branchへcommit/pushして完了報告。再開は本記録/DEPLOYMENT資料、通常Igorを勝手に終了しない。
- 未確認: 全DPI/モニター、実マウス全画面操作、長時間、旧パス遮断別PC、全独自Procedure。

# 前工程記録（適用前）

# WORK_STATUS — v1.2.9 / 2026-11-05 JST

管理版: 1.11.2。凡例・新規図の書式、native168、実QS保存再起動照合、配布検証完了。main未統合、利用者PXPへの適用なし。

- Branch codex/xrd-v1.2.9、開始1d52584afe93f8781935fc4210de101a3444e5d3、実装先xrd_workbench_v1.2.9。
- 依頼: 凡例列間隔を縮め、編集しやすい本文/トレース名へ。新規図Absolute幅16・高さ12（cmと解釈）。添付手作業PXPは参照用。
- 原因: 凡例幅にUTF-8バイト数由来の過大な下限。項目ごとのフォント/下付き書式コード反復。作図後にwidth/height=0へ戻しAutoにする。
- 最小変更: Unicode実寸列幅、共通フォント指定1回、元の相名表示、int_相名_試料番号のgraph alias、新規図453.543307×340.157480 pt。手動ドラッグは明示ボタンでAutoへ。
- 既存保存図のnativeMacro/科学値/schemaは保持。新規SnapshotにsampleNumber129のみ追加。旧284ファイルhashはdocs/BASELINE_FOR_v1.2.9.json。
- 開始時Igorなし。原本/sources不変。添付PXPと実QSはprivateコピーで参照/互換性検証する。
- 確認: Igor9.05 compile、新18・別プロセス再読込5・既存比較30/同定コピー102/検出13、計168 native合格。Unicode化学式の画像表示も確認。手編集保持と明示Auto切替を含む。
- 診断: 新テストの関数名誤り、同一行breakのcompiler errorを修正。psizeは画面pixelへ丸められるため画面矩形は0.75pt許容、Absoluteは再現macroでも検査。固定幅への置換前に旧矩形の余白を算出し負のmarginを回避。失敗試行はscratchへ保持。
- 実QS: 最新Desktopの41,732,679-byteディスク保存版をprivateコピーし旧依存も独立保管。原本同名適用は対象外。新版切替前後/保存再起動比較は下記のとおり完了。
- 最終互換: 実QS基準2,481,476、初期化前差1（active子画面）、初期化後2,481,477で差4（同画面/幅/高さ/既定値flag）。科学差0。別名保存→専用PID終了→新プロセス再読込の全2,481,477項目は完全一致。詳細はprivate、集計だけ公開。
- 配布: project直下xrd_workbench_v1.2.9とZIP/sha256。利用者原本2種hash不変、旧284ファイルhash不変。新49本体IPF、変更7。nativeログ/生成PNG/更新案内を同梱。
- 次: codex/xrd-v1.2.9へ最終commit/push、ZIPを渡す。利用者のQSへの適用は本作業の対象外。再開時は本branchと本記録/TEST_RESULTS_v1.2.9を読む。
- 未確認: 全DPI/モニター、実マウスの全画面操作、旧パス遮断別PC、長時間、全独自Procedure。

# 保持した前版記録

# WORK_STATUS — v1.2.8 / 2026-11-04 JST

管理版: 1.10.2。性能修正・600件計測・226 native・実QS保存再起動・配布・Desktop適用完了。通常UIの最終クリック確認はツールエラーで未確認。main未統合。

- Branch: codex/xrd-v1.2.8、開始cda2df536b32665e41bec04b4ae483a30c950bb9、実装先xrd_workbench_v1.2.8。
- 依頼: 特に同定画面の応答を軽量化。最終600測定を想定。既存同定/科学値/自動保存/履歴を保持し、検証後にDesktop QSへ適用する。
- 開始Igorなし。最新Desktop QSは40,524,156 bytes、2026-11-04 16:59保存。旧PXP/旧依存をprivate Desktop番号backupに保存、元とSHA一致。旧267ファイルSHAをdocs/BASELINE_FOR_v1.2.8.jsonへ。
- 現行実QS: 5 project、24 measurement、70,908 raw points、161 peaks、85 references。専用Igor9.05 64-bit、COM一意marker確認後backupコピーを読込。
- 初回測定: comparePaths 94–127ms、chooser26–29ms、score57–94ms、live178–222ms、select+live+draw334–457ms。同条件で600件人工測定との比較を進める。
- コード原因候補: 比較対象5件を返すXRD120_ComparePathsがAllMeasurementPathsを経由し全件EnsureMeasurement→Normalize/PeakTable、DataChooserは使わない全件sort、step再構築はUpgradeProjectが全測定のpreview/evidence更新。測定・呼出し証拠に基づいて最小変更する。
- 実装: 一覧の既存stackOrder読取はEnsureを省略（欠損時のみ従来初期化）。比較は選択UIDだけを解決しproject/measurement削除を即時検証。chooserの未使用sortを除去。同一projectのstep移動は全Upgradeを省略。PreviewReference後の同じEvidence再計算を除去。科学式、採用、Undo、参照、autosave不変。
- 600 synthetic×4001点×30ピーク、比較5、85参照（合計624測定/2471508点）: 選択median2804.88→156.721ms、refresh7229.25→261.063ms。選択120回、warmup60後のWave17257→17257。全波形メモリリーク不存在の保証ではない。
- 等価: 600件で10選択、候補/Evidence/Preview/Peaks/Assignmentsの共通29185項目は完全一致。差1050は新版だけ事前step1操作したfocusTable表示105×10のみ。実QSで10選択も照合予定。
- Native: 新12、workflow43、選択管理26、比較30、同定/コピー102、検出13、計226合格。読取だけでunselected WaveModCount不変、project削除/復元/比較順/重複/空選択、欠損order fallback、step移動、Evidence等価も確認。
- 試験環境の診断: PowerShell7はGetActiveObject非対応で起動確認不可、Windows PowerShell5.1のfile runnerへ統一して成功。新試験末尾Printの未束縛global直接参照はNumVarOrDefaultへ修正しcompile成功。旧102試験が参照するmissing_hkl120はscratchに手動準備されていたため初回file picker待ち、own専用PIDのみ停止。fixtureを公開テストへ追加しrunnerで必ずコピーして再実行102合格。製品不具合ではない。
- 実QS: 2358888全項目。新コード初期化前は差5（UI3/表示範囲丸め2）、初期化後は差14（UI10/表示範囲3/active子画面と案内1）、科学差0。別名保存・own PID終了・新プロセス実再読込も同数、差1はactive子画面だけ。全metadata/label/式、UID/同定/参照revision/Undo/格子履歴/科学値保持。保存RTE=0、既存CopyDimLabelToCString出力にも全照合で保持確認。
- 実QS計測: 同一5選択median309.882→174.096ms。10選択の候補/Evidence/Preview/Peaks/Assignments19451項目完全一致。600件の共通29185項目も一致。計測は専用Automation親非表示・DoUpdateあり、ハードウェア/実表示の速度保証ではない。
- 検証時native終了: 初回の旧画面終了とCloseProcを同一予約した直後にIgor9.05がucrtbase/c0000409で終了。元QS変更なし。新専用PIDで画面終了・旧entrypoint閉じ・新版読込を分けると成功。内部原因は未確定。再試行後の保存再起動照合は科学差0。
- 配布: project直下xrd_workbench_v1.2.8フォルダ/ZIP/sha256、284ファイル、49本体IPF、相対include84。旧267ファイルSHA完全一致、新本体7変更・新moduleなし、HTMLリンク19、ZIP全byte照合。ZIP SHA256=188d24f11856453f7c715af9e9db98955c1b5c498de1ae71570f71c2f19ed2f1。
- 適用: 元Desktop QS_v1.2.4.pxpの最新backupとのhash一致と他Igorなしを確認し、科学値等価を確認したQS_verified_v1.2.8.pxpを同名適用。QS.pxpは保持。通常Igorを起動しprocessのQS_v1.2.4タイトル/応答を確認。実参照先Desktop QS_update_v1.2.8_20261104_170038/xrd_workbench_v1.2.8は284ファイル全byte一致、同フォルダを残す。更新前PXP/旧依存/検証TSVはprivate、研究データ非公開。
- 通常UI未確認: Windows Computer Useは通常Igorの現在windowを一覧で取得できるが画面捕捉は壁紙、activate_windowはfailed to activate captured window。返されたwindowを再選択して1回再試行も同じためUI操作を停止。通常UIでの最終クリックとCtrl+S追加操作を行ったとは報告しない。PXP自体は検証用コピーで保存/再起動照合済みで同名配置。最終通常Igorは開いたまま。
- 未確認: 長時間、全DPI/モニター、600曲線の同時描画、旧パス遮断の別PC、全独自Procedure。再開はcodex/xrd-v1.2.8、TEST_RESULTS_v1.2.8、WORK_STATUS1.10.2。完了記録をcommit/pushしremote SHA一致を確認。main未統合。

# 保持した前版記録

# WORK_STATUS — v1.2.7 / 2026-11-04 JST

管理版: 1.9.3。実装・最終native/UI・実QS保存再起動・配布検証・Desktop同名適用完了。main未統合。

- Branch: codex/xrd-v1.2.7、開始8af51131b53cc95a97c6429e56363f5fd4c48b4d、実装先xrd_workbench_v1.2.7。
- 完了: 測定番号順、project UID上下順序、登録完了終了/最後の比較横軸同期、5%の新規初期値と変更UI、番号→組成→表示名Tabと組成→表示名同期、引用符なしproject追加、空project案内、未同定ピーク前/次移動。
- 科学計算/schema/既存測定条件/登録Wave名/比較順/手動stack順は保持。project順序と初期値はPreferences127に保存。12本体IPF変更と新module1、49本体IPF。
- Native最終: 新43、別プロセス保存再読込6、既存同定/コピー102、比較30、ピーク選択/管理26、native検出13、計220合格。最終コードで全件再実行。tests/results_v127。
- 実UI: キー入力とTabでnumber→composition→label、x=0.7自動反映、登録成功終了、plain project作成、project上移動と選択保持、初期値5%保存を確認。source変更中のcompile通知は専用の模擬実験だけ。本文内のolder画像には注記し、初心者/更新マニュアルも新入力順へ更新。
- 実QS: 新しい38MBディスク保存版をbackup。両Workbench全値2189758項目、complex Wave 0。新版初期化前はUI4件のみ。初期化後2189760項目、差15は新prefs folder/5%設定2、UI11、active子画面/自動保存案内2だけ。科学値/UID/同定/SharedLibrary/全Wave metadata/formula/Undo/格子履歴/既存作図不変。
- 保存再起動: 専用PID終了→新プロセス実再読込→2189760項目全比較。差9はUI8とactive子画面1のみ、科学差0。保存時の既存CopyDimLabelToCString出力はRTE=0で、label含む全比較で保持確認。詳細TSV/利用者PXPは非公開。
- 旧版251ファイルSHA一致。helper127と旧120の全byte一致を数値/Unicode/text/metadataで確認。研究データ/sources/元測定/参照へ変更なし。
- 配布: ワークスペース直下のxrd_workbench_v1.2.7とZIP/sha256。267ファイル、49本体IPF、相対include83、ZIP全byte一致。SHA256=7f5a83723e784752100d126c50a3dcce6859e7dfa82f910a8391575845aa1166。
- 適用: 元Desktop QS_v1.2.4.pxpのhashを最新backupと照合し、検証済み新版へ置換。通常Igor 9.05 64-bitでタイトルv1.2.7、測定一覧054→055→057、初期値5%を確認。確認画面を閉じ、主画面最大化でCtrl+S保存し、開いたまま。ファイル名は指定どおり維持。旧QS.pxpは保持。
- 依存先: Desktop QS_update_v1.2.7_20261104_145923/xrd_workbench_v1.2.7。旧PXP/旧IPFと検証済みコピー、private deployment.jsonの適用hashを保持。新版の外部Procedure参照先のためフォルダ保持案内を配置。研究データは非公開。
- 未確認: 全DPI/モニター、長時間、旧パス遮断の別PC、全独自Procedure。再開はcodex/xrd-v1.2.7とTEST_RESULTS_v1.2.7、本記録管理版1.9.3。完了記録を同branchへcommit/pushし、remote SHA一致を確認。mainへは統合しない。

# 保持した実装/検証途中記録

# WORK_STATUS — v1.2.7 / 2026-11-04 JST

管理版: 1.9.1。実装・native/UI確認済み、実QS互換検証中。指定QS適用前。main未統合。

- Branch: codex/xrd-v1.2.7。開始SHA: 8af51131b53cc95a97c6429e56363f5fd4c48b4d。実装先 xrd_workbench_v1.2.7。
- Scope: 測定chooserとtreeの通し番号順、project上下移動、登録成功時に画面を閉じる、突出量初期値5%と変更UI、番号→組成→表示名のTabと組成→表示名連動、新規projectの引用符不要入力、既存ソフト調査に基づく追加。
- 原因: chooserがstackOrder（取込順）を流用。project一覧は物理folder列挙順。floating登録画面のDoWindow/K。登録連動が表示名→組成。新規projectはDoPromptで引用符付き文字入力。突出量は0.5の固定値。
- 実装: xrd_workflow127に番号文字列の桁数/辞書順sort（float変換なし）、project UID順序、初期値設定、非modalのproject追加form、前/次の未同定ピーク移動。旧plot stackOrderと比較順を保持。新規測定defaultと標準presetを設定値へ、既存測定はEnsureNumericで保持。弱/ノイズpresetは設定値とのmin/maxで意味を保持。
- UI: number→composition→labelの作成順と位置。組成の変更/blurのみlabel同期、手動label入力と単なる再focusは保持。コピーpickerも同期基準値を更新。登録成功はKillWindow/Z、失敗時の下書き保持は既存どおり。
- 調査: HighScore公式Quick Startの未説明ピーク確認workflow、Match!公式Peak Searching/Function Listを参照。追加は未同定ピーク巡回とdefault設定に限定。科学計算や自動同定を拡張しない。
- 保持: 旧版全ファイルSHAをdocs/BASELINE_FOR_v1.2.7.json。最新Desktop QS（約38MB）と旧依存一式を新番号backupへ保存。開始時Igorなし。研究データはrepo外。sourcesはread-only。
- 検証: 新版compile成功、v125選択/管理26合格。今回新試験を実行中。実QS旧版基準はbaseline64でread-only採取済み。最終互換/再起動/配布/同名適用/UIは未完。
- 診断: 初回専用IgorのCOM登録が5秒で間に合わず失敗（data読込前、own PIDのみ終了）。再試行で成功。worker/runnerに30秒以内の登録待ちと一意marker照合を追加。dump helper127は反復するpathのescapeをWaveごとに行い値は全件保存。旧helperとの完全一致を人工文字/metadataで検査予定。
- 次: native新試験、既存102/比較30/ピーク26/検出、実UI、実QSコピーで初期化前後→別名保存→own Igor終了→新プロセス再読込全項目比較、Desktop同名QSへ適用。
# WORK_STATUS — v1.2.6 / 2026-11-04 JST

管理版: 1.8.2。実装・native/UI・実PXP保存再起動・配布・指定QS適用完了。main未統合。

- Branch: codex/xrd-v1.2.6。開始SHA: 045748ddf1ec7a1a50ec421266d74856b1cb183f。実装先 xrd_workbench_v1.2.6。
- Scope/原因: 比較の除外・表示順・表示自由度とWave名。旧ライブ作図が登録aliasを使わずintensityN/MM_UID等を生成し、選択順も一覧列挙順だった。
- 実装: 順序付きdraft一覧、除外/全解除/上下移動、反映/取消。間隔と参照・同定・未同定表示切替。測定線は登録int_norm/ttの実Waveを参照しnative offsetで積層。同定/参照/未同定は表示専用Waveへ相と試料の名前を付ける。化学式下付き数字をtraceではASCIIへ。新UIはリサイズ可能、背景project切替時も元projectへ適用。空選択はside/review双方をクリア。
- 保持: 旧主図のcursor名、保存済み作図スナップショット、解析/schema/登録Wave名は維持。旧版全ファイルSHA一致。元QS・旧依存一式・検証TSVは公開repo外へ保管。sources/と元測定/参照ファイルは変更なし。
- Native最終: 比較30、新プロセス再読込4、既存同定/コピー102、v125選択/管理26、計162合格・失敗0。tests/results_v126。
- UI: 除外、並替、反映、チェック追加/解除、取消、標準トレース編集画面を確認。再起動最終コードで表の文字残り解消も確認。通常起動した同名QSから新比較ボタンで開くことも確認。
- 実PXP: 基準975914項目。初期化前はUI位置4件だけ、初期化後979941項目との差4050は表示cache/draft4026、新設定4、UI/tree18、active子画面/自動保存案内2。科学値/全Wave metadata/formula/UID/同定/SharedLibrary/Undo/格子履歴/既存作図は不変。最終別名保存・専用PID終了・新プロセス再読込の979941項目は科学差0、差6件は保存直前に変えた画面状態5とactive子画面1。元の比較4試料と順序を保持。
- 保存時のIgor既存由来CopyDimLabelToCString出力はRTE=0。labelを含む保存再読込全項目照合で保持を確認。外部IPFを上書きしただけではinclude cacheが残る場合があるので、ProcedureTextと新プロセスで最終ソースを確認。
- 適用: Desktop QS_v1.2.4.pxpを更新前backupとhash照合後、検証済みv1.2.6 PXPへ置換。通常Igorで起動、タイトルv1.2.6と比較設定の動作を確認し、作業画面を最大化してCtrl+S。ファイル名は利用者指定のまま。QS.pxpは保持。
- 依存: Desktop QS_update_v1.2.6_20261104_134138/xrd_workbench_v1.2.6 が同名QSの外部Procedure参照先。フォルダ保持案内を配置。旧QS/依存、更新stage/verifiedは残す。研究データは公開しない。
- 配布: ワークスペース直下xrd_workbench_v1.2.6とZIP/sha256。251ファイル、48本体IPF、相対include79本、ZIP全バイト検証成功。ZIP SHA256=d816ee1023249997bc61b7d138663c96fd407a5e03740a2e3318a646ff57412e。
- 未確認: 全DPI/全モニター配置、長時間連続使用、旧パス遮断した別PC移設、全ての独自Procedure。既存保存済み作図の名前一括変更は対象外。今後はこのbranchをfetchし、TEST_RESULTS_v1.2.6と本記録を読む。追加修正は新しい番号版へ。

# 保持した検証途中記録

# WORK_STATUS — v1.2.6 / 2026-11-04 JST

管理版: 1.8.1。実装・native検証済み。実PXP最終再起動検証・配布前。main未統合。

- Branch: codex/xrd-v1.2.6。開始SHA: 045748ddf1ec7a1a50ec421266d74856b1cb183f。実装先 xrd_workbench_v1.2.6。
- Scope: 比較試料の除外・順序・表示設定、既存登録Wave名の活用。解析とschemaは不変。
- 原因: 比較にはチェック選択だけがあり順序は全測定列挙順。ライブ作図がintensityN/MM_UID_R等の一時名を使い、既存namedIndex100を参照しない。
- 実装: 順序付きdraft、除外/全解除/上下移動/取消/反映。間隔、参照線、同定/未同定マーク表示。side/review測定線は既存の依存式付き登録Waveを直接表示しoffsetを使用。marker/referenceは表示用cacheのみ読みやすく命名。旧主図のcursor名と保存済みrecipe経路は維持。
- 保持: 旧版全ファイルhashをdocs/BASELINE_FOR_v1.2.6.json、実QSと旧IPF一式をDesktopの番号付きbackupへ保存。研究データはrepo外。開始時Igor起動なし。
- 確認: 新版30、専用Igor終了/再起動4、既存同定・コピー102が合格。実UIで除外、順序、反映とトレース編集一覧を確認。前回修正26も合格、最終コードで再実行中。実QS975914項目の初期化前比較はUI位置4件だけ。
- 未確認: 実QS最終コードの保存再起動、配布・指定QS適用はこれから。
- 環境: COM New-Objectは32bit登録へ接続するため、64bit専用PIDを起動後GetActiveObject+一意marker照合。既存登録は変更しない。
- 次: 実QS stageを専用Igorへ読み込み最終moduleを確認、科学値全比較・最終別名保存・再起動。元PXPは利用者明示の更新依頼により、全検証後に同名へ適用する。
- 注意: 外部IPF差替え後に既に読込まれたincludeが残る場合をProcedureTextで確認。最終確認は新しいプロセスで行う。v1.2.6の保存実験は新パスを参照する。
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
