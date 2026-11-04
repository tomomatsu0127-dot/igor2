#pragma rtGlobals=3
// Guard every modal step of a project-management action, including validation.
// Keep registration panels separate: they are modeless editors, not dialogs.
Function XRD125_ManagerModal(action,project)
    String action,project
    String hidden=XRD124_BeginModal()
    Variable result=-1,error=0
    try
        strswitch(action)
            case "renameProject":
            case "migrateProject":
                result=XRD100_RenameUI(); AbortOnRTE
                break
            case "deleteProject":
                result=XRD100_DeleteUI(project); AbortOnRTE
                break
            case "restoreProject":
                result=XRD100_RestoreUI(); AbortOnRTE
                break
        endswitch
    catch
        error=GetRTError(1)
    endtry
    XRD124_EndModal(hidden)
    if(error)
        Abort GetErrMessage(error)
    endif
    return result
End
