#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Menu "XRD移行"
    "手作業の実験を取り込む (.pxp)...", XRDLegacySetup_Open()
End

Function XRDLegacySetup_Open()
    Variable result=XRDLegacySetup_Load()
    switch(result)
        case -1:
            DoAlert 0,"取り込み先として File → New Experiment で空の実験を作るか、XRD Workbench v1.4.4 を開いてください。移行元の .pxp は、このメニューから選びます。"
            return result
        case -2:
            DoAlert 0,"配布 ZIP をフォルダーごと解凍し、そのフォルダー内の start_xrd_migration.ipf を開いてください。"
            return result
        case -3:
            DoAlert 0,"開いている XRD Workbench の版では起動できません。v1.4.4 を開くか、空の Experiment で起動してください。"
            return result
    endswitch
    Execute/P/Q "XRDLegacySetup_Show()"
    return 0
End

Function XRDLegacySetup_Load()
    Variable hasWorkbench=exists("ProcGlobal#XRD144_ApplyOpenTicks")==6
    if(!hasWorkbench)
        if(exists("ProcGlobal#XRD_Init")==6 || exists("ProcGlobal#XRD82_ValidIndex")==6)
            return -3
        endif
        if(strlen(IgorInfo(11)) || str2num(IgorInfo(16))>0)
            return -1
        endif
    endif
    if(exists("ProcGlobal#XRDLegacy_Open")==6)
        return 0
    endif
    String path=FunctionPath("")
    if(!strlen(path) || cmpstr(path[0],":")==0)
        return -2
    endif
    String folder=ParseFilePath(1,path,":",1,0)
    String migration=folder+"support:xrd_legacy_migration.ipf"
    String runtime=folder+"runtime:xrd_main.ipf"
    if(!XRDLegacySetup_FileExists(migration) || (!hasWorkbench && !XRDLegacySetup_FileExists(runtime)))
        return -2
    endif
    if(!hasWorkbench)
        Execute/P/Q "OpenProc/R/V=0 "+XRDLegacySetup_Quote(runtime)
    endif
    Execute/P/Q "OpenProc/R/V=0 "+XRDLegacySetup_Quote(migration)
    Execute/P/Q "COMPILEPROCEDURES "
    return 0
End

Function XRDLegacySetup_Show()
    if(exists("ProcGlobal#XRDLegacy_Open")!=6)
        DoAlert 0,"移行ツールを読み込めませんでした。ZIP 全体を解凍し、Igor Pro 9.05 で開いてください。"
        return -1
    endif
    Execute/P/Q "XRDLegacy_Open()"
    return 0
End

Function XRDLegacySetup_FileExists(path)
    String path
    GetFileFolderInfo/Q/Z path
    return V_flag==0 && V_isFile
End

Function/S XRDLegacySetup_Quote(path)
    String path
    return "\""+ReplaceString("\"",path,"\\\"")+"\""
End
