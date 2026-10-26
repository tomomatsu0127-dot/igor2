#pragma rtGlobals=3
#pragma version=1.10
#include ":xrd_project"
#include ":xrd_import"
#include ":xrd_peak"
#include ":xrd_reference"
#include ":xrd_match"
#include ":xrd_graph"
#include ":xrd_ui"
#include ":xrd_v3"
#include ":xrd_v4"
#include ":xrd_v41"
#include ":xrd_v42"
#include ":xrd_v44"
#include ":xrd_v45"
#include ":xrd_lattice"
#include ":xrd_v50"
#include ":xrd_profile"
#include ":xrd_v51"
#include ":xrd_v52"
#include ":xrd_v53"
#include ":xrd_detect"
#include ":xrd_v70"
#include ":xrd_v71"
#include ":xrd_v72"
#include ":xrd_autofind"
#include ":xrd_library"
#include ":xrd_experiment"
#include ":xrd_plotworkspace"
#include ":xrd_v80_styles"
#include ":xrd_v80_ui"
#include ":xrd_v81"
#include ":xrd_plot81"
#include ":xrd_v82"
#include ":xrd_manage100"
#include ":xrd_register100"
#include ":xrd_view100"
#include ":xrd_manager100"
#include ":xrd_ui110"
#include ":xrd_tree110"
#include ":xrd_entry110"
#include ":xrd_legend110"
#include <Peak AutoFind>

// XRD Workbench v1.1.0; Igor Pro 9+. Load this entry point only.
Menu "XRD Workbench"
    "プロジェクト画面へ/F6", XRD_Open()
    "プロジェクト・測定データ一覧...", XRD80_ProjectManager()
    "プロジェクトを追加...", XRD_NewProjectUI()
    "測定データを追加...", XRD_ImportDialog()
    "オプション...", XRD100_ViewOptions()
    Submenu "編集"
        "元に戻す (Ctrl+Z)", XRD_Undo()
        "やり直す (Ctrl+Shift+Z)", XRD_Redo()
    End
End

Menu "Experiment設定"
    "保存・自動保存...", XRD_SaveSettingsPanel()
End

Menu "参照値"
    "共通参照ライブラリを開く...", XRD80_LibraryPanel()
    "参照データを追加...", XRD_ChooseReference()
    "typeごとの使用カードを選ぶ...", XRD_TypePanel()
    "使用中の相の色・記号...", XRD_StylePanel()
    "旧プロジェクトの色・記号を選ぶ...", XRD80_StyleConflicts()
End

Function XRD_Open()
    XRD_Init()
    if(XRD100_RecoveryGuard()<0)
        return -1
    endif
    Execute/P/Q "XRD80_CheckLibraryAdditions()"
    Execute/P/Q "XRD80_OfferStyleConflicts()"
    if(DataFolderExists("root:Packages:XRDWorkbench:UI"))
        Variable/G root:Packages:XRDWorkbench:UI:livePending=0
        Variable/G root:Packages:XRDWorkbench:UI:liveBusy=0
    endif
    if(WinType("XRDWorkbench")==7)
        if(cmpstr(GetUserData("XRDWorkbench","","XRDProject"),XRD_Project())!=0 || cmpstr(GetUserData("XRDWorkbench","","XRDData"),XRD_Data())!=0)
            return XRD_Panel()
        endif
        if(cmpstr(GetUserData("XRDWorkbench","","XRDUIVersion"),"1.1.0")!=0)
            return XRD_Panel()
        endif
        SetWindow XRDWorkbench userdata(XRDAdoptPending)="0"
        DoWindow/F XRDWorkbench
        XRD_RequestLive()
        return 0
    endif
    XRD_Init()
    XRD_RecoverySettings()
    Variable/G root:Packages:XRDWorkbench:Recovery:saving=0
    Variable/G root:Packages:XRDWorkbench:Recovery:busy=0
    Variable/G root:Packages:XRDWorkbench:Recovery:queued=0
    XRD_Panel()
End

Function XRD_NewProjectUI()
    String label="新しいプロジェクト"
    Prompt label,"プロジェクト名"
    DoPrompt "プロジェクトを作成",label
    if(V_flag || !strlen(TrimString(label)))
        return -1
    endif
    label=TrimString(label)
    Variable hadProject=strlen(StrVarOrDefault("root:Packages:XRDWorkbench:activeProject",""))>0
    XRD_Init()
    String preflightOwner=SelectString(hadProject,XRD_Project(),"")
    if(XRD100_ValidProjectName(preflightOwner,label)<0)
        DoAlert 0,"同名のプロジェクト、使えない文字、名前の長さを確認してください。"
        return -1
    endif
    if(hadProject || !strlen(XRD_Project()))
        XRD_NewProject()
    endif
    String created=XRD_Project(),destination=XRD100_Management()+":"+PossiblyQuoteName(TrimString(label))
    if(cmpstr(created,destination,1)!=0)
        RenameDataFolder $created,$label
    endif
    String/G root:Packages:XRDWorkbench:activeProject=destination
    String/G $(destination+":displayName")=TrimString(label)
    XRD100_RefreshRegistry(destination)
    XRD_Panel()
End
