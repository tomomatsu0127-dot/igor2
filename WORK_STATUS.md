# v1.2.1 screen transition fix / 2026-10-27 JST

- Branch: codex/xrd-v1.2.1, base 93e92d001cf0df22d834bfb6cbb7fc3d80394966.
- Scope: Igor Workbench screen transitions only. New release xrd_workbench_v1.2.1.
- Reproduced: parent dimensions/maximize unchanged; XRD_ViewSync forces a DoUpdate while controls/graphs are still at baseline geometry, before XRD_RememberControls/XRD_ResizePanel.
- Plan: gate graph view synchronization during construction, synchronize after final layout. Schema/analysis unchanged.
- Native regression and packaging pending.

# WORK_STATUS

管理版: 1.2.0 / 2026-10-27 JST

- 状態: v1.2.0の実装・模擬PXP互換性・最終回帰・ローカル配布作成を完了。main未統合。
- 継続ブランチ: codex/xrd-v1.2.0
- 基準SHA: f45dfb5（codex/safe-development-v1.0.0）
- 基準本体: xrd_workbench_v1.1.0。新規修正先: xrd_workbench_v1.2.0。
- 今回の範囲: Workbench更新時の縮小復帰、強い参照反射の確認、同定Y軸固定、操作メニューサイズ、単一の編集可能な凡例、比較対象の厳密選択、他Project同定済み試料の複製、入力欄の一方向連動、更新手順。
- 原因: XRD_Panelが毎回DoWindow/K→初期サイズNewPanel→RestorePanelState。XRD100_Zoomが局所強度でYを再設定。比較は編集試料を強制追加。凡例は複数Legendを新規作成。Popup本文は10ptの別設定。
- 元のv1.1.0、sources、原本測定・参照・利用者Experimentを変更しない。基準270ファイルのSHAをdocs/BASELINE_FOR_v1.2.0.jsonに保存。
- 実装: 画面と同じグラフの再利用、Y固定、単一凡例、読める操作メニュー、比較対象選択、コピー・入力連動を実装。
- 確認: Igor 9.05ネイティブ281項目で失敗0・実行時エラー0（本版102、実再読込12、管理61、欠損hkl57、Undo/保存41、格子8）。コピー6故障点の復元、空比較復帰、表拡大時の配置も確認。
- 互換性: 模擬v1.1.0 PXPをコピーして新版へ切替え、保存後に別プロセスで再読込。初期化前86,796項目すべて一致。初期化後86,828項目、想定した表示設定97件以外の差0。保存後の再起動で86,828項目すべて一致。旧版270ファイルのSHA一致。
- 性能: 同一模擬負荷の6回更新3組で親画面の再生成6→0回、更新中央値618→132ms。実環境の速度保証ではない。
- 配布: ワークスペース直下xrd_workbench_v1.2.0と同名ZIP。173ファイル、相対include67本とマニュアル参照を検査、ZIP内全ハッシュ一致。ZIP SHA256=5060ead927040743f9bbd0cb8aeba6ea61fbcd94885d218494d33e67068e359c。
- 検証手順の事故: 接続確認失敗時に既存Igorへ終了要求を送った。利用者へ告知・謝罪済み。その後、開始時と同じPID39124・起動日時のIgorが稼働中と確認した。原本上書きなし、未保存内容は未確認。以後の停止はこの実行で作成したPIDのみに限定。
- 次: 利用者は旧PXP/IPFを保持して別名PXPで新版へ切替え。今後の変更は本ブランチの最新SHAから再開。実データ・全DPI・長時間の確認は別途行う。
- 未確認: 利用者の実.pxp、全DPI・実マウス操作、長時間連続運転。
