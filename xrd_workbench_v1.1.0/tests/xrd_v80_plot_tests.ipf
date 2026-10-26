#pragma rtGlobals=3
// v0.8.0: cross-project identity, completed-only plotting, independent snapshots.
// Run in an isolated empty Experiment with xrd_tests.ipf and xrd_main.ipf loaded.
Function XRD_RunV80PlotTests(output)
    String output
    Variable/G root:XRDTestFailures=0
    NVAR failures=root:XRDTestFailures
    XRD_Init()
    XRD_NewProject()
    String firstProject=XRD_Project(),secondProject,first,second,unfinished,recipe,ui,win,paths,uidFirst,uidSecond
    Make/FREE/D/N=501 xx=20+p*0.1,yy=2+100*exp(-((xx[p]-35)/0.3)^2)
    first=XRD_Store(xx,yy,"first.xy")
    XRD_Manual(first,35)
    XRD_SetUnknown(first,0)
    unfinished=XRD_Store(xx,yy,"unfinished.xy")
    XRD_Manual(unfinished,35)
    XRD_NewProject()
    secondProject=XRD_Project()
    second=XRD_Store(xx,yy,"second.xy")
    XRD_Manual(second,35)
    XRD_SetUnknown(second,0)
    XRD_EnsureIdentity(firstProject,first)
    XRD_EnsureIdentity(secondProject,second)
    uidFirst=XRD80_MeasurementUID(first);uidSecond=XRD80_MeasurementUID(second)
    XRD_TestCheck(cmpstr(uidFirst,uidSecond)!=0,"v080 same Data1 across projects has distinct immutable measurement UIDs")
    XRD_TestCheck(XRD_IsAnalysisComplete(first) && XRD_IsAnalysisComplete(second) && !XRD_IsAnalysisComplete(unfinished),"v080 Unknown counts as reviewed; unfinished measurement remains excluded")
    paths=XRD_AllMeasurementPaths(1)
    XRD_TestCheck(WhichListItem(first,paths)>=0 && WhichListItem(second,paths)>=0 && WhichListItem(unfinished,paths)<0,"v080 global figure selection includes finished sample in partially completed project")
    String compareBase=XRD_PlotRoot()
    Make/O/T/N=2 $(compareBase+":compareUIDs")
    Wave/T selectedUIDs=$(compareBase+":compareUIDs")
    selectedUIDs[0]=uidFirst;selectedUIDs[1]=uidSecond
    paths=XRD_ComparePaths()
    XRD_TestCheck(WhichListItem(first,paths)>=0 && WhichListItem(second,paths)>=0,"v080 live comparison resolves selected UIDs across projects")
    SVAR projectName=$(firstProject+":displayName"),sourceName=$(first+":displayName")
    projectName="Renamed project";sourceName="Renamed sample"
    XRD_TestCheck(cmpstr(XRD80_ResolveMeasurement(uidFirst),first)==0,"v080 renaming project and sample preserves source resolution")
    XRD_PlotDefaults()
    XRD_PlotSelectionTable(1)
    ui=XRD_PlotRoot()+":UI"
    Wave/T sourcePaths=$(ui+":paths"),labels=$(ui+":labels")
    Wave flags=$(ui+":flags")
    Variable i
    for(i=0;i<numpnts(sourcePaths);i+=1)
        flags[i][0]=48
        labels[i]="plot label "+num2istr(i+1)
    endfor
    recipe=XRD_PlotSaveDraft("")
    XRD_TestCheck(strlen(recipe)>0 && strsearch(recipe,":PlotWorkspace:Plots:",0)>=0,"v080 recipe is Experiment-wide, outside projects")
    Wave/T savedUIDs=$(recipe+":sourceUIDs"),savedLabels=$(recipe+":sourceLabels")
    XRD_TestCheck(numpnts(savedUIDs)==2 && cmpstr(savedLabels[0],sourceName)!=0,"v080 figure labels are saved independently of source measurement names")
    Wave snapX=$(recipe+":Snapshot:Sample1:tt"),snapY=$(recipe+":Snapshot:Sample1:intensity")
    Variable crcX=WaveCRC(0,snapX),crcY=WaveCRC(0,snapY)
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,0)==0,"v080 independent completed cross-project figure draws")
    win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    Wave plottedX=XWaveRefFromTrace(win,"Measurement1")
    XRD_TestCheck(cmpstr(GetWavesDataFolder(plottedX,2),GetWavesDataFolder(snapX,2))==0,"v080 final figure X trace uses the stored snapshot")
    Wave upperTrace=TraceNameToWaveRef(win,"Measurement1"),lowerTrace=TraceNameToWaveRef(win,"Measurement2")
    XRD_TestCheck(abs(upperTrace[0]-lowerTrace[0]-135)<1e-8,"v080 source row order is top-to-bottom in stacked figure")
    Wave sourceRaw=$(first+":Raw:twoTheta"),sourceProcessed=$(first+":Processed:intensity")
    sourceRaw+=0.001;sourceProcessed+=0.001
    XRD_TestCheck(WaveCRC(0,snapX)==crcX && WaveCRC(0,snapY)==crcY,"v080 numeric snapshots remain unchanged after source edits")
    sourceRaw-=0.001;sourceProcessed-=0.001
    SetAxis/W=$win bottom 25,60
    Label/W=$win left "Custom intensity"
    ModifyGraph/W=$win lsize(Measurement1)=2.5
    XRD_TestCheck(XRD_PlotCaptureNative(recipe)==0 && strsearch(StrVarOrDefault(recipe+":nativeMacro",""),"Custom intensity",0)>=0,"v080 manual axis and line formatting is captured as native recreation text")
    DoWindow/K $win
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,1)==0 && WinType(win)==1,"v080 saved figure can reopen after its window is closed")
    GetAxis/W=$win/Q bottom
    XRD_TestCheck(abs(V_min-25)<1e-8 && abs(V_max-60)<1e-8,"v080 reopened figure retains manually edited native range")
    XRD_PlotLoadRecipe(recipe)
    Wave/T loadedLabels=$(ui+":labels"),loadedPaths=$(ui+":paths")
    XRD_TestCheck(cmpstr(loadedLabels[0],savedLabels[0])==0 && cmpstr(XRD80_MeasurementUID(loadedPaths[0]),savedUIDs[0])==0,"v080 recipe editor restores independent labels and measurement order")
    Wave selectedFlags=$(ui+":flags")
    Variable/G $(ui+":row")=0
    XRD_PlotMoveRow(1)
    XRD_TestCheck(cmpstr(XRD80_MeasurementUID(loadedPaths[1]),savedUIDs[0])==0,"v080 recipe rows can be reordered independently of project order")
    if(strlen(output))
        SavePICT/O/E=-5/SNAP=1/WIN=$win as output+"v080_independent_plot.png"
    endif
    Print "XRD v0.8.0 plot tests: failures="+num2istr(failures)
    return failures
End
