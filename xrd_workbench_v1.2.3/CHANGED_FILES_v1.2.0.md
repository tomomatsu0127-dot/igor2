# 変更ファイル v1.2.0

基準: v1.1.0 / GitHub f45dfb5。旧版ファイルは保持。

| ファイル | 変更 |
|---|---|
| xrd_ui120.ipf（新規） | 画面再利用、操作ボタン、同定Y固定、比較選択・凡例スライダー、空比較からの復帰 |
| xrd_reference120.ipf（新規） | 主・第2反射の照合、採用前確認、画面内表示 |
| xrd_transfer120.ipf（新規） | 他Projectの完了試料を新UIDでコピー、元の保持、失敗復元 |
| xrd_ui.ipf | 親画面維持、同一画面の更新経路、再生成を新規時だけに限定 |
| xrd_ui110.ipf / xrd_v71.ipf | 左比較の単一凡例と共通フォント、選択試料だけ描画 |
| xrd_legend110.ipf | 多列を単一Legendへ統合、プロット寸法保持 |
| xrd_v72.ipf / xrd_v44.ipf | 操作メニューのボタン化と拡大時の配置 |
| xrd_view100.ipf / xrd_v51.ipf / xrd_v81.ipf | 同定中のY固定、更新時に表示と警告を同期 |
| xrd_match.ipf | UI採用直前の強い反射確認、プレビュー時の警告更新 |
| xrd_plotworkspace.ipf / xrd_tree110.ipf | 比較選択をProjectごとに保存、編集試料の強制追加を廃止 |
| xrd_entry110.ipf | 番号→表示名→組成、一方向入力、他Projectコピーの入口、下端の余裕 |
| xrd_manage100.ipf | 新しく作ったコピーだけを復元時に撤去、内部依存を先に解除 |
| xrd_register100.ipf | 管理操作失敗のエラー詳細を保存 |
| xrd_main.ipf | 新規3ファイルのinclude、版番号1.2.0 |

その他のIPFには版のコメント・表示文字列を1.2.0へ更新したものがあります。ピーク検出や格子定数の計算式は変更していません。

試験: `tests/xrd_v120_tests.ipf`、`tests/xrd_semantic120.ipf`、`tests/compare_semantic120.py`を追加。既存`tests/xrd_v100_tests.ipf`の存在しないAssignments:hへの試験用参照を、実際の保存構造であるrefPeakIndexへ訂正しました。実データの保存構造を変えた修正ではありません。

説明: README、MANUAL_ja.html、MANUAL_BEGINNER_ja.html、MANUAL_UPDATE_ja.html、変更履歴、今回の試験結果・スクリーンショットを更新。
