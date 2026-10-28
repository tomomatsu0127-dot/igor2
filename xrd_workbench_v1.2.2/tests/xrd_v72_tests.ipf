#pragma rtGlobals=3
Function XRD_RunV72Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    XRD_Init();XRD_NewProject()
    String project=XRD_Project()
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_LoadReferenceFile("QS-A.txt",1);XRD_LoadReferenceFile("Y-A.txt",2)
    Make/FREE/D/N=4001 xx=20+0.01*p,yy=2+100*exp(-((xx[p]-30.11)/0.08)^2)+60*exp(-((xx[p]-44)/0.08)^2)+20*exp(-((xx[p]-50)/0.08)^2)
    String path=XRD_Store(xx,yy,"1200C in air.xy"),second=XRD_Store(xx,yy,"1300C in air.xy")
    XRD_Manual(path,30.11);XRD_Manual(path,44);XRD_Manual(path,50)
    XRD_Manual(second,30.11);XRD_Manual(second,44)
    SVAR active=$(project+":activeData")
    active=path
    Variable/G $(project+":activeStep")=3
    Variable/G $(project+":liveCompare")=1
    XRD_ScoreCandidates(path,0)
    XRD_PreviewCandidate(path,XRD_V71Candidate(path,1,1))
    XRD_Panel()
    Variable/G $(path+":selectedPeakRow")=0
    XRD_ScoreCandidates(path,0)
    XRD_PreviewCandidate(path,XRD_V71Candidate(path,1,1));XRD_LiveDeferred()
    XRD_TestCheck(WinType("XRDWorkbench#SideCompare")==1 && WinType("XRDWorkbench#Pattern")==1,"left comparison and right single graph exist simultaneously")
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench#Pattern","","XRDCompare"),"1")!=0,"right graph stays single even when upgrading saved live comparison preference")
    XRD_TestCheck(NumVarOrDefault(project+":liveCompare",1)==0,"old main-graph stacking preference migrates to separate pane")
    ControlInfo/W=XRDWorkbench scoreCandidates
    XRD_TestCheck(V_flag==0,"candidate refresh button is removed from persistent left space")
    ControlInfo/W=XRDWorkbench matchTolerance
    XRD_TestCheck(V_flag==0,"advanced numeric settings do not occupy comparison space")
    ControlInfo/W=XRDWorkbench matchActions
    XRD_TestCheck(V_flag!=0,"less frequent actions remain available in one menu")
    ControlInfo/W=XRDWorkbench unknownPeak
    XRD_TestCheck(V_flag!=0,"Unknown remains directly available")
    Wave raw=$(path+":Raw:intensity"),rawX=$(path+":Raw:twoTheta")
    Variable crc=WaveCRC(0,raw),xcrc=WaveCRC(0,rawX)
    SVAR displayName=$(path+":displayName")
    String originalName=displayName
    displayName="12345678901234567890123鉄鉱石の測定データ"
    XRD_TestCheck(strsearch(XRD_SideSampleName(path),"12345678901234567890123鉄…",0)>=0,"comparison short label preserves whole Japanese characters")
    displayName=originalName
    Wave top=$(XRD_PlotRoot()+":LiveSide:intensity0"),bottom=$(XRD_PlotRoot()+":LiveSide:intensity1")
    XRD_TestCheck(abs(top[0]-bottom[0]-135)<1e-8,"left comparison keeps list order and 135 spacing")
    XRD_TestCheck(abs(str2num(GetUserData("XRDWorkbench#SideCompare","","XRDReferenceAngle"))-30.38)<1e-8,"left comparison red arrow marks chosen alternative reflection")
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 1011
    ShowInfo/W=XRDWorkbench
    XRD_ZoomSelectedPeak();XRD_LiveDeferred()
    GetAxis/W=XRDWorkbench#SideCompare/Q bottom
    XRD_TestCheck(abs(V_min-25.11)<1e-8 && abs(V_max-35.11)<1e-8,"left comparison shares selected plus-minus five degree view")
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==1011,"left-only refresh preserves right native cursor")
    Variable/G $(path+":selectedPeakRow")=1
    XRD_SelectedPeakGuide(path);XRD_LiveDeferred()
    GetAxis/W=XRDWorkbench#SideCompare/Q bottom
    XRD_TestCheck(V_min==39 && V_max==49,"selecting next measured peak moves both plots to same zoom")
    STRUCT WMButtonAction ba
    ba.eventCode=2;ba.ctrlName="resetZoom"
    XRD_V72Button(ba);XRD_LiveDeferred()
    GetAxis/W=XRDWorkbench#SideCompare/Q bottom
    XRD_TestCheck(V_min==20 && V_max==60,"full-range button restores whole range in both panes")
    XRD_V70Adopt(second,1,1);XRD_LiveDeferred()
    XRD_TestCheck(WhichListItem("M"+XRD80_MeasurementUID(second)+"R1",TraceNameList("XRDWorkbench#SideCompare",";",1))>=0,"identification on other sample appears in left live pane")
    XRD_ClearPeakReview(second,1);XRD_LiveDeferred()
    XRD_TestCheck(WhichListItem("M"+XRD80_MeasurementUID(second)+"R1",TraceNameList("XRDWorkbench#SideCompare",";",1))<0,"clearing identification removes left marker immediately on refresh")
    XRD_RunMatchAction(8)
    XRD_TestCheck(WinType("XRDMatchSettings")==7,"conditions remain accessible through other-actions menu")
    ControlInfo/W=XRDMatchSettings matchTolerance
    XRD_TestCheck(V_flag!=0 && V_disable==0,"condition sheet exposes active tolerance setting")
    ba.ctrlName="applyMatch";XRD_V72Button(ba)
    XRD_TestCheck(WinType("XRDMatchSettings")==0 && WinType("XRDWorkbench#SideCompare")==1,"apply closes condition sheet and retains comparison")
    Variable/G $(path+":selectedPeakRow")=0
    XRD_ScoreCandidates(path,0);XRD_PreviewCandidate(path,XRD_V71Candidate(path,1,0))
    XRD_RunMatchAction(2);XRD_LiveDeferred()
    Wave assignments=$(path+":Assignments:refIndex")
    XRD_TestCheck(numpnts(assignments)==1 && assignments[0]==1,"menu adoption retains existing one-sample identification workflow")
    XRD_TestCheck(cmpstr(StringByKey("TNAME",CsrInfo(A,"XRDWorkbench#Pattern")),"XRDWB_Select")==0 && pcsr(A,"XRDWorkbench#Pattern")==NumVarOrDefault(path+":selectedPeakRow",-1),"menu adoption advances native cursor to selected registered peak")
    Variable/G $(path+":selectedPeakRow")=0
    XRD_RunMatchAction(4);XRD_LiveDeferred()
    XRD_TestCheck(numpnts(assignments)==0,"clear identification is available from collapsed actions")
    ba.ctrlName="unknownPeak";XRD_Button(ba);XRD_LiveDeferred()
    XRD_TestCheck(numpnts(assignments)==1 && assignments[0]==0,"direct Unknown button records unknown and refreshes comparison")
    STRUCT WMPopupAction pa
    pa.eventCode=2;pa.popNum=4;pa.ctrlName="matchActions"
    XRD_MatchActionPopup(pa)
    Variable/G $(path+":selectedPeakRow")=1
    XRD_MatchActionDeferred()
    XRD_TestCheck(numpnts(assignments)==1,"changing peak cancels stale queued menu action")
    Variable/G $(path+":selectedPeakRow")=0
    XRD_MatchActionPopup(pa);XRD_MatchActionDeferred();XRD_LiveDeferred()
    XRD_TestCheck(numpnts(assignments)==0,"queued menu action applies when original peak is still selected")
    XRD_MatchSettingsPanel()
    active=second;XRD_Panel();XRD_LiveDeferred()
    XRD_TestCheck(WinType("XRDMatchSettings")==0,"switching sample dismisses stale condition sheet")
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench#SideCompare","","XRDData"),second)==0,"left comparison marks newly active sample")
    XRD_V70Adopt(path,1,1);XRD_V70Adopt(second,0,2)
    Variable/G $(second+":selectedPeakRow")=0
    XRD_ScoreCandidates(second,0);XRD_PreviewCandidate(second,XRD_V71Candidate(second,2,0))
    XRD_Panel();XRD_LiveDeferred()
    XRD_TestCheck(WhichListItem("M"+XRD80_MeasurementUID(path)+"R1",TraceNameList("XRDWorkbench#SideCompare",";",1))>=0 && WhichListItem("M"+XRD80_MeasurementUID(second)+"R2",TraceNameList("XRDWorkbench#SideCompare",";",1))>=0,"both sample assignments appear with shared phase styles in side pane")
    MoveWindow/W=XRDWorkbench 10,10,1410,850
    XRD_ResizePanel();DoUpdate
    GetWindow XRDWorkbench#SideCompare wsize
    Variable sideRight=V_right
    GetWindow XRDWorkbench#Pattern wsize
    XRD_TestCheck(V_left>sideRight,"comparison and main graph do not overlap after monitor-sized resize")
    ControlInfo/W=XRDWorkbench peakList
    XRD_TestCheck(V_left>sideRight,"measured table stays to right of comparison")
    ControlInfo/W=XRDWorkbench candidateList
    XRD_TestCheck(V_left>sideRight,"candidate table stays to right of comparison")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"side_comparison_large_v072.png"
    MoveWindow/W=XRDWorkbench 10,10,800,520
    XRD_ResizePanel();DoUpdate
    GetWindow XRDWorkbench#SideCompare wsize
    sideRight=V_right
    GetWindow XRDWorkbench#Pattern wsize
    XRD_TestCheck(V_left>sideRight,"comparison and main graph do not overlap on laptop size")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"side_comparison_small_v072.png"
    XRD_MatchSettingsPanel();DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDMatchSettings as output+"conditions_v072.png"
    DoWindow/K XRDMatchSettings
    SaveExperiment/C/F={1,"",0} as output+"side_project.pxp"
    XRD_TestCheck(WaveCRC(0,raw)==crc && WaveCRC(0,rawX)==xcrc,"left comparison and menu operations preserve Raw")
    XRD_TestCheck(GetRTError(1)==0,"new dual-graph and collapsed actions leave no runtime error")
    Variable/G $(project+":activeStep")=1
    XRD_Panel()
    XRD_TestCheck(WinType("XRDWorkbench#SideCompare")==0 && WhichListItem("XRDWB_Preview",TraceNameList("XRDWorkbench#Pattern",";",1))<0 && ItemsInList(TraceNameList("XRDWorkbench#Pattern",";",1))==3,"measurement step retains detection-only graph plus registered-peak selector")
    NVAR failures=root:XRDTestFailures
    Print "v072 failures="+num2istr(failures)
End

Function XRD_V72Tutorial(samples)
    String samples
    XRD_Init();XRD_NewProject()
    XRD_TestCheck(XRD_ImportFile(samples+"measurement.csv")==0,"beginner tutorial measurement imports")
    NewPath/O/Q XRDReferencePath,samples+"references:"
    XRD_TestCheck(XRD_LoadReferences()==1 && NumVarOrDefault(XRD_Project()+":referenceErrorCount",-1)==0,"beginner tutorial reference folder loads without errors")
    String path=XRD_Data()
    XRD_TestCheck(XRD_Detect(path)>=0 && numpnts($(path+":Peaks:angle"))>=3,"beginner tutorial detection produces usable registered peaks")
    XRD_TestCheck(GetRTError(1)==0,"beginner tutorial leaves no native runtime error")
End

Function XRD_V72Persistence(saved)
    String saved
    DoWindow/K XRDWorkbench
    DoWindow/K XRDReviewGraph
    LoadData/O/Q/R saved
    XRD_Init();XRD_Open();XRD_LiveDeferred()
    XRD_TestCheck(WinType("XRDWorkbench#SideCompare")==1 && cmpstr(GetUserData("XRDWorkbench#Pattern","","XRDCompare"),"1")!=0,"saved project reopens left comparison and single right graph")
    XRD_TestCheck(ItemsInList(XRD_MeasurementOrderList(XRD_Project()))==2,"saved project preserves both samples")
    Wave ar=$(XRD_Data()+":Assignments:refIndex")
    XRD_TestCheck(numpnts(ar)==1 && ar[0]==2,"adopted phase identity survives new-layout reload")
    XRD_TestCheck(GetRTError(1)==0,"side comparison project reload leaves no native error")
End

Function XRD_V72Migration(saved)
    String saved
    DoWindow/K XRDWorkbench
    DoWindow/K XRDReviewGraph
    LoadData/O/Q/R saved
    String path=XRD_Data()
    Wave raw=$(path+":Raw:intensity"),ar=$(path+":Assignments:refIndex")
    Variable crc=WaveCRC(0,raw),count=numpnts(ar)
    XRD_Init();XRD_Open();XRD_LiveDeferred()
    XRD_TestCheck(WinType("XRDWorkbench#SideCompare")==1 && NumVarOrDefault(XRD_Project()+":liveCompare",1)==0,"v071 saved stacked preference migrates to side comparison")
    XRD_TestCheck(WaveCRC(0,raw)==crc && numpnts(ar)==count,"v071 migration preserves original intensity and assignments")
    XRD_TestCheck(GetRTError(1)==0,"v071 migration to new layout leaves no native error")
End
