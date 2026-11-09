#pragma rtGlobals=3
#include ":xrd_v130_tests"

Function XRD131_Rect(win)
    String win
    GetWindow $win wsize
    return V_left+2*V_top+4*V_right+8*V_bottom
End

Function XRD131_RunTests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live_native.txt"
    XRD_Init()
    String project=XRD_Project(),sample=XRD110_MeasurementPath(project,"007"),other=XRD110_MeasurementPath(project,"008")
    String/G $(XRD100_Admin()+":backupFolder")=output
    Make/FREE/D/N=6 xx=20+p,yy=p+1
    XRD_Store(xx,yy,"old.xy",target=sample)
    XRD_Store(xx,yy,"other.xy",target=other)
    String/G $(sample+":sampleNumber")="007",$(sample+":composition")="A",$(sample+":displayName")="Old sample"
    String/G $(other+":sampleNumber")="008",$(other+":composition")="B"
    XRD100_RefreshNamed(project)
    String oldUID=StrVarOrDefault(sample+":measurementUID",""),otherUID=StrVarOrDefault(other+":measurementUID",""),oldAlias=XRD100_ExistingAlias(project,oldUID,"int")
    String/G $(project+":activeData")=sample
    XRD_Panel();DoUpdate
    CtrlNamedBackground XRDAutoSave,stop
    XRD_TestCheck(WhichListItem("purgeData",ControlNameList("XRDWorkbench",";"))>=0,"v131 permanent-delete control available")
    XRD_TestCheck(XRD131_Replace(sample,"007","A","Invalid",fixtures+"one_column.txt")==-2 && cmpstr(XRD80_ResolveMeasurement(oldUID),sample)==0,"v131 malformed file leaves old measurement untouched")
    XRD_Manual(sample,22)
    XRD_RecordUndo(other,"keep")
    XRD_RecordUndo(sample,"remove")
    XRD_TestCheck(XRD110_RegisterPanel("")==0,"v131 register panel opens")
    XRD_TestCheck(WhichListItem("XRDRegister110",WinList("*",";","WIN:64,FLT:0"))>=0,"v131 registration window is ordinary")
    KillWindow/Z XRDRegister110
    MoveWindow/W=XRDWorkbench 2,2,2,2
    XRD_PlotWorkspace();DoUpdate
    Variable stable=XRD131_Rect("XRDWorkbench"),panel=XRD131_Rect("XRDPlotWorkspace")
    GetWindow XRDWorkbench maximize
    XRD_TestCheck(V_Value==0 && stable>0,"v131 maximized workbench becomes a stable large window")
    XRD_TestCheck(WhichListItem("XRDPlotWorkspace",WinList("*",";","WIN:64,FLT:0"))>=0,"v131 plot window is ordinary")
    String ui=XRD_PlotRoot()+":UI"
    Wave/T paths=$(ui+":paths")
    Wave flags=$(ui+":flags")
    flags[][0]=32+16*(cmpstr(paths[p],sample)==0)
    WaveClear paths,flags
    String savedOld=XRD_PlotSaveDraft("",warnIncomplete=0)
    XRD_TestCheck(strlen(savedOld)>0 && XRD_PlotDrawRecipe(savedOld,0)==0,"v131 graph created")
    String win="XRDP_"+StrVarOrDefault(savedOld+":plotUID","")
    DoUpdate
    XRD_TestCheck(cmpstr(WinName(0,65),win)==0,"v131 new graph takes foreground")
    XRD_TestCheck(stable==XRD131_Rect("XRDWorkbench") && panel==XRD131_Rect("XRDPlotWorkspace"),"v131 creating figure preserves both window rectangles")
    DoWindow/F XRDPlotWorkspace
    XRD_TestCheck(cmpstr(WinName(0,65),"XRDPlotWorkspace")==0,"v131 user can bring plot panel above graph")
    XRD_PlotDrawRecipe(savedOld,1)
    XRD_TestCheck(cmpstr(WinName(0,65),win)==0,"v131 reopening saved graph brings it forward")

    // User windows still holding data must cause a rollback.
    Wave raw=$(sample+":Raw:intensity")
    Display/K=1/N=UserHoldingSample raw
    WaveClear raw
    Variable result=XRD131_Replace(sample,"007","A","Rejected while in use",ReplaceString("fixtures_v070:",fixtures,"fixtures:")+"measurement.xy")
    Print "BLOCKED_RESULT",result
    XRD_TestCheck(result==-5 && cmpstr(XRD80_ResolveMeasurement(oldUID),sample)==0 && WaveExists($oldAlias),"v131 open user graph rolls replacement back")
    KillWindow UserHoldingSample
    XRD_TestCheck(XRD_DeleteMeasurement(sample)==0,"v131 old reversible deletion still available")
    result=XRD131_Replace(sample,"007","A","Remeasured",ReplaceString("fixtures_v070:",fixtures,"fixtures:")+"measurement.xy")
    Print "REPLACEMENT_RESULT",result
    XRD_TestCheck(result==0,"v131 remeasurement replaces soft-deleted number")
    String uid=StrVarOrDefault(sample+":measurementUID","")
    XRD_TestCheck(strlen(uid)>0 && cmpstr(uid,oldUID)!=0 && !strlen(XRD80_ResolveMeasurement(oldUID)),"v131 old registry UID retired")
    Wave/Z fresh=$(sample+":Raw:intensity"),peaks=$(sample+":Peaks:peakID"),assignments=$(sample+":Assignments:peakID")
    XRD_TestCheck(WaveExists(fresh) && numpnts(fresh)>6 && numpnts(peaks)==0 && numpnts(assignments)==0 && !NumVarOrDefault(sample+":deleted",0),"v131 new raw values with empty analysis")
    WaveClear fresh,peaks,assignments
    XRD_TestCheck(NumVarOrDefault(savedOld+":stale",0)==1 && DataFolderExists(savedOld+":Snapshot:Sample1"),"v131 earlier plot kept as a stale snapshot")
    XRD_TestCheck(WaveExists($oldAlias) && cmpstr(XRD80_ResolveMeasurement(otherUID),other)==0,"v131 generated alias reused and other measurement retained")
    XRD_TestCheck(XRD_Undo()==1 && cmpstr(XRD_Data(),other)==0,"v131 unrelated undo works after deleted history entries")
    XRD_TestCheck(XRD_Redo()==1 && cmpstr(XRD_Data(),other)==0,"v131 unrelated redo works")
    XRD_PlotSelectionTable(1)
    Wave/T paths=$(ui+":paths")
    Wave flags=$(ui+":flags")
    flags[][0]=32+16*(cmpstr(paths[p],sample)==0)
    WaveClear paths,flags
    String savedNew=XRD_PlotSaveDraft("",warnIncomplete=0)
    XRD_PlotDrawRecipe(savedNew,0)
    String/G $(project+":activeData")=sample
    XRD_Panel()
    XRD_RecordUndo(sample,"purge")
    result=XRD131_Purge(sample)
    Print "PURGE_RESULT",result
    XRD_TestCheck(result==0,"v131 physical delete returns success")
    XRD_TestCheck(!DataFolderExists(sample) && !strlen(XRD80_ResolveMeasurement(uid)),"v131 physical delete removes current measurement and registry")
    Wave/Z deletedAlias=$oldAlias
    XRD_TestCheck(!WaveExists(deletedAlias),"v131 physical delete removes alias")
    XRD_TestCheck(!DataFolderExists(savedNew) && DataFolderExists(savedOld),"v131 physical delete removes matching plot")
    XRD_TestCheck(!strlen(XRD131_RegisteredSample(project,"007")) && XRD110_SerialAvailable(project,"","007"),"v131 permanently deleted number reusable")
    XRD_TestCheck(cmpstr(XRD80_ResolveMeasurement(otherUID),other)==0,"v131 permanent delete preserves unrelated sample")
    Print "V131 FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
    CtrlNamedBackground XRDAutoSave,stop
End
