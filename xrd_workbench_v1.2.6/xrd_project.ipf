#pragma rtGlobals=3
// XRD Workbench v1.2.0. Project, measurement and persistent analysis state.

Function XRD_Init()
    XRD_ExperimentSettings()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:XRDWorkbench
    SVAR/Z active=root:Packages:XRDWorkbench:activeProject
    if(!SVAR_Exists(active))
        String/G root:Packages:XRDWorkbench:activeProject=""
        if(ItemsInList(XRD_ProjectList())==0)
            Variable/G root:Packages:XRDWorkbench:Schema:schemaVersion=800
        endif
        XRD_NewProject()
    elseif(strlen(active)==0 || !DataFolderExists(active))
        String available=XRD100_ProjectList()
        if(ItemsInList(available))
            active=StringFromList(0,available)
        elseif(!NumVarOrDefault("root:Packages:XRDWorkbench:Admin100:allowEmpty",0))
            XRD_NewProject()
        endif
    else
        if(NumVarOrDefault("root:Packages:XRDWorkbench:Schema:schemaVersion",0)<800)
            if(XRD80_MigrateExperiment()<0)
                Abort "XRDの移行を中断しました。旧データの復旧コピーを保持しています。Migration:stateを確認してください。"
            endif
        endif
        XRD_UpgradeProject(active)
    endif
End

Function XRD_NewProject()
    String base=XRD100_Management()+":", path
    Variable i=1
    do
        path=base+"Project"+num2istr(i)
        i+=1
    while(DataFolderExists(path))
    NewDataFolder $path
    String/G $(path+":version")="0.6.0"
    String/G $(path+":activeData")=""
    String/G $(path+":referenceFolderHint")="未選択"
    String/G $(path+":referencePolicy")="参照TXTをExperiment内へコピーし、移動後はフォルダを再指定する"
    String/G $(path+":created")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    String/G $(path+":allowedElements")=""
    String/G $(path+":protectedClasses")="Y-type;W-type;QS-type"
    String/G $(path+":referenceLoadSummary")="参照データ未読込"
    Variable/G $(path+":activeStep")=1
    Variable/G $(path+":referenceCount")=0
    Variable/G $(path+":referenceErrorCount")=0
    Variable/G $(path+":elementFilterMode")=0
    Variable/G $(path+":matchTolerance")=0.20
    Variable/G $(path+":maxCommonShift")=0.30
    Variable/G $(path+":previewMinIntensity")=1
    Variable/G $(path+":stackOffset")=120
    NewDataFolder $(path+":Measurements")
    NewDataFolder $(path+":References")
    NewDataFolder $(path+":ReferenceMigration")
    Make/D/N=0 $(path+":ReferenceMigration:legacyToGlobal")
    Variable/G $(path+":ReferenceMigration:coreMapped")=1
    String/G $(path+":ReferenceMigration:refIndexSpace")="global-v080"
    XRD_InitReferenceIndex(path)
    SVAR active=root:Packages:XRDWorkbench:activeProject
    active=path
    XRD_V3Settings(path)
    XRD_V50Project(path)
    XRD_CloseEditors()
    XRD_EnsureIdentity(path,"")
    XRD80_SyncReferenceCounts()
    KillPath/Z XRDReferencePath
    return 0
End

Function XRD_UpgradeProject(project)
    String project
    XRD_EnsureIdentity(project,"")
    NewDataFolder/O $(project+":Measurements")
    NewDataFolder/O $(project+":References")
    SVAR/Z version=$(project+":version")
    if(!SVAR_Exists(version))
        String/G $(project+":version")="0.6.0"
    else
        version="0.6.0"
    endif
    SVAR/Z activeData=$(project+":activeData")
    if(!SVAR_Exists(activeData))
        String/G $(project+":activeData")=""
    endif
    SVAR/Z hint=$(project+":referenceFolderHint")
    if(!SVAR_Exists(hint))
        String/G $(project+":referenceFolderHint")="未選択"
    endif
    SVAR/Z policy=$(project+":referencePolicy")
    if(!SVAR_Exists(policy))
        String/G $(project+":referencePolicy")="参照TXTをExperiment内へコピーし、移動後はフォルダを再指定する"
    endif
    SVAR/Z allowed=$(project+":allowedElements")
    if(!SVAR_Exists(allowed))
        String/G $(project+":allowedElements")=""
    endif
    SVAR/Z protected=$(project+":protectedClasses")
    if(!SVAR_Exists(protected))
        String/G $(project+":protectedClasses")="Y-type;W-type;QS-type"
    endif
    SVAR/Z loadSummary=$(project+":referenceLoadSummary")
    if(!SVAR_Exists(loadSummary))
        String/G $(project+":referenceLoadSummary")="参照データ未読込"
    endif
    XRD_EnsureNumeric(project+":activeStep",1)
    XRD_EnsureNumeric(project+":referenceCount",0)
    XRD_EnsureNumeric(project+":referenceErrorCount",0)
    XRD_EnsureNumeric(project+":elementFilterMode",0)
    XRD_EnsureNumeric(project+":matchTolerance",0.20)
    XRD_EnsureNumeric(project+":maxCommonShift",0.30)
    XRD_EnsureNumeric(project+":previewMinIntensity",1)
    XRD_EnsureNumeric(project+":stackOffset",120)
    XRD_V3Settings(project)
    XRD_V50Project(project)
    XRD_InitReferenceIndex(project)
    XRD_RebuildReferenceTable(project)
    DFREF measurements=$(project+":Measurements")
    String name
    Variable i=0
    do
        name=GetIndexedObjNameDFR(measurements,4,i)
        if(strlen(name)==0)
            break
        endif
        XRD_EnsureMeasurement(XRD110_MeasurementPath(project,name))
        XRD_RebuildCandidateTable(XRD110_MeasurementPath(project,name))
        XRD_RefreshAssignmentTable(XRD110_MeasurementPath(project,name))
        NVAR candidateRow=$(XRD110_MeasurementPath(project,name)+":selectedCandidateRow")
        XRD_PreviewCandidate(XRD110_MeasurementPath(project,name),candidateRow)
        i+=1
    while(1)
    return 0
End

Function XRD_EnsureNumeric(fullName,defaultValue)
    String fullName
    Variable defaultValue
    NVAR/Z value=$fullName
    if(!NVAR_Exists(value))
        Variable/G $fullName=defaultValue
    endif
End

Function XRD_InitReferenceIndex(project)
    String project
    String refRoot=project+":References"
    NewDataFolder/O $refRoot
    Wave/T/Z table=$(refRoot+":table")
    if(!WaveExists(table))
        Make/T/N=(0,6) $(refRoot+":table")
        Wave/T newTable=$(refRoot+":table")
        SetDimLabel 1,0,Index,newTable
        SetDimLabel 1,1,Card,newTable
        SetDimLabel 1,2,Name,newTable
        SetDimLabel 1,3,Formula,newTable
        SetDimLabel 1,4,Class,newTable
        SetDimLabel 1,5,File,newTable
    endif
End

Function/S XRD_Project()
    SVAR/Z active=root:Packages:XRDWorkbench:activeProject
    if(!SVAR_Exists(active) || strlen(active)==0 || !DataFolderExists(active))
        XRD_Init()
        SVAR initialized=root:Packages:XRDWorkbench:activeProject
        return initialized
    endif
    return active
End

Function/S XRD_ProjectList()
    return XRD100_ProjectList()
End

Function XRD_SelectProject()
    return XRD80_ProjectManager()
End

Function/S XRD_Data()
    String project=XRD_Project()
    SVAR active=$(project+":activeData")
    return active
End

Function/S XRD_MeasurementOrderList(project)
    String project
    DFREF folder=$(project+":Measurements")
    String name,path,result=""
    Variable i=0,n=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(strlen(name)==0)
            break
        endif
        n+=1
        i+=1
    while(1)
    Make/FREE/D/N=(n) orders
    Make/FREE/T/N=(n) names
    Variable kept=0
    for(i=0;i<n;i+=1)
        name=GetIndexedObjNameDFR(folder,4,i)
        path=XRD110_MeasurementPath(project,name)
        if(NumVarOrDefault(path+":deleted",0))
            continue
        endif
        XRD_EnsureMeasurement(path)
        NVAR order=$(path+":stackOrder")
        orders[kept]=order
        names[kept]=PossiblyQuoteName(name)
        kept+=1
    endfor
    n=kept
    Redimension/N=(n) orders,names
    if(n>1)
        Sort orders,orders,names
    endif
    for(i=0;i<n;i+=1)
        result+=names[i]+";"
    endfor
    return result
End

Function XRD_MoveMeasurement(path,direction)
    String path
    Variable direction
    if(strlen(path)==0 || (direction!=-1 && direction!=1))
        return -1
    endif
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project),name,otherPath
    DFREF currentDF=$path
    name=PossiblyQuoteName(GetDataFolder(0,currentDF))
    Variable row=WhichListItem(name,list),otherRow=row+direction
    if(row<0 || otherRow<0 || otherRow>=ItemsInList(list))
        return 0
    endif
    otherPath=project+":Measurements:"+StringFromList(otherRow,list)
    NVAR currentOrder=$(path+":stackOrder"),otherOrder=$(otherPath+":stackOrder")
    Variable temp=currentOrder
    currentOrder=otherOrder
    otherOrder=temp
    return 1
End

Function/S XRD_Store(xx,yy,source)
    Wave xx,yy
    String source
    String project=XRD_Project(),path
    Variable i=1
    do
        path=project+":Measurements:Data"+num2istr(i)
        i+=1
    while(DataFolderExists(path))
    NewDataFolder $path
    NewDataFolder $(path+":Raw")
    NewDataFolder $(path+":Processed")
    NewDataFolder $(path+":Peaks")
    NewDataFolder $(path+":Assignments")
    NewDataFolder $(path+":Candidates")
    NewDataFolder $(path+":Preview")
    Duplicate xx,$(path+":Raw:twoTheta")
    Duplicate yy,$(path+":Raw:intensity")
    Duplicate yy,$(path+":Processed:intensity")
    Make/D/N=0 $(path+":Peaks:angle"),$(path+":Peaks:height"),$(path+":Peaks:pointIndex"),$(path+":Peaks:peakID")
    Make/T/N=0 $(path+":Peaks:origin"),$(path+":Peaks:assignmentSummary")
    Make/T/N=(0,6) $(path+":Peaks:table")
    Make/D/N=0 $(path+":Assignments:peakID"),$(path+":Assignments:refIndex"),$(path+":Assignments:refPeakIndex"),$(path+":Assignments:shift")
    Make/T/N=0 $(path+":Assignments:mode"),$(path+":Assignments:created")
    Make/T/N=(0,6) $(path+":Assignments:table")
    XRD_ResetCandidates(path)
    Make/D/N=0 $(path+":Preview:angle"),$(path+":Preview:height")
    String/G $(path+":source")=source
    String/G $(path+":displayName")=ParseFilePath(0,source,":",1,0)
    String/G $(path+":status")="未着手"
    String/G $(path+":angleUnit")="degree (2theta)"
    String/G $(path+":intensityUnit")="a.u. (source units; no normalization)"
    String/G $(path+":algorithm")="local-max-plateau-v1; strongest-first spacing; no smoothing"
    Variable/G $(path+":threshold")=5
    Variable/G $(path+":minDistance")=0.15
    Variable/G $(path+":lastThreshold")=NaN
    Variable/G $(path+":lastMinDistance")=NaN
    Variable/G $(path+":manualAngle")=xx[0]
    Variable/G $(path+":nextPeakID")=1
    Variable/G $(path+":selectedPeakRow")=-1
    Variable/G $(path+":selectedCandidateRow")=-1
    Variable/G $(path+":normalization")=1
    Variable/G $(path+":stackOrder")=i-2
    Variable/G $(path+":visibleInStack")=1
    SVAR active=$(project+":activeData")
    active=path
    XRD_V50Measurement(path)
    XRD_EnsureIdentity(project,path)
    XRD_NormalizeMeasurement(path)
    XRD_PeakTable(path)
    return path
End

Function XRD_EnsureMeasurement(path)
    String path
    if(strlen(path)==0 || !DataFolderExists(path))
        return -1
    endif
    NewDataFolder/O $(path+":Assignments")
    NewDataFolder/O $(path+":Candidates")
    NewDataFolder/O $(path+":Preview")
    Wave px=$(path+":Peaks:angle")
    Wave/T/Z summary=$(path+":Peaks:assignmentSummary")
    if(!WaveExists(summary))
        Make/T/N=(numpnts(px)) $(path+":Peaks:assignmentSummary")
    endif
    Wave/Z ids=$(path+":Peaks:peakID")
    if(!WaveExists(ids))
        Make/D/N=(numpnts(px)) $(path+":Peaks:peakID")
        Wave newIDs=$(path+":Peaks:peakID")
        newIDs=p+1
    endif
    XRD_EnsureAssignmentWaves(path)
    XRD_ResetCandidatesIfMissing(path)
    Wave/Z previewX=$(path+":Preview:angle")
    if(!WaveExists(previewX))
        Make/D/N=0 $(path+":Preview:angle"),$(path+":Preview:height")
    endif
    SVAR/Z displayName=$(path+":displayName")
    if(!SVAR_Exists(displayName))
        SVAR source=$(path+":source")
        String/G $(path+":displayName")=ParseFilePath(0,source,":",1,0)
    endif
    SVAR/Z status=$(path+":status")
    if(!SVAR_Exists(status))
        String/G $(path+":status")="未着手"
    endif
    XRD_EnsureNumeric(path+":nextPeakID",numpnts(px)+1)
    XRD_EnsureNumeric(path+":selectedPeakRow",-1)
    XRD_EnsureNumeric(path+":selectedCandidateRow",-1)
    XRD_EnsureNumeric(path+":normalization",1)
    XRD_EnsureNumeric(path+":stackOrder",0)
    XRD_EnsureNumeric(path+":visibleInStack",1)
    XRD_EnsureIdentity(XRD80_ProjectForMeasurement(path),path)
    XRD_V50Measurement(path)
    XRD_NormalizeMeasurement(path)
    XRD_PeakTable(path)
    return 0
End

Function XRD_EnsureAssignmentWaves(path)
    String path
    Wave/Z ids=$(path+":Assignments:peakID")
    if(!WaveExists(ids))
        Make/D/N=0 $(path+":Assignments:peakID"),$(path+":Assignments:refIndex"),$(path+":Assignments:refPeakIndex"),$(path+":Assignments:shift")
        Make/T/N=0 $(path+":Assignments:mode"),$(path+":Assignments:created")
        Make/T/N=(0,6) $(path+":Assignments:table")
    endif
End

Function XRD_ResetCandidatesIfMissing(path)
    String path
    Wave/Z refs=$(path+":Candidates:refIndex")
    if(!WaveExists(refs))
        XRD_ResetCandidates(path)
    else
        Wave/T table=$(path+":Candidates:table")
        if(DimSize(table,1)!=11)
            XRD_ResetCandidates(path)
        endif
    endif
End

Function XRD_ResetCandidates(path)
    String path
    NewDataFolder/O $(path+":Candidates")
    Make/O/D/N=0 $(path+":Candidates:refIndex"),$(path+":Candidates:refPeakIndex"),$(path+":Candidates:shift"),$(path+":Candidates:localScore"),$(path+":Candidates:globalScore"),$(path+":Candidates:newScore"),$(path+":Candidates:intensityScore"),$(path+":Candidates:missingStrong"),$(path+":Candidates:totalScore"),$(path+":Candidates:compatible")
    Make/O/T/N=(0,11) $(path+":Candidates:table")
    Wave/T table=$(path+":Candidates:table")
    SetDimLabel 1,0,Phase,table
    SetDimLabel 1,1,'参照2θ・hkl',table
    SetDimLabel 1,2,'Δ2θ (deg)',table
    SetDimLabel 1,3,'採用前の確認',table
    SetDimLabel 1,4,'候補点',table
    SetDimLabel 1,5,'全体一致点',table
    SetDimLabel 1,6,Local,table
    SetDimLabel 1,7,Shift,table
    SetDimLabel 1,8,Name,table
    SetDimLabel 1,9,NewEvidence,table
    SetDimLabel 1,10,Missing,table
End
