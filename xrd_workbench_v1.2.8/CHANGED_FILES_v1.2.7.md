# CHANGED_FILES v1.2.7

基準 v1.2.6 / 8af5113。49本体IPF中12変更、1追加。

|ファイル|内容|
|---|---|
|xrd_workflow127.ipf（追加）|番号順のchooser、UIDによるproject順序、初期値設定、plain textのproject追加、未同定ピーク巡回|
|xrd_main.ipf|版1.27、include/初期値メニュー、project追加UIへ接続|
|xrd_project.ipf|project一覧に保存したUID順序を適用（物理フォルダとstackOrderは保持）|
|xrd_ui110.ipf|測定chooserを番号順、空projectの案内と無効化、検出設定ボタンを明示命名|
|xrd_tree110.ipf|treeの測定番号順とproject上下移動ボタン|
|xrd_entry110.ipf|番号/組成/表示名の順と同期方向、入力フォーカス、成功時のKillWindow、最後に比較横軸を再同期|
|xrd_transfer120.ipf|コピー元の組成を同期基準へ設定し、手動表示名を保持|
|xrd_detect.ipf|新規の最小突出量を設定値へ、初期値画面ボタンと寸法|
|xrd_autofind.ipf|標準presetに保存した初期値、弱/ノイズpresetの意味をmin/maxで保持|
|xrd_modal124.ipf|project追加を非modalのplain textフォームへ|
|xrd_v72.ipf|その他操作に未同定ピークの前後移動|
|xrd_ui.ipf / xrd_ui120.ipf|表示版更新|

試験: xrd_v127_tests.ipf、xrd_semantic127.ipfを追加。v120回帰の5項目は、利用者指定で逆にした組成→表示名の新仕様へ期待値を更新。その他の既存検証は保持。export helper127は全値を保存し、同じWaveのパスを毎点escapeしない。人工の数値・テキスト・Unicode・label/Note/scaleを旧helperとbyte単位で比較。元のschema、解析計算、同定方法、参照ファイルは変更なし。
