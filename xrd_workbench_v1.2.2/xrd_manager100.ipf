#pragma rtGlobals=3
// v1.2.0: project-operation previews, recovery and explicit sample metadata.
Function XRD100_ManagerControls()
    if(!WinType("XRDProjectManager"))
        return 0
    endif
    MoveWindow/W=XRDProjectManager 35,35,1015,715
    Button deleteProject,win=XRDProjectManager,pos={15,550},size={330,30},title="選択プロジェクトを削除",proc=XRD100_ManagerButton
    Button restoreProject,win=XRDProjectManager,pos={15,590},size={330,30},title="削除したプロジェクトを復元",proc=XRD100_ManagerButton
    Button sampleMeta,win=XRDProjectManager,pos={365,550},size={285,30},title="選択試料の通し番号・組成",proc=XRD100_ManagerButton
    Button migrateProject,win=XRDProjectManager,pos={665,550},size={285,30},title="Managementへ移行",proc=XRD100_ManagerButton
    TitleBox policy,win=XRDProjectManager,pos={15,640},title="番号は手動入力、組成は別欄です。改名・削除の前にExperimentのバックアップを作成します。"
End

Function/S XRD100_ManagerProject()
    String ui="root:Packages:XRDWorkbench:UI:Manager"
    Wave/T/Z paths=$(ui+":projectPaths")
    Variable row=NumVarOrDefault(ui+":projectRow",-1)
    if(WaveExists(paths) && row>=0 && row<numpnts(paths))
        return paths[row]
    endif
    return ""
End

Function XRD100_RenameUI()
    String project=XRD_Project(),label=XRD_ProjectDisplayName(XRD_Project()),preview="",target
    Prompt label,"新しいプロジェクト名"
    DoPrompt "実フォルダ・Wave名も変更",label
    if(V_flag)
        return -1
    endif
    if(XRD100_ValidProjectName(project,label)<0 || XRD100_PlanNames(project,label)<0)
        DoAlert 0,"名前の重複・使用できない文字・生成Wave名の長さを確認してください。変更していません。"
        return -1
    endif
    target=XRD100_Management()+":"+PossiblyQuoteName(label)
    Wave/T plan=$(XRD100_Admin()+":namePlan")
    Variable i
    for(i=0;i<min(8,DimSize(plan,0));i+=1)
        preview+=plan[i][1]+"\r"
    endfor
    DoAlert 1,"「"+XRD_ProjectDisplayName(project)+"」→「"+label+"」\r"+XRD100_Impact(project)+"\r\r変更先："+target+"\r変更・生成Wave "+num2istr(DimSize(plan,0))+"件\r"+preview+"\r番号・組成・固定ID・同定・格子定数を維持し、実行前バックアップを作成します。実行しますか？"
    if(V_flag!=1)
        return -1
    endif
    Variable result=XRD100_RenameProject(project,label)
    if(result<0)
        DoAlert 0,"改名できませんでした。管理操作の記録とバックアップを確認してください。\r"+StrVarOrDefault(XRD100_Admin()+":lastBackup","")
    else
        XRD_Panel()
    endif
    return result
End

Function XRD100_DeleteUI(project)
    String project
    DoAlert 1,"「"+XRD_ProjectDisplayName(project)+"」を削除しますか？\r"+XRD100_Impact(project)+"\r\r所属データは復元領域へ移し、通常の解析・新規作図から外します。\r共通参照と保存済み図は保持します。実行前バックアップも作成します。"
    if(V_flag!=1)
        return -1
    endif
    Variable result=XRD100_TrashProject(project)
    if(result<0)
        DoAlert 0,"削除できませんでした。元の状態または実行前バックアップを確認してください。"
    else
        Variable/G $(XRD100_Admin()+":allowEmpty")=1
        DoWindow/K XRDWorkbench
        XRD80_ProjectManager()
    endif
    return result
End

Function XRD100_RestoreUI()
    String base="root:Packages:XRDWorkbench:ProjectTrash",paths="",labels="",name,path,label
    XRD100_Admin()
    DFREF trash=$base
    Variable i=0,choice=1
    do
        name=GetIndexedObjNameDFR(trash,4,i)
        if(!strlen(name))
            break
        endif
        path=base+":"+PossiblyQuoteName(name)
        if(NumVarOrDefault(path+":projectDeleted100",0))
            paths+=path+";"
            labels+=XRD_ProjectDisplayName(path)+" / "+StrVarOrDefault(path+":deletedAt100","")+";"
        endif
        i+=1
    while(1)
    if(!ItemsInList(paths))
        DoAlert 0,"削除したプロジェクトはありません。"
        return 0
    endif
    Prompt choice,"復元するプロジェクト",popup,labels
    DoPrompt "プロジェクトを復元",choice
    if(V_flag)
        return -1
    endif
    path=StringFromList(choice-1,paths);label=XRD_ProjectDisplayName(path)
    Prompt label,"復元先のプロジェクト名（同名は上書きしません）"
    DoPrompt "復元先を確認",label
    if(V_flag)
        return -1
    endif
    Variable result=XRD100_RestoreProject(path,label)
    if(result<0)
        DoAlert 0,"復元できません。既存プロジェクトとの名前の重複、Wave名、バックアップ先を確認してください。"
    endif
    XRD80_ProjectManager()
    return result
End

Function XRD100_ManagerButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    return XRD100_QueueManager(ba.ctrlName)
End

Function XRD100_QueueManager(action)
    String action
    String admin=XRD100_Admin(),project=XRD100_ManagerProject(),ui="root:Packages:XRDWorkbench:UI:Manager",sample=""
    if(NumVarOrDefault(admin+":managerPending",0))
        return 0
    endif
    Wave/T/Z samples=$(ui+":samplePaths")
    Variable row=NumVarOrDefault(ui+":sampleRow",-1)
    if(WaveExists(samples) && row>=0 && row<numpnts(samples))
        sample=samples[row]
    endif
    String/G $(admin+":managerAction")=action
    String/G $(admin+":managerProjectUID")=StrVarOrDefault(project+":projectUID","")
    String/G $(admin+":managerSampleUID")=StrVarOrDefault(sample+":measurementUID","")
    Variable/G $(admin+":managerPending")=1
    Execute/P/Q "XRD100_ManagerDeferred()"
    return 0
End

Function XRD100_ManagerDeferred()
    String admin=XRD100_Admin(),action=StrVarOrDefault(admin+":managerAction",""),project=XRD100_ProjectByUID(StrVarOrDefault(admin+":managerProjectUID","")),sample=XRD80_ResolveMeasurement(StrVarOrDefault(admin+":managerSampleUID",""))
    Variable/G $(admin+":managerPending")=0
    strswitch(action)
        case "deleteProject":
            if(strlen(project))
                XRD100_DeleteUI(project)
            endif
            break
        case "restoreProject":
            XRD100_RestoreUI()
            break
        case "sampleMeta":
            if(strlen(project) && strlen(sample))
                String/G root:Packages:XRDWorkbench:activeProject=project
                String/G $(project+":activeData")=sample
                return XRD100_SampleUI()
            endif
            break
        case "migrateProject":
        case "renameProject":
            if(strlen(project))
                String/G root:Packages:XRDWorkbench:activeProject=project
                XRD100_RenameUI()
            endif
            break
    endswitch
    XRD80_ProjectManager()
    return 0
End

Function XRD100_RecoveryGuard()
    String tx=StrVarOrDefault(XRD100_Admin()+":activeTransaction","")
    if(XRD100_Busy() || cmpstr(StrVarOrDefault(tx+":state",""),"処理中")==0)
        Variable/G $(XRD100_Admin()+":busy")=1
        DoAlert 0,"完了していない管理操作があります。実行前のバックアップを別のExperimentとして開いて確認してください。\r"+StrVarOrDefault(tx+":backup","")
        return -1
    endif
    return 0
End

Function XRD100_ViewOptions()
    XRD100_ViewSettings()
    DoWindow/K XRDOptions100
    NewPanel/N=XRDOptions100/K=1/W=(80,80,660,240) as "XRD Workbench オプション"
    CheckBox auto,pos={20,25},title="同定ピークの選択時に自動拡大",variable=root:Packages:XRDWorkbench:UI:autoZoom100
    TitleBox note,pos={20,80},frame=0,title="範囲操作はIgor標準の拡大操作を使用し、全体表示ボタンで戻します。"
End
