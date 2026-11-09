# DESIGN_REVIEW v1.2.7

2026-11-04。公式資料を確認し、今回の登録・整理・同定の操作に直接役立つ点を採用した。

|参考|公式資料にある流れ|今回の採用|
|---|---|---|
|HighScore|説明できていないピーク/特徴を確認し、候補とグラフを見直す|既存の同定結果を保ち、前/次の未同定ピークへ移動できる操作を追加|
|Match!|ピーク探索の条件設定と、検出ピークから候補を評価する流れ|新規測定の突出量初期値を変更・保存できる設定入口と、既存測定の条件の保持|
|利用者の今回の操作|測定の追加・番号入力・project整理|番号順、上下移動、Tab順序、組成から表示名への連動、追加成功時の終了、plain textのproject追加|

公式資料:

- [HighScore公式Quick Start Guide](https://dam.malvernpanalytical.com/a6bf5874-67a7-4911-83d0-b05c00efbda9/qsg_highscore-highscore-plus_en_Original%20file.pdf)
- [HighScore公式機能紹介](https://www.malvernpanalytical.com/en/products/category/software/x-ray-diffraction-software/highscore)
- [Match!公式Peak Searching](https://www.crystalimpact.de/match/v3_help/idh_rawdata-proc_peaksearch.htm)
- [Match!公式Function List](https://www.crystalimpact.com/match/functions.htm)

上の「今回の採用」は本ソフト側の実装判断。各社との同等精度を示すものではない。既にある候補の根拠表示、未確認の強い参照ピークの案内、同定一覧、解析レポート、検出プレビュー、Undoは保持し、今回の登録UI改善に結び付けた。解析アルゴリズムや参照databaseを追加する変更は行っていない。
