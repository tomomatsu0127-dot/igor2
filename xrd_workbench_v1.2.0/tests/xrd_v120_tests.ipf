#pragma rtGlobals=3
#include ":xrd_v100_tests"
Function XRD_RunV120Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    String admin=XRD100_Admin(),p1=XRD_Project(),id1=XRD80_ProjectUID(p1),path,uid,other,p2,recipe,win,tree,base
    String/G $(admin+":backupFolder")=output
    NewPath/O/Q XRDReferencePath,fixtures
    Variable i,j,result
    for(i=1;i<=10;i+=1)
        XRD_TestCheck(XRD_LoadReferenceFile("phase"+num2istr(i)+".txt",i)==0,"v120 fixture imports "+num2istr(i))
    endfor
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=2
    for(i=0;i<10;i+=1)
        yy+=100*exp(-((xx[p]-(25+2*i))/0.1)^2)
    endfor
    path=XRD_Store(xx,yy,"first.xy");uid=XRD80_MeasurementUID(path)
    for(i=0;i<10;i+=1)
        XRD_Manual(path,25+2*i)
        XRD_TestCheck(XRD80_TestAdopt(path,i,i+1,0)==0,"v120 real assignment "+num2istr(i))
    endfor
    XRD_TestCheck(XRD100_SetSample(path,"015","x=-0.1","試料015")==0,"v120 plain string registration accepted")
    path=XRD80_ResolveMeasurement(uid)
    XRD_TestCheck(cmpstr(StrVarOrDefault(path+":sampleNumber",""),"015")==0 && WaveExists($(p1+":"+PossiblyQuoteName("tt_015_x=-0.1_"+XRD_ProjectDisplayName(p1)))),"v120 leading zero and single underscore retained")
    XRD_TestCheck(!WaveExists($(p1+":"+PossiblyQuoteName("tt_015__x=-0.1_"+XRD_ProjectDisplayName(p1)))),"v120 fresh registration has no double separator")
    XRD_TestCheck(cmpstr(XRD100_Leaf(path),"015")==0 && !DataFolderExists(p1+":Measurements:Data1"),"v120 physical sample folder uses entered serial")
    Wave raw110=$(path+":Raw:intensity")
    Variable serialCRC=WaveCRC(0,raw110)
    Variable/G $(admin+":faultAfter")=1
    XRD_TestCheck(XRD100_SetSample(path,"016","x=-0.1","変更失敗")<0,"v120 serial-folder rename failure is reported")
    Variable/G $(admin+":faultAfter")=0
    XRD_TestCheck(cmpstr(XRD80_ResolveMeasurement(uid),path)==0 && DataFolderExists(path) && !DataFolderExists(XRD110_MeasurementPath(p1,"016")) && !XRD100_Busy(),"v120 failed serial change restores original folder and ID")
    XRD_TestCheck(cmpstr(StrVarOrDefault(path+":sampleNumber",""),"015")==0 && WaveCRC(0,raw110)==serialCRC,"v120 failed serial change retains metadata and raw data")
    String duplicatePath=XRD_Store(xx,yy,"duplicate.xy"),duplicateUID=XRD80_MeasurementUID(duplicatePath)
    XRD_TestCheck(XRD100_SetSample(duplicatePath,"015","x=0.8","重複") == -5,"v120 duplicate serial in same project is refused even with another composition")
    XRD_TestCheck(cmpstr(StrVarOrDefault(duplicatePath+":sampleNumber",""),"")==0 && WaveCRC(0,raw110)==serialCRC,"v120 duplicate serial never overwrites existing sample")
    Variable/G $(duplicatePath+":deleted")=1
    String/G $(p1+":activeData")=path
    XRD110_RegisterPanel(path)
    ControlInfo/W=XRDRegister110 number
    XRD_TestCheck(V_flag==5 && cmpstr(StrVarOrDefault(XRD110_Entry()+":number",""),"015")==0,"v120 serial uses a string text control")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDRegister110 as output+"registration.png"
    DoWindow/K XRDRegister110
    XRD_NewProject();p2=XRD_Project()
    other=XRD_Store(xx,yy,"other.xy")
    String otherUID=XRD80_MeasurementUID(other)
    XRD_TestCheck(XRD100_SetSample(other,"015","x=0","別プロジェクトの015")==0,"v120 identical serial is allowed in another project")
    other=XRD80_ResolveMeasurement(otherUID)
    XRD_Manual(other,25);XRD80_TestAdopt(other,0,1,0)
    XRD_TestCheck(XRD_IsAnalysisComplete(other),"v120 other-project measurement is identified")
    String/G root:Packages:XRDWorkbench:activeProject=p1
    String/G $(p1+":activeData")=path
    XRD110_Manager()
    tree=XRD110_TreeBase(0)
    Wave types=$(tree+":types")
    XRD_TestCheck(numpnts(types)==2 && sum(types)==0,"v120 project tree starts collapsed")
    XRD110_Toggle(0,p1)
    Wave/T folderText=$(tree+":table")
    XRD_TestCheck(strsearch(folderText[1][1],"015 /",0)>=0,"v120 tree displays user serial instead of Data1")
    XRD_TestCheck(numpnts(types)==3 && sum(types)==1,"v120 project expansion reveals only its child")
    XRD110_Toggle(0,p1)
    XRD_TestCheck(numpnts(types)==2,"v120 folder collapses independently")
    XRD110_Toggle(0,p2)
    XRD110_ManagerSelect(2)
    XRD_TestCheck(cmpstr(XRD100_ManagerProject(),p2)==0,"v120 nested selection resolves its parent project")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDProjectManager as output+"projects.png"
    Variable/G $(p1+":activeStep")=1
    XRD_Panel()
    String controls=ControlNameList("XRDWorkbench",";"),removed="step5;undoAction;redoAction;uiText;profileFit;externalPeaks;reference;saveHelp;helpGuide;zoomPlus;zoomMinus;viewBack"
    result=1
    for(i=0;i<ItemsInList(removed);i+=1)
        result=result && WhichListItem(StringFromList(i,removed),controls)<0
    endfor
    XRD_TestCheck(result,"v120 removed Workbench controls stay absent")
    XRD_TestCheck(!strlen(CsrInfo(A,"XRDWorkbench#Pattern")),"v120 peak selection does not create a custom A cursor")
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 560
    XRD_TestCheck(XRD81_AddCursorPoint()==560,"v120 native Ctrl-I cursor point can be added")
    Wave angles=$(path+":Peaks:angle")
    XRD_TestCheck(abs(angles[numpnts(angles)-1]-48)<1e-8,"v120 exact native cursor angle is registered")
    XRD_SetUnknown(path,numpnts(angles)-1)
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"step1.png"
    for(i=2;i<=4;i+=1)
        Variable/G $(p1+":activeStep")=i
        XRD_Panel()
        XRD_TestCheck(WinType("XRDWorkbench#Pattern")==1 && strsearch(WinRecreation("XRDWorkbench",0),"title=\"New\"",0)<0,"v120 step renders without New controls "+num2istr(i))
        if(i<=3)
            ControlInfo/W=XRDWorkbench viewAll
            XRD_TestCheck(V_flag==1,"v120 full range button present step "+num2istr(i))
            SetAxis/W=XRDWorkbench#Pattern bottom 30,40
            XRD_ResetView()
            GetAxis/W=XRDWorkbench#Pattern/Q bottom
            XRD_TestCheck(V_min==20 && V_max==70,"v120 native full range restoration step "+num2istr(i))
        endif
        SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"step"+num2istr(i)+".png"
    endfor
    Variable/G $(p1+":activeStep")=3
    XRD_Panel()
    XRD100_Select(path,0,1)
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-20)<1e-8 && abs(V_max-30)<1e-8,"v120 registered peak selection still zooms to plus-minus five")
    Variable angleCRC=WaveCRC(0,angles)
    STRUCT WMWinHookStruct hook
    hook.winName="XRDWorkbench#Pattern";hook.eventCode=3;hook.eventMod=16
    XRD_TestCheck(XRD110_PointHook(hook)==0,"v120 right-click zoom override removed")
    XRD_TestCheck(WaveCRC(0,angles)==angleCRC,"v120 mouse event cannot relocate registered peak")
    XRD110_ComparePanel()
    XRD110_Toggle(2,p2)
    tree=XRD110_TreeBase(2)
    Wave/T compareMap=$(tree+":map")
    Wave cf=$(tree+":flags")
    for(i=0;i<numpnts(compareMap);i+=1)
        if(cmpstr(compareMap[i],other)==0)
            cf[i][0]=48;XRD110_CheckTree(2,i)
        endif
    endfor
    STRUCT WMButtonAction ba
    ba.eventCode=2;ba.ctrlName="apply"
    XRD_CompareSelectionButton(ba)
    XRD_TestCheck(WhichListItem(other,XRD_ComparePaths())>=0,"v120 completed data in another project can be added to comparison")
    XRD_DrawLiveStack("XRDWorkbench#SideCompare",2)
    XRD_TestCheck(strsearch(AnnotationList("XRDWorkbench#SideCompare"),"SidePhases110",0)>=0,"v120 side comparison has marker legends")
    XRD_ResizePanel()
    ControlInfo/W=XRDWorkbench measurementLabel
    XRD_TestCheck(V_left>=220 && V_top<28,"v120 sample chooser stays in header without overlapping buttons")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"cross_project_comparison.png"
    XRD_PlotWorkspace()
    String ui=XRD_PlotRoot()+":UI"
    Wave/T plotPaths=$(ui+":paths")
    Wave pf=$(ui+":flags")
    pf[][0]=48
    XRD110_PlotTrees()
    XRD_TestCheck(WhichListItem("sources",ControlNameList("XRDPlotWorkspace",";"))<0,"v120 redundant source picker button removed")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDPlotWorkspace as output+"plot_workspace.png"
    Variable/G $(ui+":legendColumns")=2
    Variable/G $(ui+":legendSeparate")=0
    recipe=XRD_PlotSaveDraft("");XRD_PlotDrawRecipe(recipe,0)
    win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    GetWindow $win psize
    Variable pw=V_right-V_left,ph=V_bottom-V_top
    XRD_TestCheck(abs(pw-NumVarOrDefault(recipe+":width",340))<1 && abs(ph-NumVarOrDefault(recipe+":height",360))<1,"v120 legend keeps requested plot rectangle")
    XRD_TestCheck(WhichListItem("Phases",AnnotationList(win))>=0 && WhichListItem("PhasesCol110_2",AnnotationList(win))<0,"v120 columns share a single editable native legend")
    SavePICT/O/E=-5/SNAP=1/WIN=$win as output+"legend_two_columns.png"
    Variable/G $(recipe+":legendColumns")=3
    XRD_PlotLegend(win)
    GetWindow $win psize
    XRD_TestCheck(abs((V_right-V_left)-pw)<0.5 && abs((V_bottom-V_top)-ph)<0.5,"v120 changing legend columns does not shrink plot")
    Variable/G $(recipe+":legendSeparate")=1
    XRD_PlotLegend(win)
    GetWindow $win psize
    XRD_TestCheck(abs((V_right-V_left)-pw)<0.5 && abs((V_bottom-V_top)-ph)<0.5,"v120 separate legend preserves plot dimensions")
    XRD_TestCheck(WinType(win+"_Legend")==1 && WhichListItem("Phases",AnnotationList(win))<0,"v120 separate native legend window exists")
    SavePICT/O/E=-5/SNAP=1/WIN=$(win+"_Legend") as output+"legend_only.png"
    SavePICT/O/E=-5/SNAP=1/WIN=$win as output+"plot_without_legend.png"
    XRD_ElementPanel()
    ControlInfo/W=XRDElements elH
    Variable oldWidth=V_width
    MoveWindow/W=XRDElements 20,20,1220,720
    XRD110_ElementLayout()
    ControlInfo/W=XRDElements elH
    XRD_TestCheck(V_width>oldWidth,"v120 periodic table cells grow with window size")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDElements as output+"periodic_table.png"
    // Scroll an ordinary list area; do not invoke a row action.
    XRD80_LibraryPanel()
    ListBox library,win=XRDLibrary,size={800,60},row=0
    ControlInfo/W=XRDLibrary library
    hook.winName="XRDLibrary";hook.eventCode=22;hook.wheelDy=-1
    hook.mouseLoc.h=V_left+100;hook.mouseLoc.v=V_top+30
    XRD_TestCheck(XRD110_WheelHook(hook)==1,"v120 wheel over list body is handled")
    ControlInfo/W=XRDLibrary library
    XRD_TestCheck(V_startRow>0,"v120 wheel advances visible rows")
    Variable serialResult=XRD100_SetSample(path,"016","x=-0.1","試料015")
    XRD_TestCheck(serialResult==0,"v120 serial can change after identification and figure creation")
    path=XRD80_ResolveMeasurement(uid)
    XRD_TestCheck(cmpstr(XRD100_Leaf(path),"016")==0 && cmpstr(GetUserData("XRDWorkbench","","XRDData"),path)==0,"v120 serial rename updates active Workbench and UID links")
    XRD_TestCheck(XRD_IsAnalysisComplete(path) && WaveCRC(0,raw110)==serialCRC,"v120 serial rename preserves assignments and raw values")
    XRD_TestCheck(XRD100_SetSample(path,"015","x=-0.1","試料015")==0,"v120 serial can return to its original value")
    path=XRD80_ResolveMeasurement(uid)
    XRD_TestCheck(DataFolderExists(recipe+":Snapshot:Sample1") && WinType(win)==1,"v120 saved figure survives serial folder changes")
    XRD_RunV120Changes(path,other,p1,p2,recipe,output)
    String/G root:XRD120SavedUID=uid
    String/G root:XRD120SavedRecipe=recipe
    XRD_PlotCaptureNative(recipe)
    SaveExperiment/C/F={1,"",0} as output+"roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "v120 failures="+num2istr(failures)
    return failures
End

Function XRD_RunV120Guard(fixtures,output)
    String fixtures,output
    Variable error=0
    try
        XRD_RunV120Tests(fixtures,output); AbortOnRTE
    catch
        Print "V120 ERROR DETAIL",GetRTErrMessage()
        error=max(1,GetRTError(1))
        Print "V120 RUNTIME ERROR",error,GetErrMessage(error)
    endtry
    return error
End

Function XRD_VerifyV120Restored()
    Variable/G root:XRDTestFailures=0
    SVAR uid=root:XRD120SavedUID,recipe=root:XRD120SavedRecipe
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    String path=XRD80_ResolveMeasurement(uid),project=XRD80_ProjectForMeasurement(path),win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    XRD_TestCheck(cmpstr(XRD100_Leaf(path),"015")==0 && cmpstr(StrVarOrDefault(path+":sampleNumber",""),"015")==0,"v120 actual reopen preserves serial folder and leading zero")
    Wave alias=$(project+":"+PossiblyQuoteName("int_015_x=-0.1_"+XRD_ProjectDisplayName(project))),raw=$(path+":Raw:intensity")
    XRD_TestCheck(WaveExists(alias) && WaveCRC(0,alias)==WaveCRC(0,raw),"v120 actual reopen evaluates named raw dependency")
    XRD_TestCheck(XRD_IsAnalysisComplete(path),"v120 actual reopen retains assignments including Unknown")
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())>=1,"v120 actual reopen retains cross-project comparison")
    XRD_TestCheck(NumVarOrDefault(recipe+":legendColumns",0)==3 && NumVarOrDefault(recipe+":legendSeparate",0)==1,"v120 actual reopen retains legend columns and separate output")
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,1)==0 && WinType(win)==1,"v120 actual reopen restores native plot")
    XRD_TestCheck(WinType(win+"_Legend")==1,"v120 actual reopen restores separate native legend")
    SVAR copiedUID=root:XRD120CopiedUID,sourceUID=root:XRD120SourceUID
    String copied=XRD80_ResolveMeasurement(copiedUID),source=XRD80_ResolveMeasurement(sourceUID)
    XRD_TestCheck(strlen(copied)>0 && strlen(source)>0 && cmpstr(copiedUID,sourceUID)!=0,"v120 actual reopen preserves independent copied and source samples")
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==3,"v120 actual reopen preserves exactly three selected comparison samples")
    XRD_TestCheck(XRD_IsAnalysisComplete(copied) && NumVarOrDefault(copied+":Lattice:a",0)==5.89,"v120 actual reopen retains copied identification and lattice values")
    String/G $(project+":activeData")=path
    Variable/G $(project+":activeStep")=3
    XRD_Panel()
    XRD100_Select(path,0,1)
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_min==-30 && V_max==110,"v120 actual reopen keeps fixed identification Y bounds")
    NVAR failures=root:XRDTestFailures
    Print "v120 reopened failures="+num2istr(failures)
    return failures
End

Function XRD_RunV120Changes(path,other,p1,p2,recipe,output)
    String path,other,p1,p2,recipe,output
    String/G root:Packages:XRDWorkbench:activeProject=p1
    String/G $(p1+":activeData")=path
    Variable/G $(p1+":activeStep")=3
    XRD_Panel()
    MoveWindow/W=XRDWorkbench 10,10,1410,850
    XRD_ResizePanel()
    String instance=GetUserData("XRDWorkbench","","XRDInstance")
    SetWindow XRDWorkbench#Pattern userdata(keep120)="same graph"
    Variable i,timer=StartMSTimer
    for(i=0;i<6;i+=1)
        XRD_Panel()
    endfor
    Variable elapsed=StopMSTimer(timer)/1000
    Print "V120_PANEL_REPEAT_6_MS",elapsed
    XRD_TestCheck(cmpstr(instance,GetUserData("XRDWorkbench","","XRDInstance"))==0 && cmpstr(GetUserData("XRDWorkbench#Pattern","","keep120"),"same graph")==0,"v120 repeated updates preserve the parent frame and graph")
    GetWindow XRDWorkbench wsizeForControls
    XRD_TestCheck(V_right>=1300 && V_bottom>=800,"v120 repeated updates retain large native window size")
    ControlInfo/W=XRDWorkbench matchActions
    XRD_TestCheck(V_flag==1 && V_width>=300 && V_height>=25,"v120 operation menu has a readable native button")
    XRD100_Select(path,0,1)
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_min==-30 && V_max==110,"v120 first peak zoom leaves Y fixed")
    XRD100_Select(path,8,1)
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_min==-30 && V_max==110,"v120 moving to another peak leaves Y fixed")
    SetAxis/W=XRDWorkbench#Pattern left 1,20
    XRD120_LockY()
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_min==-30 && V_max==110,"v120 native zoom Y changes are restored to fixed bounds")
    XRD_ResetView()
    XRD_TestCheck(strsearch(XRD120_StrongMissing(path,1,0),"第2ピーク",0)>=0,"v120 secondary reference below 70 percent still warns")
    XRD_TestCheck(strsearch(XRD120_StrongMissing(path,1,0),"主ピーク",0)<0,"v120 primary assigned to a different phase still counts as present")
    XRD_TestCheck(!strlen(XRD120_StrongMissing(path,1,100)),"v120 out-of-range reference peaks do not warn")
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=2+100*exp(-((xx[p]-30)/0.1)^2)
    String fresh=XRD_Store(xx,yy,"strong-missing.xy")
    XRD_Manual(fresh,30)
    XRD_TestCheck(strsearch(XRD120_StrongMissing(fresh,1,0),"主ピーク",0)>=0 && strsearch(XRD120_StrongMissing(fresh,1,0),"第2ピーク",0)>=0,"v120 both missing strongest reflections are identified")
    XRD_Manual(fresh,25);XRD_Manual(fresh,55)
    XRD_TestCheck(!strlen(XRD120_StrongMissing(fresh,1,0)),"v120 adding missing reflection positions clears warning")
    Variable/G $(fresh+":deleted")=1
    String/G $(p1+":activeData")=path
    String settings=XRD120_CompareSettings()
    Make/O/T/N=1 $(settings+":uids")=XRD80_MeasurementUID(other)
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==1 && cmpstr(StringFromList(0,XRD_ComparePaths()),other)==0,"v120 exact selection can show one other sample without the edited sample")
    XRD_UpdateSideCompare()
    XRD_TestCheck(str2num(GetUserData("XRDWorkbench#SideCompare","","XRDPlotCount"))==1,"v120 side graph renders exactly one selected sample")
    Variable/G $(settings+":legendFont")=18
    XRD_UpdateSideCompare()
    String info=AnnotationInfo("XRDWorkbench#SideCompare","SidePhases110",1),labelInfo=AnnotationInfo("XRDWorkbench#SideCompare","LiveLabel0",1)
    XRD_TestCheck(strsearch(info,"\\Z18",0)>=0 && strsearch(labelInfo,"\\Z18",0)>=0,"v120 sample and phase legends use the same selected font")
    XRD_TestCheck(WhichListItem("SidePhases110_2",AnnotationList("XRDWorkbench#SideCompare"))<0,"v120 left comparison uses one legend textbox")
    Variable/G $(settings+":legendFont")=12
    Make/O/T/N=0 $(settings+":uids")
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==0,"v120 zero selection never silently restores all samples")
    XRD_UpdateSideCompare()
    XRD_TestCheck(str2num(GetUserData("XRDWorkbench#SideCompare","","XRDPlotCount"))==0,"v120 zero selection clears the side graph")
    Make/O/T/N=1 $(settings+":uids")=XRD80_MeasurementUID(other)
    XRD_UpdateSideCompare()
    XRD_TestCheck(GetRTError(0)==0 && str2num(GetUserData("XRDWorkbench#SideCompare","","XRDPlotCount"))==1,"v120 comparison resumes after an empty selection")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"identification_selected.png"
    XRD110_RegisterPanel("")
    ControlInfo/W=XRDRegister110 label
    Variable labelY=V_top
    ControlInfo/W=XRDRegister110 composition
    XRD_TestCheck(labelY<V_top,"v120 display name precedes composition")
    String entry=XRD110_Entry()
    String/G $(entry+":label")="x=0.25"
    STRUCT WMSetVariableAction sva
    sva.eventCode=1;sva.ctrlName="label"
    XRD110_EntryChanged(sva)
    XRD_TestCheck(cmpstr(StrVarOrDefault(entry+":composition",""),"x=0.25")==0,"v120 display name fills composition automatically")
    String/G $(entry+":composition")="x=0.20"
    sva.ctrlName="composition";XRD110_EntryChanged(sva)
    XRD_TestCheck(cmpstr(StrVarOrDefault(entry+":label",""),"x=0.25")==0,"v120 editing composition never changes display name")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDRegister110 as output+"registration_order.png"
    DoWindow/K XRDRegister110
    String/G root:Packages:XRDWorkbench:activeProject=p2
    String/G $(p2+":activeData")=other
    NewPath/O/Q XRDReferencePath,output
    XRD_TestCheck(XRD_LoadReferenceFile("missing_hkl120.txt",11)==0,"v120 missing-hkl copy fixture imports")
    XRD_TestCheck(XRD80_TestAdopt(other,0,11,0)==0,"v120 source assignment can use missing hkl")
    XRD_Manual(other,26);XRD_SetUnknown(other,1)
    NewDataFolder/O $(other+":Lattice")
    Variable/G $(other+":Lattice:a")=5.89
    NewDataFolder/O $(other+":LatticeRuns")
    NewDataFolder/O $(other+":LatticeRuns:Run1")
    Make/O/D/N=3 $(other+":LatticeRuns:Run1:inputs")={1,2,3}
    String/G root:Packages:XRDWorkbench:activeProject=p1
    String/G $(p1+":activeData")=path
    String admin=XRD100_Admin()
    Variable/G $(admin+":faultAfter")=1
    String failed=XRD120_CopyMeasurement(other,p1,"021","x=0.1","複製失敗")
    Variable/G $(admin+":faultAfter")=0
    XRD_TestCheck(!strlen(failed) && !DataFolderExists(XRD110_MeasurementPath(p1,"021")) && !XRD100_Busy(),"v120 failed copy rolls back without partial sample")
    String copied=XRD120_CopyMeasurement(other,p1,"022","x=0.1","同定済みコピー")
    XRD_TestCheck(strlen(copied)>0 && cmpstr(XRD80_MeasurementUID(copied),XRD80_MeasurementUID(other))!=0,"v120 copy receives a new stable measurement ID")
    Wave sourceRaw=$(other+":Raw:intensity"),copyRaw=$(copied+":Raw:intensity"),sourceA=$(other+":Assignments:refIndex"),copyA=$(copied+":Assignments:refIndex"),copyRows=$(copied+":Assignments:refPeakIndex")
    Wave copyH=$(XRD_ReferencePath(copyA[0])+":h")
    XRD_TestCheck(WaveCRC(0,sourceRaw)==WaveCRC(0,copyRaw) && WaveCRC(0,sourceA)==WaveCRC(0,copyA),"v120 copy retains raw values and every phase assignment")
    XRD_TestCheck(numtype(copyH[copyRows[0]])==2 && copyA[1]==0 && XRD_IsAnalysisComplete(copied),"v120 copy preserves missing hkl Unknown and completion")
    XRD_TestCheck(NumVarOrDefault(copied+":Lattice:a",0)==5.89 && WaveExists($(copied+":LatticeRuns:Run1:inputs")),"v120 copy retains lattice values and history")
    XRD_TestCheck(cmpstr(StrVarOrDefault(copied+":copiedFromMeasurementUID120",""),XRD80_MeasurementUID(other))==0,"v120 copy records its source without moving it")
    XRD_TestCheck(!strlen(XRD120_CopyMeasurement(other,p1,"022","x=0.2","重複")),"v120 copy refuses a duplicate destination serial")
    Make/O/T/N=3 $(settings+":uids")
    Wave/T chosen=$(settings+":uids")
    chosen[0]=XRD80_MeasurementUID(other);chosen[1]=XRD80_MeasurementUID(path);chosen[2]=XRD80_MeasurementUID(copied)
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==3,"v120 exact comparison can display three chosen samples")
    XRD_UpdateSideCompare()
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"identification_three.png"
    String/G root:XRD120CopiedUID=XRD80_MeasurementUID(copied)
    String/G root:XRD120SourceUID=XRD80_MeasurementUID(other)
    return 0
End
