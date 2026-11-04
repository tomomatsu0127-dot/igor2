#pragma rtGlobals=3
// v0.8.0: real legacy data, fit history, style choices, and persisted figures.
Function XRD_RunV80MigrationTests(savedFile,output)
    String savedFile,output
    Variable/G root:XRDTestFailures=0
    LoadData/O/Q/R savedFile
    String project=StrVarOrDefault("root:Packages:XRDWorkbench:activeProject",""),path=StrVarOrDefault(project+":activeData","")
    Wave raw=$(path+":Raw:intensity"),oldRefs=$(path+":Assignments:refIndex")
    Variable crc=WaveCRC(0,raw),oldUndo=NumVarOrDefault(project+":Undo:count",0)
    Duplicate/FREE oldRefs,beforeRefs
    XRD_Init()
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:Schema:schemaVersion",0)==800,"v080 real v072 saved data migrates to schema 800")
    XRD_TestCheck(DataFolderExists("root:Packages:XRDWorkbenchRecoveryV080"),"v080 migration retains untouched legacy recovery tree")
    XRD_TestCheck(WaveCRC(0,raw)==crc,"v080 real old raw data remains byte-identical after migration")
    Wave map=$(project+":ReferenceMigration:legacyToGlobal"),refs=$(path+":Assignments:refIndex")
    Variable i,valid=numpnts(refs)==numpnts(beforeRefs)
    for(i=0;i<numpnts(refs);i+=1)
        if(beforeRefs[i]>0)
            valid=valid && refs[i]==map[beforeRefs[i]-1]
        else
            valid=valid && refs[i]==beforeRefs[i]
        endif
    endfor
    XRD_TestCheck(valid,"v080 legacy assignments translate through the owner-specific reference map")
    XRD_TestCheck(NumVarOrDefault(project+":Undo:count",0)==oldUndo,"v080 legacy Undo action count is preserved")
    String uid=XRD80_MeasurementUID(path)
    Variable count=NumVarOrDefault(XRD80_Library()+":referenceCount",0)
    XRD80_MigrateExperiment()
    XRD_TestCheck(cmpstr(uid,XRD80_MeasurementUID(path))==0 && count==NumVarOrDefault(XRD80_Library()+":referenceCount",0),"v080 repeated migration neither changes IDs nor duplicates references")
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_TestCheck(WinType("XRDWorkbench#Pattern")==1,"v080 migrated data opens a normal editable measurement graph")
    if(oldUndo>0)
        XRD_TestCheck(XRD_Undo()==1,"v080 retained legacy Undo entry can actually be applied")
        XRD_TestCheck(XRD_Redo()==1,"v080 retained legacy Undo can be redone")
    endif
    XRD80_ProjectManager()
    XRD_TestCheck(WinType("XRDProjectManager")==7,"v080 project and sample navigator opens after migration")
    XRD80_LibraryPanel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDLibrary as output+"library_v080.png"
    XRD_TestCheck(WinType("XRDLibrary")==7 && GetRTError(1)==0,"v080 shared library detail and checkbox panel renders without runtime error")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDProjectManager as output+"projects_v080.png"
    SaveExperiment/C/F={1,"",0} as output+"migration_roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "v080 migration failures="+num2istr(failures)
    return failures
End

Function XRD80_TestAdopt(path,peakRow,index,reflection)
    String path
    Variable peakRow,index,reflection
    XRD_ScoreCandidates(path,peakRow)
    Wave refs=$(path+":Candidates:refIndex"),rows=$(path+":Candidates:refPeakIndex")
    Variable i
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==index && rows[i]==reflection)
            return XRD_AssignCandidate(path,peakRow,i,0)
        endif
    endfor
    return -1
End

Function XRD_RunV80UITests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_LoadReferenceFile("QS-A.txt",1)
    XRD_LoadReferenceFile("Y-A.txt",2)
    XRD_TestCheck(cmpstr(StrVarOrDefault(XRD_ReferencePath(1)+":folder",""),"QS-type")==0 && cmpstr(StrVarOrDefault(XRD_ReferencePath(2)+":folder",""),"Y-type")==0,"v080 imported cards appear in their type folders")
    Make/FREE/D/N=1001 xx=20+p*0.05,yy=2+100*exp(-((xx[p]-30.1)/0.1)^2)+60*exp(-((xx[p]-44)/0.15)^2)
    String project=XRD_Project(),first=XRD_Store(xx,yy,"x=-0.1.xy")
    XRD80_RenameProject(project,"1200℃ in Air")
    XRD_Manual(first,30.1)
    XRD_Manual(first,44)
    XRD_TestCheck(XRD80_TestAdopt(first,0,1,0)==0 && XRD80_TestAdopt(first,1,2,2)==0 && XRD_IsAnalysisComplete(first),"v080 real candidate adoption automatically completes a fully assigned sample")
    XRD_ScoreCandidates(first,0)
    Wave refs=$(first+":Candidates:refIndex"),rows=$(first+":Candidates:refPeakIndex")
    Variable i,near=0
    for(i=0;i<numpnts(refs);i+=1)
        near+=(refs[i]==1 && (rows[i]==0 || rows[i]==1))
    endfor
    XRD_TestCheck(near==2,"v080 nearby reflections of one card remain separate candidate choices")
    XRD_NewProject()
    XRD80_RenameProject(XRD_Project(),"1250℃ in Air")
    String second=XRD_Store(xx,yy,"x=0.xy"),other=XRD_Project()
    XRD_Manual(second,30.1)
    XRD80_TestAdopt(second,0,1,0)
    String base=XRD_PlotRoot()
    Make/O/T/N=2 $(base+":compareUIDs")
    Wave/T selected=$(base+":compareUIDs")
    selected[0]=XRD80_MeasurementUID(first);selected[1]=XRD80_MeasurementUID(second)
    SVAR active=root:Packages:XRDWorkbench:activeProject
    active=project
    String/G $(project+":activeData")=first
    Variable/G $(project+":activeStep")=3
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    XRD_TestCheck(WinType("XRDWorkbench#SideCompare")==1 && strsearch(WinRecreation("XRDWorkbench#SideCompare",0),"1250℃",0)>=0,"v080 left live comparison renders another project's sample with its project label")
    XRD_PreviewCandidate(first,0)
    XRD_ReferenceArrow(first)
    DrawAction/W=XRDWorkbench#Pattern/L=UserFront getgroup=XRDReferenceArrow
    XRD_TestCheck(V_flag!=0,"v080 selected reference reflection has an arrow")
    DrawAction/W=XRDWorkbench#Pattern/L=UserFront getgroup=XRDSelectedArrow
    XRD_TestCheck(V_flag==0,"v080 measured selection does not also show a foreground arrow")
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 202
    SetAxis/W=XRDWorkbench#Pattern bottom 27,34
    XRD_UpdateSideCompare()
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==202,"v080 cross-project comparison refresh preserves the native Ctrl I cursor")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"workbench_v080.png"
    XRD80_LibraryPanel()
    Variable/G $(XRD_ReferencePath(2)+":enabled")=0
    XRD80_LibraryChanged()
    XRD80_RefreshLibraryList()
    XRD_TestCheck(XRD_IsAnalysisComplete(first),"v080 disabling a reference does not change historical completion")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDLibrary as output+"library_v080.png"
    XRD_PlotWorkspace()
    XRD_TestCheck(WinType("XRDPlotWorkspace")==7,"v080 independent completed-sample workspace opens")
    ControlInfo/W=XRDPlotWorkspace xMin
    XRD_TestCheck(V_disable==1,"v080 advanced figure settings start folded")
    Variable/G $(XRD_PlotRoot()+":UI:showDetails")=1
    XRD_PlotDetailControls()
    ControlInfo/W=XRDPlotWorkspace xMin
    XRD_TestCheck(V_disable==0,"v080 figure axes and fonts can be expanded for editing")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDPlotWorkspace as output+"plot_workspace_v080.png"
    XRD_PlotQuickCreate(first+";"+second+";","2プロジェクトの比較")
    String recipe=XRD_PlotRoot()+":Plots:Plot1",win="XRDP_plot1"
    XRD_TestCheck(strsearch(AnnotationInfo(win,"Phases",1),"QS-type",0)>=0 && strsearch(AnnotationInfo(win,"Phases",1),"Y-type",0)>=0,"v080 figure legend contains both phases including an inactive historical reference")
    Wave/T revisionIDs=$(recipe+":Snapshot:Sample1:referenceRevisionUIDs")
    XRD_TestCheck(strlen(revisionIDs[0])>0,"v080 figure snapshot records immutable reference revision IDs")
    DoWindow/K $win
    Wave styles=$(XRD80_Styles()+":values")
    Variable styleRow=XRD_StyleIndex(1)
    styles[styleRow][0]=23
    XRD_RefreshStyles()
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,1)==0 && strsearch(WinRecreation(win,0),"marker(MS1R1)=23",0)>=0,"v080 a closed saved figure adopts the new shared marker when reopened")
    XRD_ClearPeakReview(first,0)
    XRD_TestCheck(NumVarOrDefault(recipe+":stale",0)==1 && !XRD_IsAnalysisComplete(first) && XRD_IsAnalysisComplete(second),"v080 editing one source marks its figure stale and changes only that sample's completion")
    XRD_Undo()
    XRD_TestCheck(XRD_IsAnalysisComplete(first),"v080 Undo restores completion automatically")
    SavePICT/O/E=-5/SNAP=1/WIN=$win as output+"comparison_v080.png"
    SaveExperiment/C/F={1,"",0} as output+"integration_roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "v080 UI integration failures="+num2istr(failures)
    return failures
End

Function XRD_VerifyV80Restored()
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_TestCheck(NumVarOrDefault("root:Packages:XRDWorkbench:Schema:schemaVersion",0)==800,"v080 schema version survives Experiment reopen")
    XRD_TestCheck(ItemsInList(XRD_ProjectList())==2,"v080 both projects survive Experiment reopen")
    XRD_TestCheck(NumVarOrDefault(XRD80_Library()+":referenceCount",0)==2 && !XRD80_LibraryReferenceEnabled(2),"v080 shared library content and OFF setting survive Experiment reopen")
    String recipe=XRD_PlotRoot()+":Plots:Plot1"
    Wave/T ids=$(recipe+":sourceUIDs")
    XRD_TestCheck(numpnts(ids)==2 && XRD_IsAnalysisComplete(XRD80_ResolveMeasurement(ids[0])) && XRD_IsAnalysisComplete(XRD80_ResolveMeasurement(ids[1])),"v080 source identities and completion survive Experiment reopen")
    XRD_TestCheck(XRD_PlotDrawRecipe(recipe,1)==0,"v080 saved cross-project figure reopens from persisted recipe and numeric snapshot")
    Wave/T revisions=$(recipe+":Snapshot:Sample1:referenceRevisionUIDs")
    XRD_TestCheck(strlen(revisions[0])>0,"v080 immutable reference provenance survives Experiment reopen")
    XRD_TestCheck(NumVarOrDefault(XRD_Project()+":Undo:redoCount",0)>0 && XRD_Redo()==1 && XRD_Undo()==1,"v080 saved Undo and Redo remain usable after reopen")
    NVAR failures=root:XRDTestFailures
    Print "v080 persisted integration failures="+num2istr(failures)
    return failures
End

Function XRD_RunV80LatticeTests(output)
    String output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=1+exp(-((xx[p]-30)/0.1)^2)
    String path=XRD_Store(xx,yy,"lattice.xy")
    NewDataFolder/O $(path+":Lattice")
    Make/O/D/N=(8,6) $(path+":Lattice:inputs")
    Wave input=$(path+":Lattice:inputs")
    Make/FREE/D hh={1,0,1,1,2,2,0,2},kk={0,0,1,0,0,1,0,0},ll={0,2,0,2,1,0,4,3}
    Variable aa=5.89,cc=23.2,lambda=1.5406,zero=0.04
    Variable/G $(path+":zeroCorrection")=zero
    Variable/G $(path+":Lattice:refIndex")=1
    input[][0]=1
    input[][1]=360/pi*asin(lambda/2*sqrt(4*(hh[p]^2+hh[p]*kk[p]+kk[p]^2)/(3*aa^2)+ll[p]^2/cc^2))+zero
    input[][2]=hh[p];input[][3]=kk[p];input[][4]=ll[p];input[][5]=p+1
    String folder=GetDataFolder(1)
    XRD_TestCheck(XRD_FitHexagonal(path)==0 && abs(NumVarOrDefault(path+":Lattice:a",0)-aa)<1e-6 && abs(NumVarOrDefault(path+":Lattice:c",0)-cc)<1e-6,"v080 hexagonal Igor CurveFit recovers known a and c with zero correction")
    XRD_TestCheck(cmpstr(GetDataFolder(1),folder)==0,"v080 lattice calculation restores caller data folder")
    XRD_TestCheck(DataFolderExists(path+":LatticeRuns:Run1:AssignmentSnapshot"),"v080 lattice run keeps immutable calculation conditions and assignment snapshot")
    Wave savedInput=$(path+":LatticeRuns:Run1:inputs")
    Variable savedCRC=WaveCRC(0,savedInput)
    XRD_InvalidateFit(path)
    XRD_TestCheck(NumVarOrDefault(path+":LatticeRuns:Run1:stale",0)==1 && WaveCRC(0,savedInput)==savedCRC,"v080 edits mark history stale without altering historical input values")
    Redimension/N=(4,6) input
    aa=4.195
    Variable i
    for(i=0;i<4;i+=1)
        input[i][0]=1
        input[i][1]=2*asin(lambda*sqrt(i+1)/(2*aa))*180/pi+zero
        input[i][2]=1+(i==3);input[i][3]=(i==1 || i==2);input[i][4]=(i==2);input[i][5]=i+1
    endfor
    XRD_TestCheck(XRD_FitCubic(path)==0 && abs(NumVarOrDefault(path+":Lattice:a",0)-aa)<1e-6,"v080 cubic Igor CurveFit recovers known a with zero correction")
    XRD_TestCheck(NumVarOrDefault(path+":Lattice:stale",1)==0 && NumVarOrDefault(path+":LatticeRuns:Run2:stale",1)==0,"v080 recalculation creates a new current result while keeping old history")
    XRD_TestCheck(cmpstr(XRD80_LatticeResultPath(path,1),path+":LatticeRuns:Run2")==0,"v080 summary resolves the newest run by reference identity")
    XRD80_ProjectLatticeSummary()
    Wave/T table=$(XRD_Project()+":Summary:lattice")
    XRD_TestCheck(DimSize(table,0)==2 && strsearch(table[0][9],"変更",0)>=0,"v080 project lattice summary distinguishes stale and current runs")
    SaveExperiment/C/F={1,"",0} as output+"lattice_roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "v080 lattice failures="+num2istr(failures)
    return failures
End

Function XRD_RunV80StyleTests()
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    NewDataFolder/O root:StyleProbeA
    NewDataFolder/O root:StyleProbeB
    NewDataFolder/O root:StyleProbeA:Styles
    NewDataFolder/O root:StyleProbeB:Styles
    Make/O/T/N=1 root:StyleProbeA:Styles:keys="ConflictTest",root:StyleProbeB:Styles:keys="ConflictTest"
    Make/O/D/N=(1,4) root:StyleProbeA:Styles:values,root:StyleProbeB:Styles:values
    Wave first=root:StyleProbeA:Styles:values,second=root:StyleProbeB:Styles:values
    first[0][0]=19;first[0][1]=0;first[0][2]=0;first[0][3]=50000
    second[0][0]=23;second[0][1]=55000;second[0][2]=0;second[0][3]=0
    XRD80_MigrateStyles("root:StyleProbeA")
    XRD80_MigrateStyles("root:StyleProbeB")
    XRD_TestCheck(XRD80_StyleConflictCount()==1,"v080 different legacy styles create an explicit unresolved choice")
    XRD80_StyleConflicts()
    XRD_TestCheck(WinType("XRDStyleConflicts")==7 && GetRTError(1)==0,"v080 style conflict chooser displays native symbol and color previews")
    Wave values=$(XRD80_Styles()+":values"),rows=$(XRD80_Styles()+":conflictRows")
    XRD80_ResolveStyle(0,1)
    XRD_TestCheck(values[rows[0]][0]==23 && values[rows[0]][1]==55000 && XRD80_StyleConflictCount()==0,"v080 user-selected incoming style becomes the shared style")
    XRD_TestCheck(first[0][0]==19 && second[0][0]==23,"v080 style selection leaves original legacy palettes intact")
    XRD80_MigrateStyles("root:StyleProbeB")
    XRD_TestCheck(XRD80_StyleConflictCount()==0,"v080 repeated style migration does not repeat a resolved conflict")
    NVAR failures=root:XRDTestFailures
    Print "v080 style failures="+num2istr(failures)
    return failures
End
