# v1.2.4 変更ファイル

本体46 IPFのうち8ファイル（追加1）。

- `xrd_library.ipf`
- `xrd_main.ipf`
- `xrd_modal124.ipf`
- `xrd_reference.ipf`
- `xrd_tree110.ipf`
- `xrd_ui.ipf`
- `xrd_ui120.ipf`
- `xrd_v80_ui.ipf`

xrd_modal124: 表示中のXRD floatingパネルだけを標準入力/確認/フォルダ選択中に隠し、確定・取消・例外時に同じオブジェクトを復帰。元のhidden状態、寸法、下書きを保持。入れ子も対応。
main/reference/library: プロジェクト名入力、参照追加確認・追加検出確認・フォルダ選択で退避を利用。プロジェクト作成成功を明示して一覧の更新を判定。
v80_ui: 管理画面からの追加をExecute/Pへ回し、control callback終了後に処理。
tree110/library: floatingパネルの再構築前の閉鎖をKillWindow/Zへ変更し、DoWindow/Kで既存floatが残る問題を修正。
ui/ui120: 表示の版番号のみ。

科学計算・保存schema・Raw/Processed・同定・UID/revisionの変更なし。既存includeと起動・自動保存経路を維持。
