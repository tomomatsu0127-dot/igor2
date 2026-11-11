#pragma rtGlobals=3
// Ordinary auxiliary windows are contained by Igor's Windows workspace.
Function/S XRD123_PanelState(win)
    String win
    if(!WinType(win))
        return ""
    endif
    // Use the viewport rectangle even when the panel has a scrollable canvas.
    GetWindow $win wsizeRM
    return num2str(V_left)+";"+num2str(V_top)+";"+num2str(V_right)+";"+num2str(V_bottom)
End

Function XRD123_FinishPanel(win,state)
    String win,state
    ModifyPanel/W=$win fixedSize=0
    GetWindow $win wsizeRM
    Variable l=V_left,t=V_top,w=V_right-V_left,h=V_bottom-V_top
    Variable oldL=l,oldT=t,oldW=w,oldH=h
    if(ItemsInList(state)==4)
        l=str2num(StringFromList(0,state))
        t=str2num(StringFromList(1,state))
        w=str2num(StringFromList(2,state))-l
        h=str2num(StringFromList(3,state))-t
    endif
    if(cmpstr(IgorInfo(2),"Windows")==0)
        GetWindow kwFrameInner wsize
        Variable frameW=V_right-V_left,frameH=V_bottom-V_top
        w=min(w,max(120,frameW-16))
        h=min(h,max(100,frameH-42))
        l=max(0,min(l,frameW-w-8))
        t=max(0,min(t,frameH-h))

        // Keep controls at their design sizes while the visible window fits.
        Variable factor=PanelResolution(win)/ScreenResolution
        GetWindow $win wsizeForControls
        Variable canvasW=V_right,canvasH=V_bottom,i
        String controls=ControlNameList(win,";"),name
        for(i=0;i<ItemsInList(controls);i+=1)
            name=StringFromList(i,controls)
            ControlInfo/W=$win $name
            canvasW=max(canvasW,V_left+V_width+8)
            canvasH=max(canvasH,V_top+V_height+8)
        endfor
        if(cmpstr(win,"XRDLibrary")==0)
            canvasW=max(canvasW,950)
            canvasH=max(canvasH,600)
        endif
        canvasW*=factor
        canvasH*=factor
        if(canvasW>w+0.75 || canvasH>h+0.75)
            SetWindow $win doScroll=(max(canvasW,w),max(canvasH,h))
        endif
    endif
    if(abs(l-oldL)+abs(t-oldT)+abs(w-oldW)+abs(h-oldH)>0.75)
        MoveWindow/W=$win l,t,l+w,t+h
    endif
    return 0
End
