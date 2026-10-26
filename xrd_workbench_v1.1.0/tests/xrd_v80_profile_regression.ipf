#pragma rtGlobals=3
// v0.8.0: unchanged numerical/profile assertions from v0.5.0.
// The obsolete reference editor and final-graph UI assertions are covered by v080 integration tests.
Function XRD_RunV80ProfileRegression(samplesPath,outputPath)
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
    XRD81_SetPickMode(1)
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
    NVAR failures=root:XRDTestFailures
    Print "v080 profile and matching regression failures="+num2istr(failures)
    return failures
End
