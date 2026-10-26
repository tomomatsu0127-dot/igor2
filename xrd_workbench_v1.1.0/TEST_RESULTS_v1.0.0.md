# v1.0.0 検証結果 — 2026-10-26

**Igor Pro 9.05 / Windows 64-bitの独立プロセスで375項目成功、失敗0。** 37本体IPF・530関数をネイティブでコンパイル。以前の版の成功件数は流用せず、この配布版で実行したログだけを集計。

|検証|成功|失敗|記録|
|---|---:|---:|---|
|v0.9/v1.0 統合・12箇所の故障注入|61|0|[ログ](tests/results_v100/integration.txt)|
|番号・名前・追加・拡大・最終Project削除|23|0|[ログ](tests/results_v100/edges.txt)|
|識別子・完了状態・Raw・依存式|19|0|[ログ](tests/results_v100/core100.txt)|
|実旧Experimentの移行・改名・Undo|15|0|[ログ](tests/results_v100/legacy.txt)|
|改名後Experimentの実再読込|7|0|[ログ](tests/results_v100/actual_reopen.txt)|
|欠損hkl・実5参照ファイル・計算防御|57|0|[ログ](tests/results_v100/native.txt)|
|欠損hklの実再読込|10|0|[ログ](tests/results_v100/actual_reopen82.txt)|
|既存参照形式・厳密な不正入力検証|55|0|[ログ](tests/results_v100/43.txt)|
|共有参照・版管理・キャッシュ|17|0|[ログ](tests/results_v100/library.txt)|
|六方晶・立方晶CurveFitと履歴|8|0|[ログ](tests/results_v100/lattice.txt)|
|ピーク・CurveFit・同定回帰|33|0|[ログ](tests/results_v100/profile.txt)|
|プロジェクト横断作図と保存|16|0|[ログ](tests/results_v100/plot.txt)|
|共有マーカー・色|5|0|[ログ](tests/results_v100/styles.txt)|
|Undo・キー処理・自動保存3世代|41|0|[ログ](tests/results_v100/saveundo.txt)|
|配布用検証runnerの起動・基本操作|8|0|[ログ](tests/results_v100/distribution_smoke.txt)|

## v0.9：名前変更・削除

- Managementの実フォルダと関連Waveを改名。日本語・空白・大文字小文字だけの変更、手動番号007/023、組成の保持。
- Raw、同定参照index、hkl、格子定数入力履歴のCRCを改名前後で比較して一致。数値を複製・推測して置換しない。
- Registryの固定ID、Undo target、文字列・text Wave、window userdata、依存式の保存文字列を更新。保存図の独立スナップショット、手編集の軸・ラベル・線幅を維持。
- 実行前のpacked Experimentバックアップを書き出し、非空ファイルを確認。書込不能先では変更しない。
- 改名12操作の各直後に故障を注入し、旧フォルダ・旧Wave名・ID接続・数値データへ復元。リベラル名のWaveも含む。
- プロジェクト・Wave名の衝突、不正名、255バイトを超えるフォルダ名や生成Wave名は変更前に拒否。
- 削除は復元領域へ移動。通常のProject検索と新規作図から除外し、共有参照と保存図は維持。同名衝突を拒否して復元。最後のProject削除後に空Projectを自動生成しない。
- 実際の旧v0.7.2 Experimentのコピーを読み、従来の共有化移行に加えてManagementへ物理移動。Raw・同定・Undo件数を保持し、旧UndoとRedoを実行。

## v1.0：選択・拡大・表示

- グラフの登録済みピークと一覧の共通選択処理。最初の全体表示から±5°へ拡大し、別ピークへ移動。端ではデータ範囲へ制限。OFFでは選択のみ。
- 直前のXY範囲を正確に復帰。表示操作でRaw・同定のCRCは変化しない。
- WMWinHookStructを直接与えるネイティブ試験で、登録ピークのヒット、離れたクリックの無視、Shiftクリックからの追加、ダブルクリック・右クリック・設定OFFを確認。
- XYグラフのカーソル角度はhcsrで取得。点番号を角度として確認表示する誤りを修正し、選択点と追加ピークの角度を比較して一致。
- 追加ボタン有効化、Ctrl+Iを標準処理へ渡すこと、Ctrl+Zの分岐、文字入力中の標準Undoを維持。
- 追加後のstatusBar更新がリサイズ位置を保ち、暗黙のNewボタンが再生成されないことを確認。小・大パネルのネイティブ画像を目視確認。

## 保存・互換性

- 改名・削除・復元後の.pxpを別のIgorへLoadExperimentし、固定ID、名前、番号、依存式、同定状態、格子定数履歴、保存図、手編集軸、設定を実再読込。
- 実5ファイルの122反射・23欠損hkl、候補、表示、格子定数除外、科学版を保持。元参照フォルダなしで使えることも実再読込で確認。
- 既存の参照・同定・CurveFit・作図・Undo・自動保存3世代を回帰検証。
- 旧テストの「表示名だけ変更」「Project一覧は短いフォルダ名」という前提は新仕様と異なるため、v100テスト内で固定IDからのパス再解決・完全パス列挙へ更新。計算・保存などの期待値は変更していない。
- 元参照5ファイルのSHA-256不変。旧v0.8.2 manifestの212ファイルも不変。sourcesと利用中のExperimentには書き込んでいない。

マニュアル3ページは1100px・390pxの6画面で表示し、リンク・画像・ページ内リンク・横はみ出しを検査。代表画像も目視確認。

## 未確認・制約

- 利用者が現在編集中のExperimentそのものへの導入、長時間連続運用、全OS・全DPI、ノートPCと外部画面の全組合せ。
- 実マウスによるイベント配送・ドラッグ全件、入力ダイアログの全操作。フック処理は直接イベントを与えた試験であり、実マウスの全経路の保証ではない。
- 強制終了・停電の全タイミング。未完了の管理操作を検出した場合は、自動保存を抑止し実行前バックアップを案内する。バックアップは自動では消さない。
- 以前の自動保存クラッシュの完全解消。短時間の保存・世代交代・失敗復旧が通ったことと、長時間安定性は区別する。
- パッケージ外でユーザー自身が記述した文字列・Procedure中の絶対パスは自動書換えの対象外。
- 一括登録・Excel貼り付け等の別要件は今回のv0.9/v1.0対象外。単体読込と旧試料への番号・組成登録を提供。
- 元の共通ライブラリ格納先は互換性のため維持し、Workbench:Referenceには閲覧用の名前付き依存Waveを作る。すでに旧版で取り込まれたカードは、共通ライブラリを開いた時や追加・再読込時にこの別名を作成する。

## 参照した公式仕様

[リベラル名とパス](https://docs.wavemetrics.com/igorpro/programming/programming-techniques)、[ウィンドウフック](https://docs.wavemetrics.com/igorpro/advanced-topics)、[AbortOnValueと例外処理](https://docs.wavemetrics.com/igorpro/programming/keywords/flow-control)、[hcsrのグラフ座標](https://docs.wavemetrics.com/igorpro/commands/hcsr)。
