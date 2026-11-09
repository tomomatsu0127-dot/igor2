#pragma rtGlobals=3
Function XRD_V51KeySetup()
    XRD_Init()
    XRD_NewProject()
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=5+100*exp(-((xx[p]-31)/0.08)^2)
    String path=XRD_Store(xx,yy,"KEYBOARD_TEST_SYNTHETIC.xy"),project=XRD_Project()
    XRD_DetectLegacy(path)
    XRD_TestDisableFollow()
    XRD_Panel()
    Variable/G $(project+":Undo:count")=0
    Variable/G $(project+":Undo:sequence")=0
    XRD_ViewSync(path)
    SetAxis/W=XRDWorkbench#Pattern bottom 30,35
    XRD_RecordPendingZoom(path)
    XRD_Manual(path,33)
    XRD_TestDisableFollow()
    XRD_Panel()
    SetActiveSubwindow XRDWorkbench#Pattern
    DoWindow/T XRDWorkbench,"XRD v0.5.1 KEYBOARD TEST - synthetic data only"
End
