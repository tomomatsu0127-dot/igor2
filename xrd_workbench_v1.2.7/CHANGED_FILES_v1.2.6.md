# CHANGED_FILES v1.2.6

基準 v1.2.5 / 045748dd。48本体IPFのうち6変更、1追加。

|ファイル|内容|
|---|---|
|xrd_compare126.ipf（追加）|比較の順序付き下書き、除外・全解除・上下移動、表示設定、確定・取消、可変サイズの配置、既存Wave参照と表示用命名|
|xrd_v71.ipf|side/review測定線の登録alias参照と表示offset、読みやすい同定・参照・未同定Wave、間隔と表示切替、参照矢印の間隔追従|
|xrd_tree110.ipf|比較設定を新版へ接続、再構築時に表の空欄を初期化して以前の文字残りを解消|
|xrd_ui110.ipf|ボタンを「比較の追加・除外…」へ|
|xrd_ui120.ipf|空選択を別窓にも反映、ガイドと空選択メッセージを更新、表示版更新|
|xrd_ui.ipf|表示版更新|
|xrd_main.ipf|新module includeと版番号1.26|

tests/xrd_v126_tests.ipf、tools/run_igor_v126.ps1を追加。表示の設定値は既存Comparison120に追加し、科学データのschema・計算・UID・Assignmentsと既存登録Waveは保持。主図の旧トレース名と保存済み作図のスナップショット経路を保持。
