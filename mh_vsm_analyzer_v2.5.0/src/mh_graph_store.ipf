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
    String wins=HMP_PlotList(),win
    Variable i
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(cmpstr(GetUserData(win,"","HMHGraphUID"),uid)==0)
            return win
        endif
    endfor
    return ""
End

Function HMG_OpenGraph(uid)
    String uid
    if(HMG_Init()!=0 || HMG_Find("graph",uid)<0)
        return -1
    endif
    String live=HMG_GraphWindow(uid),base=HMG_SnapshotPath(uid)
    Variable overlay=HMP_NeedsOverlay()
    if(strlen(live) && (!overlay || strsearch(live,"#",0)>=0))
        String/G root:MHApp:lastGraph=live
        return HMP_Front(live)
    endif
    String rec,full,savedDF=GetDataFolder(1),oldWins=WinList("*",";","WIN:1"),created
    Variable i,index,error=0
    Wave/T paths=root:MHApp:paths,graphs=root:MHApp:Manager:graphs
    if(strlen(live))
        // Keep the current edits when an already-open plot moves into the overlay.
        SetDataFolder root:MHApp:Manager:Scratch
        rec=WinRecreation(live,0)
        SetDataFolder $savedDF
    else
        SVAR/Z saved=$(base+"recreation")
        Wave/T/Z bindings=$(base+"bindings")
        if(!SVAR_Exists(saved) || strlen(saved)==0 || !WaveExists(bindings))
            return -2
        endif
        rec=saved
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
    endif
    rec=ReplaceString("\tSetWindow kwTopWin,hook(HMGStore)=HMG_WindowHook\r",rec,"")
    String host="",title=HMG_Name("graph",uid)
    if(overlay)
        host=HMP_NewHost(title)
        rec="Macro HMPRestore()"+rec[strsearch(rec,"\r",0),inf]
        rec=ReplaceString("\tDisplay ",rec,"\tDisplay /HOST="+host+"/N=Plot/FG=(FL,FT,FR,FB) ")
        rec=ReplaceString("kwTopWin",rec,host+"#Plot")
    else
        rec=ReplaceString("\tDisplay ",rec,"\tDisplay /K="+num2istr(HMP_CloseMode())+" ")
    endif
    SetDataFolder root:MHApp:Manager:Scratch
    Execute/Z rec
    error=V_flag
    SetDataFolder $savedDF
    if(strlen(host))
        SetActiveSubwindow _endfloat_
        created=host+"#Plot"
    else
        created=StringFromList(0,WinList("*",";","WIN:1"))
        if(WhichListItem(created,oldWins)>=0)
            created=""
        endif
    endif
    if(error || WinType(created)!=1)
        if(strlen(host))
            DoWindow/K $host
        elseif(strlen(created))
            DoWindow/K $created
        endif
        Print "MH: 保存図を開けませんでした。"
        return -4
    endif
    if(strlen(host))
        Variable width=str2num(GetUserData(created,"","HMHCanvasWidth"))
        Variable height=str2num(GetUserData(created,"","HMHCanvasHeight"))
        if(numtype(width+height)==0 && width>0 && height>0)
            HMP_ResizeOverlay(created,width,height)
        endif
    endif
    if(strlen(live))
        HMP_Close(live)
    endif
    SetWindow $created userdata(HMHGraphUID)=uid
    index=HMG_Find("graph",uid)
    graphs[index][3]=created
    if(NumVarOrDefault("root:MHApp:Figure:sharedApplied",0))
        if(HMH_ApplyDefaults(created)!=0)
            HMP_Close(created)
            Print "MH: 共通設定の寸法に保存図の凡例が収まりません。"
            return -5
        endif
    endif
    String/G root:MHApp:lastGraph=created
    return HMP_Front(created)
End

// v2.3 saved hooks resolve on reopen. Existing snapshots are read-only.
Function HMG_BeforeSave(refNum,fileName,pathName,fileType,creator,fileKind)
    Variable refNum,fileKind
    String fileName,pathName,fileType,creator
    return 0
End

Function HMG_WindowHook(s)
    STRUCT WMWinHookStruct &s
    return 0
End

Function HMG_CloseGraph(uid)
    String uid
    return HMP_Close(HMG_GraphWindow(uid))
End

Function HMG_DeleteGraph(uid)
    String uid
    Variable row=HMG_Find("graph",uid)
    if(row<0)
        return -1
    endif
    if(HMG_CloseGraph(uid)!=0)
        return -2
    endif
    String base=HMG_GraphPath(uid)
    if(DataFolderExists(base))
        KillDataFolder/Z $base
        if(DataFolderExists(base))
            return -2
        endif
    endif
    Wave/T graphs=root:MHApp:Manager:graphs
    DeletePoints/M=0 row,1,graphs
    return 0
End

Function HMG_GraphUsesData(graph,uid,runPath)
    String graph,uid,runPath
    String base=HMG_SnapshotPath(graph)
    Wave/T/Z bindings=$(base+"bindings")
    Variable i
    if(WaveExists(bindings))
        for(i=0;i<DimSize(bindings,0);i+=1)
            if(cmpstr(bindings[i][1],uid)==0 || strsearch(bindings[i][3],runPath,0)==0)
                return 1
            endif
        endfor
    endif
    return 0
End

Function HMG_ClosePlotsUsing(runPath)
    String runPath
    String wins=HMH_FigureList(),win,traces,trace
    Variable i,j
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        traces=TraceNameList(win,";",1)
        for(j=0;j<ItemsInList(traces);j+=1)
            trace=StringFromList(j,traces)
            Wave/Z yw=TraceNameToWaveRef(win,trace),xw=XWaveRefFromTrace(win,trace)
            if(HMG_WaveUsesRun(yw,runPath) || HMG_WaveUsesRun(xw,runPath))
                HMP_Close(win)
                break
            endif
        endfor
    endfor
    return 0
End

Function HMG_WaveUsesRun(w,runPath)
    Wave/Z w
    String runPath
    if(!WaveExists(w))
        return 0
    endif
    return cmpstr(GetWavesDataFolder(w,1),runPath)==0
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
