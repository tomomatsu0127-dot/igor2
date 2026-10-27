# WORK_LOG

管理版: 1.0.0。日時はJST。古い記録を消さず追記する。

## 2026-10-26 / checkpoint 1: baseline and recovery records

- 開始: igor2 main `2c30ceffde11c4013bf496fced92f7da6d68ee49`、XRD main `98d1d0268905f0a4d3e0cdd5bf44c020432aaa45`。
- 確認: 各repoの全branch一覧はmainのみ、releaseは0件、再帰treeはtruncated=false。igor2=.gitkeepのみ、XRD=HTML/Python版、両方IPFなし。
- 判断: 空のigor2へ管理基盤を作成。ユーザーがローカルv1.1.0の専用ブランチへの取り込みを許可したため、無改変で正本化候補として保存する。別XRDや元データを削除する必要はない。
- 変更: AGENTS.md、WORK_STATUS.md、WORK_LOG.md、README.md、.gitignore、.gitattributes、候補本体、原本とのSHA-256一覧。
- 確認: コピー時に全ファイルをbyte単位SHA-256照合。実行数は後続検証記録へ記載する。
- 未確認: 利用者の実.pxp、Igor 9.05上での更新・再起動、本体のmain採用。過去同梱の試験結果は参考記録。
- 次: 依存調査、Skills、管理基盤の検証を進める。

## 2026-10-26 / checkpoint 2: dependency evidence and skills

- checkpoint 1のGitHub保存SHA: `c3655396600a8118598d192dc9e3284c21a6a137`。remote一致確認済み。
- 変更: docsの依存報告、Igor実機試験手順、再開手順、3 SkillsとUI metadata、読取専用の管理基盤検査スクリプト。
- 判断: .pxp保存だけで外部IPFが不要とは判断しない。初期化による移行・参照追加走査・2系統rootと内部の参照index対応を保持対象として記録した。アプリのバグ修正やデータ構造変更は行わない。
- 根拠: 本体コードとIgor 9付属Manual II-16/25、III-400–401、IV-166–167、AdoptFiles V-23–24。Web公式仕様も照合。Web PDF取得はtimeoutしたが、インストール済みIgor 9 Manualをローカルで読み確認できた。
- 静的確認: 初回902項目エラー0、原本270ファイル完全一致、相対include63本（本体40本+試験23本）すべて存在、標準Peak AutoFind v5.15の存在を確認。
- Skills: quick_validate.pyで3件合格。最初はPyYAML不足、次にWindowsの既定cp932読込で失敗した。検証用scratchへPyYAMLを導入し、Python -X utf8で解消。既存のシステムSkillやPython環境は変更していない。
- 認識: 当地Codexのapp-server skills/list（read-only、agent実行なし）で3件ともrepo/user scopeでenabled=true、エラー0。repoと公式の~/.agents/skillsへ配置。試験で作成した従来~/.codex/skillsの重複コピーは内容一致を検査して除去した。結果はdocs/SKILL_DISCOVERY_v1.0.0.json。SKILL.md本文の明示読込も確認した。
- 初回commitでGit author未設定のエラーが出たため、接続済みアカウントのnoreply identityをrepo-localに設定してcommit/pushを完了した。global設定は変更していない。
- 未確認: 実Igor 9.05での実行、利用者.pxpの保存/再起動/同定一致、Skillsの実機デバッグでの有効性。構文・検出・指示本文を確認したことと実機機能保証を区別する。
- 次: GitHubからの新規checkout復元検証、改変検出試験、最終記録とDraft PR。

## 2026-10-26 / checkpoint 3: verified resumption and draft review

- checkpoint 2の保存SHA: `4da023ee4bbfeec5159c371754f6746ba2d75d8b`。
- 復元試験: GitHubから新規cloneしたtmp/igor2_resume_check_v1で同じSHA、git status clean、管理基盤検査905項目エラー0を確認。元IPFの改行・encodingを含む270ファイルを保持したまま再開可能。
- 失敗検出試験: 別clone tmp/igor2_negative_check_v1のxrd_main.ipfにだけ検証用コメントを追加し、検査がBaseline changed/size changedと終了コード1を返すことを確認。意図した失敗のため、この試験cloneは継続開発に使わない。
- 変更: STATUSを次回の実.pxp検証待ちへ更新。VALIDATION_RESULTSを追加し、READMEからリンク。
- 最終静的検査: 906項目、エラー0。3 Skillsの構文/検出はcheckpoint 2で合格、原本とアプリコードは以後変更なし。git diff --check合格。
- GitHub: Draft PR #1 https://github.com/tomomatsu0127-dot/igor2/pull/1 を作成してチャットに添付。作業区切りごとにbranchへ保存。mainの開始SHAは保持。
- 判断: 開発基盤の整備は完了。正本化候補のmain採用と実.pxp互換性保証は別の未完了事項。ユーザーの「GitHubの中身を全部消してよい」は許可として受け取ったが、作業に不要な削除は行わず、別XRDの既存実装も保持した。
- 次: AGENTS/STATUS/LOGを読んで継続branchを取得し、Igor 9.05で利用者の複製.pxpの基準採取と更新・保存・再起動比較を実施する。現在のチェックポイントSHAはgit log -1またはPR最新commitから取得する。

## 2026-10-27 / v1.2.0 investigation checkpoint

- 基準: fetch後、safe-development branchのHEAD/remoteがf45dfb5で一致。mainへは反映しない。新しいcodex/xrd-v1.2.0へ分岐。
- Skills: Safe Update、Data Compatibility、Performance Debugを明示読込。調査対象と上書き禁止を確認。
- 原因: XRD_Panelの毎回の初期サイズ再生成、ZoomのY再計算、比較への編集試料強制追加、別Legend列、Popup本文の別フォント設定をコードで確認。
- 方針: 解析ロジックを置換せず、画面の再利用・表示設定を分離する。参照の主/第2強度反射を全測定範囲で照合し、他相との重なりを一致として扱った上で採用前に確認。
- 他Projectからの追加は元を保持した同定済み試料の複製とし、新しい測定UIDを与える。参照ライブラリは共通のまま保持。
- 検証: まだ新版本体の実行確認なし。旧本体の全ファイルSHAを保存した。これから最小修正、別Igor実行、PXP実再起動比較。

## 2026-10-27 / v1.2.0 implementation checkpoint

- 変更: xrd_ui120/reference120/transfer120を追加。親フレームを残して必要内容だけ更新し、同じ画面の操作はグラフも再利用。Y固定をUndoの操作として記録しない。
- 変更: 主・第2反射の確認（範囲外除外、他相と重なる登録ピークは一致）、採用前の確認と常設表示。凡例をネイティブ1ボックスへまとめ、共通フォントとマウス用スライダーを追加。
- 変更: 比較選択をProjectごとに保存し編集試料の強制追加を廃止。他Projectの同定済み試料は新UIDで複製、元を保持。入力は番号→表示名→組成、表示名から組成だけへ反映。
- 検証: Igor 9.05の単体96項目で失敗0。コピーの故障復元・欠損hkl・Unknownも確認。6回更新の3組でフレーム再生成6→0、中央値617.655→132.356ms。
- 互換性: 全項目TSVを旧版コピー、新コード初期化前後、別名PXP保存・別プロセス再起動後で比較。86,796項目採取、解析・保存データ28,886項目は一致。初版検証で表示Yの既定値変更がUndoを1件消費したため、表示基準だけ更新し再試験で解消した。全変更差分はUIと既存初期化でのリスト末尾整形に限る。
- 注意: TSVは日本語を含むバイト列をパーセント符号化し、出力時の文字コード変換を避けた。過去試験の数値を今回の合格数に加えない。
- 事故: 検証helperの接続確認失敗時finallyにQuitがあり、既存Igorへ終了要求を送ってしまった。利用者へ告知済み。原本ファイルへの上書きはしていないが未保存状態の保持は未確認。helperは起動したPIDだけ停止するよう修正し、一意な接続マーカー確認前にはExperimentを開かない。
- 次: 空比較から復帰するケース、保存後の設定/複製結果、既存機能回帰、マニュアル2種、ZIP/マニフェスト、最終checkpoint。

## 2026-10-27 / v1.2.0 final validation and local distribution

- 実装checkpoint: 114273f。最終変更は空比較→再選択の復帰、コピー失敗時の内部依存解除、表示名再フォーカスでの組成保護、表専用モードの警告/リスト配置、登録画面下端の余裕。追加の画面構築フラグ案は回帰を起こしたため撤回し、採用していない。
- 試験の不具合: 旧管理試験が存在しないAssignments:hを参照していた。正しい保存列refPeakIndexへ試験だけ訂正。本版のコピー試験でもhklは共有参照の反射行を通して検証するよう訂正。保存schemaを変えた対応ではない。
- コピーの失敗注入で、内部の別名Wave依存があるとKillDataFolder/Zだけでは撤去できないことを確認した。新しく作成したコピーに限って依存式を解除し、厳密なKillDataFolderで撤去。全6mutationで半端な試料が残らず、ロック解除と元データの保持を確認。
- Igor 9.05最終実行: 本版102、別プロセス実再読込12、管理61、欠損hkl57、Undo/自動保存41、格子8。計281項目合格、失敗0、実行時エラー0。旧版から持ち越したログを計上しない。
- 完全比較: 新しいcompat_1831940809に旧PXPをコピーし、初期化前86,796記録全一致。初期化後86,828記録の97差分はUI/比較設定・既存文字列末尾整形・Y表示基準のみ。別名保存後に専用Igorを終了・起動して再読込、86,828記録全一致。Raw/Processed/Peaks/Assignments/参照UID/revision/hkl/Registry/格子履歴/Undo/保存図を含む。比較helperは差分を明示し想定外の差を失敗にする。最初の期待値112は実際の17桁表示112.00000000000001へ訂正した。
- 目視: 同定3試料、警告・表・大きい操作ボタン、単一の2列凡例、登録画面の順序と下端をIgor画像で確認。GUI操作そのものを全部実マウスで行ったとは報告しない。
- 性能: 同一模擬負荷の6回更新3組。旧681.832/602.512/617.655ms、新172.452/114.886/132.356ms、フレーム再生成6→0。実環境での速度保証ではない。
- 文書: 初心者向けと更新向けHTML、README、変更ファイル、検証結果、今回だけのログを作成。旧図の手編集を勝手に再生成しないこと、コピーは独立・管理バックアップ扱いであることを記載。
- 配布: 直下xrd_workbench_v1.2.0とZIP。173ファイル、IPF44、相対include67本、マニュアル参照正常。元測定・参照、ユーザーPXPや試験PXP・大きいTSVは含めない。ZIP展開内容の全SHA一致。SHA256=5060ead927040743f9bbd0cb8aeba6ea61fbcd94885d218494d33e67068e359c。旧版270ファイルは基準SHA一致。CRLFを意図的に保持しているためgitの差分空白検査はcr-at-eolで実施し合格。
- 事故の追加確認: 既存Igor PID39124、起動日時2026-10-26 17:59:01、タイトルQSが引き続き稼働していることを確認。終了要求を送った誤りは撤回できないが、アプリが閉じた・未保存状態が失われたと断定しない。helperは専用PID以外を停止せず、接続マーカー確認前はPXPを開かない。
- 未確認: 利用者の実PXP、全DPI/モニター移動、実マウスの全操作、長時間運転、採用済み/独自Procedure付きPXP、旧パス完全遮断環境。mainへ統合しない。
- 次: 最終checkpointをcodex/xrd-v1.2.0へpushし、ローカルZIPと更新ガイドを渡す。

## 2026-10-27 / v1.2.0 delivery checkpoint

- 5058d7dをcodex/xrd-v1.2.0へpush済み。mainは変更していない。配布ZIPは前項SHAと一致。
- 差分の空白検査補足: コード・文書はcr-at-eolで合格。Igorの故障注入結果Printには空のエラー文字列を表す末尾空白が6行あり、出力を保持したため全ログを含める検査はその6行を報告する。コードの不具合・試験失敗ではない。コード・文書だけを対象にした最終検査は合格。
- 利用者へ渡すもの: ワークスペース直下のZIP、更新HTML、初心者HTML、変更ファイル/試験結果。次の開発は本branchの最新SHAを取得して再開する。

## 2026-10-27 / independent XRD v0.1.0 investigation and implementation checkpoint

- 最新版をGitHub branch一覧とfetchで確認: codex/xrd-v1.2.0、93e92d001cf0df22d834bfb6cbb7fc3d80394966。cleanなcheckoutから新規branch codex/xrd-standalone-v0.1.0へ分岐。
- ユーザー方針: 各モジュールは独立して作り、ゆくゆく統合。最初に.pxpをIgorなしで開く必要ありとの回答があったが、続く明示回答で既存Igorの引継ぎ不要・新規独立ソフトへ訂正。PXP互換調査を打ち切り、互換層は実装しない。
- 調査: 44 IPF・14,477行・602関数。入口include、元値/処理後、参照ロード、候補スコア、共通シフト、Gaussian/Lorentzian、立方晶/六方晶の変換式、保存・Undoを確認。旧v1.2.0の203ファイルのSHAを新規manifestへ保存。
- 実装: xrd_studio_v0.1.0に新規独立エンジン・共通文書・Tk UI・描画・出力・人工データ。旧IPF・利用者PXP・測定原本は変更しない。Peak AutoFindを同一と偽らず、SciPyベースの独立方式に別アルゴリズム名を与え設定/依存版を保存。
- 方針: Python/Tk + NumPy/SciPy/Matplotlib。当地の既存環境を使用し、global packageの追加・更新なし。将来のMT/MHは共通文書境界とエンジン分離を再利用するが、統合済みと扱わない。
- 検証: エンジン17試験合格。原値不変、厳密パーサ、重なり/Unknown/参照反射所有、中心の明示採用、既知格子定数、別プロセス保存読込、履歴・ハッシュ検証・図出力を確認。旧版同梱の参照例4種も読込成功（1/2/156/8反射）。
- GUI: 最初の画面で縦長・高倍率環境にはみ出しを確認し、狭幅時タブUIと2段ツールバーへ変更。実画面で条件タブと検出ボタンを操作。Tk実体の狭幅/横長11チェック×2=22項目合格。最初の接続試験の単独図の線数期待値は、選択ピークの補助線も数えた誤りだったため測定曲線のlabelで判定するよう訂正。アプリのデータ不具合ではない。
- 未完了: type別カード・保護分類・専用元素判定・外部ピークリスト・候補モード・全証拠表・複数作図レシピ・自由グラフ編集・試料管理の全操作。本版は実行可能な開発プレビュー。実測/長時間/全DPI/クリーンPCは未確認。
- 次: EXEビルド、EXE起動と画面確認、配布ZIP/ハッシュ、最終結果記録、branchへのcommit/push。既存Igorには接続・終了要求を送らない。
