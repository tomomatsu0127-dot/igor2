#pragma rtGlobals=3
// XRD Workbench v1.2.0: normalized display and project-wide native symbols.
Function XRD_CloseEditors()
    DoWindow/K XRDElements
    DoWindow/K XRDStyles
    DoWindow/K XRDLatticePanel
    DoWindow/K XRDLatticeInput
    DoWindow/K XRDPeakPicker
    DoWindow/K XRDProfilePanel
    DoWindow/K XRDProfileGraph
    DoWindow/K XRDAudit
    DoWindow/K XRDEvidence
    DoWindow/K XRDReferenceEditor
    DoWindow/K XRDMetadata
    DoWindow/K XRDTypeCards
    DoWindow/K XRDDetectionSettings
    DoWindow/K XRDDetectionPreview
    DoWindow/K XRDMaterials
    DoWindow/K XRDLegendOrder
End

Function XRD_V3Settings(project)
    String project
    XRD_EnsureNumeric(project+":previewOpacity",85)
    XRD_EnsureNumeric(project+":previewWidth",1.5)
    XRD_EnsureNumeric(project+":selectedReference",0)
    XRD_EnsureNumeric(project+":tablesOnly",0)
    XRD_EnsureNumeric(project+":wavelength",1.5406)
    XRD_EnsureNumeric(project+":elementFilterMode",0)
    NVAR filterMode=$(project+":elementFilterMode")
    XRD_V4Settings(project)
    XRD_TypeSettings(project)
    NewDataFolder/O $(project+":Styles")
    XRD80_MigrateStyles(project)
    Wave/T/Z keys=$(XRD80_Styles()+":keys")
    if(!WaveExists(keys))
        Make/T/N=0 $(XRD80_Styles()+":keys")
        Make/D/N=(0,4) $(XRD80_Styles()+":values")
    endif
End

Function XRD_NormalizeMeasurement(path)
    String path
    Wave raw=$(path+":Raw:intensity"),out=$(path+":Processed:intensity")
    WaveStats/Q raw
    Variable lo=V_min,span=V_max-V_min
    out=0
    if(span>0)
        out=100*(raw[p]-lo)/span
    endif
    SetScale d,0,0,"",out
    String/G $(path+":displayNormalization")="100*(raw-min(raw))/(max(raw)-min(raw)); constant data -> 0"
    Wave py=$(path+":Peaks:height"),indices=$(path+":Peaks:pointIndex")
    py=out[indices[p]]
End

Function XRD_UnassignedPlot(path)
    String path
    Wave px=$(path+":Peaks:angle"),py=$(path+":Peaks:height"),ids=$(path+":Peaks:peakID")
    Wave aid=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex")
    Make/O/D/N=(numpnts(px)) $(path+":Preview:unassignedX"),$(path+":Preview:unassignedY")
    Wave xx=$(path+":Preview:unassignedX"),yy=$(path+":Preview:unassignedY")
    Variable i,j,n=0,assigned
    for(i=0;i<numpnts(px);i+=1)
        assigned=0
        for(j=0;j<numpnts(aid);j+=1)
            if(aid[j]==ids[i] && refs[j]>0)
                assigned=1
                break
            endif
        endfor
        if(!assigned)
            xx[n]=px[i]
            yy[n]=py[i]
            n+=1
        endif
    endfor
    Redimension/N=(n) xx,yy
End

Function XRD_StyleIndex(refIndex)
    Variable refIndex
    String project=XRD_Project(),rp=XRD_ReferencePath(refIndex),key,legacyKey=""
    XRD_V3Settings(project)
    SVAR phase=$(rp+":phaseClass"),card=$(rp+":cardNumber")
    key=XRD_PhaseLabel(refIndex)
    if(strlen(key)==0)
        key=card
    endif
    SVAR/Z custom=$(rp+":styleGroup")
    if(SVAR_Exists(custom))
        if(cmpstr(custom,card)==0 || cmpstr(custom,XRD_FormulaLabel(StrVarOrDefault(rp+":formula","")))==0)
            legacyKey=custom
            custom=key
        else
            key=custom
        endif
    else
        String/G $(rp+":styleGroup")=key
    endif
    Wave/T keys=$(XRD80_Styles()+":keys")
    Wave vals=$(XRD80_Styles()+":values")
    XRD_RepairAutoStyles(project)
    Variable i,n=numpnts(keys)
    for(i=0;i<n;i+=1)
        if(cmpstr(keys[i],key)==0)
            return i
        endif
    endfor
    Wave/T owners=$(XRD80_Styles()+":owners")
    Redimension/N=(n+1) keys,owners
    owners[n]=project
    Redimension/N=(n+1,4) vals
    keys[n]=key
    Variable red,green,blue
    XRD_PhaseColor(n+1,red,green,blue)
    vals[n][0]=XRD_FilledSymbol(n)
    vals[n][1]=red
    vals[n][2]=green
    vals[n][3]=blue
    vals[n][1,3]*=0.75
    if(cmpstr(key,"M-type")==0)
        vals[n][0]=19
        vals[n][1]=0;vals[n][2]=0;vals[n][3]=50000
    elseif(cmpstr(key,"Z-type")==0)
        vals[n][0]=23
        vals[n][1]=55000;vals[n][2]=0;vals[n][3]=0
    endif
    // Preserve a saved v0.3 card-specific symbol/color when grouping by formula.
    for(i=0;i<n;i+=1)
        if(strlen(legacyKey)>0 && cmpstr(keys[i],legacyKey)==0)
            vals[n][]=vals[i][q]
            break
        endif
    endfor
    return n
End

Function XRD_ApplyPhaseStyle(win,trace,refIndex)
    String win,trace
    Variable refIndex
    Variable row=XRD_StyleIndex(refIndex)
    Wave vals=$(XRD80_Styles()+":values")
    ModifyGraph/W=$win mode($trace)=3,marker($trace)=vals[row][0],msize($trace)=XRD81_MarkerSize(row)
    ModifyGraph/W=$win rgb($trace)=(vals[row][1],vals[row][2],vals[row][3])
End

Function XRD_RefreshStyles()
    String palette=XRD80_Styles()
    Variable/G $(palette+":revision")=NumVarOrDefault(palette+":revision",0)+1
    String project=XRD_Project(),wins=WinList("*",";","WIN:1"),win,traces,trace,rp
    Variable i,j,refIndex
    if(WinType("XRDWorkbench"))
        wins+="XRDWorkbench#Pattern;"
    endif
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(!strlen(GetUserData(win,"","XRDProject")) && !strlen(GetUserData(win,"","XRDPlotUID")))
            continue
        endif
        traces=TraceNameList(win,";",1)
        for(j=0;j<ItemsInList(traces);j+=1)
            trace=StringFromList(j,traces)
            refIndex=str2num(GetUserData(win,"","Ref_"+trace))
            if(numtype(refIndex)==0 && refIndex>0)
                XRD_ApplyPhaseStyle(win,trace,refIndex)
            endif
        endfor
        // Native legend symbols follow trace style automatically. Do not
        // rebuild text/layout here and overwrite the user's manual formatting.
    endfor
    XRD_PlotRefreshStyles()
End

Function XRD_GraphStyle(win,upper,publication)
    String win
    Variable upper,publication
    ModifyGraph/W=$win tickUnit(bottom)=1,tickUnit(left)=1
    ModifyGraph/W=$win gFont="Times New Roman",gfSize=12,tick(left)=3,tick(bottom)=2,mirror=1,noLabel(left)=1,standoff=0
    Label/W=$win left "Intensity (arb. units)"
    Label/W=$win bottom "2\\f02θ\\f00 (deg.)    "+XRD_RadiationLabel(win)
    if(publication)
        SetWindow $win userdata(XRDFigureWidth)="340.157"
        SetWindow $win userdata(XRDFigureHeight)="255.118"
        ModifyGraph/W=$win gfSize=24,width=340.157,height=255.118,margin(left)=78,margin(bottom)=78,margin(right)=28,lblMargin(left)=15,lblMargin(bottom)=12,lblLatPos(bottom)=0
        SetAxis/W=$win bottom 20,70
    endif
    SetAxis/W=$win left -30,upper
End

Function XRD_AddPhaseTraces(win,path,offset)
    String win,path
    Variable offset
    String project=XRD_Project(),trace,rootPath=path+":Stack",rp,graphRoot=GetUserData(win,"","XRDGraphData")
    NVAR count=$(project+":referenceCount")
    NewDataFolder/O $rootPath
    XRD_BuildStackPhaseWaves(path,offset,1)
    Variable i
    for(i=1;i<=count;i+=1)
        Wave xx=$(rootPath+":Ref"+num2istr(i)+"_X"),yy=$(rootPath+":Ref"+num2istr(i)+"_Y")
        if(numpnts(xx)==0)
            continue
        endif
        trace="Phase"+num2istr(i)
        // Unique names allow several measurements in the same native graph.
        trace=CleanupName(ParseFilePath(0,path,":",1,0)+"_"+trace,0)
        if(strlen(graphRoot)>0)
            Duplicate/O xx,$(graphRoot+":"+trace+"X")
            Duplicate/O yy,$(graphRoot+":"+trace+"Y")
            Wave gx=$(graphRoot+":"+trace+"X"),gy=$(graphRoot+":"+trace+"Y")
            AppendToGraph/W=$win gy/TN=$trace vs gx
        else
            AppendToGraph/W=$win yy/TN=$trace vs xx
        endif
        SetWindow $win userdata($("Ref_"+trace))=num2istr(i)
        XRD_ApplyPhaseStyle(win,trace,i)
    endfor
    SetWindow $win userdata(XRDProject)=project
    if(strlen(graphRoot)>0)
        // The complete figure adds its legend after the axes are formatted.
    endif
    return 0
End

Function/S XRD_NewGraphData()
    String project=XRD_Project(),path
    XRD_EnsureNumeric(project+":graphSerial",0)
    NVAR serial=$(project+":graphSerial")
    NewDataFolder/O $(project+":Graphs")
    do
        serial+=1
        path=project+":Graphs:Graph"+num2istr(serial)
    while(DataFolderExists(path))
    NewDataFolder/O $path
    return path
End

Function XRD_TableLayout(project)
    String project
    return XRD_ResizePanel()
End

Function XRD_PanelHook(info)
    STRUCT WMWinHookStruct &info
    if(info.eventCode==8 && WinType("XRDWorkbench#Pattern"))
        XRD_ScheduleViewCheck()
    endif
    if(cmpstr(info.winName,"XRDWorkbench")==0)
        if(info.eventCode==0)
            SetWindow XRDWorkbench userdata(XRDAdoptPending)="0"
        endif
        if(info.eventCode==6)
            XRD_ScheduleResize()
        endif
    endif
    return XRD110_WheelHook(info)
End

Function XRD_PreviewSetting(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva
    if(sva.eventCode<1 || sva.eventCode>3)
        return 0
    endif
    if(strlen(XRD_Data())==0)
        return 0
    endif
    NVAR opacity=$(XRD_Project()+":previewOpacity"),lineWidth=$(XRD_Project()+":previewWidth")
    Variable alpha=65535*opacity/100
    ModifyGraph/W=XRDWorkbench#Pattern rgb(XRDWB_Preview)=(60000,0,0,alpha),lsize(XRDWB_Preview)=lineWidth
    return 0
End

Function XRD_ReferenceSelection(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode==4 || lba.eventCode==3)
        NVAR count=$(XRD_Project()+":referenceCount")
        if(lba.row<0 || lba.row>=count)
            return 0
        endif
        NVAR selected=$(XRD_Project()+":selectedReference")
        selected=lba.row
        String path=XRD_Data()
        if(strlen(path)>0)
            XRD_PreviewReference(path,selected+1,XRD_ReferenceShift(path,selected+1))
        endif
    endif
    return 0
End

Function XRD_StylePanel()
    XRD_UISettings()
    String project=XRD_Project(),rp
    NVAR selected=$(project+":selectedReference"),count=$(project+":referenceCount")
    if(selected<0 || selected>=count)
        return -1
    endif
    String targets=XRD81_StyleTargets(),choices=""
    if(!ItemsInList(targets))
        DoAlert 0,"まだ同定に使った相がありません。先にピークを同定してください。参照情報の編集は『参照情報・出典』から行えます。"
        return -1
    endif
    Variable index=selected+1,choice=WhichListItem(num2istr(index),targets)
    if(choice<0)
        choice=0;index=str2num(StringFromList(0,targets))
    endif
    Variable row=XRD_StyleIndex(index),ci
    for(ci=0;ci<ItemsInList(targets);ci+=1)
        choices+=XRD_PhaseLabel(str2num(StringFromList(ci,targets)))+";"
    endfor
    rp=XRD_ReferencePath(index)
    Variable/G root:Packages:XRDWorkbench:UI:markerSize81=XRD81_MarkerSize(row)
    Wave values=$(XRD80_Styles()+":values")
    DoWindow/K XRDElements
    DoWindow/K XRDStyles
    NewPanel/N=XRDStyles/W=(70,70,560,420) as "Experiment共通の相・色・記号"
    SetWindow XRDStyles userdata(XRDRef)=num2istr(index)
    SetWindow XRDStyles userdata(XRDProject)=project
    String/G root:Packages:XRDWorkbench:UI:styleChoices=choices
    SetWindow XRDStyles userdata(XRDTargetMap)=targets
    PopupMenu target,pos={15,15},title="設定する相",value=#"root:Packages:XRDWorkbench:UI:styleChoices",mode=(choice+1),proc=XRD_StyleTargetAction
    SetVariable name,pos={15,55},size={455,22},title="参照名",value=$(rp+":phaseName")
    String classes="自動;通常相;Z-type;X-type;M-type;QS-type;W-type;T-type;Y-type;U-type"
    String chosen=StrVarOrDefault(rp+":typeOverride","自動")
    PopupMenu family,pos={15,90},title="type分類",value="自動;通常相;Z-type;X-type;M-type;QS-type;W-type;T-type;Y-type;U-type",mode=max(1,WhichListItem(chosen,classes)+1),proc=XRD_StyleTypeAction
    SetVariable group,pos={15,128},size={455,22},title="共通グループ",value=$(rp+":styleGroup")
    TitleBox note,pos={15,162},frame=0,title="同じグループは全試料・全グラフで色と記号を共有します。"
    PopupMenu symbol,pos={15,195},title="Igor標準記号",value="*MARKERPOP*",mode=values[row][0]+1,proc=XRD81_StylePopup
    PopupMenu color,pos={260,195},title="色",value="*COLORPOP*",popColor=(values[row][1],values[row][2],values[row][3]),proc=XRD81_StylePopup
    CheckBox usedOnly,pos={15,228},title="同定に使った相だけを表示",variable=root:Packages:XRDWorkbench:UI:styleUsedOnly81,proc=XRD81_StyleFilter
    SetVariable markerSize,pos={270,228},size={200,22},title="記号サイズ",limits={1,20,0.5},value=root:Packages:XRDWorkbench:UI:markerSize81,proc=XRD81_StyleSize
    Button apply,pos={15,263},size={455,28},title="Experiment内のグラフへ反映",proc=XRD_ApplyStyleButton
    Button legendOrder,pos={15,308},size={455,25},title="使用中の相の凡例順を並べ替える",proc=XRD_V70Button
    return 0
End

Function XRD_ApplyStyleButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(cmpstr(GetUserData("XRDStyles","","XRDProject"),XRD_Project())!=0)
        DoAlert 0,"設定を開いたプロジェクトへ戻るか、参照設定を開き直してください。"
        return -1
    endif
    Variable index=str2num(GetUserData("XRDStyles","","XRDRef")),row=XRD_StyleIndex(index)
    Wave values=$(XRD80_Styles()+":values")
    ControlInfo/W=XRDStyles symbol
    values[row][0]=V_Value-1
    ControlInfo/W=XRDStyles color
    values[row][1]=V_Red
    values[row][2]=V_Green
    values[row][3]=V_Blue
    XRD81_SetMarkerSize(row,NumVarOrDefault("root:Packages:XRDWorkbench:UI:markerSize81",3))
    XRD_RebuildReferenceTable(XRD_Project())
    XRD_RefreshStyles()
    XRD81_RefreshPeaks(XRD_Data(),rescore=0)
    DoWindow/F XRDStyles
    return 0
End

Function XRD_OpenPicker()
    String path=XRD_Data()
    if(strlen(path)==0)
        return -1
    endif
    Wave xx=$(path+":Raw:twoTheta"),yy=$(path+":Processed:intensity")
    DoWindow/K XRDPeakPicker
    DoWindow/K XRDProfilePanel
    DoWindow/K XRDProfileGraph
    DoWindow/K XRDAudit
    DoWindow/K XRDEvidence
    DoWindow/K XRDReferenceEditor
    DoWindow/K XRDMetadata
    DoWindow/K XRDTypeCards
    DoWindow/K XRDDetectionSettings
    DoWindow/K XRDDetectionPreview
    DoWindow/K XRDMaterials
    DoWindow/K XRDLegendOrder
    Display/N=XRDPeakPicker/W=(70,70,640,410) yy/TN=Measurement vs xx as "カーソルAをピークへ移動 → この位置を登録"
    ModifyGraph/W=XRDPeakPicker rgb(Measurement)=(0,0,0)
    XRD_GraphStyle("XRDPeakPicker",110,0)
    SetWindow XRDPeakPicker userdata(XRDData)=path
    ControlBar 30
    Button addCursor,win=XRDPeakPicker,pos={10,4},size={175,22},title="カーソルAの位置を登録",proc=XRD_PickerButton
    Cursor/P/W=XRDPeakPicker A Measurement 0
    ShowInfo/W=XRDPeakPicker
    return 0
End

Function XRD_PickerButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String path=GetUserData("XRDPeakPicker","","XRDData")
    Variable point=pcsr(A,"XRDPeakPicker")
    Wave xx=$(path+":Raw:twoTheta")
    if(numtype(point)!=0 || point<0 || point>=numpnts(xx))
        return -1
    endif
    XRD_AddPoint(path,point,"Manual")
    XRD_PeakTable(path)
    NVAR angle=$(path+":manualAngle")
    angle=xx[point]
    XRD_Panel()
    DoWindow/F XRDPeakPicker
    return 0
End

Function XRD_InvalidateFit(path)
    String path
    XRD80_AnalysisChanged(path,"同定・補正・ピーク変更")
    XRD80_MarkPlotsStale(path)
    XRD_MarkGraphsStale()
    XRD_InvalidateLatticeResults(path)
    XRD_RequestLive()
    SVAR/Z state=$(path+":Lattice:state")
    if(SVAR_Exists(state))
        state="同定変更あり：再計算してください"
    endif
End
