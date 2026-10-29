# Igorが提供していた機能の独立化 v0.2.0

2026-10-29 JST。設計v1.0.0への追加実装。基準: Igor XRD Workbench v1.2.3 / fb0c031、保存済み独立v0.1.0 / 7d5f209。

|Igor依存|実装先|内容・境界|
|---|---|---|
|Wave / Data Folder|document.py / workspace.py|固定ID、プロジェクト、原配列/処理配列、参照版、作業データと単位/注記。任意のIgorコマンドは実行しない|
|Table|qt_app.ArrayModel / wave_dialog|大きい配列の遅延表示、原値読取専用、作業コピーのセル編集・処理・コピー・図/表出力|
|Graph / カーソル|qt_app / plotting.py|Qt上のMatplotlib、拡大・移動・表示履歴、カーソル位置、登録マーカーだけを選択、同定Y固定|
|パネルとイベント|StudioWindow / QDockWidget / QDialog|主画面の再利用。表示更新は主画面を作り直さない。補助画面は独立したダイアログ|
|CurveFit|analysis.py / profile_dialog|既存独立エンジンに背景ON/OFFを追加。中心の明示採用、取消、残差図出力。格子は既存の無重み変換回帰|
|Peak AutoFind|analysis.detect_peaks|SciPy方式で代替。完全一致の主張はしない。現行Robust/旧方式の移植と性能比較は残作業|
|参照の表示・候補表|score_candidates / workspace.evidence|元素集合と保護type、候補3モード、スコア内訳、証拠表、強い2反射の確認|
|Undo / Redo|Document.change / undo / redo|失敗時rollback、文書状態20操作、保存後の再読込でも履歴保持。大容量時の最適化は未実施|
|SaveExperiment|save_document / load_document|.labx schema2、schema1読込、一時ファイル+fsync+置換、配列ハッシュ検査。PXPを開く機能ではない|
|復旧・自動保存|workspace.recover / Qt timer|5分/3世代、失敗前の文書保持、起動時候補。バックアップは通常保存を代替しない|
|保存グラフ / WinRecreation|workspace.save_plot|完成図の数値snapshotと書式を保存。閉じても再表示。後の解析変更で自動再描画しない|
|SavePICT / SaveTable|plotting.export_figure / workspace.export_tables|PDF/SVG/PNG、CSV、XLSXを内蔵。Excel本体不要。作業データとフィット図も出力|

## 保存schemaの追加

schema1の科学値を変更せず、waves、plots、reference_settings、audit、削除状態/解析revisionと図のY範囲の既定欄を追加する。読み込んだ現在状態とUndo/Redo内の状態を同じ規則で拡張する。

原配列、配列型/形状/単位、試料ID/参照ID/revision、ピークと角度、割当、採用済みフィット、格子履歴、Undo/Redoの旧フィールドを別プロセスで比較する。新規欄の追加は想定差分。数値の再計算を移行処理に混ぜない。

## 実装済みと完了の区別

この資料は上記の実装経路を説明する。全52機能の完全移植、全Igor操作との同等性、実測受入試験を完了したことを意味しない。未完了はREADMEと機能進捗表へ残す。
