# v1.2.3 変更ファイル

本体45 IPFのうち26ファイル（追加1）。補助パネル25作成箇所へ同じ寸法維持方針を適用。

- `xrd_detect.ipf`
- `xrd_entry110.ipf`
- `xrd_lattice.ipf`
- `xrd_library.ipf`
- `xrd_main.ipf`
- `xrd_manage100.ipf`
- `xrd_manager100.ipf`
- `xrd_plot81.ipf`
- `xrd_plotworkspace.ipf`
- `xrd_profile.ipf`
- `xrd_transfer120.ipf`
- `xrd_tree110.ipf`
- `xrd_ui.ipf`
- `xrd_ui110.ipf`
- `xrd_ui120.ipf`
- `xrd_ui123.ipf`
- `xrd_v3.ipf`
- `xrd_v4.ipf`
- `xrd_v45.ipf`
- `xrd_v50.ipf`
- `xrd_v51.ipf`
- `xrd_v53.ipf`
- `xrd_v70.ipf`
- `xrd_v72.ipf`
- `xrd_v80_styles.ipf`
- `xrd_v80_ui.ipf`

xrd_ui123は再構築前後の寸法引継ぎとfloating targetの解除を担当。各作成関数では/K=1を保持し、作成直後にfixedSize=0を指定してから従来の部品・サイズ制限を設定する。管理画面のwindow path更新はfloating panelも対象に含め、試料名変更後の参照を保持。

解析アルゴリズム、Raw/Processed、同定、保存schemaは変更なし。起動include、初期化、既存の永続データ書込は従来の経路を保持。
