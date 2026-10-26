#pragma rtGlobals=3
// XRD Workbench v1.1.0: rotating recovery copies and project-scoped undo.
Function XRD_RecoverySettings()
    NewDataFolder/O root:Packages:XRDWorkbench:Recovery
    String base="root:Packages:XRDWorkbench:Recovery:"
    XRD_EnsureNumeric(base+"enabled",1)
    XRD_V51RecoveryPolicy()
    XRD_EnsureNumeric(base+"minutes",5)
    XRD_EnsureNumeric(base+"generation",0)
    XRD_EnsureNumeric(base+"busy",0)
    XRD_EnsureNumeric(base+"lastSave",0)
    SVAR/Z key=$(base+"sessionKey")
    if(!SVAR_Exists(key))
        String/G $(base+"sessionKey")=num2istr(DateTime)+"_"+num2istr(round(abs(enoise(1000000))))
        String/G $(base+"lastFile")=""
        String/G $(base+"message")="自動保存：ON（5分おきの復旧コピー）"
    endif
End

Function XRD_StartAutoSave()
    XRD_RecoverySettings()
    NVAR enabled=root:Packages:XRDWorkbench:Recovery:enabled,minutes=root:Packages:XRDWorkbench:Recovery:minutes
    SVAR message=root:Packages:XRDWorkbench:Recovery:message
    if(!enabled)
        Variable/G root:Packages:XRDWorkbench:Recovery:queued=0
        CtrlNamedBackground XRDAutoSave,stop
        message="自動保存：OFF（保存設定から再開できます）"
        XRD_UpdateRecoveryPanel()
        return 0
    endif
    if(numtype(minutes)!=0 || minutes<1 || minutes>60)
        minutes=5
    endif
    CtrlNamedBackground XRDAutoSave,status
    if(NumberByKey("RUN",S_info)==1 && NumberByKey("PERIOD",S_info)==round(minutes*3600))
        return 0
    endif
    CtrlNamedBackground XRDAutoSave,proc=XRD_AutoSaveTask,period=(round(minutes*3600)),dialogsOK=0,burst=0
    CtrlNamedBackground XRDAutoSave,start=(ticks+round(minutes*3600))
    message="自動保存："+num2str(minutes)+"分おき（復旧コピー3世代）"
    XRD_UpdateRecoveryPanel()
    return 0
End

Function XRD_AutoSaveTask(s)
    STRUCT WMBackgroundStruct &s
    // An old experiment may restore its timer before the panel is opened.
    XRD_RecoverySettings()
    NVAR/Z enabled=root:Packages:XRDWorkbench:Recovery:enabled
    if(!NVAR_Exists(enabled) || !enabled)
        return 1
    endif
    NVAR busy=root:Packages:XRDWorkbench:Recovery:busy,pending=root:Packages:XRDWorkbench:Recovery:queued
    if(!busy && !pending)
        pending=1
        Execute/P/Q "XRD_RunQueuedRecovery()"
    endif
    return 0
End

Function XRD_SaveRecovery()
    // A runtime stack guard survives callbacks without persisting a locked flag
    // in the recovery file itself.
    String saveStack=GetRTStackInfo(0)
    if(ItemsInList(saveStack)-ItemsInList(RemoveFromList("XRD_SaveRecovery",saveStack))>1)
        return -1
    endif
    if(XRD100_Busy())
        return -1
    endif
    XRD_RecoverySettings()
    NVAR busy=root:Packages:XRDWorkbench:Recovery:busy,generation=root:Packages:XRDWorkbench:Recovery:generation,lastSave=root:Packages:XRDWorkbench:Recovery:lastSave
    SVAR key=root:Packages:XRDWorkbench:Recovery:sessionKey,file=root:Packages:XRDWorkbench:Recovery:lastFile,message=root:Packages:XRDWorkbench:Recovery:message
    if(busy || strlen(StrVarOrDefault("root:Packages:XRDWorkbench:activeProject",""))==0)
        return -1
    endif
    busy=1
    Variable error=0,slot=mod(generation,3)+1,previousSave=lastSave,previousGeneration=generation
    String parent,destination,tempFile="",previousFile=file,name=CleanupName(IgorInfo(1),0)
    try
        PathInfo XRDAutoSaveCustomPath
        if(V_flag)
            parent=S_path
        else
            PathInfo home
            if(V_flag)
                parent=S_path
            else
                PathInfo IgorUserFiles
                parent=S_path
            endif
        endif
        destination=parent+"XRDWorkbench_Autosave:"
        NewPath/O/C/Q/Z XRDAutoSavePath,destination
        if(V_flag)
            busy=0
            message="自動保存失敗：保存フォルダを作成できません"
            Print message
            XRD_UpdateRecoveryPanel()
            return -1
        endif
        destination+=name+"_"+key+"_"+num2istr(slot)+".pxp"
        XRD_CapturePanelState(1)
        XRD_CaptureView()
        file=destination
        lastSave=DateTime
        message="自動保存済："+Secs2Time(lastSave,3)
        generation+=1
        // A copy leaves the currently open experiment's name and home path intact.
        // Explicit packed format also supports previously-unsaved experiments.
        busy=0
        tempFile=destination+".pending.pxp"
        XRD_SaveDiagnostic("SaveExperiment開始")
        SaveExperiment/C/F={1,"",0} as tempFile; AbortOnRTE
        XRD_SaveDiagnostic("SaveExperiment完了")
        GetFileFolderInfo/Q/Z tempFile
        if(V_flag || !V_isFile || V_logEOF<=0)
            Abort "復旧コピーを確認できません"
        endif
        MoveFile/O tempFile as destination; AbortOnRTE
        XRD_SaveDiagnostic("世代コピー置換完了")
    catch
        error=GetRTError(1)
        if(!error)
            error=1
        endif
        generation=previousGeneration
        lastSave=previousSave
        file=previousFile
        message="自動保存失敗（エラー "+num2istr(error)+"）：保存先を確認してください"
    endtry
    busy=0
    if(error)
        Print message
    endif
    XRD_UpdateRecoveryPanel()
    return -error
End

Function XRD_SaveSettingsPanel()
    XRD_RecoverySettings()
    DoWindow/K XRDSaveSettings
    NewPanel/N=XRDSaveSettings/W=(80,80,630,390) as "保存・自動保存"
    DefaultGUIFont/W=XRDSaveSettings all={"Segoe UI",12,0}
    CheckBox enabled,pos={15,15},title="自動保存を使う",variable=root:Packages:XRDWorkbench:Recovery:enabled,proc=XRD_AutoSaveToggle
    SetVariable minutes,pos={15,48},size={270,22},title="保存間隔（分）",limits={1,60,1},value=root:Packages:XRDWorkbench:Recovery:minutes,proc=XRD_AutoSaveMinutes
    TitleBox note,pos={15,82},frame=0,title="初期設定はON（5分おき）。主処理で復旧コピーを保存します。\r復旧用.pxpを3世代保存。実データでの解消は未確認です。\r通常保存：File → Save Experiment As...（未保存の作業は先に保存）。"
    Button saveNow,pos={15,150},size={160,28},title="今すぐ復旧コピーを保存",proc=XRD_SaveButton
    Button chooseFolder,pos={185,150},size={150,28},title="保存先フォルダを選ぶ",proc=XRD_SaveButton
    Button defaultFolder,pos={345,150},size={180,28},title="標準の保存先へ戻す",proc=XRD_SaveButton
    TitleBox saveState,pos={15,191},size={510,22},frame=0,title=""
    SetVariable lastFile,pos={15,220},size={510,22},title="最新コピー",noedit=1,value=root:Packages:XRDWorkbench:Recovery:lastFile
    Button recoveryList,pos={15,260},size={220,28},title="復旧コピーの一覧を開く",proc=XRD_V50Button
    XRD_UpdateRecoveryPanel()
    return 0
End

Function XRD_UpdateRecoveryPanel()
    XRD_UpdateHistoryUI()
    if(WinType("XRDSaveSettings"))
        SVAR message=root:Packages:XRDWorkbench:Recovery:message
        TitleBox saveState,win=XRDSaveSettings,title=message
    endif
End

Function XRD_AutoSaveToggle(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    if(cba.eventCode==2)
        Variable/G root:Packages:XRDWorkbench:Recovery:userChoice81=1
        XRD_StartAutoSave()
    endif
End

Function XRD_AutoSaveMinutes(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva
    if(sva.eventCode>=1 && sva.eventCode<=3)
        XRD_StartAutoSave()
    endif
End

Function XRD_SaveButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    strswitch(ba.ctrlName)
        case "saveNow":
            XRD_SaveRecovery()
            break
        case "chooseFolder":
            NewPath/O/Q/M="自動保存の保存先を選んでください" XRDAutoSaveCustomPath
            break
        case "defaultFolder":
            KillPath/Z XRDAutoSaveCustomPath
            break
    endswitch
    return 0
End

Function XRD_UndoSettings(project)
    String project
    NewDataFolder/O $(project+":Undo")
    XRD_EnsureNumeric(project+":Undo:sequence",0)
    XRD_EnsureNumeric(project+":Undo:count",0)
    XRD_EnsureNumeric(project+":Undo:pending",0)
End

Function XRD_RecordUndo(path,label)
    String path,label
    String project=XRD_Project(),name=ParseFilePath(0,path,":",1,0)
    if(!DataFolderExists(path) || cmpstr(path,XRD110_MeasurementPath(project,name))!=0)
        return -1
    endif
    XRD_RecordPendingZoom(path)
    XRD_UndoSettings(project)
    XRD_EnsureNumeric(project+":Undo:redoCount",0)
    NVAR sequence=$(project+":Undo:sequence"),count=$(project+":Undo:count"),redo=$(project+":Undo:redoCount")
    XRD_Snapshot(path,project+":Undo:Entry"+num2istr(mod(sequence,20)),label)
    sequence+=1;count=min(20,count+1);redo=0
    return 0
End

Function XRD_Undo()
    XRD_RecordPendingZoom(XRD_Data())
    String project=XRD_Project()
    XRD_UndoSettings(project)
    XRD_EnsureNumeric(project+":Undo:redoCount",0)
    NVAR sequence=$(project+":Undo:sequence"),count=$(project+":Undo:count"),pending=$(project+":Undo:pending"),redo=$(project+":Undo:redoCount")
    pending=0
    if(count<=0)
        return 0
    endif
    String entry=project+":Undo:Entry"+num2istr(mod(sequence-1,20))
    SVAR path=$(entry+":target"),label=$(entry+":label")
    if(!DataFolderExists(path))
        return -1
    endif
    XRD_Snapshot(path,project+":Undo:Redo"+num2istr(redo),label)
    String/G $(project+":Undo:Redo"+num2istr(redo)+":kind")=StrVarOrDefault(entry+":kind","analysis")
    redo+=1;sequence-=1;count-=1
    XRD_ApplySnapshot(entry)
    Print "元に戻しました："+label
    return 1
End

Function XRD_UndoHook(info)
    STRUCT WMWinHookStruct &info
    if(cmpstr(StringFromList(0,info.winName,"#"),"XRDWorkbench")!=0 || (info.eventCode!=26 && info.eventCode!=11))
        return 0
    endif
    // Ctrl+Y belongs to Igor's Window Control and can bypass window hooks.
    Variable isZ=(info.keycode==122 || info.keycode==90 || info.keycode==26)
    Variable redoKey=isZ && (info.eventMod & 2)
    if(!(info.eventMod & 8) || (info.eventMod & 4) || !isZ)
        return 0
    endif
    // Editing a value keeps native text undo. Tables and graph use analysis undo.
    if(strlen(info.focusCtrl))
        ControlInfo/W=$info.winName $info.focusCtrl
        if(V_flag==5)
            return 0
        endif
    endif
    String project=XRD_Project()
    XRD_UndoSettings(project)
    NVAR pending=$(project+":Undo:pending")
    if(!pending)
        pending=1
        if(redoKey)
            Execute/P/Q "XRD_Redo()"
        else
            Execute/P/Q "XRD_Undo()"
        endif
    endif
    return 1
End

Function XRD_UndoButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode==2)
        XRD_Undo()
    endif
End
