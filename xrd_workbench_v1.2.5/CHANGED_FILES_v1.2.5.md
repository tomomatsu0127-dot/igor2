# CHANGED_FILES v1.2.5

基準 v1.2.4 / 2694482。47本体IPFのうち6変更、1追加。

|ファイル|内容|
|---|---|
|xrd_modal125.ipf（追加）|管理の改名・移行・削除・復元全体でmodal guardと例外時の復帰|
|xrd_manager100.ipf|管理の対象操作をguard付きdispatchへ。復旧案内にも既存Alert guard|
|xrd_entry110.ipf|登録の入力エラー6件と測定ファイル選択をguard。取消時に下書き保持|
|xrd_view100.ipf|共通選択関数に任意preserveScroll引数。既定のグラフ追従は保持|
|xrd_ui.ipf|検出ピーク一覧のみpreserveScroll指定、callbackは標準return 0。表示版更新|
|xrd_ui120.ipf|表示版更新|
|xrd_main.ipf|新module includeと版番号1.25|

tests/xrd_v125_tests.ipf追加、tools/run_igor_v125.ps1追加。測定・参照・同定アルゴリズム・schemaは無変更。
