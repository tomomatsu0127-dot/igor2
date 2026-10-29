#pragma rtGlobals=3
// v1.2.4: retain the native frame and separate view state from analysis.
Function XRD120_CanRefresh()
    if(!WinType("XRDWorkbench") || cmpstr(GetUserData("XRDWorkbench","","XRDUIVersion"),"1.2.3")!=0)
        return 0
    endif
    String project=XRD_Project(),path=XRD_Data()
    return cmpstr(GetUserData("XRDWorkbench","","XRDProject"),project)==0 && cmpstr(GetUserData("XRDWorkbench","","XRDData"),path)==0 && str2num(GetUserData("XRDWorkbench","","XRDStep"))==NumVarOrDefault(project+":activeStep",1)
End

Function XRD120_RefreshPanel()
    PauseUpdate; Silent 1
    String project=XRD_Project(),path=XRD_Data()
    Variable step=NumVarOrDefault(project+":activeStep",1)
    DoWindow/T XRDWorkbench,"XRD Workbench v1.2.4 - "+XRD_ProjectDisplayName(project)
    XRD_CapturePanelState(1)
    XRD_CaptureView()
    XRD_EnsureFilterCurrent(path)
    if(strlen(path) && (step==1 || step==3))
        XRD81_RefreshPeaks(path)
        if(step==1)
            XRD120_ThresholdBinding(path)
        endif
        // RefreshPeaks also updates status, chooser, Y lock, warning and live
        // comparison. Do not repeat those scans and control writes here.
        return 0
    elseif(step==2)
        XRD_RebuildReferenceTable(project)
        ControlUpdate/W=XRDWorkbench referenceList
        TitleBox referenceSummary,win=XRDWorkbench,title=StrVarOrDefault(XRD80_Library()+":referenceLoadSummary","")
    elseif(step==4 && strlen(path))
        XRD_RefreshAssignmentTable(path)
        ControlUpdate/W=XRDWorkbench assignmentList
    endif
    XRD_StatusBar(project,path)
    XRD110_DataChooser()
    XRD120_LockY()
    XRD120_UpdateWarning(path)
    XRD_RequestLive()
    return 0
End

Function XRD120_ClearContents()
    String controls=ControlNameList("XRDWorkbench",";"),children=ChildWindowList("XRDWorkbench"),name
    Variable i
    for(i=0;i<ItemsInList(controls);i+=1)
        name=StringFromList(i,controls)
        KillControl/W=XRDWorkbench $name
    endfor
    for(i=0;i<ItemsInList(children);i+=1)
        name="XRDWorkbench#"+StringFromList(i,children)
        if(WinType(name))
            KillWindow $name
        endif
    endfor
    return 0
End

Function XRD120_Controls()
    if(!WinType("XRDWorkbench"))
        return 0
    endif
    String settings=XRD120_CompareSettings()
    if(NumVarOrDefault(XRD_Project()+":activeStep",1)==3)
        TitleBox strongNotice120,win=XRDWorkbench,pos={345,275},size={470,38},fixedSize=1,frame=0,fSize=11,title=""
        TitleBox legendSize120,win=XRDWorkbench,pos={158,164},frame=0,title="凡例",fSize=10
        Slider legendFont120,win=XRDWorkbench,pos={186,160},size={105,18},vert=0,ticks=0,limits={10,24,1},variable=$(settings+":legendFont"),proc=XRD120_LegendSlider
    endif
    return 0
End

Function XRD120_Layout(scale,left,width,graphTop,half,tableTop)
    Variable scale,left,width,graphTop,half,tableTop
    if(NumVarOrDefault(XRD_Project()+":activeStep",1)!=3)
        return 0
    endif
    Variable side=left-12*scale,inner=side-20*scale
    Button matchActions,win=XRDWorkbench,pos={12*scale,110*scale},size={inner,25*scale},fSize=max(12,round(12*scale))
    TitleBox legendSize120,win=XRDWorkbench,pos={side*0.52,164*scale},fSize=round(10*scale)
    Slider legendFont120,win=XRDWorkbench,pos={side*0.62,160*scale},size={side*0.33,19*scale}
    if(NumVarOrDefault(XRD_Project()+":tablesOnly",0))
        TitleBox strongNotice120,win=XRDWorkbench,pos={left,60*scale},size={width,32*scale},fSize=max(11,round(11*scale))
        ListBox peakList,win=XRDWorkbench,pos={left,94*scale},size={width,half-32*scale}
        ListBox candidateList,win=XRDWorkbench,pos={left,94*scale+half},size={width,half-30*scale}
        return 0
    endif
    TitleBox strongNotice120,win=XRDWorkbench,pos={left,tableTop-2*scale},size={width,32*scale},fSize=max(11,round(11*scale))
    ListBox peakList,win=XRDWorkbench,pos={left,tableTop+33*scale},size={width*0.46,half-53*scale}
    ListBox candidateList,win=XRDWorkbench,pos={left+width*0.46+5*scale,tableTop+33*scale},size={width*0.54-5*scale,half-53*scale}
    return 0
End

Function XRD120_MatchMenu(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    PopupContextualMenu XRD_MatchActionChoices()
    Variable action=V_flag
    if(action>1 && cmpstr(GetUserData("XRDWorkbench","","XRDMorePending"),"1")!=0)
        SetWindow XRDWorkbench userdata(XRDMorePending)="1"
        SetWindow XRDWorkbench userdata(XRDMoreAction)=num2istr(action)
        SetWindow XRDWorkbench userdata(XRDMoreContext)=XRD_MatchActionContext(action)
        Execute/P/Q "XRD_MatchActionDeferred()"
    endif
    return 0
End

Function XRD120_LockY()
    String win="XRDWorkbench#Pattern"
    if(!WinType(win) || NumVarOrDefault(XRD_Project()+":activeStep",1)!=3)
        return 0
    endif
    GetAxis/W=$win/Q left
    if(abs(V_min+30)>1e-8 || abs(V_max-110)>1e-8)
        SetAxis/W=$win left -30,110
    endif
    // The fixed Y policy is a display default, never a new analysis Undo entry.
    Wave/Z baseline=$(XRD_Data()+":viewBaseline")
    if(WaveExists(baseline) && numpnts(baseline)==4)
        baseline[2]=-30;baseline[3]=110
    endif
    return 0
End

Function/S XRD120_CompareSettings()
    String base=XRD_Project()+":Comparison120",root=XRD_PlotRoot()
    NewDataFolder/O $base
    XRD_EnsureNumeric(base+":legendFont",12)
    if(!NumVarOrDefault(root+":comparisonScope120",0))
        Wave/T/Z old=$(root+":compareUIDs")
        if(WaveExists(old))
            Duplicate/O old,$(base+":uids")
        endif
        Variable/G $(root+":comparisonScope120")=1
    endif
    return base
End

Function/S XRD120_ComparePaths()
    String base=XRD120_CompareSettings(),all=XRD_AllMeasurementPaths(0),out="",path,project=XRD_Project(),names
    Wave/T/Z selected=$(base+":uids")
    Variable i
    if(WaveExists(selected))
        for(i=0;i<numpnts(selected);i+=1)
            path=XRD80_ResolveMeasurement(selected[i])
            if(strlen(path) && WhichListItem(path,all)>=0 && WhichListItem(path,out)<0)
                out+=path+";"
            endif
        endfor
    else
        names=XRD_MeasurementOrderList(project)
        for(i=0;i<ItemsInList(names);i+=1)
            out+=project+":Measurements:"+StringFromList(i,names)+";"
        endfor
    endif
    return out
End

Function XRD120_LegendSlider(sa) : SliderControl
    STRUCT WMSliderAction &sa
    if(sa.eventCode>=0 && WinType("XRDWorkbench#SideCompare"))
        XRD_UpdateSideCompare()
    endif
    return 0
End

Function XRD120_EmptyComparison(win,embedded)
    String win
    Variable embedded
    if(embedded!=2)
        return -1
    endif
    String folder=XRD_PlotRoot()+":LiveSide",traces,name
    NewDataFolder/O $folder
    if(!WinType(win))
        Make/O/D/N=2 $(folder+":emptyX")=NaN,$(folder+":emptyY")=NaN
        Wave xx=$(folder+":emptyX"),yy=$(folder+":emptyY")
        Display/HOST=XRDWorkbench/N=SideCompare/W=(12,190,315,460) yy vs xx
    endif
    traces=TraceNameList(win,";",1)
    Variable i
    for(i=ItemsInList(traces)-1;i>=0;i-=1)
        RemoveFromGraph/W=$win/Z $(StringFromList(i,traces))
    endfor
    traces=AnnotationList(win)
    for(i=0;i<ItemsInList(traces);i+=1)
        name=StringFromList(i,traces)
        TextBox/W=$win/K/N=$name
    endfor
    Make/O/D/N=2 $(folder+":emptyX")=NaN,$(folder+":emptyY")=NaN
    Wave emptyX=$(folder+":emptyX"),emptyY=$(folder+":emptyY")
    AppendToGraph/W=$win emptyY/TN=XRDCompareEmpty120 vs emptyX
    SetAxis/W=$win bottom 0,1
    SetAxis/W=$win left 0,1
    TextBox/W=$win/C/N=EmptyCompare120/F=0/A=MC "\Z12比較する試料を選択してください"
    SetWindow $win userdata(XRDPlotCount)="0"
    return 0
End

Function XRD120_ThresholdBinding(path)
    String path
    Variable mode=NumVarOrDefault(path+":detectorMode",0)
    if(mode==1)
        SetVariable threshold,win=XRDWorkbench,title="最小突出量 (%)",limits={0,100,0.1},value=$(path+":detectProminence")
    elseif(mode==2)
        SetVariable threshold,win=XRDWorkbench,title="最小高さ (%)",limits={0,100,0.1},value=$(path+":autoMinHeight")
    else
        SetVariable threshold,win=XRDWorkbench,title="高さしきい値 (%)",limits={0,100,1},value=$(path+":threshold")
    endif
    return 0
End
