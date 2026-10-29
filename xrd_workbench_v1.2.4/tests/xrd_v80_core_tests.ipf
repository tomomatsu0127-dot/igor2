#pragma rtGlobals=3
// Run only in an isolated empty Experiment. Does not depend on an external library.
Function XRD80_CoreCheck(condition,label)
    Variable condition
    String label
    NVAR failures=root:XRD80CoreFailures
    if(condition)
        Print "PASS: "+label
    else
        Print "FAIL: "+label
        failures+=1
    endif
End

Function XRD_RunV80CoreTests()
    Variable/G root:XRD80CoreFailures=0
    XRD_Init()
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=1+100*exp(-((xx[p]-30)/0.15)^2)+60*exp(-((xx[p]-40)/0.15)^2)
    String firstProject=XRD_Project(),first=XRD_Store(xx,yy,"x=-0.1.xy")
    String firstID=XRD80_MeasurementUID(first),projectID=XRD80_ProjectUID(firstProject)
    Wave raw=$(first+":Raw:intensity"),rawX=$(first+":Raw:twoTheta")
    Variable rawCRC=WaveCRC(0,raw),xCRC=WaveCRC(0,rawX)
    XRD80_CoreCheck(cmpstr(StrVarOrDefault(first+":analysisState",""),"未解析")==0,"zero peaks are not automatically complete")
    XRD_Manual(first,30)
    XRD_Manual(first,40)
    XRD80_CoreCheck(!XRD_IsAnalysisComplete(first) && cmpstr(StrVarOrDefault(first+":analysisState",""),"解析中")==0,"unreviewed detected peaks remain in progress")
    XRD_SetUnknown(first,0)
    XRD80_CoreCheck(!XRD_IsAnalysisComplete(first),"one Unknown leaves a second unreviewed peak incomplete")
    XRD_SetUnknown(first,1)
    XRD80_CoreCheck(XRD_IsAnalysisComplete(first),"all Unknown peaks automatically complete the sample")
    XRD80_CoreCheck(cmpstr(StrVarOrDefault(first+":status",""),"同定完了")==0,"automatic completion maintains the legacy status adapter")
    NewDataFolder/O $(first+":Lattice")
    String/G $(first+":Lattice:state")="計算済"
    Variable/G $(first+":zeroCorrection")=0.04
    XRD80_AnalysisChanged(first,"補正を変更")
    XRD80_CoreCheck(XRD_IsAnalysisComplete(first) && NumVarOrDefault(first+":Lattice:stale",0)==1,"correction keeps completed assignments and marks lattice for recalculation")
    XRD_ClearPeakReview(first,0)
    XRD80_CoreCheck(!XRD_IsAnalysisComplete(first),"clearing a review returns only that sample to in-progress")
    XRD_SetUnknown(first,0)
    XRD80_CoreCheck(XRD_SetMeasurementComplete(first)==0,"legacy completion command validates automatic state")
    XRD80_RenameProject(firstProject,"1200℃ in Air")
    XRD80_RenameMeasurement(first,"x=-0.1 改名後")
    XRD80_CoreCheck(cmpstr(XRD80_ProjectUID(firstProject),projectID)==0 && cmpstr(XRD80_MeasurementUID(first),firstID)==0,"project/sample renaming preserves immutable identities")
    XRD80_CoreCheck(cmpstr(XRD_ProjectDisplayName(firstProject),"1200℃ in Air")==0,"project name is independent of the storage path")
    Wave tt=$(first+":Waves:tt_"+firstID),intensity=$(first+":Waves:int_"+firstID),processed=$(first+":Processed:intensity")
    DoUpdate
    XRD80_CoreCheck(tt[200]==rawX[200] && abs(intensity[200]-processed[200])<1e-9,"prefix waves are formula-linked to canonical measured data")
    XRD80_CoreCheck(strlen(GetFormula(tt))>0 && strlen(GetFormula(intensity))>0,"prefix waves retain dependencies rather than an independently editable duplicate")
    String unfinished=XRD_Store(xx,yy,"x=0.xy")
    XRD80_CoreCheck(cmpstr(XRD80_ProjectProgress(firstProject),"1/2完了")==0,"project progress counts independently completed samples")
    XRD_NewProject()
    String secondProject=XRD_Project(),second=XRD_Store(xx,yy,"x=0.2.xy")
    XRD80_CoreCheck(cmpstr(XRD80_MeasurementUID(second),firstID)!=0,"Data1 in another project receives a different experiment-wide sample ID")
    XRD80_CoreCheck(cmpstr(XRD80_ResolveMeasurement(firstID),first)==0,"registry resolves another project's sample without changing its identity")
    XRD80_CoreCheck(XRD_IsAnalysisComplete(first) && !XRD_IsAnalysisComplete(second),"another project's incomplete sample does not affect the completed sample")
    XRD80_CoreCheck(WaveCRC(0,raw)==rawCRC && WaveCRC(0,rawX)==xCRC,"identity/state/correction/rename preserve Raw waves")
    Make/FREE/D/N=3 map={9,4,7}
    NewDataFolder/O root:XRD80MapTest
    Make/O/D/N=4 root:XRD80MapTest:refs={1,3,0,2}
    XRD80_MapReferenceWave("root:XRD80MapTest:refs",map)
    Wave mapped=root:XRD80MapTest:refs
    XRD80_CoreCheck(mapped[0]==9 && mapped[1]==7 && mapped[2]==0 && mapped[3]==4,"legacy reference map preserves Unknown and translates positive indices")
    XRD80_CoreCheck(GetRTError(1)==0,"core operations leave no runtime error")
    NVAR failures=root:XRD80CoreFailures
    Print "v0.8.0 core failures="+num2istr(failures)
    return failures
End
