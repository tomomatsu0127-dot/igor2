#pragma rtGlobals=3
#include ":xrd_v120_tests"
Function XRD123_Box(win,box)
    String win
    Wave box
    GetWindow $win wsize
    box[0]=V_left;box[1]=V_top;box[2]=V_right;box[3]=V_bottom
End
Function XRD123_BoxSame(win,box)
    String win
    Wave box
    Make/FREE/D/N=4 actual
    XRD123_Box(win,actual)
    return abs(actual[0]-box[0])<1 && abs(actual[1]-box[1])<1 && abs(actual[2]-box[2])<1 && abs(actual[3]-box[3])<1
End
Function XRD123_OpenAux(kind)
    Variable kind
    switch(kind)
        case 0:
            XRD80_LibraryPanel()
            break
        case 1:
            XRD110_Manager()
            break
        case 2:
            XRD_ElementPanel()
            break
        case 3:
            XRD_DetectionPanel()
            break
        case 4:
            XRD_SaveSettingsPanel()
            break
        case 5:
            XRD_PlotWorkspace()
            break
        case 6:
            XRD110_ComparePanel()
            break
        case 7:
            XRD100_ViewOptions()
            break
        case 8:
            XRD_TypePanel()
            break
        case 9:
            XRD_MatchSettingsPanel()
            break
    endswitch
End
Function XRD_RunV123Tests()
    Variable/G root:XRDTestFailures=0
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    Make/FREE/D/N=1001 xx=20+p*0.05,yy=2+100*exp(-((xx[p]-30)/0.1)^2)
    String path=XRD_Store(xx,yy,"size123.xy"),project=XRD_Project()
    XRD_Manual(path,30)
    XRD_Panel()
    Wave raw=$(path+":Raw:intensity"),processed=$(path+":Processed:intensity"),peaks=$(path+":Peaks:angle")
    Variable rawCRC=WaveCRC(0,raw),processedCRC=WaveCRC(0,processed),peakCRC=WaveCRC(0,peaks)
    String panels="XRDLibrary;XRDProjectManager;XRDElements;XRDDetectionSettings;XRDSaveSettings;XRDPlotWorkspace;XRDCompareSelection;XRDOptions100;XRDTypeCards;XRDMatchSettings",win,instance=GetUserData("XRDWorkbench","","XRDInstance")
    Variable mode,i,j
    Make/FREE/D/N=4 mainBox,auxBox
    for(mode=0;mode<2;mode+=1)
        MoveWindow/W=XRDWorkbench 10,40,1410,880
        if(mode)
            MoveWindow/W=XRDWorkbench 2,2,2,2
        endif
        XRD_ResizePanel();DoUpdate
        XRD123_Box("XRDWorkbench",mainBox)
        for(i=0;i<10;i+=1)
            win=StringFromList(i,panels)
            XRD123_OpenAux(i);DoUpdate
            XRD_TestCheck(strsearch(WinRecreation(win,0),"/FLT=1",0)>=0,"v123 auxiliary independent from MDI maximize: "+win)
            XRD_TestCheck(XRD123_BoxSame("XRDWorkbench",mainBox),"v123 main geometry after opening: "+win)
            GetWindow XRDWorkbench maximize
            XRD_TestCheck(V_Value==mode,"v123 main maximize after opening: "+win)
            MoveWindow/W=$win 60,80,1260,780
            DoUpdate
            XRD123_Box(win,auxBox)
            for(j=0;j<3;j+=1)
                XRD123_OpenAux(i);DoUpdate
                XRD_TestCheck(XRD123_BoxSame(win,auxBox),"v123 auxiliary retains size and position: "+win)
                XRD_TestCheck(XRD123_BoxSame("XRDWorkbench",mainBox),"v123 main geometry after refresh: "+win)
            endfor
            KillWindow $win
            DoWindow/F XRDWorkbench;DoUpdate
            XRD_TestCheck(XRD123_BoxSame("XRDWorkbench",mainBox),"v123 main geometry after close: "+win)
            GetWindow XRDWorkbench maximize
            XRD_TestCheck(V_Value==mode,"v123 main maximize after close: "+win)
            XRD_TestCheck(GetRTError(1)==0,"v123 native runtime clean: "+win)
        endfor
    endfor
    // Exercise real control callbacks with the main graph still present.
    XRD_ElementPanel()
    STRUCT WMButtonAction ba
    ba.eventCode=2;ba.ctrlName="elFe";ba.win="XRDElements"
    XRD_ElementButton(ba)
    XRD_TestCheck(WhichListItem("Fe",StrVarOrDefault(project+":allowedElements",""))>=0,"v123 floating element control targets correct project")
    KillWindow XRDElements
    XRD_PlotWorkspace();MoveWindow/W=XRDPlotWorkspace 60,80,1260,780;DoUpdate
    XRD123_Box("XRDPlotWorkspace",auxBox)
    XRD110_PlotControls();DoUpdate
    XRD_TestCheck(XRD123_BoxSame("XRDPlotWorkspace",auxBox),"v123 plot controls do not force initial size")
    XRD110_Manager();MoveWindow/W=XRDProjectManager 60,80,1260,780;DoUpdate
    XRD123_Box("XRDProjectManager",auxBox)
    XRD100_ManagerControls();DoUpdate
    XRD_TestCheck(XRD123_BoxSame("XRDProjectManager",auxBox),"v123 manager controls do not force initial size")
    XRD_TestCheck(cmpstr(instance,GetUserData("XRDWorkbench","","XRDInstance"))==0,"v123 main frame reused")
    XRD_TestCheck(WaveCRC(0,raw)==rawCRC && WaveCRC(0,processed)==processedCRC && WaveCRC(0,peaks)==peakCRC,"v123 raw processed and peaks unchanged")
    CtrlNamedBackground XRDAutoSave,stop
    NVAR failures=root:XRDTestFailures
    Print "v123 failures=",failures,"RTE=",GetRTError(1)
End
