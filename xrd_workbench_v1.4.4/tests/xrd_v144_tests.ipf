#pragma rtGlobals=3
#include ":xrd_tests"

Function XRD144_HasInwardTicks(win,axis)
    String win,axis
    return strsearch(AxisInfo(win,axis),"tick(x)=2;",0)>=0
End

Function XRD144_TestTicks(output)
    String output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    Make/FREE/D/N=601 xx=15+0.1*p,yy=10+80*exp(-((xx[p]-31)/0.6)^2)
    String path=XRD_Store(xx,yy,"synthetic.xy")
    Variable/G $(XRD_Project()+":activeStep")=3
    XRD_Panel()
    DoUpdate
    CtrlNamedBackground XRDAutoSave,stop
    String pattern="XRDWorkbench#Pattern",side="XRDWorkbench#SideCompare",review="XRDReviewGraph"
    XRD_TestCheck(XRD144_HasInwardTicks(pattern,"bottom"),"v144 Workbench pattern has inward ticks")
    XRD_TestCheck(XRD144_HasInwardTicks(side,"bottom"),"v144 embedded comparison has inward ticks")
    XRD_TestCheck(XRD143_SetRange(pattern,-16,153)==0 && XRD144_HasInwardTicks(pattern,"bottom"),"v144 changing Workbench limits preserves inward ticks")
    GetAxis/W=$pattern/Q left
    XRD_TestCheck(V_min==-16 && V_max==153,"v144 Workbench accepts both intensity limits")
    XRD_OpenReview()
    ModifyGraph/W=$review tick(bottom)=0
    XRD_OpenReview()
    XRD_TestCheck(XRD144_HasInwardTicks(review,"bottom"),"v144 reopening an old live comparison restores inward ticks")

    XRD_PlotWorkspace()
    String ui=XRD_PlotRoot()+":UI"
    Wave flags=$(ui+":flags")
    flags[0][0]=48
    String recipe=XRD_PlotSaveDraft("",warnIncomplete=0)
    String win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    XRD_PlotDrawRecipe(recipe,0)
    XRD_TestCheck(XRD144_HasInwardTicks(win,"bottom") && strsearch(AxisInfo(win,"bottom"),"mirror(x)=1;",0)>=0,"v144 new plot mirrors the inward ticks at the top")
    XRD143_SetRange(win,-18,156)
    SetAxis/W=$win bottom 23,65
    TextBox/W=$win/C/N=Condition1 "Custom sample label"
    ModifyGraph/W=$win lsize(Measurement1)=2.5,tick(bottom)=0
    XRD_PlotCaptureNative(recipe)
    XRD_PlotDrawRecipe(recipe,1)
    XRD_TestCheck(XRD144_HasInwardTicks(win,"bottom"),"v144 existing open plot is corrected")
    ModifyGraph/W=$win tick(bottom)=0
    XRD_PlotCaptureNative(recipe)
    DoWindow/K $win
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,1)==0 && XRD144_HasInwardTicks(win,"bottom"),"v144 an old saved native plot reopens with inward ticks")
    GetAxis/W=$win/Q left
    XRD_TestCheck(V_min==-18 && V_max==156,"v144 correcting an old plot preserves intensity limits")
    GetAxis/W=$win/Q bottom
    XRD_TestCheck(V_min==23 && V_max==65,"v144 correcting an old plot preserves angular limits")
    XRD_TestCheck(strsearch(AnnotationInfo(win,"Condition1",1),"Custom sample label",0)>=0 && strsearch(TraceInfo(win,"Measurement1",0),"lSize(x)=2.5",0)>=0,"v144 correcting an old plot preserves custom labels and line width")
    SavePICT/O/E=-5/WIN=$win as output+"inward_v144.png"
    String/G root:XRD144Recipe=recipe
    SaveExperiment/C/F={1,"",0} as output+"test_v144.pxp"
    CtrlNamedBackground XRDAutoSave,stop
    Print "V144 FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End

Function XRD144_TestReopen()
    SVAR recipe=root:XRD144Recipe
    String win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    Variable/G root:XRDTestFailures=0
    XRD_TestCheck(XRD144_HasInwardTicks(win,"bottom"),"v144 the saved experiment retains inward ticks after restart")
    DoWindow/K $win
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,1)==0 && XRD144_HasInwardTicks(win,"bottom"),"v144 the saved figure can be reopened after restart")
    Print "V144 REOPEN FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End
