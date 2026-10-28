#pragma rtGlobals=3
// XRD Workbench v1.2.0: detection focus, linked zoom and event-driven live identification.
Function XRD_V71Controls(project,path)
    String project,path
    Variable step=NumVarOrDefault(project+":activeStep",1)
    if(step==2)
        Button typeCards,pos={16,233},size={175,23},title="使う物質をまとめて選ぶ",proc=XRD_V70Button
        Button typeFamilies,pos={16,261},size={175,23},title="typeごとにカードを選ぶ",proc=XRD_V71Button
        Button referenceStyle,pos={16,290},size={175,23}
        TitleBox overlayNote,pos={16,318},title="右の相を選ぶと参照棒を表示します。"
    elseif((step==1 || step==3) && strlen(path))
        XRD_EnsureNumeric(path+":followPeak",1)
        if(step==1)
            TitleBox stepHelp,title="黒点＝登録された測定ピーク。\r検出・追加・削除を行います。"
            XRD_DetectionTable(path)
            ListBox peakList,listWave=$(path+":Peaks:focusTable"),widths={100,100,110}
            CheckBox followPeak,pos={16,287},title="拡大を選択ピークに追従",variable=$(path+":followPeak")
            Button zoomPeak,pos={16,267},size={85,18},title="選択±5°",proc=XRD_V70Button
            Button resetZoom,pos={106,267},size={85,18},title="全範囲"
            Button deleteData,pos={16,435},size={175,20},title="この測定データを削除"
            Button restoreData,pos={16,459},size={175,20},title="削除した測定を戻す"
            TitleBox rawNote,pos={16,403},title="この画面では参照棒・同定記号を\r表示しません。Ctrl+Iも使えます。"
        else
            XRD_EnsureNumeric(project+":liveCompare",0)
            Button reviewSamples,pos={16,310},size={175,20},title="比較図を別窓でも開く",proc=XRD_V71Button
            CheckBox liveCompare,pos={16,291},title="ここで複数試料を比較",variable=$(project+":liveCompare"),proc=XRD_LiveCompareAction
            CheckBox followPeak,pos={16,275},title="拡大を選択ピークに追従",variable=$(path+":followPeak")
            Button tableView,pos={16,237},size={175,18}
            Button zoomPeak,pos={16,257},size={85,18}
            Button resetZoom,pos={106,257},size={85,18}
            Button details,pos={16,360},size={81,20},title=SelectString(NumVarOrDefault(project+":detailControls",0),"詳細設定 ▼","詳細を閉じる ▲")
            Button audit,pos={104,360},size={87,20},title="同定の確認一覧"
        endif
    endif
End

Function XRD_DetectionTable(path)
    String path
    XRD_PeakTable(path)
    Wave/T original=$(path+":Peaks:table"),origin=$(path+":Peaks:origin")
    Make/O/T/N=(DimSize(original,0),3) $(path+":Peaks:focusTable")
    Wave/T table=$(path+":Peaks:focusTable")
    table[][0]=original[p][0];table[][1]=original[p][1]
    table[][2]=SelectString(cmpstr(origin[p],"Auto")==0,SelectString(cmpstr(origin[p],"Manual")==0,"外部","手動"),"自動")
    SetDimLabel 1,0,'2theta (deg)',table
    SetDimLabel 1,1,'Intensity (%)',table
    SetDimLabel 1,2,'登録方法',table
End

Function XRD_DrawPeakFocus(path)
    String path
    Wave xx=$(path+":Raw:twoTheta"),yy=$(path+":Processed:intensity"),px=$(path+":Peaks:angle"),py=$(path+":Peaks:height")
    Display/HOST=XRDWorkbench/N=Pattern/W=(210,60,840,270) yy/TN=XRDWB_Measured vs xx
    AppendToGraph/W=XRDWorkbench#Pattern py/TN=XRDWB_Peaks vs px
    ModifyGraph/W=XRDWorkbench#Pattern rgb(XRDWB_Measured)=(0,0,0),lsize(XRDWB_Measured)=1.2
    ModifyGraph/W=XRDWorkbench#Pattern mode(XRDWB_Peaks)=3,marker(XRDWB_Peaks)=19,rgb(XRDWB_Peaks)=(0,0,0),msize(XRDWB_Peaks)=3
    SetWindow XRDWorkbench#Pattern userdata(XRDCompare)="0"
    XRD_GraphStyle("XRDWorkbench#Pattern",110,0)
    XRD_RestoreView(path)
    XRD_SelectedPeakGuide(path)
    XRD_ViewSync(path)
    SetActiveSubwindow XRDWorkbench
    return 0
End

Function XRD_CacheModeView(path)
    String path
    Variable mode=cmpstr(GetUserData("XRDWorkbench#Pattern","","XRDCompare"),"1")==0
    Variable/G $(path+":lastViewMode")=mode
    NewDataFolder/O $(path+":Views")
    String target=path+":Views:"+SelectString(mode,"Single","Compare")
    Make/O/D/N=4 $target
    Wave box=$target
    box[0]=NumVarOrDefault(path+":viewXMin",0);box[1]=NumVarOrDefault(path+":viewXMax",0)
    box[2]=NumVarOrDefault(path+":viewYMin",0);box[3]=NumVarOrDefault(path+":viewYMax",110)
    if(mode)
        Variable/G $(path+":Views:compareCount")=str2num(GetUserData("XRDWorkbench#Pattern","","XRDPlotCount"))
    endif
End

Function XRD_RestoreModeView(path)
    String path
    Variable mode=cmpstr(GetUserData("XRDWorkbench#Pattern","","XRDCompare"),"1")==0
    Wave/Z box=$(path+":Views:"+SelectString(mode,"Single","Compare"))
    if(WaveExists(box) && box[0]<box[1] && box[2]<box[3])
        SetAxis/W=XRDWorkbench#Pattern bottom box[0],box[1]
        if(!mode || NumVarOrDefault(path+":Views:compareCount",0)==ItemsInList(XRD_ComparePaths()))
            SetAxis/W=XRDWorkbench#Pattern left box[2],box[3]
        endif
        return 1
    endif
    if(mode || NumVarOrDefault(path+":lastViewMode",0)!=mode)
        if(NumVarOrDefault(path+":hasView",0))
            SetAxis/W=XRDWorkbench#Pattern bottom NumVarOrDefault(path+":viewXMin",20),NumVarOrDefault(path+":viewXMax",70)
        endif
        return 1
    endif
    return 0
End

Function XRD_FollowSelection(path)
    String path
    return XRD100_Follow(path)
End

Function XRD_LiveCompareAction(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    if(cba.eventCode==2)
        Execute/P/Q "XRD_Panel()"
    endif
    return 0
End

Function XRD_V71Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(cmpstr(ba.ctrlName,"typeFamilies")==0)
        Execute/P/Q "XRD_TypePanel()"
    elseif(cmpstr(ba.ctrlName,"reviewSamples")==0)
        Execute/P/Q "XRD_OpenReview()"
    endif
    return 0
End

Function XRD_DrawLiveStack(win,embedded)
    String win
    Variable embedded
    String project=XRD_Project(),path=XRD_Data(),list=XRD_ComparePaths(),folder=XRD_PlotRoot()+":Live"+SelectString(embedded,"Review","Panel")
    if(embedded==2)
        folder=XRD_PlotRoot()+":LiveSide"
    endif
    if(!strlen(path) || !ItemsInList(list))
        return XRD120_EmptyComparison(win,embedded)
    endif
    NewDataFolder/O $folder
    Variable existing=WinType(win)!=0,i,j,total=ItemsInList(list),offset,spacing=135,upper=100+(total-1)*135+40
    Variable xmin=NaN,xmax=NaN,ymin=NaN,ymax=NaN,oldCount=0
    String traces,trace,data,previewSource=path+":Preview",activeWin=""
    if(existing)
        oldCount=str2num(GetUserData(win,"","XRDPlotCount"))
        if(WhichListItem("XRDNeedsUpdate",AnnotationList(win))>=0)
            TextBox/W=$win/K/N=XRDNeedsUpdate
        endif
        GetAxis/W=$win/Q bottom
        xmin=V_min;xmax=V_max
        GetAxis/W=$win/Q left
        ymin=V_min;ymax=V_max
        traces=TraceNameList(win,";",1)
        // Keep native axes alive while replacing traces, retaining labels and style.
        Make/O/D/N=2 $(folder+":axisAnchorX")=NaN,$(folder+":axisAnchorY")=NaN
        Wave anchorX=$(folder+":axisAnchorX"),anchorY=$(folder+":axisAnchorY")
        AppendToGraph/W=$win anchorY/TN=XRDLiveAxisAnchor vs anchorX
        for(i=ItemsInList(traces)-1;i>=0;i-=1)
            trace=StringFromList(i,traces)
            RemoveFromGraph/W=$win/Z $trace
        endfor
        for(i=0;i<max(total,NumVarOrDefault(project+":liveLastCount",0));i+=1)
            if(WhichListItem("LiveLabel"+num2istr(i),AnnotationList(win))>=0)
                TextBox/W=$win/K/N=$("LiveLabel"+num2istr(i))
            endif
        endfor
    endif
    for(i=0;i<total;i+=1)
        data=StringFromList(i,list);offset=(total-1-i)*spacing
        Wave xx=$(data+":Raw:twoTheta"),yy=$(data+":Processed:intensity")
        Duplicate/O yy,$(folder+":intensity"+num2istr(i))
        Wave gy=$(folder+":intensity"+num2istr(i))
        gy=yy[p]+offset
        trace=SelectString(cmpstr(data,path)==0,"Sample"+XRD80_MeasurementUID(data),"XRDWB_Measured")
        if(!existing && i==0)
            if(embedded==2)
                Display/HOST=XRDWorkbench/N=SideCompare/W=(12,150,315,460) gy/TN=$trace vs xx
            elseif(embedded)
                Display/HOST=XRDWorkbench/N=Pattern/W=(210,60,840,270) gy/TN=$trace vs xx
            else
                Display/K=1/N=XRDReviewGraph/W=(35,35,825,600) gy/TN=$trace vs xx as "同定状況のライブ比較"
            endif
            SetWindow $win userdata(XRDGraphData)=folder
            SetWindow $win userdata(XRDReview)="1"
            SetWindow $win userdata(XRDProject)=project
        else
            AppendToGraph/W=$win gy/TN=$trace vs xx
        endif
        ModifyGraph/W=$win rgb($trace)=(0,0,0),lsize($trace)=SelectNumber(cmpstr(data,path)==0,1,1.8)
        XRD_PlotAddPhases(win,data,offset,folder)
        XRD_UnassignedPlot(data)
        Duplicate/O $(data+":Preview:unassignedY"),$(folder+":unassigned"+num2istr(i))
        Wave uy=$(folder+":unassigned"+num2istr(i)),ux=$(data+":Preview:unassignedX")
        uy+=offset
        trace=SelectString(cmpstr(data,path)==0,"Peaks"+XRD80_MeasurementUID(data),"XRDWB_Peaks")
        AppendToGraph/W=$win uy/TN=$trace vs ux
        ModifyGraph/W=$win mode($trace)=3,marker($trace)=19,msize($trace)=2,rgb($trace)=(0,0,0)
        XRD_LiveReference(win,folder,data,path,i,offset)
        String label=SelectString(cmpstr(data,path)==0,"","▶ 編集中  ")+XRD_ProjectDisplayName(XRD_PlotOwner(data))+" / "+XRD110_SampleLabel(data)+"\r"+XRD_ComparisonPhases(data)
        if(embedded==2)
            label=SelectString(cmpstr(data,path)==0,"","▶ ")+XRD_ProjectDisplayName(XRD_PlotOwner(data))+"\r"+XRD110_SampleLabel(data)
        endif
        TextBox/W=$win/C/N=$("LiveLabel"+num2istr(i))/F=0/B=1/A=RT/X=1/Y=(100*(upper-offset-100)/(upper+30)) "\\F'Times New Roman'\\Z"+num2istr(SelectNumber(embedded==2,12,NumVarOrDefault(XRD120_CompareSettings()+":legendFont",12)))+label
    endfor
    if(existing)
        RemoveFromGraph/W=$win/Z XRDLiveAxisAnchor
    endif
    SetWindow $win userdata(XRDCompare)="1"
    SetWindow $win userdata(XRDData)=path
    SetWindow $win userdata(XRDPlotCount)=num2istr(total)
    SetWindow $win userdata(XRDLivePaths)=list
    Variable/G $(project+":liveLastCount")=total
    if(!existing)
        XRD_GraphStyle(win,upper,0)
        if(!embedded)
            ModifyGraph/W=$win width=0,height=0,margin(top)=55,margin(left)=65,margin(bottom)=55,gfSize=14
            SetWindow $win userdata(XRDFlexible)="1"
            SetWindow $win userdata(XRDFigureLegendFont)="14"
        endif
    endif
    if(existing)
        SetAxis/W=$win bottom xmin,xmax
        if(oldCount==total && ymin<ymax)
            SetAxis/W=$win left ymin,ymax
        else
            SetAxis/W=$win left -30,upper
        endif
    elseif(embedded==1)
        XRD_RestoreView(path)
    else
        Wave activeX=$(path+":Raw:twoTheta")
        SetAxis/W=$win bottom activeX[0],activeX[numpnts(activeX)-1]
    endif
    if(embedded==2)
        XRD_SyncSideRange()
        XRD_ReviewMeasuredGuide(win,path)
    elseif(embedded)
        XRD_SelectedPeakGuide(path)
        XRD_ShiftNotice(path)
        if(!existing)
            XRD_ViewSync(path)
            SetActiveSubwindow XRDWorkbench
        endif
    else
        XRD_PlotLegend(win)
        XRD_FollowReview(win,path)
        XRD_ReviewMeasuredGuide(win,path)
    endif
    XRD_DrawReferenceGuide(win,path)
    XRD110_SideLegend(win,embedded)
    return 0
End

Function XRD_FollowReview(win,path)
    String win,path
    Wave ids=$(path+":Peaks:peakID"),xx=$(path+":Peaks:angle"),rawX=$(path+":Raw:twoTheta")
    Variable row=NumVarOrDefault(path+":selectedPeakRow",-1)
    if(row<0 || row>=numpnts(ids))
        return 0
    endif
    String key=path+":"+num2istr(ids[row]),last=GetUserData(win,"","XRDFollowPeak")
    SetWindow $win userdata(XRDFollowPeak)=key
    if(cmpstr(key,last)==0 || !strlen(last) || !NumVarOrDefault(path+":followPeak",1))
        return 0
    endif
    GetAxis/W=$win/Q bottom
    Variable span=V_max-V_min,lo
    if(span>0 && span<rawX[numpnts(rawX)-1]-rawX[0]-1e-6)
        lo=max(rawX[0],min(rawX[numpnts(rawX)-1]-span,xx[row]-span/2))
        SetAxis/W=$win bottom lo,lo+span
    endif
    return 0
End

Function XRD_ReviewMeasuredGuide(win,path)
    String win,path
    DrawAction/W=$win/L=UserBack getgroup=XRDReviewMeasured
    if(V_flag)
        DrawAction/W=$win/L=UserBack getgroup=XRDReviewMeasured,delete
    endif
    Wave xx=$(path+":Peaks:angle")
    Variable row=NumVarOrDefault(path+":selectedPeakRow",-1)
    if(row>=0 && row<numpnts(xx))
        SetDrawLayer/W=$win UserBack
        SetDrawEnv/W=$win gstart,gname=XRDReviewMeasured
        SetDrawEnv/W=$win xcoord=bottom,ycoord=prel,dash=3,linefgc=(0,0,0)
        DrawLine/W=$win xx[row],0,xx[row],1
        SetDrawEnv/W=$win gstop
    endif
End

Function XRD_ReviewGuide(local)
    Variable local
    String path=XRD_Data()
    Wave xx=$(path+":Peaks:angle"),rawX=$(path+":Raw:twoTheta")
    Variable row=NumVarOrDefault(path+":selectedPeakRow",-1)
    if(local && row>=0 && row<numpnts(xx))
        SetAxis/W=XRDReviewGraph bottom max(rawX[0],xx[row]-5),min(rawX[numpnts(rawX)-1],xx[row]+5)
    else
        SetAxis/W=XRDReviewGraph bottom rawX[0],rawX[numpnts(rawX)-1]
    endif
    XRD_ReviewMeasuredGuide("XRDReviewGraph",path)
    XRD_DrawReferenceGuide("XRDReviewGraph",path)
    return 0
End

Function XRD_LiveReference(win,folder,data,active,index,offset)
    String win,folder,data,active
    Variable index,offset
    Variable step=NumVarOrDefault(XRD_Project()+":activeStep",1),ref=NumVarOrDefault(active+":Preview:referenceIndex",0),row=NumVarOrDefault(active+":Preview:reflectionIndex",-1)
    if((step!=2 && step!=3) || ref<1)
        return 0
    endif
    String rp=XRD_ReferencePath(ref),trace="LiveReference"+num2istr(index)
    Wave rx=$(rp+":twoTheta"),ri=$(rp+":intensity"),rawX=$(data+":Raw:twoTheta")
    Variable shift=XRD_ReferenceShift(data,ref),j,n=0,maximum=WaveMax(ri),height,minimum=NumVarOrDefault(XRD_Project()+":previewMinIntensity",1)
    Make/O/D/N=(3*numpnts(rx)) $(folder+":refX"+num2istr(index)),$(folder+":refY"+num2istr(index))
    Wave ox=$(folder+":refX"+num2istr(index)),oy=$(folder+":refY"+num2istr(index))
    for(j=0;j<numpnts(rx);j+=1)
        height=100*ri[j]/max(maximum,1e-12)
        if((height<minimum && j!=row) || rx[j]+shift<rawX[0] || rx[j]+shift>rawX[numpnts(rawX)-1])
            continue
        endif
        ox[n]=rx[j]+shift;oy[n]=offset
        ox[n+1]=rx[j]+shift;oy[n+1]=offset+height
        ox[n+2]=NaN;oy[n+2]=NaN;n+=3
    endfor
    Redimension/N=(n) ox,oy
    AppendToGraph/W=$win oy/TN=$trace vs ox
    ModifyGraph/W=$win mode($trace)=0,lsize($trace)=NumVarOrDefault(XRD_Project()+":previewWidth",1.5),rgb($trace)=(60000,0,0,65535*NumVarOrDefault(XRD_Project()+":previewOpacity",85)/100)
End

Function XRD_ReferenceArrow(path)
    String path
    if(WinType("XRDWorkbench#Pattern") && cmpstr(path,GetUserData("XRDWorkbench","","XRDData"))==0)
        XRD_DrawReferenceGuide("XRDWorkbench#Pattern",path)
    endif
    return 0
End

Function XRD_DrawReferenceGuide(win,path)
    String win,path
    DrawAction/W=$win/L=UserFront getgroup=XRDReferenceArrow
    if(V_flag)
        DrawAction/W=$win/L=UserFront getgroup=XRDReferenceArrow,delete
    endif
    if(WhichListItem("ReferenceSelected",AnnotationList(win))>=0)
        TextBox/W=$win/K/N=ReferenceSelected
    endif
    SetWindow $win userdata(XRDReferenceAngle)=""
    Variable ref=NumVarOrDefault(path+":Preview:referenceIndex",0),row=NumVarOrDefault(path+":Preview:reflectionIndex",-1),step=NumVarOrDefault(XRD_Project()+":activeStep",1)
    if(step!=3 || ref<1 || row<0)
        return 0
    endif
    Wave rx=$(XRD_ReferencePath(ref)+":twoTheta"),ri=$(XRD_ReferencePath(ref)+":intensity")
    Wave hh=$(XRD_ReferencePath(ref)+":h"),kk=$(XRD_ReferencePath(ref)+":k"),ll=$(XRD_ReferencePath(ref)+":l")
    if(row>=numpnts(rx))
        return 0
    endif
    Variable compare=cmpstr(GetUserData(win,"","XRDCompare"),"1")==0,i,total=1,offset=0,x,height=100*ri[row]/max(WaveMax(ri),1e-12)
    String list=GetUserData(win,"","XRDLivePaths"),data=path
    if(compare && !strlen(list))
        list=XRD_ComparePaths()
    endif
    if(compare)
        total=ItemsInList(list)
    endif
    GetAxis/W=$win/Q left
    Variable top=V_max,length=min(18,max(6,(V_max-V_min)*0.025))
    SetDrawLayer/W=$win UserFront
    SetDrawEnv/W=$win gstart,gname=XRDReferenceArrow
    SetDrawEnv/W=$win push
    SetDrawEnv/W=$win xcoord=prel,ycoord=prel,clipRect=(0,0,1,1),save
    SetDrawEnv/W=$win xcoord=bottom,ycoord=left,linefgc=(55000,0,0),linethick=2,dash=0,arrow=1,arrowlen=7
    for(i=0;i<total;i+=1)
        if(compare)
            data=StringFromList(i,list)
            offset=(total-1-i)*135
        endif
        x=rx[row]+XRD_ReferenceShift(data,ref)
        DrawLine/W=$win x,min(top-2,offset+height+length),x,offset+height
        if(cmpstr(data,path)==0)
            SetWindow $win userdata(XRDReferenceAngle)=XRD_ExactNumber(x)
        endif
    endfor
    SetDrawEnv/W=$win pop
    SetDrawEnv/W=$win gstop
    String text="選択参照 "+XRD_HKL(hh[row],kk[row],ll[row])+"  "+num2str(rx[row]+XRD_ReferenceShift(path,ref))+"°"
    TextBox/W=$win/C/N=ReferenceSelected/F=0/B=1/A=RT/X=1/Y=9 "\\Z11"+text
    return 0
End

Function XRD_OpenReview()
    if(!strlen(XRD_Data()))
        return -1
    endif
    XRD_UISettings()
    if(WinType("XRDReviewGraph") && cmpstr(GetUserData("XRDReviewGraph","","XRDProject"),XRD_Project())!=0)
        DoWindow/K XRDReviewGraph
    endif
    Variable/G root:Packages:XRDWorkbench:UI:liveBusy=1
    Variable result=0
    try
        result=XRD_DrawLiveStack("XRDReviewGraph",0)
    catch
        result=-GetRTError(1)
    endtry
    Variable/G root:Packages:XRDWorkbench:UI:liveBusy=0
    if(result<0)
        return result
    endif
    ControlBar/W=XRDReviewGraph 34
    Button reviewRefresh,win=XRDReviewGraph,pos={8,5},size={125,24},title="今すぐ更新",proc=XRD_V70Button
    Button reviewZoom,win=XRDReviewGraph,pos={140,5},size={155,24},title="選択ピークの±5°",proc=XRD_V70Button
    Button reviewAll,win=XRDReviewGraph,pos={302,5},size={110,24},title="全範囲",proc=XRD_V70Button
    TitleBox reviewHelp,win=XRDReviewGraph,pos={425,8},frame=0,title="ライブ更新：同定・候補・試料切替を自動反映"
    return result
End

Function XRD_RequestLive()
    String base="root:Packages:XRDWorkbench:UI:"
    if(!DataFolderExists("root:Packages:XRDWorkbench:UI") || NumVarOrDefault(base+"liveBusy",0) || NumVarOrDefault(base+"livePending",0))
        return 0
    endif
    Variable main=WinType("XRDWorkbench#Pattern") && cmpstr(GetUserData("XRDWorkbench#Pattern","","XRDCompare"),"1")==0
    Variable review=WinType("XRDReviewGraph") && cmpstr(GetUserData("XRDReviewGraph","","XRDProject"),XRD_Project())==0
    Variable side=WinType("XRDWorkbench#SideCompare")!=0
    if(!main && !review && !side)
        return 0
    endif
    Variable/G $(base+"livePending")=1
    Execute/P/Q "XRD_LiveDeferred()"
    return 1
End

Function XRD_LiveDeferred()
    String base="root:Packages:XRDWorkbench:UI:",path=XRD_Data()
    if(!NumVarOrDefault(base+"livePending",0) || NumVarOrDefault(base+"liveBusy",0))
        return 0
    endif
    Variable/G $(base+"liveBusy")=1
    Variable error=0
    try
        XRD_UpdateSideCompare()
        if(strlen(path) && WinType("XRDWorkbench#Pattern") && NumVarOrDefault(XRD_Project()+":activeStep",1)==3 && NumVarOrDefault(XRD_Project()+":liveCompare",0))
            XRD_CapturePanelState(1)
            String previousActive=StrVarOrDefault(path+":uiActiveChild","XRDWorkbench")
            XRD_DrawLiveStack("XRDWorkbench#Pattern",1)
            XRD_RestorePanelCursors(path)
            if(WinType(previousActive))
                SetActiveSubwindow $previousActive
            endif
        endif
        if(strlen(path) && WinType("XRDReviewGraph") && cmpstr(GetUserData("XRDReviewGraph","","XRDProject"),XRD_Project())==0)
            XRD_DrawLiveStack("XRDReviewGraph",0)
        endif
    catch
        error=GetRTError(1)
    endtry
    Variable/G $(base+"liveLastError")=error
    Variable/G $(base+"liveRunCount")=NumVarOrDefault(base+"liveRunCount",0)+1
    Variable/G $(base+"livePending")=0
    Variable/G $(base+"liveBusy")=0
    if(error)
        Print "ライブ比較を更新できませんでした。画面を開き直してください。エラー="+num2istr(error)
    endif
    return error
End
