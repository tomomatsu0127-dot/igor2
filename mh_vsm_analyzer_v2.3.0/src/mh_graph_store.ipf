#pragma rtGlobals=3

Function/S HMG_GraphPath(uid)
    String uid
    return "root:MHApp:Manager:Graphs:"+uid+":"
End

Function/S HMG_SnapshotPath(uid)
    String uid
    String base=HMG_GraphPath(uid)
    SVAR/Z active=$(base+"activeSnapshot")
    if(SVAR_Exists(active))
        return base+active+":"
    endif
    return base
End

Function/S HMG_GraphWindow(uid)
    String uid
    Wave/T/Z graphs=root:MHApp:Manager:graphs
    Variable row=HMG_Find("graph",uid)
    String owner=""
    if(row>=0 && WaveExists(graphs))
        owner=graphs[row][3]
        if(WinType(owner)==1 && cmpstr(GetUserData(owner,"","HMHGraphUID"),uid)==0)
            return owner
        endif
    endif
    String wins=WinList("*",";","WIN:1"),win
    Variable i
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(cmpstr(GetUserData(win,"","HMHGraphUID"),uid)==0)
            return win
        endif
    endfor
    return ""
End

Function/S HMG_DatasetFromWave(w)
    Wave w
    Wave/T paths=root:MHApp:paths,ids=root:MHApp:Manager:datasetUID
    String folder=GetWavesDataFolder(w,1)
    Variable i
    for(i=0;i<numpnts(ids);i+=1)
        if(cmpstr(folder,paths[i])==0)
            return ids[i]
        endif
    endfor
    return ""
End

Function/S HMG_AdoptGraph(win,[parent])
    String win,parent
    if(HMG_Init()!=0 || WinType(win)!=1)
        return ""
    endif
    if(ParamIsDefault(parent))
        parent=HMG_TargetFolder()
    endif
    if(HMG_Find("folder",parent)<0)
        return ""
    endif
    Wave/T graphs=root:MHApp:Manager:graphs
    String uid=GetUserData(win,"","HMHGraphUID"),base,owner
    Variable row=HMG_Find("graph",uid),n=DimSize(graphs,0)
    if(row>=0)
        owner=graphs[row][3]
        if(WinType(owner)==1 && cmpstr(owner,win)!=0 && cmpstr(GetUserData(owner,"","HMHGraphUID"),uid)==0)
            // Preserve the original owner's identity when a native graph is duplicated.
            row=-1
        endif
    endif
    if(row<0)
        uid=HMG_NewUID("g")
        base=HMG_GraphPath(uid)
        NewDataFolder/O $(RemoveEnding(base,":"))
        String/G $(base+"recreation")=""
        Make/O/T/N=(0,4) $(base+"bindings")
        Make/O/T/N=(0,4) $(base+"traces")
        Redimension/N=(n+1,4) graphs
        graphs[n][0]=uid;graphs[n][1]=parent;graphs[n][2]=win;graphs[n][3]=win
        row=n
    endif
    SetWindow $win userdata(HMHGraphUID)=uid
    SetWindow $win hook(HMGStore)=HMG_WindowHook
    graphs[row][3]=win
    if(HMG_Capture(win)!=0)
        Print "MH: 図の状態を保存できませんでした: ",win
    endif
    return uid
End

Function HMG_Capture(win)
    String win
    if(WinType(win)!=1)
        return -1
    endif
    String uid=GetUserData(win,"","HMHGraphUID"),base=HMG_GraphPath(uid)
    Variable row=HMG_Find("graph",uid)
    if(row<0)
        return -1
    endif
    NVAR busy=root:MHApp:Manager:busy
    if(busy)
        return 0
    endif
    busy=1
    String savedDF=GetDataFolder(1),rec,traceNames,trace,full,ds,path,nextName="state0",stage
    Variable i,n,error=0
    try
        SetDataFolder root:MHApp:Manager:Scratch
        // Native tokens have meaning only inside this capture and binding table.
        rec=WinRecreation(win,2)
        String previousBase=HMG_SnapshotPath(uid)
        SVAR/Z previous=$(previousBase+"recreation")
        if(SVAR_Exists(previous))
            if(cmpstr(previous,rec)==0)
                SetDataFolder $savedDF
                busy=0
                return 0
            endif
        endif
        GetWindow $win wavelist
        Wave/T waveList=W_WaveList
        n=DimSize(waveList,0)
        Make/FREE/T/N=(n,4) bindings
        for(i=0;i<n;i+=1)
            Wave/Z w=$waveList[i][1]
            if(!WaveExists(w))
                Abort "グラフのWaveを取得できません。"
            endif
            bindings[i][0]=waveList[i][2]
            ds=HMG_DatasetFromWave(w)
            bindings[i][1]=ds
            bindings[i][2]=NameOfWave(w)
            bindings[i][3]=GetWavesDataFolder(w,2)
        endfor
        traceNames=TraceNameList(win,";",1)
        Make/FREE/T/N=(ItemsInList(traceNames),4) traceBindings
        for(i=0;i<ItemsInList(traceNames);i+=1)
            trace=StringFromList(i,traceNames)
            Wave/Z yw=TraceNameToWaveRef(win,trace),xw=XWaveRefFromTrace(win,trace)
            traceBindings[i][0]=trace
            if(WaveExists(yw))
                traceBindings[i][1]=HMG_DatasetFromWave(yw)
                traceBindings[i][2]=GetWavesDataFolder(yw,2)
            endif
            if(WaveExists(xw))
                traceBindings[i][3]=GetWavesDataFolder(xw,2)
            endif
        endfor
        if(strlen(rec)==0)
            Abort "再構築情報が空です。"
        endif
        // Write the inactive generation first, then switch a single pointer.
        // Allocation or capture errors cannot mix new bindings with old commands.
        SVAR/Z active=$(base+"activeSnapshot")
        if(SVAR_Exists(active))
            nextName=SelectString(cmpstr(active,"state0")==0,"state0","state1")
        endif
        stage=base+nextName+":"
        NewDataFolder/O $(RemoveEnding(stage,":"))
        Duplicate/O bindings,$(stage+"bindings")
        Duplicate/O traceBindings,$(stage+"traces")
        String/G $(stage+"recreation")=rec
        Variable/G $(stage+"savedAt")=DateTime
        String/G $(base+"activeSnapshot")=nextName
        Wave/T graphs=root:MHApp:Manager:graphs
        graphs[row][3]=win
    catch
        error=GetRTError(1)
        if(error==0)
            error=-1
        endif
    endtry
    SetDataFolder $savedDF
    busy=0
    return error
End

Function HMG_OpenGraph(uid)
    String uid
    if(HMG_Init()!=0 || HMG_Find("graph",uid)<0)
        return -1
    endif
    String win=HMG_GraphWindow(uid),base=HMG_SnapshotPath(uid)
    if(strlen(win))
        DoWindow/F $win
        String/G root:MHApp:lastGraph=win
        return 0
    endif
    SVAR/Z saved=$(base+"recreation")
    Wave/T/Z bindings=$(base+"bindings")
    if(!SVAR_Exists(saved) || strlen(saved)==0 || !WaveExists(bindings))
        return -2
    endif
    String rec=saved,full,savedDF=GetDataFolder(1),oldWins=WinList("*",";","WIN:1"),after,created
    Variable i,index,error=0
    Wave/T paths=root:MHApp:paths,graphs=root:MHApp:Manager:graphs
    for(i=0;i<DimSize(bindings,0);i+=1)
        full=bindings[i][3]
        if(strlen(bindings[i][1]))
            index=HMG_Find("data",bindings[i][1])
            if(index<0)
                Print "MH: 図で使う測定IDが見つかりません: ",bindings[i][1]
                return -3
            endif
            full=paths[index]+PossiblyQuoteName(bindings[i][2])
        endif
        Wave/Z w=$full
        if(!WaveExists(w))
            Print "MH: 図で使うWaveが見つかりません: ",full
            return -3
        endif
        rec=ReplaceString(bindings[i][0],rec,GetWavesDataFolder(w,2))
    endfor
    // The native recreation macro runs as a whole, including user annotations.
    // Do not call DrawGraph, Layout, NewGraphAxes or FitFigure on this path.
    NVAR busy=root:MHApp:Manager:busy
    busy=1
    SetDataFolder root:MHApp:Manager:Scratch
    V_flag=0
    Execute/Z rec
    error=V_flag
    after=WinList("*",";","WIN:1");created=""
    for(i=0;i<ItemsInList(after);i+=1)
        win=StringFromList(i,after)
        if(WhichListItem(win,oldWins)<0)
            if(error)
                DoWindow/K $win
            else
                created=win
            endif
        endif
    endfor
    SetDataFolder $savedDF
    busy=0
    if(error || strlen(created)==0)
        Print "MH: 保存図の復元に失敗しました。元の保存状態を保持します。"
        return -4
    endif
    SetWindow $created userdata(HMHGraphUID)=uid
    SetWindow $created hook(HMGStore)=HMG_WindowHook
    index=HMG_Find("graph",uid)
    graphs[index][3]=created
    String/G root:MHApp:lastGraph=created
    DoWindow/F $created
    return 0
End

Function HMG_SaveAll()
    NVAR/Z schema=root:MHApp:Manager:schemaVersion
    if(!NVAR_Exists(schema))
        return 0
    endif
    if(schema!=1)
        return -1
    endif
    String wins=HMH_FigureList(),win,uid
    Variable i,failures=0
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        uid=GetUserData(win,"","HMHGraphUID")
        if(HMG_Find("graph",uid)<0)
            uid=HMG_AdoptGraph(win)
        endif
        if(strlen(uid)==0 || HMG_Capture(win)!=0)
            failures+=1
            Print "MH: 図の保存失敗: ",win
        endif
    endfor
    return failures
End

Function HMG_BeforeSave(refNum,fileName,pathName,fileType,creator,fileKind)
    Variable refNum,fileKind
    String fileName,pathName,fileType,creator
    if(NumVarOrDefault("root:MHApp:Manager:Autosave:saving",0))
        return 0
    endif
    Variable failed=HMG_SaveAll()
    if(failed)
        Print "MH: 保存状態を更新できなかった図があります。開いている図を保持して確認してください。"
    endif
    return 0
End

Function HMG_WindowHook(s)
    STRUCT WMWinHookStruct &s
    NVAR/Z schema=root:MHApp:Manager:schemaVersion,busy=root:MHApp:Manager:busy
    if(!NVAR_Exists(schema) || !NVAR_Exists(busy))
        return 0
    endif
    if(busy)
        return 0
    endif
    String uid=GetUserData(s.winName,"","HMHGraphUID")
    Variable row=HMG_Find("graph",uid)
    if(row<0)
        return 0
    endif
    Wave/T graphs=root:MHApp:Manager:graphs
    strswitch(s.eventName)
        case "killVote":
            if(HMG_Capture(s.winName)!=0)
                Print "MH: 保存できないため図を閉じませんでした: ",s.winName
                return 2
            endif
            break
        case "kill":
            graphs[row][3]=""
            break
        case "renamed":
            graphs[row][3]=s.winName
            break
    endswitch
    return 0
End

Function HMG_CloseGraph(uid)
    String uid
    String win=HMG_GraphWindow(uid)
    if(strlen(win)==0)
        return 0
    endif
    if(HMG_Capture(win)!=0)
        return -1
    endif
    DoWindow/K $win
    return 0
End

Function/S HMG_GraphSources(uid)
    String uid
    String base=HMG_SnapshotPath(uid),text="",ds,name,seen=""
    Wave/T/Z traces=$(base+"traces")
    if(!WaveExists(traces))
        return "関連情報なし"
    endif
    Variable i
    for(i=0;i<DimSize(traces,0);i+=1)
        ds=traces[i][1]
        if(strlen(ds) && WhichListItem(ds,seen)<0)
            seen+=ds+";"
            name=HMG_Name("data",ds)
            if(strlen(HMM_SampleNumber(ds)))
                name=HMM_SampleNumber(ds)+" | "+name
            endif
            text+="・"+name+"\r"
        elseif(strlen(ds)==0)
            text+="・管理外のWave: "+traces[i][2]+"\r"
        endif
    endfor
    return text
End
