#pragma rtGlobals=3
#include ":xrd_tests"

Function XRD142_TestWindows()
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    Make/FREE/D/N=601 xx=10+0.1*p,yy=20+70*exp(-((xx[p]-29)/0.8)^2)
    String path=XRD_Store(xx,yy,"synthetic.xy"),project=XRD_Project()
    XRD_Panel()
    CtrlNamedBackground XRDAutoSave,stop
    XRD_AddPoint(path,190,"Manual")
    XRD80_ProjectManager()
    DoWindow/F XRDProjectManager
    String controls=ControlNameList("XRDProjectManager",";"),box=XRD123_PanelState("XRDWorkbench")
    Variable result=XRD81_SetPickMode(1)
    XRD_TestCheck(result==0 && !GetRTError(1),"v142 cursor info works with project manager in front")
    XRD_TestCheck(cmpstr(StringByKey("TNAME",CsrInfo(A,"XRDWorkbench#Pattern")),"XRDWB_Measured")==0,"v142 Cursor A belongs to measured graph")
    Variable/G $(project+":activeStep")=3
    result=XRD_Panel()
    XRD_TestCheck(result==0 && !GetRTError(1),"v142 rebuild restores cursor info with another panel in front")
    XRD_TestCheck(cmpstr(controls,ControlNameList("XRDProjectManager",";"))==0,"v142 project manager keeps only its own controls")
    XRD_TestCheck(cmpstr(box,XRD123_PanelState("XRDWorkbench"))==0,"v142 background rebuild preserves workbench rectangle")
    ControlInfo/W=XRDWorkbench matchActions
    XRD_TestCheck(V_flag==1 && WinType("XRDWorkbench#Pattern")==1 && WinType("XRDWorkbench#SideCompare")==1,"v142 identification button and both graph children exist")
    ControlInfo/W=XRDWorkbench candidateList
    XRD_TestCheck(V_flag==11 && strsearch(WinRecreation("XRDWorkbench",0),"title=\"New\"",0)<0,"v142 candidate list is present without placeholder controls")
    XRD_TestCheck(cmpstr(WinName(0,65),"XRDProjectManager")==0,"v142 background rebuild leaves project manager in front")
    CtrlNamedBackground XRDAutoSave,stop
    Print "V142 WINDOW FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End

Function XRD142_LegacyArrow(win,side)
    String win
    Variable side
    Variable x=SelectNumber(side,0.15,0.85),tip=SelectNumber(side,0.05,0.95)
    Variable red=SelectNumber(side,55000,0),blue=SelectNumber(side,0,54000)
    SetDrawEnv/W=$win xcoord=prel,ycoord=prel,linefgc=(red,0,blue),linethick=3
    DrawLine/W=$win x,0.39,x,0.32
    SetDrawEnv/W=$win xcoord=prel,ycoord=prel,linefgc=(red,0,blue),linethick=3,arrow=1,arrowlen=7,arrowfat=0.9,arrowsharp=0
    DrawLine/W=$win x,0.32,tip,0.32
End

Function XRD142_TestArrows(output)
    String output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    String folder=XRD133_TrendFigures(),id="LTrend_Test142",recipe=folder+":"+id,win="XRDP_"+id
    NewDataFolder/O $folder
    NewDataFolder $recipe
    String/G $(recipe+":plotUID")=id
    String/G $(recipe+":crystal")="六方晶"
    Make/D $(recipe+":horizontal")={-0.1,0,0.2,0.4,0.5}
    Make/D $(recipe+":latticeA")={5.88,5.9,5.91,5.93,5.94}
    Make/D $(recipe+":latticeC")={14.25,14.27,14.28,14.29,14.32}
    Wave xx=$(recipe+":horizontal"),aa=$(recipe+":latticeA"),cc=$(recipe+":latticeC")
    Display/K=1/N=$win aa/TN=LatticeA vs xx
    AppendToGraph/W=$win/R cc/TN=LatticeC vs xx
    SetWindow $win userdata(XRDPlotRecipe)=recipe
    SetDrawLayer/W=$win UserFront
    DrawText/W=$win 0.3,0.2,"custom drawing"
    XRD142_LegacyArrow(win,0)
    XRD142_LegacyArrow(win,1)
    SetDrawEnv/W=$win xcoord=prel,ycoord=prel
    DrawLine/W=$win 0.31,0.28,0.36,0.33
    Variable x,y,d,legacy
    XRD_TestCheck(XRD142_ArrowPosition(win,0,x,y,d,legacy) && legacy>=0 && abs(y-0.32)<1e-6,"v142 reads original ungrouped a arrow")
    XRD_TestCheck(XRD142_ArrowPosition(win,1,x,y,d,legacy) && legacy>=0 && abs(x-0.85)<1e-6,"v142 reads original ungrouped c arrow")
    SetAxis/W=$win bottom -0.02,0.42
    SetAxis/W=$win left 5.89,5.945
    SetAxis/W=$win right 14.26,14.33
    ModifyGraph/W=$win manTick(bottom)={0,1,-1,1}
    Label/W=$win bottom "User axis label"
    XRD_TestCheck(XRD142_ArrowPanel(win)==0 && abs(NumVarOrDefault("root:Packages:XRDWorkbench:UI:ArrowPosition142:ay",0)-32)<1e-6,"v142 panel opens with original positions")
    XRD_TestCheck(XRD142_AdjustArrows(win,0,30,20,70,81)==0,"v142 independently positions both arrows")
    XRD_TestCheck(XRD142_ArrowPosition(win,0,x,y,d,legacy) && legacy<0 && abs(x-0.30)<1e-6 && abs(y-0.20)<1e-6,"v142 saved left arrow is a movable group")
    XRD_TestCheck(XRD142_ArrowPosition(win,1,x,y,d,legacy) && legacy<0 && abs(x-0.70)<1e-6 && abs(y-0.81)<1e-6,"v142 saved right arrow is a movable group")
    DrawAction/W=$win/L=UserFront commands
    XRD_TestCheck(strsearch(S_recreation,"custom drawing",0)>=0 && strsearch(S_recreation,"DrawLine 0.31,0.28,0.36,0.33",0)>=0 && strsearch(S_recreation,"DrawLine 0.15,0.32,0.05,0.32",0)<0,"v142 original arrows replaced while unrelated drawings survive")
    GetAxis/W=$win/Q bottom
    String macroText=WinRecreation(win,4)
    XRD_TestCheck(abs(V_min+0.02)<1e-12 && abs(V_max-0.42)<1e-12 && strsearch(macroText,"manTick(bottom)",0)>=0 && strsearch(macroText,"User axis label",0)>=0,"v142 edited axis limits ticks and label survive arrow placement")
    XRD_TestCheck(XRD142_AdjustArrows(win,1,0,0,0,0)==0 && XRD142_ArrowPosition(win,0,x,y,d,legacy),"v142 current-axis automatic placement")
    Variable before=y
    SetAxis/W=$win left 5.88,6.05
    SetAxis/W=$win right 14.25,14.45
    XRD_TestCheck(XRD142_AdjustArrows(win,1,0,0,0,0)==0 && XRD142_ArrowPosition(win,0,x,y,d,legacy) && abs(y-before)>0.03,"v142 automatic placement responds to edited vertical ranges")
    XRD142_AdjustArrows(win,0,30,20,70,81)
    SavePICT/O/E=-5/WIN=$win as output+"arrows.png"
    String/G root:XRD142TestRecipe=recipe
    KillWindow/Z XRDTrendArrows
    KillWindow/Z $win
    XRD142_CheckArrowReopen()
    Print "V142 ARROW FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
    return 0
End

Function XRD142_CheckArrowReopen()
    String recipe=StrVarOrDefault("root:XRD142TestRecipe",""),win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    XRD_TestCheck(XRD133_DrawTrend(recipe)==0,"v142 edited saved figure reopens")
    Variable x,y,d,legacy
    XRD_TestCheck(XRD142_ArrowPosition(win,0,x,y,d,legacy) && abs(x-0.3)<1e-6 && abs(y-0.2)<1e-6,"v142 left arrow retained after reopening")
    XRD_TestCheck(XRD142_ArrowPosition(win,1,x,y,d,legacy) && abs(x-0.7)<1e-6 && abs(y-0.81)<1e-6,"v142 right arrow retained after reopening")
    GetAxis/W=$win/Q bottom
    XRD_TestCheck(abs(V_min+0.02)<1e-12 && abs(V_max-0.42)<1e-12,"v142 user axis range retained after reopening")
End
