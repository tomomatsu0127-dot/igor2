#pragma rtGlobals=3
#include ":xrd_v129_tests"
Function XRD_RunV130Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    XRD_TestCheck(cmpstr(XRD130_FileSerial("C:Data:0015_sample.xy"),"0015")==0,"v130 leading serial preserves zeroes")
    XRD_TestCheck(cmpstr(XRD130_FileSerial("123 sample.dat"),"123")==0,"v130 leading serial without underscore")
    XRD_TestCheck(!strlen(XRD130_FileSerial("sample_015.xy")),"v130 non-leading digits never become a serial")
    Make/FREE/D/N=3001 xx=10+0.025*p,yy=2+100*exp(-((xx[p]-30.05)/0.16)^2)+60*exp(-((xx[p]-50.1)/0.21)^2)
    XRD_TestCheck(abs(xx[XRD130_RawMaximum(xx,yy,30.025,0.05)]-30.05)<1e-9,"v130 smoothing candidate snaps to measured apex")
    String path=XRD_Store(xx,yy,"0015_synthetic.xy"),project=XRD_Project()
    XRD_DetectRobust(path,1)
    Wave angles=$(path+":Peaks:angle"),indices=$(path+":Peaks:pointIndex"),height=$(path+":Peaks:height"),measured=$(path+":Processed:intensity"),ids=$(path+":Peaks:peakID")
    XRD_TestCheck(numpnts(angles)==2,"v130 robust detector finds both measured mountains")
    Variable i,index
    for(i=0;i<numpnts(angles);i+=1)
        index=indices[i]
        XRD_TestCheck(angles[i]==xx[index] && height[i]==measured[index] && measured[index]>=measured[index-1] && measured[index]>=measured[index+1],"v130 registered marker is an original measured apex "+num2istr(i))
    endfor
    Variable/G $(project+":activeStep")=1
    XRD_Panel();DoUpdate
    CtrlNamedBackground XRDAutoSave,stop
    XRD_TestCheck(WhichListItem("projects110",ControlNameList("XRDWorkbench",";"))<0,"v130 redundant project button is absent")
    XRD_TestCheck(WhichListItem("peakZoom130",ControlNameList("XRDWorkbench",";"))>=0,"v130 step-one zoom span can be changed")
    Duplicate/FREE angles,savedAngles
    Duplicate/FREE ids,savedIDs
    XRD100_Select(path,0,1)
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs((V_max-V_min)-10)<0.001 && abs((V_max+V_min)/2-angles[0])<0.001,"v130 measured-peak selection zooms to plus-minus five degrees")
    XRD_TestCheck(WaveCRC(0,angles)==WaveCRC(0,savedAngles) && WaveCRC(0,ids)==WaveCRC(0,savedIDs),"v130 selecting a marker preserves peak coordinates and IDs")
    Wave display=$(path+":Preview:peakDisplay130")
    XRD_TestCheck(abs(display[0]-interp(angles[0],xx,measured))<1e-9,"v130 display markers remain on the measured curve")
    XRD110_RegisterPanel("")
    XRD_TestCheck(WhichListItem("copy120",ControlNameList("XRDRegister110",";"))<0,"v130 identified-sample-copy item removed from registration")
    XRD_TestCheck(strsearch(WinRecreation("XRDRegister110",0),"/FLTH=1",0)>=0,"v130 auxiliary panel hides when Igor is deactivated")
    KillWindow/Z XRDRegister110
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_LoadReferenceFile("phase1.txt",1)
    XRD_LoadReferenceFile("phase2.txt",2)
    XRD_TestCheck(!strlen(XRD81_AllUsedStyles()),"v130 legend order has no unassigned-reference fallback")
    XRD80_TestAdopt(path,0,1,0)
    XRD80_TestAdopt(path,1,2,0)
    Variable/G $(project+":selectedReference")=0
    XRD_StylePanel()
    SetWindow XRDStyles userdata(identity130)="same-editor"
    STRUCT WMPopupAction pa
    pa.eventCode=2;pa.popNum=2;pa.popStr="phase2"
    XRD_StyleTargetAction(pa)
    XRD_TestCheck(cmpstr(GetUserData("XRDStyles","","identity130"),"same-editor")==0,"v130 style target changes reuse the same native window")
    XRD_TestCheck(str2num(GetUserData("XRDStyles","","XRDRef"))==2,"v130 existing style editor is rebound to the chosen phase")
    KillWindow/Z XRDStyles
    Variable/G $(project+":activeStep")=4
    XRD_Panel();DoUpdate
    CtrlNamedBackground XRDAutoSave,stop
    XRD_TestCheck(WinType("XRDWorkbench#SideCompare")!=0,"v130 lattice screen retains its comparison graph")
    XRD_TestCheck(WhichListItem("XRDWB_Preview",TraceNameList("XRDWorkbench#Pattern",";",1))<0,"v130 lattice main graph has no reference sticks")
    String traces=TraceNameList("XRDWorkbench#SideCompare",";",1)
    XRD_TestCheck(strsearch(traces,"_reference_R",0)<0 && strsearch(traces,"LiveReference",0)<0,"v130 lattice comparison has no reference sticks")
    String rp=XRD_ReferencePath(1)
    Variable/G $(rp+":latticeA130")=5.89
    Variable/G $(rp+":latticeC130")=23.2
    NewDataFolder/O $(path+":Lattice")
    Variable/G $(path+":Lattice:refIndex")=1
    Variable/G $(path+":Lattice:a")=5.9
    Variable/G $(path+":Lattice:c")=23.3
    Variable/G $(path+":Lattice:aSigma")=0.01
    Variable/G $(path+":Lattice:cSigma")=0.02
    String/G $(path+":Lattice:crystalSystem")="六方晶"
    XRD130_ReferenceComparison(path,refresh=1)
    Wave/T comparison=$(path+":Lattice:comparison130")
    XRD_TestCheck(DimSize(comparison,0)==2 && cmpstr(comparison[0][3],"5.89")==0 && cmpstr(comparison[1][3],"23.2")==0,"v130 explicit reference lattice constants appear beside fitted constants")
    XRD_TestCheck(abs(XRD130_CellNumber("a_nm","0.589 nm")-5.89)<1e-10 && XRD130_CellAxis("_cell_length_c")==2,"v130 reference metadata keys and nm units are normalized explicitly")
    XRD_PlotWorkspace()
    CtrlNamedBackground XRDAutoSave,stop
    String ui=XRD_PlotRoot()+":UI"
    String incomplete=XRD_Store(xx,yy,"0016_unfinished.xy")
    XRD_PlotSelectionTable(1)
    Wave/T paths=$(ui+":paths")
    Wave flags=$(ui+":flags")
    Variable row=-1
    for(i=0;i<numpnts(paths);i+=1)
        if(cmpstr(paths[i],incomplete)==0)
            row=i;flags[i][0]=48
        endif
    endfor
    XRD_TestCheck(row>=0,"v130 unfinished data are available in the plot selector")
    String warning=XRD130_IncompletePlot(paths,flags)
    XRD_TestCheck(ItemsInList(warning)==1 && cmpstr(StringFromList(0,warning),XRD80_MeasurementUID(incomplete))==0,"v130 pre-plot warning identifies unfinished source UIDs")
    String recipe=XRD_PlotSaveDraft("",warnIncomplete=0)
    XRD_TestCheck(strlen(recipe)>0 && cmpstr(StrVarOrDefault(recipe+":acknowledgedIncomplete130",""),warning)==0,"v130 acknowledged unfinished data can be saved as a figure recipe")
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,0)==0,"v130 an unfinished measurement produces a graph")
    XRD110_PlotTrees()
    STRUCT WMWinHookStruct hook
    hook.winName="XRDPlotWorkspace";hook.eventCode=22;hook.wheelDy=-1
    ControlInfo/W=XRDPlotWorkspace sourceTree
    hook.mouseLoc.h=V_left+60;hook.mouseLoc.v=V_top+40
    XRD_TestCheck(XRD110_WheelHook(hook)==1,"v130 source-project list consumes wheel scrolling inside its bounds")
    Print "V130 FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
    return NumVarOrDefault("root:XRDTestFailures",-1)
End
