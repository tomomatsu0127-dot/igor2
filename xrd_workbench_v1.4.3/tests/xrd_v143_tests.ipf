#pragma rtGlobals=3
#include ":xrd_tests"

Function XRD143_TestAdopt(path,ref,reflection)
    String path
    Variable ref,reflection
    Wave peakIDs=$(path+":Peaks:peakID")
    Wave ids=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex")
    Wave reflections=$(path+":Assignments:refPeakIndex"),shifts=$(path+":Assignments:shift")
    Wave/T modes=$(path+":Assignments:mode"),times=$(path+":Assignments:created")
    Redimension/N=1 ids,refs,reflections,shifts,modes,times
    ids[0]=peakIDs[0];refs[0]=ref;reflections[0]=reflection;shifts[0]=0
    modes[0]="Primary";times[0]="test"
    XRD_InvalidateFit(path)
End

Function XRD143_TestRange(path,project)
    String path,project
    String win="XRDWorkbench#Pattern"
    Variable/G $(project+":activeStep")=3
    XRD_Panel();DoUpdate
    CtrlNamedBackground XRDAutoSave,stop
    GetAxis/W=$win/Q left
    XRD_TestCheck(V_min==-30 && V_max==140,"v143 identification defaults leave vertical clearance")
    XRD_TestCheck(strsearch(WinRecreation(win,0),"tick(bottom)=0",0)>=0 || strsearch(WinRecreation(win,0),"tick(bottom)=3",0)<0,"v143 angle ticks point outward")
    XRD_TestCheck(XRD143_SetRange(win,-15,159)==0,"v143 workbench intensity range can be set")
    XRD81_RefreshPeaks(path)
    XRD_ViewDeferred()
    XRD100_Zoom(path,25,4)
    DoUpdate/W=$win
    GetAxis/W=$win/Q left
    XRD_TestCheck(V_min==-15 && V_max==159,"v143 range survives refresh, modified callback and angular zoom")
    GetAxis/W=$win/Q bottom
    XRD_TestCheck(abs(V_max-V_min-4)<1e-8,"v143 angular zoom remains available")
    XRD_ApplyViewEntry(project+":Undo:Entry"+num2istr(mod(NumVarOrDefault(project+":Undo:sequence",1)-2,20)))
    XRD_ResetView();DoUpdate
    GetAxis/W=$win/Q left
    XRD_TestCheck(V_min==-30 && V_max==140,"v143 full range restores intensity defaults")
    Variable/G $(project+":activeStep")=1
    XRD_Panel()
    Variable/G $(project+":activeStep")=3
    XRD_Panel()
    XRD_TestCheck(WinType("XRDWorkbench#Pattern")==1 && WinType("XRDWorkbench#SideCompare")==1,"v143 switching between measurement and identification keeps both views")
End

Function XRD143_RunTests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_LoadReferenceFile("phase1.txt",1)
    XRD_LoadReferenceFile("phase2.txt",2)
    String project=XRD_Project()
    String/G $(project+":displayName")="DataOwner"
    Make/FREE/D/N=501 xx=20+0.05*p,yy=10+70*exp(-((xx[p]-25)/0.22)^2)
    String a=XRD_Store(xx,yy,"run_A.xy"),b=XRD_Store(xx,yy,"run_B.xy"),ua=XRD80_MeasurementUID(a),ub=XRD80_MeasurementUID(b)
    XRD_TestCheck(XRD100_SetSample(a,"025","x=0","raw long sample A")==0,"v143 registers sample A")
    a=XRD80_ResolveMeasurement(ua)
    XRD_TestCheck(XRD100_SetSample(b,"026","x=-0.2","raw long sample B")==0,"v143 registers sample B")
    b=XRD80_ResolveMeasurement(ub)
    XRD_Manual(a,25);XRD_Manual(b,25.1)
    XRD143_TestAdopt(a,1,0);XRD143_TestAdopt(b,2,0)
    XRD_TestCheck(strlen(XRD143_AssignmentConflicts(a,25,1,0))>0,"v143 alerts on another phase in the same project and angular tolerance")
    XRD_TestCheck(!strlen(XRD143_AssignmentConflicts(a,25,2,0)),"v143 same reference reflection does not warn")
    XRD_TestCheck(strlen(XRD143_AssignmentConflicts(a,25,2,1))>0,"v143 different reflections on the same card warn")
    XRD_TestCheck(!strlen(XRD143_AssignmentConflicts(a,24,1,0)),"v143 outside the tolerance does not warn")
    Variable/G $(b+":deleted")=1
    XRD_TestCheck(!strlen(XRD143_AssignmentConflicts(a,25,1,0)),"v143 excluded samples do not warn")
    Variable/G $(b+":deleted")=0
    XRD143_TestAdopt(b,0,-1)
    XRD_TestCheck(!strlen(XRD143_AssignmentConflicts(a,25,1,0)),"v143 Unknown does not warn")
    XRD143_TestAdopt(b,2,0)
    String/G $(project+":activeData")=a
    XRD143_TestRange(a,project)
    XRD_OpenReview()
    String label=AnnotationInfo("XRDReviewGraph","LiveLabel0",1)
    XRD_TestCheck(strsearch(label,"025",0)>=0 && strsearch(label," = 0",0)>=0 && strsearch(label,"DataOwner",0)<0 && strsearch(label,"raw long",0)<0,"v143 live comparison uses sample number and composition")
    XRD_TestCheck(NumVarOrDefault(project+":previewOpacity",0)==40,"v143 default overlay opacity is 40 percent")
    XRD_NewProject()
    String active=XRD_Project()
    String/G $(active+":displayName")="ActiveOther"
    XRD_TestCheck(XRD143_SetDefaults(18,10,-25,145,55)==0 && NumVarOrDefault(project+":previewOpacity",0)==55 && NumVarOrDefault(active+":previewOpacity",0)==55,"v143 Experiment-wide opacity also applies to existing projects")
    XRD_PlotWorkspace()
    String ui=XRD_PlotRoot()+":UI"
    XRD_TestCheck(abs(NumVarOrDefault(ui+":width",0)-18*72/2.54)<1e-6 && abs(NumVarOrDefault(ui+":height",0)-10*72/2.54)<1e-6,"v143 new figure uses Experiment-wide aspect")
    XRD_TestCheck(NumVarOrDefault(ui+":yMax143",0)==145 && NumVarOrDefault(ui+":opacity143",0)==55,"v143 new figure uses Experiment-wide range and opacity")
    Wave flags=$(ui+":flags")
    flags[][0]=48
    Variable/G $(ui+":offsetMode")=0
    String recipe=XRD_PlotSaveDraft("",warnIncomplete=0),win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    XRD_TestCheck(strlen(recipe)>0 && XRD_PlotDrawRecipe(recipe,0)==0,"v143 creates an overlay")
    XRD_TestCheck(cmpstr(XRD141_ExportName(win),"XRD DataOwner.png")==0,"v143 PNG name uses data owner rather than active project")
    XRD_TestCheck(strsearch(WinRecreation(win,0),"36044",0)>=0,"v143 overlay traces use the Experiment alpha")
    XRD_TestCheck(strsearch(AnnotationInfo(win,"Phases",0),"A=MT",0)>=0,"v143 phase legend is top-centered")
    XRD_TestCheck(XRD143_SetRange(win,-10,167)==0,"v143 saved graph accepts new axis limits")
    TextBox/W=$win/C/N=Condition1 "Custom sample annotation"
    ModifyGraph/W=$win lsize(Measurement1)=3
    String folder=recipe+":Snapshot:Sample1"
    Wave oldInt=$(folder+":intensity"),source=$(a+":Processed:intensity")
    Variable original=oldInt[4]
    source[4]=91
    XRD_InvalidateFit(a)
    XRD_TestCheck(oldInt[4]==original && NumVarOrDefault(recipe+":stale",0)==1,"v143 manual mode retains the stored data")
    XRD_TestCheck(XRD143_SyncRecipe(recipe,"")==0 && oldInt[4]==91 && NumVarOrDefault(recipe+":stale",1)==0,"v143 manual synchronization copies the changed data")
    GetAxis/W=$win/Q left
    XRD_TestCheck(V_min==-10 && V_max==167,"v143 sync retains axis limits")
    XRD_TestCheck(strsearch(AnnotationInfo(win,"Condition1",1),"Custom sample annotation",0)>=0,"v143 sync retains custom annotation")
    XRD_TestCheck(strsearch(TraceInfo(win,"Measurement1",0),"lSize(x)=3",0)>=0,"v143 sync retains trace style")
    Variable/G $(recipe+":autoSync143")=1
    source[4]=86
    XRD143_TestAdopt(a,2,0)
    XRD143_RefreshPendingPlots()
    Wave refs=$(folder+":refIndex")
    XRD_TestCheck(oldInt[4]==86 && refs[0]==2 && NumVarOrDefault(recipe+":stale",1)==0,"v143 queued automatic synchronization refreshes data and phase")
    XRD_TestCheck(WhichListItem("XRDNeedsUpdate",AnnotationList(win))<0,"v143 successful sync clears stale annotation")
    String rp=XRD_ReferencePath(1),draft=XRD80_Library()+":UI:Draft"
    XRD80_LibraryPanel()
    XRD80_SelectLibraryReference(1)
    String/G $(draft+":displayOverride")="spinel"
    String/G $(draft+":phaseClass")="Custom-type"
    XRD_TestCheck(XRD143_ResetReferenceName(1,draft)==0 && !strlen(StrVarOrDefault(draft+":displayOverride","missing")) && cmpstr(StrVarOrDefault(draft+":phaseClass",""),StrVarOrDefault(rp+":origin_phaseClass",""))==0,"v143 resets display name and original reference metadata in the draft")
    KillWindow/Z XRDLibrary
    SavePICT/O/E=-5/WIN=$win as output+"overlay143c.png"
    XRD_PlotCaptureNative(recipe)
    String/G root:testRecipe143=recipe
    SaveExperiment/C/F={1,"",0} as output+"synthetic143c.pxp"
    CtrlNamedBackground XRDAutoSave,stop
    Print "V143 FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End

Function XRD143_TestReopen()
    Variable/G root:XRDTestFailures=0
    SVAR storedRecipe=root:testRecipe143
    String recipe=storedRecipe,win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    XRD_TestCheck(NumVarOrDefault(recipe+":autoSync143",0)==1,"v143 synchronization setting persists across restart")
    XRD_TestCheck(XRD143_Default("opacity")==55 && abs(XRD143_Default("width")-18*72/2.54)<1e-6,"v143 Experiment defaults persist across restart")
    DoWindow/K $win
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,1)==0,"v143 native graph reopens after process restart")
    GetAxis/W=$win/Q left
    XRD_TestCheck(V_min==-10 && V_max==167 && strsearch(AnnotationInfo(win,"Condition1",1),"Custom sample annotation",0)>=0,"v143 manual range and annotation persist after restart")
    Print "V143 REOPEN FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End
