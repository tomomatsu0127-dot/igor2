#pragma rtGlobals=3
#include ":xrd_v140_tests"

Function XRD141_RunFigureTests(fixture,output)
    String fixture,output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    NewPath/O/Q XRDReferencePath,fixture
    XRD_LoadReferenceFile("trend_hex.txt",1)
    String project=XRD_Project(),base=XRD133_TrendSettings(project)
    Variable/G $(base+":axis")=2
    Variable/G $(base+":ref")=1
    NewDataFolder/O $XRD133_TrendFigures()
    String recipe=XRD133_TrendFigures()+":LTrend_test141"
    NewDataFolder $recipe
    String/G $(recipe+":ownerUID")=StrVarOrDefault(project+":projectUID","")
    String/G $(recipe+":plotUID")="LTrend_test141"
    String/G $(recipe+":crystal")="六方晶"
    String/G $(recipe+":referenceRevisionUID")=StrVarOrDefault(XRD_ReferencePath(1)+":revisionUID","")
    Variable/G $(recipe+":axisKind")=2
    Make/D $(recipe+":horizontal")={-0.1,0,0.2,0.4,0.5}
    Make/D $(recipe+":latticeA")={5.88,5.90,5.895,5.91,5.93}
    Make/D $(recipe+":latticeC")={23.00,23.10,23.17,23.18,23.27}
    String msg=""
    XRD_TestCheck(XRD141_TrendStyle(base,recipe,1,msg)==0 && abs(NumVarOrDefault(recipe+":referenceA",NaN)-5.9)<1e-8,"v141 automatically uses declared reference")
    Variable/G $(XRD_ReferencePath(1)+":latticeA130")=NaN
    String/G $(XRD80_Library()+":referenceFolderHint")=fixture
    XRD_TestCheck(XRD141_TrendStyle(base,recipe,1,msg)==0 && abs(NumVarOrDefault(recipe+":referenceA",NaN)-5.9)<1e-8,"v141 automatic reference reads original TXT when metadata is missing")
    String refs=XRD141_RefDraft(base,1)
    String/G $(refs+":aOverride")="5.889"
    String/G $(refs+":cOverride")="23.123"
    String/G $(base+":compositionLabel141")="Substitution x"
    XRD_TestCheck(XRD141_TrendStyle(base,recipe,1,msg)==0 && NumVarOrDefault(recipe+":referenceA",NaN)==5.889 && NumVarOrDefault(recipe+":referenceC",NaN)==23.123,"v141 manual a and c override the automatic reference")
    XRD_TestCheck(cmpstr(StrVarOrDefault(recipe+":axisText141",""),"Substitution x")==0,"v141 composition label can be edited")
    String/G $(refs+":cOverride")="not a number"
    XRD_TestCheck(XRD141_TrendStyle(base,recipe,1,msg)<0,"v141 invalid reference override rejected")
    String/G $(refs+":cOverride")="23.123"
    String copy=XRD141_CopyTrend(recipe,project,msg)
    XRD_TestCheck(strlen(copy)>0 && XRD133_DrawTrend(copy)==0,"v141 reformat produces a separate native graph")
    if(!strlen(copy))
        return -1
    endif
    String win="XRDP_"+StrVarOrDefault(copy+":plotUID","")
    GetAxis/W=$win/Q bottom
    XRD_TestCheck(abs(V_min+0.1)<1e-12 && abs(V_max-0.5)<1e-12,"v141 axis endpoints exactly match composition measurements")
    Wave tickValues=$(copy+":tickPositions141")
    Wave/T tickLabels=$(copy+":tickLabels141")
    XRD_TestCheck(numpnts(tickValues)==7 && abs(tickValues[2]-0.1)<1e-12 && cmpstr(tickLabels[0],"−0.1")==0,"v141 composition ticks every 0.1 with mathematical minus")
    Make/FREE/D temp={1100,1150,1200,1250,1300}
    XRD_TestCheck(abs(XRD141_TickStep(temp)-50)<1e-12,"v141 temperature ticks preserve 50-degree spacing")
    String native=WinRecreation(win,4),traces=TraceNameList(win,";",1)
    XRD_TestCheck(WhichListItem("LatticeLegend",AnnotationList(win))<0 && strsearch(native,"DrawLine",0)>=0,"v141 colored native arrows replace legend")
    XRD_TestCheck(strsearch(native,"lblRot(right)=180",0)>=0 && strsearch(native,"lblMargin",0)>=0,"v141 right label rotates and label gap is explicit")
    XRD_TestCheck(WhichListItem("ReferenceA",traces)>=0 && WhichListItem("ReferenceC",traces)>=0,"v141 both reference lines plotted")
    XRD_TestCheck(cmpstr(XRD141_ExportName(win),XRD141_FigureName("格子定数",project)+".png")==0,"v141 lattice PNG default contains project")
    Display/K=1/N=XRD141SpectrumTest tickValues
    SetWindow XRD141SpectrumTest userdata(XRDPlotRecipe)=project
    XRD_TestCheck(cmpstr(XRD141_ExportName("XRD141SpectrumTest"),XRD141_FigureName("XRD",project)+".png")==0,"v141 XRD PNG default contains project")
    KillWindow XRD141SpectrumTest
    SavePICT/O/E=-5/WIN=$win as output+"figure141.png"
    WaveClear tickValues,tickLabels
    KillWindow $win
    XRD_TestCheck(XRD133_DrawTrend(copy)==0 && WhichListItem("LatticeLegend",AnnotationList(win))<0,"v141 native layout and ticks reopen")
    XRD_TestCheck(cmpstr(StrVarOrDefault(recipe+":plotUID",""),"LTrend_test141")==0,"v141 source figure retained")
    Print "V141 FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
    return 0
End
