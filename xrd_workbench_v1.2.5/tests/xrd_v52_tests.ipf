#pragma rtGlobals=3
// v0.5.2 isolated regression tests. Synthetic measurements only.
Function XRD_RunV52Tests(samples,output)
    String samples,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    XRD_NewProject()
    String project=XRD_Project()
    NewPath/O/Q XRDReferencePath,samples
    XRD_LoadReferences()
    Make/FREE/D/N=5001 xx=20+0.01*p,yy=5+100*exp(-((xx[p]-30.1)/0.08)^2)+40*exp(-((xx[p]-35.42)/0.08)^2)
    String first=XRD_Store(xx,yy,"first.xy")
    XRD_Manual(first,30.1)
    XRD_Manual(first,30.2)
    XRD_Manual(first,35.42)
    NVAR selected=$(first+":selectedPeakRow"),candidate=$(first+":selectedCandidateRow"),step=$(project+":activeStep")
    selected=0;step=3
    XRD_ScoreCandidates(first,0)
    Wave cr=$(first+":Candidates:refIndex"),cp=$(first+":Candidates:refPeakIndex"),cs=$(first+":Candidates:shift")
    Variable refIndex=cr[0],refRow=cp[0]
    XRD_TestCheck(XRD_AssignCandidate(first,0,0,0)==0,"first measured peak adopts reference reflection")
    // Freeze a candidate pair to exercise the core guard independently of ranking.
    cr[0]=refIndex;cp[0]=refRow;cs[0]=0
    XRD_SetUnknown(first,1)
    cr[0]=refIndex;cp[0]=refRow;cs[0]=0
    Wave aid=$(first+":Assignments:peakID"),ar=$(first+":Assignments:refIndex"),ap=$(first+":Assignments:refPeakIndex"),ids=$(first+":Peaks:peakID")
    Variable count=numpnts(aid),crc=WaveCRC(0,aid),history=NumVarOrDefault(project+":Undo:sequence",-1)
    XRD_TestCheck(XRD_AssignCandidate(first,1,0,0)==-2,"duplicate reflection is rejected before replacement")
    XRD_TestCheck(numpnts(aid)==count && WaveCRC(0,aid)==crc && ar[1]==0,"rejected replacement retains old Unknown and original assignment")
    XRD_TestCheck(NumVarOrDefault(project+":Undo:sequence",-2)==history,"rejected duplicate does not add Undo entry")
    XRD_TestCheck(XRD_AssignCandidate(first,1,0,1)==-2,"overlap path also rejects reuse by another measured peak")
    XRD_TestCheck(XRD_ReferencePeakOwner(first,refIndex,refRow,ids[1])==0,"conflict identifies owning measured peak")
    XRD_TestCheck(XRD_AssignCandidate(first,0,0,0)==0,"same measured peak may re-adopt its own reflection")
    XRD_ScoreCandidates(first,2)
    XRD_TestCheck(XRD_AssignCandidate(first,2,0,0)==0,"different reference reflection can be assigned")
    XRD_ClearPeakReview(first,0)
    XRD_ScoreCandidates(first,1)
    cr[0]=refIndex;cp[0]=refRow;cs[0]=0
    XRD_TestCheck(XRD_AssignCandidate(first,1,0,0)==0,"released reflection can be assigned to another measured peak")

    String second=XRD_Store(xx,yy,"second.xy"),third=XRD_Store(xx,yy,"third.xy")
    XRD_Manual(second,30.1)
    XRD_ScoreCandidates(second,0)
    XRD_TestCheck(XRD_AssignCandidate(second,0,0,0)==0,"another measurement may use the same reference reflection")
    XRD_BuildMeasurementTable(project)
    Wave/T table=$(project+":measurementTable")
    XRD_TestCheck(cmpstr(table[0][0],"Data1")==0 && cmpstr(table[2][0],"Data3")==0,"completion table follows stored measurement order")
    XRD_CreateStackGraph()
    String win=WinName(0,1),rootPath=GetUserData(win,"","XRDGraphData")
    Wave y0=$(rootPath+":intensity0"),y1=$(rootPath+":intensity1"),y2=$(rootPath+":intensity2")
    Variable spacing=100+max(20,min(50,NumVarOrDefault(project+":stackGap",0)))
    XRD_TestCheck(abs(y0[0]-y1[0]-spacing)<1e-8 && abs(y1[0]-y2[0]-spacing)<1e-8,"first table row is top trace; all three follow top-to-bottom order")
    String marker=CleanupName("Data2_Phase"+num2istr(refIndex),0)
    Wave/Z markerY=$(rootPath+":"+marker+"Y")
    Wave py=$(second+":Peaks:height")
    XRD_TestCheck(WaveExists(markerY) && abs(markerY[0]-py[0]-spacing)<1e-8,"phase marker shares its measured trace offset")
    DoUpdate/W=$win
    String a0=AnnotationInfo(win,"Condition1",1),a2=AnnotationInfo(win,"Condition3",1)
    XRD_TestCheck(NumberByKey("ABSY",a0)<NumberByKey("ABSY",a2),"condition labels follow the same top-to-bottom order")
    SavePICT/O/E=-5/WIN=$win as output+"stack_order_v052.png"
    NVAR visible=$(second+":visibleInStack")
    visible=0
    XRD_CreateStackGraph()
    win=WinName(0,1);rootPath=GetUserData(win,"","XRDGraphData")
    Wave hy0=$(rootPath+":intensity0"),hy2=$(rootPath+":intensity2")
    XRD_TestCheck(abs(hy0[0]-hy2[0]-spacing)<1e-8,"hidden measurement leaves no gap or reversed stack")
    visible=1
    XRD_MoveMeasurement(third,-1)
    XRD_MoveMeasurement(third,-1)
    XRD_BuildMeasurementTable(project)
    XRD_CreateStackGraph()
    win=WinName(0,1);rootPath=GetUserData(win,"","XRDGraphData")
    Wave/T conditions=$(rootPath+":conditions")
    XRD_TestCheck(cmpstr(table[0][0],"Data3")==0 && strsearch(conditions[0],"third.xy",0)>=0,"moving measurement up changes graph and condition order together")

    SVAR active=$(project+":activeData")
    active=first
    XRD_ClearPeakReview(first,1)
    selected=0;step=3
    XRD_ScoreCandidates(first,0)
    XRD_TestDisableFollow()
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 29,36
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 1010
    STRUCT WMListboxAction lba
    lba.eventCode=4;lba.row=0
    count=numpnts(aid)
    XRD_CandidateListAction(lba)
    XRD_TestCheck(numpnts(aid)==count && cmpstr(GetUserData("XRDWorkbench","","XRDAdoptPending"),"1")!=0,"single click previews without adoption")
    lba.eventCode=3
    XRD_CandidateListAction(lba)
    XRD_TestCheck(numpnts(aid)==count && cmpstr(GetUserData("XRDWorkbench","","XRDAdoptPending"),"1")==0,"double click queues adoption without rebuilding inside callback")
    XRD_TestCheck(XRD_QueueCandidateAdoption(first,0)==0,"repeated double click coalesces while pending")
    XRD_AdoptDeferred()
    XRD_TestCheck(selected==1 && numpnts(aid)==count+1,"deferred adoption assigns clicked candidate and advances one measured peak")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==29 && V_max==36 && pcsr(A,"XRDWorkbench#Pattern")==1010,"double click adoption preserves zoom and standard Ctrl I cursor")
    count=numpnts(aid)
    XRD_AdoptDeferred()
    XRD_TestCheck(numpnts(aid)==count,"already processed deferred action cannot adopt twice")
    XRD_QueueCandidateAdoption(first,0)
    selected=2
    XRD_AdoptDeferred()
    XRD_TestCheck(numpnts(aid)==count,"changing measured peak cancels stale double click")
    selected=1
    XRD_ScoreCandidates(first,1)
    XRD_QueueCandidateAdoption(first,0)
    active=second
    XRD_AdoptDeferred()
    XRD_TestCheck(numpnts(aid)==count,"changing measurement cancels stale double click")
    active=first
    String before=GetUserData("XRDWorkbench","","XRDData")
    XRD_Open()
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(cmpstr(before,GetUserData("XRDWorkbench","","XRDData"))==0 && V_min==29 && V_max==36 && pcsr(A,"XRDWorkbench#Pattern")==1010,"quick open focuses existing workbench without rebuilding or clearing cursor")

    XRD_CreateEditableGraph()
    win=WinName(0,1)
    XRD_TestCheck(cmpstr(GetUserData(win,"","XRDFlexible"),"1")==0 && strsearch(WinRecreation(win,0),"XRD_FigureHook",0)>=0,"completed graph uses native automatic dimensions and persistent resize hook")
    GetWindow $win psize
    Variable w=V_right-V_left,h=V_bottom-V_top
    GetWindow $win wsize
    Variable left=V_left,top=V_top,right=V_right,bottom=V_bottom
    MoveWindow/W=$win left,top,right+160,bottom
    DoUpdate/W=$win
    XRD_FigureResized(win)
    GetWindow $win psize
    XRD_TestCheck(V_right-V_left>w+100 && abs(V_bottom-V_top-h)<1,"native horizontal resize changes width independently")
    MoveWindow/W=$win left,top,right+160,bottom+100
    DoUpdate/W=$win
    XRD_FigureResized(win)
    GetWindow $win psize
    XRD_TestCheck(V_bottom-V_top>h+70,"native vertical resize changes height independently")
    GetAxis/W=$win/Q bottom
    XRD_TestCheck(V_min==20 && V_max==70 && strsearch(AnnotationInfo(win,"Phases",1),"\\Z24",0)>=0,"resizing retains axis ranges and 24 point legend")
    XRD_TestCheck(strsearch(WinRecreation(win,0),"gfSize=24",0)>=0,"resizing retains 24 point axis text")
    SavePICT/O/E=-5/WIN=$win as output+"single_resized_v052.png"
    Legend/W=$win/C/N=Phases "\\Z20My custom legend"
    MoveWindow/W=$win left,top,right+200,bottom+130
    DoUpdate/W=$win
    XRD_FigureResized(win)
    XRD_TestCheck(strsearch(AnnotationInfo(win,"Phases",1),"My custom legend",0)>=0 && strsearch(AnnotationInfo(win,"Phases",1),"\\Z20",0)>=0,"resize preserves manually edited legend content and font")
    XRD_TestCheck(cmpstr(GetUserData(win,"","XRDFigurePending"),"1")!=0,"resize observer releases queue guard")
    SetWindow $win userdata(XRDFlexible)="0"
    SetWindow $win sizeLimit={0,0,inf,inf}
    ModifyGraph/W=$win width=420,height=300
    XRD_FigurePanel()
    STRUCT WMButtonAction button
    button.eventCode=2;button.ctrlName="dragFigure"
    XRD_V51Button(button)
    XRD_TestCheck(cmpstr(GetUserData(win,"","XRDFlexible"),"1")==0 && strsearch(AnnotationInfo(win,"Phases",1),"My custom legend",0)>=0,"existing fixed-size figure can enable drag without losing handwritten legend")
    DoWindow/K XRDFigureSettings
    // Nonzero shifts must survive the queue without decimal rounding.
    selected=2
    XRD_ClearPeakReview(first,2)
    XRD_ScoreCandidates(first,2)
    XRD_TestDisableFollow()
    XRD_Panel()
    cs[0]=0.0123456789012345
    XRD_QueueCandidateAdoption(first,0)
    XRD_TestCheck(abs(str2num(GetUserData("XRDWorkbench","","XRDAdoptShift"))-cs[0])<1e-15,"queued nonzero shift retains full precision")
    XRD_AdoptDeferred()
    Wave shifts=$(first+":Assignments:shift")
    XRD_TestCheck(abs(shifts[numpnts(shifts)-1]-0.0123456789012345)<1e-15,"nonzero-shift double click adopts captured reflection")
    // Exercise long legends and a different active project.
    NVAR refCount=$(project+":referenceCount")
    String rp,labels="NiFe2O4;MgFe2O4;Ca2Fe16O25;CoFe2O4;CaCO3;Cu(OH)2"
    Variable i
    for(i=1;i<=6;i+=1)
        rp=XRD_ReferencePath(i)
        if(i>refCount)
            DuplicateDataFolder $(XRD_ReferencePath(1)),$rp
        endif
        String/G $(rp+":styleGroup")=StringFromList(i-1,labels)
    endfor
    refCount=6
    Redimension/N=6 aid,ar,ap
    aid=ids[0];ar=p+1;ap=0
    XRD_CreateEditableGraph()
    win=WinName(0,1)
    GetWindow $win wsize
    left=V_left;top=V_top
    MoveWindow/W=$win left,top,left+600,top+650
    DoUpdate/W=$win
    XRD_FigureResized(win)
    DoUpdate/W=$win
    String rect=StringByKey("RECT",AnnotationInfo(win,"Phases",1))
    Variable rl,rt,rr,rb
    sscanf rect,"%g,%g,%g,%g",rl,rt,rr,rb
    GetWindow $win gsize
    XRD_TestCheck(rl>=-1 && rt>=-1 && rr<=V_right+1 && rb<=V_bottom+1,"long legend remains inside resized native canvas")
    SavePICT/O/E=-5/WIN=$win as output+"long_resized_v052.png"
    GetWindow $win psize
    w=V_right-V_left;h=V_bottom-V_top
    XRD_FigurePanel()
    XRD_TestCheck(abs(NumVarOrDefault("root:Packages:XRDWorkbench:UI:figureWidth",0)-w)<1 && abs(NumVarOrDefault("root:Packages:XRDWorkbench:UI:figureHeight",0)-h)<1,"size panel reads physical dimensions without dividing screen magnification twice")
    DoWindow/K XRDFigureSettings
    XRD_NewProject()
    MoveWindow/W=$win left,top,left+750,top+650
    DoUpdate/W=$win
    XRD_FigureResized(win)
    XRD_TestCheck(strsearch(AnnotationInfo(win,"Phases",1),"NiFe",0)>=0 && strsearch(AnnotationInfo(win,"Phases",1),"Ca",0)>=0,"resizing earlier-project figure retains its own phase names")
    XRD_TestCheck(GetRTError(1)==0,"new assignment and figure paths leave no runtime error")
    NVAR failures=root:XRDTestFailures
    Print "v0.5.2 tests failures="+num2str(failures)
End

Function XRD_V52QueueStart(samples,output)
    String samples,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"queue_live.txt"
    String/G root:XRDQueueOutput=output
    Variable/G root:XRDQueueHistory=CaptureHistoryStart()
    XRD_Init()
    XRD_NewProject()
    NewPath/O/Q XRDReferencePath,samples
    XRD_LoadReferences()
    Make/FREE/D/N=5001 xx=20+0.01*p,yy=5+100*exp(-((xx[p]-30.1)/0.08)^2)+40*exp(-((xx[p]-35.42)/0.08)^2)
    String path=XRD_Store(xx,yy,"queued_double_click.xy")
    XRD_Manual(path,30.1)
    XRD_Manual(path,35.42)
    Variable/G $(XRD_Project()+":activeStep")=3
    Variable/G $(path+":selectedPeakRow")=0
    XRD_ScoreCandidates(path,0)
    XRD_TestDisableFollow()
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 29,36
    STRUCT WMListboxAction lba
    lba.eventCode=3;lba.row=0
    XRD_CandidateListAction(lba)
    Variable/G root:XRDQueueStage=1
    CtrlNamedBackground XRDQueueCheck,proc=XRD_V52QueueCheck,period=60,start=(ticks+60)
End

Function XRD_V52QueueCheck(s)
    STRUCT WMBackgroundStruct &s
    NVAR stage=root:XRDQueueStage
    String path=XRD_Data(),win
    if(stage==1)
        Wave aid=$(path+":Assignments:peakID")
        XRD_TestCheck(numpnts(aid)==1 && NumVarOrDefault(path+":selectedPeakRow",-1)==1,"real deferred double click runs from Igor queue and advances once")
        GetAxis/W=XRDWorkbench#Pattern/Q bottom
        XRD_TestCheck(V_min==29 && V_max==36,"queued callback retains current zoom")
        XRD_CreateEditableGraph()
        win=WinName(0,1)
        String/G root:XRDQueueGraph=win
        GetWindow $win wsize
        Variable l=V_left,t=V_top,r=V_right,b=V_bottom,i
        for(i=0;i<12;i+=1)
            MoveWindow/W=$win l,t,r+10*i,b+5*i
        endfor
        stage=2
        return 0
    endif
    SVAR graph=root:XRDQueueGraph,output=root:XRDQueueOutput
    XRD_TestCheck(cmpstr(GetUserData(graph,"","XRDFigurePending"),"1")!=0,"native resize queue reaches idle after twelve changes")
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench","","XRDAdoptPending"),"1")!=0,"native double click pending flag is released")
    XRD_TestCheck(GetRTError(1)==0,"real deferred callbacks leave no runtime error")
    NVAR history=root:XRDQueueHistory
    String log=CaptureHistory(history,1)
    Variable file
    Open file as output+"queue_result.txt"
    fprintf file,"%s",log
    Close file
    Execute/P "Quit/N"
    return 1
End
