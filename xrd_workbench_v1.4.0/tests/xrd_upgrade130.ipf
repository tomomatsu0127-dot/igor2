#pragma rtGlobals=3
#include ":xrd_semantic127"
// Validation only: switch a private copy, then remove this helper before saving.
Function XRD130_BeginUpgrade(main,output,saved)
    String main,output,saved
    String/G root:XRD130UpgradeMain=main
    String/G root:XRD130UpgradeOutput=output
    String/G root:XRD130UpgradeSaved=saved
    CtrlNamedBackground XRDAutoSave,stop
    XRD127_DumpAll(output+"baseline.tsv")
    XRD_CloseEditors()
    KillWindow/Z XRDWorkbench
    KillWindow/Z XRDProjectManager
    KillWindow/Z XRDCompareSelection
    KillWindow/Z XRDPlotWorkspace
    Execute/P/Q "CloseProc/NAME=\"xrd_main.ipf\"/COMP=0/D=0"
    Execute/P/Q "OpenProc \""+main+"\""
    Execute/P/Z "COMPILEPROCEDURES "
    Execute/P/Z "XRD130_FinishUpgrade()"
    return 0
End

Function XRD130_FinishUpgrade()
    String output=StrVarOrDefault("root:XRD130UpgradeOutput",""),saved=StrVarOrDefault("root:XRD130UpgradeSaved",""),log=StrVarOrDefault("root:XRD130NativeLog","")
    XRD127_DumpAll(output+"preinit.tsv")
    XRD_Init()
    XRD_Panel()
    DoUpdate
    CtrlNamedBackground XRDAutoSave,stop
    XRD127_DumpAll(output+"postinit.tsv")
    String saveCommand="SaveExperiment/C/F={1,\"\",0} as \""+saved+"\""
    String logCommand="Variable relocationLog130;Open relocationLog130 as \""+log+"\";fprintf relocationLog130,\"UPDATE_SAVED_RTE %d\\rSOURCE %s\\r\",GetRTError(1),FunctionPath(\"XRD_Open\");Close relocationLog130"
    Execute/P/Q "CloseProc/NAME=\"xrd_upgrade130.ipf\"/COMP=0/D=0"
    Execute/P/Q "KillVariables/Z root:XRDCLIIsolated130,root:testCapture;KillStrings/Z root:XRD130UpgradeMain,root:XRD130UpgradeOutput,root:XRD130UpgradeSaved,root:XRD130NativeLog"
    Execute/P/Z saveCommand
    Execute/P/Z logCommand
    Execute/P "Quit/N"
    return 0
End
