#pragma rtGlobals=3
// XRD Workbench v1.2.0: persistent left comparison beside single-sample identification.
Function XRD_V72Settings(project)
    String project
    // The comparison occupies its own pane; the main graph stays single-sample.
    if(NumVarOrDefault(project+":activeStep",1)==3)
        Variable/G $(project+":liveCompare")=0
    endif
    if(WinType("XRDMatchSettings"))
        if(cmpstr(GetUserData("XRDMatchSettings","","XRDData"),XRD_Data())!=0 || NumVarOrDefault(project+":activeStep",1)!=3)
            DoWindow/K XRDMatchSettings
        endif
    endif
End

Function XRD_V72Controls(project,path)
    String project,path
    if(NumVarOrDefault(project+":activeStep",1)!=3 || !strlen(path))
        return 0
    endif
    String remove="stepHelp;shiftMode;scoreCandidates;adoptCandidate;overlapCandidate;clearAssignment;evidence;tableView;followPeak;liveCompare;reviewSamples;deletePeak2;details;audit;candidateMode;matchTolerance;maxShift;previewMin;opacity;lineWidth;candidateRadius",name
    Variable i
    for(i=0;i<ItemsInList(remove);i+=1)
        name=StringFromList(i,remove)
        KillControl/W=XRDWorkbench $name
    endfor
    GroupBox workGroup,title="同定状況を比較（自動更新）"
    Button zoomPeak,pos={16,82},size={90,22},title="選択±5°",proc=XRD_V72Button
    Button resetZoom,pos={112,82},size={90,22},title="全範囲",proc=XRD_V72Button
    Button unknownPeak,pos={208,82},size={90,22},title="不明にする",proc=XRD_Button
    Button matchActions,pos={16,110},size={280,26},fSize=12,title="その他の操作… ▼",proc=XRD120_MatchMenu
    TitleBox sideHint,pos={16,68},frame=0,title="右の候補をダブルクリックして採用"
    TitleBox sideRange,pos={16,138},frame=0,title="他プロジェクトも選択可 ／ 右図と同じ範囲"
    XRD_DrawLiveStack("XRDWorkbench#SideCompare",2)
    XRD_TrimSideAnnotation()
    SetActiveSubwindow XRDWorkbench
    return 0
End

Function/S XRD_MatchActionChoices()
    return "その他の操作…;置き換えて採用;重なり追加;同定を解除;候補の根拠を見る;同定の確認一覧;候補を更新;同定条件を設定…;比較図を別窓で開く;表を大きく／グラフと半分;選択した測定ピークを削除;拡大の選択追従を切替;比較する測定データを選ぶ…"
End

Function XRD_MatchActionPopup(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2 && pa.popNum>1)
        if(cmpstr(GetUserData("XRDWorkbench","","XRDMorePending"),"1")==0)
            return 0
        endif
        SetWindow XRDWorkbench userdata(XRDMorePending)="1"
        SetWindow XRDWorkbench userdata(XRDMoreAction)=num2istr(pa.popNum)
        SetWindow XRDWorkbench userdata(XRDMoreContext)=XRD_MatchActionContext(pa.popNum)
        Execute/P/Q "XRD_MatchActionDeferred()"
        PopupMenu matchActions,win=XRDWorkbench,mode=1
    endif
    return 0
End

Function/S XRD_MatchActionContext(action)
    Variable action
    String path=XRD_Data(),key=path
    if(!strlen(path))
        return key
    endif
    Wave ids=$(path+":Peaks:peakID")
    Variable row=NumVarOrDefault(path+":selectedPeakRow",-1),candidate=NumVarOrDefault(path+":selectedCandidateRow",-1)
    if(row>=0 && row<numpnts(ids))
        key+=":"+num2istr(ids[row])
    endif
    if(action==2 || action==3)
        Wave refs=$(path+":Candidates:refIndex"),rows=$(path+":Candidates:refPeakIndex"),shifts=$(path+":Candidates:shift")
        if(candidate>=0 && candidate<numpnts(refs))
            key+=":"+XRD_CandidateIdentity(refs[candidate],rows[candidate])+":"+XRD_ExactNumber(shifts[candidate])
        endif
    endif
    return key
End

Function XRD_MatchActionDeferred()
    if(!WinType("XRDWorkbench") || cmpstr(GetUserData("XRDWorkbench","","XRDMorePending"),"1")!=0)
        return 0
    endif
    Variable action=str2num(GetUserData("XRDWorkbench","","XRDMoreAction"))
    String context=GetUserData("XRDWorkbench","","XRDMoreContext")
    SetWindow XRDWorkbench userdata(XRDMorePending)="0"
    if(cmpstr(context,XRD_MatchActionContext(action))==0)
        return XRD_RunMatchAction(action)
    endif
    return 0
End

Function XRD_RunMatchAction(action)
    Variable action
    String path=XRD_Data(),name=""
    if(!strlen(path) || NumVarOrDefault(XRD_Project()+":activeStep",1)!=3)
        return -1
    endif
    switch(action)
        case 2:
            name="adoptCandidate"
            break
        case 3:
            name="overlapCandidate"
            break
        case 4:
            name="clearAssignment"
            break
        case 5:
            XRD_EvidencePanel()
            return 0
        case 6:
            XRD_AuditPanel()
            return 0
        case 7:
            name="scoreCandidates"
            break
        case 8:
            XRD_MatchSettingsPanel()
            return 0
        case 9:
            return XRD_OpenReview()
        case 10:
            name="tableView"
            break
        case 11:
            name="deletePeak2"
            break
        case 13:
            return XRD_CompareSelection()
        case 12:
            Variable/G root:Packages:XRDWorkbench:UI:autoZoom100=1-NumVarOrDefault("root:Packages:XRDWorkbench:UI:autoZoom100",1)
            XRD_MatchSettingsPanel()
            return 0
    endswitch
    if(strlen(name))
        STRUCT WMButtonAction ba
        ba.eventCode=2;ba.ctrlName=name
        XRD_Button(ba)
    endif
    return 0
End

Function XRD_MatchSettingsPanel()
    String project=XRD_Project(),path=XRD_Data()
    if(!strlen(path))
        return -1
    endif
    DoWindow/K XRDMatchSettings
    NewPanel/N=XRDMatchSettings/W=(45,45,510,435) as "同定条件と表示"
    DefaultGUIFont/W=XRDMatchSettings all={"Segoe UI",12,0}
    SetWindow XRDMatchSettings userdata(XRDData)=path
    NVAR mode=$(path+":candidateMode")
    TitleBox sample,pos={15,14},frame=0,title=StrVarOrDefault(path+":displayName","")
    PopupMenu candidateMode,pos={15,45},title="候補",mode=(mode+1),value="すべて;採用済みの相;新しい相",proc=XRD_MatchSettingsPopup
    PopupMenu shiftMode,pos={15,80},title="参照角度",mode=(NumVarOrDefault(project+":referenceShiftMode",0)+1),value="元の値;全体シフト",proc=XRD_MatchSettingsPopup
    SetVariable matchTolerance,pos={15,117},size={420,22},title="一致幅 ±deg",limits={0.001,5,0.01},value=$(project+":matchTolerance")
    SetVariable maxShift,pos={15,149},size={420,22},title="共通シフト上限 deg",limits={0,5,0.01},value=$(project+":maxCommonShift")
    SetVariable candidateRadius,pos={15,181},size={420,22},title="候補探索幅 ±deg",limits={0.01,5,0.05},value=$(project+":candidateRadius")
    SetVariable previewMin,pos={15,213},size={420,22},title="参照の表示強度下限 %",limits={0,100,1},value=$(project+":previewMinIntensity")
    SetVariable opacity,pos={15,245},size={420,22},title="参照濃さ %",limits={10,100,5},value=$(project+":previewOpacity")
    SetVariable lineWidth,pos={15,277},size={420,22},title="参照線幅",limits={0.5,5,0.5},value=$(project+":previewWidth")
    CheckBox followPeak,pos={15,309},title="ピーク選択時に自動拡大",variable=root:Packages:XRDWorkbench:UI:autoZoom100
    Button applyMatch,pos={15,345},size={420,28},title="条件を反映して閉じる",proc=XRD_V72Button
    return 0
End

Function XRD_MatchSettingsPopup(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    String target=GetUserData("XRDMatchSettings","","XRDData")
    if(pa.eventCode!=2 || cmpstr(target,XRD_Data())!=0)
        return 0
    endif
    if(cmpstr(pa.ctrlName,"candidateMode")==0)
        Variable/G $(target+":candidateMode")=pa.popNum-1
    elseif(cmpstr(pa.ctrlName,"shiftMode")==0)
        Variable/G $(XRD_Project()+":referenceShiftMode")=pa.popNum-1
    endif
    return 0
End

Function XRD_V72Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    strswitch(ba.ctrlName)
        case "zoomPeak":
            XRD_ZoomSelectedPeak()
            break
        case "resetZoom":
            XRD_ResetView()
            break
        case "applyMatch":
            String target=GetUserData("XRDMatchSettings","","XRDData")
            DoWindow/K XRDMatchSettings
            if(cmpstr(target,XRD_Data())==0)
                XRD_InvalidateFilterCandidates()
                XRD_Panel()
            endif
            break
    endswitch
    XRD_RequestLive()
    return 0
End

Function/S XRD_SideSampleName(path)
    String path
    String name=StrVarOrDefault(path+":displayName","")
    Variable i,count=0,byteValue
    for(i=0;i<strlen(name);i+=1)
        byteValue=char2num(name[i])
        if(byteValue<0)
            byteValue+=256
        endif
        if(byteValue<128 || byteValue>=192)
            if(count==24)
                break
            endif
            count+=1
        endif
    endfor
    if(i<strlen(name))
        name=name[0,i-1]+"…"
    endif
    return ParseFilePath(0,path,":",1,0)+"  "+name
End

Function XRD_SyncSideRange()
    if(WinType("XRDWorkbench#Pattern") && WinType("XRDWorkbench#SideCompare"))
        GetAxis/W=XRDWorkbench#Pattern/Q bottom
        SetAxis/W=XRDWorkbench#SideCompare bottom V_min,V_max
    endif
    return 0
End

Function XRD_TrimSideAnnotation()
    if(WhichListItem("ReferenceSelected",AnnotationList("XRDWorkbench#SideCompare"))>=0)
        TextBox/W=XRDWorkbench#SideCompare/K/N=ReferenceSelected
    endif
End

Function XRD_UpdateSideCompare()
    if(WinType("XRDWorkbench#SideCompare") && NumVarOrDefault(XRD_Project()+":activeStep",1)==3 && strlen(XRD_Data()))
        GetWindow XRDWorkbench activeSW
        String active=S_Value
        XRD_DrawLiveStack("XRDWorkbench#SideCompare",2)
        XRD_TrimSideAnnotation()
        if(WinType(active))
            SetActiveSubwindow $active
        endif
    endif
    return 0
End

Function XRD_V72Layout(w,h,scale)
    Variable w,h,scale
    if(NumVarOrDefault(XRD_Project()+":activeStep",1)!=3 || !WinType("XRDWorkbench#SideCompare"))
        return 0
    endif
    Variable side=min(320*scale,w*0.35),inner=side-20*scale,bw=(inner-12*scale)/3
    GroupBox workGroup,win=XRDWorkbench,size={side-4*scale,h-73*scale}
    TitleBox recoveryState,win=XRDWorkbench,pos={side+12*scale,h-39*scale},size={w-side-205*scale,16*scale}

    Button matchActions,win=XRDWorkbench,pos={12*scale,110*scale},size={inner,25*scale},fSize=max(12,round(12*scale))
    Button pointAdd,win=XRDWorkbench,pos={12*scale+(inner+6*scale)/2,137*scale},size={(inner-6*scale)/2,20*scale}
    Button deletePeak2,win=XRDWorkbench,pos={12*scale,161*scale},size={(inner-6*scale)/2,20*scale}
    MoveSubwindow/W=XRDWorkbench#SideCompare fnum=(12*scale,190*scale,side-4*scale,h-48*scale)
    ModifyGraph/W=XRDWorkbench#SideCompare gfSize=round(12*scale),fSize=round(12*scale),margin(left)=48*scale,margin(right)=10*scale,margin(bottom)=35*scale,margin(top)=16*scale
    XRD110_SideLegend("XRDWorkbench#SideCompare",2)
    Label/W=XRDWorkbench#SideCompare bottom "2\\f02θ\\f00 (deg.)"
    return 0
End
