#pragma rtGlobals=3
#include ":xrd_v123_tests"
Function XRD_RunV126Tests(fixtures)
    String fixtures
    Variable/G root:XRDTestFailures=0
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_LoadReferenceFile("phase1.txt",1)
    XRD_LoadReferenceFile("phase2.txt",2)
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=2+100*exp(-((xx[p]-25)/0.1)^2)+60*exp(-((xx[p]-27)/0.1)^2)
    String p1=XRD_Project(),a=XRD_Store(xx,yy,"first.xy"),ua=XRD80_MeasurementUID(a)
    XRD_Manual(a,25);XRD_Manual(a,27);XRD80_TestAdopt(a,0,1,0)
    XRD_TestCheck(XRD100_SetSample(a,"015","x=0.4","試料十五")==0,"v126 register existing readable aliases")
    a=XRD80_ResolveMeasurement(ua)
    String b=XRD_Store(xx,yy,"second.xy"),ub=XRD80_MeasurementUID(b)
    XRD100_SetSample(b,"016","x=0.5","試料十六");b=XRD80_ResolveMeasurement(ub)
    XRD_NewProject()
    String p2=XRD_Project(),c=XRD_Store(xx,yy,"third.xy"),uc=XRD80_MeasurementUID(c)
    XRD100_SetSample(c,"015","x=0.4","別プロジェクト十五");c=XRD80_ResolveMeasurement(uc)
    String/G root:Packages:XRDWorkbench:activeProject=p1
    String/G $(p1+":activeData")=a
    Variable/G $(p1+":activeStep")=3
    Variable/G $(a+":Preview:referenceIndex")=1
    Variable/G $(a+":Preview:reflectionIndex")=0
    String settings=XRD120_CompareSettings()
    Make/O/T/N=3 $(settings+":uids")
    Wave/T selected=$(settings+":uids")
    selected[0]=ua;selected[1]=ub;selected[2]=uc
    XRD_Panel();XRD_OpenReview()
    String win="XRDReviewGraph",traces=TraceNameList(win,";",1),trace=CleanupName(XRD126_Name(a,0,""),0,220),source=XRD126_Source(a,"int_norm",":Processed:intensity")
    XRD_TestCheck(WhichListItem(trace,traces)>=0,"v126 measured trace has registered readable name")
    Wave displayed=TraceNameToWaveRef(win,trace),original=$(a+":Processed:intensity")
    XRD_TestCheck(cmpstr(GetWavesDataFolder(displayed,2),source)==0,"v126 measured trace uses original named alias directly")
    XRD_TestCheck(WaveCRC(0,displayed)==WaveCRC(0,original),"v126 display offset never changes measured intensities")
    XRD_TestCheck(strsearch(TraceInfo(win,trace,0),"offset(x)={0,270}",0)>=0 || strsearch(WinRecreation(win,0),"={0,270}",0)>=0,"v126 stack uses native display offset")
    String identified=XRD126_Cache(XRD_PlotRoot()+":LiveReview",a,1,"_identified_R1")
    Wave marker=$identified,peaks=$(a+":Peaks:height")
    XRD_TestCheck(numpnts(marker)==1 && abs(marker[0]-peaks[0]-270)<1e-8,"v126 readable phase markers retain assigned measured peaks")
    XRD_TestCheck(strsearch(traces,"MM_",0)<0 && strsearch(traces,"XRDWB_Measured",0)<0,"v126 review no opaque legacy trace names")
    XRD110_ComparePanel()
    String draft=XRD126_Draft()
    Wave/T order=$(draft+":order126")
    XRD_TestCheck(numpnts(order)==3 && cmpstr(order[2],c)==0,"v126 initial ordered list retains all projects")
    Make/FREE/D/N=4 originalBox126
    XRD123_Box("XRDCompareSelection",originalBox126)
    MoveWindow/W=XRDCompareSelection 55,55,955,595
    XRD126_Layout()
    ControlInfo/W=XRDCompareSelection clear126
    Variable clearBottom126=V_top+V_height
    ControlInfo/W=XRDCompareSelection display126
    XRD_TestCheck(clearBottom126<V_top,"v126 chooser buttons do not overlap display settings at minimum size")
    ControlInfo/W=XRDCompareSelection selected126
    Variable selectedBottom126=V_top+V_height
    ControlInfo/W=XRDCompareSelection remove126
    XRD_TestCheck(selectedBottom126<V_top,"v126 selected list stays above removal buttons after resize")
    MoveWindow/W=XRDCompareSelection originalBox126[0],originalBox126[1],originalBox126[2],originalBox126[3]
    XRD126_Layout()
    Wave/T treeTable126=$(XRD110_TreeBase(2)+":table")
    Variable clean126=1,i
    for(i=0;i<DimSize(treeTable126,0);i+=1)
        clean126=clean126 && !strlen(treeTable126[i][0])
    endfor
    XRD_TestCheck(clean126,"v126 rebuilt checkbox tree clears stale cell text")
    XRD126_EditOrder("up126",2)
    XRD_TestCheck(cmpstr(order[1],c)==0 && cmpstr(StringFromList(1,XRD_ComparePaths()),b)==0,"v126 draft reorder does not apply early")
    XRD126_EditOrder("remove126",0)
    XRD_TestCheck(numpnts(order)==2 && ItemsInList(XRD_ComparePaths())==3,"v126 removal remains draft until Apply")
    STRUCT WMButtonAction ba
    ba.eventCode=2;ba.ctrlName="cancel126";XRD126_Button(ba)
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==3 && !WinType("XRDCompareSelection"),"v126 Cancel retains comparison and closes panel")
    XRD110_ComparePanel();XRD126_EditOrder("up126",2);XRD126_EditOrder("remove126",0)
    Variable/G $(draft+":spacing126")=180
    Variable/G $(draft+":references126")=0
    Variable/G $(draft+":peaks126")=0
    Variable/G $(draft+":phases126")=0
    XRD126_Apply();XRD_DrawLiveStack(win,0)
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==2 && cmpstr(StringFromList(0,XRD_ComparePaths()),c)==0,"v126 Apply persists exclusion and selected order")
    XRD_TestCheck(ItemsInList(TraceNameList(win,";",1))==2,"v126 show toggles hide reference and marker traces")
    GetAxis/W=$win/Q left
    XRD_TestCheck(abs(V_max-320)<1e-8 && cmpstr(GetUserData(win,"","XRDSpacing126"),"180")==0,"v126 spacing updates Y bounds")
    XRD_TestCheck(!strlen(GetUserData(win,"","XRDReferenceAngle")),"v126 hidden references clear arrow selection")
    XRD110_ComparePanel();XRD126_EditOrder("clear126",-1);XRD126_Apply()
    XRD_DrawLiveStack(win,0);XRD_UpdateSideCompare()
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==0,"v126 explicit empty selection stays empty")
    XRD_TestCheck(cmpstr(GetUserData(win,"","XRDPlotCount"),"0")==0 && WhichListItem("EmptyCompare120",AnnotationList(win))>=0,"v126 detached comparison cleared with message")
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench#SideCompare","","XRDPlotCount"),"0")==0,"v126 embedded comparison cleared")
    XRD110_ComparePanel();KillWindow/Z XRDCompareSelection
    XRD_TestCheck(numpnts(order)==0 && ItemsInList(XRD_ComparePaths())==0,"v126 reopen empty chooser does not restore excluded samples")
    XRD110_ComparePanel()
    Redimension/N=3 order;order[0]=a;order[1]=b;order[2]=c
    XRD126_SyncDraft()
    Variable/G $(draft+":references126")=1
    Variable/G $(draft+":peaks126")=1
    Variable/G $(draft+":phases126")=1
    XRD126_Apply();XRD_DrawLiveStack(win,0)
    XRD_TestCheck(WhichListItem("EmptyCompare120",AnnotationList(win))<0 && ItemsInList(XRD_ComparePaths())==3,"v126 samples can be re-added after clearing")
    XRD_TestCheck(strlen(GetUserData(win,"","XRDReferenceAngle"))>0,"v126 references restore selection guide")
    XRD_TestCheck(WaveCRC(0,displayed)==WaveCRC(0,original),"v126 all comparison edits preserve measurement values")
    String longName=PadString("int_試料",270,0x61)
    XRD_TestCheck(strlen(XRD126_Trace(win,longName))<=220,"v126 overlong trace names safely clipped")
    String nextName=XRD126_Trace(win,trace)
    XRD_TestCheck(cmpstr(nextName,trace)!=0,"v126 duplicate trace name receives discriminator")
    XRD_TestCheck(cmpstr(XRD126_Trace(win,"int_SnO₂_test"),"int_SnO2_test")==0,"v126 formula subscripts remain readable in native trace names")
    XRD110_ComparePanel()
    Redimension/N=2 order;order[0]=c;order[1]=a
    String/G root:Packages:XRDWorkbench:activeProject=p2
    XRD126_Apply()
    Wave/T originalSelection126=$(settings+":uids")
    XRD_TestCheck(numpnts(originalSelection126)==2 && cmpstr(originalSelection126[0],uc)==0,"v126 chooser applies to its original project after background project switch")
    String/G root:Packages:XRDWorkbench:activeProject=p1
    String/G root:XRD126ExpectedUIDs=uc+";"+ua+";"
    XRD_DrawLiveStack(win,0)
    XRD_TestCheck(GetRTError(1)==0,"v126 runtime clean")
    Print "V126_FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End

Function XRD126_ReopenCheck()
    Variable/G root:XRDTestFailures=0
    SVAR expected=root:XRD126ExpectedUIDs
    String settings=XRD120_CompareSettings(),actual="",paths=XRD_ComparePaths(),trace,win="XRDReviewGraph"
    Wave/T selected=$(settings+":uids")
    Variable i,resolved=1
    for(i=0;i<numpnts(selected);i+=1)
        actual+=selected[i]+";"
    endfor
    XRD_TestCheck(cmpstr(actual,expected)==0 && ItemsInList(paths)==2,"v126 fresh process retains exclusion and comparison order")
    XRD_TestCheck(NumVarOrDefault(settings+":spacing126",0)==180 && NumVarOrDefault(settings+":references126",0)==1 && NumVarOrDefault(settings+":peaks126",0)==1 && NumVarOrDefault(settings+":phases126",0)==1,"v126 fresh process retains all display settings")
    XRD_DrawLiveStack(win,0)
    for(i=0;i<ItemsInList(paths);i+=1)
        String data=StringFromList(i,paths),source=XRD126_Source(data,"int_norm",":Processed:intensity")
        trace=CleanupName(XRD126_Name(data,0,""),0,220)
        Wave w=TraceNameToWaveRef(win,trace)
        resolved=resolved && WaveExists(w)
        if(WaveExists(w))
            resolved=resolved && cmpstr(GetWavesDataFolder(w,2),source)==0
        endif
    endfor
    XRD_TestCheck(resolved,"v126 reopened readable traces resolve to existing aliases")
    XRD_TestCheck(GetRTError(1)==0,"v126 reopened runtime clean")
    Print "V126_REOPEN_FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End
