# v1.2.8 変更ファイル

- xrd_project.ipf: 初期化済み測定の順序一覧取得を読取中心に変更。欠損stackOrderは従来の初期化へ。
- xrd_ui120.ipf: 比較の選択UIDだけを解決。所属プロジェクト/測定の削除・復元を毎回確認し、順序・重複排除・空選択を保持。
- xrd_ui110.ipf: 選択ボタンの表示に使われていなかった全測定sortを除去。一覧を実際に開く時の番号順は維持。
- xrd_ui.ipf: 同じ初期化済みプロジェクトでタブを変える際の全件Upgradeを省略。新画面・別プロジェクト・旧schemaでは初期化を維持。
- xrd_match.ipf: PreviewReferenceが作成した同じEvidenceをPreviewCandidateで再作成しない。
- xrd_main.ipf、xrd_ui.ipf、xrd_ui120.ipf、xrd_ui123.ipf: 版・ウィンドウタイトルをv1.2.8へ。

本体49本中7ファイルを変更、新規本体moduleなし。科学式、Wave名、UID、Assignments、SharedLibrary revision、schema、Undoと復旧保存の実装は変更しない。

試験: tests/xrd_perf128.ipf（旧新版共通の計測/600件合成/結果出力）、tests/xrd_v128_tests.ipf（読取の非破壊・選択/削除/復元など12項目）、fixtures_v110/missing_hkl120.txt（既存102試験の不足していた汎用fixture）、tests/results_v128（今回の成功ログ・集計）。run_igor_v128.ps1 / run_v128_final_regressions.ps1はWindows PowerShell5.1で実行し、専用Igorの一意markerを確認してから試験する。
