#pragma rtGlobals=3
#include ":xrd_v123_tests"
Function XRD_RunV124Tests()
    Variable/G root:XRDTestFailures=0
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    Make/FREE/D/N=1001 xx=20+p*0.05,yy=2+100*exp(-((xx[p]-30)/0.1)^2)
    String path=XRD_Store(xx,yy,"modal124.xy"),project=XRD_Project()
    XRD_Manual(path,30)
    Wave raw=$(path+":Raw:intensity"),processed=$(path+":Processed:intensity"),peaks=$(path+":Peaks:angle")
    Variable rawCRC=WaveCRC(0,raw),processedCRC=WaveCRC(0,processed)
    XRD_Panel();MoveWindow/W=XRDWorkbench 2,2,2,2
    DoUpdate
    Make/FREE/D/N=4 mainBox,libraryBox,managerBox
    XRD123_Box("XRDWorkbench",mainBox)
    XRD80_LibraryPanel();XRD110_Manager()
    MoveWindow/W=XRDLibrary 40,50,1240,750
    MoveWindow/W=XRDProjectManager 70,80,1080,810
    XRD123_Box("XRDLibrary",libraryBox)
    XRD123_Box("XRDProjectManager",managerBox)
    NewPanel/FLT=1/K=1/N=XRDHidden124/W=(1,1,100,100)
    SetActiveSubwindow _endfloat_
    SetWindow XRDHidden124 hide=1
    NewPanel/FLT=1/K=1/N=Foreign124/W=(1,1,100,100)
    SetActiveSubwindow _endfloat_
    String hidden=XRD124_BeginModal(),nested=XRD124_BeginModal()
    XRD_TestCheck(WhichListItem("XRDLibrary",hidden)>=0 && WhichListItem("XRDProjectManager",hidden)>=0,"v124 guards both auxiliary panels")
    XRD_TestCheck(WhichListItem("XRDHidden124",hidden)<0 && WhichListItem("Foreign124",hidden)<0,"v124 excludes hidden and foreign panels")
    XRD_TestCheck(!strlen(nested),"v124 nested dialog does not own outer visibility")
    GetWindow XRDLibrary hide
    XRD_TestCheck((V_Value & 1)==1,"v124 library hidden while dialog waits")
    GetWindow XRDProjectManager hide
    XRD_TestCheck((V_Value & 1)==1,"v124 manager hidden while dialog waits")
    GetWindow Foreign124 hide
    XRD_TestCheck((V_Value & 1)==0,"v124 foreign panel remains visible")
    XRD124_EndModal(nested)
    GetWindow XRDLibrary hide
    XRD_TestCheck((V_Value & 1)==1,"v124 nested completion keeps outer panels hidden")
    XRD124_EndModal(hidden)
    GetWindow XRDLibrary hide
    XRD_TestCheck((V_Value & 1)==0,"v124 library restored after dialog")
    GetWindow XRDProjectManager hide
    XRD_TestCheck((V_Value & 1)==0,"v124 manager restored after dialog")
    GetWindow XRDHidden124 hide
    XRD_TestCheck((V_Value & 1)==1,"v124 originally hidden panel remains hidden")
    XRD_TestCheck(XRD123_BoxSame("XRDLibrary",libraryBox),"v124 library geometry unchanged")
    XRD_TestCheck(XRD123_BoxSame("XRDProjectManager",managerBox),"v124 manager geometry unchanged")
    XRD_TestCheck(XRD123_BoxSame("XRDWorkbench",mainBox),"v124 main geometry unchanged")
    GetWindow XRDWorkbench maximize
    XRD_TestCheck(V_Value==1,"v124 main stays maximized")
    hidden=XRD124_BeginModal()
    KillWindow XRDProjectManager
    XRD124_EndModal(hidden)
    XRD_TestCheck(!WinType("XRDProjectManager"),"v124 closed panel is not recreated")
    XRD_TestCheck(WaveCRC(0,raw)==rawCRC && WaveCRC(0,processed)==processedCRC && numpnts(peaks)==1,"v124 raw processed and peak data remain intact")
    XRD_TestCheck(GetRTError(1)==0,"v124 runtime clean")
    KillWindow Foreign124;KillWindow XRDHidden124;KillWindow XRDLibrary
    Print "V124_FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End
