# XRDWorkbench dependency audit v1.0.0

2026-10-26 JST。対象はブランチ `codex/safe-development-v1.0.0` の `xrd_workbench_v1.1.0/`。元はユーザー許可によるローカルv1.1.0の無改変コピー。GitHubに既存IPFはなかったため、本取り込み前から存在したGitHubリリースとしては扱わない。原本の270ファイルは [manifest](BASELINE_MANIFEST_v1.0.0.json) で識別する。

## リポジトリと入口

調査開始時のigor2 main=`2c30ceffde11c4013bf496fced92f7da6d68ee49` は.gitkeepのみ。XRD main=`98d1d0268905f0a4d3e0cdd5bf44c020432aaa45` はHTML/Python実装・説明・sample_dataで、IPFなし。双方mainのみ、releaseなし。全treeでtruncated=falseを確認した。

取り込んだ本体はルートのIPF、tests、samples、reference_examples、preview、マニュアル、過去検証ログからなる。入口は [xrd_main.ipf](../xrd_workbench_v1.1.0/xrd_main.ipf)。2行目に#pragma version=1.10、3–42行に40本の `#include ":xrd_..."`、43行に `#include <Peak AutoFind>` がある。主な群はプロジェクト・測定読込、ピーク・同定、参照、格子、保存/Undo、v3–v82の拡張、共通ライブラリ・移行、v100管理、v110のUI。全40本の相対対象は同じフォルダに存在する。

`Peak AutoFind` はWaveMetrics提供。当地のIgor 9インストールでは `WaveMetrics Procedures/Analysis/Peak Fitting/Peak AutoFind.ipf` が存在し#pragma version=5.15。コードは `xrd_autofind.ipf` から `AutomaticallyFindPeaks` を使用する。製品付属IPFはrepoへコピーしない。標準ライブラリの存在確認はコンパイル試験とは別である。

## 最初に開いた後も元IPFが必要か

**必要になる設計である。** 実行中はコンパイル済み処理を使うが、「一度開けば元IPFが不要」という配布方式ではない。Igorのshared procedureは外部ファイルを参照し、Experiment再読込時に再度開く。includeもコンパイル時にファイルを開く。相対includeは呼出元の場所と構成を保つ必要がある。明示的に開いたxrd_mainだけを残し、子IPFを削除する運用は不可。

Igor 9 Manual IV-166（物理1260ページ）の相対include探索順は、Igor Pro Folder→Igor Pro User Files→includeを書いたProcedureのフォルダ（built-inならExperimentのフォルダ）。同名の古いIPFが上位探索先にあると、同じ場所の新版より先に見つかる可能性がある。実機ではProcedureのFile Information等で実際の参照先も確認する。静的な相対ファイル存在検査は探索先の競合までは保証しない。

Procedureの種類と保存状態は別問題である。built-in procedureや採用済みのprocedureはpacked内に保存されるが、外部shared procedureは参照として残り得る。Adoptで外部ファイルを採用して保存する手段はあるが、本体の相対include解決まで含む自己完結性は実機確認が必要。現行本体にはAdoptFilesを呼んで自動的に全依存を内包する処理は見つからない。利用者の.pxpでどのprocedureが採用済みかは**未確認**。

根拠: [Procedure Windows](https://docs.wavemetrics.com/igorpro/programming/procedure-windows)、Igor 9付属ManualのIII-400–401（PDF物理974–975ページ）。packedの一般仕様はII-16（物理88）、採用はII-25（物理97）とAdoptFiles V-23–24（物理1461–1462）も確認した。現行Web版の見出しはIgor 10なので、9.05の細部は付属Manualと実機を優先する。

## .pxpに保存される状態と外部依存

| 状態 | コード根拠 | 保存/依存の判定 |
|---|---|---|
| 元測定値 | xrd_import.ipf:24–95、xrd_project.ipf:249–299 | Open/R→FReadLine→Closeで読み、Raw:twoTheta / Raw:intensityへDuplicate。常時元ファイルから読む方式ではない |
| 処理後と描画用値 | xrd_project.ipf:267、xrd_experiment.ipf:104–132 | Processedを保持、Wavesの一部はRaw/ProcessedへのSetFormula。依存先はExperiment内部Wave |
| 同定・ピーク | xrd_project.ipf:268–273、xrd_match.ipf:298以降 | Peaks/Assignmentsの数値Wave・文字Wave。AssignmentsはpeakID/refIndex/refPeakIndex/shift/mode/created等。表の表示文字列だけを保存しても不十分 |
| 参照科学値 | xrd_reference.ipf:72–219、xrd_library.ipf:4–28 | TXT等を読んでtwoTheta/intensity/h/k/l/dをSharedLibrary:References:RefNへDuplicate。元参照は継続ストリームではない |
| 参照の履歴と対応 | xrd_library.ipf:94–165、xrd_experiment.ipf:350以降/562/629 | refUID/revisionUID、旧→共通indexの対応と格子計算の参照revisionが必要 |
| UIDとパス | xrd_experiment.ipf:5–102、xrd_manage100.ipf:3–10 | XRDWorkbench:Registry/Schemaと、実プロジェクトを置くWorkbench:Managementの双方が存在。片方だけ移すと欠損する |
| 元ファイルの所在 | xrd_project.ipf:277、xrd_reference.ipf:18–19/207、xrd_v4.ipf:151–163 | source、fileName、referenceFolderHint、symbolic pathは所在情報。数値のキャッシュとは別。移動後の追加読込には再指定が必要 |
| 復旧保存 | xrd_v45.ipf:61–138 | SaveExperiment/C/F={1,"",0}でpackedコピー。3世代を循環置換。homeまたはIgorUserFiles/カスタム保存先に依存し、外部Procedure採用の保証にはならない |
| 管理前backup | xrd_manage100.ipf:83–117 | packedコピーを保存。バックアップ先の可用性が必要 |

packed保存は通常、Experiment所属のWave・変数・Data Folder・グラフ・procedure等を保持する。外部保存済みWave等は別参照になり得るため、利用者が他ツールで追加した共有Wave/Procedureも実.pxpで棚卸しする。元測定TXT/参照TXTそのもののバイト列やPDFを自動添付する処理ではない。

根拠: [Experiments, Files and Folders](https://docs.wavemetrics.com/igorpro/igor-basics/experiments-files-and-folders)、[SaveExperiment](https://docs.wavemetrics.com/igorpro/commands/saveexperiment)、[AdoptFiles](https://docs.wavemetrics.com/igorpro/commands/adoptfiles)。SaveExperimentは既存の同名ファイルを上書きする。試験は未使用の別名へ保存する。

## 読み込みと移動・削除の影響

測定入力はtxt/csv/xy/datの2列を厳密に解析し、2theta増加順・最低3点を検証する（xrd_import.ipf）。参照入力は選択フォルダのtxt/csv/tsv/datを走査し、列名から読み、同一内容を再利用しつつ新しい科学値を別revisionとして追加する（xrd_reference.ipf、xrd_library.ipf）。

| 移動したもの | 既に読み込んだ値 | 後の操作への影響 |
|---|---|---|
| 旧IPF一式 | 現在のメモリ実行が継続する場合でも安全とは判定できない | 元版を参照した.pxpの再読込・再コンパイルで欠損。更新前後の版を両方保存する |
| 元測定TXT等 | Raw/Processedとして保持された数値はコード上独立 | 再取込や由来の追跡には元ファイルが必要。source文字列は自動修復されない |
| 元参照フォルダ | SharedLibraryへ取り込まれた値と既存同定はコード上独立 | 追加走査・再取込にはフォルダ再指定。XRD_RestoreReferencePathは復元失敗時にsymbolic pathを解除する |
| Experiment内のSharedLibrary/Registry等 | 削除すれば参照index・UID対応が失われる | 同定結果の意味を再構築できない。外部IPF更新とは分けて保持する |

XRD_Openは `XRD80_CheckLibraryAdditions` を予約し、フォルダを走査して新規ファイルがあると取込確認を出す（xrd_main.ipf:75以降、xrd_library.ipf:228–272）。参照フォルダとの接点は初回だけではない。通常の同定はキャッシュを使うが、「以後まったく外部を参照しない」とは言えない。

削除は推奨しない。必要な隔離試験は原本の移動ではなく、別の検証用Windows環境または複製ツリーで行う。実データでの挙動は**未確認**。

## ソフトだけの更新で同定結果を引き継ぐ条件

コード上、状態はprocedureのテキストではなくData Folder/Waveに保持されるため、コードの差替えと状態の保持を分離できる。ただし**任意の将来版との互換性を保証するものではない**。次の条件を検証する。

- Raw/Processed、Peaks、Assignments、SharedLibraryの対応、Registry/UID、格子履歴、Undo、PlotWorkspaceと式/グラフの参照先を丸ごと保持する。
- activeProjectだけでなく全プロジェクトを比較する。Unknown（refIndex=0）、hkl欠損、旧形式、削除済み項目も含める。
- XRD_InitはschemaVersion<800でXRD80_MigrateExperimentを呼び、その後XRD_UpgradeProjectで表や候補等を再構成する（xrd_project.ipf:4–30/79–138）。「起動するだけだから書換えがない」と扱わない。
- 移行は復旧Data Folderを作成するが、生成条件はUID欠損等による（xrd_experiment.ipf:666以降）。この内部コピーだけを全利用者の外部バックアップの代わりにしない。
- v1.1.0の番号変更は実フォルダ/Wave/依存式へ影響する管理操作。更新直後に一括再登録しない。独自Procedureの文字列パスまでは保証できない。

## 見つけた課題と推奨対応（今回は未修正）

1. 本体の配布版1.1.0、project version=0.6.0、schemaVersion=800は異なる概念だが表示が混在する。次回、版の意味を文書化し、明示的な互換性表を作る。
2. 実験全体にWorkbenchとXRDWorkbenchの2系統のrootがある。部分export/移植で見落とす危険がある。次回の互換性試験で双方を棚卸しする。
3. 自動移行・起動時再構築・参照追加走査は副作用を持つ。将来、更新前後の差分を保存する検証用export機構を別依頼で検討する。
4. .pxpコピーにも外部IPF参照が残り得る。旧版IPF一式とハッシュを保存し、再起動試験を配布前の条件とする。
5. 現行自動保存は3世代循環。長期保管用の不変バックアップは別に保持する。
6. 相対includeにも探索順による別版混入の余地がある。Igor/User Filesの同名IPFやショートカットを棚卸しし、実際に開いたファイルの版・パスを記録する。既存ファイルの一律削除は行わない。

## 今回の検証限界

コード、ファイル存在、SHA-256、公式仕様を確認した。過去のTEST_RESULTS_v1.1.0.mdに記載の326合格は過去資料であり今回の実行結果ではない。当地にIgor 9がインストールされていることは確認したが、今回Igorを起動せず、利用者の実.pxpのprocedure保存状態・保存後再読込・同定の完全一致は未確認。[実機試験手順](IGOR905_VALIDATION_v1.0.0.md)を参照。
