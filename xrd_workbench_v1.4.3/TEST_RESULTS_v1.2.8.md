# v1.2.8 検証結果（2026-11-04）

## 速度

Igor Pro 9.05 64-bit、Windows、同じPC・共通の計測関数・専用Automation（親ウィンドウ非表示、DoUpdateあり）。読み込み・コンパイルを計測から除き、候補の再計算と比較更新を含む反復操作を測定しました。プロジェクト内600件の合成測定は各4001点・30ピーク、参照85件、比較5件。元の24測定も含む全体624件・2,471,508点です。

|操作|v1.2.7中央値|v1.2.8中央値|
|---|---:|---:|
|ピーク選択＋比較更新＋DoUpdate（5回）|2804.88ms|156.721ms|
|同じ画面の更新＋比較更新＋DoUpdate（3回）|7229.25ms|261.063ms|
|比較パス5件の取得（3回）|2394.43ms|0.832ms|
|測定選択ボタン更新（3回）|2109.24ms|0.1175ms|

実QS（24測定、85参照）で同じ5回のピーク選択は309.882→174.096ms。最初の1回を除外せず、測定値をすべてperformance600.jsonへ収録しています。数値はこの負荷と環境での観測であり、実画面の体感や別ハードウェアの速度保証ではありません。600曲線の同時表示は未確認です。

## 処理・保存の保持

- Native 226 assertions合格、失敗0: 新性能/読取の非破壊12、workflow43、選択/管理26、比較30、既存同定/コピー102、native検出13。今回の成功runのみresults_v128へ保存。
- 600件の同定画面で120回の選択、60回warm後のWave数17257→17257。履歴・参照を削除して軽量化していません。全期間/全経路のメモリリーク不存在を意味しません。
- 600件で10選択: Candidates/Evidence/Preview/Peaks/Assignmentsの共通29185項目が一致。新側でだけ先にstep1を開いたため追加されたfocusTable表示項目1050以外に差なし。
- 実QSで10選択: 同じ19451項目が完全一致。候補順位・スコア、参照反射、shift、根拠、一致/重なり、元ピーク・Assignmentsを照合。
- 実QS全値: 更新前2358888項目。新コード初期化前は同数・差5（UI3、表示範囲の浮動小数点丸め2）。初期化後も同数・差14（UI10、表示範囲3、自動保存案内/active子画面1）。Raw/Processed、全Wave metadata/式、UID、同定、SharedLibraryの科学revision、Undo/Redoと格子履歴、既存作図の科学値に差なし。
- 別名PXP保存時RTE=0。保存時に既存IgorのCopyDimLabelToCString出力があるため、labelを含めて終了→新プロセス実再読込の2358888項目を全比較。差1はactive子画面状態のみ、科学差0。最終集計はactual_compatibility_summary.json。

更新中の試験用Igor終了1回は、画面終了と旧entrypointを同時に予約した直後のucrtbase.dll / c0000409。処理を分けた再試行は正常。内部原因は未確定。元QSは上書きせず独立backup/旧IPFを保持した。試験fixture不足のfile picker待ちとPowerShell/試験Printの記述問題は環境準備を修正して再合格した。

長時間連続使用、別PCで旧パスを遮断した移設、全DPI/モニター、全独自Procedureは未確認。詳細TSV・研究PXP・実データの画像は公開しない。

## 参照

WaveModCountの検証用途と制約は[WaveMetrics Igor Pro 9公式マニュアル](https://www.wavemetrics.net/doc/igorman/IgorMan.pdf)に従い、main threadのglobal Waveについて更新前後を比較しています。性能改善はコード上の無駄の確認と実測に基づき、同定アルゴリズムを置き換えていません。
