# 検証結果 v0.2.0

2026-10-29 JST。XRD独立版の実装開始版。今回実行した試験のみを記載。過去の設計検査207項目やIgor版の同梱ログはアプリの合格数に含めない。

## 今回の結果

|対象|結果|根拠|
|---|---|---|
|数値・読込・保存の既存回帰|19試験合格|tests/test_engine.py / test_run_v0.2.0.log|
|新しいデータ・管理・保存図・復旧・出力|14試験合格|tests/test_workspace.py|
|Qt画面接続・表編集・取消・寸法|8試験合格|tests/test_qt.py|
|合計|41試験合格、失敗0|tests/test_run_v0.2.0.log|
|schema1→2の別プロセス比較|旧状態の全フィールド一致、元ファイル不変|tests/compatibility_v0.2.0.json|
|旧ファイルの保持|基準167ファイルのSHA一致|tests/baseline_v0.2.0.json|
|ソース統合確認|PASS|tests/source_integration_v0.2.0.json|
|最終単体EXE自身の統合確認|PASS、終了コード0、frozen=true|tests/compiled_validation_v0.2.0.json|

## 確認した具体的な挙動

- 厳密な測定/参照読込、Raw不変、既知人工ピーク、重なり/Unknown、反射所有、Gaussian/Lorentzian、立方晶/六方晶の既知値、保存故障時の保持。
- 作業コピーの編集・処理・単位・Undo/Redo、無効値のrollback、先頭0と重複番号の検査、別プロジェクトの同定済み試料複製、横断比較。
- 完成図snapshotが解析変更/試料削除後も保持され、文書再読込で再表示できること。
- 外部ピークの元角度と由来が再検出後も残り、不正リストで部分追加されないこと。
- 元素集合と保護type、候補モード別の対象/スコア、完了/未確認の区別。
- 復旧3世代と保存失敗時の旧世代保持。XLSX番号の文字列保持と、ユーザー文字列を数式として書かないこと。
- Qtボタンから検出→候補採用→Undo/Redo→格子計算の接続。workerの取消後の結果破棄。実際のQt表編集delegateを通したセル変更。
- 1366x768/1920x1080の画面配置と、補助書式ダイアログ10回開閉・全段階切替での主画面寸法保持。

Qt試験はoffscreenの実ウィジェットとQtTestによる試験。利用者デスクトップでの全マウス操作を完了したという意味ではない。

## 保存互換性の比較

旧独立v0.1.0の別プロセスで人工試料を生成。検出・同定・フィット採用・格子計算・通し番号015、別試料のUnknown、hkl欠損を持つ参照、Undo/Redoを含むschema1文書を保存した。

新コード読込後と、別名schema2保存後にもう一度新しいプロセスで読み込んだ状態を、旧文書の全フィールドと比較。配列のdtype/形状/全バイト、単位・由来・ID・参照版・ピーク・割当・採用中心・格子履歴・Undo/Redoが一致した。新規の入れ物と既定欄の追加だけを許可し、元schema1ファイルは不変。

これは独立版.labxの試験で、Igor PXP互換性の保証ではない。PXP直接読込は本版の対象外。

## EXE自身での確認

Python 3.12.2、NumPy 2.4.4、SciPy 1.17.1、Matplotlib 3.10.9、Qt/PySide6 6.12.0を同梱。

人工5ピーク・5割当、Gaussian中心28.4474620573 deg、格子a=5.43062460568 Å（検出点の離散化を含む）。Rawと割当の保存再読込一致、PDF 61,045 / SVG 95,602 / PNG 113,496 bytesの出力、Qt画面、日本語表示、作業表のUndo/Redo、XLSX出力を確認した。スクリーンショットはcompiled_validation_v0.2.0.png。

## ビルド時に見つけて修正した問題

初回のEXEはQtCoreのDLL読込で失敗した。原因は作成環境のPATHに含まれるPoppler ICU78のicuuc.dllをPyInstallerが誤収集したこと。Qtが要求するWindows ICUのunversioned APIを持たず、PEのimport/export比較で不足を確認した。

ビルド子プロセスのPATHをWindows/インタープリターに限定しclean build。外来icuuc.dllを含むarchiveを拒否する確認を加えた。修復後EXEの自己検査がPASS。PC全体のPATHやWindowsのDLLは変更していない。失敗記録はcompiled_failure_v0.2.0.jsonに残す。

offscreen Qtの既定フォント一覧が空で、日本語が四角になる問題も確認した。インストール済みWindowsフォントを登録して描画し、PNGを目視確認。Windowsフォント自体は配布しない。

## 未確認・残作業

実測でのIgor版との数値比較、全DPI/複数モニター、全マウス操作、別クリーンPC、大量データ/大量参照/長時間の性能は未確認。現行52機能の完全移行は未完了で、FEATURE_PROGRESSに項目別の残りを記載している。

元のIgor版・旧独立版・未追跡v0.1.1・利用者の測定/参照/PXPは変更していない。mainへ統合していない。
