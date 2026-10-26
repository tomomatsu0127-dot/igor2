#pragma rtGlobals=3
#include ":xrd_v80_tests"

Function XRD_RunV81Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    XRD_RecoverySettings()
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:enabled",0)==1,"v081 autosave starts ON")
    Variable/G root:Packages:XRDWorkbench:Recovery:enabled=0
    XRD_RecoverySettings()
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:enabled",1)==0,"v081 explicitly disabled autosave stays OFF")
    CtrlNamedBackground XRDAutoSave,stop
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_LoadReferenceFile("QS-A.txt",1)
    XRD_LoadReferenceFile("Y-A.txt",2)
    Make/FREE/D/N=1001 xx=20+p*0.05,yy=2+100*exp(-((xx[p]-30.1)/0.1)^2)+60*exp(-((xx[p]-44)/0.15)^2)
    String project=XRD_Project(),path=XRD_Store(xx,yy,"x=0.xy")
    XRD80_RenameProject(project,"project1")
    XRD80_RenameMeasurement(path,"x=0")
    XRD81_CreateNamedWaves(path)
    String stem=StrVarOrDefault(path+":namedWaveStem81","")
    XRD_TestCheck(strsearch(stem,"project1",0)>=0 && WaveExists($(path+":Waves:"+PossiblyQuoteName("tt_"+stem))),"v081 readable sample-project wave alias exists")
    XRD_TestCheck(strlen(stem)<=27 && strlen(XRD81_NamePrefix("日本語",8))==6,"v081 wave aliases respect byte limit without cutting Japanese characters")
    XRD_Manual(path,30.1)
    XRD_Manual(path,44)
    Variable/G $(project+":activeStep")=1
    XRD_TestDisableFollow()
    XRD_Panel()
    String instance=GetUserData("XRDWorkbench","","XRDInstance")
    SetAxis/W=XRDWorkbench#Pattern bottom 29,32
    XRD81_SetPickMode(1)
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 220
    XRD_TestCheck(XRD81_AddCursorPoint()==220,"v081 add button registers exact native cursor point")
    Wave points=$(path+":Peaks:pointIndex")
    FindValue/V=220 points
    XRD_TestCheck(V_value>=0 && NumVarOrDefault(path+":pickMode81",1)==0,"v081 addition returns to registered-peak selection")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==29 && V_max==32 && cmpstr(instance,GetUserData("XRDWorkbench","","XRDInstance"))==0,"v081 adding preserves zoom and panel instance")
    XRD81_SelectPeak(path,1)
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==1 && cmpstr(StringByKey("TNAME",CsrInfo(A,"XRDWorkbench#Pattern")),"XRDWB_Select")==0,"v081 selecting marker attaches native cursor to peak-only trace")
    STRUCT WMWinHookStruct hook
    hook.winName="XRDWorkbench#Pattern";hook.cursorName="A";hook.traceName="XRDWB_Measured";hook.eventCode=7;hook.pointNumber=400
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 400
    XRD81_PointHook(hook)
    XRD_TestCheck(cmpstr(StringByKey("TNAME",CsrInfo(A,"XRDWorkbench#Pattern")),"XRDWB_Select")==0,"v081 native cursor event rejects a nonpeak measurement point")
    XRD81_SelectPeak(path,0)
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"step1.png"
    Variable/G $(project+":activeStep")=3
    XRD_Panel()
    XRD81_SelectPeak(path,0)
    XRD_ScoreCandidates(path,0)
    Wave refs=$(path+":Candidates:refIndex"),rows=$(path+":Candidates:refPeakIndex")
    Variable i,candidate=-1
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==1 && rows[i]==0)
            candidate=i
        endif
    endfor
    Variable/G $(path+":selectedCandidateRow")=candidate
    instance=GetUserData("XRDWorkbench","","XRDInstance")
    SetAxis/W=XRDWorkbench#Pattern bottom 29,46
    GetWindow XRDWorkbench wsize
    Variable width=V_right-V_left,height=V_bottom-V_top
    XRD_TestCheck(XRD_ApplySelectedCandidate(path,0)==0,"v081 native adoption succeeds")
    GetWindow XRDWorkbench wsize
    XRD_TestCheck(cmpstr(instance,GetUserData("XRDWorkbench","","XRDInstance"))==0 && abs(width-(V_right-V_left))<1 && abs(height-(V_bottom-V_top))<1,"v081 adoption does not recreate or resize panel")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==29 && V_max==46,"v081 adoption retains expanded view")
    XRD_TestCheck(NumVarOrDefault(path+":selectedPeakRow",-1)==1,"v081 adoption advances to next peak")
    XRD_LiveDeferred()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"step3.png"
    XRD81_SelectPeak(path,1)
    Wave ids=$(path+":Peaks:peakID")
    Variable removed=ids[1],count=numpnts(ids)
    STRUCT WMButtonAction button
    button.eventCode=2;button.ctrlName="deletePeak2"
    XRD_Button(button)
    FindValue/V=(removed) ids
    XRD_TestCheck(numpnts(ids)==count-1 && V_value<0,"v081 delete button removes precisely selected peak")
    for(i=0;i<numpnts(ids);i+=1)
        XRD_SetUnknown(path,i)
    endfor
    Variable/G $(project+":activeStep")=5
    XRD_Panel()
    DoUpdate
    String controls=ControlNameList("XRDWorkbench",";"),name,recreation=WinRecreation("XRDWorkbench",0)
    Variable clean=1
    for(i=0;i<ItemsInList(controls);i+=1)
        name=StringFromList(i,controls)
        ControlInfo/W=XRDWorkbench $name
        if(V_flag==1 && strsearch(S_recreation,"title=\"New\"",0)>=0)
            clean=0
        endif
    endfor
    XRD_TestCheck(clean,"v081 Step 5 has no accidentally-created New buttons")
    XRD_TestCheck(XRD81_TestButtonOverlap()==0,"v081 Step 5 visible buttons do not overlap at default size")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"step5.png"
    MoveWindow/W=XRDWorkbench 10,40,1410,870
    XRD_ResizeDeferred()
    XRD_TestCheck(XRD81_TestButtonOverlap()==0,"v081 Step 5 visible buttons do not overlap when enlarged")
    XRD80_ProjectManager()
    instance=GetUserData("XRDWorkbench","","XRDInstance")
    XRD80_OpenManagerSelection(0)
    XRD_TestCheck(cmpstr(instance,GetUserData("XRDWorkbench","","XRDInstance"))==0,"v081 reopening same project brings existing panel forward")
    XRD_NewProject()
    XRD80_RenameProject(XRD_Project(),"project2")
    String second=XRD_Store(xx,yy,"x=0.xy")
    XRD80_RenameMeasurement(second,"x=0")
    XRD81_CreateNamedWaves(second)
    XRD_TestCheck(cmpstr(stem,StrVarOrDefault(second+":namedWaveStem81",""))!=0,"v081 equal sample labels in different projects have distinct wave stems")
    XRD_Manual(second,44)
    XRD80_TestAdopt(second,0,2,2)
    SVAR active=root:Packages:XRDWorkbench:activeProject
    active=project
    XRD_Open()
    XRD_PlotWorkspace()
    XRD81_PlotSources()
    XRD_TestCheck(WinType("XRDPlotSources")==7,"v081 project-folder measurement chooser opens")
    DoWindow/K XRDPlotSources
    XRD_PlotQuickCreate(path+";"+second+";","live test")
    String recipe=XRD_PlotRoot()+":Plots:Plot1",win="XRDP_plot1",ui=XRD_PlotRoot()+":UI"
    Wave original=$(recipe+":Snapshot:Sample1:intensity")
    Variable crc=WaveCRC(0,original)
    Variable/G $(ui+":font")=28
    Variable/G $(ui+":legendFont")=26
    Variable/G $(ui+":xMin")=25
    Variable/G $(ui+":xMax")=65
    XRD81_ApplyPlotLive(recipe)
    GetAxis/W=$win/Q bottom
    XRD_TestCheck(V_min==25 && V_max==65,"v081 figure settings update live")
    XRD_TestCheck(WaveCRC(0,original)==crc,"v081 live figure settings preserve frozen scientific snapshot")
    STRUCT WMListboxAction drag
    drag.win="XRDPlotWorkspace";drag.ctrlName="samples";drag.col=1;drag.row=0;drag.eventCode=1
    XRD_PlotSample(drag)
    drag.row=1;drag.eventCode=4
    XRD_PlotSample(drag)
    drag.eventCode=2
    XRD_PlotSample(drag)
    XRD81_ApplyPlotLive(recipe)
    Wave upperY=$(recipe+":Snapshot:Sample2:displayIntensity"),lowerY=$(recipe+":Snapshot:Sample1:displayIntensity")
    XRD_TestCheck(upperY[0]>lowerY[0],"v081 dragging sample row changes top-to-bottom graph order")
    XRD_PlotLoadRecipe(recipe)
    Wave/T sourcePaths=$(ui+":paths")
    XRD_TestCheck(cmpstr(sourcePaths[0],second)==0,"v081 saved figure reload retains drag order")
    XRD_StylePanel()
    Variable row=XRD_StyleIndex(2)
    XRD81_SetMarkerSize(row,6)
    XRD_RefreshStyles()
    XRD_TestCheck(XRD81_MarkerSize(row)==6,"v081 shared marker size is saved")
    XRD_TestCheck(strsearch(WinRecreation(win,0),"msize(MS2R2)=6",0)>=0,"v081 shared marker size reaches finished figure")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDStyles as output+"styles.png"
    DeleteFile/Z output+"export.png"
    XRD81_ExportGraph(win,output+"export.png")
    GetFileFolderInfo/Q/Z output+"export.png"
    XRD_TestCheck(!V_flag && V_logEOF>1000,"v081 graph exports PNG")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDPlotWorkspace as output+"plot_workspace.png"
    SaveExperiment/C/F={1,"",0} as output+"roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "v081 failures="+num2istr(failures)
    return failures
End

Function XRD_RunV81EdgeTests()
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    Make/FREE/D/N=1001 xx=20+p*0.05,yy=2+100*exp(-((xx[p]-30)/0.1)^2)
    String path=XRD_Store(xx,yy,"delete-last.xy"),project=XRD_Project()
    XRD_Manual(path,30)
    Variable/G $(project+":activeStep")=3
    XRD_Panel()
    Variable/G $(path+":selectedPeakRow")=0
    STRUCT WMButtonAction ba
    ba.eventCode=2;ba.ctrlName="deletePeak2"
    XRD_Button(ba)
    Wave angles=$(path+":Peaks:angle")
    XRD_TestCheck(numpnts(angles)==0 && strlen(CsrInfo(A,"XRDWorkbench#Pattern"))==0,"v081 deleting last peak clears cursor without selecting raw trace")
    XRD81_SetPickMode(1)
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 205
    XRD_TestCheck(XRD81_AddCursorPoint()==205 && numpnts(angles)==1,"v081 add mode can register a peak after all peaks were removed")
    XRD_TestCheck(GetRTError(1)==0,"v081 empty candidate and peak operations leave no runtime error")
    NVAR failures=root:XRDTestFailures
    Print "v081 edge failures="+num2istr(failures)
    return failures
End

Function XRD81_TestButtonOverlap()
    String controls=ControlNameList("XRDWorkbench",";"),a,b
    Variable i,j,left,top,right,bottom,overlaps=0
    for(i=0;i<ItemsInList(controls);i+=1)
        a=StringFromList(i,controls)
        ControlInfo/W=XRDWorkbench $a
        if(V_flag!=1 || V_disable!=0)
            continue
        endif
        left=V_left;top=V_top;right=left+V_width;bottom=top+V_height
        for(j=i+1;j<ItemsInList(controls);j+=1)
            b=StringFromList(j,controls)
            ControlInfo/W=XRDWorkbench $b
            if(V_flag==1 && V_disable==0 && min(right,V_left+V_width)-max(left,V_left)>1 && min(bottom,V_top+V_height)-max(top,V_top)>1)
                overlaps+=1
                Print "overlap "+a+" / "+b
            endif
        endfor
    endfor
    return overlaps
End

Function XRD_VerifyV81Restored()
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_TestCheck(ItemsInList(XRD_ProjectList())==2,"v081 projects survive actual Experiment reopen")
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:policy81",0)==1 && NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:enabled",1)==0,"v081 explicit autosave OFF survives actual reopen")
    XRD_TestCheck(XRD81_MarkerSize(XRD_StyleIndex(2))==6,"v081 marker size survives actual Experiment reopen")
    String recipe=XRD_PlotRoot()+":Plots:Plot1"
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,1)==0,"v081 finished graph reopens with saved native style")
    Wave topY=$(recipe+":Snapshot:Sample2:displayIntensity"),bottomY=$(recipe+":Snapshot:Sample1:displayIntensity")
    XRD_TestCheck(topY[0]>bottomY[0],"v081 visual sample order survives actual reopen")
    XRD_PlotWorkspace()
    XRD_TestCheck(NumVarOrDefault(XRD_PlotRoot()+":UI:livePending81",1)==0,"v081 opening persisted plot editor clears stale queue guard")
    NVAR failures=root:XRDTestFailures
    Print "v081 persisted failures="+num2istr(failures)
    return failures
End

Function XRD_V81TimerStart(output)
    String output
    Variable/G root:XRDTestFailures=0
    Variable/G root:XRDTimerHistory=CaptureHistoryStart()
    String/G root:XRDTimerOutput=output
    XRD_Init()
    Make/FREE/D/N=200001 xx=10+p*0.0004,yy=1+100*exp(-((xx[p]-30)/0.06)^2)
    String path=XRD_Store(xx,yy,"timer-stress.xy")
    XRD_Manual(path,30)
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 29,31
    XRD_RecoverySettings()
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:enabled",0)==1,"v081 actual timer uses default ON")
    Wave raw=$(path+":Raw:intensity")
    Variable/G root:XRDTimerCRC=WaveCRC(0,raw)
    Variable/G root:XRDTimerDeadline=ticks+1800
    NewPath/O/Q XRDAutoSaveCustomPath,output
    XRD_StartAutoSave()
    CtrlNamedBackground XRDAutoSave,period=60,start=(ticks+60)
    CtrlNamedBackground XRDTimerVerifier,proc=XRD_V81TimerVerify,period=60,start=(ticks+60)
End

Function XRD_V81TimerVerify(s)
    STRUCT WMBackgroundStruct &s
    NVAR generation=root:Packages:XRDWorkbench:Recovery:generation,deadline=root:XRDTimerDeadline
    if(generation<3 && ticks<deadline)
        return 0
    endif
    Variable/G root:Packages:XRDWorkbench:Recovery:enabled=0
    XRD_StartAutoSave()
    XRD_TestCheck(generation>=3,"v081 actual queued background timer creates three recovery generations")
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:busy",1)==0 && NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:queued",1)==0,"v081 timed recovery releases busy and queue guards")
    Wave raw=$(XRD_Data()+":Raw:intensity")
    NVAR crc=root:XRDTimerCRC
    XRD_TestCheck(WaveCRC(0,raw)==crc,"v081 timed saves preserve 200001 raw points")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==29 && V_max==31,"v081 timed recovery preserves expanded graph")
    NVAR history=root:XRDTimerHistory,failures=root:XRDTestFailures
    SVAR output=root:XRDTimerOutput
    Print "v081 timer failures="+num2istr(failures)
    String log=CaptureHistory(history,1)
    Variable ref
    Open ref as output+"timed_result.txt"
    fprintf ref,"%s",log
    Close ref
    Execute/P "Quit/N"
    return 1
End
