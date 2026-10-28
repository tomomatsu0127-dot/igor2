#pragma rtGlobals=3
// v0.5.0 meaningful synthetic and state-transition tests.
Function XRD_RunV50Tests(samplesPath,outputPath)
    String samplesPath,outputPath
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_NewProject()
    String project=XRD_Project()
    NewPath/O/Q XRDReferencePath,samplesPath
    XRD_LoadReferences()
    Make/FREE/D/N=6001 xx=20+0.01*p,yy=5+0.05*(xx[p]-20)+100*exp(-((xx[p]-30.023)/0.06)^2)+30*exp(-((xx[p]-43.057)/0.08)^2)
    String path=XRD_Store(xx,yy,"synthetic_gaussian.xy")
    XRD_Manual(path,30)
    Wave ids=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle"),raw=$(path+":Raw:intensity")
    Duplicate/FREE raw,before
    NVAR selected=$(path+":selectedPeakRow")
    selected=0
    XRD_TestCheck(abs(angles[0]-30)<1e-10,"registered center remains measurement-grid point")
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_TestCheck(GetRTError(1)==0,"opening workbench leaves no runtime error")
    SetAxis/W=XRDWorkbench#Pattern bottom 29.8,30.2
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 1000
    Variable result=XRD_FitPeakProfile(path,0,29.6,30.4,1,1)
    Print "PROFILE RESULT="+num2str(result)
    String rp=XRD_ProfilePath(path,ids[0])
    XRD_TestCheck(result==0,"Igor CurveFit Gaussian succeeds with linear background")
    if(result==0)
        XRD_TestCheck(abs(NumVarOrDefault(rp+":center",NaN)-30.023)<1e-5,"fit recovers sub-grid synthetic center")
        XRD_TestCheck(abs(NumVarOrDefault(rp+":fwhm",NaN)-2*sqrt(ln(2))*0.06)<1e-5,"Gaussian FWHM uses Igor width convention")
        XRD_TestCheck(abs(angles[0]-30)<1e-10 && !NumVarOrDefault(rp+":accepted",0),"preview does not adopt fitted angle")
        Variable id=ids[0]
        XRD_TestCheck(XRD_AdoptProfile(path,id)==0 && abs(angles[0]-30.023)<1e-5,"explicit adoption updates center and preserves stable ID")
        XRD_TestCheck(GetRTError(1)==0,"adopting center restores info panel without error")
        XRD_TestCheck(ids[0]==id && strsearch(XRD_PeakAngleSource(path,0),"採用済",0)>=0,"adopted angle source is recorded")
        Variable adoptedCenter=XRD_LatticeAngle(path,0)
        XRD_TestCheck(XRD_FitPeakProfile(path,0,29.65,30.35,1,1)==0 && abs(XRD_LatticeAngle(path,0)-adoptedCenter)<1e-10,"replacement preview retains previously adopted center")
        XRD_Undo()
        XRD_TestCheck(XRD_Undo()==1 && abs(angles[0]-30)<1e-10,"undo restores registered angle and profile adoption state")
        XRD_TestCheck(GetRTError(1)==0,"undo restores info panel without error")
        XRD_TestCheck(!NumVarOrDefault(rp+":accepted",0),"undo does not leave a stale adopted profile")
        XRD_TestCheck(XRD_Redo()==1 && abs(angles[0]-30.023)<1e-5,"redo reapplies fitted center")
        XRD_TestCheck(GetRTError(1)==0,"redo restores info panel without error")
        GetAxis/W=XRDWorkbench#Pattern/Q bottom
        XRD_TestCheck(abs(V_min-29.8)<1e-10 && abs(V_max-30.2)<1e-10 && pcsr(A,"XRDWorkbench#Pattern")==1000,"fit adoption and undo redo preserve zoom and Ctrl I cursor")
        XRD_Undo()
        XRD_Manual(path,43.06)
        XRD_TestCheck(XRD_Redo()==0,"new mutation clears redo branch")
    endif
    XRD_TestCheck(WaveCRC(0,raw)==WaveCRC(0,before),"CurveFit never changes original measurement")
    XRD_TestCheck(GetRTError(1)==0,"new branch retains valid window state")
    XRD_TestCheck(XRD_FitPeakProfile(path,0,30,30.02,1,1)==-2,"insufficient fit points are rejected")
    XRD_TestCheck(XRD_FitPeakProfile(path,0,29,30.4,3,1)==-1,"unsupported model is rejected")
    NVAR lambda=$(path+":measurementWavelength")
    lambda=1.2345
    String second=XRD_Store(xx,yy,"second.xy")
    XRD_TestCheck(NumVarOrDefault(second+":measurementWavelength",0)==1.5406 && lambda==1.2345,"wavelength belongs to each measurement")
    SVAR active=$(project+":activeData")
    active=path
    Make/FREE/D/N=601 lx=29+0.005*p,ly=3+500/(1+((lx[p]-30.017)/0.04)^2)
    String lorPath=XRD_Store(lx,ly,"lorentz.xy")
    XRD_Manual(lorPath,30)
    XRD_TestCheck(GetRTError(1)==0,"second measurement leaves no stale error")
    result=XRD_FitPeakProfile(lorPath,0,29.6,30.4,2,0)
    Print "LORENTZ RESULT="+num2str(result)
    Wave/Z lorCoef=$(lorPath+":ProfileWork:W_coef")
    if(WaveExists(lorCoef))
        Print lorCoef
    endif
    Wave lorIDs=$(lorPath+":Peaks:peakID")
    String lorRP=XRD_ProfilePath(lorPath,lorIDs[0])
    XRD_TestCheck(result==0 && abs(NumVarOrDefault(lorRP+":center",NaN)-30.017)<1e-5,"Lorentz fit recovers center")
    XRD_TestCheck(abs(NumVarOrDefault(lorRP+":fwhm",NaN)-0.08)<1e-5,"Lorentz FWHM is validated")
    active=path
    // Independently controlled reference and measurement peaks exercise overlap/missing cases.
    String ref1=XRD_ReferencePath(1),ref2=XRD_ReferencePath(2)
    Make/O/D/N=3 $(ref1+":twoTheta"),$(ref1+":intensity"),$(ref1+":h"),$(ref1+":k"),$(ref1+":l")
    Wave rx=$(ref1+":twoTheta"),ri=$(ref1+":intensity")
    rx[0]=30;rx[1]=43;rx[2]=55;ri[0]=100;ri[1]=50;ri[2]=90
    XRD_Manual(path,55.10)
    angles[0]=30.09;angles[1]=43.11;angles[2]=55.10
    Variable refined=XRD_RefineShift(path,1,0.09)
    XRD_TestCheck(abs(refined-0.10)<1e-8,"reference alignment uses multiple-peak median")
    Wave aid=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex"),arows=$(path+":Assignments:refPeakIndex"),shifts=$(path+":Assignments:shift")
    Wave/T modes=$(path+":Assignments:mode"),created=$(path+":Assignments:created")
    Redimension/N=1 aid,refs,arows,shifts,modes,created
    aid[0]=ids[0];refs[0]=2;arows[0]=0;shifts[0]=0;modes[0]="Primary";created[0]="test"
    XRD_TestCheck(XRD_BuildEvidence(path,1,0.10)==3,"all matched reference peaks count including another-phase assignment")
    XRD_TestCheck(NumVarOrDefault(path+":Evidence:overlaps",0)==1 && NumVarOrDefault(path+":Evidence:missingStrong",-1)==0,"overlapped strongest line is not counted missing")
    NVAR mode=$(path+":candidateMode")
    mode=1
    XRD_TestCheck(XRD_CandidateAllowed(path,2)==1 && XRD_CandidateAllowed(path,1)==0,"adopted-phase mode uses this measurement only")
    mode=2
    XRD_TestCheck(XRD_CandidateAllowed(path,2)==0 && XRD_CandidateAllowed(path,1)==1,"new-phase mode excludes adopted references")
    mode=0
    angles[2]=60
    XRD_BuildEvidence(path,1,0.10)
    XRD_TestCheck(NumVarOrDefault(path+":Evidence:missingStrong",0)==1,"unmatched strong reference is separately reported")
    refs[0]=1
    XRD_TestCheck(XRD_BuildAudit(path)>=3,"audit contains unreviewed peaks and missing strong reference")
    Wave/T audit=$(path+":Audit:table")
    Variable found=0,i
    for(i=0;i<DimSize(audit,0);i+=1)
        found+=(cmpstr(audit[i][0],"強い参照ピークが未一致")==0)
    endfor
    XRD_TestCheck(found==1,"review exposes strong missing peak without rejecting phase")
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_EvidencePanel()
    XRD_AuditPanel()
    XRD_MetadataPanel()
    XRD_ReferenceEditor()
    XRD_TestCheck(WinType("XRDEvidence")==7 && WinType("XRDAudit")==7 && WinType("XRDMetadata")==7 && WinType("XRDReferenceEditor")==7,"new review metadata and reference panels open")
    String originalFormula=StrVarOrDefault(ref1+":formula","")
    String/G $(project+":ReferenceDraft:formula")="CuFeO2"
    XRD_TestCheck(cmpstr(StrVarOrDefault(ref1+":formula",""),originalFormula)==0,"reference draft does not edit cached reference until applied")
    XRD_ApplyReferenceMetadata()
    XRD_TestCheck(cmpstr(StrVarOrDefault(ref1+":formula",""),"CuFeO2")==0,"reference editor applies metadata without changing card identity")
    Variable/G $(path+":Evidence:draftWavelength")=1.2
    Variable/G $(path+":Evidence:draftZero")=0.03
    XRD_TestCheck(XRD_ApplyMetadata(path)==0 && lambda==1.2,"metadata draft applies validated wavelength")
    XRD_Undo()
    XRD_TestCheck(abs(lambda-1.2345)<1e-10 && NumVarOrDefault(path+":zeroCorrection",1)==0,"calibration edits can be undone")
    NVAR allowedMode=$(project+":elementFilterMode")
    SVAR allowed=$(project+":allowedElements")
    allowedMode=1;allowed="Ba;Fe;O"
    String/G $(ref1+":formula")="CuFeO2"
    String/G $(ref1+":typeOverride")="通常相"
    XRD_TestCheck(strsearch(XRD_FilterReason(1),"除外",0)>=0,"filter explains ordinary forbidden-element phase")
    String/G $(ref1+":typeOverride")="Y-type"
    XRD_TestCheck(strsearch(XRD_FilterReason(1),"除外しません",0)>=0,"filter explains type-family exemption")
    String/G $(ref1+":displayOverride")="Custom Y label"
    XRD_TestCheck(cmpstr(XRD_PhaseLabel(1),"Custom Y label")==0,"display override leaves reference card identity separate")
    allowedMode=0
    XRD_TestCheck(XRD_BuildComparison()>0,"project comparison table includes assigned measurement")
    XRD_TestCheck(XRD_WriteReport(outputPath+"report_v0.5.0.md")==0,"analysis report exports provenance and assignments")
    GetFileFolderInfo/Q/Z outputPath+"report_v0.5.0.md"
    XRD_TestCheck(V_flag==0 && V_logEOF>0,"report exists and is nonempty")
    XRD_ProfilePanel()
    XRD_TestCheck(WinType("XRDProfilePanel")==7,"local CurveFit panel opens")
    STRUCT WMWinHookStruct hook
    hook.winName="XRDWorkbench#Pattern";hook.eventCode=26;hook.eventMod=10;hook.keycode=122
    XRD_TestCheck(XRD_UndoHook(hook)==1,"Ctrl Shift Z graph hook schedules redo")
    hook.keycode=105
    XRD_TestCheck(XRD_UndoHook(hook)==0,"Ctrl I is left to native cursor handling")
    XRD_CreateEditableGraph()
    XRD_InvalidateFit(path)
    XRD_TestCheck(strsearch(WinRecreation("XRDAnalysisGraph",0),"XRDNeedsUpdate",0)>=0,"derived graphs visibly require regeneration after changes")
    XRD_TestCheck(GetRTError(1)==0,"derived graph and annotation updates leave no stale error")
    NewPath/O/Q XRDAutoSaveCustomPath,outputPath
    XRD_TestCheck(XRD_SaveRecovery()==0,"completed temporary recovery copy replaces rotation slot")
    SVAR lastCopy=root:Packages:XRDWorkbench:Recovery:lastFile
    GetFileFolderInfo/Q/Z lastCopy+".pending.pxp"
    XRD_TestCheck(V_flag!=0,"successful recovery leaves no pending copy")
    XRD_SaveSettingsPanel()
    XRD_TestCheck(strsearch(ControlNameList("XRDSaveSettings",";"),"recoveryList",0)>=0,"save settings include recovery browser")
    CtrlNamedBackground XRDAutoSave,stop
    SaveExperiment/C/F={1,"",0} as outputPath+"v50_roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.5.0 tests: failures="+num2istr(failures)
    return failures
End

Function XRD_V50Persistence(savedFile)
    String savedFile
    LoadData/O/Q/R savedFile
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    String project=XRD_Project(),path=XRD_Data(),rp=XRD_ProfilePath(path,1)
    XRD_TestCheck(NumVarOrDefault(path+":measurementWavelength",0)==1.2345,"measurement-specific wavelength persists")
    XRD_TestCheck(NumVarOrDefault(rp+":valid",0)==1 && abs(NumVarOrDefault(rp+":center",NaN)-30.023)<1e-5,"local fit coefficients and center persist")
    XRD_TestCheck(cmpstr(StrVarOrDefault(XRD_ReferencePath(1)+":displayOverride",""),"Custom Y label")==0,"reference display name persists separately from card")
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_TestCheck(GetRTError(1)==0,"saved experiment reopens responsive workbench without runtime errors")
    XRD_TestCheck(WinType("XRDWorkbench")==7,"saved project reopens all imported measurement state")
    XRD_TestCheck(XRD_Undo()==1 && XRD_Redo()==1,"undo and redo snapshots remain usable after reload")
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.5.0 persistence failures="+num2str(failures)
    return failures
End

Function XRD_V50LockedRecovery(outputPath,locked)
    String outputPath
    Variable locked
    XRD_Init()
    XRD_RecoverySettings()
    Variable/G root:XRDTestFailures=0
    NewPath/O/Q XRDAutoSaveCustomPath,outputPath
    String/G root:Packages:XRDWorkbench:Recovery:sessionKey="LOCK_TEST_V050"
    Variable/G root:Packages:XRDWorkbench:Recovery:generation=0
    if(locked)
        XRD_TestCheck(XRD_SaveRecovery()<0,"locked rotation target reports failure after temporary copy completes")
        XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:generation",-1)==0 && NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:busy",-1)==0,"locked replacement retains generation and releases saving flag")
    else
        XRD_TestCheck(XRD_SaveRecovery()==0,"seed recovery copy for locked-file preservation test")
    endif
    return 0
End

Function XRD_V50LatticeTests()
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_NewProject()
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=1+exp(-((xx[p]-30)/0.1)^2)
    String path=XRD_Store(xx,yy,"lattice-calibration.xy")
    NewDataFolder/O $(path+":Lattice")
    Make/O/D/N=(4,6) $(path+":Lattice:inputs")
    Wave input=$(path+":Lattice:inputs")
    Variable i,lambda=1.5406,aa=4.195,zero=0.04
    Variable/G $(path+":zeroCorrection")=zero
    Variable/G $(path+":Lattice:refIndex")=1
    for(i=0;i<4;i+=1)
        input[i][0]=1
        input[i][1]=2*asin(lambda*sqrt(i+1)/(2*aa))*180/pi+zero
        input[i][2]=1+(i==3);input[i][3]=(i==1 || i==2);input[i][4]=(i==2);input[i][5]=i+1
    endfor
    XRD_TestCheck(XRD_FitCubic(path)==0 && abs(NumVarOrDefault(path+":Lattice:a",0)-aa)<1e-6,"cubic CurveFit uses measurement-specific zero correction")
    XRD_TestCheck(DataFolderExists(path+":LatticeResults:Ref1") && DimSize($(path+":Lattice:quality"),0)==4,"phase-specific lattice archive and residual quality table saved")
    Variable/G $(path+":Lattice:refIndex")=2
    XRD_FitCubic(path)
    XRD_TestCheck(DataFolderExists(path+":LatticeResults:Ref1") && DataFolderExists(path+":LatticeResults:Ref2"),"two selected phases retain separate lattice results")
    XRD_InvalidateFit(path)
    XRD_TestCheck(strsearch(StrVarOrDefault(path+":LatticeResults:Ref1:state",""),"再計算",0)>=0,"analysis change invalidates stored phase-specific lattice results")
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.5.0 lattice failures="+num2str(failures)
    return failures
End
