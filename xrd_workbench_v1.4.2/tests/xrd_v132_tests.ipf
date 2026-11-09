#pragma rtGlobals=3
#include ":xrd_tests"

Function XRD132_PurgeWithinFrame()
    ControlInfo/W=XRDWorkbench workGroup
    Variable groupLeft=V_left,groupTop=V_top,groupRight=V_left+V_width,groupBottom=V_top+V_height
    ControlInfo/W=XRDWorkbench purgeData
    return V_flag==1 && V_left>=groupLeft+2 && V_top>=groupTop+2 && V_left+V_width<=groupRight-2 && V_top+V_height<=groupBottom-2
End

Function XRD132_RunTests(output)
    String output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    Make/FREE/D/N=601 xx=10+0.1*p,yy=20+70*exp(-((xx[p]-29)/0.8)^2)+30*exp(-((xx[p]-48)/1.0)^2)
    String path=XRD_Store(xx,yy,"synthetic.xy")
    String/G $(path+":conditionLabel")="x=-0.2"
    XRD_Panel(); DoUpdate
    CtrlNamedBackground XRDAutoSave,stop
    XRD_TestCheck(XRD132_PurgeWithinFrame(),"v132 purge button inside normal work group")
    Variable mode
    for(mode=0;mode<3;mode+=1)
        Variable/G root:Packages:XRDWorkbench:UI:textMode=mode
        MoveWindow/W=XRDWorkbench 10,10,550,340
        XRD_ResizePanel(); DoUpdate
        XRD_TestCheck(XRD132_PurgeWithinFrame(),"v132 purge button inside compact work group at text size "+num2istr(mode))
    endfor
    Variable/G root:Packages:XRDWorkbench:UI:textMode=0
    XRD_ResizePanel(); DoUpdate

    GetWindow kwFrameInner wsize
    Variable frameW=V_right-V_left,frameH=V_bottom-V_top
    String mainBox=XRD123_PanelState("XRDWorkbench")
    XRD80_LibraryPanel(); DoUpdate
    String libBox=XRD123_PanelState("XRDLibrary")
    GetWindow XRDLibrary wsizeForControls
    Variable libCanvas=V_right
    GetWindow XRDLibrary doScroll
    XRD_TestCheck(frameW>=885 || V_Value==1,"v132 reference panel scrolls when viewport is smaller")
    GetWindow XRDLibrary wsizeRM
    XRD_TestCheck(V_right-V_left<=frameW && V_bottom-V_top<=frameH,"v132 reference viewport fits workspace")
    XRD80_LibraryPanel(); DoUpdate
    GetWindow XRDLibrary wsizeForControls
    XRD_TestCheck(cmpstr(libBox,XRD123_PanelState("XRDLibrary"))==0 && abs(V_right-libCanvas)<1 && V_right>=950,"v132 reopening library retains viewport and design canvas")
    XRD_TestCheck(cmpstr(mainBox,XRD123_PanelState("XRDWorkbench"))==0,"v132 library leaves workbench rectangle unchanged")
    XRD110_RegisterPanel(""); DoUpdate
    GetWindow XRDRegister110 wsizeRM
    XRD_TestCheck(V_right-V_left<=frameW && V_bottom-V_top<=frameH,"v132 registration viewport fits workspace")
    KillWindow/Z XRDRegister110
    XRD_PlotWorkspace(); DoUpdate
    String plotBox=XRD123_PanelState("XRDPlotWorkspace")
    GetWindow XRDPlotWorkspace wsizeRM
    XRD_TestCheck(V_right-V_left<=frameW && V_bottom-V_top<=frameH,"v132 plot viewport fits workspace")
    GetWindow XRDPlotWorkspace wsizeForControls
    ControlInfo/W=XRDPlotWorkspace create
    Variable createBottom=V_top+V_height
    GetWindow XRDPlotWorkspace wsizeForControls
    XRD_TestCheck(createBottom<=V_bottom,"v132 create button within plot canvas")

    String italic=num2char(92)+"f02x"+num2char(92)+"f00"
    XRD_TestCheck(cmpstr(XRD132_CompositionLabel("x=-0.2"),italic+" = −0.2")==0,"v132 standalone composition typography")
    XRD_TestCheck(cmpstr(XRD132_CompositionLabel("試料 x  =  －.2 / A-01"),"試料 "+italic+" = −.2 / A-01")==0,"v132 normalizes spacing and minus without changing other hyphens")
    XRD_TestCheck(cmpstr(XRD132_CompositionLabel("x=0.2"),italic+" = 0.2")==0,"v132 normalizes spacing for positive composition")
    XRD_TestCheck(cmpstr(XRD132_CompositionLabel("max=-0.2"),"max=-0.2")==0,"v132 leaves unrelated words unchanged")
    XRD_TestCheck(cmpstr(XRD132_CompositionLabel((num2char(92)+"f01x=-0.2")),(num2char(92)+"f01x=-0.2"))==0,"v132 retains manually styled labels")

    String ui=XRD_PlotRoot()+":UI"
    Wave flags=$(ui+":flags")
    Wave/T labels=$(ui+":labels")
    flags[0][0]=48
    String recipe=XRD_PlotSaveDraft("",warnIncomplete=0)
    XRD_TestCheck(strlen(recipe)>0 && XRD_PlotDrawRecipe(recipe,0)==0,"v132 creates graph with formatted composition")
    String win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    Wave/T savedLabels=$(recipe+":sourceLabels")
    XRD_TestCheck(cmpstr(savedLabels[0],"x=-0.2")==0 && cmpstr(StrVarOrDefault(path+":conditionLabel",""),"x=-0.2")==0,"v132 keeps raw saved and editable labels")
    XRD_TestCheck(strsearch(AnnotationInfo(win,"Condition1",1),italic+" = −0.2",0)>=0,"v132 native annotation uses italic x, spaces and mathematical minus")
    XRD_TestCheck(cmpstr(WinName(0,65),win)==0 && cmpstr(plotBox,XRD123_PanelState("XRDPlotWorkspace"))==0 && cmpstr(mainBox,XRD123_PanelState("XRDWorkbench"))==0,"v132 graph foreground preserves panel rectangles")
    SavePICT/O/E=-5/WIN=$win as output+"composition.png"
    labels[0]="x=-0.3"
    XRD_TestCheck(XRD81_ApplyPlotLive(recipe)==0 && strsearch(AnnotationInfo(win,"Condition1",1),italic+" = −0.3",0)>=0,"v132 live update uses the same formatting")
    TextBox/W=$win/C/N=Condition1 "Custom annotation"
    XRD_PlotCaptureNative(recipe)
    DoWindow/K $win
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,1)==0 && strsearch(AnnotationInfo(win,"Condition1",1),"Custom annotation",0)>=0,"v132 reopening a graph retains manual edits")
    Print "V132 FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
    CtrlNamedBackground XRDAutoSave,stop
End
