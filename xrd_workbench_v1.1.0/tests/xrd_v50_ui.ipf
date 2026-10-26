#pragma rtGlobals=3
Function XRD_V50Preview(samplesPath,outputPath)
    String samplesPath,outputPath
    XRD_Init()
    XRD_NewProject()
    NewPath/O/Q XRDReferencePath,samplesPath
    XRD_LoadReferences()
    Make/FREE/D/N=5001 xx=20+0.01*p,yy=2+100*exp(-((xx[p]-35.423)/0.07)^2)+30*exp(-((xx[p]-30.095)/0.09)^2)+20*exp(-((xx[p]-43.053)/0.1)^2)+30*exp(-((xx[p]-56.944)/0.1)^2)+40*exp(-((xx[p]-62.516)/0.1)^2)
    String path=XRD_Store(xx,yy,"v0.5.0_UI_preview.xy")
    XRD_DetectLegacy(path)
    Wave angles=$(path+":Peaks:angle")
    Variable row=1
    XRD_ScoreCandidates(path,row)
    XRD_AssignCandidate(path,row,0,0)
    NVAR step=$(XRD_Project()+":activeStep")
    step=3
    XRD_TestDisableFollow()
    XRD_Panel()
    MoveWindow/W=XRDWorkbench 10,40,1160,730
    XRD_ResizeDeferred()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as outputPath+"workbench_v0.5.0.png"
    XRD_EvidencePanel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDEvidence as outputPath+"evidence_v0.5.0.png"
    XRD_AuditPanel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDAudit as outputPath+"review_v0.5.0.png"
    XRD_ReferenceEditor()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDReferenceEditor as outputPath+"reference_v0.5.0.png"
    DoWindow/K XRDEvidence
    DoWindow/K XRDAudit
    DoWindow/K XRDReferenceEditor
    XRD_ProfilePanel()
    STRUCT WMButtonAction ba
    ba.eventCode=2;ba.ctrlName="runProfile";ba.win="XRDProfilePanel"
    XRD_ProfileButton(ba)
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDProfilePanel as outputPath+"profile_panel_v0.5.0.png"
    SavePICT/O/E=-5/WIN=XRDProfileGraph as outputPath+"profile_graph_v0.5.0.png"
    CtrlNamedBackground XRDAutoSave,stop
    DoWindow/K XRDProfilePanel
    DoWindow/K XRDProfileGraph
    DoWindow/F XRDWorkbench
    DoWindow/T XRDWorkbench,"XRD Workbench v0.5.0 — 検証用"
End
