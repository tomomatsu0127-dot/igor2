#pragma rtGlobals=3
#include ":xrd_v120_tests"
Function XRD122_CloseCheck(win)
    String win
    String recreation=WinRecreation(win,0)
    XRD_TestCheck(strsearch(recreation,"/K=1",0)>=0,"v122 native no-dialog flag: "+win)
    DoWindow/F $win
    KillWindow $win
    XRD_TestCheck(!WinType(win),"v122 programmatic close preserves lifecycle: "+win)
End
Function XRD_RunClose122(output)
    String output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    Make/FREE/D/N=1001 xx=20+p*0.05,yy=2+100*exp(-((xx[p]-30)/0.1)^2)
    String path=XRD_Store(xx,yy,"close.xy"),project=XRD_Project()
    XRD_Manual(path,30)
    NVAR step=$(project+":activeStep")
    step=1;XRD_Panel()
    MoveWindow/W=XRDWorkbench 10,10,1410,850;XRD_ResizePanel()
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 180
    Cursor/P/W=XRDWorkbench#Pattern B XRDWB_Measured 280
    XRD122_CloseCheck("XRDWorkbench")
    XRD_TestCheck(DataFolderExists(path) && numpnts($(path+":Raw:twoTheta"))==1001,"v122 closing UI preserves measurement")
    XRD_Open();DoUpdate
    XRD_TestCheck(WinType("XRDWorkbench")==7 && pcsr(A,"XRDWorkbench#Pattern")==180 && pcsr(B,"XRDWorkbench#Pattern")==280,"v122 reopen restores both native cursors")
    ControlInfo/W=XRDWorkbench measurementLabel
    XRD_TestCheck(V_width>900,"v122 reopen restores expanded layout")
    XRD_SaveSettingsPanel();XRD122_CloseCheck("XRDSaveSettings")
    XRD_DetectionPanel();XRD122_CloseCheck("XRDDetectionSettings")
    XRD_QuickGuide()
    DoWindow/F XRDGuide
    KillWindow XRDGuide
    XRD_TestCheck(!WinType("XRDGuide"),"v122 generated guide closes")
    // Recipe-backed graph retains manual annotations and original stored macro.
    XRD_SetUnknown(path,0)
    XRD_PlotWorkspace()
    Wave flags=$(XRD_PlotRoot()+":UI:flags")
    flags[0][0]=16
    String recipe=XRD_PlotSaveDraft(""),win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    XRD_PlotDrawRecipe(recipe,0)
    TextBox/W=$win/C/N=KeepClose/F=0 "Manual annotation retained"
    XRD122_CloseCheck(win)
    XRD_TestCheck(strsearch(StrVarOrDefault(recipe+":nativeMacro",""),"Manual annotation retained",0)>=0,"v122 close captures edited native graph")
    XRD_PlotDrawRecipe(recipe,1)
    XRD_TestCheck(WhichListItem("KeepClose",AnnotationList(win))>=0,"v122 recipe reopens manual graph edit")
    XRD122_CloseCheck(win)
    // Simulate an older saved graph whose creation command had /K=0.
    String/G $(recipe+":nativeMacro")=ReplaceString("/K=1",StrVarOrDefault(recipe+":nativeMacro",""),"/K=0")
    XRD_PlotDrawRecipe(recipe,1)
    XRD122_CloseCheck(win)
    CtrlNamedBackground XRDAutoSave,stop
    NVAR failures=root:XRDTestFailures
    Print "v122 close failures=",failures,"RTE=",GetRTError(1)
End
