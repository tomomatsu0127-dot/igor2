# TEST_RESULTS v1.2.6

2026-11-04、Windows / Igor Pro 9.05 64-bit。開始コード v1.2.5 / 045748dd、作業branch codex/xrd-v1.2.6。

本リリースの最終コードで162 assertion合格、失敗0。

|試験|合格|記録|
|---|---:|---|
|比較の除外・順序・取消・表示設定・既存Waveの直接参照・offset・名前衝突・下付き文字・可変サイズ・project切替|30|tests/results_v126/comparison.txt|
|別名保存、専用Igor終了、新プロセスで実際に再読込し除外・順序・表示設定・Wave参照を確認|4|tests/results_v126/comparison_reopen.txt|
|既存の同定・参照・手動ピーク・登録と改名・作図スナップショット・凡例・他projectコピーと全故障点rollback|102|tests/results_v126/regression.txt|
|v1.2.5のスクロール後のピーク選択・グラフ追従・管理画面復帰|26|tests/results_v126/selection_manager.txt|

実UIでは、比較一覧での試料選択、除外、上下移動、反映、チェックでの追加と解除、取消、標準Modify Trace Appearanceでの名前表示を確認。利用者の比較4試料と元の順序へ戻した。大きな設定画面でのボタン重なりを調整し、最小サイズの配置をnativeで検査。表のチェック欄に以前の文字が残る現象も初期化で解消し、再起動した最終コードの実画面で確認した。

実QSは、元PXPと旧IPF一式の別保管後、コピーだけで試験。WorkbenchとXRDWorkbenchの両方について、Wave値・型・次元・scale/units・label・Note・formula、scalar/string、全project・削除保持データを列挙して比較した。更新前975914項目、最終初期化後979941項目。初期化前の差は画面位置等4項目だけ。初期化後の差4050件は比較表示用cache/draft4026、新表示設定4、UI配置/tree18、active子画面と自動保存案内2。科学値・UID・同定・SharedLibrary参照/科学revision・Undo/格子履歴・登録Wave/依存式・保存済み作図は一致。研究データと詳細TSVは公開repo外に保管した。

最終版を新しい名前で保存し、専用Igorを終了、新プロセスで再読込して979941項目を全照合した。科学値・全Wave metadata・依存式・同定・参照・履歴・比較4試料と順序に差はない。差6件は、保存前に明示的に設定した画面寸法等5値とactive子画面1件だけ（表示状態）。`tests/results_v126/actual_compatibility_summary.json`に個人データを含まない集計を保存。実際のDesktop同名QSへの適用結果はWORK_STATUS/WORK_LOGに記録する。

旧版全ファイルのSHAはdocs/BASELINE_FOR_v1.2.6.jsonと再照合し一致。tests/results_v126/old_release_preservation.jsonに集計。保存時にIgorが既存由来の`BUG: CopyDimLabelToCString`を出力するため、RTE=0だけで保存合格とはせず、再読込したlabelを含め全項目で照合する。

未確認: 全DPI/モニター配置、長時間連続使用、旧パスを遮断した別PCでの移設、全ての独自Procedure。以前の保存済み作図のトレース名を一括変更する機能は今回の対象外。新しい表示名はライブ比較に適用する。
