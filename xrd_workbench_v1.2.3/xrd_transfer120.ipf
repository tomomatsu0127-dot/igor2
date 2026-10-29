#pragma rtGlobals=3
// v1.2.0: copy a completed measurement; never move or mutate the source.
Function XRD120_CopyButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode==2)
        Execute/P/Q "XRD120_CopyPicker()"
    endif
    return 0
End

Function XRD120_CopyPicker()
    String ui=XRD110_Entry()+":Copy120",all=XRD_AllMeasurementPaths(1),owner=XRD100_ProjectByUID(StrVarOrDefault(XRD110_Entry()+":ownerUID","")),path
    NewDataFolder/O $ui
    Make/O/T/N=(0,3) $(ui+":table")
    Make/O/T/N=0 $(ui+":paths")
    Wave/T table=$(ui+":table"),paths=$(ui+":paths")
    Variable i,n=0
    for(i=0;i<ItemsInList(all);i+=1)
        path=StringFromList(i,all)
        if(cmpstr(XRD80_ProjectForMeasurement(path),owner)==0)
            continue
        endif
        Redimension/N=(n+1,3) table
        Redimension/N=(n+1) paths
        table[n][0]=XRD_ProjectDisplayName(XRD80_ProjectForMeasurement(path))
        table[n][1]=StrVarOrDefault(path+":sampleNumber","番号未登録")
        table[n][2]=StrVarOrDefault(path+":displayName","");paths[n]=path;n+=1
    endfor
    if(!n)
        DoAlert 0,"他プロジェクトに解析完了済みの測定データがありません。"
        return -1
    endif
    SetDimLabel 1,0,'元プロジェクト',table
    SetDimLabel 1,1,'通し番号',table
    SetDimLabel 1,2,'表示名',table
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDCopy120")
    DoWindow/K XRDCopy120
    NewPanel/FLT=1/N=XRDCopy120/K=1/W=(50,50,930,580) as "同定済み試料から追加：元は残して複製"
    DefaultGUIFont/W=XRDCopy120 all={"Segoe UI",12,0}
    TitleBox help,pos={15,18},frame=0,title="追加する試料をダブルクリックしてください。\r元の測定・同定結果を保持し、新しい試料として登録先へ複製します。"
    ListBox sources,pos={15,75},size={835,380},listWave=table,mode=1,selRow=-1,widths={300,120,390},proc=XRD120_CopyList
    Button close,pos={15,470},size={835,30},title="閉じる",proc=XRD120_CopyClose
    SetWindow XRDCopy120 hook(wheel120)=XRD110_WheelHook
    XRD123_FinishPanel("XRDCopy120",panelState123)
    return n
End

Function XRD120_CopyClose(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode==2)
        DoWindow/K XRDCopy120
    endif
    return 0
End

Function XRD120_CopyList(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode!=3 || lba.row<0)
        return 0
    endif
    String base=XRD110_Entry()
    Wave/T paths=$(base+":Copy120:paths")
    if(lba.row>=numpnts(paths))
        return 0
    endif
    String source=paths[lba.row]
    String/G $(base+":copyUID120")=XRD80_MeasurementUID(source)
    String/G $(base+":number")=StrVarOrDefault(source+":sampleNumber","")
    String/G $(base+":label")=StrVarOrDefault(source+":displayName","")
    String/G $(base+":lastSyncedLabel120")=StrVarOrDefault(source+":displayName","")
    String/G $(base+":composition")=StrVarOrDefault(source+":composition","")
    String/G $(base+":file")=""
    TitleBox fileName,win=XRDRegister110,title="複製元："+XRD_ProjectDisplayName(XRD80_ProjectForMeasurement(source))+" / "+XRD110_SampleLabel(source)
    XRD110_EntryPreview()
    DoWindow/K XRDCopy120
    DoWindow/F XRDRegister110
    return 0
End

Function XRD120_RebindCopy(base,oldPath,newPath)
    String base,oldPath,newPath
    DFREF folder=$base
    Variable i=0
    String name,path,formula
    do
        name=GetIndexedObjNameDFR(folder,1,i)
        if(!strlen(name))
            break
        endif
        path=base+":"+PossiblyQuoteName(name)
        Wave w=$path
        if(WaveType(w)==0)
            Wave/T text=$path
            text=SelectString(strsearch(text[p][q][r][s],oldPath,0)>=0,text[p][q][r][s],XRD100_RepathList(text[p][q][r][s],oldPath,newPath))
        endif
        formula=GetFormula(w)
        if(strlen(formula))
            SetFormula w,ReplaceString(oldPath+":",formula,newPath+":"); AbortOnRTE
        endif
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,3,i)
        if(!strlen(name))
            break
        endif
        SVAR value=$(base+":"+PossiblyQuoteName(name))
        if(strsearch(value,oldPath,0)>=0)
            if(cmpstr(name,"nativeMacro")==0)
                value=ReplaceString(oldPath+":",value,newPath+":")
            else
                value=XRD100_RepathList(value,oldPath,newPath)
            endif
        endif
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        XRD120_RebindCopy(base+":"+PossiblyQuoteName(name),oldPath,newPath)
        i+=1
    while(1)
    return 0
End

Function/S XRD120_CopyMeasurement(source,project,number,composition,label)
    String source,project,number,composition,label
    if(!DataFolderExists(source) || !DataFolderExists(project) || cmpstr(XRD80_ProjectForMeasurement(source),project)==0 || !XRD_IsAnalysisComplete(source))
        return ""
    endif
    if(!XRD110_SerialAvailable(project,"",number) || !XRD100_ValidPart(composition) || !strlen(TrimString(label)))
        return ""
    endif
    String path=XRD110_MeasurementPath(project,number),tx=XRD100_TxStart("同定済み測定を別プロジェクトへ複製",project),uid
    if(!strlen(tx))
        return ""
    endif
    Variable error=0
    try
        DuplicateDataFolder $source,$path; AbortOnRTE
        XRD100_Op(tx,"createdFolder","",path)
        uid=XRD80_NewUID("M")
        String/G $(path+":measurementUID")=uid
        String/G $(path+":projectUID")=XRD80_ProjectUID(project)
        String/G $(path+":waveStem")=uid
        String/G $(path+":sampleNumber")=number
        String/G $(path+":composition")=composition
        String/G $(path+":displayName")=label
        String/G $(path+":copiedFromMeasurementUID120")=XRD80_MeasurementUID(source)
        String/G $(path+":copiedFromProjectUID120")=XRD80_ProjectUID(XRD80_ProjectForMeasurement(source))
        String/G $(path+":copiedAt120")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
        Variable/G $(path+":deleted")=0
        Variable/G $(path+":stackOrder")=ItemsInList(XRD_MeasurementOrderList(project))
        XRD120_RebindCopy(path,source,path); AbortOnRTE
        XRD80_RegisterMeasurement(path,project); AbortOnRTE
        if(XRD100_PlanNames(project,XRD_ProjectDisplayName(project))<0)
            AbortOnValue 1,10001
        endif
        XRD100_ExecuteNamePlan(tx,project,project); AbortOnRTE
        XRD100_CommitNames(project,XRD_ProjectDisplayName(project),tx=tx); AbortOnRTE
        if(XRD100_VerifyFingerprint(project,tx)<0)
            AbortOnValue 1,10001
        endif
        XRD100_Commit(tx)
    catch
        error=max(1,GetRTError(1))
        String/G $(tx+":error")=GetErrMessage(error)
    endtry
    if(error)
        // Leave the exception scope first so temporary Wave handles are released.
        XRD100_Rollback(tx)
        return ""
    endif
    return path
End

Function XRD120_ClearCopyFormulas(base)
    String base
    DFREF folder=$base
    String name
    Variable i=0
    do
        name=GetIndexedObjNameDFR(folder,1,i)
        if(!strlen(name))
            break
        endif
        Wave w=$(base+":"+PossiblyQuoteName(name))
        if(strlen(GetFormula(w)))
            SetFormula w,"";AbortOnRTE
        endif
        WaveClear w
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        XRD120_ClearCopyFormulas(base+":"+PossiblyQuoteName(name))
        i+=1
    while(1)
    return 0
End
