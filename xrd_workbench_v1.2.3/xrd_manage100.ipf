#pragma rtGlobals=3
// v1.2.0: journaled physical project operations; stable IDs remain unchanged.
Function/S XRD100_Management()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:Workbench
    NewDataFolder/O root:Packages:Workbench:Management
    NewDataFolder/O root:Packages:Workbench:Reference
    return "root:Packages:Workbench:Management"
End

Function XRD100_Busy()
    return NumVarOrDefault("root:Packages:XRDWorkbench:Admin100:busy",0)
End

Function/S XRD100_Admin()
    NewDataFolder/O root:Packages:XRDWorkbench:Admin100
    NewDataFolder/O root:Packages:XRDWorkbench:ProjectTrash
    NewDataFolder/O root:Packages:XRDWorkbench:ProjectTransactions
    return "root:Packages:XRDWorkbench:Admin100"
End

Function/S XRD100_ProjectAt(list,index)
    String list
    Variable index
    String item=StringFromList(index,list)
    if(strsearch(item,"root:",0)==0)
        return item
    endif
    return "root:Packages:XRDWorkbench:"+item
End

Function/S XRD100_ProjectList()
    String roots="root:Packages:XRDWorkbench;"+XRD100_Management(),base,name,path,list=""
    Variable b,i
    for(b=0;b<ItemsInList(roots);b+=1)
        base=StringFromList(b,roots)
        if(!DataFolderExists(base))
            continue
        endif
        DFREF folder=$base
        i=0
        do
            name=GetIndexedObjNameDFR(folder,4,i)
            if(!strlen(name))
                break
            endif
            path=base+":"+PossiblyQuoteName(name)
            if(DataFolderExists(path+":Measurements") && DataFolderExists(path+":References") && !NumVarOrDefault(path+":projectDeleted100",0))
                list+=path+";"
            endif
            i+=1
        while(1)
    endfor
    return list
End

Function/S XRD100_ProjectByUID(uid,[deleted])
    String uid
    Variable deleted
    Wave/T registry=root:Packages:XRDWorkbench:Registry:objects
    Variable i
    for(i=0;i<DimSize(registry,0);i+=1)
        if(cmpstr(registry[i][0],"project")==0 && cmpstr(registry[i][1],uid)==0 && DataFolderExists(registry[i][2]))
            if(!NumVarOrDefault(registry[i][2]+":projectDeleted100",0) || deleted)
                return registry[i][2]
            endif
        endif
    endfor
    return ""
End

Function/S XRD100_Repath(value,oldPath,newPath)
    String value,oldPath,newPath
    if(cmpstr(value,oldPath)==0)
        return newPath
    endif
    if(strsearch(value,oldPath+":",0)==0)
        return newPath+value[strlen(oldPath),inf]
    endif
    return value
End

Function/S XRD100_RepathList(value,oldPath,newPath)
    String value,oldPath,newPath
    Variable i
    String result="",item
    if(strsearch(value,";",0)<0)
        return XRD100_Repath(value,oldPath,newPath)
    endif
    for(i=0;i<ItemsInList(value);i+=1)
        item=StringFromList(i,value)
        result+=XRD100_Repath(item,oldPath,newPath)+";"
    endfor
    return result
End

Function XRD100_Backup()
    String admin=XRD100_Admin(),folder=StrVarOrDefault(admin+":backupFolder",""),destination
    Variable ref,error=0
    if(!strlen(folder))
        PathInfo IgorUserFiles
        folder=S_path+"XRDWorkbench_ProjectBackups:"
    endif
    NewPath/O/C/Q/Z XRD100BackupPath,folder
    if(V_flag)
        return -1
    endif
    destination=folder+"XRD_before_"+num2istr(DateTime)+"_"+num2istr(ticks)+".pxp"
    try
        SaveExperiment/C/F={1,"",0} as destination; AbortOnRTE
        GetFileFolderInfo/Q/Z destination
        if(V_flag || !V_isFile || V_logEOF<=0)
            error=1
        endif
    catch
        error=max(1,GetRTError(1))
    endtry
    if(error)
        return -1
    endif
    String/G $(admin+":lastBackup")=destination
    return 0
End

Function/S XRD100_TxStart(kind,project)
    String kind,project
    String admin=XRD100_Admin(),tx="root:Packages:XRDWorkbench:ProjectTransactions:T"+XRD80_NewUID("J")
    if(XRD100_Busy())
        return ""
    endif
    if(XRD100_Backup()<0)
        return ""
    endif
    NewDataFolder $tx
    NewDataFolder $(tx+":TextCopies")
    Make/O/T/N=(0,3) $(tx+":ops"),$(tx+":strings"),$(tx+":texts"),$(tx+":windows"),$(tx+":formulas"),$(tx+":fingerprints")
    String/G $(tx+":kind")=kind
    String/G $(tx+":projectUID")=StrVarOrDefault(project+":projectUID","")
    String/G $(tx+":backup")=StrVarOrDefault(admin+":lastBackup","")
    String/G $(tx+":state")="処理中"
    String/G $(tx+":originalPath")=project
    String/G $(admin+":activeTransaction")=tx
    try
        XRD100_CaptureMetadata("root:Packages:XRDWorkbench",tx); AbortOnRTE
        XRD100_CaptureMetadata("root:Packages:Workbench",tx); AbortOnRTE
        XRD100_Fingerprint(project,tx); AbortOnRTE
        XRD100_CaptureFormulas("root:",tx,project); AbortOnRTE
        XRD100_WindowPaths(tx,project,project,1); AbortOnRTE
    catch
        String/G $(tx+":error")=GetErrMessage(GetRTError(1))
        String/G $(tx+":state")="事前取得失敗（元データ未変更）"
        return ""
    endtry
    Variable/G $(admin+":busy")=1
    return tx
End

Function XRD100_CaptureMetadata(base,tx)
    String base,tx
    if(!DataFolderExists(base) || strsearch(base,"root:Packages:XRDWorkbench:ProjectTransactions",0)==0)
        return 0
    endif
    DFREF folder=$base
    Wave/T strings=$(tx+":strings"),texts=$(tx+":texts")
    String name,path
    Variable i=0,n
    do
        name=GetIndexedObjNameDFR(folder,3,i)
        if(!strlen(name))
            break
        endif
        path=base+":"+PossiblyQuoteName(name)
        SVAR value=$path
        n=DimSize(strings,0);Redimension/N=(n+1,3) strings
        strings[n][0]=path;strings[n][1]=value
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,1,i)
        if(!strlen(name))
            break
        endif
        path=base+":"+PossiblyQuoteName(name)
        Wave w=$path
        if(WaveType(w)==0)
            n=DimSize(texts,0);Redimension/N=(n+1,3) texts
            texts[n][0]=path;texts[n][1]=tx+":TextCopies:W"+num2istr(n)
            Duplicate w,$(texts[n][1])
        endif
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        XRD100_CaptureMetadata(base+":"+PossiblyQuoteName(name),tx)
        i+=1
    while(1)
End

Function XRD100_CaptureFormulas(base,tx,project)
    String base,tx,project
    if(strsearch(base,"root:Packages:XRDWorkbench:ProjectTransactions",0)==0 || strsearch(base,"root:Packages:XRDWorkbenchRecovery",0)==0)
        return 0
    endif
    DFREF folder=$base
    Wave/T formulas=$(tx+":formulas")
    String name,path,formula
    Variable i=0,n
    do
        name=GetIndexedObjNameDFR(folder,1,i)
        if(!strlen(name))
            break
        endif
        path=RemoveEnding(base,":")+":"+PossiblyQuoteName(name)
        Wave w=$path
        formula=GetFormula(w)
        if(strsearch(formula,project+":",0)>=0)
            n=DimSize(formulas,0);Redimension/N=(n+1,3) formulas
            formulas[n][0]=path;formulas[n][1]=formula
        endif
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        XRD100_CaptureFormulas(RemoveEnding(base,":")+":"+PossiblyQuoteName(name),tx,project)
        i+=1
    while(1)
End

Function XRD100_WindowPaths(tx,oldPath,newPath,capture)
    String tx,oldPath,newPath
    Variable capture
    String windows=WinList("*",";","WIN:65")+WinList("*",";","FLT:1"),win,children,keys="XRDData;XRDProject;XRDAdoptData;XRDLivePaths;XRDFollowPeak;XRDGraphData;XRDPlotRecipe",key,value
    Wave/T saved=$(tx+":windows")
    Variable i,j,n
    for(i=0;i<ItemsInList(windows);i+=1)
        win=StringFromList(i,windows)
        children=ChildWindowList(win)
        for(j=0;j<ItemsInList(children);j+=1)
            windows+=win+"#"+StringFromList(j,children)+";"
        endfor
        for(j=0;j<ItemsInList(keys);j+=1)
            key=StringFromList(j,keys);value=GetUserData(win,"",key)
            if(capture)
                n=DimSize(saved,0);Redimension/N=(n+1,3) saved
                saved[n][0]=win;saved[n][1]=key;saved[n][2]=value
            elseif(strlen(value))
                SetWindow $win userdata($key)=XRD100_RepathList(value,oldPath,newPath)
            endif
        endfor
    endfor
End

Function XRD100_Op(tx,kind,oldPath,newPath)
    String tx,kind,oldPath,newPath
    Wave/T ops=$(tx+":ops")
    Variable n=DimSize(ops,0)
    Redimension/N=(n+1,3) ops
    ops[n][0]=kind;ops[n][1]=oldPath;ops[n][2]=newPath
    Variable fault=NumVarOrDefault(XRD100_Admin()+":faultAfter",0)
    if(fault>0 && n+1==fault)
        AbortOnValue 1,10001 // 管理操作の故障注入
    endif
End

Function XRD100_Rebind(tx,oldPath,newPath)
    String tx,oldPath,newPath
    Wave/T strings=$(tx+":strings"),texts=$(tx+":texts"),formulas=$(tx+":formulas"),ops=$(tx+":ops")
    String path,value,formula,oldWave,newWave
    Variable i,j
    for(i=0;i<DimSize(strings,0);i+=1)
        path=XRD100_Repath(strings[i][0],oldPath,newPath)
        SVAR/Z target=$path
        if(SVAR_Exists(target))
            if(cmpstr(ParseFilePath(0,path,":",1,0),"nativeMacro")==0)
                target=XRD100_MapValue(tx,target,oldPath,newPath,1)
            else
                target=XRD100_MapValue(tx,target,oldPath,newPath,0)
            endif
        endif
    endfor
    for(i=0;i<DimSize(texts,0);i+=1)
        path=XRD100_Repath(texts[i][0],oldPath,newPath)
        Wave/T/Z targetText=$path
        if(WaveExists(targetText))
            targetText=XRD100_MapValue(tx,targetText[p][q][r][s],oldPath,newPath,0)
        endif
    endfor
    for(i=0;i<DimSize(formulas,0);i+=1)
        path=XRD100_Repath(formulas[i][0],oldPath,newPath)
        formula=ReplaceString(oldPath+":",formulas[i][1],newPath+":")
        for(j=0;j<DimSize(ops,0);j+=1)
            if(cmpstr(ops[j][0],"wave")==0)
                path=XRD100_Repath(path,ops[j][1],ops[j][2])
                formula=ReplaceString(ops[j][1],formula,ops[j][2])
            endif
        endfor
        Wave/Z dependency=$path
        if(WaveExists(dependency))
            SetFormula dependency,formula; AbortOnRTE
        endif
    endfor
    XRD100_WindowPaths(tx,oldPath,newPath,0)
    DoUpdate
End

Function XRD100_Rollback(tx)
    String tx
    Wave/T ops=$(tx+":ops"),strings=$(tx+":strings"),texts=$(tx+":texts"),windows=$(tx+":windows"),formulas=$(tx+":formulas")
    Variable i,error=0
    String parent,name,path
    try
        for(i=DimSize(ops,0)-1;i>=0;i-=1)
            path=ops[i][2];name=XRD100_Leaf(ops[i][1])
            strswitch(ops[i][0])
                case "folder":
                    RenameDataFolder $path,$name; AbortOnRTE
                    break
                case "move":
                    parent=RemoveEnding(ParseFilePath(1,ops[i][1],":",1,0),":")
                    MoveDataFolder $path,$parent; AbortOnRTE
                    break
                case "wave":
                    Wave w=$path
                    Rename w,$name; AbortOnRTE
                    WaveClear w
                    break
                case "newString":
                    KillStrings/Z $path
                    break
                case "createdFolder":
                    XRD120_ClearCopyFormulas(path)
                    KillDataFolder $path; AbortOnRTE
                    break
                case "created":
                    KillWaves/Z $path
                    break
            endswitch
        endfor
        for(i=0;i<DimSize(strings,0);i+=1)
            String/G $(strings[i][0])=strings[i][1]
        endfor
        for(i=0;i<DimSize(texts,0);i+=1)
            Duplicate/O $(texts[i][1]),$(texts[i][0])
        endfor
        for(i=0;i<DimSize(formulas,0);i+=1)
            Wave/Z dependency=$(formulas[i][0])
            if(WaveExists(dependency))
                SetFormula dependency,formulas[i][1]
            endif
        endfor
        for(i=0;i<DimSize(windows,0);i+=1)
            if(WinType(windows[i][0]))
                SetWindow $(windows[i][0]) userdata($(windows[i][1]))=windows[i][2]
            endif
        endfor
    catch
        error=max(1,GetRTError(1))
        String/G $(tx+":restoreError")=GetErrMessage(error)
    endtry
    String/G $(tx+":state")=SelectString(error==0,"復旧失敗：実行前バックアップから復旧が必要","変更前へ復元済み")
    Variable/G $(XRD100_Admin()+":busy")=(error!=0)
    return error
End

Function XRD100_ValidProjectName(project,name)
    String project,name
    name=TrimString(name)
    if(!strlen(name) || strlen(name)>255 || GrepString(name,"[\"':;\\x00-\\x1f]"))
        return -1
    endif
    String list=XRD100_ProjectList(),other,base=XRD100_Management()
    Variable i,error
    for(i=0;i<ItemsInList(list);i+=1)
        other=StringFromList(i,list)
        if(cmpstr(other,project)!=0 && cmpstr(LowerStr(XRD_ProjectDisplayName(other)),LowerStr(name))==0)
            return -2
        endif
    endfor
    DFREF previous=GetDataFolderDFR()
    SetDataFolder $base
    error=CheckName(name,11)
    SetDataFolder previous
    if(error && cmpstr(LowerStr(project),LowerStr(base+":"+PossiblyQuoteName(name)))!=0)
        return -2
    endif
    return 0
End

Function XRD100_RenameProject(project,newName)
    String project,newName
    newName=TrimString(newName)
    if(!DataFolderExists(project) || XRD100_ValidProjectName(project,newName)<0 || XRD100_Busy())
        return -1
    endif
    String oldName=XRD_ProjectDisplayName(project),base=XRD100_Management(),newPath=base+":"+PossiblyQuoteName(newName),temp="XRDTemp_"+XRD80_ProjectUID(project),temporary,tx
    if(cmpstr(project,newPath,1)==0 && cmpstr(oldName,newName,1)==0)
        return 0
    endif
    XRD100_Admin()
    if(XRD100_PlanNames(project,newName)<0)
        return -2
    endif
    tx=XRD100_TxStart("プロジェクト改名・移行",project)
    if(!strlen(tx))
        return -3
    endif
    Variable error=0
    try
        temporary=RemoveEnding(ParseFilePath(1,project,":",1,0),":")+":"+temp
        RenameDataFolder $project,$temp; AbortOnRTE
        XRD100_Op(tx,"folder",project,temporary)
        if(cmpstr(RemoveEnding(ParseFilePath(1,temporary,":",1,0),":"),base)!=0)
            MoveDataFolder $temporary,$base; AbortOnRTE
            XRD100_Op(tx,"move",temporary,base+":"+temp)
            temporary=base+":"+temp
        endif
        RenameDataFolder $temporary,$newName; AbortOnRTE
        XRD100_Op(tx,"folder",temporary,newPath)
        XRD100_ExecuteNamePlan(tx,project,newPath); AbortOnRTE
        XRD100_Rebind(tx,project,newPath); AbortOnRTE
        String/G $(newPath+":displayName")=newName
        XRD100_RefreshRegistry(newPath); AbortOnRTE
        XRD100_CommitNames(newPath,newName,tx=tx); AbortOnRTE
        if(!DataFolderExists(newPath) || cmpstr(StrVarOrDefault(newPath+":projectUID",""),StrVarOrDefault(tx+":projectUID",""))!=0)
            AbortOnValue 1,10001 // プロジェクト整合性検査に失敗
        endif
        if(XRD100_VerifyFingerprint(newPath,tx)<0)
            AbortOnValue 1,10001 // 数値データの整合性検査に失敗
        endif
        XRD100_Commit(tx)
    catch
        error=max(1,GetRTError(1))
        String/G $(tx+":error")=GetErrMessage(error)
        XRD100_Rollback(tx)
    endtry
    return SelectNumber(error==0,-4,0)
End

Function XRD100_RefreshRegistry(project)
    String project
    XRD80_RegisterProject(project)
    DFREF folder=$(project+":Measurements")
    String name
    Variable i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        XRD80_RegisterMeasurement(project+":Measurements:"+PossiblyQuoteName(name),project)
        i+=1
    while(1)
End

Function XRD100_Commit(tx)
    String tx
    String/G $(tx+":state")="完了"
    String/G $(tx+":finished")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    Variable/G $(XRD100_Admin()+":busy")=0
End

Function XRD100_TrashProject(project)
    String project
    if(!DataFolderExists(project) || XRD100_Busy())
        return -1
    endif
    String trash="root:Packages:XRDWorkbench:ProjectTrash",uid=XRD80_ProjectUID(project),destination=trash+":"+uid,tx,temp,oldName=ParseFilePath(0,project,":",1,0)
    XRD100_Admin()
    if(DataFolderExists(destination))
        return -2
    endif
    tx=XRD100_TxStart("プロジェクト削除",project)
    if(!strlen(tx))
        return -3
    endif
    Variable error=0
    try
        temp=RemoveEnding(ParseFilePath(1,project,":",1,0),":")+":"+uid
        RenameDataFolder $project,$uid; AbortOnRTE
        XRD100_Op(tx,"folder",project,temp)
        MoveDataFolder $temp,$trash; AbortOnRTE
        XRD100_Op(tx,"move",temp,destination)
        XRD100_Rebind(tx,project,destination); AbortOnRTE
        XRD100_RefreshRegistry(destination); AbortOnRTE
        Variable/G $(destination+":projectDeleted100")=1
        Variable/G $(XRD100_Admin()+":allowEmpty")=1
        String/G $(destination+":deletedAt100")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
        SVAR active=root:Packages:XRDWorkbench:activeProject
        if(cmpstr(active,destination)==0)
            active=StringFromList(0,XRD100_ProjectList())
        endif
        XRD100_Commit(tx)
    catch
        error=max(1,GetRTError(1))
        String/G $(tx+":error")=GetErrMessage(error)
        XRD100_Rollback(tx)
    endtry
    return SelectNumber(error==0,-4,0)
End

Function XRD100_RestoreProject(project,newName)
    String project,newName
    if(!NumVarOrDefault(project+":projectDeleted100",0))
        return -1
    endif
    Variable result=XRD100_RenameProject(project,newName)
    if(result==0)
        String destination=XRD100_Management()+":"+PossiblyQuoteName(TrimString(newName))
        Variable/G $(destination+":projectDeleted100")=0
        String/G root:Packages:XRDWorkbench:activeProject=destination
    endif
    return result
End

Function/S XRD100_Impact(project)
    String project
    String list=XRD_MeasurementOrderList(project),uid,recipe,base=XRD_PlotRoot()+":Plots",result
    Variable i,j,figures=0,compares=0
    DFREF plots=$base
    Wave/T/Z compare=$(XRD_PlotRoot()+":compareUIDs")
    for(i=0;i<ItemsInList(list);i+=1)
        uid=StrVarOrDefault(project+":Measurements:"+StringFromList(i,list)+":measurementUID","")
        if(WaveExists(compare))
            for(j=0;j<numpnts(compare);j+=1)
                compares+=(cmpstr(compare[j],uid)==0)
            endfor
        endif
    endfor
    i=0
    do
        recipe=GetIndexedObjNameDFR(plots,4,i)
        if(!strlen(recipe))
            break
        endif
        Wave/T/Z sources=$(base+":"+recipe+":sourceUIDs")
        if(WaveExists(sources))
            for(j=0;j<numpnts(sources);j+=1)
                uid=XRD80_ResolveMeasurement(sources[j])
                if(strsearch(uid,project+":",0)==0)
                    figures+=1
                    break
                endif
            endfor
        endif
        i+=1
    while(1)
    return "測定データ "+num2istr(ItemsInList(list))+"件 / 保存図 "+num2istr(figures)+"件 / 比較対象 "+num2istr(compares)+"試料"
End

Function/S XRD100_Leaf(path)
    String path
    String name=ParseFilePath(0,path,":",1,0)
    if(strlen(name)>1 && cmpstr(name[0],"'")==0 && cmpstr(name[strlen(name)-1],"'")==0)
        name=name[1,strlen(name)-2]
    endif
    return name
End

Function/S XRD100_MapValue(tx,value,oldPath,newPath,script)
    String tx,value,oldPath,newPath
    Variable script
    Wave/T ops=$(tx+":ops")
    Variable j
    if(script)
        value=ReplaceString(oldPath+":",value,newPath+":")
    else
        value=XRD100_RepathList(value,oldPath,newPath)
    endif
    for(j=0;j<DimSize(ops,0);j+=1)
        if(cmpstr(ops[j][0],"wave")==0 || cmpstr(ops[j][0],"folder")==0 || cmpstr(ops[j][0],"move")==0)
            if(script)
                value=ReplaceString(ops[j][1],value,ops[j][2])
            else
                value=XRD100_RepathList(value,ops[j][1],ops[j][2])
            endif
        endif
    endfor
    return value
End

Function XRD100_Fingerprint(base,tx)
    String base,tx
    DFREF folder=$base
    Wave/T fingerprints=$(tx+":fingerprints")
    String name,path
    Variable i=0,n
    do
        name=GetIndexedObjNameDFR(folder,1,i)
        if(!strlen(name))
            break
        endif
        path=base+":"+PossiblyQuoteName(name)
        Wave w=$path
        if(WaveType(w)!=0 && !strlen(GetFormula(w)) && (strsearch(path,":Raw:",0)>0 || strsearch(path,":Peaks:",0)>0 || strsearch(path,":Assignments:",0)>0 || strsearch(path,":Lattice",0)>0))
            n=DimSize(fingerprints,0);Redimension/N=(n+1,3) fingerprints
            fingerprints[n][0]=path;fingerprints[n][1]=num2str(WaveCRC(0,w))
        endif
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        XRD100_Fingerprint(base+":"+PossiblyQuoteName(name),tx)
        i+=1
    while(1)
End

Function XRD100_VerifyFingerprint(project,tx)
    String project,tx
    Wave/T fingerprints=$(tx+":fingerprints")
    String old=StrVarOrDefault(tx+":originalPath",""),path
    Variable i
    for(i=0;i<DimSize(fingerprints,0);i+=1)
        path=XRD100_MapValue(tx,fingerprints[i][0],old,project,0)
        Wave/Z w=$path
        if(!WaveExists(w) || cmpstr(num2str(WaveCRC(0,w)),fingerprints[i][1])!=0)
            return -1
        endif
    endfor
    return 0
End
