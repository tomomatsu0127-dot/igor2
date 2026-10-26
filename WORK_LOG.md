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
