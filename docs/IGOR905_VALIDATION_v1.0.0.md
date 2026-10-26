# Igor Pro 9.05 / .pxp compatibility validation v1.0.0

実施状況: 未実施。利用者のバックアップ済み原本は開いて上書きしない。空の別Igorインスタンスと検証用の複製だけを使う。

## 1. 基準の作成

1. 原本.pxp、既存IPF一式、元測定/参照ファイルの場所・版・ハッシュを記録する。データと対応コードの組を保持する。研究データはGitHubへ送らない。
2. 別の検証フォルダに一式をコピーする。コピー先が既存ファイルなら新しいフォルダ名を選ぶ。以後そこだけで操作する。
3. Igor 9.05でコピーを開き、使用Procedure一覧、外部保存Wave、外部Notebook、include探索先、独自Procedureを確認する。built-in / packed / standalone / WaveMetricsを区別する。
4. 各project/measurementについて下記の基準をData Browser等から検証用ファイルへ記録する。記録作成そのものが値を変更しないことを確認する。

| 比較対象 | 記録する内容 | 合格条件 |
|---|---|---|
| Data Folder / UID | 全階層、projectUID/measurementUID/refUID/revisionUID、Registry | 同じUIDが同じ対象へ解決。消失なし |
| Raw / Processed | 全点、型、次元、単位、scale、dim label、Note | Rawは完全一致。処理後も依頼外の変化なし |
| Peaks / Assignments | peakID、角度、高さ、origin、refIndex/refPeakIndex、shift、mode/created、Unknown | 同定の意味と順序を保持。Unknownは0のまま |
| SharedLibrary | 全RefNの科学値とUID/revision、hkl欠損、旧index対応 | 同定が同じ科学値を参照。NaN/欠損保持 |
| 設定・履歴 | 算法、閾値、単位、格子計算履歴、Undo/Redo、完了状態 | 失われず、不要な再計算なし |
| 依存式・図 | GetFormula、Waveパス、Trace参照、保存図recipe | 式と参照が有効、表示/再表示できる |
| 保存情報 | schemaVersion、activeProject、管理rootとXRDWorkbench root | 全projectへ戻れる。部分保存による欠損なし |

数値比較は先頭数点や合計値だけで合格にしない。NaNを同じ欠損として扱い全要素を比較する。schema移行で物理パス変更が必要な場合だけ、期待差分と理由を事前定義し、UIDと内容の対応で判定する。

## 2. コード更新と再起動

1. 検証コピーで旧Workbench Procedureを閉じ、候補版の `xrd_main.ipf` のみを開く。旧新版を同時に開かない。includeを含む一式を同じ構成で置く。Igor Folder/User Filesが相対includeの先行探索先なので、全Procedureが意図した版・場所から開かれたかFile Information等で確認する。
2. コンパイルする。失敗時は本番へ適用せず、エラーとProcedure一覧を記録する。
3. XRD画面を開く前後で比較する。自動移行が走った場合はMigration:state、復旧folder、schemaVersionを記録する。追加参照の取込や番号変更など不要な操作をしない。
4. 手順1の全対象を比較し、同定・設定を確認する。全project、Unknown、hkl欠損、旧形式を含める。
5. 新しい未使用名 `compat_v1.1.0_日時.pxp` にSave Experiment Asで保存する。
6. この検証用Igorのみを終了し、再起動して保存したコピーを開く。メモリ状態を共有しない。コンパイル・画面・全データを再比較する。
7. Undo/Redo、保存図の再表示は別の複製上で確認する。変更があるので最初の基準比較とは分ける。

## 3. 外部ファイルを参照できない環境

原本やバックアップを移動・削除して試さない。複製を使い、元の絶対パスが存在しない別PC/隔離環境で確認する。単に.pxpを別フォルダに置くだけでは、元PCの絶対パスへ到達できるため隔離試験にはならない。

- A: 測定/参照の外部元ファイルを提供せず、IPF一式と標準ライブラリは提供する。取込済み値・同定・図を確認。追加参照/再取込がフォルダ再指定で回復するかも別に記録する。
- B: 候補IPF一式を提供し、旧IPFの場所へ到達させない。Procedure参照を候補へ切替えた保存コピーが再起動できるか確認する。
- C: IPF一式も提供しない。自己完結を必要とする場合だけ、別のコピーでAdopt Allの対象を確認して採用・別名保存し、さらに隔離した環境で再起動する。採用操作をしない外部参照版との違いを記録する。WaveMetricsは採用対象が別なので確認する。Adoptは将来の外部コード更新方法も変えるため一律に実行しない。

## 記録と判断

日時、Igor版/bit数/OS、本体commit、候補と旧版、試験用コピー名、操作、期待値、実値、合否、ログの保管場所をWORK_LOGに記載する。実データは非公開保管し、repoには匿名の概要だけ置く。不一致は原因確認までmain採用を保留する。各試験は「合格/失敗/未確認」のどれかを明示する。
