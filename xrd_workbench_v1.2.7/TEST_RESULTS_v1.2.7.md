# TEST_RESULTS v1.2.7

2026-11-04、Windows / Igor Pro 9.05 64-bit。開始コード v1.2.6 / 8af5113、branch codex/xrd-v1.2.7。全試験は今回のコードを専用のIgorで実行した。

|試験|合格|ログ|
|---|---:|---|
|番号順/桁違い/長番号、project上下/改名/非表示/選択保持、登録/Tab配置/組成同期/成功終了、5%初期値/設定/取消/既存条件保持、plain project作成/取消/不正名、空project案内、未同定巡回、比較横軸同期|43|tests/results_v127/workflow.txt|
|別名PXP保存、専用Igor終了、新プロセスで実際に再読込してproject順序・初期値・登録とUIDを確認|6|tests/results_v127/workflow_reopen.txt|
|既存同定・参照・登録・改名・snapshot作図・凡例・コピー/欠測hkl/Unknown/全故障点rollback|102|tests/results_v127/regression.txt|
|比較の除外/順序/表示設定/元Wave参照/offset/名前衝突|30|tests/results_v127/comparison.txt|
|検出ピークのスクロール後選択と管理画面復帰|26|tests/results_v127/selection_manager.txt|
|native Peak AutoFind/preview/登録/Undo/Redo/元値保持/不正条件/非等間隔/flat/短入力|13|tests/results_v127/detector.txt|

計220合格、失敗0。v120回帰の5項目は今回の利用者指定（組成→表示名）へ期待値を変更し、残りの検証は保持。最終の横軸同期・空project案内を含むコードで43/6を実行し、既存102/30/26/13も最終コードで再実行した。

実UIでは、番号のキー入力→Tabで組成→キー入力x=0.7→Tabで表示名x=0.7が自動反映されること、登録ボタンでファイル追加と画面終了、引用符なしのproject名入力/作成、project選択→上移動と選択保持、初期値5%の表示と保存を確認した。確認は模擬Experimentだけで行った。

実QSは最新ディスク保存版と旧IPF一式を独立保管し、コピー上で検証。WorkbenchとXRDWorkbenchの両方について全project/削除保持データのWave値/型/次元/scale/units/label/Note/formula、scalar/stringを列挙した。基準2189758項目（complex Wave 0）。科学値・UID・Peaks/Assignments・SharedLibrary/refUID/revisionUID・Undo/格子履歴・登録Waveと依存式・保存済み作図を保持する。

初期化前は2189758項目で差4件（画面状態のみ）。初期化後2189760項目との差15件は、新しい設定folderと初期値5%の2件、UI状態11件、active子画面/自動保存案内2件。科学値の差0。

最終コードを別名PXPに保存し、専用Igorを終了、新プロセスで実際に再読込した。再読込後2189760項目を全比較し、差9件はUI geometry/selection/tree/draft 8件、active UI child/autosave notice 1件。科学値・全Wave metadata・同定・参照・履歴の差は0。個人/研究データを含まない集計のみtests/results_v127/actual_compatibility_summary.jsonへ保存し、詳細TSVは公開repo外に置いた。

export helper127は、同じパスのescapeをWaveごとにまとめるだけで全値を出力する。人工の数値・Unicode/区切り文字を含むテキスト・scale/label/Noteについて旧helper120とTSVの全byte一致を確認。旧リリース全ファイルもSHA一致。集計はverification_summary.json。

保存時のIgor既存由来CopyDimLabelToCString出力はRTE=0。labelを含めて保存再読込全項目を照合し、保持を確認した。診断中のCOM登録待ち、試験fixtureの指定誤り、外部IPF変更後のcompile前通知は検証手順側で修正し、合格ログには最終成功runだけを収録。

デスクトップ同名QSへの適用と通常起動結果はWORK_STATUS/WORK_LOGへ記録する。未確認: 全DPI/モニター配置、長時間連続利用、旧パスを遮断した別PC、全ての独自Procedure。初期値はExperiment内の設定であり、既存測定を一括再検出する機能ではない。
