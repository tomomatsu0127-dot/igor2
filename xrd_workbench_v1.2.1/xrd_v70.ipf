#pragma rtGlobals=3
// XRD Workbench v1.2.0: focused phase selection, ordered legends and review workflow.
Function/S XRD_OrderedKeys(project,keys)
    String project,keys
    String order=StrVarOrDefault(XRD80_Styles()+":legendOrder",""),out="",key
    Variable i
    for(i=0;i<ItemsInList(order);i+=1)
        key=StringFromList(i,order)
        if(WhichListItem(key,keys)>=0 && WhichListItem(key,out)<0)
            out+=key+";"
        endif
    endfor
    for(i=0;i<ItemsInList(keys);i+=1)
        key=StringFromList(i,keys)
        if(WhichListItem(key,out)<0)
            out+=key+";"
        endif
    endfor
    return out
End

Function XRD_SortLegendItems(project,keys,traces)
    String project
    String &keys,&traces
    String ordered=XRD_OrderedKeys(project,keys),out=""
    Variable i
    for(i=0;i<ItemsInList(ordered);i+=1)
        out+=StringFromList(WhichListItem(StringFromList(i,ordered),keys),traces)+";"
    endfor
    keys=ordered;traces=out
End

Function/S XRD_UsedStyleTargets()
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project),path,keys="",indices="",key
    Variable i,j,index
    for(i=0;i<ItemsInList(list);i+=1)
        path=project+":Measurements:"+StringFromList(i,list)
        Wave/Z refs=$(path+":Assignments:refIndex")
        if(!WaveExists(refs))
            continue
        endif
        for(j=0;j<numpnts(refs);j+=1)
            index=refs[j]
            if(index<1)
                continue
            endif
            XRD_StyleIndex(index)
            key=StrVarOrDefault(XRD_ReferencePath(index)+":styleGroup",XRD_PhaseLabel(index))
            if(WhichListItem(key,keys)<0)
                keys+=key+";";indices+=num2istr(index)+";"
            endif
        endfor
    endfor
    String wins=WinList("*",";","WIN:1"),win,traces,trace
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(cmpstr(GetUserData(win,"","XRDProject"),project)!=0)
            continue
        endif
        traces=TraceNameList(win,";",1)
        for(j=0;j<ItemsInList(traces);j+=1)
            trace=StringFromList(j,traces)
            index=str2num(GetUserData(win,"","Ref_"+trace))
            if(numtype(index)!=0 || index<1 || index>NumVarOrDefault(project+":referenceCount",0))
                continue
            endif
            XRD_StyleIndex(index)
            key=StrVarOrDefault(XRD_ReferencePath(index)+":styleGroup",XRD_PhaseLabel(index))
            if(WhichListItem(key,keys)<0)
                keys+=key+";";indices+=num2istr(index)+";"
            endif
        endfor
    endfor
    XRD_SortLegendItems(project,keys,indices)
    return indices
End

Function/S XRD_UsedStyleChoices()
    String targets=XRD81_AllUsedStyles(),out="",rp
    Variable i,index
    for(i=0;i<ItemsInList(targets);i+=1)
        index=str2num(StringFromList(i,targets));rp=XRD_ReferencePath(index)
        out+=StrVarOrDefault(rp+":styleGroup",XRD_PhaseLabel(index))+";"
    endfor
    return out
End

Function XRD_LegendOrderPanel()
    XRD_UISettings()
    String targets=XRD81_AllUsedStyles(),base="root:Packages:XRDWorkbench:UI:"
    if(!ItemsInList(targets))
        DoAlert 0,"同定に使った相がまだありません。先にピークを同定してください。"
        return -1
    endif
    String/G $(base+"legendDraft")=XRD_UsedStyleChoices()
    Variable/G $(base+"legendRow")=0
    DoWindow/K XRDLegendOrder
    NewPanel/N=XRDLegendOrder/W=(50,50,610,475) as "使用中の相：凡例の順番"
    DefaultGUIFont/W=XRDLegendOrder all={"Segoe UI",12,0}
    SetWindow XRDLegendOrder userdata(XRDProject)=XRD_Project()
    TitleBox note,pos={15,15},frame=0,title="上から順に、凡例の左から右へ並びます。\r同じ共通グループは1項目として扱います。"
    Make/O/T/N=(0,1) $(base+"legendTable")
    ListBox legendList,pos={15,70},size={380,245},mode=1,listWave=$(base+"legendTable"),widths={350},proc=XRD_LegendSelection
    Button legendUp,pos={410,90},size={110,30},title="上へ",proc=XRD_V70Button
    Button legendDown,pos={410,135},size={110,30},title="下へ",proc=XRD_V70Button
    Button legendApply,pos={15,335},size={505,30},title="この順番を保存し、未編集の凡例へ反映",proc=XRD_V70Button
    TitleBox keep,pos={15,380},frame=0,title="Igorで手編集した凡例は保護します。\r新しく作る図は、この順番になります。"
    XRD_LegendDraftTable()
    return 0
End

Function XRD_LegendDraftTable()
    String base="root:Packages:XRDWorkbench:UI:"
    SVAR draft=$(base+"legendDraft")
    Wave/T table=$(base+"legendTable")
    Redimension/N=(ItemsInList(draft),1) table
    table[][0]=StringFromList(p,draft)
    SetDimLabel 1,0,'凡例の順番',table
    NVAR row=$(base+"legendRow")
    ListBox legendList,win=XRDLegendOrder,selRow=row
End

Function XRD_LegendSelection(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode==4 && lba.row>=0)
        Variable/G root:Packages:XRDWorkbench:UI:legendRow=lba.row
    endif
    return 0
End

Function XRD_MoveLegend(direction)
    Variable direction
    SVAR draft=root:Packages:XRDWorkbench:UI:legendDraft
    NVAR row=root:Packages:XRDWorkbench:UI:legendRow
    Variable target=row+direction,i
    if(target<0 || target>=ItemsInList(draft))
        return -1
    endif
    String out="",a=StringFromList(row,draft),b=StringFromList(target,draft)
    for(i=0;i<ItemsInList(draft);i+=1)
        out+=SelectString(i==row,SelectString(i==target,StringFromList(i,draft),a),b)+";"
    endfor
    draft=out;row=target
    XRD_LegendDraftTable()
    XRD_ApplyLegendOrder()
    return 0
End

Function XRD_ApplyLegendOrder()
    String project=XRD_Project(),wins=XRD_FigureList(),win
    if(WinType("XRDReviewGraph"))
        wins+="XRDReviewGraph;"
    endif
    if(cmpstr(project,GetUserData("XRDLegendOrder","","XRDProject"))!=0)
        return -1
    endif
    String/G $(XRD80_Styles()+":legendOrder")=StrVarOrDefault("root:Packages:XRDWorkbench:UI:legendDraft","")
    Variable i,skipped=0
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(cmpstr(GetUserData(win,"","XRDProject"),project)!=0)
            continue
        endif
        if(XRD_IsManagedLegend(win))
            XRD_PhaseLegend(win)
        else
            skipped+=1
        endif
    endfor
    Print "凡例順を保存。手編集の凡例は保持: "+num2istr(skipped)+"図"
    XRD81_RefreshLegendOrder()
    return 0
End

Function XRD_MaterialAllowed(index)
    Variable index
    return XRD80_LibraryReferenceEnabled(index)
End
Function XRD_MaterialPanel()
    return XRD80_LibraryPanel()
End
Function XRD_MaterialHook(s)
    STRUCT WMWinHookStruct &s
    if(s.eventCode==6 && cmpstr(GetUserData("XRDMaterials","","XRDLayoutPending"),"1")!=0)
        SetWindow XRDMaterials userdata(XRDLayoutPending)="1"
        Execute/P/Q "XRD_MaterialLayout()"
    endif
    return 0
End

Function XRD_MaterialLayout()
    if(!WinType("XRDMaterials"))
        return 0
    endif
    SetWindow XRDMaterials userdata(XRDLayoutPending)="1"
    GetWindow XRDMaterials wsizeForControls
    Variable w=V_right,h=V_bottom,factor=PanelResolution("XRDMaterials")/ScreenResolution
    SetWindow XRDMaterials sizeLimit={600*factor,390*factor,inf,inf}
    ListBox materials,win=XRDMaterials,pos={15,100},size={w-30,max(110,h-210)}
    Button materialAll,win=XRDMaterials,pos={15,h-90},size={155,28}
    Button materialNone,win=XRDMaterials,pos={185,h-90},size={155,28}
    Button materialApply,win=XRDMaterials,pos={w-540,h-47},size={290,30}
    Button materialCancel,win=XRDMaterials,pos={w-240,h-47},size={225,30}
    SetWindow XRDMaterials userdata(XRDLayoutPending)="0"
    return 0
End

Function XRD_ApplyMaterials()
    // Kept for callers from earlier procedures; the library owns the only flag.
    return XRD80_LibraryPanel()
End
Function XRD_ReferenceShift(path,index)
    String path
    Variable index
    if(!NumVarOrDefault(XRD_Project()+":referenceShiftMode",0) || !strlen(path))
        return 0
    endif
    Wave mx=$(path+":Peaks:angle"),rx=$(XRD_ReferencePath(index)+":twoTheta"),ri=$(XRD_ReferencePath(index)+":intensity")
    Variable tol=NumVarOrDefault(XRD_Project()+":matchTolerance",0.2),limit=NumVarOrDefault(XRD_Project()+":maxCommonShift",0.3)
    Variable seeds=min(100,max(1,ceil(2*limit/max(tol/2,0.01)))),i,j,seed,shift,delta,best,score,bestScore=-1,result=0,n
    Duplicate/FREE ri,weights
    Make/FREE/D/N=(numpnts(rx)) order=p
    Sort/R weights,weights,order
    for(i=0;i<=seeds;i+=1)
        seed=SelectNumber(limit>0,0,-limit+2*limit*i/seeds)
        shift=XRD_RefineShift(path,index,seed)
        Make/FREE/B/U/N=(numpnts(mx)) used=0
        score=0;n=0
        for(j=0;j<numpnts(order);j+=1)
            best=XRD_FindMeasuredMatch(mx,used,rx[order[j]]+shift,tol,delta)
            if(best>=0)
                used[best]=1;n+=1
                score+=sqrt(max(0,ri[order[j]]))*(1-delta/tol)
            endif
        endfor
        if(n>=2 && (score>bestScore+1e-9 || (abs(score-bestScore)<1e-9 && abs(shift)<abs(result))))
            bestScore=score;result=shift
        endif
    endfor
    return result
End

Function XRD_ShiftModeAction(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        Variable/G $(XRD_Project()+":referenceShiftMode")=pa.popNum-1
        XRD_InvalidateFilterCandidates()
        Execute/P/Q "XRD_Panel()"
    endif
    return 0
End

Function XRD_ZoomSelectedPeak()
    String path=XRD_Data()
    if(!strlen(path) || !WinType("XRDWorkbench#Pattern"))
        return -1
    endif
    Wave angles=$(path+":Peaks:angle"),xx=$(path+":Raw:twoTheta")
    Variable row=NumVarOrDefault(path+":selectedPeakRow",-1)
    if(row<0 || row>=numpnts(angles))
        return -1
    endif
    Variable/G $(path+":followPeak")=1
    ControlUpdate/W=XRDWorkbench followPeak
    XRD_RecordPendingZoom(path)
    SetAxis/W=XRDWorkbench#Pattern bottom max(xx[0],angles[row]-5),min(xx[numpnts(xx)-1],angles[row]+5)
    XRD_RecordPendingZoom(path)
    XRD_CaptureView()
    XRD_RequestLive()
    return 0
End

Function XRD_V70Controls(project,path)
    String project,path
    Variable step=NumVarOrDefault(project+":activeStep",1)
    if(step==2)
        PopupMenu shiftMode,pos={16,345},title="参照角度",mode=(NumVarOrDefault(project+":referenceShiftMode",0)+1),value="元の値;全体から共通シフト",proc=XRD_ShiftModeAction
    elseif(step==3 && strlen(path))
        Button zoomPeak,pos={16,257},size={85,24},title="選択±5°",proc=XRD_V70Button
        Button resetZoom,pos={106,257},size={85,24},title="全範囲"
        Button reviewSamples,pos={16,310},size={175,22},title="他試料の同定と見比べる",proc=XRD_V70Button
        Button deletePeak2,pos={16,336},size={175,20}
        Button details,pos={16,360}
        Variable details=NumVarOrDefault(project+":detailControls",0),i
        String controls="matchTolerance;maxShift;previewMin;opacity;lineWidth;candidateRadius"
        for(i=0;i<6;i+=1)
            ModifyControl $(StringFromList(i,controls)),pos={16,397+i*16}
        endfor
        PopupMenu shiftMode,pos={16,112},title="角度",mode=(NumVarOrDefault(project+":referenceShiftMode",0)+1),value="元の値;全体シフト",proc=XRD_ShiftModeAction
        PopupMenu candidateMode,pos={16,379},disable=SelectNumber(details,1,0)
    elseif(step==1 && strlen(path))
        Button externalPeaks,pos={16,375},size={175,24},title="外部ピークリストを追加",proc=XRD_V70Button
        TitleBox rawNote,pos={16,402},title="検出設定 → 候補確認 → 登録。\r外部ピークも同定に使えます。"
        Button deleteData,pos={16,437},size={83,24}
        Button restoreData,pos={104,437},size={87,24}
    elseif(step==5)
        Button stackGraph,pos={16,238},size={175,18}
        Button editGraph2,pos={16,260},size={175,18}
        Button moveUp,pos={16,282},size={81,18}
        Button moveDown,pos={104,282},size={81,18}
        Button referenceStyle,pos={16,306},size={175,18}
        Button comparison,pos={16,330},size={175,18}
        Button report,pos={16,354},size={175,18}
        Button deleteData,pos={16,378},size={175,18}
        Button legendOrder,pos={16,402},size={175,18},title="凡例の順番を並べ替える",proc=XRD_V70Button
        Button figureSettings,pos={16,426},size={175,18}
        Button restoreData,pos={16,450},size={175,18}
    endif
End

Function XRD_OpenReviewLegacy()
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project),path=XRD_Data(),win,rootPath=project+":ReviewGraph"
    if(!strlen(path))
        return -1
    endif
    Variable savedMin=NaN,savedMax=NaN
    if(WinType("XRDReviewGraph") && cmpstr(GetUserData("XRDReviewGraph","","XRDProject"),project)==0)
        GetAxis/W=XRDReviewGraph/Q bottom
        savedMin=V_min;savedMax=V_max
    endif
    DoWindow/K XRDReviewGraph
    NewDataFolder/O $rootPath
    Variable i,n=0,offset,total=ItemsInList(list),upper=100+max(0,total-1)*135+40
    for(i=0;i<total;i+=1)
        String data=project+":Measurements:"+StringFromList(i,list),trace="Sample"+num2istr(i+1)
        Wave xx=$(data+":Raw:twoTheta"),yy=$(data+":Processed:intensity")
        Duplicate/O xx,$(rootPath+":angle"+num2istr(i))
        Duplicate/O yy,$(rootPath+":intensity"+num2istr(i))
        Wave gx=$(rootPath+":angle"+num2istr(i)),gy=$(rootPath+":intensity"+num2istr(i))
        offset=(total-1-i)*135;gy=yy[p]+offset
        if(n==0)
            Display/N=XRDReviewGraph/W=(60,60,850,700) gy/TN=$trace vs gx as "同定中の試料比較（確認用）"
            SetWindow XRDReviewGraph userdata(XRDGraphData)=rootPath
            SetWindow XRDReviewGraph userdata(XRDReview)="1"
        else
            AppendToGraph/W=XRDReviewGraph gy/TN=$trace vs gx
        endif
        ModifyGraph/W=XRDReviewGraph rgb($trace)=(0,0,0),lsize($trace)=SelectNumber(cmpstr(data,path)==0,1,2)
        XRD_AddPhaseTraces("XRDReviewGraph",data,offset)
        String label=SelectString(cmpstr(data,path)==0,"","▶ 編集中  ")+StrVarOrDefault(data+":displayName","")
        TextBox/W=XRDReviewGraph/C/N=$("SampleLabel"+num2istr(i))/F=0/B=1/A=RT/X=2/Y=(100*(upper-offset-95)/(upper+30)) "\\Z12"+label
        n+=1
    endfor
    XRD_GraphStyle("XRDReviewGraph",upper,0)
    ModifyGraph/W=XRDReviewGraph width=0,height=0,margin(top)=55,margin(left)=65,margin(bottom)=55,gfSize=14
    SetWindow XRDReviewGraph userdata(XRDFlexible)="1"
    SetWindow XRDReviewGraph userdata(XRDFigureLegendFont)="14"
    XRD_PhaseLegend("XRDReviewGraph")
    ControlBar/W=XRDReviewGraph 34
    Button reviewRefresh,win=XRDReviewGraph,pos={8,5},size={145,24},title="同定結果を更新",proc=XRD_V70Button
    Button reviewZoom,win=XRDReviewGraph,pos={160,5},size={180,24},title="選択ピークの±5°",proc=XRD_V70Button
    Button reviewAll,win=XRDReviewGraph,pos={348,5},size={135,24},title="全範囲",proc=XRD_V70Button
    TitleBox reviewHelp,win=XRDReviewGraph,pos={495,8},frame=0,title="同定はWorkbenchで1試料ずつ行います"
    XRD_ReviewGuide(0)
    if(numtype(savedMin+savedMax)==0 && savedMin<savedMax)
        SetAxis/W=XRDReviewGraph bottom savedMin,savedMax
    endif
    return 0
End

Function XRD_ShiftNotice(path)
    String path
    if(!WinType("XRDWorkbench#Pattern") || cmpstr(GetUserData("XRDWorkbench","","XRDData"),path)!=0)
        return 0
    endif
    if(NumVarOrDefault(XRD_Project()+":activeStep",1)==1)
        TextBox/W=XRDWorkbench#Pattern/K/N=ShiftInfo
        return 0
    endif
    Variable index=NumVarOrDefault(path+":Preview:referenceIndex",0),shift=NumVarOrDefault(path+":Preview:shift",0)
    if(index<=0)
        TextBox/W=XRDWorkbench#Pattern/K/N=ShiftInfo
        return 0
    endif
    String text="参照棒: "+XRD_PhaseLabel(index)+SelectString(NumVarOrDefault(XRD_Project()+":referenceShiftMode",0)," / 元の角度"," / 全体シフト")+" / Δ2θ="+num2str(shift)+"°"
    TextBox/W=XRDWorkbench#Pattern/C/N=ShiftInfo/F=0/B=1/A=RT/X=1/Y=2 "\\Z10"+text
End

Function XRD_ReviewGuideLegacy(local)
    Variable local
    String path=XRD_Data()
    Wave angles=$(path+":Peaks:angle"),xx=$(path+":Raw:twoTheta")
    Variable row=NumVarOrDefault(path+":selectedPeakRow",-1),x=NaN
    if(row>=0 && row<numpnts(angles))
        x=angles[row]
    endif
    SetDrawLayer/W=XRDReviewGraph/K UserFront
    if(numtype(x)==0)
        SetDrawEnv/W=XRDReviewGraph xcoord=bottom,ycoord=prel,dash=3,linefgc=(0,0,0)
        DrawLine/W=XRDReviewGraph x,0,x,1
    endif
    if(local && numtype(x)==0)
        SetAxis/W=XRDReviewGraph bottom max(xx[0],x-5),min(xx[numpnts(xx)-1],x+5)
    else
        SetAxis/W=XRDReviewGraph bottom xx[0],xx[numpnts(xx)-1]
    endif
End

Function XRD_V70Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    strswitch(ba.ctrlName)
        case "legendOrder":
            Execute/P/Q "XRD_LegendOrderPanel()"
            break
        case "legendUp":
        case "legendDown":
            if(cmpstr(GetUserData("XRDLegendOrder","","XRDProject"),XRD_Project())==0)
                XRD_MoveLegend(SelectNumber(cmpstr(ba.ctrlName,"legendUp")==0,1,-1))
            endif
            break
        case "legendApply":
            XRD_ApplyLegendOrder()
            break
        case "typeCards":
            Execute/P/Q "XRD_MaterialPanel()"
            break
        case "materialAll":
        case "materialNone":
            Wave selection=root:Packages:XRDWorkbench:UI:MaterialDraft:selection
            selection[][0]=32+16*(cmpstr(ba.ctrlName,"materialAll")==0)
            break
        case "materialApply":
            if(XRD_ApplyMaterials()==0)
                DoWindow/K XRDMaterials
                Execute/P/Q "XRD_Panel()"
            endif
            break
        case "materialCancel":
            DoWindow/K XRDMaterials
            break
        case "zoomPeak":
            XRD_ZoomSelectedPeak()
            break
        case "reviewSamples":
        case "reviewRefresh":
            Execute/P/Q "XRD_OpenReview()"
            break
        case "reviewZoom":
            XRD_ReviewGuide(1)
            break
        case "reviewAll":
            XRD_ReviewGuide(0)
            break
        case "externalPeaks":
            Execute/P/Q "XRD_ExternalPeakDialog()"
            break
    endswitch
    return 0
End
