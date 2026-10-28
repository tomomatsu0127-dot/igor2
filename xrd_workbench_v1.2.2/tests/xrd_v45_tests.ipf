#pragma rtGlobals=3
// v0.4.5 recovery and undo tests, isolated experiment only.
Function XRD_RunV45Tests(fixturesPath,outputPath)
    String fixturesPath,outputPath
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_NewProject()
    NewPath/O/Q XRDReferencePath,fixturesPath
    XRD_LoadReferences()
    XRD_ImportFile(fixturesPath+"measurement.xy")
    String path=XRD_Data(),project=XRD_Project()
    XRD_DetectLegacy(path)
    XRD_UndoSettings(project)
    NVAR count=$(project+":Undo:count"),sequence=$(project+":Undo:sequence")
    count=0;sequence=0
    Wave xx=$(path+":Raw:twoTheta"),raw=$(path+":Raw:intensity"),ids=$(path+":Peaks:peakID"),angle=$(path+":Peaks:angle"),refs=$(path+":Assignments:refIndex")
    Duplicate/FREE raw,original
    Variable n=numpnts(ids),id0=ids[0]
    NVAR selected=$(path+":selectedPeakRow"),nextID=$(path+":nextPeakID")
    selected=0
    XRD_TestDisableFollow()
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 30,35
    // Establish the view baseline for this analysis-only regression. Mixed zoom
    // chronology is tested separately in xrd_v51_tests.ipf.
    XRD_ViewSync(path)
    XRD81_SetPickMode(1)
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 2
    Variable previousNext=nextID
    XRD_Manual(path,32)
    XRD_TestCheck(numpnts(ids)==n+1 && count==1,"manual peak creates one undo step")
    XRD_TestCheck(XRD_Undo()==1 && numpnts(ids)==n,"undo restores live peak waves used by UI")
    XRD_TestCheck(nextID==previousNext && ids[0]==id0,"undo restores stable peak identifiers")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==30 && V_max==35 && pcsr(A,"XRDWorkbench#Pattern")==2,"undo preserves zoom and standard cursor")
    XRD_Manual(path,31)
    XRD_TestCheck(count==0,"duplicate manual peak does not consume undo history")
    XRD_Manual(path,999)
    XRD_Delete(path,-1)
    XRD_TestCheck(count==0,"invalid changes do not consume undo history")
    XRD_ScoreCandidates(path,0)
    XRD_AssignCandidate(path,0,0,0)
    Variable primary=refs[0]
    XRD_TestCheck(numpnts(refs)==1 && count==1,"candidate assignment recorded")
    XRD_Undo()
    XRD_TestCheck(numpnts(refs)==0,"undo candidate assignment")
    XRD_ScoreCandidates(path,0)
    XRD_AssignCandidate(path,0,0,0)
    XRD_SetUnknown(path,0)
    XRD_Undo()
    XRD_TestCheck(numpnts(refs)==1 && refs[0]==primary,"undo Unknown restores assigned phase")
    XRD_ScoreCandidates(path,0)
    XRD_AssignCandidate(path,0,1,1)
    XRD_Undo()
    XRD_TestCheck(numpnts(refs)==1 && refs[0]==primary,"undo overlap retains primary assignment")
    XRD_ClearPeakReview(path,0)
    XRD_Undo()
    XRD_TestCheck(numpnts(refs)==1 && refs[0]==primary,"undo review clearing")
    XRD_Delete(path,0)
    XRD_Undo()
    XRD_TestCheck(numpnts(ids)==n && ids[0]==id0 && refs[0]==primary,"undo peak deletion restores assignment and peak")
    XRD_Manual(path,32)
    XRD_DetectLegacy(path)
    XRD_Undo()
    XRD_TestCheck(numpnts(ids)==n+1,"undo detection preserves previous manual peaks")
    XRD_Undo()
    XRD_TestCheck(numpnts(ids)==n,"undo previous manual insertion")
    XRD_SetUnknown(path,1)
    XRD_SetMeasurementComplete(path)
    XRD_Undo()
    XRD_TestCheck(cmpstr(StrVarOrDefault(path+":status",""),"同定中")==0,"undo completion returns to identification")
    XRD_DeleteMeasurement(path)
    XRD_Undo()
    XRD_TestCheck(!NumVarOrDefault(path+":deleted",0) && cmpstr(XRD_Data(),path)==0,"undo measurement deletion restores active measurement")
    XRD_DeleteMeasurement(path)
    XRD_RestoreMeasurement(path)
    XRD_Undo()
    XRD_TestCheck(NumVarOrDefault(path+":deleted",0)==1 && strlen(XRD_Data())==0,"undo restore returns measurement to deleted state")
    XRD_Undo()
    XRD_ImportFile(fixturesPath+"measurement.xy")
    String second=XRD_Data()
    XRD_DetectLegacy(second)
    XRD_Undo()
    Wave secondPeaks=$(second+":Peaks:angle")
    XRD_TestCheck(numpnts(secondPeaks)==0 && numpnts(ids)==n,"undo does not mix measurements")
    XRD_NewProject()
    XRD_TestCheck(XRD_Undo()==0,"new project cannot undo another project's actions")
    SVAR active=root:Packages:XRDWorkbench:activeProject
    active=project
    SVAR measurement=$(project+":activeData")
    measurement=path
    count=0;sequence=0
    Variable i
    for(i=0;i<23;i+=1)
        XRD_SetUnknown(path,0)
    endfor
    XRD_TestCheck(count==20,"undo history capped at twenty actions")
    for(i=0;i<20;i+=1)
        XRD_Undo()
    endfor
    XRD_TestCheck(count==0 && XRD_Undo()==0,"twenty undo steps then clean empty history")
    XRD_TestCheck(EqualWaves(raw,original,1)==1,"undo never changes raw intensity")
    XRD_RecordUndo(path,"keyboard test")
    XRD_TestDisableFollow()
    XRD_Panel()
    STRUCT WMWinHookStruct hook
    hook.winName="XRDWorkbench#Pattern";hook.eventCode=26;hook.eventMod=8;hook.keycode=122
    XRD_TestCheck(XRD_UndoHook(hook)==1,"Ctrl+Z accepted in workbench graph")
    hook.keycode=105
    XRD_TestCheck(XRD_UndoHook(hook)==0,"Ctrl+I left to native Igor")
    hook.winName="OtherGraph";hook.keycode=122
    XRD_TestCheck(XRD_UndoHook(hook)==0,"Ctrl+Z outside workbench left to Igor")
    hook.winName="XRDWorkbench";hook.focusCtrl="manualAngle"
    NVAR step=$(project+":activeStep")
    step=1
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_TestCheck(XRD_UndoHook(hook)==0,"text field keeps native undo")
    XRD_Undo()
    XRD_RecoverySettings()
    XRD_TestCheck(WhichListItem("Recovery",XRD_ProjectList())<0 && WhichListItem("UI",XRD_ProjectList())<0 && WhichListItem(ParseFilePath(0,project,":",1,0),XRD_ProjectList())>=0,"project selector excludes UI and auto-save settings folders")
    NVAR enabled=root:Packages:XRDWorkbench:Recovery:enabled,minutes=root:Packages:XRDWorkbench:Recovery:minutes,generation=root:Packages:XRDWorkbench:Recovery:generation
    XRD_TestCheck(enabled==1 && minutes==5,"v081 autosave starts ON with five minute interval")
    enabled=1
    XRD_StartAutoSave()
    CtrlNamedBackground XRDAutoSave,status
    XRD_TestCheck(NumberByKey("RUN",S_info)==1 && NumberByKey("PERIOD",S_info)==18000,"five minute background timer started")
    Variable scheduled=NumberByKey("NEXT",S_info)
    XRD_TestDisableFollow()
    XRD_Panel()
    CtrlNamedBackground XRDAutoSave,status
    XRD_TestCheck(NumberByKey("NEXT",S_info)==scheduled,"UI refresh does not postpone auto-save")
    minutes=2
    XRD_StartAutoSave()
    CtrlNamedBackground XRDAutoSave,status
    XRD_TestCheck(NumberByKey("PERIOD",S_info)==7200,"save interval changes")
    enabled=0
    XRD_StartAutoSave()
    CtrlNamedBackground XRDAutoSave,status
    XRD_TestCheck(NumberByKey("RUN",S_info)==0,"automatic save can be disabled")
    NewPath/O/Q XRDAutoSaveCustomPath,outputPath
    String beforeName=IgorInfo(12),first,folder
    generation=0
    XRD_TestCheck(XRD_SaveRecovery()==0,"previously-unsaved experiment saved silently as recovery copy")
    SVAR savedFile=root:Packages:XRDWorkbench:Recovery:lastFile
    first=savedFile
    GetFileFolderInfo/Q/Z first
    XRD_TestCheck(V_flag==0 && V_isFile && V_logEOF>0,"recovery copy exists on disk")
    XRD_TestCheck(cmpstr(beforeName,IgorInfo(12))==0,"saving a copy retains original experiment identity")
    for(i=0;i<3;i+=1)
        XRD_SaveRecovery()
    endfor
    XRD_TestCheck(generation==4 && cmpstr(savedFile,first)==0,"fourth save safely rotates back to first slot")
    PathInfo XRDAutoSavePath
    folder=IndexedFile(XRDAutoSavePath,-1,".pxp")
    String sessionKey=StrVarOrDefault("root:Packages:XRDWorkbench:Recovery:sessionKey","")
    Variable matching=0
    for(i=0;i<ItemsInList(folder);i+=1)
        matching+=(strsearch(StringFromList(i,folder),sessionKey,0)>=0)
    endfor
    XRD_TestCheck(matching==3,"three recovery generations retained for this session")
    NVAR busy=root:Packages:XRDWorkbench:Recovery:busy
    XRD_TestCheck(busy==0,"recovery copy stores a cleared busy flag")
    String failureFolder=outputPath+"failure:"
    NewPath/O/C/Q XRDAutoSaveFailurePath,failureFolder
    Variable fileNum
    Open fileNum as failureFolder+"XRDWorkbench_Autosave"
    fprintf fileNum,"blocked folder test"
    Close fileNum
    NewPath/O/Q XRDAutoSaveCustomPath,failureFolder
    Variable beforeGeneration=generation
    String beforeFile=savedFile
    XRD_TestCheck(XRD_SaveRecovery()<0,"unwritable recovery destination reports failure without a dialog")
    XRD_TestCheck(generation==beforeGeneration && cmpstr(savedFile,beforeFile)==0 && busy==0,"save failure retains latest successful recovery and unlocks saving")
    NewPath/O/Q XRDAutoSaveCustomPath,outputPath
    XRD_SaveSettingsPanel()
    XRD_TestCheck(WinType("XRDSaveSettings")==7,"save settings panel opens")
    XRD_RecordUndo(path,"persisted undo test")
    XRD_SetUnknown(path,0)
    XRD_SaveRecovery()
    SaveExperiment as outputPath+"undo_roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.5 tests: failures="+num2istr(failures)
    return failures
End

Function XRD_V45TimedStart(outputPath)
    String outputPath
    XRD_Init()
    XRD_RecoverySettings()
    Variable/G root:XRDTestFailures=0
    Variable/G root:XRDTimerHistory=CaptureHistoryStart()
    String/G root:XRDTimerOutput=outputPath
    Variable/G root:XRDTimerDeadline=ticks+600
    NewPath/O/Q XRDAutoSaveCustomPath,outputPath
    NVAR enabled=root:Packages:XRDWorkbench:Recovery:enabled,generation=root:Packages:XRDWorkbench:Recovery:generation
    enabled=1;generation=0
    XRD_StartAutoSave()
    CtrlNamedBackground XRDAutoSave,period=12,start=(ticks+12)
    CtrlNamedBackground XRDTimerVerifier,proc=XRD_V45TimedVerify,period=60,start=(ticks+60)
End

Function XRD_V45TimedVerify(s)
    STRUCT WMBackgroundStruct &s
    NVAR generation=root:Packages:XRDWorkbench:Recovery:generation,deadline=root:XRDTimerDeadline
    if(generation<3 && ticks<deadline)
        return 0
    endif
    CtrlNamedBackground XRDAutoSave,stop
    XRD_TestCheck(generation>=3,"real background task writes recovery copies without UI actions")
    String copies=IndexedFile(XRDAutoSavePath,-1,".pxp")
    XRD_TestCheck(ItemsInList(copies)==3,"background task produces three rotating recovery files")
    NVAR busy=root:Packages:XRDWorkbench:Recovery:busy
    XRD_TestCheck(busy==0,"background save completes without reentrancy lock")
    SVAR output=root:XRDTimerOutput
    NVAR history=root:XRDTimerHistory
    String log=CaptureHistory(history,1)
    Variable refNum
    Open refNum as output+"timed_result.txt"
    fprintf refNum,"%s",log
    Close refNum
    Execute/P "Quit/N"
    return 1
End

Function XRD_UIQAPreviewV45(samplesPath,outputPath)
    String samplesPath,outputPath
    XRD_UIQAPreview(samplesPath)
    DoWindow/T kwFrame,"XRD v0.4.5 確認用"
    NVAR step=$(XRD_Project()+":activeStep")
    step=1
    XRD_TestDisableFollow()
    XRD_Panel()
    NewPath/O/Q XRDAutoSaveCustomPath,outputPath
End

Function XRD_VerifyV45Restored()
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    String project=XRD_Project()
    NVAR count=$(project+":Undo:count")
    XRD_TestCheck(count>0 && XRD_Undo()==1,"undo history usable after reopening saved data")
    NVAR enabled=root:Packages:XRDWorkbench:Recovery:enabled,minutes=root:Packages:XRDWorkbench:Recovery:minutes,busy=root:Packages:XRDWorkbench:Recovery:busy
    XRD_TestCheck(enabled==0 && minutes==2 && busy==0,"save settings restore without stuck saving state")
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.5 persistence tests: failures="+num2istr(failures)
End

Function XRD_VerifyV45WriteFailure()
    Variable/G root:XRDTestFailures=0
    NVAR generation=root:Packages:XRDWorkbench:Recovery:generation,busy=root:Packages:XRDWorkbench:Recovery:busy
    SVAR file=root:Packages:XRDWorkbench:Recovery:lastFile
    Variable previous=generation
    String previousFile=file
    XRD_TestCheck(XRD_SaveRecovery()<0,"locked recovery file fails without stopping Igor")
    XRD_TestCheck(generation==previous && busy==0 && cmpstr(file,previousFile)==0,"file write failure preserves last successful generation and unlocks saving")
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.5 write-failure tests: failures="+num2istr(failures)
End
