#pragma rtGlobals=3
#include ":xrd_v124_tests"
Function XRD_RunV125Tests()
    Variable/G root:XRDTestFailures=0
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    Make/FREE/D/N=4001 xx=10+p*0.02,yy=2
    Variable i,row,first
    for(i=0;i<60;i+=1)
        yy+=100*exp(-((xx[p]-(15+i))/0.08)^2)
    endfor
    String path=XRD_Store(xx,yy,"selection125.xy")
    for(i=0;i<60;i+=1)
        XRD_Manual(path,15+i)
    endfor
    Variable/G $(XRD_Project()+":activeStep")=3
    XRD_Panel();DoUpdate
    Wave angles=$(path+":Peaks:angle"),ids=$(path+":Peaks:peakID"),raw=$(path+":Raw:intensity")
    Duplicate/FREE angles,beforeAngles
    Duplicate/FREE ids,beforeIDs
    Variable rawCRC=WaveCRC(0,raw)
    STRUCT WMListboxAction lba
    lba.ctrlName="peakList";lba.win="XRDWorkbench";lba.eventCode=4
    Make/FREE/D wanted={20,18,22,33,47,59}
    for(i=0;i<numpnts(wanted);i+=1)
        row=wanted[i];first=max(0,row-5)
        ListBox peakList,win=XRDWorkbench,row=first
        lba.row=row
        XRD_TestCheck(XRD_PeakListAction(lba)==0,"v125 native list selection returns normal control result")
        ControlInfo/W=XRDWorkbench peakList
        XRD_TestCheck(V_Value==row && V_startRow==first,"v125 list click retains selected row and viewport "+num2istr(row))
        XRD_TestCheck(NumVarOrDefault(path+":selectedPeakRow",-1)==row && NumVarOrDefault(path+":selectedPeakID100",-1)==ids[row],"v125 selected stable peak ID matches clicked row")
    endfor
    XRD100_Select(path,12,1)
    ControlInfo/W=XRDWorkbench peakList
    XRD_TestCheck(V_Value==12 && V_startRow==9,"v125 graph selection still brings selected peak into view")
    lba.row=-1;XRD_PeakListAction(lba)
    lba.row=60;XRD_PeakListAction(lba)
    XRD_TestCheck(NumVarOrDefault(path+":selectedPeakRow",-1)==12,"v125 title and empty-space clicks never change selected peak")
    lba.row=14;lba.eventCode=8;XRD_PeakListAction(lba)
    XRD_TestCheck(NumVarOrDefault(path+":selectedPeakRow",-1)==12,"v125 scroll notifications are not selections")
    XRD_TestCheck(sum(abs(angles-beforeAngles))==0 && sum(abs(ids-beforeIDs))==0 && WaveCRC(0,raw)==rawCRC,"v125 navigation preserves all angles IDs and raw values")
    XRD110_Manager();XRD80_LibraryPanel()
    Make/FREE/D/N=4 managerBox,libraryBox
    XRD123_Box("XRDProjectManager",managerBox);XRD123_Box("XRDLibrary",libraryBox)
    XRD_TestCheck(XRD125_ManagerModal("unknown",XRD_Project())==-1,"v125 unsupported manager action has no data mutation")
    GetWindow XRDProjectManager hide
    XRD_TestCheck((V_Value & 1)==0 && XRD123_BoxSame("XRDProjectManager",managerBox),"v125 manager restored with original geometry")
    GetWindow XRDLibrary hide
    XRD_TestCheck((V_Value & 1)==0 && XRD123_BoxSame("XRDLibrary",libraryBox),"v125 other floating panel restored with original geometry")
    XRD_TestCheck(GetRTError(1)==0,"v125 runtime clean")
    Print "V125_FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End
