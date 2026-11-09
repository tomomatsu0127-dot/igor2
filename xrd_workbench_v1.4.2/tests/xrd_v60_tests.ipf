#pragma rtGlobals=3
Function XRD_TestNearestError(path,angle)
    String path
    Variable angle
    Wave peaks=$(path+":Peaks:angle")
    Variable i,best=inf
    for(i=0;i<numpnts(peaks);i+=1)
        best=min(best,abs(peaks[i]-angle))
    endfor
    return best
End

Function XRD_RunV60Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    XRD_NewProject()
    XRD_ImportFile(fixtures+"noisy_uniform.csv")
    String path=XRD_Data(),project=XRD_Project()
    Wave raw=$(path+":Raw:intensity"),xx=$(path+":Raw:twoTheta"),peaks=$(path+":Peaks:angle"),ids=$(path+":Peaks:peakID")
    Wave norm=$(path+":Processed:intensity")
    Variable normCRC=WaveCRC(0,norm),crc=WaveCRC(0,raw),xcrc=WaveCRC(0,xx),legacyHits=0,legacyCount,i,result
    XRD_TestCheck(NumVarOrDefault(path+":detectorMode",-1)==1,"B release defaults to improved detector")
    XRD_DetectLegacy(path)
    legacyCount=numpnts(peaks)
    Make/FREE/D truth={30,33,40,40.22,50}
    for(i=0;i<5;i+=1)
        legacyHits+=XRD_TestNearestError(path,truth[i])<=0.04
    endfor
    XRD_TestDisableFollow()
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 29,41
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 1000
    Variable before=numpnts(peaks),undoCount=NumVarOrDefault(project+":Undo:sequence",0)
    result=XRD_DetectRobust(path,0)
    XRD_TestCheck(result>=0 && numpnts(peaks)==before,"preview computes candidates without changing registered peaks")
    XRD_TestCheck(NumVarOrDefault(project+":Undo:sequence",0)==undoCount,"preview does not consume Undo history")
    XRD_ShowDetection(path)
    DoUpdate
    SavePICT/O/E=-5/WIN=XRDDetectionPreview as output+"detection_preview_v060.png"
    DoWindow/K XRDDetectionPreview
    result=XRD_Detect(path)
    Variable hits=0
    for(i=0;i<5;i+=1)
        hits+=XRD_TestNearestError(path,truth[i])<=0.04
        XRD_TestCheck(XRD_TestNearestError(path,truth[i])<=0.04,"improved detector recovers synthetic true peak "+num2str(truth[i]))
    endfor
    Print "DETECTION METRICS legacy="+num2istr(legacyHits)+"/5 true, "+num2istr(legacyCount-legacyHits)+" extra; robust="+num2istr(hits)+"/5 true, "+num2istr(numpnts(peaks)-hits)+" extra"
    XRD_TestCheck(numpnts(peaks)-hits<=1 && numpnts(peaks)<legacyCount,"improved detector removes most spurious peaks on deterministic noisy fixture")
    XRD_TestCheck(XRD_TestNearestError(path,47)>0.06,"minimum width rejects single-sample intensity spike")
    XRD_TestCheck(WaveCRC(0,norm)==normCRC,"displayed normalized measurement remains bit-identical")
    XRD_TestCheck(WaveCRC(0,raw)==crc && WaveCRC(0,xx)==xcrc,"raw intensity and angle waves remain bit-identical")
    XRD_TestCheck(cmpstr(StrVarOrDefault(path+":algorithm",""),"prominence-sg-v1")==0 && strsearch(StrVarOrDefault(path+":detectionRunDescription",""),"smooth=",0)>=0,"method and actual parameters are retained for saving")
    XRD_Undo()
    XRD_TestCheck(numpnts(peaks)==before && strsearch(StrVarOrDefault(path+":algorithm",""),"local-max",0)>=0,"Undo restores prior peak set and prior detection method")
    XRD_Redo()
    XRD_TestCheck(numpnts(peaks)<=6 && cmpstr(StrVarOrDefault(path+":algorithm",""),"prominence-sg-v1")==0,"Redo restores improved peak set and method")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==29 && V_max==41 && pcsr(A,"XRDWorkbench#Pattern")==1000,"detection and history retain zoom and Ctrl I cursor")
    XRD_Manual(path,55)
    Variable manualID=ids[numpnts(ids)-1]
    XRD_SetUnknown(path,0)
    Variable reviewedID=ids[0],count=numpnts(ids)
    XRD_Detect(path)
    Variable manualFound=0,reviewFound=0
    for(i=0;i<numpnts(ids);i+=1)
        manualFound=max(manualFound,ids[i]==manualID)
        reviewFound=max(reviewFound,ids[i]==reviewedID)
    endfor
    XRD_TestCheck(manualFound && reviewFound,"rerun retains manual and reviewed peaks with stable IDs")
    XRD_TestCheck(numpnts(ids)==count,"repeat detection does not accumulate duplicate peaks")
    NVAR smoothSetting=$(path+":detectSmoothDeg")
    smoothSetting=0
    XRD_TestCheck(XRD_DetectRobust(path,0)>=3,"zero-smoothing option still evaluates prominence and noise")
    smoothSetting=0.05
    XRD_TestCheck(XRD_OddWindow(10,0.000000001,500001,5)==32767,"very dense grids cap native smoothing window at supported size")
    NVAR prominence=$(path+":detectProminence")
    prominence=NaN
    before=numpnts(peaks);undoCount=NumVarOrDefault(project+":Undo:sequence",0)
    XRD_TestCheck(XRD_Detect(path)==-1 && numpnts(peaks)==before && NumVarOrDefault(project+":Undo:sequence",0)==undoCount,"invalid parameters leave peaks and Undo unchanged")
    prominence=0.5
    XRD_DetectionPanel()
    XRD_TestCheck(WinType("XRDDetectionSettings")==7,"detection controls and preview panel open")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDDetectionSettings as output+"detection_settings_v060.png"
    DoWindow/K XRDDetectionSettings
    XRD_ImportFile(fixtures+"noisy_uneven.csv")
    String uneven=XRD_Data()
    result=XRD_Detect(uneven)
    hits=0
    for(i=0;i<5;i+=1)
        hits+=XRD_TestNearestError(uneven,truth[i])<=0.04
    endfor
    Print "UNEVEN METRICS "+num2istr(hits)+"/5 true"
    XRD_TestCheck(result>=0 && hits==5,"working grid handles nonuniform angle sampling")
    Make/FREE/D/N=501 flatX=20+0.01*p,flatY=7
    String flat=XRD_Store(flatX,flatY,"flat.xy")
    XRD_TestCheck(XRD_Detect(flat)==0 && numpnts($(flat+":Peaks:angle"))==0,"flat signal does not produce peaks")
    Make/FREE/D/N=5 tinyX=p+20,tinyY={0,1,0,2,0}
    String tiny=XRD_Store(tinyX,tinyY,"tiny.xy")
    XRD_TestCheck(XRD_Detect(tiny)==-2,"too-short signal refuses improved detection without mutation")
    Variable/G $(tiny+":detectorMode")=0
    XRD_TestCheck(XRD_Detect(tiny)==0 && numpnts($(tiny+":Peaks:angle"))==2,"legacy method remains selectable for very short data")
    SVAR active=$(project+":activeData")
    active=path
    SaveExperiment/C/F={1,"",0} as output+"detection_settings.pxp"
    XRD_TestCheck(GetRTError(1)==0,"improved detector and UI leave no runtime error")
    NVAR failures=root:XRDTestFailures
    Print "v0.6.0 tests failures="+num2str(failures)
End

Function XRD_V60Persistence(saved)
    String saved
    LoadData/O/Q/R saved
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    String path=XRD_Data()
    XRD_TestCheck(NumVarOrDefault(path+":detectorMode",0)==1 && NumVarOrDefault(path+":detectSNR",0)==4,"saved detection mode and settings restore")
    XRD_TestCheck(cmpstr(StrVarOrDefault(path+":algorithm",""),"prominence-sg-v1")==0 && strlen(StrVarOrDefault(path+":detectionRunDescription",""))>30,"saved run retains detector version and parameters")
    XRD_TestCheck(DataFolderExists(path+":Detection") && numpnts($(path+":Detection:peakAngle"))>0,"detection diagnostic data persists separately from Raw")
End
