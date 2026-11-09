#pragma rtGlobals=3
// XRD Workbench v0.4.2 isolated runtime regression tests.
Function XRD_RunV42Tests(fixturesPath,outputPath)
    String fixturesPath,outputPath
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_NewProject()
    NewPath/O/Q XRDReferencePath,fixturesPath
    XRD_LoadReferences()
    XRD_ImportFile(fixturesPath+"measurement.xy")
    String project=XRD_Project(),path=XRD_Data(),rp,win,info,second,savedGraph
    NVAR step=$(project+":activeStep"),selectedRef=$(project+":selectedReference")
    XRD_DetectLegacy(path)
    XRD_ScoreCandidates(path,0)
    NVAR selectedCandidate=$(path+":selectedCandidateRow")
    Variable savedCandidate=selectedCandidate
    Wave candidateRefs=$(path+":Candidates:refIndex"),rtt=$(XRD_ReferencePath(2)+":twoTheta")
    Variable candidates=numpnts(candidateRefs)
    rtt[0]=30.5
    step=2
    XRD_TestDisableFollow()
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 30,35
    STRUCT WMListboxAction click
    click.eventCode=4;click.row=1
    XRD_ReferenceSelection(click)
    Wave previewX=$(path+":Preview:angle"),previewY=$(path+":Preview:height")
    XRD_TestCheck(previewX[0]==30.5 && previewY[0]==100,"reference list overlays selected normalized phase")
    XRD_TestCheck(selectedCandidate==savedCandidate && numpnts(candidateRefs)==candidates,"reference preview preserves identification candidates")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==30 && V_max==35,"reference click preserves zoom")
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_TestCheck(previewX[0]==30.5 && selectedRef==1,"reference preview survives refresh")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as outputPath+"references_v042.png"
    step=3
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_TestCheck(previewX[0]!=30.5,"identification tab restores candidate preview")
    XRD_TestCheck(cmpstr(XRD_LegendText("Cu2"),"Cu\\B2\\M")==0,"ASCII formula uses Igor subscripts")
    XRD_TestCheck(cmpstr(XRD_LegendText("CuFe₁₂O₂"),"CuFe\\B12\\MO\\B2\\M")==0,"Unicode subscripts convert to native grouped commands")
    XRD_TestCheck(cmpstr(XRD_LegendText("Y-type"),"Y-type")==0,"type label unchanged")
    String labels="Cu;CuO;Cu2O;CuFeO2;Fe2O3;Fe3O4;M-type;Y-type;Z-type;W-type"
    Variable i
    NVAR count=$(project+":referenceCount")
    for(i=1;i<=10;i+=1)
        rp=XRD_ReferencePath(i)
        if(i>count)
            DuplicateDataFolder $(XRD_ReferencePath(1)),$rp
        endif
        String/G $(rp+":phaseName")=StringFromList(i-1,labels)
        String/G $(rp+":styleGroup")=StringFromList(i-1,labels)
        String/G $(rp+":formula")=""
        String/G $(rp+":typeOverride")="通常相"
    endfor
    count=10
    Wave ids=$(path+":Peaks:peakID"),refs=$(path+":Assignments:refIndex"),aids=$(path+":Assignments:peakID"),rows=$(path+":Assignments:refPeakIndex")
    Redimension/N=9 refs,aids,rows
    refs=p+1;aids=ids[0];rows=0
    XRD_CreateEditableGraph()
    win=WinName(0,1)
    savedGraph=win
    GetAxis/W=$win/Q left
    XRD_TestCheck(V_min==-30,"single graph lower limit -30")
    info=AnnotationInfo(win,"Phases",0)
    // AnnotationInfo escapes backslashes for command-string recreation.
    info=ReplaceString("\\\\",info,"\\")
    XRD_TestCheck(strsearch(info,"\\Z24\\[0",0)>=0 && strsearch(info,"Cu\\B2\\MO",0)>=0,"legend uses 24pt and native subscript commands")
    XRD_TestCheck(strsearch(info,"        ",0)>=0,"nine-phase legend uses wide spacing")
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as outputPath+"legend9_v042.png"
    Redimension/N=10 refs,aids,rows
    refs[9]=10;aids[9]=ids[0];rows[9]=0
    XRD_CreateEditableGraph()
    win=WinName(0,1)
    info=AnnotationInfo(win,"Phases",0)
    XRD_TestCheck(strsearch(info,"        ",0)<0 && strsearch(info,"   ",0)>=0,"ten-phase legend uses compact spacing")
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as outputPath+"legend10_v042.png"
    Wave xx=$(path+":Raw:twoTheta"),yy=$(path+":Raw:intensity")
    second=XRD_Store(xx,yy,"second.xy")
    String/G $(path+":status")="同定完了"
    String/G $(second+":status")="同定完了"
    XRD_CreateStackGraph()
    win=WinName(0,1)
    GetAxis/W=$win/Q left
    XRD_TestCheck(V_min==-30 && V_max==260,"stack lower limit -30 and retained headroom")
    XRD_TestCheck(strlen(AnnotationInfo(win,"Condition2",0))>0,"stack condition text present")
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as outputPath+"stack_v042.png"
    XRD_TestCheck(XRD_DeleteMeasurement(second)==0 && XRD_TotalMeasurementCount()==1 && XRD_CompletedMeasurementCount()==1,"delete updates list and completed count")
    XRD_TestCheck(cmpstr(XRD_Data(),path)==0 && numpnts(yy)==7,"delete selects remaining data and preserves raw")
    XRD_TestCheck(WinType(win)==1 && WinType(savedGraph)==1,"existing graphs survive deletion")
    XRD_CreateStackGraph()
    String one=WinName(0,1)
    XRD_TestCheck(ItemsInList(ListMatch(TraceNameList(one,";",1),"Measurement*"))==1,"new stack excludes deleted data")
    XRD_TestCheck(XRD_RestoreMeasurement(second)==0 && XRD_TotalMeasurementCount()==2,"restore returns measurement")
    XRD_TestCheck(XRD_DeleteMeasurement(project)==-1,"delete rejects non-measurement path")
    XRD_DeleteMeasurement(second)
    XRD_DeleteMeasurement(path)
    XRD_TestCheck(XRD_TotalMeasurementCount()==0 && strlen(XRD_Data())==0,"last deletion leaves valid empty project")
    ControlInfo/W=XRDWorkbench restoreEmpty
    XRD_TestCheck(V_flag!=0,"empty project exposes restore button")
    XRD_TestCheck(XRD_CreateStackGraph()==-1,"empty project makes no comparison")
    XRD_RestoreMeasurement(path)
    XRD_TestCheck(numpnts(refs)==10 && refs[9]==10,"restore retains assignments")
    step=1
    XRD_TestDisableFollow()
    XRD_Panel()
    ControlInfo/W=XRDWorkbench deleteData
    XRD_TestCheck(V_flag!=0,"measurement delete button present")
    NewDataFolder/O $(path+":Lattice")
    Variable/G $(path+":Lattice:a")=5.89
    Variable/G $(path+":Lattice:aSigma")=0.002
    Variable/G $(path+":Lattice:c")=23.2
    Variable/G $(path+":Lattice:cSigma")=0.004
    String/G $(path+":Lattice:crystalSystem")="六方晶"
    info=XRD_LatticeResultText(path)
    XRD_TestCheck(strsearch(info,"a = 5.89 Å",0)>=0 && strsearch(info,"標準誤差（1σ）",0)>=0,"lattice result separates constants and standard errors")
    String/G $(path+":Lattice:crystalSystem")="立方晶"
    XRD_TestCheck(strsearch(XRD_LatticeResultText(path),"c =",0)<0,"cubic result reports only a")
    SaveExperiment as outputPath+"v042_deleted.pxp"
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.2 tests: failures="+num2istr(failures)
End

Function XRD_VerifyV42Restored()
    Variable/G root:XRDTestFailures=0
    String project=XRD_Project(),path=XRD_Data(),deleted=project+":Measurements:Data2"
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_TestCheck(XRD_TotalMeasurementCount()==1 && NumVarOrDefault(deleted+":deleted",0)==1,"deleted state persists in saved experiment data")
    Wave refs=$(path+":Assignments:refIndex")
    XRD_TestCheck(numpnts(refs)==10 && refs[9]==10,"assignments survive saved data reload")
    NVAR sigma=$(path+":Lattice:aSigma")
    XRD_TestCheck(sigma==0.002,"standard error remains stored")
    XRD_TestCheck(XRD_RestoreMeasurement(deleted)==0 && XRD_TotalMeasurementCount()==2,"deleted measurement can be restored after reload")
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.2 persistence tests: failures="+num2istr(failures)
End
