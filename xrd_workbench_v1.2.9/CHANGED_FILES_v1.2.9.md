# v1.2.9 変更ファイル

- xrd_legend110.ipf
- xrd_main.ipf
- xrd_plot81.ipf
- xrd_plotworkspace.ipf
- xrd_v3.ipf
- xrd_v51.ipf
- xrd_v52.ipf

凡例: xrd_legend110。新規図寸法: xrd_v3/v51/v52/plotworkspace。Snapshotの読みやすいtrace aliasと更新時の重複除去: plotworkspace/plot81。entrypoint: main。schema/解析式/Assignments/参照科学値を変更しません。

新規SnapshotだけsampleNumber129を記録し、旧SnapshotではsourceUIDから試料番号を解決、解決不能ならS1等へfallbackします。保存native macroはそのまま再表示します。PlotWorkspace:UI:figureDefaults129は新規図下書きの初回既定値設定だけに用います。
