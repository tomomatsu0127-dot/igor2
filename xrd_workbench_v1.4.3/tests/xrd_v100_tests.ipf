#pragma rtGlobals=3
#include ":xrd_v82_tests"

Function XRD_RunV100Smoke(output)
    String output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    CtrlNamedBackground XRDAutoSave,stop
    String admin=XRD100_Admin()
    String/G $(admin+":backupFolder")=output
    String project=XRD_Project(),uid=XRD80_ProjectUID(project)
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=2+100*exp(-((xx[p]-30)/0.1)^2)
    String path=XRD_Store(xx,yy,"sample.xy"),sampleUID=XRD80_MeasurementUID(path)
    XRD_TestCheck(strsearch(project,":Workbench:Management:",0)>0,"v100 new project belongs to Management")
    Print "RENAME BEGIN"
    Variable result=XRD100_RenameProject(project,"CuFeQS1200inair")
    Print "RENAME RESULT "+num2istr(result)
    project=XRD100_ProjectByUID(uid)
    path=XRD80_ResolveMeasurement(sampleUID)
    XRD_TestCheck(result==0 && strsearch(project,"CuFeQS1200inair",0)>0 && strlen(path)>0,"v100 physical project rename preserves identity resolution")
    Print "SET META BEGIN"
    result=XRD100_SetSample(path,"023","x=0.2","試料A")
    path=XRD80_ResolveMeasurement(sampleUID)
    Print "SET META RESULT "+num2istr(result)
    XRD_TestCheck(result==0 && WaveExists($(project+":"+PossiblyQuoteName("int_023_x=0.2_CuFeQS1200inair"))),"v100 manual serial and separate composition create readable Waves")
    result=XRD100_RenameProject(project,"CuFeQS1250inair")
    project=XRD100_ProjectByUID(uid);path=XRD80_ResolveMeasurement(sampleUID)
    XRD_TestCheck(result==0 && WaveExists($(project+":"+PossiblyQuoteName("int_023_x=0.2_CuFeQS1250inair"))),"v100 rename updates readable Wave names")
    XRD_TestCheck(cmpstr(StrVarOrDefault(path+":sampleNumber",""),"023")==0 && cmpstr(StrVarOrDefault(path+":composition",""),"x=0.2")==0,"v100 rename preserves manual number and composition")
    XRD_Manual(path,30)
    Variable/G $(project+":activeStep")=3
    XRD_Panel()
    XRD100_Select(path,0,1)
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-25)<1e-8 && abs(V_max-35)<1e-8,"v100 first peak selection zooms to ten degrees")
    result=XRD100_TrashProject(project)
    XRD_TestCheck(result==0 && !strlen(XRD100_ProjectByUID(uid)) && strlen(XRD100_ProjectByUID(uid,deleted=1)),"v100 project deletion is recoverable and removed from active registry lookup")
    result=XRD100_RestoreProject(XRD100_ProjectByUID(uid,deleted=1),"CuFeQS1250inair")
    XRD_TestCheck(result==0 && strlen(XRD100_ProjectByUID(uid)) && strlen(XRD80_ResolveMeasurement(sampleUID)),"v100 restore preserves identities")
    NVAR failures=root:XRDTestFailures
    Print "v100 smoke failures="+num2istr(failures)
    return failures
End

Function XRD_RunV100Integration(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    CtrlNamedBackground XRDAutoSave,stop
    String admin=XRD100_Admin(),project=XRD_Project(),puid=XRD80_ProjectUID(project),path,uid,recipe,win,old,second,tx
    String/G $(admin+":backupFolder")=output
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_TestCheck(XRD_LoadReferenceFile("QS-A.txt",1)==0,"v100 normal shared reference imports")
    Wave ref=$(XRD_ReferencePath(1)+":twoTheta")
    Variable refCRC=WaveCRC(0,ref)
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=2+100*exp(-((xx[p]-30.1)/0.1)^2)+60*exp(-((xx[p]-44)/0.2)^2)
    path=XRD_Store(xx,yy,"sample.xy");uid=XRD80_MeasurementUID(path)
    XRD_Manual(path,30.1);XRD_Manual(path,44)
    XRD_TestCheck(XRD80_TestAdopt(path,0,1,0)==0 && XRD80_TestAdopt(path,1,1,2)==0,"v100 real reference assignments created")
    XRD_TestCheck(XRD100_SetSample(path,"023","x=0.2","試料023")==0,"v100 explicit sample metadata accepted")
    path=XRD80_ResolveMeasurement(uid)
    XRD_TestCheck(WaveExists($(project+":"+PossiblyQuoteName("int_QS-type_023_x=0.2_"+XRD_ProjectDisplayName(project)))),"v100 adopted-card named Wave created")
    Wave raw=$(path+":Raw:intensity"),assigned=$(path+":Assignments:refIndex"),hkl=$(path+":Assignments:refPeakIndex")
    Variable rawCRC=WaveCRC(0,raw),assignmentCRC=WaveCRC(0,assigned),hklCRC=WaveCRC(0,hkl),undoCount=NumVarOrDefault(project+":Undo:count",0)
    NewDataFolder/O $(path+":Lattice")
    Variable/G $(path+":Lattice:a")=5.89
    Make/O/D/N=(3,6) $(path+":Lattice:inputs")=p+q
    XRD80_RecordLatticeRun(path)
    Wave historyInput=$(path+":LatticeRuns:Run1:inputs")
    Variable historyCRC=WaveCRC(0,historyInput)
    XRD_PlotDefaults();XRD_PlotSelectionTable(1)
    String ui=XRD_PlotRoot()+":UI"
    Wave flags=$(ui+":flags")
    flags[][0]=48
    recipe=XRD_PlotSaveDraft("")
    XRD_TestCheck(strlen(recipe)>0 && XRD_PlotDrawRecipe(recipe,0)==0,"v100 independent saved figure created")
    win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    SetAxis/W=$win bottom 25,60
    Label/W=$win left "Custom intensity"
    ModifyGraph/W=$win lsize(Measurement1)=2.5
    XRD_PlotCaptureNative(recipe)
    Wave snap=$(recipe+":Snapshot:Sample1:intensity")
    Variable snapshotCRC=WaveCRC(0,snap)
    Make/O/T/N=1 $(XRD_PlotRoot()+":compareUIDs")=uid
    Variable/G $(project+":activeStep")=3
    XRD_Panel()
    String/G root:XRD100ProjectUID=puid
    String/G root:XRD100SampleUID=uid
    String/G root:XRD100Recipe=recipe
    old=project
    XRD_TestCheck(XRD100_RenameProject(project,"1250℃ in Air")==0,"v100 Unicode project physically renamed")
    project=XRD100_ProjectByUID(puid);path=XRD80_ResolveMeasurement(uid)
    XRD_TestCheck(!DataFolderExists(old) && DataFolderExists(project),"v100 old physical folder removed only after new location exists")
    XRD_TestCheck(strsearch(project,"'1250℃ in Air'",0)>0 && cmpstr(XRD_ProjectDisplayName(project),"1250℃ in Air")==0,"v100 quoted Unicode project and display name agree")
    XRD_TestCheck(WaveCRC(0,raw)==rawCRC && WaveCRC(0,assigned)==assignmentCRC && WaveCRC(0,hkl)==hklCRC,"v100 Raw assignments and hkl are byte-identical")
    XRD_TestCheck(WaveCRC(0,historyInput)==historyCRC && NumVarOrDefault(path+":Lattice:a",0)==5.89,"v100 lattice result and immutable history retained")
    XRD_TestCheck(XRD_IsAnalysisComplete(path) && NumVarOrDefault(project+":Undo:count",0)==undoCount,"v100 completion and Undo entry count retained")
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench","","XRDData"),path)==0 && WhichListItem(path,XRD_ComparePaths())>=0,"v100 Workbench and cross-project comparison resolve renamed source")
    Wave named=$(project+":"+PossiblyQuoteName("int_023_x=0.2_1250℃ in Air"))
    XRD_TestCheck(WaveExists(named) && strsearch(GetFormula(named),project+":",0)>=0,"v100 readable Wave and serialized dependency point at renamed source")
    XRD_TestCheck(WaveCRC(0,snap)==snapshotCRC && WinType(win)==1,"v100 independent figure snapshot and open window preserved")
    GetAxis/W=$win/Q bottom
    XRD_TestCheck(V_min==25 && V_max==60 && strsearch(StrVarOrDefault(recipe+":nativeMacro",""),"Custom intensity",0)>=0,"v100 saved manual graph formatting retained")
    XRD_TestCheck(WaveCRC(0,ref)==refCRC,"v100 shared reference is unchanged by rename")
    XRD_TestCheck(XRD100_RenameProject(project,"bad:name")==-1,"v100 illegal project name rejected")
    XRD_NewProject();second=XRD_Project()
    XRD_TestCheck(XRD100_RenameProject(second,"1250℃ in Air")==-1,"v100 duplicate project name rejected without overwrite")
    String/G root:Packages:XRDWorkbench:activeProject=project
    // Inject an error after every journaled mutation, including liberal Wave names.
    XRD100_PlanNames(project,"Failure target")
    Wave/T plan=$(admin+":namePlan")
    Variable operations=2+2*DimSize(plan,0),i,result
    for(i=1;i<=operations;i+=1)
        Variable/G $(admin+":faultAfter")=i
        result=XRD100_RenameProject(project,"Failure target")
        XRD_TestCheck(result<0 && DataFolderExists(project) && cmpstr(XRD100_ProjectByUID(puid),project)==0 && !XRD100_Busy(),"v100 rollback mutation "+num2istr(i))
        if(XRD100_Busy() || !DataFolderExists(project))
            break
        endif
        XRD_TestCheck(WaveCRC(0,raw)==rawCRC && WaveCRC(0,assigned)==assignmentCRC && WaveCRC(0,historyInput)==historyCRC,"v100 rollback keeps scientific data "+num2istr(i))
    endfor
    Variable/G $(admin+":faultAfter")=0
    XRD_TestCheck(XRD100_RenameProject(project,"CuFeQS1250inair")==0,"v100 project rename succeeds after failure recovery")
    project=XRD100_ProjectByUID(puid);path=XRD80_ResolveMeasurement(uid)
    String/G root:Packages:XRDWorkbench:activeProject=project
    XRD_Panel()
    // View-only navigation, list/graph selectors and strict pixel hit testing.
    SetAxis/W=XRDWorkbench#Pattern bottom 20,70
    SetAxis/W=XRDWorkbench#Pattern left -30,110
    XRD_ViewSync(path)
    XRD_TestCheck(XRD100_Select(path,0,1)==0,"v100 common peak selector runs")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-25.1)<1e-7 && abs(V_max-35.1)<1e-7,"v100 selected registered peak is centered at plus-minus five degrees")
    XRD100_Select(path,1,1)
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==39 && V_max==49,"v100 selecting another peak moves the view")
    XRD_TestCheck(XRD100_BackView(path)==1,"v100 previous view is available")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-25.1)<1e-7 && abs(V_max-35.1)<1e-7,"v100 previous view restores exact bounds")
    Variable/G root:Packages:XRDWorkbench:UI:autoZoom100=0
    XRD100_Select(path,1,1)
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-25.1)<1e-7 && NumVarOrDefault(path+":selectedPeakRow",-1)==1,"v100 auto-zoom OFF selects without moving axes")
    Variable/G root:Packages:XRDWorkbench:UI:autoZoom100=1
    XRD100_Zoom(path,20.1,10)
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==20 && V_max==30,"v100 edge zoom is clamped to data bounds")
    XRD100_Zoom(path,45,50)
    STRUCT WMWinHookStruct hook
    hook.winName="XRDWorkbench#Pattern";hook.eventCode=5;hook.eventMod=0
    hook.mouseLoc.h=round(PixelFromAxisVal("XRDWorkbench#Pattern","bottom",44))
    Wave peaksY=$(path+":Peaks:height")
    hook.mouseLoc.v=round(PixelFromAxisVal("XRDWorkbench#Pattern","left",peaksY[1]))
    Variable/G $(path+":selectedPeakRow")=0
    XRD_TestCheck(XRD100_PointHook(hook)==1 && NumVarOrDefault(path+":selectedPeakRow",-1)==1,"v100 registered peak mouse event selects and zooms")
    hook.mouseLoc.h=round(PixelFromAxisVal("XRDWorkbench#Pattern","bottom",45))
    hook.mouseLoc.v=round(PixelFromAxisVal("XRDWorkbench#Pattern","left",20))
    XRD_TestCheck(XRD100_PointHook(hook)==0 && NumVarOrDefault(path+":selectedPeakRow",-1)==1,"v100 distant mouse event does not snap to a peak")
    XRD_TestCheck(WaveCRC(0,raw)==rawCRC && WaveCRC(0,assigned)==assignmentCRC,"v100 zoom and selection never modify scientific values")
    XRD_ResizePanel()
    ControlInfo/W=XRDWorkbench statusBar
    Variable statusY=V_top
    XRD_StatusBar(project,path)
    ControlInfo/W=XRDWorkbench statusBar
    XRD_TestCheck(V_top==statusY,"v100 status refresh preserves resized footer position")
    XRD_TestCheck(strsearch(WinRecreation("XRDWorkbench",0),"title=\"New\"",0)<0,"v100 no implicit New buttons in match screen")
    XRD100_TrashProject(project)
    XRD_TestCheck(!strlen(XRD100_ProjectByUID(puid)) && strlen(XRD100_ProjectByUID(puid,deleted=1)),"v100 deleted project is retained only in recovery registry")
    XRD_TestCheck(WhichListItem(path,XRD_AllMeasurementPaths(1))<0 && WaveCRC(0,ref)==refCRC,"v100 deleted sample excluded from new plots and common reference kept")
    XRD_TestCheck(WaveCRC(0,snap)==snapshotCRC && XRD_PlotDrawRecipe(recipe,1)==0,"v100 saved figure remains usable after source deletion")
    result=XRD100_RestoreProject(XRD100_ProjectByUID(puid,deleted=1),XRD_ProjectDisplayName(second))
    XRD_TestCheck(result<0,"v100 restore refuses an existing project name")
    XRD_TestCheck(XRD100_RestoreProject(XRD100_ProjectByUID(puid,deleted=1),"CuFeQS1250inair")==0,"v100 recoverable deletion restores source")
    path=XRD80_ResolveMeasurement(uid);project=XRD100_ProjectByUID(puid)
    String/G root:Packages:XRDWorkbench:activeProject=project
    XRD_TestCheck(WaveCRC(0,raw)==rawCRC && WaveCRC(0,assigned)==assignmentCRC && XRD_IsAnalysisComplete(path),"v100 restored source retains data assignments and completion")
    XRD_Panel()
    XRD80_ProjectManager()
    SavePICT/O/E=-5/SNAP=1/WIN=XRDProjectManager as output+"project_manager.png"
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"matching.png"
    SaveExperiment/C/F={1,"",0} as output+"roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "v100 integration failures="+num2istr(failures)
    return failures
End

Function XRD_VerifyV100Restored()
    Variable/G root:XRDTestFailures=0
    SVAR puid=root:XRD100ProjectUID,uid=root:XRD100SampleUID,recipe=root:XRD100Recipe
    XRD_Init()
    CtrlNamedBackground XRDAutoSave,stop
    String project=XRD100_ProjectByUID(puid),path=XRD80_ResolveMeasurement(uid)
    XRD_TestCheck(DataFolderExists(project) && strlen(path)>0,"v100 reopened project and sample IDs resolve")
    XRD_TestCheck(cmpstr(XRD_ProjectDisplayName(project),"CuFeQS1250inair")==0 && cmpstr(StrVarOrDefault(path+":sampleNumber",""),"023")==0,"v100 reopened project name and manual serial retained")
    Wave alias=$(project+":"+PossiblyQuoteName("int_023_x=0.2_CuFeQS1250inair")),raw=$(path+":Raw:intensity")
    XRD_TestCheck(WaveExists(alias) && WaveCRC(0,alias)==WaveCRC(0,raw),"v100 reopened named dependency evaluates correctly")
    XRD_TestCheck(XRD_IsAnalysisComplete(path) && NumVarOrDefault(path+":Lattice:a",0)==5.89 && DataFolderExists(path+":LatticeRuns:Run1"),"v100 reopened assignments state and lattice history retained")
    String win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,1)==0 && WinType(win)==1,"v100 saved independent figure reopens")
    GetAxis/W=$win/Q bottom
    XRD_TestCheck(V_min==25 && V_max==60,"v100 native figure axes retained across Experiment save and reopen")
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:UI:autoZoom100",0)==1,"v100 auto-zoom setting persists")
    NVAR failures=root:XRDTestFailures
    Print "v100 actual reopen failures="+num2istr(failures)
    return failures
End

Function XRD_RunV100Guard(fixtures,output)
    String fixtures,output
    Variable error=0
    try
        XRD_RunV100Integration(fixtures,output); AbortOnRTE
    catch
        error=max(1,GetRTError(1))
        Print "INTEGRATION RUNTIME ERROR",error,GetErrMessage(error)
    endtry
    return error
End

Function XRD_RunV100Edges(output)
    String output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    String admin=XRD100_Admin(),project=XRD_Project(),uid=XRD80_ProjectUID(project),path,mid,old,tx
    String/G $(admin+":backupFolder")=output
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=2+100*exp(-((xx[p]-30)/0.1)^2)
    path=XRD_Store(xx,yy,"sample.xy");mid=XRD80_MeasurementUID(path)
    XRD_Manual(path,30);XRD_SetUnknown(path,0)
    XRD_TestCheck(XRD100_SetSample(path,"007","x=0","sample")==0,"v100 edge explicit serial accepted")
    XRD_TestCheck(XRD100_RenameProject(project,"Edge Project")==0,"v100 edge liberal project name accepted")
    project=XRD100_ProjectByUID(uid);path=XRD80_ResolveMeasurement(mid)
    XRD_TestCheck(XRD100_RenameProject(project,"EDGE PROJECT")==0 && strsearch(XRD_ProjectDisplayName(XRD100_ProjectByUID(uid)),"EDGE PROJECT",0)==0,"v100 case-only rename updates physical and displayed names")
    project=XRD100_ProjectByUID(uid);path=XRD80_ResolveMeasurement(mid)
    XRD_TestCheck(XRD_Undo()==1 && XRD_Redo()==1 && XRD_IsAnalysisComplete(path),"v100 retained analysis Undo and Redo execute after physical rename")
    XRD_TestCheck(XRD100_SetSample(path,"","x=0","sample")==-1 && XRD100_SetSample(path,"auto","x=0","sample")==-1,"v100 missing or nonnumeric manual serial is never auto-assigned")
    XRD_TestCheck(XRD100_RenameProject(project,PadString("",256,65))==-1,"v100 folder byte-limit preflight rejects 256-byte name")
    XRD_TestCheck(XRD100_RenameProject(project,PadString("",250,65))==-2 && DataFolderExists(project),"v100 generated Wave byte-limit fails before folder changes")
    String collision=project+":"+PossiblyQuoteName("tt_007_x=0_Another")
    Make/D/N=1 $collision=123
    XRD_TestCheck(XRD100_RenameProject(project,"Another")==-2 && WaveExists($collision),"v100 target Wave collision rejected without overwrite")
    KillWaves $collision
    String/G $(admin+":backupFolder")=output+"not_a_directory.txt:"
    Variable file
    Open file as output+"not_a_directory.txt";fprintf file,"backup refusal test";Close file
    XRD_TestCheck(XRD100_RenameProject(project,"Another")==-3 && DataFolderExists(project),"v100 unavailable backup prevents any rename")
    String/G $(admin+":backupFolder")=output
    Variable/G $(project+":activeStep")=3
    XRD_Panel()
    XRD100_Zoom(path,45,50)
    STRUCT WMWinHookStruct h
    h.winName="XRDWorkbench#Pattern";h.eventCode=5;h.eventMod=2
    h.mouseLoc.h=round(PixelFromAxisVal("XRDWorkbench#Pattern","bottom",40))
    h.mouseLoc.v=round(PixelFromAxisVal("XRDWorkbench#Pattern","left",2))
    XRD_TestCheck(XRD100_PointHook(h)==1 && NumVarOrDefault(path+":pickMode81",0)==1,"v100 Shift-click selects a raw point in identification mode")
    ControlInfo/W=XRDWorkbench pointAdd
    XRD_TestCheck(V_disable==0 && cmpstr(StringByKey("TNAME",CsrInfo(A,"XRDWorkbench#Pattern")),"XRDWB_Measured")==0,"v100 selected raw cursor enables add button")
    Variable selectedAngle=hcsr(A,"XRDWorkbench#Pattern")
    XRD_TestCheck(XRD81_AddCursorPoint()>=0 && NumVarOrDefault(path+":pickMode81",1)==0,"v100 one selected point is added without reselection")
    Wave peaks=$(path+":Peaks:angle")
    XRD_TestCheck(numpnts(peaks)==2 && abs(peaks[1]-selectedAngle)<1e-8,"v100 selected raw point appears in the peak list")
    XRD100_Zoom(path,45,50)
    h.eventCode=3;h.eventMod=0;h.ticks=100
    h.mouseLoc.h=round(PixelFromAxisVal("XRDWorkbench#Pattern","bottom",45))
    h.mouseLoc.v=round(PixelFromAxisVal("XRDWorkbench#Pattern","left",10))
    XRD100_PointHook(h);h.ticks=110
    XRD_TestCheck(XRD100_PointHook(h)==1,"v100 double-click event performs plot zoom")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs((V_min+V_max)/2-45)<0.1 && abs(V_max-V_min-10)<1e-6,"v100 double-click centers ten-degree range")
    h.eventMod=16
    XRD_TestCheck(XRD100_PointHook(h)==1,"v100 right-click event restores previous view")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==20 && V_max==70,"v100 right-click restores pre-double-click range")
    Variable/G root:Packages:XRDWorkbench:UI:doubleZoom100=0
    XRD_TestCheck(XRD100_PointHook(h)==0,"v100 disabled custom navigation leaves contextual click native")
    Variable/G root:Packages:XRDWorkbench:UI:doubleZoom100=1
    Variable/G $(project+":activeStep")=1
    XRD_Panel()
    MoveWindow/W=XRDWorkbench 0,0,1366,768
    XRD_ResizePanel();XRD_StatusBar(project,path)
    XRD81_RefreshPeaks(path)
    ControlInfo/W=XRDWorkbench statusBar
    Variable footer=V_top
    ControlInfo/W=XRDWorkbench detectorSettings
    XRD_TestCheck(footer>V_top+V_height && strsearch(WinRecreation("XRDWorkbench",0),"title=\"New\"",0)<0,"v100 added-peak footer stays below controls at larger panel size")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"detection_large.png"
    XRD_TestCheck(XRD100_TrashProject(project)==0,"v100 last project can be deleted")
    XRD_Init()
    XRD_TestCheck(ItemsInList(XRD_ProjectList())==0 && !strlen(XRD_Project()),"v100 deleting last project does not create a replacement")
    XRD_TestCheck(XRD100_RestoreProject(XRD100_ProjectByUID(uid,deleted=1),"Edge restored")==0,"v100 last project can be restored")
    XRD_TestCheck(cmpstr(XRD80_ResolveMeasurement(mid),XRD_Data())==0,"v100 restored last sample is active")
    NVAR failures=root:XRDTestFailures
    Print "v100 edge failures="+num2istr(failures)
    return failures
End

Function XRD_RunV100Legacy(saved,output)
    String saved,output
    XRD_RunV80MigrationTests(saved,output)
    String project=XRD_Project(),path=XRD_Data(),uid=XRD80_ProjectUID(project),mid=XRD80_MeasurementUID(path),admin=XRD100_Admin()
    String/G $(admin+":backupFolder")=output
    Wave raw=$(path+":Raw:intensity"),refs=$(path+":Assignments:refIndex")
    Variable crc=WaveCRC(0,raw),assigned=WaveCRC(0,refs),undo=NumVarOrDefault(project+":Undo:count",0)
    XRD_TestCheck(XRD100_RenameProject(project,"Legacy migrated")==0,"v100 real legacy folder can migrate and rename")
    project=XRD100_ProjectByUID(uid);path=XRD80_ResolveMeasurement(mid)
    XRD_TestCheck(strsearch(project,":Workbench:Management:",0)>0 && strlen(path)>0,"v100 migrated old sample retains immutable ID under Management")
    XRD_TestCheck(WaveCRC(0,raw)==crc && WaveCRC(0,refs)==assigned && NumVarOrDefault(project+":Undo:count",0)==undo,"v100 migration retains Raw mapped assignments and Undo count")
    XRD_TestCheck(XRD_Undo()==1 && XRD_Redo()==1,"v100 real legacy Undo and Redo run after physical move")
    NVAR failures=root:XRDTestFailures
    Print "v100 legacy failures="+num2istr(failures)
    return failures
End

// Core regression adapted only for physical rename path/name semantics.
Function XRD_RunV100CoreTests(output)
    String output
    Variable/G root:XRD80CoreFailures=0
    XRD_Init()
    String/G $(XRD100_Admin()+":backupFolder")=output
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=1+100*exp(-((xx[p]-30)/0.15)^2)+60*exp(-((xx[p]-40)/0.15)^2)
    String firstProject=XRD_Project(),first=XRD_Store(xx,yy,"x=-0.1.xy")
    String firstID=XRD80_MeasurementUID(first),projectID=XRD80_ProjectUID(firstProject)
    Wave raw=$(first+":Raw:intensity"),rawX=$(first+":Raw:twoTheta")
    Variable rawCRC=WaveCRC(0,raw),xCRC=WaveCRC(0,rawX)
    XRD80_CoreCheck(cmpstr(StrVarOrDefault(first+":analysisState",""),"未解析")==0,"zero peaks are not automatically complete")
    XRD_Manual(first,30)
    XRD_Manual(first,40)
    XRD80_CoreCheck(!XRD_IsAnalysisComplete(first) && cmpstr(StrVarOrDefault(first+":analysisState",""),"解析中")==0,"unreviewed detected peaks remain in progress")
    XRD_SetUnknown(first,0)
    XRD80_CoreCheck(!XRD_IsAnalysisComplete(first),"one Unknown leaves a second unreviewed peak incomplete")
    XRD_SetUnknown(first,1)
    XRD80_CoreCheck(XRD_IsAnalysisComplete(first),"all Unknown peaks automatically complete the sample")
    XRD80_CoreCheck(cmpstr(StrVarOrDefault(first+":status",""),"同定完了")==0,"automatic completion maintains the legacy status adapter")
    NewDataFolder/O $(first+":Lattice")
    String/G $(first+":Lattice:state")="計算済"
    Variable/G $(first+":zeroCorrection")=0.04
    XRD80_AnalysisChanged(first,"補正を変更")
    XRD80_CoreCheck(XRD_IsAnalysisComplete(first) && NumVarOrDefault(first+":Lattice:stale",0)==1,"correction keeps completed assignments and marks lattice for recalculation")
    XRD_ClearPeakReview(first,0)
    XRD80_CoreCheck(!XRD_IsAnalysisComplete(first),"clearing a review returns only that sample to in-progress")
    XRD_SetUnknown(first,0)
    XRD80_CoreCheck(XRD_SetMeasurementComplete(first)==0,"legacy completion command validates automatic state")
    XRD80_RenameProject(firstProject,"1200℃ in Air")
    firstProject=XRD100_ProjectByUID(projectID);first=XRD80_ResolveMeasurement(firstID)
    XRD80_RenameMeasurement(first,"x=-0.1 改名後")
    XRD80_CoreCheck(cmpstr(XRD80_ProjectUID(firstProject),projectID)==0 && cmpstr(XRD80_MeasurementUID(first),firstID)==0,"project/sample renaming preserves immutable identities")
    XRD80_CoreCheck(cmpstr(XRD_ProjectDisplayName(firstProject),"1200℃ in Air")==0,"project name and physical storage change together")
    String stem=StrVarOrDefault(first+":namedWaveStem81",firstID)
    Wave tt=$(first+":Waves:"+PossiblyQuoteName("tt_"+stem)),intensity=$(first+":Waves:"+PossiblyQuoteName("int_"+stem)),processed=$(first+":Processed:intensity")
    DoUpdate
    XRD80_CoreCheck(tt[200]==rawX[200] && abs(intensity[200]-processed[200])<1e-9,"prefix waves are formula-linked to canonical measured data")
    XRD80_CoreCheck(strlen(GetFormula(tt))>0 && strlen(GetFormula(intensity))>0,"prefix waves retain dependencies rather than an independently editable duplicate")
    String unfinished=XRD_Store(xx,yy,"x=0.xy")
    XRD80_CoreCheck(cmpstr(XRD80_ProjectProgress(firstProject),"1/2完了")==0,"project progress counts independently completed samples")
    XRD_NewProject()
    String secondProject=XRD_Project(),second=XRD_Store(xx,yy,"x=0.2.xy")
    XRD80_CoreCheck(cmpstr(XRD80_MeasurementUID(second),firstID)!=0,"Data1 in another project receives a different experiment-wide sample ID")
    XRD80_CoreCheck(cmpstr(XRD80_ResolveMeasurement(firstID),first)==0,"registry resolves another project's sample without changing its identity")
    XRD80_CoreCheck(XRD_IsAnalysisComplete(first) && !XRD_IsAnalysisComplete(second),"another project's incomplete sample does not affect the completed sample")
    XRD80_CoreCheck(WaveCRC(0,raw)==rawCRC && WaveCRC(0,rawX)==xCRC,"identity/state/correction/rename preserve Raw waves")
    Make/FREE/D/N=3 map={9,4,7}
    NewDataFolder/O root:XRD80MapTest
    Make/O/D/N=4 root:XRD80MapTest:refs={1,3,0,2}
    XRD80_MapReferenceWave("root:XRD80MapTest:refs",map)
    Wave mapped=root:XRD80MapTest:refs
    XRD80_CoreCheck(mapped[0]==9 && mapped[1]==7 && mapped[2]==0 && mapped[3]==4,"legacy reference map preserves Unknown and translates positive indices")
    XRD80_CoreCheck(GetRTError(1)==0,"core operations leave no runtime error")
    NVAR failures=root:XRD80CoreFailures
    Print "v1.0.0 core failures="+num2istr(failures)
    return failures
End

// Existing save/Undo regression: project enumeration now returns full paths.
Function XRD_RunV100SaveUndoTests(fixturesPath,outputPath)
    String fixturesPath,outputPath
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_NewProject()
    NewPath/O/Q XRDReferencePath,fixturesPath
    XRD_LoadReferences()
    XRD_ImportFile(fixturesPath+"measurement.xy")
    String path=XRD_Data(),project=XRD_Project()
    XRD_DetectLegacy(path)
    XRD_UndoSettings(project)
    NVAR count=$(project+":Undo:count"),sequence=$(project+":Undo:sequence")
    count=0;sequence=0
    Wave xx=$(path+":Raw:twoTheta"),raw=$(path+":Raw:intensity"),ids=$(path+":Peaks:peakID"),angle=$(path+":Peaks:angle"),refs=$(path+":Assignments:refIndex")
    Duplicate/FREE raw,original
    Variable n=numpnts(ids),id0=ids[0]
    NVAR selected=$(path+":selectedPeakRow"),nextID=$(path+":nextPeakID")
    selected=0
    XRD_TestDisableFollow()
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 30,35
    // Establish the view baseline for this analysis-only regression. Mixed zoom
    // chronology is tested separately in xrd_v51_tests.ipf.
    XRD_ViewSync(path)
    XRD81_SetPickMode(1)
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 2
    Variable previousNext=nextID
    XRD_Manual(path,32)
    XRD_TestCheck(numpnts(ids)==n+1 && count==1,"manual peak creates one undo step")
    XRD_TestCheck(XRD_Undo()==1 && numpnts(ids)==n,"undo restores live peak waves used by UI")
    XRD_TestCheck(nextID==previousNext && ids[0]==id0,"undo restores stable peak identifiers")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==30 && V_max==35 && pcsr(A,"XRDWorkbench#Pattern")==2,"undo preserves zoom and standard cursor")
    XRD_Manual(path,31)
    XRD_TestCheck(count==0,"duplicate manual peak does not consume undo history")
    XRD_Manual(path,999)
    XRD_Delete(path,-1)
    XRD_TestCheck(count==0,"invalid changes do not consume undo history")
    XRD_ScoreCandidates(path,0)
    XRD_AssignCandidate(path,0,0,0)
    Variable primary=refs[0]
    XRD_TestCheck(numpnts(refs)==1 && count==1,"candidate assignment recorded")
    XRD_Undo()
    XRD_TestCheck(numpnts(refs)==0,"undo candidate assignment")
    XRD_ScoreCandidates(path,0)
    XRD_AssignCandidate(path,0,0,0)
    XRD_SetUnknown(path,0)
    XRD_Undo()
    XRD_TestCheck(numpnts(refs)==1 && refs[0]==primary,"undo Unknown restores assigned phase")
    XRD_ScoreCandidates(path,0)
    XRD_AssignCandidate(path,0,1,1)
    XRD_Undo()
    XRD_TestCheck(numpnts(refs)==1 && refs[0]==primary,"undo overlap retains primary assignment")
    XRD_ClearPeakReview(path,0)
    XRD_Undo()
    XRD_TestCheck(numpnts(refs)==1 && refs[0]==primary,"undo review clearing")
    XRD_Delete(path,0)
    XRD_Undo()
    XRD_TestCheck(numpnts(ids)==n && ids[0]==id0 && refs[0]==primary,"undo peak deletion restores assignment and peak")
    XRD_Manual(path,32)
    XRD_DetectLegacy(path)
    XRD_Undo()
    XRD_TestCheck(numpnts(ids)==n+1,"undo detection preserves previous manual peaks")
    XRD_Undo()
    XRD_TestCheck(numpnts(ids)==n,"undo previous manual insertion")
    XRD_SetUnknown(path,1)
    XRD_SetMeasurementComplete(path)
    XRD_Undo()
    XRD_TestCheck(cmpstr(StrVarOrDefault(path+":status",""),"同定中")==0,"undo completion returns to identification")
    XRD_DeleteMeasurement(path)
    XRD_Undo()
    XRD_TestCheck(!NumVarOrDefault(path+":deleted",0) && cmpstr(XRD_Data(),path)==0,"undo measurement deletion restores active measurement")
    XRD_DeleteMeasurement(path)
    XRD_RestoreMeasurement(path)
    XRD_Undo()
    XRD_TestCheck(NumVarOrDefault(path+":deleted",0)==1 && strlen(XRD_Data())==0,"undo restore returns measurement to deleted state")
    XRD_Undo()
    XRD_ImportFile(fixturesPath+"measurement.xy")
    String second=XRD_Data()
    XRD_DetectLegacy(second)
    XRD_Undo()
    Wave secondPeaks=$(second+":Peaks:angle")
    XRD_TestCheck(numpnts(secondPeaks)==0 && numpnts(ids)==n,"undo does not mix measurements")
    XRD_NewProject()
    XRD_TestCheck(XRD_Undo()==0,"new project cannot undo another project's actions")
    SVAR active=root:Packages:XRDWorkbench:activeProject
    active=project
    SVAR measurement=$(project+":activeData")
    measurement=path
    count=0;sequence=0
    Variable i
    for(i=0;i<23;i+=1)
        XRD_SetUnknown(path,0)
    endfor
    XRD_TestCheck(count==20,"undo history capped at twenty actions")
    for(i=0;i<20;i+=1)
        XRD_Undo()
    endfor
    XRD_TestCheck(count==0 && XRD_Undo()==0,"twenty undo steps then clean empty history")
    XRD_TestCheck(EqualWaves(raw,original,1)==1,"undo never changes raw intensity")
    XRD_RecordUndo(path,"keyboard test")
    XRD_TestDisableFollow()
    XRD_Panel()
    STRUCT WMWinHookStruct hook
    hook.winName="XRDWorkbench#Pattern";hook.eventCode=26;hook.eventMod=8;hook.keycode=122
    XRD_TestCheck(XRD_UndoHook(hook)==1,"Ctrl+Z accepted in workbench graph")
    hook.keycode=105
    XRD_TestCheck(XRD_UndoHook(hook)==0,"Ctrl+I left to native Igor")
    hook.winName="OtherGraph";hook.keycode=122
    XRD_TestCheck(XRD_UndoHook(hook)==0,"Ctrl+Z outside workbench left to Igor")
    hook.winName="XRDWorkbench";hook.focusCtrl="manualAngle"
    NVAR step=$(project+":activeStep")
    step=1
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_TestCheck(XRD_UndoHook(hook)==0,"text field keeps native undo")
    XRD_Undo()
    XRD_RecoverySettings()
    XRD_TestCheck(WhichListItem("Recovery",XRD_ProjectList())<0 && WhichListItem("UI",XRD_ProjectList())<0 && WhichListItem(project,XRD_ProjectList())>=0,"project selector excludes UI and auto-save settings folders")
    NVAR enabled=root:Packages:XRDWorkbench:Recovery:enabled,minutes=root:Packages:XRDWorkbench:Recovery:minutes,generation=root:Packages:XRDWorkbench:Recovery:generation
    XRD_TestCheck(enabled==1 && minutes==5,"v081 autosave starts ON with five minute interval")
    enabled=1
    XRD_StartAutoSave()
    CtrlNamedBackground XRDAutoSave,status
    XRD_TestCheck(NumberByKey("RUN",S_info)==1 && NumberByKey("PERIOD",S_info)==18000,"five minute background timer started")
    Variable scheduled=NumberByKey("NEXT",S_info)
    XRD_TestDisableFollow()
    XRD_Panel()
    CtrlNamedBackground XRDAutoSave,status
    XRD_TestCheck(NumberByKey("NEXT",S_info)==scheduled,"UI refresh does not postpone auto-save")
    minutes=2
    XRD_StartAutoSave()
    CtrlNamedBackground XRDAutoSave,status
    XRD_TestCheck(NumberByKey("PERIOD",S_info)==7200,"save interval changes")
    enabled=0
    XRD_StartAutoSave()
    CtrlNamedBackground XRDAutoSave,status
    XRD_TestCheck(NumberByKey("RUN",S_info)==0,"automatic save can be disabled")
    NewPath/O/Q XRDAutoSaveCustomPath,outputPath
    String beforeName=IgorInfo(12),first,folder
    generation=0
    XRD_TestCheck(XRD_SaveRecovery()==0,"previously-unsaved experiment saved silently as recovery copy")
    SVAR savedFile=root:Packages:XRDWorkbench:Recovery:lastFile
    first=savedFile
    GetFileFolderInfo/Q/Z first
    XRD_TestCheck(V_flag==0 && V_isFile && V_logEOF>0,"recovery copy exists on disk")
    XRD_TestCheck(cmpstr(beforeName,IgorInfo(12))==0,"saving a copy retains original experiment identity")
    for(i=0;i<3;i+=1)
        XRD_SaveRecovery()
    endfor
    XRD_TestCheck(generation==4 && cmpstr(savedFile,first)==0,"fourth save safely rotates back to first slot")
    PathInfo XRDAutoSavePath
    folder=IndexedFile(XRDAutoSavePath,-1,".pxp")
    String sessionKey=StrVarOrDefault("root:Packages:XRDWorkbench:Recovery:sessionKey","")
    Variable matching=0
    for(i=0;i<ItemsInList(folder);i+=1)
        matching+=(strsearch(StringFromList(i,folder),sessionKey,0)>=0)
    endfor
    XRD_TestCheck(matching==3,"three recovery generations retained for this session")
    NVAR busy=root:Packages:XRDWorkbench:Recovery:busy
    XRD_TestCheck(busy==0,"recovery copy stores a cleared busy flag")
    String failureFolder=outputPath+"failure:"
    NewPath/O/C/Q XRDAutoSaveFailurePath,failureFolder
    Variable fileNum
    Open fileNum as failureFolder+"XRDWorkbench_Autosave"
    fprintf fileNum,"blocked folder test"
    Close fileNum
    NewPath/O/Q XRDAutoSaveCustomPath,failureFolder
    Variable beforeGeneration=generation
    String beforeFile=savedFile
    XRD_TestCheck(XRD_SaveRecovery()<0,"unwritable recovery destination reports failure without a dialog")
    XRD_TestCheck(generation==beforeGeneration && cmpstr(savedFile,beforeFile)==0 && busy==0,"save failure retains latest successful recovery and unlocks saving")
    NewPath/O/Q XRDAutoSaveCustomPath,outputPath
    XRD_SaveSettingsPanel()
    XRD_TestCheck(WinType("XRDSaveSettings")==7,"save settings panel opens")
    XRD_RecordUndo(path,"persisted undo test")
    XRD_SetUnknown(path,0)
    XRD_SaveRecovery()
    SaveExperiment as outputPath+"undo_roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "XRD v1.0.0 save/Undo tests: failures="+num2istr(failures)
    return failures
End
