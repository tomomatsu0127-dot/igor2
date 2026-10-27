#pragma rtGlobals=3
// v1.2.0: parent-window input routing and explicit view-only navigation.
Function XRD100_ViewSettings()
    NewDataFolder/O root:Packages:XRDWorkbench:UI
    XRD_EnsureNumeric("root:Packages:XRDWorkbench:UI:autoZoom100",1)
    XRD_EnsureNumeric("root:Packages:XRDWorkbench:UI:doubleZoom100",1)
    XRD_EnsureNumeric("root:Packages:XRDWorkbench:UI:selectBusy100",0)
End

Function XRD100_ViewControls(project,path)
    String project,path
    return 0
End

Function XRD100_ViewLayout(left,width,scale)
    Variable left,width,scale
    return XRD110_Layout(scale)
End

Function XRD100_Select(path,row,gesture)
    String path
    Variable row,gesture
    Wave xx=$(path+":Peaks:angle"),ids=$(path+":Peaks:peakID")
    if(row<0 || row>=numpnts(xx) || XRD100_Busy())
        return -1
    endif
    XRD100_ViewSettings()
    NVAR busy=root:Packages:XRDWorkbench:UI:selectBusy100
    busy=1
    Variable/G $(path+":pickMode81")=0
    Variable changed=(row!=NumVarOrDefault(path+":selectedPeakRow",-1))
    Variable/G $(path+":selectedPeakRow")=row
    Variable/G $(path+":selectedPeakID100")=ids[row]
    Variable/G $(path+":lastFollowID")=ids[row]
    ListBox peakList,win=XRDWorkbench,selRow=row,row=max(0,row-3)
    if(changed && NumVarOrDefault(XRD_Project()+":activeStep",1)==3)
        XRD_ScoreCandidates(path,row)
        ListBox candidateList,win=XRDWorkbench,selRow=0,row=0
    endif
    XRD_SelectedPeakGuide(path)
    XRD81_SyncPeakCursor(path)
    busy=0
    XRD81_UpdatePickerButtons(path)
    if(gesture && NumVarOrDefault(XRD_Project()+":activeStep",1)==3 && NumVarOrDefault("root:Packages:XRDWorkbench:UI:autoZoom100",1))
        XRD100_Zoom(path,xx[row],NumVarOrDefault(path+":zoomSpan100",10))
    endif
    return row
End

Function XRD100_Follow(path)
    String path
    if(!WinType("XRDWorkbench#Pattern") || NumVarOrDefault("root:Packages:XRDWorkbench:UI:selectBusy100",0))
        return 0
    endif
    Wave ids=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle")
    Variable row=NumVarOrDefault(path+":selectedPeakRow",-1),old=NumVarOrDefault(path+":lastFollowID",-1)
    if(row<0 || row>=numpnts(ids))
        return 0
    endif
    Variable/G $(path+":lastFollowID")=ids[row]
    Variable/G $(path+":selectedPeakID100")=ids[row]
    if(old>=0 && old!=ids[row] && NumVarOrDefault(XRD_Project()+":activeStep",1)==3 && NumVarOrDefault("root:Packages:XRDWorkbench:UI:autoZoom100",1))
        return XRD100_Zoom(path,angles[row],NumVarOrDefault(path+":zoomSpan100",10))
    endif
    return 0
End

Function XRD100_PushView(path,box)
    String path
    Wave box
    Wave/Z history=$(path+":viewHistory100")
    if(!WaveExists(history))
        Make/O/D/N=(0,4) $(path+":viewHistory100")
        Wave history=$(path+":viewHistory100")
    endif
    Variable n=DimSize(history,0)
    if(n>=50)
        DeletePoints/M=0 0,1,history
        n-=1
    endif
    Redimension/N=(n+1,4) history
    history[n][]=box[q]
End

Function XRD100_Zoom(path,center,span)
    String path
    Variable center,span
    String win="XRDWorkbench#Pattern"
    if(!strlen(path) || !WinType(win) || XRD100_Busy())
        return -1
    endif
    Wave xx=$(path+":Raw:twoTheta"),yy=$(path+":Processed:intensity")
    Variable total=xx[numpnts(xx)-1]-xx[0],minimum=2*total/max(2,numpnts(xx)-1)
    span=max(minimum,min(total,span))
    Variable lo=max(xx[0],min(xx[numpnts(xx)-1]-span,center-span/2)),hi=lo+span,i,maximum=0
    XRD_RecordPendingZoom(path)
    for(i=0;i<numpnts(xx);i+=1)
        if(xx[i]>=lo && xx[i]<=hi && numtype(yy[i])==0)
            maximum=max(maximum,yy[i])
        endif
    endfor
    Wave/Z rx=$(path+":Preview:angle"),ri=$(path+":Preview:height")
    if(NumVarOrDefault(XRD_Project()+":activeStep",1)==3 && WaveExists(rx))
        for(i=0;i<numpnts(rx);i+=1)
            if(rx[i]>=lo && rx[i]<=hi && numtype(ri[i])==0)
                maximum=max(maximum,ri[i])
            endif
        endfor
    endif
    SetAxis/W=$win bottom lo,hi
    if(NumVarOrDefault(XRD_Project()+":activeStep",1)==3)
        XRD120_LockY()
    else
        SetAxis/W=$win left -30,max(10,maximum*1.12)
    endif
    DoUpdate/W=$win
    XRD_RecordPendingZoom(path)
    XRD_CaptureView()
    XRD_SyncSideRange()
    XRD_RequestLive()
    return 0
End

Function XRD100_BackView(path)
    String path
    Wave/Z history=$(path+":viewHistory100")
    if(!WaveExists(history) || DimSize(history,0)==0)
        return 0
    endif
    Variable n=DimSize(history,0)-1
    Make/FREE/D/N=4 box=history[n][p]
    SetAxis/W=XRDWorkbench#Pattern bottom box[0],box[1]
    SetAxis/W=XRDWorkbench#Pattern left box[2],box[3]
    Redimension/N=(n,4) history
    XRD_CaptureView()
    XRD_ViewSync(path)
    XRD_SyncSideRange()
    return 1
End

Function XRD100_ViewButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String path=XRD_Data()
    if(!strlen(path))
        return 0
    endif
    Wave angles=$(path+":Peaks:angle"),xx=$(path+":Raw:twoTheta")
    Variable row=NumVarOrDefault(path+":selectedPeakRow",-1),center=(xx[0]+xx[numpnts(xx)-1])/2,span
    if(row>=0 && row<numpnts(angles))
        center=angles[row]
    endif
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    span=V_max-V_min
    strswitch(ba.ctrlName)
        case "zoomPlus":
            Variable/G $(path+":zoomSpan100")=span/2
            XRD100_Zoom(path,center,span/2)
            break
        case "zoomMinus":
            Variable/G $(path+":zoomSpan100")=min(xx[numpnts(xx)-1]-xx[0],span*2)
            XRD100_Zoom(path,center,span*2)
            break
        case "viewBack":
            XRD100_BackView(path)
            break
        case "viewAll":
            XRD100_Zoom(path,(xx[0]+xx[numpnts(xx)-1])/2,xx[numpnts(xx)-1]-xx[0])
            Variable/G $(path+":zoomSpan100")=10
            break
        case "pointAdd":
            if(NumVarOrDefault(path+":pickMode81",0) && cmpstr(StringByKey("TNAME",CsrInfo(A,"XRDWorkbench#Pattern")),"XRDWB_Measured")==0)
                DoAlert 1,"2θ = "+num2str(hcsr(A,"XRDWorkbench#Pattern"))+"° の点を測定ピークに追加しますか？"
                if(V_flag==1)
                    XRD81_AddCursorPoint()
                endif
            else
                DoAlert 0,"測定ピーク画面では曲線をクリック、同定画面ではShiftを押しながら曲線をクリックして追加位置を選んでください。"
            endif
            break
    endswitch
    return 0
End

Function XRD100_PointHook(s)
    STRUCT WMWinHookStruct &s
    return XRD110_PointHook(s)
End
