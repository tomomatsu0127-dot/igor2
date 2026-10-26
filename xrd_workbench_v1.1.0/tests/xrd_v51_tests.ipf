#pragma rtGlobals=3
// v0.5.1 isolated tests: supplied reference, actual annotation bounds, mixed history.
Function XRD_RunV51Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_NewProject()
    XRD_RecoverySettings()
    NVAR enabled=root:Packages:XRDWorkbench:Recovery:enabled
    XRD_TestCheck(enabled==0,"new version disables automatic saving on migration")
    Variable/G root:Packages:XRDWorkbench:Recovery:policy51=0
    enabled=1
    STRUCT WMBackgroundStruct restoredTimer
    XRD_TestCheck(XRD_AutoSaveTask(restoredTimer)==1 && enabled==0 && NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:queued",1)==0,"restored old timer applies OFF migration before it can queue a save")
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_TestCheck(XRD_LoadReferenceFile("gamma_CFF_Ca2Fe16O25_idealized.txt",1)==0,"supplied structure-factor table imports without editing")
    Wave tt=$(XRD_ReferencePath(1)+":twoTheta"),ii=$(XRD_ReferencePath(1)+":intensity"),hh=$(XRD_ReferencePath(1)+":h"),kk=$(XRD_ReferencePath(1)+":k"),ll=$(XRD_ReferencePath(1)+":l"),dd=$(XRD_ReferencePath(1)+":d")
    XRD_TestCheck(numpnts(tt)>100 && tt[0]==5.60736 && ii[0]==25.90135 && dd[0]==15.748,"provided 2theta intensity and d map to exact columns")
    Variable i,found=0
    for(i=0;i<numpnts(tt);i+=1)
        if(hh[i]==-1 && kk[i]==-1 && ll[i]==3 && ii[i]==100)
            found=1
        endif
    endfor
    XRD_TestCheck(found,"negative Miller indices and coincident reflections retained")
    XRD_TestCheck(XRD_LoadReferenceFile("extra_columns.csv",2)==0,"CSV with quoted unit headers and extra text column imports")
    XRD_TestCheck(XRD_LoadReferenceFile("comment_header.tsv",3)==0,"commented header with d unit and tabs imports")
    XRD_TestCheck(XRD_LoadReferenceFile("alias_units.dat",4)==0,"DAT aliases and attached units import")
    Make/FREE/D/N=6 map,values
    String error=""
    Variable n=XRD_MapReferenceHeader("h k l d (Å) F(real) F(imag) |F| 2θ I M",map,error)
    XRD_TestCheck(n==10 && map[3]==8 && map[4]==7 && map[5]==3,"unit suffix does not shift ten-column mapping")
    n=XRD_MapReferenceHeader("h k l tt F(real) |F| M",map,error)
    XRD_TestCheck(n<0 && strsearch(error,"intensity",0)>=0,"never substitute structure factor or multiplicity for intensity")
    n=XRD_MapReferenceHeader("h k l tt I extra",map,error)
    XRD_TestCheck(n==6 && XRD_ParseMappedReferenceRow("1 0 -2 30 100 note",n,map,values,error)==1,"named extra text columns ignored while required values validated")
    XRD_TestCheck(XRD_ParseMappedReferenceRow("1 0 -2 30 broken note",n,map,values,error)<0,"bad required intensity remains rejected")
    XRD_TestCheck(XRD_LoadReferenceFile("missing_required.csv",5)<0 && NumVarOrDefault(XRD_Project()+":referenceCount",0)==4,"missing required column cannot partially register a card")
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=5+100*exp(-((xx[p]-31)/0.08)^2)+40*exp(-((xx[p]-40)/0.08)^2)
    String path=XRD_Store(xx,yy,"v051_synthetic.xy"),project=XRD_Project()
    XRD_DetectLegacy(path)
    XRD_TestDisableFollow()
    XRD_Panel()
    NVAR count=$(project+":Undo:count"),seq=$(project+":Undo:sequence")
    count=0;seq=0
    XRD_ViewSync(path)
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    Variable initialMin=V_min,initialMax=V_max
    XRD_TestCheck(initialMax>initialMin && initialMin<=20 && initialMax>=70,"initial automatic axes are calculated before capturing history")
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 220
    SetAxis/W=XRDWorkbench#Pattern bottom 30,35
    XRD_TestCheck(XRD_RecordPendingZoom(path)==1 && count==1,"zoom appends one chronological undo action")
    XRD_TestCheck(XRD_RecordPendingZoom(path)==0 && count==1,"duplicate modified event does not append duplicate zoom")
    Wave peaks=$(path+":Peaks:angle")
    Variable before=numpnts(peaks)
    XRD_Manual(path,33)
    XRD_TestCheck(count==2 && numpnts(peaks)==before+1,"analysis edit follows zoom in the same history")
    XRD_Undo()
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(numpnts(peaks)==before && V_min==30 && V_max==35,"first undo removes peak and retains zoom")
    XRD_Undo()
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==initialMin && V_max==initialMax && numpnts(peaks)==before,"second undo restores previous axes without changing peaks")
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==220,"view undo preserves native cursor")
    XRD_Redo()
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==30 && V_max==35,"redo restores zoom range")
    XRD_Redo()
    XRD_TestCheck(numpnts(peaks)==before+1,"redo restores analysis after zoom")
    NVAR step=$(project+":activeStep")
    step=3
    XRD_TestDisableFollow()
    XRD_Panel()
    ControlInfo/W=XRDWorkbench matchTolerance
    XRD_TestCheck(V_flag==0,"advanced matching controls leave permanent sidebar")
    Variable/G $(project+":detailControls")=1
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_MatchSettingsPanel()
    ControlInfo/W=XRDMatchSettings matchTolerance
    XRD_TestCheck(V_disable==0 && V_flag!=0,"advanced matching controls remain available in condition sheet")
    DoWindow/K XRDMatchSettings
    XRD_QuickGuide()
    XRD_TestCheck(WinType("XRDGuide")==5,"beginner guide opens inside Igor")
    DoWindow/K XRDGuide
    NVAR refs=$(project+":referenceCount")
    String rp,labels="NiFe₂O₄;MgFe₂₃₊O₄;Ca₂Fe₁₆O₂₅;CoFe₂O₄;CaCO₃;Cu(OH)₂"
    for(i=1;i<=6;i+=1)
        rp=XRD_ReferencePath(i)
        if(i>refs)
            DuplicateDataFolder $(XRD_ReferencePath(1)),$rp
        endif
        String/G $(rp+":styleGroup")=StringFromList(i-1,labels)
    endfor
    refs=6
    Wave ids=$(path+":Peaks:peakID"),ar=$(path+":Assignments:refIndex"),aid=$(path+":Assignments:peakID"),rows=$(path+":Assignments:refPeakIndex")
    Redimension/N=6 ar,aid,rows
    ar=p+1;aid=ids[0];rows=0
    XRD_CreateEditableGraph()
    String win=WinName(0,1),info=AnnotationInfo(win,"Phases",1),rect=StringByKey("RECT",info)
    Variable l,t,r,b
    sscanf rect,"%g,%g,%g,%g",l,t,r,b
    GetWindow $win gsize
    XRD_TestCheck(l>=-1 && t>=-1 && r<=V_right+1 && b<=V_bottom+1,"long-formula legend rectangle stays within complete canvas")
    XRD_TestCheck(strsearch(info,"\\Z24",0)>=0 && NumVarOrDefault(project+":graphSerial",0)>0,"native 24 point legend remains editable")
    XRD_TestCheck(str2num(GetUserData(win,"","XRDLegendRows"))>=3,"long entries wrap by available width instead of three per row")
    SavePICT/O/E=-5/WIN=$win as output+"single_long_v051.png"
    GetWindow $win psize
    Variable width=V_right-V_left,height=V_bottom-V_top
    ModifyGraph/W=$win expand=0.5
    GetWindow $win psize
    XRD_TestCheck(abs(V_right-V_left-width)<0.01 && abs(V_bottom-V_top-height)<0.01,"onscreen magnification preserves physical plot dimensions")
    SavePICT/O/E=-5/WIN=$win as output+"single_half_v051.png"
    XRD_FigurePanel()
    XRD_TestCheck(WinType("XRDFigureSettings")==7,"native figure adjustment panel opens")
    Variable/G root:Packages:XRDWorkbench:UI:figureWidth=410
    XRD_TestCheck(XRD_ApplyFigureSettings()==0,"explicit figure settings apply to selected graph")
    GetWindow $win psize
    XRD_TestCheck(abs(str2num(GetUserData(win,"","XRDFigureWidth"))-410)<1,"figure width can be edited after creation in native resize mode")
    Legend/W=$win/C/N=Phases "\\Z18Manual legend"
    ModifyGraph/W=$win width=455
    XRD_RefreshStyles()
    XRD_TestCheck(strsearch(AnnotationInfo(win,"Phases",1),"Manual legend",0)>=0 && strsearch(WinRecreation(win,0),"width=455",0)>=0,"shared marker changes preserve manually edited legend and graph width")
    SetWindow $win userdata(XRDFigureWidth)=""
    SetWindow $win userdata(XRDFigureHeight)=""
    XRD_ReadFigureSettings(win)
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:UI:figureWidth",0)>200 && NumVarOrDefault("root:Packages:XRDWorkbench:UI:figureHeight",0)>150,"pre-v051 graphs without layout metadata can use adjustment panel")
    String second=XRD_Store(xx,yy,"v051_second.xy")
    XRD_DetectLegacy(second)
    DuplicateDataFolder/O=2 $(path+":Peaks"),$(second+":Peaks")
    DuplicateDataFolder/O=2 $(path+":Assignments"),$(second+":Assignments")
    XRD_CreateStackGraph()
    String stackWin=WinName(0,1)
    String stackInfo=AnnotationInfo(stackWin,"Phases",1),stackRect=StringByKey("RECT",stackInfo)
    sscanf stackRect,"%g,%g,%g,%g",l,t,r,b
    GetWindow $stackWin gsize
    XRD_TestCheck(l>=-1 && t>=-1 && r<=V_right+1 && b<=V_bottom+1,"stack graph with long formulas reserves full legend canvas")
    SavePICT/O/E=-5/WIN=$stackWin as output+"stack_long_v051.png"
    XRD_TestCheck(GetRTError(1)==0,"new UI graph and history paths leave no runtime error")
    XRD_SaveSettingsPanel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDSaveSettings as output+"save_settings_v051.png"
    DoWindow/K XRDFigureSettings
    DoWindow/K XRDSaveSettings
    Variable/G $(project+":detailControls")=0
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"workbench_v051.png"
    NVAR failures=root:XRDTestFailures
    Print "v0.5.1 tests failures="+num2str(failures)
    return failures
End

Function XRD_V51FiveMinuteStart(output)
    String output
    XRD_Init()
    XRD_NewProject()
    Make/FREE/D/N=200001 xx=20+50*p/200000,yy=5+100*exp(-((xx[p]-31)/0.08)^2)
    String path=XRD_Store(xx,yy,"five_minute_synthetic.xy")
    XRD_DetectLegacy(path)
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_RecoverySettings()
    NewPath/O/Q XRDAutoSaveCustomPath,output
    String/G root:XRDTimerOutput=output
    Variable/G root:XRDTestFailures=0
    Variable/G root:XRDTimerHistory=CaptureHistoryStart()
    Variable/G root:XRDTimerDeadline=ticks+360*60
    NVAR enabled=root:Packages:XRDWorkbench:Recovery:enabled,minutes=root:Packages:XRDWorkbench:Recovery:minutes
    enabled=1;minutes=5
    XRD_StartAutoSave()
    CtrlNamedBackground XRDLongVerifier,proc=XRD_V51FiveMinuteVerify,period=60,start=(ticks+60)
End

Function XRD_V51FiveMinuteVerify(s)
    STRUCT WMBackgroundStruct &s
    NVAR generation=root:Packages:XRDWorkbench:Recovery:generation,deadline=root:XRDTimerDeadline
    if(generation<1 && ticks<deadline)
        return 0
    endif
    CtrlNamedBackground XRDAutoSave,stop
    XRD_TestCheck(generation>=1,"real five minute timer completes queued recovery on 200001 point experiment")
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:saving",1)==0,"foreground save guard released after real five minute timer")
    NVAR history=root:XRDTimerHistory
    SVAR output=root:XRDTimerOutput
    String log=CaptureHistory(history,1)
    Variable ref
    Open ref as output+"five_minute_result.txt"
    fprintf ref,"%s",log
    Close ref
    Execute/P "Quit/N"
    return 1
End

Function XRD_V51StressStart(output)
    String output
    XRD_V51FiveMinuteStart(output)
    CtrlNamedBackground XRDLongVerifier,stop
    String path=XRD_Data()
    Variable i
    for(i=0;i<12;i+=1)
        SetAxis/W=XRDWorkbench#Pattern bottom 30,35
        XRD_RecordPendingZoom(path)
        XRD_Manual(path,33)
        XRD_Undo()
        XRD_Undo()
        XRD_Redo()
        XRD_Redo()
        XRD_Delete(path,1)
    endfor
    Variable/G root:XRDTimerDeadline=ticks+900
    CtrlNamedBackground XRDAutoSave,period=12,start=(ticks+12)
    CtrlNamedBackground XRDQueueVerifier,proc=XRD_V51StressVerify,period=60,start=(ticks+60)
End

Function XRD_V51StressVerify(s)
    STRUCT WMBackgroundStruct &s
    NVAR generation=root:Packages:XRDWorkbench:Recovery:generation,deadline=root:XRDTimerDeadline
    if(generation<3 && ticks<deadline)
        return 0
    endif
    // Use the product's OFF path, which cancels an already queued next copy.
    Variable/G root:Packages:XRDWorkbench:Recovery:enabled=0
    XRD_StartAutoSave()
    XRD_TestCheck(generation>=3,"view observer and repeated mixed history do not starve queued saves")
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:busy",1)==0 && NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:queued",1)==0,"queued save releases busy and pending state")
    String copies=IndexedFile(XRDAutoSavePath,-1,".pxp")
    XRD_TestCheck(ItemsInList(copies)==3,"large experiment and repeated view history retain three copies")
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench","","XRDViewPending"),"1")!=0,"view observer reaches idle rather than continuously requeueing itself")
    XRD_TestCheck(GetRTError(1)==0,"combined timer view and undo redo leave no runtime error")
    SVAR output=root:XRDTimerOutput
    NVAR history=root:XRDTimerHistory
    Variable ref
    String log=CaptureHistory(history,1)
    Open ref as output+"stress_result.txt"
    fprintf ref,"%s",log
    Close ref
    Execute/P "Quit/N"
    return 1
End
