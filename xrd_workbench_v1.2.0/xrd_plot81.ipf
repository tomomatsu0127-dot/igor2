#pragma rtGlobals=3
// v1.2.0: folder selection, drag ordering and live figure settings.
Function XRD81_PlotWorkspaceHook(s)
    STRUCT WMWinHookStruct &s
    if(s.eventCode==0)
        Variable/G $(XRD_PlotRoot()+":UI:livePending81")=0
    endif
    return 0
End

Function XRD81_PlotButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    strswitch(ba.ctrlName)
        case "sources":
            XRD81_PlotSources()
            break
        case "markerSettings":
            XRD_StylePanel()
            break
        case "legendSettings":
            XRD_LegendOrderPanel()
            break
        case "sourcesApply":
            XRD81_ApplySources()
            break
    endswitch
    return 0
End

Function XRD81_PlotSources()
    String ui=XRD_PlotRoot()+":UI",base=XRD_PlotRoot()+":SourcePicker",projects=XRD_ProjectList(),project,names,path
    NewDataFolder/O $base
    Wave/T paths=$(ui+":paths")
    Wave chosen=$(ui+":flags")
    Variable i,j,k,n=0,index
    for(i=0;i<ItemsInList(projects);i+=1)
        project=XRD100_ProjectAt(projects,i)
        n+=1+ItemsInList(XRD_MeasurementOrderList(project))
    endfor
    Make/O/T/N=(n,3) $(base+":table")
    Make/O/T/N=(n) $(base+":paths")
    Make/O/B/U/N=(n,3) $(base+":flags")=0
    Wave/T table=$(base+":table"),map=$(base+":paths")
    Wave flags=$(base+":flags")
    n=0
    for(i=0;i<ItemsInList(projects);i+=1)
        project=XRD100_ProjectAt(projects,i)
        table[n][1]="▾ "+XRD_ProjectDisplayName(project)
        map[n]="";n+=1
        names=XRD_MeasurementOrderList(project)
        for(j=0;j<ItemsInList(names);j+=1)
            path=project+":Measurements:"+StringFromList(j,names)
            table[n][1]="     "+StrVarOrDefault(path+":displayName","")
            XRD_UpdateAnalysisState(path)
            table[n][2]=StrVarOrDefault(path+":analysisState","")
            map[n]=path
            if(XRD_IsAnalysisComplete(path))
                flags[n][0]=32
                for(k=0;k<numpnts(paths);k+=1)
                    if(cmpstr(paths[k],path)==0)
                        flags[n][0]=32+(chosen[k][0] & 16)
                    endif
                endfor
            else
                table[n][2]+="（選択不可）"
            endif
            n+=1
        endfor
    endfor
    SetDimLabel 1,0,'使用',table
    SetDimLabel 1,1,'プロジェクト / 測定データ',table
    SetDimLabel 1,2,'解析状態',table
    DoWindow/K XRDPlotSources
    NewPanel/N=XRDPlotSources/W=(50,50,830,630) as "作図する測定データ：プロジェクトフォルダ"
    DefaultGUIFont/W=XRDPlotSources all={"Segoe UI",12,0}
    TitleBox hint,pos={15,15},frame=0,title="プロジェクト内の完了試料をチェックしてください。\r未解析・解析中の試料は表示のみです。順番は作図ウィンドウでドラッグします。"
    ListBox folders,pos={15,75},size={745,425},listWave=table,selWave=flags,mode=1,widths={50,480,195}
    Button sourcesApply,pos={15,520},size={745,32},title="選んだ測定データを作図に使う",proc=XRD81_PlotButton
    return 0
End

Function XRD81_ApplySources()
    String ui=XRD_PlotRoot()+":UI",base=XRD_PlotRoot()+":SourcePicker"
    Wave/T map=$(base+":paths"),paths=$(ui+":paths")
    Wave flags=$(base+":flags"),chosen=$(ui+":flags")
    Variable i,j
    chosen[][0]=32
    for(i=0;i<numpnts(map);i+=1)
        if(strlen(map[i]) && (flags[i][0] & 16) && XRD_IsAnalysisComplete(map[i]))
            for(j=0;j<numpnts(paths);j+=1)
                if(cmpstr(paths[j],map[i])==0)
                    chosen[j][0]=48
                endif
            endfor
        endif
    endfor
    DoWindow/K XRDPlotSources
    XRD81_QueuePlotLive()
    return 0
End

Function XRD81_MovePlotRow(fromRow,toRow)
    Variable fromRow,toRow
    String ui=XRD_PlotRoot()+":UI"
    Wave/T paths=$(ui+":paths")
    if(min(fromRow,toRow)<0 || max(fromRow,toRow)>=numpnts(paths))
        return -1
    endif
    Variable/G $(ui+":row")=fromRow
    NVAR row=$(ui+":row")
    do
        if(row==toRow)
            break
        endif
        XRD_PlotMoveRow(SelectNumber(toRow>row,-1,1))
    while(1)
    XRD110_PlotTrees()
    return row
End

Function XRD81_PlotDrag(lba)
    STRUCT WMListboxAction &lba
    String win=lba.win,control=lba.ctrlName
    Variable fromRow=str2num(GetUserData(win,control,"XRDDrag81"))
    if(lba.eventCode==1 && lba.col>0)
        ListBox $control,win=$win,userdata(XRDDrag81)=num2istr(lba.row)
    elseif(lba.eventCode==4 && numtype(fromRow)==0 && fromRow!=lba.row)
        if(XRD81_MovePlotRow(fromRow,lba.row)>=0)
            ListBox $control,win=$win,userdata(XRDDrag81)=num2istr(lba.row)
        endif
    elseif(lba.eventCode==2 || lba.eventCode==-2)
        ListBox $control,win=$win,userdata(XRDDrag81)=""
        XRD81_QueuePlotLive()
    endif
    return 0
End

Function XRD81_PlotSetting(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva
    if(sva.eventCode>=1 && sva.eventCode<=3)
        if(cmpstr(sva.ctrlName,"draftLabel")==0 || cmpstr(sva.ctrlName,"lineWidth")==0)
            XRD81_StoreLineSettings()
        endif
        XRD81_QueuePlotLive()
    endif
    return 0
End

Function XRD81_PlotColor(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        XRD81_StoreLineSettings()
        XRD81_QueuePlotLive()
    endif
    return 0
End

Function XRD81_PlotOffset(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    if(cba.eventCode==2)
        XRD81_QueuePlotLive()
    endif
    return 0
End

Function XRD81_StoreLineSettings()
    String ui=XRD_PlotRoot()+":UI"
    Variable row=NumVarOrDefault(ui+":row",-1)
    Wave/T labels=$(ui+":labels")
    Wave style=$(ui+":lineStyle")
    if(row>=0 && row<numpnts(labels))
        labels[row]=StrVarOrDefault(ui+":draftLabel","")
        style[row][0]=NumVarOrDefault(ui+":lineWidth",1)
        ControlInfo/W=XRDPlotWorkspace color
        style[row][1]=V_red;style[row][2]=V_green;style[row][3]=V_blue
    endif
    return 0
End

Function XRD81_QueuePlotLive()
    String ui=XRD_PlotRoot()+":UI",recipe=StrVarOrDefault(ui+":recipe","")
    if(!strlen(recipe) || !WinType("XRDP_"+StrVarOrDefault(recipe+":plotUID","")) || NumVarOrDefault(ui+":livePending81",0))
        return 0
    endif
    Variable/G $(ui+":livePending81")=1
    String/G $(ui+":liveRecipe81")=recipe
    Execute/P/Q "XRD81_PlotLiveDeferred()"
    return 0
End

Function XRD81_PlotLiveDeferred()
    String ui=XRD_PlotRoot()+":UI",recipe=StrVarOrDefault(ui+":recipe","")
    Variable/G $(ui+":livePending81")=0
    if(cmpstr(recipe,StrVarOrDefault(ui+":liveRecipe81",""))!=0)
        return 0
    endif
    return XRD81_ApplyPlotLive(recipe)
End

Function XRD81_ApplyPlotLive(recipe)
    String recipe
    String ui=XRD_PlotRoot()+":UI",win="XRDP_"+StrVarOrDefault(recipe+":plotUID",""),key
    if(!DataFolderExists(recipe) || !WinType(win))
        return -1
    endif
    if(NumVarOrDefault(ui+":width",0)<200 || NumVarOrDefault(ui+":height",0)<150 || NumVarOrDefault(ui+":font",0)<12 || NumVarOrDefault(ui+":legendFont",0)<12 || NumVarOrDefault(ui+":spacing",0)<120 || NumVarOrDefault(ui+":yMin",0)>=100)
        return -1
    endif
    Variable xMin=NumVarOrDefault(ui+":xMin",20),xMax=NumVarOrDefault(ui+":xMax",70)
    if(numtype(xMin+xMax)!=0 || xMin>=xMax)
        return -1
    endif
    Wave/T paths=$(ui+":paths"),labels=$(ui+":labels"),savedUIDs=$(recipe+":sourceUIDs"),savedLabels=$(recipe+":sourceLabels")
    Wave flags=$(ui+":flags"),style=$(ui+":lineStyle"),savedStyle=$(recipe+":lineStyle")
    Variable i,j,n=numpnts(savedUIDs),spacing=NumVarOrDefault(ui+":spacing",135)*NumVarOrDefault(ui+":offsetMode",1),upper=140+max(0,n-1)*spacing
    String settings="spacing;offsetMode;width;height;font;legendFont;xMin;xMax;yMin;legendColumns;legendSeparate",folder,trace,uid,order=""
    Variable members=0,known=0
    for(i=0;i<numpnts(paths);i+=1)
        if(flags[i][0] & 16)
            members+=1;uid=XRD80_MeasurementUID(paths[i])
            for(j=0;j<n;j+=1)
                known+=(cmpstr(savedUIDs[j],uid)==0)
            endfor
        endif
    endfor
    if(members==0)
        return -1
    endif
    if(members!=n || known!=n)
        // An explicit source selection refreshes its numeric snapshots.
        recipe=XRD_PlotSaveDraft(recipe)
        if(strlen(recipe))
            return XRD_PlotDrawRecipe(recipe,0)
        endif
        return -1
    endif
    // Source science stays frozen. Reorder its existing snapshots by stable UID.
    for(i=0;i<numpnts(paths);i+=1)
        uid=XRD80_MeasurementUID(paths[i])
        for(j=0;j<n;j+=1)
            if(cmpstr(savedUIDs[j],uid)==0)
                order+=num2istr(j)+";"
                savedLabels[j]=labels[i];savedStyle[j][]=style[i][q]
            endif
        endfor
    endfor
    if(ItemsInList(order)!=n)
        return -1
    endif
    PauseUpdate; Silent 1
    for(i=0;i<ItemsInList(settings);i+=1)
        key=StringFromList(i,settings)
        Variable/G $(recipe+":"+key)=NumVarOrDefault(ui+":"+key,0)
    endfor
    String/G $(recipe+":displayName")=StrVarOrDefault(ui+":title","")
    DoWindow/T $win StrVarOrDefault(recipe+":displayName","")
    String traces=TraceNameList(win,";",1),refTrace
    Variable index,offset
    for(i=0;i<n;i+=1)
        index=str2num(StringFromList(i,order));offset=(n-1-i)*spacing
        folder=recipe+":Snapshot:Sample"+num2istr(index+1)
        Wave raw=$(folder+":intensity"),displayY=$(folder+":displayIntensity")
        displayY=raw[p]+offset
        trace="Measurement"+num2istr(index+1)
        ModifyGraph/W=$win lsize($trace)=savedStyle[index][0],rgb($trace)=(savedStyle[index][1],savedStyle[index][2],savedStyle[index][3])
        for(j=0;j<ItemsInList(traces);j+=1)
            refTrace=StringFromList(j,traces)
            if(StringMatch(refTrace,"MS"+num2istr(index+1)+"R*"))
                RemoveFromGraph/W=$win $refTrace
            endif
        endfor
        XRD_PlotSnapshotPhases(win,recipe,index,offset)
        TextBox/W=$win/C/N=$("Condition"+num2istr(index+1))/F=0/B=1/A=RT/X=2/Y=(100*(upper-offset-90)/(upper-NumVarOrDefault(recipe+":yMin",-30))) "\\Z16"+savedLabels[index]
    endfor
    // Save visual order separately so reopen does not reorder/copy raw snapshots.
    String/G $(recipe+":visualOrder81")=order
    ModifyGraph/W=$win gfSize=NumVarOrDefault(recipe+":font",24),width=NumVarOrDefault(recipe+":width",340),height=NumVarOrDefault(recipe+":height",360)
    SetAxis/W=$win bottom xMin,xMax
    SetAxis/W=$win left NumVarOrDefault(recipe+":yMin",-30),upper
    SetWindow $win userdata(XRDFigureLegendFont)=num2str(NumVarOrDefault(recipe+":legendFont",24))
    XRD_PlotLegend(win)
    XRD_EnableFigureResize(win)
    XRD_PlotCaptureNative(recipe)
    return 0
End

Function/S XRD81_AllUsedStyles()
    XRD_UISettings()
    Variable old=NumVarOrDefault("root:Packages:XRDWorkbench:UI:styleUsedOnly81",1)
    Variable/G root:Packages:XRDWorkbench:UI:styleUsedOnly81=1
    String out=XRD81_StyleTargets()
    Variable/G root:Packages:XRDWorkbench:UI:styleUsedOnly81=old
    return out
End

Function XRD81_RefreshLegendOrder()
    String wins=WinList("XRDP_*",";","WIN:1"),win
    Variable i
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(XRD_IsManagedLegend(win))
            XRD_PlotLegend(win)
            XRD_PlotCaptureNative(GetUserData(win,"","XRDPlotRecipe"))
        endif
    endfor
    return 0
End
