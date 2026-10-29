#pragma rtGlobals=3
// v1.2.3: auxiliary panels must not take over the MDI maximize state.
Function/S XRD123_PanelState(win)
    String win
    if(!WinType(win))
        return ""
    endif
    // Floating panels have no native maximize state. wsize is the content
    // rectangle accepted by MoveWindow; wsizeRM includes a title offset.
    GetWindow $win wsize
    return num2str(V_left)+";"+num2str(V_top)+";"+num2str(V_right)+";"+num2str(V_bottom)
End

Function XRD123_FinishPanel(win,state)
    String win,state
    ModifyPanel/W=$win fixedSize=0
    if(ItemsInList(state)==4)
        Variable l=str2num(StringFromList(0,state)),t=str2num(StringFromList(1,state))
        Variable r=str2num(StringFromList(2,state)),b=str2num(StringFromList(3,state))
        MoveWindow/W=$win l,t,r,b
    endif
    // A floating panel remains the implicit target while being built only.
    SetActiveSubwindow _endfloat_
    return 0
End
