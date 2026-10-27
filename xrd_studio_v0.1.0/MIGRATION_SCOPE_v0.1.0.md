# 独立化の範囲 v0.1.0

2026-10-27 JST。開始点：GitHub `tomomatsu0127-dot/igor2`、`codex/xrd-v1.2.0`、`93e92d001cf0df22d834bfb6cbb7fc3d80394966`。旧本体の44 IPF、14,477行、602関数を調査。旧版は変更しません。既存Igorファイルとの互換性は今回の必須条件から除外する、とユーザーが明示しました。

## 製品の完成条件

目標はIgorなしで導入・起動・測定読込・解析・作図・保存・再開・出力できる研究用ソフトです。まずXRDを独立して完成させ、MTとMHも別に開発した後、共通文書・試料ID・図設定を使って統合します。本v0.1.0はその第1段階の動作するプレビューで、全機能移行の完成判定はまだ行いません。

| 旧機能・Igorの役割 | 根拠IPF | v0.1.0の対応 | 完成までの残り |
|---|---|---|---|
| Wave / Data Folder / UID管理 | project, experiment, library, manage100 | 共通文書、独立ID、元/処理後配列、参照revision | 汎用Waveエディタは対象外。大量データ性能確認 |
| ファイル読込・厳密検証 | import, reference | 2列測定、名前付き参照、cp932/UTF-8、欠損hkl、VESTA追加列 | 研究室の実ファイルで確認 |
| 規格化 | v3 | min-maxを0〜100%、元値別保持 | 実測比較 |
| 自動・手動ピーク | peak, detect, autofind | 独立検出方式、角度間隔、手動・確認済み保護、ID保持 | Igorの3検出方式の代わりに新方式。検出性能評価、外部リスト |
| 同定・重なり・Unknown | match, v70, reference120 | 一反射一測定ピーク、複数相重なり、スコア表示、強反射確認 | type別カード、保護相、化学元素判定、モード別順位、詳細証拠表 |
| CurveFit局所ピーク | profile | Gaussian/Lorentzian、中心採用と取消、FWHM・誤差・残差 | 実測・境界条件、残差図出力 |
| CurveFit格子定数 | lattice | 立方晶/六方晶の元変換式、無重み回帰、誤差、除外、履歴 | 実測・Igor計算値比較、入力一覧UI |
| グラフ・凡例・比較 | graph, plotworkspace, legend110, ui120 | 比較対象限定、マーカー併用、図設定、注釈、PDF/SVG/PNG | 自由編集、複数レシピ、順序・個別書式、レイアウト細部 |
| 表・マウス・パネル | ui, ui110, ui120 | Tkデスクトップ、操作単位の折畳み、狭い画面用タブ | 全DPI、マウス操作の全ケース |
| Undo/Redo・保存 | v45 | 原子的保存、配列検証、20操作履歴、3世代自動保存 | 故障時復旧・大容量・長時間評価 |
| プロジェクト管理・コピー | manage100, transfer120 | 複数Project、番号重複拒否、別UIDの独立コピー | 試料管理の全操作 |
| .pxp / Igor Procedure | mainのincludeとSaveExperiment | 対象外 | ユーザーが互換性不要と指定 |

## 構成

- `studio/document.py`：将来共用する文書コンテナ・状態変更・保存・Undo。アプリ版とschema版を分離。
- `studio/io.py`：読み取りと検証。ファイルを勝手に修復せず、出所名と元バイトのSHAを保存。
- `studio/analysis.py`：XRDエンジン。画面やIgorに依存しない。
- `studio/plotting.py`：プレビューと出力が共有する描画。寸法はcm、文字/線はpt。
- `studio/app.py`：XRDのデスクトップ画面。

新規ソフトでは元値配列と処理後配列を区別し、解析方式・設定・参照revision・計算入力を保存します。参照値を読み込んだ後は元フォルダがなくても解析を再開できます。任意のIgor式やProcedureを独立版で実行する互換層は作りません。

## 次の開発と完了判定

1. このプレビューで基本操作と研究室の実ファイルを確認し、旧版の機能対応表の残りを実装する。
2. 同じ入力に対するピーク検出・候補順位・中心角度・格子定数を、条件を明示して比較する。新方式の差を仕様として説明できる状態にする。
3. 完成図の編集・保存復元、故障時保存、クリーンPC起動、全DPI、大量データ、長時間運転を検証する。
4. 以上が済んでから独立XRDの安定版とする。別開発のMT/MHには同じ文書境界を使用し、統合前に単位・試料対応・保存互換性を検証する。

## 一次資料

- [SciPy signal](https://docs.scipy.org/doc/scipy/reference/signal.html)：ピーク検出・平滑化のAPI。元Igor方式と等価という根拠にはしていません。
- [Matplotlib](https://matplotlib.org/stable/api/matplotlib_configuration_api.html)：描画・Tkバックエンド。
- [PyInstaller](https://pyinstaller.org/en/stable/operating-mode.html)：実行環境を内包するWindows配布。
