#pragma rtGlobals=3

Function XRD143_CopySample(path,folder)
    String path,folder
    Duplicate/O $(path+":Raw:twoTheta"),$(folder+":tt")
    Duplicate/O $(path+":Processed:intensity"),$(folder+":intensity")
    Duplicate/O $(path+":Peaks:angle"),$(folder+":peakAngle")
    Duplicate/O $(path+":Peaks:height"),$(folder+":peakHeight")
    Duplicate/O $(path+":Peaks:peakID"),$(folder+":peakID")
    Duplicate/O $(path+":Assignments:peakID"),$(folder+":assignmentID")
    Duplicate/O $(path+":Assignments:refIndex"),$(folder+":refIndex")
    Wave/Z reflections=$(path+":Assignments:refPeakIndex"),shifts=$(path+":Assignments:shift")
    if(WaveExists(reflections))
        Duplicate/O reflections,$(folder+":refPeakIndex")
    endif
    if(WaveExists(shifts))
        Duplicate/O shifts,$(folder+":referenceShift")
    endif
    Variable/G $(folder+":analysisRevision")=NumVarOrDefault(path+":analysisRevision",0)
    Variable/G $(folder+":wavelength")=NumVarOrDefault(path+":measurementWavelength",1.5406)
    Variable/G $(folder+":zeroCorrection")=NumVarOrDefault(path+":zeroCorrection",0)
    Wave assignmentIDs=$(path+":Assignments:peakID"),referenceIDs=$(path+":Assignments:refIndex"),peakAngles=$(path+":Peaks:angle")
    String/G $(folder+":sourceRevision")=num2str(WaveCRC(0,assignmentIDs))+":"+num2str(WaveCRC(0,referenceIDs))+":"+num2str(WaveCRC(0,peakAngles))
    Make/O/T/N=(numpnts(referenceIDs)) $(folder+":phaseLabels"),$(folder+":phaseKeys"),$(folder+":referenceUIDs"),$(folder+":referenceRevisionUIDs"),$(folder+":reflectionUIDs")
    Wave/T phaseLabels=$(folder+":phaseLabels"),phaseKeys=$(folder+":phaseKeys"),referenceUIDs=$(folder+":referenceUIDs"),revisions=$(folder+":referenceRevisionUIDs"),reflectionIDs=$(folder+":reflectionUIDs")
    Variable j
    for(j=0;j<numpnts(referenceIDs);j+=1)
        if(referenceIDs[j]>0)
            phaseLabels[j]=XRD_PhaseLabel(referenceIDs[j])
            phaseKeys[j]=StrVarOrDefault(XRD_ReferencePath(referenceIDs[j])+":styleGroup",phaseLabels[j])
            referenceUIDs[j]=StrVarOrDefault(XRD_ReferencePath(referenceIDs[j])+":refUID","")
            revisions[j]=StrVarOrDefault(XRD_ReferencePath(referenceIDs[j])+":revisionUID","")
            Wave/T/Z reflectionMap=$(XRD_ReferencePath(referenceIDs[j])+":reflectionUID")
            if(WaveExists(reflectionMap) && WaveExists(reflections))
                if(reflections[j]>=0 && reflections[j]<numpnts(reflectionMap))
                    reflectionIDs[j]=reflectionMap[reflections[j]]
                endif
            endif
        endif
    endfor
    return 0
End

Function XRD143_PlotAlpha(recipe)
    String recipe
    if(NumVarOrDefault(recipe+":offsetMode",1))
        return 65535
    endif
    return round(65535*NumVarOrDefault(recipe+":opacity143",40)/100)
End

Function/S XRD143_PhaseTrace(win,traces,folder,index)
    String win,traces,folder
    Variable index
    String trace
    Variable i
    for(i=0;i<ItemsInList(traces);i+=1)
        trace=StringFromList(i,traces)
        if(cmpstr(GetUserData(win,"","XRDPhaseSnapshot129_"+trace),folder)==0 && str2num(GetUserData(win,"","Ref_"+trace))==index)
            return trace
        endif
    endfor
    return ""
End

Function XRD143_SyncSample(recipe,win,index,traces)
    String recipe,win,traces
    Variable index
    Wave/T uids=$(recipe+":sourceUIDs")
    String path=XRD80_ResolveMeasurement(uids[index]),folder=recipe+":Snapshot:Sample"+num2istr(index+1)
    String owner=XRD80_ProjectForMeasurement(path)
    if(!strlen(path) || !strlen(owner) || NumVarOrDefault(path+":deleted",0) || NumVarOrDefault(owner+":projectDeleted100",0))
        return -1
    endif
    XRD143_CopySample(path,folder)
    Variable n=numpnts(uids),spacing=NumVarOrDefault(recipe+":spacing",135)*NumVarOrDefault(recipe+":offsetMode",1)
    String order=StrVarOrDefault(recipe+":visualOrder81",""),trace
    Variable rank=index,i
    if(ItemsInList(order)==n)
        rank=WhichListItem(num2istr(index),order)
    endif
    Variable offset=(n-1-rank)*spacing
    Wave intensity=$(folder+":intensity")
    Wave/Z displayY=$(folder+":displayIntensity")
    if(WaveExists(displayY))
        Redimension/N=(numpnts(intensity)) displayY
        displayY=intensity[p]+offset
    endif
    Wave refs=$(folder+":refIndex")
    for(i=ItemsInList(traces)-1;i>=0;i-=1)
        trace=StringFromList(i,traces)
        if(cmpstr(GetUserData(win,"","XRDPhaseSnapshot129_"+trace),folder)!=0)
            continue
        endif
        FindValue/V=(str2num(GetUserData(win,"","Ref_"+trace))) refs
        if(V_value<0)
            RemoveFromGraph/W=$win/Z $trace
        endif
    endfor
    XRD_PlotSnapshotPhases(win,recipe,index,offset)
    return 0
End

Function XRD143_SyncRecipe(recipe,indices)
    String recipe,indices
    if(!strlen(recipe) || !DataFolderExists(recipe))
        return -1
    endif
    Wave/T/Z sources=$(recipe+":sourceUIDs")
    String win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    if(!WaveExists(sources) || !WinType(win) || strsearch(recipe,XRD_PlotRoot()+":Plots:",0)!=0)
        return -1
    endif
    PauseUpdate; Silent 1
    String traces=TraceNameList(win,";",1)
    Variable i,missing=0,managed=XRD_IsManagedLegend(win)
    for(i=0;i<numpnts(sources);i+=1)
        if(!strlen(indices) || WhichListItem(num2istr(i),indices)>=0)
            missing+=XRD143_SyncSample(recipe,win,i,traces)<0
        else
            String path=XRD80_ResolveMeasurement(sources[i]),owner=XRD80_ProjectForMeasurement(path)
            missing+=!strlen(owner) || NumVarOrDefault(path+":deleted",0) || NumVarOrDefault(owner+":projectDeleted100",0)
        endif
    endfor
    Variable/G $(recipe+":stale")=(missing>0)
    String/G $(recipe+":syncPending143")=""
    if(missing)
        TextBox/W=$win/C/N=XRDNeedsUpdate/F=0/B=1/A=LT "\\Z12元データが見つからない試料は前回の内容を表示"
    elseif(WhichListItem("XRDNeedsUpdate",AnnotationList(win))>=0)
        TextBox/W=$win/K/N=XRDNeedsUpdate
    endif
    if(managed)
        XRD_PlotLegend(win)
    endif
    XRD_PlotCaptureNative(recipe)
    return missing
End

Function XRD143_SyncOnOpen(recipe)
    String recipe
    if(NumVarOrDefault(recipe+":autoSync143",0) && NumVarOrDefault(recipe+":stale",0))
        return XRD143_SyncRecipe(recipe,"")
    endif
    return 0
End

Function XRD143_QueueSync(recipe,index)
    String recipe
    Variable index
    String base=XRD_PlotRoot(),pending=StrVarOrDefault(recipe+":syncPending143",""),item=num2istr(index)
    if(WhichListItem(item,pending)<0)
        String/G $(recipe+":syncPending143")=pending+item+";"
    endif
    if(!NumVarOrDefault(base+":syncQueued143",0))
        Variable/G $(base+":syncQueued143")=1
        Execute/P/Q "XRD143_RefreshPendingPlots()"
    endif
    return 0
End

Function XRD143_RefreshPendingPlots()
    String base=XRD_PlotRoot(),wins=WinList("XRDP_*",";","WIN:1"),win,recipe,pending
    Variable i
    Variable/G $(base+":syncQueued143")=0
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        recipe=GetUserData(win,"","XRDPlotRecipe")
        pending=StrVarOrDefault(recipe+":syncPending143","")
        if(strlen(pending) && NumVarOrDefault(recipe+":autoSync143",0))
            XRD143_SyncRecipe(recipe,pending)
        endif
    endfor
    return 0
End

Function XRD143_SyncUI(recipe,action)
    String recipe
    Variable action
    if(!strlen(recipe) || strsearch(recipe,XRD_PlotRoot()+":Plots:",0)!=0 || !DataFolderExists(recipe))
        XRD124_Alert(0,"作図ウィンドウで作成したXRD図を開いてください。")
        return -1
    endif
    if(action==2)
        Variable mode=1+NumVarOrDefault(recipe+":autoSync143",0)
        Prompt mode,"元の測定・同定結果",popup,"手動で同期;変更時に自動で同期"
        DoPrompt "保存図のデータ同期",mode
        if(V_flag)
            return 0
        endif
        Variable/G $(recipe+":autoSync143")=(mode==2)
        if(mode==1)
            String/G $(recipe+":syncPending143")=""
            return 0
        endif
    endif
    return XRD143_SyncRecipe(recipe,"")
End
