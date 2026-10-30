# v1.2.4 検証 / 2026-10-29 JST

Igor Pro 9.05 Windows 64-bit。今回起動した専用プロセスと人工データで検証。旧版同梱ログは今回の合格数へ加えていません。

| 検証 | 合格数 |
|---|---:|
| モーダル前後の退避/復帰、入れ子、元からhidden/他パネル除外、位置/寸法/最大化、原値保持 | 17 |
| 補助10画面×通常/最大化、繰り返し更新と寸法・操作callback | 247 |
| 既存同定/参照/コピー/故障復元/凡例/比較の回帰 | 102 |
| 合計 | 366 |

失敗0。ログはtests/results_v124。regressionの6故障点では半端なコピーが残らず元データを保持。

実マウス/キーボード: 旧版の「元フォルダの追加を確認」でDoAlertDialogがfloatingパネルの背後に存在することを再現。新版でOK/No/Yes、プロジェクト名入力・作成、追加後の再操作・Cancel、参照フォルダ選択・サンプル4参照の取込と画面復帰を確認。最終コードで追加・再操作後のCancelを実行し、native WinListでもXRDProjectManagerが1枚だけ、XRDProjectManager0なし、RTE=0を確認。UI操作の記録はui124_native_state.txtとWORK_LOG。

模擬v1.2.3 PXPの185,889項目は、新版読込前/後、初期化後、別名保存して専用Igorを終了・再起動・再読込した後まで全項目一致。Raw/Processed、ピーク、Assignments/Unknown/hkl欠損、参照UID/revision、Registry、格子履歴、Undo、依存式等を含む。保存schemaの変更なし。

途中試行の問題: DoPromptのby-reference変数直接指定をlocal draftへ訂正。floatingの可視性操作をDoWindow/HIDEからGetWindow/SetWindowへ訂正。試験helperの構文、regressionのmissing_hkl120.txt配置、呼出引数を訂正。追加操作でDoWindow/Kが元のfloating画面を残すことを検出し、KillWindow/Zへの変更後に実操作/WinListで重複なしを確認。失敗/timeout/途中版の結果を最終合格へ混ぜていません。

未確認: 利用者の実PXP、全DPI・複数モニター、長時間・大容量、独自/採用済みProcedure、旧パス遮断環境。実データに対する速度改善率は未測定。main未統合。
