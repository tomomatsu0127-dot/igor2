# 保存・再開手順 v1.0.0

正本: https://github.com/tomomatsu0127-dot/igor2 / 継続branch: `codex/safe-development-v1.0.0`。mainは未採用。

## 次のWorkチャット

repoの継続ブランチを開いて、次のように依頼する。

> igor2のcodex/safe-development-v1.0.0を取得し、AGENTS.md、WORK_STATUS.md、WORK_LOG.mdを読んで前回の続きから再開してください。まず最新SHA・未push変更・未完了事項を確認してください。既存Experimentと元データは変更せず、未確認のIgor 9.05互換性検証を優先してください。

ローカルcheckoutがない場合は以下で取得する。既存ディレクトリに上書きしない。

```powershell
git clone --branch codex/safe-development-v1.0.0 https://github.com/tomomatsu0127-dot/igor2.git igor2-resume
Set-Location igor2-resume
git status --short --branch
git log -3 --oneline
python tools/verify_environment_v1.0.0.py
```

既存checkoutがある場合はAGENTSの手順でstatus→fetch→ローカル/remote比較を先に行う。未コミット変更は保護し、無条件のpull/reset/cleanをしない。継続branchがmerge済みならPRとmainの記録を確認してから、新しい作業branchを作る。

## 作業区切りで保存する

STATUSに完了/未完了/次操作を反映し、LOGへ変更・判断理由・試験を追記する。差分を読んで意図したファイルだけstageする。

```powershell
git diff --check
git status --short
git add AGENTS.md WORK_STATUS.md WORK_LOG.md docs .agents tools README.md
git commit -m "docs: checkpoint with validation and next action"
git push origin codex/safe-development-v1.0.0
git rev-parse HEAD
git ls-remote origin refs/heads/codex/safe-development-v1.0.0
```

2つのSHAが一致することを確認する。GitHub UIだけで編集した場合はローカルへ取り込んでから継続する。push失敗・権限/ネットワーク障害時は未pushのコミットを保持し、未同期であることを明記する。Gitのauthor未設定ならユーザー確認済みのアカウントのrepo-local設定を使用する。global設定や認証情報を文書に書かない。

突然の切断は最後のpushまで復元可能。未保存メモリや未push差分まで自動復元される仕組みではない。長い作業に入る前にもチェックポイントを作る。自動スケジュールは作成していない。

## Skillsの利用

正本はrepoの `.agents/skills/`。Codexをrepo内で開くと認識対象になる。`$igor-safe-update`、`$igor-data-compatibility`、`$igor-performance-debug` で明示指定できる。候補に見えなければCodexを再起動する。認識しない場合も該当SKILL.mdのパスを指定して読み込ませられる。

このPCには同内容を公式ユーザー配置 `~/.agents/skills/` へ配置した。当地のskill-creatorが案内する従来の `~/.codex/skills/` も検出されることを実測したが、重複を増やさないため今回作成した従来配置のコピーのみ除去した。repo版とユーザー版はCodexのskills/listでscope=repo/user、enabled=true、エラー0を確認済み。個人コピーが古くなった場合、repo版を優先し、差分を確認して更新する。同名Skillが複数候補に表示される場合はrepo版のパスを選ぶ。独自変更を上書きしない。

参照: [OpenAI公式 Build skills](https://learn.chatgpt.com/docs/build-skills)。ホストの自動認識/UI表示と、ファイルの構文・明示読込は別の確認項目。
