#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

Function MHC_Upgrade(output)
    String output
    Variable/G root:MHTFailures=0
    // Saved before any manager initialization, after replacing the Procedure.
    SaveExperiment/C/F={1,"",0} as output+"loaded_before_init.pxp"
    MHT_Check(HMG_Init()==0,"legacy Experiment initializes without moving waves")
    HMG_OpenManager()
    Wave/T numbers=root:MHApp:Manager:sampleNumber,names=root:MHApp:names
    MHT_Check(cmpstr(numbers[0],"044")==0 && cmpstr(names[0],"旧測定 サンプル")==0,"legacy filename number backfilled without replacing custom display name")
    SVAR last=root:MHApp:lastGraph
    String graph=GetUserData(last,"","HMHGraphUID")
    String/G root:MHCompatGraph=graph
    MHT_Check(strlen(graph)>0,"existing legacy graph adopted with stable identity")
    SavePICT/WIN=$last/O/E=-5/B=72 as output+"after_init_graph.png"
    SaveExperiment/C/F={1,"",0} as output+"upgraded.pxp"
    MHT_Check(GetRTError(1)==0,"legacy migration ends without runtime errors")
    Print "COMPAT_UPGRADE_FAILURES",NumVarOrDefault("root:MHTFailures",-1)
End

Function MHC_Reopen(output)
    String output
    Variable/G root:MHTFailures=0
    SVAR graph=root:MHCompatGraph
    MHT_Check(HMG_OpenGraph(graph)==0,"upgraded legacy graph survives another process restart")
    MHT_Check(strsearch(HMG_GraphSources(graph),"044",0)>=0,"migrated graph source retains sample number after restart")
    String win=HMG_GraphWindow(graph)
    MHT_Check(strsearch(AnnotationInfo(win,"HMHLegend1",1),"旧版の手編集凡例",0)>=0,"legacy hand-edited legend survives restart")
    SavePICT/WIN=$win/O/E=-5/B=72 as output+"reopened_legacy_graph.png"
    SaveExperiment/C/F={1,"",0} as output+"upgraded_reopened.pxp"
    MHT_Check(GetRTError(1)==0,"upgraded legacy restart ends without runtime errors")
    Print "COMPAT_REOPEN_FAILURES",NumVarOrDefault("root:MHTFailures",-1)
End
