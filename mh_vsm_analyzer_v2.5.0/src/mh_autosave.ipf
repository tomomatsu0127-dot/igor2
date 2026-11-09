#pragma rtGlobals=3

Function HMA_Init()
    NewDataFolder/O root:MHApp:Manager:Autosave
    String base="root:MHApp:Manager:Autosave:"
    HMH_DefaultNumber(base+"enabled",1)
    HMH_DefaultNumber(base+"interval",300)
    HMH_DefaultNumber(base+"saving",0)
    HMH_DefaultNumber(base+"nextDue",DateTime+300)
    HMH_DefaultNumber(base+"lastSavedAt",0)
    HMH_DefaultNumber(base+"saveCount",0)
    SVAR/Z directory=$(base+"directory"),session=$(base+"session")
    if(!SVAR_Exists(directory))
        String/G $(base+"directory")=SpecialDirPath("Documents",0,0,0)+"MH_Autosave:"
        String/G $(base+"lastPath")=""
        String/G $(base+"status")="5分ごとに復旧用コピーを保存します"
    endif
    if(!SVAR_Exists(session))
        String/G $(base+"session")=HMG_NewUID("recovery")
    endif
    return 0
End

Function HMA_Arm()
    HMA_Init()
    NVAR enabled=root:MHApp:Manager:Autosave:enabled,saving=root:MHApp:Manager:Autosave:saving,nextDue=root:MHApp:Manager:Autosave:nextDue
    saving=0;nextDue=DateTime+300
    CtrlNamedBackground HMARecovery,period=18000,proc=HMA_Background,dialogsOK=0,burst=0
    if(enabled)
        CtrlNamedBackground HMARecovery,start
    else
        CtrlNamedBackground HMARecovery,stop
    endif
    return 0
End

Function HMA_EnsureArmed()
    NVAR enabled=root:MHApp:Manager:Autosave:enabled
    if(!enabled)
        return 0
    endif
    CtrlNamedBackground HMARecovery,status
    if(NumberByKey("RUN",S_info)!=1)
        HMA_Arm()
    endif
    return 0
End

// Only already-initialized autosave state is resumed on compile/reopen.
// Loading the new Procedure into a legacy Experiment does not migrate its data.
static Function AfterCompiledHook()
    NVAR/Z enabled=root:MHApp:Manager:Autosave:enabled
    if(NVAR_Exists(enabled))
        HMA_Arm()
    endif
    return 0
End

Function HMA_Background(s)
    STRUCT WMBackgroundStruct &s
    NVAR/Z schema=root:MHApp:Manager:schemaVersion,enabled=root:MHApp:Manager:Autosave:enabled
    if(!NVAR_Exists(schema) || !NVAR_Exists(enabled))
        return 1
    endif
    HMA_Tick(DateTime)
    return 0
End

Function HMA_Tick(now)
    Variable now
    NVAR enabled=root:MHApp:Manager:Autosave:enabled,nextDue=root:MHApp:Manager:Autosave:nextDue
    NVAR saving=root:MHApp:Manager:Autosave:saving,busy=root:MHApp:Manager:busy
    if(!enabled || saving || busy || now<nextDue)
        return 0
    endif
    nextDue=now+300
    return HMA_SaveRecovery()
End

Function HMA_SaveRecovery()
    NVAR saving=root:MHApp:Manager:Autosave:saving,busy=root:MHApp:Manager:busy
    if(saving || busy)
        return -1
    endif
    SVAR directory=root:MHApp:Manager:Autosave:directory,session=root:MHApp:Manager:Autosave:session
    SVAR lastPath=root:MHApp:Manager:Autosave:lastPath,status=root:MHApp:Manager:Autosave:status
    NVAR lastSaved=root:MHApp:Manager:Autosave:lastSavedAt,count=root:MHApp:Manager:Autosave:saveCount
    Variable oldTime=lastSaved,oldCount=count,error=0,slot
    String oldPath=lastPath,oldSession=session,target
    // A recovery file may itself be open as the working Experiment.
    // Give that run a new recovery series so neither generation can overwrite it.
    if(StringMatch(LowerStr(HMM_FileName(IgorInfo(1))),LowerStr(session)+"_*"))
        session=HMG_NewUID("recovery")
        count=0
    endif
    slot=mod(count,2)+1
    target=directory+session+"_"+num2istr(slot)+".pxp"
    saving=1
    try
        NewPath/C/O/Q/Z HMARecoveryPath,directory
        if(V_flag!=0)
            Abort "自動保存先を作成できませんでした。"
        endif
        lastSaved=DateTime;count+=1;lastPath=target
        status="最終保存 "+Secs2Time(lastSaved,3)+"（復旧用コピー）"
        // /C preserves the user's original Experiment file and its save identity.
        SaveExperiment/C/F={1,"",0} as target
    catch
        error=GetRTError(1)
        if(error==0)
            error=-1
        endif
        lastSaved=oldTime;count=oldCount;lastPath=oldPath;session=oldSession
        status="自動保存に失敗しました。保存先を確認してください。"
        Print "MH: "+status
    endtry
    saving=0
    HMA_UpdateStatus()
    if(error)
        return -1
    endif
    return 1
End

Function HMA_UpdateStatus()
    if(WinType("HMG_Manager")==0)
        return 0
    endif
    SVAR status=root:MHApp:Manager:Autosave:status,directory=root:MHApp:Manager:Autosave:directory
    NVAR enabled=root:MHApp:Manager:Autosave:enabled
    String label=SelectString(enabled!=0,"自動保存：停止中",status)
    TitleBox autoStatus,win=HMG_Manager,title=label,help={directory}
    return 0
End

Function HMA_Toggle(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    if(cba.eventCode==2)
        Variable/G root:MHApp:Manager:Autosave:enabled=cba.checked
        HMA_Arm()
        HMA_UpdateStatus()
    endif
    return 0
End

Function HMA_ChooseDirectory()
    NewPath/O/M="復旧用コピーの保存先を選んでください" HMAChosenPath
    if(V_flag)
        return 0
    endif
    PathInfo HMAChosenPath
    String/G root:MHApp:Manager:Autosave:directory=S_path
    String/G root:MHApp:Manager:Autosave:status="保存先を設定しました。5分ごとに保存します。"
    HMA_UpdateStatus()
    return 0
End
