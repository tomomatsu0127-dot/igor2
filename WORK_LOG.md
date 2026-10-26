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
