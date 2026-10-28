# XRD Workbench v1.2.2

最大化時のサイズ警告と重複更新を修正し、再生成できる画面・図・表を×で確認なしに閉じる設定へ統一しました。

- [更新と再表示の手順](UPDATE_v1.2.2.html)
- [今回の検証結果・未確認](TEST_RESULTS_v1.2.2.md)
- [今回の変更ファイル](CHANGED_FILES_v1.2.2.md)
- [基本操作](MANUAL_BEGINNER_ja.html)

入口は `xrd_main.ipf` だけです。相対include先44個の本体IPF一式を保持してください。
閉じたWorkbenchはF6、完成図は作図画面の保存済み図から再表示します。解析操作のCtrl+Z/Ctrl+Shift+Zは従来どおりです。

v1.2.0/v1.2.1の文書・manifest・resultsは過去版の記録です。今回のログは `tests/results_v122/`、現在の配布内容は `MANIFEST_v1.2.2.json` を参照します。利用者実PXP、全DPI、実際の×クリック、長時間運転は未確認です。
