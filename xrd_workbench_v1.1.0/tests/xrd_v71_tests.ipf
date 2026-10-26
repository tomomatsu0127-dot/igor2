#pragma rtGlobals=3
// v0.7.1 native integration: focused detection and live identification.
Function XRD_V71Candidate(path,ref,reflection)
    String path
    Variable ref,reflection
    Wave refs=$(path+":Candidates:refIndex"),rows=$(path+":Candidates:refPeakIndex")
    Variable i
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==ref && rows[i]==reflection)
            return i
        endif
    endfor
    return -1
End

Function XRD_RunV71Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    XRD_Init();XRD_NewProject()
    String project=XRD_Project()
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_TestCheck(XRD_LoadReferenceFile("QS-A.txt",1)==0 && XRD_LoadReferenceFile("QS-B.txt",2)==0 && XRD_LoadReferenceFile("Y-A.txt",3)==0,"v071 separate type cards load")
    Make/FREE/D/N=4001 xx=20+0.01*p,yy=2+100*exp(-((xx[p]-30.11)/0.07)^2)+60*exp(-((xx[p]-44)/0.07)^2)+20*exp(-((xx[p]-50)/0.07)^2)
    String path=XRD_Store(xx,yy,"sample A.xy"),second
    XRD_Manual(path,30.11);XRD_Manual(path,44);XRD_Manual(path,50)
    Wave raw=$(path+":Raw:intensity"),rawX=$(path+":Raw:twoTheta"),ids=$(path+":Peaks:peakID")
    Variable crc=WaveCRC(0,raw),xcrc=WaveCRC(0,rawX),r0,r1
    XRD_ScoreCandidates(path,0)
    r0=XRD_V71Candidate(path,1,0)
    XRD_TestCheck(r0>=0 && XRD_AssignCandidate(path,0,r0,0)==0,"v071 existing assignment prepared before focus view")
    XRD_PreviewReference(path,1,0)
    second=XRD_Store(xx,yy,"sample B.xy")
    XRD_Manual(second,30.11);XRD_Manual(second,44)
    SVAR active=$(project+":activeData")
    active=path
    NVAR step=$(project+":activeStep"),selected=$(path+":selectedPeakRow")
    step=1;selected=0
    XRD_Panel()
    String traces=TraceNameList("XRDWorkbench#Pattern",";",1)
    XRD_TestCheck(ItemsInList(traces)==2 && WhichListItem("XRDWB_Measured",traces)>=0 && WhichListItem("XRDWB_Peaks",traces)>=0,"focus view has only measured curve and registered peaks")
    XRD_TestCheck(WhichListItem("ShiftInfo",AnnotationList("XRDWorkbench#Pattern"))<0 && WhichListItem("ReferenceSelected",AnnotationList("XRDWorkbench#Pattern"))<0,"focus view has no reference annotations")
    Wave/T table=$(path+":Peaks:focusTable")
    XRD_TestCheck(DimSize(table,0)==3 && DimSize(table,1)==3 && cmpstr(table[0][2],"手動")==0,"focus table shows angle intensity and registration method")
    Wave plotted=TraceNameToWaveRef("XRDWorkbench#Pattern","XRDWB_Peaks")
    XRD_TestCheck(numpnts(plotted)==3,"focus includes assigned and unassigned registered peaks")
    XRD_TestCheck(NumVarOrDefault(path+":followPeak",0)==1,"linked zoom defaults on for new measurement")
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 1011
    ShowInfo/W=XRDWorkbench
    XRD_ZoomSelectedPeak()
    selected=1;XRD_SelectedPeakGuide(path)
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-39)<1e-8 && abs(V_max-49)<1e-8,"selecting another peak follows with unchanged ten degree span")
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_min==-30 && V_max==110 && pcsr(A,"XRDWorkbench#Pattern")==1011,"following preserves intensity and native cursor point")
    Variable/G $(path+":followPeak")=0
    selected=2;XRD_SelectedPeakGuide(path)
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==39 && V_max==49,"follow off retains previous zoom on selection")
    XRD_ResetView()
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==20 && V_max==60,"full range button restores raw angular extent")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"detection_v071.png"
    step=2;XRD_Panel()
    ControlInfo/W=XRDWorkbench typeFamilies
    XRD_TestCheck(V_flag!=0,"type card chooser has separate visible entrance")
    Variable/G $(XRD_ReferencePath(1)+":materialEnabled")=0
    XRD_TypePanel()
    String draft="root:Packages:XRDWorkbench:UI:TypeDraft"
    Wave enabled=$(draft+":enabled"),modes=$(draft+":modes"),single=$(draft+":singleRef"),configured=$(draft+":configured")
    XRD_TestCheck(enabled[0]==0,"family chooser reflects general material exclusions")
    modes[3]=1;single[3]=1;configured[3]=1;enabled[0]=1
    XRD_ApplyTypeDraft()
    XRD_TestCheck(XRD_MaterialAllowed(1) && XRD_TypeCardAllowed(1) && !XRD_TypeCardAllowed(2),"single type chooser re-enables selected material and excludes sibling")
    modes[3]=0;enabled[0]=1;enabled[1]=1
    XRD_ApplyTypeDraft()
    XRD_TestCheck(XRD_MaterialAllowed(1) && XRD_MaterialAllowed(2) && XRD_TypeCardAllowed(2),"multiple type mode restores two cards")
    Wave assignments=$(path+":Assignments:refIndex")
    XRD_TestCheck(numpnts(assignments)==1 && assignments[0]==1,"card policy does not erase existing assignment")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDTypeCards as output+"type_cards_v071.png"
    DoWindow/K XRDTypeCards
    step=3;selected=0;XRD_Panel()
    XRD_ScoreCandidates(path,0)
    r0=XRD_V71Candidate(path,1,0);r1=XRD_V71Candidate(path,1,1)
    XRD_TestCheck(r0>=0 && r1>=0,"one reference card has two nearby reflection candidates")
    XRD_PreviewCandidate(path,r0)
    XRD_TestCheck(abs(str2num(GetUserData("XRDWorkbench#Pattern","","XRDReferenceAngle"))-30.1)<1e-8,"red arrow marks first selected reference reflection")
    XRD_PreviewCandidate(path,r1)
    XRD_TestCheck(abs(str2num(GetUserData("XRDWorkbench#Pattern","","XRDReferenceAngle"))-30.38)<1e-8,"red arrow follows second reflection within same card")
    String annotation=StringByKey("TEXT",AnnotationInfo("XRDWorkbench#Pattern","ReferenceSelected",1))
    XRD_TestCheck(strsearch(annotation,"(110)",0)>=0,"selected reflection label exposes hkl")
    Variable/G $(project+":liveCompare")=1
    XRD_Panel()
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench#Pattern","","XRDCompare"),"1")==0,"identification main graph switches to live stack")
    ControlInfo/W=XRDWorkbench peakList
    XRD_TestCheck(V_flag!=0,"measured peak table remains in live comparison mode")
    ControlInfo/W=XRDWorkbench candidateList
    XRD_TestCheck(V_flag!=0,"reference candidate table remains in live comparison mode")
    Wave top=$(project+":LivePanel:intensity0"),bottom=$(project+":LivePanel:intensity1")
    XRD_TestCheck(abs(top[0]-bottom[0]-135)<1e-8,"live stack follows measurement list from top to bottom")
    XRD_TestCheck(WaveExists(TraceNameToWaveRef("XRDWorkbench#Pattern","XRDWB_Measured")),"live stack keeps native active measured cursor target")
    Wave refY=$(project+":LivePanel:refY0")
    XRD_TestCheck(refY[0]==135 && numtype(refY[2])==2,"reference sticks start at each sample baseline with separated segments")
    XRD_ResetView()
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_min==-30 && V_max==275,"live reset includes all sample rows and headroom")
    XRD_ZoomSelectedPeak()
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 1011
    SetWindow XRDWorkbench#Pattern userdata(TestSentinel)="kept"
    XRD_TestCheck(XRD_OpenReview()==0,"detached live comparison opens")
    SetWindow XRDReviewGraph userdata(TestSentinel)="kept"
    XRD_ScoreCandidates(second,1)
    XRD_TestCheck(XRD_V70Adopt(second,1,1)==0,"other sample can be identified while live views exist")
    XRD_RequestLive();XRD_LiveDeferred()
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:UI:liveLastError",-1)==0,"coalesced live refresh completes without runtime error")
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench#Pattern","","TestSentinel"),"kept")==0 && cmpstr(GetUserData("XRDReviewGraph","","TestSentinel"),"kept")==0,"refresh reuses both native graph windows")
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==1011,"live refresh restores native cursor point")
    String recreation=WinRecreation("XRDWorkbench#Pattern",0)
    XRD_TestCheck(strsearch(recreation,"noLabel(left)=1",0)>=0 && strsearch(recreation,"Intensity (arb. units)",0)>=0 && strsearch(recreation,"Cu-K",0)>=0,"repeated refresh retains hidden y numbers and both scientific axis labels")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-25.11)<1e-8 && abs(V_max-35.11)<1e-8,"live refresh preserves angular zoom")
    XRD_TestCheck(ItemsInList(TraceNameList("XRDReviewGraph",";",1))>=8,"live review includes both adopted symbols and reference sticks")
    XRD_MarkGraphsStale()
    XRD_TestCheck(WhichListItem("XRDNeedsUpdate",AnnotationList("XRDReviewGraph"))<0,"live views do not show stale completed-figure warning")
    XRD_ReviewGuide(1)
    XRD_TestCheck(strlen(GetUserData("XRDReviewGraph","","XRDReferenceAngle"))>0,"review zoom preserves selected reference arrow")
    Variable before=NumVarOrDefault("root:Packages:XRDWorkbench:UI:liveRunCount",0)
    XRD_RequestLive();XRD_RequestLive();XRD_RequestLive();XRD_LiveDeferred()
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:UI:liveRunCount",0)==before+1 && NumVarOrDefault("root:Packages:XRDWorkbench:UI:livePending",1)==0 && NumVarOrDefault("root:Packages:XRDWorkbench:UI:liveBusy",1)==0,"repeated live requests coalesce and release pending busy guards")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"live_identification_v071.png"
    SavePICT/O/E=-5/SNAP=1/WIN=XRDReviewGraph as output+"live_review_v071.png"
    Variable/G $(project+":liveCompare")=0
    XRD_Panel()
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench#Pattern","","XRDCompare"),"1")!=0,"single sample graph can be restored without losing tables")
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_min==-30 && V_max==110,"single graph does not inherit stacked intensity range")
    XRD_TestCheck(WaveCRC(0,raw)==crc && WaveCRC(0,rawX)==xcrc,"live detection identification and view operations preserve Raw")
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:UI:liveBusy",1)==0,"no live refresh guard remains held")
    XRD_CreateEditableGraph()
    String final=WinName(0,1),snapshot=GetUserData(final,"","XRDGraphData")
    Wave finalY=$(snapshot+":intensity")
    Variable finalCRC=WaveCRC(0,finalY)
    Variable/G $(project+":liveCompare")=1
    XRD_Panel()
    active=second
    Variable/G $(second+":selectedPeakRow")=1
    XRD_Panel();XRD_RequestLive();XRD_LiveDeferred()
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench#Pattern","","XRDData"),second)==0 && cmpstr(GetUserData("XRDReviewGraph","","XRDData"),second)==0,"measurement switch updates active sample in both live views")
    Wave activeY=TraceNameToWaveRef("XRDWorkbench#Pattern","XRDWB_Measured")
    XRD_TestCheck(activeY[0]==bottom[0],"native cursor target is rebound to newly active measured sample")
    XRD_ClearPeakReview(second,1);XRD_RequestLive();XRD_LiveDeferred()
    XRD_TestCheck(WhichListItem("Data2_Phase1",TraceNameList("XRDWorkbench#Pattern",";",1))<0,"clearing identification removes marker in live stack")
    XRD_TestCheck(WaveCRC(0,finalY)==finalCRC && WhichListItem("XRDNeedsUpdate",AnnotationList(final))>=0,"live edits preserve completed figure snapshot and mark it stale")
    String third=XRD_Store(xx,yy,"sample C.xy")
    XRD_Panel();XRD_RequestLive();XRD_LiveDeferred()
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_max==410 && cmpstr(GetUserData("XRDReviewGraph","","XRDPlotCount"),"3")==0,"adding measurement reflows live sample count and full stack height")
    XRD_DeleteMeasurement(third);XRD_Panel();XRD_RequestLive();XRD_LiveDeferred()
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_max==275 && cmpstr(GetUserData("XRDReviewGraph","","XRDPlotCount"),"2")==0,"deleting measurement reflows both live views without gaps")
    active=path
    Variable/G $(path+":followPeak")=1
    XRD_Panel()
    Variable/G root:Packages:XRDWorkbench:UI:livePending=1
    SaveExperiment/C/F={1,"",0} as output+"live_settings.pxp"
    Variable/G root:Packages:XRDWorkbench:UI:livePending=0
    XRD_TestCheck(GetRTError(1)==0,"all focus and live operations leave no native runtime error")
    NVAR failures=root:XRDTestFailures
    Print "v071 feature failures="+num2istr(failures)
End

Function XRD_V71Persistence(saved)
    String saved
    // LoadData restores data only; discard windows from earlier isolated test fixtures.
    DoWindow/K XRDWorkbench
    DoWindow/K XRDReviewGraph
    LoadData/O/Q/R saved
    XRD_Init();XRD_Open()
    String path=XRD_Data(),project=XRD_Project()
    XRD_TestCheck(NumVarOrDefault(project+":liveCompare",0)==1 && NumVarOrDefault(path+":followPeak",0)==1,"live and follow preferences survive saved experiment data reload")
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench#Pattern","","XRDCompare"),"1")==0,"reopening saved project restores live stack with tables")
    XRD_LiveDeferred()
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:UI:livePending",1)==0 && NumVarOrDefault("root:Packages:XRDWorkbench:UI:liveBusy",1)==0,"reopening clears saved pending guard and refreshes normally")
    XRD_TestCheck(GetRTError(1)==0,"live settings reload leaves no native runtime error")
End

Function XRD_V71Screens(output)
    String output
    String project=XRD_Project(),path=XRD_Data()
    NVAR step=$(project+":activeStep"),selected=$(path+":selectedPeakRow")
    selected=0;step=1
    XRD_Panel()
    MoveWindow/W=XRDWorkbench 10,10,1410,850
    XRD_ResizePanel();XRD_ResetView()
    ListBox peakList,win=XRDWorkbench,selRow=0
    XRD_SelectedPeakGuide(path)
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"detection_large_v071.png"
    step=2;XRD_Panel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"references_large_v071.png"
    step=3
    Variable/G $(project+":liveCompare")=1
    XRD_ScoreCandidates(path,0)
    XRD_PreviewCandidate(path,XRD_V71Candidate(path,1,1))
    XRD_Panel();XRD_ResetView()
    Variable/G $(path+":followPeak")=1
    ControlUpdate/W=XRDWorkbench followPeak
    XRD_RequestLive();XRD_LiveDeferred()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"live_large_v071.png"
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 1011
    SetWindow XRDWorkbench userdata(XRDUIVersion)="0.7.0"
    XRD_Open()
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench","","XRDUIVersion"),"0.7.1")==0,"opening old saved Workbench window migrates UI to current controls")
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==1011,"UI version migration preserves native measured cursor")
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_max==275,"enlarged live panel and migrated view retain full stacked range")
    XRD_TestCheck(GetRTError(1)==0,"large screen rendering and UI migration leave no runtime error")
End

Function XRD_V71QueueStart(fixtures,output)
    String fixtures,output
    XRD_Init();XRD_NewProject()
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_LoadReferenceFile("QS-A.txt",1)
    Make/FREE/D/N=4001 xx=20+0.01*p,yy=2+100*exp(-((xx[p]-30.11)/0.07)^2)+60*exp(-((xx[p]-44)/0.07)^2)
    String path=XRD_Store(xx,yy,"live queue A.xy"),other
    XRD_Manual(path,30.11);XRD_Manual(path,44)
    other=XRD_Store(xx,yy,"live queue B.xy")
    XRD_Manual(other,30.11);XRD_Manual(other,44)
    SVAR active=$(XRD_Project()+":activeData")
    active=path
    Variable/G $(XRD_Project()+":activeStep")=3
    Variable/G $(XRD_Project()+":liveCompare")=1
    XRD_ScoreCandidates(path,0)
    XRD_Panel();XRD_OpenReview()
    XRD_ZoomSelectedPeak()
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 1011
    XRD_PreviewCandidate(path,XRD_V71Candidate(path,1,1))
    XRD_ScoreCandidates(other,1)
    XRD_V70Adopt(other,1,1)
    SetWindow XRDReviewGraph userdata(QueueSentinel)="kept"
    String/G root:XRDV71QueueOutput=output
    Variable/G root:XRDV71QueueStage=0
    Variable/G root:XRDV71QueueHistory=CaptureHistoryStart()
    CtrlNamedBackground XRDV71Queue,proc=XRD_V71QueueCheck,period=60,start=(ticks+60)
End

Function XRD_V71QueueCheck(s)
    STRUCT WMBackgroundStruct &s
    NVAR stage=root:XRDV71QueueStage
    String path=XRD_Data(),base="root:Packages:XRDWorkbench:UI:"
    if(stage==0)
        XRD_TestCheck(NumVarOrDefault(base+"liveLastError",-1)==0 && NumVarOrDefault(base+"livePending",1)==0 && NumVarOrDefault(base+"liveBusy",1)==0,"real queued live refresh reaches idle without error")
        XRD_TestCheck(WhichListItem("Data2_Phase1",TraceNameList("XRDWorkbench#SideCompare",";",1))>=0 && WhichListItem("Data2_Phase1",TraceNameList("XRDReviewGraph",";",1))>=0,"queued assignment appears in side and detached live views")
        XRD_TestCheck(abs(str2num(GetUserData("XRDReviewGraph","","XRDReferenceAngle"))-30.38)<1e-8,"queued candidate change updates exact selected reflection arrow")
        XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==1011,"real queued live redraw retains native cursor")
        Variable/G root:XRDV71QueueRuns=NumVarOrDefault(base+"liveRunCount",0)
        stage=1
        return 0
    elseif(stage==1)
        XRD_TestCheck(NumVarOrDefault(base+"liveRunCount",0)==NumVarOrDefault("root:XRDV71QueueRuns",-1),"idle live view does not enter recurring redraw loop")
        Variable/G $(path+":selectedPeakRow")=1
        XRD_SelectedPeakGuide(path)
        XRD_ScoreCandidates(path,1)
        stage=2
        return 0
    endif
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-39)<1e-8 && abs(V_max-49)<1e-8,"native queued selection follows selected measured peak")
    XRD_TestCheck(cmpstr(GetUserData("XRDReviewGraph","","QueueSentinel"),"kept")==0,"native queued updates keep existing detached graph")
    XRD_TestCheck(NumVarOrDefault(base+"livePending",1)==0 && NumVarOrDefault(base+"liveBusy",1)==0 && GetRTError(1)==0,"queue and runtime guards are released after repeated changes")
    NVAR history=root:XRDV71QueueHistory
    SVAR output=root:XRDV71QueueOutput
    String log=CaptureHistory(history,1)
    Variable file
    Open file as output+"queue_result.txt"
    fprintf file,"%s",log
    Close file
    Execute/P "Quit/N"
    return 1
End
