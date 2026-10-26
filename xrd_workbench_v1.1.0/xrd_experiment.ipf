#pragma rtGlobals=3
// XRD Workbench v1.1.0. Experiment identity, compatible migration and sample state.
// Physical legacy paths remain stable: old graphs and Undo targets keep their bindings.

Function XRD80_EnsureExperiment()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:XRDWorkbench
    NewDataFolder/O root:Packages:XRDWorkbench:Schema
    NewDataFolder/O root:Packages:XRDWorkbench:Registry
    NewDataFolder/O root:Packages:XRDWorkbench:Migration
    String schema="root:Packages:XRDWorkbench:Schema"
    XRD_EnsureNumeric(schema+":schemaVersion",0)
    XRD_EnsureNumeric(schema+":nextUID",1)
    XRD_EnsureNumeric(schema+":migrationBusy",0)
    SVAR/Z experimentUID=$(schema+":experimentUID")
    if(!SVAR_Exists(experimentUID))
        String/G $(schema+":experimentUID")="E_"+num2str(DateTime)
    endif
    Wave/T/Z registry=root:Packages:XRDWorkbench:Registry:objects
    if(!WaveExists(registry))
        Make/T/N=(0,4) root:Packages:XRDWorkbench:Registry:objects
        Wave/T newRegistry=root:Packages:XRDWorkbench:Registry:objects
        SetDimLabel 1,0,Kind,newRegistry
        SetDimLabel 1,1,UID,newRegistry
        SetDimLabel 1,2,Path,newRegistry
        SetDimLabel 1,3,ProjectUID,newRegistry
    endif
    return 0
End

Function XRD_ExperimentSettings()
    return XRD80_EnsureExperiment()
End

Function/S XRD80_NewUID(kind)
    String kind
    XRD80_EnsureExperiment()
    NVAR serial=root:Packages:XRDWorkbench:Schema:nextUID
    String uid
    sprintf uid,"%s_%010.0f",kind,serial
    serial+=1
    return uid
End

Function XRD80_RegisterObject(kind,uid,path,projectUID)
    String kind,uid,path,projectUID
    XRD80_EnsureExperiment()
    Wave/T registry=root:Packages:XRDWorkbench:Registry:objects
    Variable i,n=DimSize(registry,0)
    for(i=0;i<n;i+=1)
        if(cmpstr(registry[i][1],uid)==0)
            registry[i][2]=path
            registry[i][3]=projectUID
            return i
        endif
    endfor
    Redimension/N=(n+1,4) registry
    registry[n][0]=kind
    registry[n][1]=uid
    registry[n][2]=path
    registry[n][3]=projectUID
    return n
End

Function XRD80_RegisterProject(project)
    String project
    if(!DataFolderExists(project))
        return -1
    endif
    XRD80_EnsureExperiment()
    SVAR/Z uid=$(project+":projectUID")
    if(!SVAR_Exists(uid))
        String/G $(project+":projectUID")=XRD80_NewUID("P")
    endif
    SVAR/Z label=$(project+":displayName")
    if(!SVAR_Exists(label))
        DFREF folder=$project
        String/G $(project+":displayName")=GetDataFolder(0,folder)
    endif
    XRD_EnsureNumeric(project+":schemaVersion",800)
    return XRD80_RegisterObject("project",StrVarOrDefault(project+":projectUID",""),project,"")
End

Function XRD80_RegisterMeasurement(path,project)
    String path,project
    if(!DataFolderExists(path))
        return -1
    endif
    XRD80_RegisterProject(project)
    SVAR/Z uid=$(path+":measurementUID")
    if(!SVAR_Exists(uid))
        String/G $(path+":measurementUID")=XRD80_NewUID("M")
    endif
    String/G $(path+":projectUID")=StrVarOrDefault(project+":projectUID","")
    XRD_EnsureNumeric(path+":analysisRevision",0)
    SVAR/Z waveStem=$(path+":waveStem")
    if(!SVAR_Exists(waveStem))
        // The stable stem is independent of editable sample labels.
        String/G $(path+":waveStem")=StrVarOrDefault(path+":measurementUID","")
    endif
    XRD80_EnsureMeasurementWaveNames(path)
    return XRD80_RegisterObject("measurement",StrVarOrDefault(path+":measurementUID",""),path,StrVarOrDefault(project+":projectUID",""))
End

Function XRD80_EnsureMeasurementWaveNames(path)
    String path
    String stem=StrVarOrDefault(path+":waveStem","")
    if(!strlen(stem))
        return -1
    endif
    Wave/Z rawX=$(path+":Raw:twoTheta"),rawY=$(path+":Raw:intensity"),processedY=$(path+":Processed:intensity")
    if(!WaveExists(rawX) || !WaveExists(rawY) || !WaveExists(processedY))
        return -1
    endif
    NewDataFolder/O $(path+":Waves")
    Wave/Z tt=$(path+":Waves:tt_"+stem)
    if(!WaveExists(tt))
        Make/D/N=(numpnts(rawX)) $(path+":Waves:tt_"+stem)
        Wave createdTT=$(path+":Waves:tt_"+stem)
        createdTT=rawX[p]
        SetFormula createdTT,GetWavesDataFolder(rawX,2)+"[p]"
        Make/D/N=(numpnts(rawY)) $(path+":Waves:int_raw_"+stem)
        Wave createdRaw=$(path+":Waves:int_raw_"+stem)
        createdRaw=rawY[p]
        SetFormula createdRaw,GetWavesDataFolder(rawY,2)+"[p]"
        Make/D/N=(numpnts(processedY)) $(path+":Waves:int_"+stem)
        Wave createdIntensity=$(path+":Waves:int_"+stem)
        createdIntensity=processedY[p]
        SetFormula createdIntensity,GetWavesDataFolder(processedY,2)+"[p]"
    endif
    String/G $(path+":waveNamePolicy")="tt_/int_/int_raw_は固定IDの式連動Wave。旧Raw/Processedが正本。Igorの依存式は画面更新時に評価され、関数内から読む場合はDoUpdateを使う。"
    return 0
End

Function XRD_EnsureIdentity(project,path)
    String project,path
    XRD80_RegisterProject(project)
    if(strlen(path))
        XRD80_RegisterMeasurement(path,project)
    endif
    return 0
End

Function/S XRD80_ProjectUID(project)
    String project
    XRD80_RegisterProject(project)
    return StrVarOrDefault(project+":projectUID","")
End

Function/S XRD80_MeasurementUID(path)
    String path
    String project=XRD80_ProjectForMeasurement(path)
    if(strlen(project))
        XRD80_RegisterMeasurement(path,project)
    endif
    return StrVarOrDefault(path+":measurementUID","")
End

Function/S XRD80_ProjectForMeasurement(path)
    String path
    Variable marker=strsearch(path,":Measurements:",0)
    if(marker<0)
        return ""
    endif
    return path[0,marker-1]
End

Function/S XRD80_ResolveMeasurement(uid)
    String uid
    XRD80_EnsureExperiment()
    Wave/T registry=root:Packages:XRDWorkbench:Registry:objects
    Variable i
    for(i=0;i<DimSize(registry,0);i+=1)
        if(cmpstr(registry[i][0],"measurement")==0 && cmpstr(registry[i][1],uid)==0 && DataFolderExists(registry[i][2]))
            return registry[i][2]
        endif
    endfor
    return ""
End

Function/S XRD_ProjectDisplayName(project)
    String project
    XRD80_RegisterProject(project)
    return StrVarOrDefault(project+":displayName",project)
End

Function XRD_UpdateAnalysisState(path)
    String path
    if(!strlen(path) || !DataFolderExists(path))
        return -1
    endif
    Wave/Z ids=$(path+":Peaks:peakID"),assignIDs=$(path+":Assignments:peakID"),assignRefs=$(path+":Assignments:refIndex"),assignRows=$(path+":Assignments:refPeakIndex")
    Variable i,j,n=0,reviewed=0,found
    if(WaveExists(ids))
        n=numpnts(ids)
        for(i=0;i<n;i+=1)
            found=0
            if(WaveExists(assignIDs) && WaveExists(assignRefs))
                for(j=0;j<numpnts(assignIDs);j+=1)
                    // refIndex=0 is the explicit Unknown assignment, also reviewed.
                    if(assignIDs[j]==ids[i])
                        if(assignRefs[j]==0)
                            found=1
                        elseif(assignRefs[j]>0 && WaveExists(assignRows))
                            Wave/Z referenceAngles=$("root:Packages:XRDWorkbench:SharedLibrary:References:Ref"+num2istr(assignRefs[j])+":twoTheta")
                            if(WaveExists(referenceAngles))
                                found=(assignRows[j]>=0 && assignRows[j]<numpnts(referenceAngles))
                            endif
                        endif
                        if(found)
                            break
                        endif
                    endif
                endfor
            endif
            reviewed+=found
        endfor
    endif
    String state="解析中",legacy="同定中"
    if(n==0)
        state="未解析"
        legacy="未着手"
    elseif(reviewed==n)
        state="解析完了"
        legacy="同定完了"
    endif
    String/G $(path+":analysisState")=state
    String/G $(path+":status")=legacy
    Variable/G $(path+":reviewedPeakCount")=reviewed
    Variable/G $(path+":registeredPeakCount")=n
    return (n>0 && reviewed==n)
End

Function XRD_IsAnalysisComplete(path)
    String path
    if(NumVarOrDefault(path+":deleted",0))
        return 0
    endif
    return XRD_UpdateAnalysisState(path)==1
End

Function XRD80_AnalysisChanged(path,reason)
    String path,reason
    if(!DataFolderExists(path))
        return -1
    endif
    Variable/G $(path+":analysisRevision")=NumVarOrDefault(path+":analysisRevision",0)+1
    String/G $(path+":analysisChangedReason")=reason
    XRD_UpdateAnalysisState(path)
    XRD80_MarkLatticeStale(path,reason)
    return 0
End

Function XRD80_MarkLatticeStale(path,reason)
    String path,reason
    SVAR/Z state=$(path+":Lattice:state")
    if(SVAR_Exists(state))
        state="同定・補正変更あり：再計算してください"
        Variable/G $(path+":Lattice:stale")=1
    endif
    // History is preserved with a stale flag; its input values never follow live edits.
    if(DataFolderExists(path+":LatticeRuns"))
        DFREF runs=$(path+":LatticeRuns")
        String name,run
        Variable i=0
        do
            name=GetIndexedObjNameDFR(runs,4,i)
            if(!strlen(name))
                break
            endif
            run=path+":LatticeRuns:"+name
            Variable/G $(run+":stale")=1
            String/G $(run+":staleReason")=reason
            i+=1
        while(1)
    endif
    return 0
End

Function/S XRD80_ProjectProgress(project)
    String project
    String list=XRD_MeasurementOrderList(project),path
    Variable i,total=ItemsInList(list),complete=0
    for(i=0;i<total;i+=1)
        path=project+":Measurements:"+StringFromList(i,list)
        complete+=XRD_IsAnalysisComplete(path)
    endfor
    return num2istr(complete)+"/"+num2istr(total)+"完了"
End

Function XRD80_RenameProject(project,newName)
    String project,newName
    return XRD100_RenameProject(project,newName)
End

Function XRD80_RenameMeasurement(path,newName)
    String path,newName
    newName=TrimString(newName)
    if(!DataFolderExists(path) || !strlen(newName))
        return -1
    endif
    String/G $(path+":displayName")=newName
    return 0
End

Function XRD80_RenameProjectUI()
    return XRD100_RenameUI()
End

Function XRD80_RenameMeasurementUI()
    String path=XRD_Data()
    if(!strlen(path))
        return -1
    endif
    String label=StrVarOrDefault(path+":displayName","")
    Prompt label,"測定データ名"
    DoPrompt "測定データ名を変更",label
    if(V_flag)
        return -1
    endif
    Variable result=XRD80_RenameMeasurement(path,label)
    XRD_Panel()
    return result
End

Function XRD80_ProjectManager()
    return XRD80_ShowProjectManager()
End

Function XRD80_RecordLatticeRun(path)
    String path
    if(!DataFolderExists(path+":Lattice"))
        return -1
    endif
    NewDataFolder/O $(path+":LatticeRuns")
    Variable serial=NumVarOrDefault(path+":nextLatticeRun",1)
    String run=path+":LatticeRuns:Run"+num2istr(serial)
    do
        if(!DataFolderExists(run))
            break
        endif
        serial+=1
        run=path+":LatticeRuns:Run"+num2istr(serial)
    while(1)
    DuplicateDataFolder $(path+":Lattice"),$run
    String/G $(run+":runUID")=XRD80_NewUID("L")
    String/G $(run+":measurementUID")=XRD80_MeasurementUID(path)
    String/G $(run+":calculatedAt")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    String/G $(run+":calibrationNote")=StrVarOrDefault(path+":calibrationNote","")
    String/G $(run+":radiation")=StrVarOrDefault(path+":radiation","")
    Variable/G $(run+":analysisRevision")=NumVarOrDefault(path+":analysisRevision",0)
    Variable/G $(run+":runSequence")=serial
    String reference=XRD_ReferencePath(NumVarOrDefault(run+":refIndex",0))
    String/G $(run+":referenceUID")=StrVarOrDefault(reference+":refUID","")
    String/G $(run+":referenceRevisionUID")=StrVarOrDefault(reference+":revisionUID","")
    Variable/G $(run+":stale")=0
    Variable/G $(path+":Lattice:stale")=0
    Variable/G $(path+":nextLatticeRun")=serial+1
    DuplicateDataFolder $(path+":Assignments"),$(run+":AssignmentSnapshot")
    return serial
End

Function/S XRD80_LatticeResultPath(path,refIndex)
    String path
    Variable refIndex
    String result="",name,item
    Variable i,bestSequence=-1,sequence
    // Prefer immutable history, which cannot be overwritten by a legacy RefN
    // folder whose old index differs from the new Experiment-wide index.
    if(DataFolderExists(path+":LatticeRuns"))
        DFREF runs=$(path+":LatticeRuns")
        i=0
        do
            name=GetIndexedObjNameDFR(runs,4,i)
            if(!strlen(name))
                break
            endif
            item=path+":LatticeRuns:"+name
            if(NumVarOrDefault(item+":refIndex",-1)==refIndex)
                sequence=NumVarOrDefault(item+":runSequence",0)
                if(sequence>=bestSequence)
                    result=item
                    bestSequence=sequence
                endif
            endif
            i+=1
        while(1)
    endif
    if(strlen(result))
        return result
    endif
    if(DataFolderExists(path+":LatticeResults"))
        DFREF oldResults=$(path+":LatticeResults")
        i=0
        do
            name=GetIndexedObjNameDFR(oldResults,4,i)
            if(!strlen(name))
                break
            endif
            item=path+":LatticeResults:"+name
            if(NumVarOrDefault(item+":refIndex",-1)==refIndex)
                result=item
            endif
            i+=1
        while(1)
    endif
    return result
End

Function XRD80_ProjectLatticeSummary()
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project),path,name,result,refPath
    NewDataFolder/O $(project+":Summary")
    Make/O/T/N=(0,12) $(project+":Summary:lattice")
    Wave/T table=$(project+":Summary:lattice")
    Variable i,j,n=0,index
    for(i=0;i<ItemsInList(list);i+=1)
        path=project+":Measurements:"+StringFromList(i,list)
        if(!DataFolderExists(path+":LatticeRuns"))
            continue
        endif
        DFREF runs=$(path+":LatticeRuns")
        j=0
        do
            name=GetIndexedObjNameDFR(runs,4,j)
            if(!strlen(name))
                break
            endif
            result=path+":LatticeRuns:"+name
            Redimension/N=(n+1,12) table
            index=NumVarOrDefault(result+":refIndex",0)
            refPath=XRD_ReferencePath(index)
            table[n][0]=StrVarOrDefault(path+":displayName","")
            table[n][1]=StrVarOrDefault(path+":analysisState","")
            table[n][2]="不明"
            if(DataFolderExists(refPath))
                table[n][2]=XRD_PhaseLabel(index)
            endif
            table[n][3]=StrVarOrDefault(result+":crystalSystem","")
            table[n][4]=num2str(NumVarOrDefault(result+":a",NaN))
            table[n][5]=num2str(NumVarOrDefault(result+":c",NaN))
            table[n][6]=num2istr(NumVarOrDefault(result+":usedCount",0))
            table[n][7]=num2str(NumVarOrDefault(result+":wavelength",NaN))
            table[n][8]=num2str(NumVarOrDefault(result+":zeroCorrection",0))
            table[n][9]=SelectString(NumVarOrDefault(result+":stale",0),"計算済","変更あり・再計算が必要")
            table[n][10]=StrVarOrDefault(result+":calculatedAt",name)
            table[n][11]=StrVarOrDefault(result+":runUID","")
            n+=1
            j+=1
        while(1)
    endfor
    SetDimLabel 1,0,'試料',table
    SetDimLabel 1,1,'解析状態',table
    SetDimLabel 1,2,'相',table
    SetDimLabel 1,3,'晶系',table
    SetDimLabel 1,4,'a (Å)',table
    SetDimLabel 1,5,'c (Å)',table
    SetDimLabel 1,6,'使用ピーク数',table
    SetDimLabel 1,7,'波長 (Å)',table
    SetDimLabel 1,8,'補正 (deg)',table
    SetDimLabel 1,9,'計算状態',table
    SetDimLabel 1,10,'計算日時',table
    SetDimLabel 1,11,'計算ID',table
    DoWindow/K XRDProjectLatticeSummary
    Edit/N=XRDProjectLatticeSummary table as XRD_ProjectDisplayName(project)+"：格子定数・計算履歴"
    return n
End

Function XRD80_MapReferenceWave(fullName,map)
    String fullName
    Wave map
    Wave/Z refs=$fullName
    if(!WaveExists(refs))
        return 0
    endif
    if(strsearch(note(refs),"XRD80ReferenceSpace=global",0)>=0)
        return 0
    endif
    Variable i,oldIndex
    for(i=0;i<numpnts(refs);i+=1)
        oldIndex=refs[i]
        if(oldIndex>0 && oldIndex<=numpnts(map) && map[oldIndex-1]>0)
            refs[i]=map[oldIndex-1]
        endif
    endfor
    Note refs,"XRD80ReferenceSpace=global"
    return 0
End

Function XRD80_ValidateReferenceTree(folderPath,map)
    String folderPath
    Wave map
    Wave/Z refs=$(folderPath+":refIndex")
    Variable i,oldIndex
    if(WaveExists(refs))
        for(i=0;i<numpnts(refs);i+=1)
            oldIndex=refs[i]
            if(oldIndex>0)
                if(oldIndex>numpnts(map) || map[oldIndex-1]<=0)
                    return -1
                endif
            endif
        endfor
    endif
    NVAR/Z scalar=$(folderPath+":refIndex"),preview=$(folderPath+":referenceIndex")
    if(NVAR_Exists(scalar))
        oldIndex=scalar
        if(oldIndex>0)
            if(oldIndex>numpnts(map) || map[oldIndex-1]<=0)
                return -1
            endif
        endif
    endif
    if(NVAR_Exists(preview))
        oldIndex=preview
        if(oldIndex>0)
            if(oldIndex>numpnts(map) || map[oldIndex-1]<=0)
                return -1
            endif
        endif
    endif
    DFREF folder=$folderPath
    String name
    i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        if(cmpstr(name,"References")!=0 && cmpstr(name,"ReferenceMigration")!=0)
            if(XRD80_ValidateReferenceTree(folderPath+":"+name,map)<0)
                return -1
            endif
        endif
        i+=1
    while(1)
    return 0
End

Function XRD80_MapReferenceScalar(fullName,map)
    String fullName
    Wave map
    NVAR/Z index=$fullName
    if(NumVarOrDefault(fullName+"Mapped80",0))
        return 0
    endif
    if(NVAR_Exists(index))
        Variable oldIndex=index
        if(oldIndex>0 && oldIndex<=numpnts(map) && map[oldIndex-1]>0)
            index=map[oldIndex-1]
        endif
        Variable/G $(fullName+"Mapped80")=1
    endif
    return 0
End

Function XRD80_MigrateUndoTree(folderPath,map)
    String folderPath
    Wave map
    if(!DataFolderExists(folderPath))
        return 0
    endif
    XRD80_MapReferenceWave(folderPath+":Assignments:refIndex",map)
    DFREF folder=$folderPath
    Variable i=0
    String name
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        // The only matching waves are assignment snapshots. Original backup is untouched.
        XRD80_MigrateUndoTree(folderPath+":"+name,map)
        i+=1
    while(1)
    return 0
End

Function XRD80_MigrateWindowReferences(project,map)
    String project
    Wave map
    String windows=WinList("*",";","WIN:1"),win,traces,trace,value
    Variable i,j,index
    for(i=0;i<ItemsInList(windows);i+=1)
        win=StringFromList(i,windows)
        if(cmpstr(GetUserData(win,"","XRDProject"),project)!=0 || cmpstr(GetUserData(win,"","XRDReferenceIndexSpace"),"global-v080")==0)
            continue
        endif
        traces=TraceNameList(win,";",1)
        for(j=0;j<ItemsInList(traces);j+=1)
            trace=StringFromList(j,traces)
            value=GetUserData(win,"","Ref_"+trace)
            index=str2num(value)
            if(numtype(index)==0 && index>0 && index<=numpnts(map))
                if(map[index-1]>0)
                    SetWindow $win userdata($("Ref_"+trace))=num2istr(map[index-1])
                endif
            endif
        endfor
        SetWindow $win userdata(XRDReferenceIndexSpace)="global-v080"
    endfor
    return 0
End

Function XRD80_MigrateProjectReferences(project)
    String project
    XRD80_ImportLegacyReferences(project)
    if(NumVarOrDefault(project+":ReferenceMigration:coreMapped",0))
        return 0
    endif
    Wave/Z map=$(project+":ReferenceMigration:legacyToGlobal")
    if(!WaveExists(map))
        return -1
    endif
    // Validate before changing any saved index; a missing card must never silently
    // point to a different reference after library consolidation.
    if(XRD80_ValidateReferenceTree(project,map)<0)
        String/G $(project+":ReferenceMigration:error")="対応する旧参照カードがありません。移行を中断しました。"
        return -2
    endif
    DFREF measurements=$(project+":Measurements")
    String name,path,item,result
    Variable i=0,j,oldIndex
    do
        name=GetIndexedObjNameDFR(measurements,4,i)
        if(!strlen(name))
            break
        endif
        path=XRD110_MeasurementPath(project,name)
        XRD80_MapReferenceWave(path+":Assignments:refIndex",map)
        XRD80_MapReferenceWave(path+":Candidates:refIndex",map)
        XRD80_MapReferenceScalar(path+":Preview:referenceIndex",map)
        XRD80_MapReferenceScalar(path+":Lattice:refIndex",map)
        if(DataFolderExists(path+":LatticeResults"))
            DFREF results=$(path+":LatticeResults")
            j=0
            do
                item=GetIndexedObjNameDFR(results,4,j)
                if(!strlen(item))
                    break
                endif
                result=path+":LatticeResults:"+item
                oldIndex=NumVarOrDefault(result+":refIndex",0)
                Variable/G $(result+":legacyRefIndex")=oldIndex
                XRD80_MapReferenceScalar(result+":refIndex",map)
                NewDataFolder/O $(path+":LatticeRuns")
                String archived=path+":LatticeRuns:Legacy"+num2istr(j+1)
                if(!DataFolderExists(archived))
                    DuplicateDataFolder $result,$archived
                    String/G $(archived+":runUID")=XRD80_NewUID("L")
                    String/G $(archived+":measurementUID")=XRD80_MeasurementUID(path)
                    String/G $(archived+":calculatedAt")="v0.7.xから引継ぎ（日時記録なし）"
                endif
                j+=1
            while(1)
        endif
        XRD_UpdateAnalysisState(path)
        i+=1
    while(1)
    XRD80_MigrateUndoTree(project+":Undo",map)
    XRD80_MigrateWindowReferences(project,map)
    String/G $(project+":ReferenceMigration:refIndexSpace")="global-v080"
    Variable/G $(project+":ReferenceMigration:coreMapped")=1
    return 0
End

Function XRD80_MigrateExperiment()
    XRD80_EnsureExperiment()
    NVAR busy=root:Packages:XRDWorkbench:Schema:migrationBusy
    if(busy)
        return 0
    endif
    busy=1
    String list=XRD_ProjectList(),project,path,name,backup="root:Packages:XRDWorkbenchRecoveryV080"
    Variable i,j,needsBackup=0,result=0
    try
    for(i=0;i<ItemsInList(list);i+=1)
        project=XRD100_ProjectAt(list,i)
        if(!strlen(StrVarOrDefault(project+":projectUID","")))
            needsBackup=1
        endif
    endfor
    if(needsBackup && !DataFolderExists(backup))
        DuplicateDataFolder root:Packages:XRDWorkbench,$backup
        String/G root:Packages:XRDWorkbench:Migration:originalBackup=backup
        String/G root:Packages:XRDWorkbench:Migration:policy="旧パス・Raw・Undoを残す互換移行。旧参照ON/OFFは共通初期値へ引き継がない。"
    endif
    XRD80_InitLibrary()
    for(i=0;i<ItemsInList(list);i+=1)
        project=XRD100_ProjectAt(list,i)
        XRD80_RegisterProject(project)
        DFREF measurements=$(project+":Measurements")
        j=0
        do
            name=GetIndexedObjNameDFR(measurements,4,j)
            if(!strlen(name))
                break
            endif
            path=XRD110_MeasurementPath(project,name)
            XRD80_RegisterMeasurement(path,project)
            XRD_UpdateAnalysisState(path)
            j+=1
        while(1)
        result=XRD80_MigrateProjectReferences(project)
        if(result<0)
            break
        endif
        XRD80_MigrateStyles(project)
    endfor
    if(result>=0)
        XRD80_SyncReferenceCounts()
    endif
    catch
        result=-max(1,GetRTError(1))
    endtry
    if(result>=0)
        Variable/G root:Packages:XRDWorkbench:Schema:schemaVersion=800
        String/G root:Packages:XRDWorkbench:Migration:state="移行済み（旧パス・Undoを維持）"
    else
        String/G root:Packages:XRDWorkbench:Migration:state="移行未完了：元バックアップを保持"
    endif
    busy=0
    return result
End
