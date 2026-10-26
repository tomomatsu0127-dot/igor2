# 変更ファイル v1.0.0

## 主な役割

- xrd_manage100.ipf：管理ルート、実改名、衝突検査、バックアップ、記録、数値CRC検証、ロールバック、削除・復元。
- xrd_register100.ipf：手動番号・独立組成、命名計画、長さ検査、名前付き依存Wave、参照の閲覧用別名。
- xrd_manager100.ipf：改名・影響確認・削除・復元・移行の画面。保存を伴う操作はボタンのイベントから離して予約実行。
- xrd_view100.ipf：親ウィンドウの入力分配、登録ピークの選択、自動拡大、範囲履歴、Shift追加、XYカーソルの実角度。
- 既存モジュール：プロジェクトの完全パス列挙、固定ID接続、一覧・作図・保存・UIの接続部分を変更。
- tests/xrd_v100_tests.ipf：新規統合・境界・移行・再読込試験、旧仕様を新しいパス方式へ適応した回帰試験。
- READMEとマニュアル3ページ、今回の検証ログ、ネイティブ画面画像、manifest。

## 本体の処理が変わったファイル

- xrd_experiment.ipf：処理変更
- xrd_import.ipf：処理変更
- xrd_library.ipf：処理変更
- xrd_main.ipf：処理変更
- xrd_manage100.ipf：新規
- xrd_manager100.ipf：新規
- xrd_match.ipf：処理変更
- xrd_plot81.ipf：処理変更
- xrd_plotworkspace.ipf：処理変更
- xrd_project.ipf：処理変更
- xrd_reference.ipf：処理変更
- xrd_register100.ipf：新規
- xrd_ui.ipf：処理変更
- xrd_v44.ipf：処理変更
- xrd_v45.ipf：処理変更
- xrd_v51.ipf：処理変更
- xrd_v71.ipf：処理変更
- xrd_v72.ipf：処理変更
- xrd_v80_ui.ipf：処理変更
- xrd_v81.ipf：処理変更
- xrd_view100.ipf：新規

ほかの本体IPFは版表記のみ更新。科学計算式・元データ・ピーク検出アルゴリズムは変更していない。
