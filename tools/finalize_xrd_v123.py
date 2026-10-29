from pathlib import Path
import hashlib,json,re,shutil,sys
repo=Path(__file__).resolve().parents[1];src=repo/'xrd_workbench_v1.2.3';old=repo/'xrd_workbench_v1.2.2'
scratch=repo/'scratch/v123';out=src/'tests/results_v123';out.mkdir(exist_ok=True)
logs={'native123_final.txt':247,'transitions123_final.txt':343,'regression120_pass.txt':102,'close123.txt':18,'undo123.txt':41,'reopened123.txt':12}
for name,count in logs.items():
    text=(scratch/name).read_text(encoding='utf-8-sig')
    assert text.count('PASS:')==count,(name,text.count('PASS:'))
    assert 'FAIL:' not in text and 'RUNTIME ERROR' not in text
    text=text.replace(str(repo).replace('\\',':'),'<validation-workspace>').replace(str(repo),'<validation-workspace>')
    (out/name).write_text(text,encoding='utf-8')
sys.path.insert(0,str(src/'tests'));from compare_semantic120 import read
path=Path((scratch/'latest_compat.txt').read_text(encoding='utf-8-sig'));control=Path((scratch/'latest_control.txt').read_text(encoding='utf-8-sig'))
a=read(path/'old.tsv');b=read(path/'new_preinit.tsv');c=read(path/'new_postinit.tsv');d=read(path/'reopened.tsv');control_post=read(control/'new_postinit.tsv')
changes=[k for k in a.keys()|b.keys() if a.get(k)!=b.get(k)]
assert changes==["S|root:Packages:Workbench:Management:Project1:Measurements:'015':uiActiveChild"],changes
assert b==c and c==d and c==control_post,'Unexpected semantic or restart change'
summary={'date_jst':'2026-10-29','igor':'9.05 Windows 64-bit','fixture':'validated synthetic v1.2.2 PXP; no user data','old_records':len(a),'new_preinit_records':len(b),'code_load_and_initialization_matches_old_control':True,'close_hook_only_change':{k:{'old':a.get(k),'new':b.get(k)} for k in changes},'postinit_records':len(c),'restart_records':len(d),'restart_changes':0,'all_final_native_assertions':sum(logs.values())}
(out/'compatibility123.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
changed=[p.name for p in src.glob('*.ipf') if not (old/p.name).exists() or p.read_bytes()!=(old/p.name).read_bytes()]
panels=sum(p.read_text(encoding='utf-8-sig').count('NewPanel/FLT=1') for p in src.glob('*.ipf'))
(src/'README_ja.md').write_text('''# XRD Workbench v1.2.3

操作中のウィンドウの大きさを維持する更新です。

- 設定・参照・一覧などの補助画面を独立したパネルとして開き、主画面の最大化とサイズを保持します。
- 開いている補助画面の更新では、調整したサイズと位置を引き継ぎます。
- 管理・作図画面の部品更新で初期サイズへ戻す処理を除去しました。

入口は **xrd_main.ipf** だけです。45個の本体IPFを同じフォルダに保持してください。

旧版一式と現在のExperimentを保持し、旧版のProcedureを外して新版の入口へ切り替え、F6で開きます。旧新版を同時に読み込まず、更新後は別名保存してください。測定・参照データの再取込は不要です。

補助画面は主画面の前に表示されます。不要になった画面は×で閉じられます。補助画面を×で閉じた後の新規表示は初期サイズです。完成図のサイズ変更・画面に収める操作は従来どおりです。

- [更新手順](UPDATE_v1.2.3.html)
- [検証結果と未確認事項](TEST_RESULTS_v1.2.3.md)
- [変更ファイル](CHANGED_FILES_v1.2.3.md)
- [基本操作](MANUAL_BEGINNER_ja.html)

実測の利用者PXP、全DPI・全モニター、実キーボード/マウスのfocus切替、長時間運転は未確認です。旧版番号の文書・ログ・manifestは過去版の記録です。現在の内容はMANIFEST_v1.2.3.jsonを参照します。
''',encoding='utf-8')
(src/'CHANGED_FILES_v1.2.3.md').write_text('# v1.2.3 変更ファイル\n\n'+f'本体45 IPFのうち{len(changed)}ファイル（追加1）。補助パネル{panels}作成箇所へ同じ寸法維持方針を適用。\n\n'+'\n'.join('- `'+n+'`' for n in sorted(changed))+'''

xrd_ui123は再構築前後の寸法引継ぎとfloating targetの解除を担当。各作成関数では/K=1を保持し、作成直後にfixedSize=0を指定してから従来の部品・サイズ制限を設定する。管理画面のwindow path更新はfloating panelも対象に含め、試料名変更後の参照を保持。

解析アルゴリズム、Raw/Processed、同定、保存schemaは変更なし。起動include、初期化、既存の永続データ書込は従来の経路を保持。
''',encoding='utf-8')
(src/'TEST_RESULTS_v1.2.3.md').write_text('''# v1.2.3 検証 / 2026-10-29 JST

Igor Pro 9.05 Windows 64-bit、今回起動した専用プロセスと人工データで検証。旧版の同梱ログを今回の合格数へ加えていません。

| 内容 | 今回の合格数 |
|---|---:|
| 通常/最大化×補助10画面、3回更新、寸法/位置/閉鎖、操作callbackと管理path | 247 |
| 4画面切替、文字/サイズ/表の配置matrix、カーソルとY固定 | 343 |
| 既存総合回帰（同定、コピー、故障復元、凡例、改名など） | 102 |
| 閉鎖・再表示、図の手編集保持 | 18 |
| Undo・自動保存・失敗復元 | 41 |
| 補助画面も保存したPXPの別プロセス再読込 | 12 |
| 合計 | 763 |

最終ログはtests/results_v123。失敗0。Raw/Processed/ピーク不変、補助画面作成・更新・閉鎖時の主画面の寸法と最大化保持を確認。登録パネルと元素表等のIgor出力画像も確認。

模擬v1.2.2 PXPの185,889項目を比較。旧画面を閉じるhookがuiActiveChildを1件更新する以外、全データ一致。これは旧版を再初期化した対照群でも同じ。新版の初期化前後は一致し、別名保存後に専用Igorを終了・再起動・再読込した185,889項目も完全一致。元測定、処理値、割当/Unknown、参照UID/revision/hkl、Registry、格子履歴、Undo、依存式等を含む。

途中の失敗: 試験helperの構文/引数誤り、missing_hkl120.txt未配置による入力待ちを訂正。floating panelの初期fixedSize=1のままlibraryのsizeLimitへ到達する問題を回帰試験で検出し、作成直後fixedSize=0へ訂正。初期版の合格や失敗を最終結果へ混ぜていません。

未確認: 利用者の実PXP、全DPI/モニター、実マウス・キーボードのfocus/×操作、長時間、大容量、独自/採用済みProcedure、旧パスを遮断した別PC。Computer Useでhiddenな専用Igorはtarget可能なwindowを返さず、実入力は行っていません。ネイティブcallback試験を実入力試験とは扱いません。

補助画面は前面に表示され、不要時は×で閉じます。図/表/ガイドの新規表示や、利用者が明示した図サイズ変更まで固定する更新ではありません。補助画面の×後の寸法保存は追加していません。main未統合。
''',encoding='utf-8')
(src/'UPDATE_v1.2.3.html').write_text('''<!doctype html><html lang="ja"><meta charset="utf-8"><title>XRD Workbench v1.2.3 更新</title><style>body{max-width:850px;margin:40px auto;font:17px/1.8 "Segoe UI",sans-serif;color:#233243}li{margin:12px 0}code{background:#edf2f6;padding:3px}</style><h1>XRD Workbench v1.2.3</h1><p>補助画面を開く操作で主画面の最大化が解除される問題、画面更新で初期サイズへ戻る問題を修正しました。補助パネルは主画面の前に独立して表示されます。</p><ol><li>現在のExperimentを別名の.pxpとして保存し、旧版IPF一式も保持します。</li><li>新版を別フォルダへ展開します。本体45個のIPFは一式のまま保持してください。</li><li>旧XRDの画面を閉じ、旧版xrd_main.ipfをExperimentから外します。新版の<strong>xrd_main.ipfだけ</strong>を開きます。旧新版を同時に読み込まないでください。</li><li>F6で開き、タイトルのv1.2.3と測定・同定結果を確認します。主画面を最大化し、参照値・設定を開いても主画面の大きさが維持されることを確認して別名保存します。</li></ol><p>測定・参照の再取込は不要です。不要な補助画面は×で閉じられます。補助画面を閉じた後の新規表示は初期サイズです。</p><p><a href="TEST_RESULTS_v1.2.3.md">今回の検証結果と未確認</a> ／ <a href="MANUAL_UPDATE_ja.html#update">従来の詳しい更新手順（新版フォルダはv1.2.3へ読み替え）</a></p></html>''',encoding='utf-8')
print(json.dumps({'native_passes':sum(logs.values()),'auxiliary_panel_sites':panels,'changed_production_files':len(changed),'semantic':summary},ensure_ascii=False,indent=2))
