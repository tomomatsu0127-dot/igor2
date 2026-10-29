#pragma rtGlobals=3
// v1.2.4: a floating auxiliary panel can cover Igor 9 modal dialogs.
// Keep panel objects, controls, drafts and geometry; hide only visible XRD floats.
Function/S XRD124_BeginModal()
    String panels=WinList("XRD*",";","FLT:1"),hidden="",win
    Variable i
    SetActiveSubwindow _endfloat_
    for(i=0;i<ItemsInList(panels);i+=1)
        win=StringFromList(i,panels)
        DoWindow/HIDE=? $win
        if(V_flag==1)
            hidden+=win+";"
            DoWindow/HIDE=1 $win
        endif
    endfor
    return hidden
End

Function XRD124_EndModal(hidden)
    String hidden
    String win
    Variable i
    // Restore in reverse stacking order, and never resurrect a closed panel.
    for(i=ItemsInList(hidden)-1;i>=0;i-=1)
        win=StringFromList(i,hidden)
        if(WinType(win))
            DoWindow/HIDE=0 $win
        endif
    endfor
    SetActiveSubwindow _endfloat_
End

Function XRD124_Alert(kind,message)
    Variable kind
    String message
    String hidden=XRD124_BeginModal()
    Variable answer=0,error=0
    try
        DoAlert kind,message; AbortOnRTE
        answer=V_flag
    catch
        error=GetRTError(1)
    endtry
    XRD124_EndModal(hidden)
    if(error)
        Abort GetErrMessage(error)
    endif
    return answer
End

Function XRD124_ProjectPrompt(label)
    String &label
    String hidden=XRD124_BeginModal()
    Variable cancelled=1,error=0
    Prompt label,"プロジェクト名"
    try
        DoPrompt "プロジェクトを作成",label; AbortOnRTE
        cancelled=V_flag
    catch
        error=GetRTError(1)
    endtry
    XRD124_EndModal(hidden)
    if(error)
        Abort GetErrMessage(error)
    endif
    return cancelled
End

Function XRD124_ReferenceFolder()
    String hidden=XRD124_BeginModal()
    Variable cancelled=1,error=0
    try
        NewPath/O/Q/Z/M="参照TXTフォルダを選択" XRDReferencePath; AbortOnRTE
        cancelled=V_flag
    catch
        error=GetRTError(1)
    endtry
    XRD124_EndModal(hidden)
    if(error)
        Abort GetErrMessage(error)
    endif
    return cancelled
End
