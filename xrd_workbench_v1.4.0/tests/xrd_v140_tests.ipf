#pragma rtGlobals=3
#include ":xrd_tests"
#include ":xrd_v80_integration_tests"

Function/S XRD140_TestSample(name,ref,cellA,cellC,hasAssignments)
    String name
    Variable ref,cellA,cellC,hasAssignments
    Make/FREE/D/N=701 xx=5+p*0.1,yy=1
    String path=XRD_Store(xx,yy,name),rp=XRD_ReferencePath(ref)
    String/G $(path+":displayName")=name
    String/G $(path+":composition")="x=-0.2"
    if(!hasAssignments)
        return path
    endif
    Wave hh=$(rp+":h"),kk=$(rp+":k"),ll=$(rp+":l")
    Variable n=numpnts(hh),waveLength=NumVarOrDefault(path+":measurementWavelength",1.5406)
    Wave peaks=$(path+":Peaks:angle"),height=$(path+":Peaks:height"),peakIDs=$(path+":Peaks:peakID"),points=$(path+":Peaks:pointIndex")
    Wave/T origins=$(path+":Peaks:origin"),summary=$(path+":Peaks:assignmentSummary")
    Redimension/N=(n+1) peaks,height,peakIDs,points,origins,summary
    peaks[0,n-1]=(360/pi)*asin(0.5*waveLength*sqrt((4.0/3)*(hh[p]^2+hh[p]*kk[p]+kk[p]^2)/cellA^2+ll[p]^2/cellC^2))
    peaks[n]=74
    height=10
    peakIDs=p+1
    points=XRD_NearestPoint(xx,peaks[p])
    origins="Manual"
    Wave ids=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex"),rows=$(path+":Assignments:refPeakIndex"),shifts=$(path+":Assignments:shift")
    Wave/T modes=$(path+":Assignments:mode"),dates=$(path+":Assignments:created")
    Redimension/N=(n) ids,refs,rows,shifts,modes,dates
    ids=p+1
    refs=ref
    rows=p
    shifts=0
    modes="Primary"
    dates="synthetic"
    XRD_PeakTable(path)
    XRD_RefreshAssignmentTable(path)
    return path
End

Function XRD140_DraftInput(base,path,value,selected)
    String base,path,value
    Variable selected
    Variable row=XRD133_DraftRow(base,StrVarOrDefault(path+":measurementUID",""),1)
    Wave/T draft=$(base+":draft")
    draft[row][1]=num2istr(selected)
    draft[row][NumVarOrDefault(base+":axis",1)+1]=value
End

Function XRD140_RunTrendTests(fixture,output)
    String fixture,output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    String/G root:XRDLiveTestFile=output+"live.txt"
    NewPath/O/Q XRDReferencePath,fixture
    XRD_LoadReferenceFile("trend_hex.txt",1)
    String project=XRD_Project()
    String first=XRD140_TestSample("First",1,5.9,23.1,1),unassigned=XRD140_TestSample("Unassigned",1,5.9,23.1,0)
    XRD_NewProject()
    String secondProject=XRD_Project(),second=XRD140_TestSample("Second",1,5.8,23.3,1)
    String/G root:Packages:XRDWorkbench:activeProject=project
    String/G $(project+":activeData")=first
    String base=XRD133_TrendSettings(project),ui=base+":UI"
    XRD_TestCheck(XRD133_TrendTable(project)==2,"v140 default scope is the current project")
    Variable/G $(base+":allProjects")=1
    XRD_TestCheck(XRD133_TrendTable(project)==3,"v140 external project contributes additional rows")
    Wave phases=$(ui+":phases")
    XRD_TestCheck(numpnts(phases)==1 && phases[0]==1,"v140 phase menu derives from adopted reflections")
    WaveClear phases
    Variable/G $(base+":ref")=1
    Variable/G $(base+":axis")=2
    XRD133_TrendTable(project)
    Wave/T table=$(ui+":table")
    XRD_TestCheck(cmpstr(table[0][3],"-0.2")==0,"v140 registered composition prefilled as a number")
    XRD140_DraftInput(base,first,"-0.25",1)
    Variable/G $(base+":axis")=1
    XRD133_TrendTable(project)
    XRD_TestCheck(!strlen(table[0][3]),"v140 composition edits do not become temperatures")
    XRD140_DraftInput(base,first,"1200",1)
    XRD140_DraftInput(base,second,"1100",1)
    XRD140_DraftInput(base,unassigned,"1050",1)
    XRD133_TrendTable(project)
    XRD_TestCheck(numtype(XRD133_ParseX("1200 C"))==2 && XRD133_ParseX("−0.2")==-0.2,"v140 strict numeric input and mathematical minus")
    NewDataFolder/O $(first+":Lattice")
    Variable/G $(first+":Lattice:refIndex")=99
    Variable/G $(first+":Lattice:a")=99
    String message=XRD133_BatchTrend(project)
    Print "BATCH",message
    String run1=XRD133_CurrentRun(first,1,"六方晶"),run2=XRD133_CurrentRun(second,1,"六方晶")
    XRD_TestCheck(strlen(run1)>0 && strlen(run2)>0,"v140 batch computes both projects from their adopted peaks")
    if(!strlen(run1) || !strlen(run2))
        return -1
    endif
    XRD_TestCheck(abs(NumVarOrDefault(run1+":a",NaN)-5.9)<1e-5 && abs(NumVarOrDefault(run1+":c",NaN)-23.1)<1e-5,"v140 hexagonal fit recovers known a and c")
    XRD_TestCheck(abs(NumVarOrDefault(run2+":a",NaN)-5.8)<1e-5 && abs(NumVarOrDefault(run2+":c",NaN)-23.3)<1e-5,"v140 cross-project fit recovers known a and c")
    XRD_TestCheck(NumVarOrDefault(first+":Lattice:a",NaN)==99 && !DataFolderExists(second+":Lattice"),"v140 batch preserves the single-measurement workspace")
    XRD_TestCheck(XRD133_Compute(first,1,"六方晶")==0 && XRD133_Compute(unassigned,1,"六方晶")==-1,"v140 reuses valid fit and skips unassigned phase")
    XRD_TestCheck(!strlen(XRD133_SaveTrend(project,message)),"v140 no silent partial plotting")
    XRD140_DraftInput(base,unassigned,"1050",0)
    XRD133_TrendTable(project)
    Variable/G $(project+":activeStep")=4
    XRD_Panel()
    XRD_TestCheck(WhichListItem("latticeTrend",ControlNameList("XRDWorkbench",";"))>=0,"v140 lattice screen has the integrated entry point")
    XRD_TestCheck(XRD133_TrendPanel()==0,"v140 integrated window opens")
    XRD_TestCheck(cmpstr(XRD133_TrendOwner(),project)==0,"v140 graph window is owned by the starting project")
    XRD140_CheckTableActions(project)
    String recipe=XRD133_SaveTrend(project,message)
    XRD_TestCheck(strlen(recipe)>0 && XRD133_DrawTrend(recipe)==0,"v140 makes a native lattice graph")
    String win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    if(!WinType(win))
        return -1
    endif
    Wave xSaved=$(recipe+":horizontal"),aSaved=$(recipe+":latticeA")
    Wave/T savedIDs=$(recipe+":sourceUIDs"),runIDs=$(recipe+":runUIDs")
    XRD_TestCheck(xSaved[0]==1100 && xSaved[1]==1200 && abs(aSaved[0]-5.8)<1e-5 && cmpstr(savedIDs[0],StrVarOrDefault(second+":measurementUID",""))==0,"v140 sorting retains measurement and value alignment")
    XRD_TestCheck(cmpstr(runIDs[0],StrVarOrDefault(run2+":runUID",""))==0 && cmpstr(WaveUnits(aSaved,-1),"Å")==0,"v140 figure records fit provenance and units")
    String traces=TraceNameList(win,";",1)
    XRD_TestCheck(WhichListItem("LatticeA",traces)>=0 && WhichListItem("LatticeC",traces)>=0 && WhichListItem("ReferenceA",traces)>=0 && WhichListItem("ReferenceC",traces)>=0,"v140 dual axes and declared reference values drawn")
    XRD_TestCheck(WinType("XRDLatticeTrend")==7 && cmpstr(WinName(0,65),win)==0,"v140 graph appears in front of the normal window")
    SavePICT/O/E=-5/WIN=$win as output+"trend.png"
    XRD80_AnalysisChanged(first,"test")
    XRD_TestCheck(!strlen(XRD133_CurrentRun(first,1,"六方晶")) && xSaved[1]==1200,"v140 stale fit rejected while the saved figure stays fixed")
    XRD_TestCheck(XRD133_Compute(first,1,"六方晶")==1 && cmpstr(run1,XRD133_CurrentRun(first,1,"六方晶"))!=0,"v140 recalculation appends a new run")
    WaveClear xSaved,aSaved,savedIDs,runIDs,table
    DoWindow/K $win
    XRD_TestCheck(XRD133_DrawTrend(recipe)==0 && cmpstr(WinName(0,65),win)==0,"v140 saved native graph reopens")
    KillWindow/Z XRDLatticeTrend
    CtrlNamedBackground XRDAutoSave,stop
    String/G root:XRD140TestRecipe=recipe
    String/G root:XRD140TestMeasurement=second
    Print "V140 FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
    return 0
End

Function XRD140_CheckTableActions(project)
    String project
    String base=project+":LatticeTrend",ui=base+":UI"
    STRUCT WMListboxAction action
    Wave/T action.listWave=$(ui+":table")
    Wave action.selWave=$(ui+":flags")
    action.eventCode=7
    action.row=0
    action.col=3
    action.listWave[0][3]="1201"
    XRD133_TrendList(action)
    XRD133_RefreshTrend(project)
    XRD_TestCheck(cmpstr(action.listWave[0][3],"1201")==0,"v140 editing the x cell updates the project draft")
    action.listWave[0][3]="1200"
    XRD133_TrendList(action)
    action.eventCode=13
    action.row=1
    action.col=0
    action.selWave[1][0]=48
    XRD133_TrendList(action)
    XRD133_RefreshTrend(project)
    XRD_TestCheck((action.selWave[1][0] & 16)!=0,"v140 checkbox callback preserves a selected measurement")
    action.selWave[1][0]=32
    XRD133_TrendList(action)
    XRD133_RefreshTrend(project)
End

Function XRD140_ReopenAndPurge(output)
    String output
    Variable/G root:XRDTestFailures=0
    String recipe=StrVarOrDefault("root:XRD140TestRecipe",""),path=StrVarOrDefault("root:XRD140TestMeasurement","")
    String uid=StrVarOrDefault(path+":measurementUID",""),project=XRD_Project(),base=project+":LatticeTrend"
    String/G $(XRD100_Admin()+":backupFolder")=output
    XRD_TestCheck(DataFolderExists(recipe) && strlen(XRD133_CurrentRun(path,1,"六方晶"))>0,"v140 saved result and figure persist across restart")
    Variable row=XRD133_DraftRow(base,uid,0)
    Wave/T draft=$(base+":draft")
    XRD_TestCheck(row>=0 && cmpstr(draft[row][2],"1100")==0,"v140 cross-project selection and x value persist")
    WaveClear draft
    XRD_TestCheck(XRD133_DrawTrend(recipe)==0,"v140 saved figure can be reopened after restart")
    Variable result=XRD131_Purge(path)
    XRD_TestCheck(result==0 && !DataFolderExists(recipe) && !strlen(XRD80_ResolveMeasurement(uid)),"v140 permanent measurement removal also removes dependent trend figure")
    XRD_TestCheck(XRD133_DraftRow(base,uid,0)<0,"v140 removal cleans cross-project draft selections")
    Print "V140 REOPEN FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
    return 0
End
