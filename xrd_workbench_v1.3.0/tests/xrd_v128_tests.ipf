#pragma rtGlobals=3
#include ":xrd_v127_tests"
Function XRD_RunV128Tests(fixtures)
    String fixtures
    Variable/G root:XRDTestFailures=0
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_LoadReferenceFile("phase1.txt",1)
    XRD_LoadReferenceFile("phase2.txt",2)
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=2+100*exp(-((xx[p]-25)/0.1)^2)+60*exp(-((xx[p]-27)/0.1)^2)
    String project=XRD_Project(),a=XRD_Store(xx,yy,"first.xy"),ua=XRD80_MeasurementUID(a)
    XRD_Manual(a,25);XRD_Manual(a,27)
    String b=XRD_Store(xx,yy,"second.xy"),ub=XRD80_MeasurementUID(b)
    XRD_Manual(b,25)
    XRD_NewProject()
    String p2=XRD_Project(),c=XRD_Store(xx,yy,"third.xy"),uc=XRD80_MeasurementUID(c)
    String/G root:Packages:XRDWorkbench:activeProject=project
    String/G $(project+":activeData")=a
    Variable/G $(project+":activeStep")=3
    XRD_Panel();XRD_LiveDeferred();DoUpdate
    String settings=XRD120_CompareSettings(),list
    Make/O/T/N=4 $(settings+":uids")
    Wave/T selected=$(settings+":uids")
    selected[0]=uc;selected[1]=ua;selected[2]=uc;selected[3]="missing-uid"
    list=XRD_ComparePaths()
    XRD_TestCheck(ItemsInList(list)==2 && cmpstr(StringFromList(0,list),c)==0 && cmpstr(StringFromList(1,list),a)==0,"v128 selected UIDs retain cross-project order and remove duplicate/missing UID")
    Variable/G $(c+":deleted")=1
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==1,"v128 deleted measurement is excluded immediately")
    Variable/G $(c+":deleted")=0
    Variable/G $(p2+":projectDeleted100")=1
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==1,"v128 deleted project is excluded immediately")
    Variable/G $(p2+":projectDeleted100")=0
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==2,"v128 restored project is visible without a stale cache")
    Redimension/N=0 selected
    XRD_TestCheck(ItemsInList(XRD_ComparePaths())==0,"v128 empty comparison remains explicitly empty")
    Redimension/N=1 selected;selected[0]=ua
    Wave raw=$(b+":Raw:intensity"),processed=$(b+":Processed:intensity"),heights=$(b+":Peaks:height")
    Wave/T table=$(b+":Peaks:table")
    Variable rawMod=WaveModCount(raw),processedMod=WaveModCount(processed),heightMod=WaveModCount(heights),tableMod=WaveModCount(table)
    Variable i
    for(i=0;i<5;i+=1)
        list=XRD_MeasurementOrderList(project)
        list=XRD127_MeasurementList(project)
        list=XRD_ComparePaths()
        XRD110_DataChooser()
    endfor
    XRD_TestCheck(WaveModCount(raw)==rawMod && WaveModCount(processed)==processedMod,"v128 repeated list/chooser/comparison queries never write unselected raw or normalized waves")
    XRD_TestCheck(WaveModCount(heights)==heightMod && WaveModCount(table)==tableMod,"v128 list queries never rewrite unselected peak heights or table")
    Variable/G $(project+":activeStep")=1;XRD_Panel();XRD_LiveDeferred();DoUpdate
    Variable/G $(project+":activeStep")=3;XRD_Panel();XRD_LiveDeferred();DoUpdate
    XRD_TestCheck(WaveModCount(processed)==processedMod && WaveModCount(table)==tableMod,"v128 same-project step changes avoid upgrading all measurements")
    XRD_ScoreCandidates(a,0)
    Wave refs=$(a+":Candidates:refIndex")
    XRD_TestCheck(numpnts(refs)>0,"v128 candidate scoring remains available after step changes")
    Wave/T evidence=$(a+":Evidence:table")
    Variable evidenceCRC=WaveCRC(0,evidence)
    Wave shifts=$(a+":Candidates:shift")
    XRD_PreviewReference(a,refs[0],shifts[0])
    XRD_TestCheck(WaveCRC(0,evidence)==evidenceCRC,"v128 single evidence build retains the identical candidate evidence")
    KillVariables/Z $(b+":stackOrder")
    list=XRD_MeasurementOrderList(project)
    XRD_TestCheck(numtype(NumVarOrDefault(b+":stackOrder",NaN))==0 && ItemsInList(list)==2,"v128 legacy missing stack order still initializes")
    XRD100_Select(a,1,1,preserveScroll=1);XRD_LiveDeferred();DoUpdate
    Variable selectedRow=NumVarOrDefault(a+":selectedPeakRow",-1)
    Variable liveError=NumVarOrDefault("root:Packages:XRDWorkbench:UI:liveLastError",1)
    XRD_TestCheck(selectedRow==1 && liveError==0,"v128 selection updates candidates and live comparison without errors")
    Print "V128_FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End
