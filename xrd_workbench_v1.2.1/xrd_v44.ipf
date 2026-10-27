#pragma rtGlobals=3
// XRD Workbench v1.2.0: native resizable panel and retained cursor/view state.
Function XRD_UISettings()
    NewDataFolder/O root:Packages:XRDWorkbench:UI
    String base="root:Packages:XRDWorkbench:UI:"
    XRD_EnsureNumeric(base+"textMode",0)
    XRD_EnsureNumeric(base+"hasWindow",0)
    XRD_EnsureNumeric(base+"maximized",0)
    XRD_EnsureNumeric(base+"left",10)
    XRD_EnsureNumeric(base+"top",10)
    XRD_EnsureNumeric(base+"width",858)
    XRD_EnsureNumeric(base+"height",510)
End

Function XRD_CapturePanelState(captureCursors)
    Variable captureCursors
    if(!WinType("XRDWorkbench") || cmpstr(GetUserData("XRDWorkbench","","XRDLayoutBusy"),"1")==0)
        return 0
    endif
    XRD_UISettings()
    String base="root:Packages:XRDWorkbench:UI:"
    GetWindow XRDWorkbench wsizeRM
    Variable/G $(base+"left")=V_left
    Variable/G $(base+"top")=V_top
    // Store restored dimensions in panel units at 100%, portable across DPI.
    Variable factor=ScreenResolution/PanelResolution("")
    Variable/G $(base+"width")=(V_right-V_left)*factor
    Variable/G $(base+"height")=(V_bottom-V_top)*factor
    GetWindow XRDWorkbench maximize
    Variable/G $(base+"maximized")=V_Value
    Variable/G $(base+"hasWindow")=1
    if(!captureCursors)
        return 0
    endif
    String path=GetUserData("XRDWorkbench","","XRDData"),cursorName,info,trace
    if(strlen(path)==0 || !DataFolderExists(path) || !WinType("XRDWorkbench#Pattern"))
        return 0
    endif
    GetWindow XRDWorkbench activeSW
    String/G $(path+":uiActiveChild")=S_Value
    Variable/G $(path+":uiShowInfo")=(strsearch(WinRecreation("XRDWorkbench",0),"ShowInfo",0)>=0)
    Variable i
    for(i=0;i<2;i+=1)
        cursorName=StringFromList(i,"A;B")
        if(i==0)
            info=CsrInfo(A,"XRDWorkbench#Pattern")
        else
            info=CsrInfo(B,"XRDWorkbench#Pattern")
        endif
        trace=StringByKey("TNAME",info)
        Variable/G $(path+":uiCursor"+cursorName)=-1
        if(cmpstr(trace,"XRDWB_Measured")==0)
            Variable/G $(path+":uiCursor"+cursorName)=NumberByKey("POINT",info)
            Variable/G $(path+":uiShowInfo")=1
        endif
    endfor
    return 0
End

Function XRD_RestorePanelState()
    NVAR saved=root:Packages:XRDWorkbench:UI:hasWindow
    if(!saved)
        return 0
    endif
    NVAR left=root:Packages:XRDWorkbench:UI:left,top=root:Packages:XRDWorkbench:UI:top
    NVAR width=root:Packages:XRDWorkbench:UI:width,height=root:Packages:XRDWorkbench:UI:height,maximized=root:Packages:XRDWorkbench:UI:maximized
    Variable factor=PanelResolution("")/ScreenResolution
    // Clamp saved coordinates to Igor's current workspace when changing monitors.
    GetWindow kwFrameInner wsize
    Variable frameWidth=V_right-V_left,frameHeight=V_bottom-V_top
    Variable w=max(720*factor,min(width*factor,frameWidth-12))
    Variable h=max(440*factor,min(height*factor,frameHeight-36))
    Variable x=max(0,min(left,frameWidth-w-8)),y=max(0,min(top,frameHeight-h-32))
    SetWindow XRDWorkbench userdata(XRDLayoutBusy)="1"
    MoveWindow/W=XRDWorkbench x,y,x+w,y+h
    if(maximized)
        MoveWindow/W=XRDWorkbench 2,2,2,2
    endif
    SetWindow XRDWorkbench userdata(XRDLayoutBusy)="0"
    return 0
End

Function XRD_RememberControls()
    String list=ControlNameList("XRDWorkbench",";"),name
    Variable i,n=ItemsInList(list)
    Make/O/T/N=(n) root:Packages:XRDWorkbench:UI:controls
    Make/O/D/N=(n,4) root:Packages:XRDWorkbench:UI:geometry
    Wave/T controls=root:Packages:XRDWorkbench:UI:controls
    Wave geometry=root:Packages:XRDWorkbench:UI:geometry
    for(i=0;i<n;i+=1)
        name=StringFromList(i,list)
        controls[i]=name
        ControlInfo/W=XRDWorkbench $name
        geometry[i][0]=V_left;geometry[i][1]=V_top
        geometry[i][2]=V_width;geometry[i][3]=V_height
    endfor
    SetWindow XRDWorkbench userdata(XRDLayoutReady)="1"
End

Function XRD_ResizePanel()
    if(!WinType("XRDWorkbench") || cmpstr(GetUserData("XRDWorkbench","","XRDLayoutReady"),"1")!=0 || cmpstr(GetUserData("XRDWorkbench","","XRDLayoutBusy"),"1")==0)
        return 0
    endif
    SetWindow XRDWorkbench userdata(XRDLayoutBusy)="1"
    NVAR mode=root:Packages:XRDWorkbench:UI:textMode
    Variable floorScale=1+0.1*max(0,min(2,mode))
    Variable factor=PanelResolution("XRDWorkbench")/ScreenResolution
    Variable minW=720*factor*floorScale,minH=440*factor*floorScale
    SetWindow XRDWorkbench sizeLimit={minW,minH,inf,inf}
    GetWindow XRDWorkbench wsizeForControls
    Variable w=V_right,h=V_bottom,i,cx,cy,cw,ch,stepWidth
    Variable scale=max(floorScale,min(2,min(w/858,h/510)))
    SetWindow XRDWorkbench userdata(XRDUIScale)=num2str(scale)
    Wave/T controls=root:Packages:XRDWorkbench:UI:controls
    Wave geometry=root:Packages:XRDWorkbench:UI:geometry
    String name
    Variable vertical=min(1,(h/scale-80)/430)
    for(i=0;i<numpnts(controls);i+=1)
        name=controls[i]
        cx=geometry[i][0];cy=geometry[i][1]
        if(cx<205 && cy>=60 && cy<490)
            cy=60+(cy-60)*vertical
        endif
        cw=geometry[i][2];ch=geometry[i][3]
        ModifyControl $name,win=XRDWorkbench,pos={cx*scale,cy*scale},size={cw*scale,ch*scale},fSize=round(10*scale)
    endfor
    GroupBox workGroup,win=XRDWorkbench,size={195*scale,h-73*scale}
    TitleBox projectLabel,win=XRDWorkbench,disable=1

    stepWidth=(w-12*scale)/4
    for(i=0;i<4;i+=1)
        name="step"+num2istr(i+1)
        Button $name,win=XRDWorkbench,pos={6*scale+i*stepWidth,29*scale},size={stepWidth-3*scale,20*scale}
    endfor
    TitleBox statusBar,win=XRDWorkbench,pos={10*scale,h-15*scale},size={w-310*scale,12*scale}


    String project=XRD_Project(),path=XRD_Data(),listControls="peakList;candidateList;referenceList;assignmentList;measurementList"
    NVAR step=$(project+":activeStep"),full=$(project+":tablesOnly")
    Variable graphTop=60*scale
    if(step<=3)
        graphTop=80*scale
    endif
    Variable contentLeft=210*scale,contentW=w-228*scale,half=(h-120*scale)/2,tableTop=graphTop+10*scale+half,split=contentW*290/630
    if(step==3 && strlen(path))
        contentLeft=min(320*scale,w*0.35)+12*scale
        contentW=w-contentLeft-18*scale
        split=contentW*0.46
    endif
    if(WinType("XRDWorkbench#Pattern"))
        MoveSubwindow/W=XRDWorkbench#Pattern fnum=(contentLeft,graphTop,w-18*scale,graphTop+half)
        ModifyGraph/W=XRDWorkbench#Pattern gfSize=round(12*scale),fSize=round(12*scale)
        SetWindow XRDWorkbench#Pattern hide=(step==3 && full)
    endif
    for(i=0;i<ItemsInList(listControls);i+=1)
        name=StringFromList(i,listControls)
        ControlInfo/W=XRDWorkbench $name
        if(V_flag!=11)
            continue
        endif
        cx=contentLeft;cy=tableTop;cw=contentW;ch=half-20*scale
        if(step==3 && cmpstr(name,"peakList")==0)
            if(full)
                cy=60*scale;ch=half
            else
                cw=split
            endif
        elseif(step==3 && cmpstr(name,"candidateList")==0 && !full)
            cx=contentLeft+5*scale+split;cw=contentW-split-5*scale
        endif
        ListBox $name,win=XRDWorkbench,pos={cx,cy},size={cw,ch}
        strswitch(name)
            case "peakList":
                if(step==1)
                    ListBox peakList,win=XRDWorkbench,widths={100*scale,100*scale,110*scale}
                else
                    ListBox peakList,win=XRDWorkbench,widths={70*scale,65*scale,175*scale,60*scale,55*scale}
                endif
                break
            case "candidateList":
                ListBox candidateList,win=XRDWorkbench,widths={140*scale,110*scale,65*scale,120*scale,55*scale,65*scale,50*scale,55*scale,210*scale,70*scale,60*scale}
                break
            case "referenceList":
                ListBox referenceList,win=XRDWorkbench,widths={175*scale,115*scale,110*scale,220*scale,240*scale,50*scale}
                break
            case "measurementList":
                ListBox measurementList,win=XRDWorkbench,widths={90*scale,310*scale,150*scale,120*scale,120*scale}
                break
        endswitch
    endfor

    TitleBox recoveryState,win=XRDWorkbench,pos={210*scale,h-39*scale},size={w-405*scale,16*scale}
    XRD_UpdateHistoryUI()
    XRD_V72Layout(w,h,scale)
    XRD100_ViewLayout(contentLeft,contentW,scale)
    XRD120_Layout(scale,contentLeft,contentW,graphTop,half,tableTop)
    // No graph recreation, axis changes, or active-subwindow changes on resize.
    SetWindow XRDWorkbench userdata(XRDLayoutBusy)="0"
    XRD_CapturePanelState(0)
    return 0
End

Function XRD_ScheduleResize()
    if(cmpstr(GetUserData("XRDWorkbench","","XRDLayoutReady"),"1")!=0 || cmpstr(GetUserData("XRDWorkbench","","XRDLayoutBusy"),"1")==0 || cmpstr(GetUserData("XRDWorkbench","","XRDResizePending"),"1")==0)
        return 0
    endif
    SetWindow XRDWorkbench userdata(XRDResizePending)="1"
    // Native resize/maximize notifications can precede the final frame dimensions.
    Execute/P/Q "XRD_ResizeDeferred()"
End

Function XRD_ResizeDeferred()
    if(WinType("XRDWorkbench"))
        SetWindow XRDWorkbench userdata(XRDResizePending)="0"
        XRD_ResizePanel()
    endif
End

Function XRD_TextSizeAction(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2)
        return 0
    endif
    NVAR mode=root:Packages:XRDWorkbench:UI:textMode
    mode=max(0,min(2,pa.popNum-1))
    XRD_ResizePanel()
    return 0
End

Function XRD_RestorePanelCursors(path)
    String path
    if(strlen(path)==0 || !WinType("XRDWorkbench#Pattern"))
        return 0
    endif
    Variable shown=NumVarOrDefault(path+":uiShowInfo",0),point,i
    String cursorName
    Wave xx=$(path+":Raw:twoTheta")
    for(i=0;i<2;i+=1)
        cursorName=StringFromList(i,"A;B")
        point=NumVarOrDefault(path+":uiCursor"+cursorName,-1)
        if(point>=0 && point<numpnts(xx))
            if(i==0)
                Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured point
            else
                Cursor/P/W=XRDWorkbench#Pattern B XRDWB_Measured point
            endif
        endif
    endfor
    if(shown)
        SetActiveSubwindow XRDWorkbench#Pattern
        ShowInfo
    endif
    return 0
End
