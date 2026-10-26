#pragma rtGlobals=3
// v0.4.4 isolated layout, cursor and saved UI tests.
Function XRD_RunV44Tests(fixturesPath,outputPath)
    String fixturesPath,outputPath
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_NewProject()
    NewPath/O/Q XRDReferencePath,fixturesPath
    XRD_LoadReferences()
    XRD_ImportFile(fixturesPath+"measurement.xy")
    String project=XRD_Project(),path=XRD_Data()
    XRD_DetectLegacy(path)
    XRD_ScoreCandidates(path,0)
    XRD_UISettings()
    NVAR saved=root:Packages:XRDWorkbench:UI:hasWindow,mode=root:Packages:XRDWorkbench:UI:textMode
    saved=0;mode=0
    NVAR step=$(project+":activeStep"),full=$(project+":tablesOnly")
    step=3;full=0
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_TestCheck(WhichListItem("referenceList",ControlNameList("XRDWorkbench",";"))<0 && WhichListItem("measurementList",ControlNameList("XRDWorkbench",";"))<0,"resize does not create unrelated tables over identification tables")
    GetWindow XRDWorkbench expand
    XRD_TestCheck(V_Value>=1,"initial panel does not reduce original text size")
    GetWindow XRDWorkbench wsizeForControls
    XRD_TestCheck(V_right>=720 && V_bottom>=440,"panel has usable minimum dimensions")
    SetAxis/W=XRDWorkbench#Pattern bottom 30,35
    SetAxis/W=XRDWorkbench#Pattern left -1,40
    XRD81_SetPickMode(1)
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 2
    Cursor/P/W=XRDWorkbench#Pattern B XRDWB_Measured 4
    ShowInfo/W=$"XRDWorkbench#Pattern"
    SetActiveSubwindow XRDWorkbench#Pattern
    MoveWindow/W=XRDWorkbench 10,40,1010,640
    XRD_ResizeDeferred()
    DoUpdate
    XRD_TestCheck(str2num(GetUserData("XRDWorkbench","","XRDUIScale"))>1,"larger window automatically enlarges controls and text")
    GetWindow XRDWorkbench wsize
    XRD_TestCheck(abs(V_right-V_left-1000)<2 && abs(V_bottom-V_top-600)<2,"automatic layout retains requested outer dimensions")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==30 && V_max==35,"resize retains zoomed angle range")
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_min==-1 && V_max==40,"resize retains zoomed intensity range")
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==2 && pcsr(B,"XRDWorkbench#Pattern")==4,"resize retains both measured-trace cursors")
    GetWindow XRDWorkbench activeSW
    XRD_TestCheck(cmpstr(S_Value,"XRDWorkbench#Pattern")==0,"resize retains active graph for Ctrl+I")
    XRD_CapturePanelState(1)
    XRD_TestCheck(NumVarOrDefault(path+":uiShowInfo",0)==1,"native cursor info bar state detected")
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    GetWindow XRDWorkbench wsize
    XRD_TestCheck(abs(V_right-V_left-1000)<2 && abs(V_bottom-V_top-600)<2,"workflow refresh retains resized window dimensions")
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==2 && pcsr(B,"XRDWorkbench#Pattern")==4,"workflow refresh restores both cursor positions")
    XRD_TestCheck(NumVarOrDefault(path+":uiShowInfo",0)==1,"workflow refresh retains cursor info request")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as outputPath+"large_cursor_v044.png"
    MoveWindow/W=XRDWorkbench 2,2,2,2
    XRD_ResizePanel()
    DoUpdate
    GetWindow XRDWorkbench maximize
    XRD_TestCheck(V_Value==1,"native maximize available")
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    GetWindow XRDWorkbench maximize
    XRD_TestCheck(V_Value==1,"workflow refresh retains maximized state")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as outputPath+"maximized_v044.png"
    MoveWindow/W=XRDWorkbench 1,1,1,1
    MoveWindow/W=XRDWorkbench 10,40,730,480
    XRD_ResizePanel()
    DoUpdate
    GetWindow XRDWorkbench expand
    XRD_TestCheck(V_Value>=1,"small window keeps original minimum text size")
    GetWindow XRDWorkbench wsizeForControls
    Variable w=V_right,h=V_bottom
    ControlInfo/W=XRDWorkbench candidateList
    XRD_TestCheck(V_left+V_width<=w && V_top+V_height<=h-15,"small-window candidate table stays inside content")
    ControlInfo/W=XRDWorkbench peakList
    XRD_TestCheck(V_left+V_width<=w && V_top+V_height<=h-15,"small-window measured-peak table stays inside content")
    ControlInfo/W=XRDWorkbench deletePeak2
    XRD_TestCheck(V_top+V_height<h-22,"small-window delete button stays above footer")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as outputPath+"small_v044.png"
    full=1
    XRD_TableLayout(project)
    ControlInfo/W=XRDWorkbench peakList
    Variable contentScale=str2num(GetUserData("XRDWorkbench","","XRDUIScale"))
    XRD_TestCheck(abs(V_width-(w-min(320*contentScale,w*0.35)-30*contentScale))<2 && abs(V_top-60*contentScale)<2,"expanded tables use available right pane beside comparison")
    GetWindow XRDWorkbench#Pattern hide
    XRD_TestCheck(V_Value==1,"table-only mode hides graph")
    full=0
    XRD_TableLayout(project)
    GetWindow XRDWorkbench#Pattern hide
    XRD_TestCheck(V_Value==0,"graph returns from table-only mode")
    STRUCT WMPopupAction pa
    pa.eventCode=2;pa.popNum=3
    XRD_TextSizeAction(pa)
    XRD_TestCheck(str2num(GetUserData("XRDWorkbench","","XRDUIScale"))>=1.2 && mode==2,"manual large text sets a 120 percent floor")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as outputPath+"text_large_v044.png"
    NVAR manual=$(path+":manualAngle")
    manual=32
    STRUCT WMButtonAction ba
    ba.eventCode=2;ba.ctrlName="addPeak"
    XRD_Button(ba)
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==2,"manual peak addition preserves cursor")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==30 && V_max==35,"manual peak addition preserves zoom after responsive refresh")
    Variable tab
    for(tab=1;tab<=5;tab+=1)
        step=tab
        XRD_TestDisableFollow()
    XRD_Panel()
        GetWindow XRDWorkbench wsizeForControls
        ControlInfo/W=XRDWorkbench step5
        XRD_TestCheck(V_left+V_width<=V_right+2,"responsive step tab "+num2istr(tab))
    endfor
    step=3
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_CapturePanelState(1)
    SaveExperiment as outputPath+"ui_roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.4 layout tests: failures="+num2istr(failures)
    return failures
End

Function XRD_UIQAPreview(samplesPath)
    String samplesPath
    XRD_Init()
    XRD_NewProject()
    NewPath/O/Q XRDReferencePath,samplesPath
    XRD_LoadReferences()
    Make/FREE/D/N=1001 xx,yy
    xx=20+0.05*p
    yy=2+30*exp(-((xx[p]-30.095)/0.12)^2)+100*exp(-((xx[p]-35.423)/0.13)^2)+8*exp(-((xx[p]-37.053)/0.11)^2)+20*exp(-((xx[p]-43.053)/0.14)^2)+10*exp(-((xx[p]-53.392)/0.12)^2)+30*exp(-((xx[p]-56.944)/0.16)^2)+40*exp(-((xx[p]-62.516)/0.16)^2)
    String path=XRD_Store(xx,yy,"画面確認用・模擬データ.xy")
    XRD_DetectLegacy(path)
    XRD_ScoreCandidates(path,0)
    NVAR step=$(XRD_Project()+":activeStep")
    step=3
    XRD_UISettings()
    NVAR mode=root:Packages:XRDWorkbench:UI:textMode,saved=root:Packages:XRDWorkbench:UI:hasWindow
    mode=0;saved=0
    XRD_TestDisableFollow()
    XRD_Panel()
    DoWindow/T kwFrame,"XRD v0.4.4 画面確認用"
    MoveWindow/W=XRDWorkbench 2,2,2,2
End

Function XRD_VerifyV44Restored()
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_TestDisableFollow()
    XRD_Panel()
    NVAR mode=root:Packages:XRDWorkbench:UI:textMode
    XRD_TestCheck(mode==2 && str2num(GetUserData("XRDWorkbench","","XRDUIScale"))>=1.2,"saved text size restores in a fresh Igor")
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==2,"cursor data restores when reopening workbench")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==30 && V_max==35,"saved zoom restores with responsive window")
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.4 persistence tests: failures="+num2istr(failures)
    return failures
End
