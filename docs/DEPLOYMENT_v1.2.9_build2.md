# v1.2.9 build2 / Desktop適用結果

2026-11-05 JST。依頼「更新もやって」に従い、DesktopのQS_v1.2.4.pxpへv1.2.9 build2を同名適用しました。旧QS.pxpは保持しています。

本buildはv1.2.9の画面タイトルに残るv1.2.8を修正。変更はxrd_ui.ipfとxrd_ui120.ipfの文字列だけで、解析や凡例処理を変えていません。前版の168 native結果はv1.2.9の処理試験です。今回build2で新たに実施した確認はcompile・実QS画面構築・設定値・別名保存・専用Igor終了・新プロセス再読込・全値照合です。

実QS基準2,481,476項目、画面構築後2,481,477項目。差12はUI位置/幅、UI操作回数/配置cache、active子画面、作図下書きの幅/高さ/既定値flag、自動保存案内だけです。Raw/Processed/Peaks/Assignments/SharedLibraryの全値・UID/revision/metadata/ラベル/Note/式、Undo・格子履歴・保存図の科学差0。新しい名前へ保存し専用PIDだけ終了、新プロセスの全2,481,477項目は保存前と完全一致しました。保存RTE=0。

実参照先はDesktopのQS_update_v1.2.9_20261105_170241/xrd_workbench_v1.2.9_build2です。更新前PXPと旧依存一式を同フォルダへ保持し、最終適用前に元QSのhashがbackupと同じこと、他Igorがないことを確認しました。試験用dump helperは保存前に閉じ、実再読込で未参照と確認しました。利用者の研究データ/詳細TSVは非公開です。

通常Igorを起動し、QS_v1.2.4タイトルと応答を確認して開いたままにしました。画面操作ツールではスクリーンショットが壁紙となり、activate_windowがfailed to activate captured windowで失敗。現在windowを再取得して1回再試行も同じため入力を中止。通常プロセスはCOM ActiveObjectを公開していないため、そこへの入力も行っていません。通常画面の最終クリック/追加Ctrl+Sは未確認です。適用PXPは専用プロセスで保存・再起動照合済みです。

既存保存図は手編集を守るため自動再生成しません。新規図の初期値は16×12cm、Absoluteです。凡例を新書式へ更新する場合は図の書式反映を使用してください。
