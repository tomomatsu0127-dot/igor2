#pragma rtGlobals=3
// XRD Workbench v1.2.0: fixed figure canvas, guided UI, view history and queued saves.
Function/S XRD_ReferenceHeader(line)
    String line
    String s=LowerStr(line),units="Å;å;angstrom;ang;deg;degree;degrees;°;%;a.u.;a.u;arb. units"
    Variable i
    s=ReplaceString("θ",s,"theta")
    for(i=0;i<ItemsInList(units);i+=1)
        String u=StringFromList(i,units)
        s=ReplaceString(" ("+u+")",s,"")
        s=ReplaceString("("+u+")",s,"")
        s=ReplaceString(" ["+u+"]",s,"")
        s=ReplaceString("["+u+"]",s,"")
    endfor
    s=ReplaceString("\"",s,"")
    s=ReplaceString(",",s," ")
    s=ReplaceString(";",s," ")
    return XRD_NormalizeSpaces(s)
End

Function/S XRD_ReferenceDataLine(line)
    String line
    Variable comment=strsearch(line,"#",0)
    if(comment>=0)
        line=line[0,comment-1]
    endif
    line=ReplaceString("\"",line,"")
    line=ReplaceString(",",line," ")
    line=ReplaceString(";",line," ")
    return XRD_NormalizeSpaces(line)
End

Function XRD_V51RecoveryPolicy()
    String base="root:Packages:XRDWorkbench:Recovery:"
    XRD_EnsureNumeric(base+"queued",0)
    XRD_EnsureNumeric(base+"saving",0)
    if(!NumVarOrDefault(base+"policy81",0))
        // Adopt the requested ON default once; later explicit OFF stays OFF.
        Variable/G $(base+"enabled")=1
        Variable/G $(base+"policy51")=1
        Variable/G $(base+"policy81")=1
        Variable/G $(base+"queued")=0
        Variable/G $(base+"saving")=0
    endif
End

Function XRD_RunQueuedRecovery()
    XRD_RecoverySettings()
    NVAR/Z pending=root:Packages:XRDWorkbench:Recovery:queued
    if(!NVAR_Exists(pending) || !pending)
        return 0
    endif
    pending=0
    if(!NumVarOrDefault("root:Packages:XRDWorkbench:Recovery:enabled",0))
        return 0
    endif
    return XRD_SaveRecovery()
End

Function XRD_SaveDiagnostic(stage)
    String stage
    Variable ref
    Open/A/P=XRDAutoSavePath/Z=2 ref as "XRD_save_diagnostic.log"
    if(V_flag==0)
        fprintf ref,"%s %s v1.2.0 %s\r\n",Secs2Date(DateTime,-2),Secs2Time(DateTime,3),stage
        Close ref
    endif
End

Function XRD_ViewBox(path,values)
    String path
    Wave values
    if(!strlen(path) || !WinType("XRDWorkbench#Pattern") || cmpstr(path,GetUserData("XRDWorkbench","","XRDData"))!=0)
        return -1
    endif
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    values[0]=V_min;values[1]=V_max
    GetAxis/W=XRDWorkbench#Pattern/Q left
    values[2]=V_min;values[3]=V_max
    if(values[0]>=values[1] || values[2]>=values[3])
        return -1
    endif
    return 0
End

Function XRD_ViewSync(path)
    String path
    if(!strlen(path))
        return 0
    endif
    // v1.2.1: never paint baseline-sized contents during screen construction.
    // XRD_Panel synchronizes the view once the final layout is ready.
    if(cmpstr(GetUserData("XRDWorkbench","","XRDLayoutReady"),"1")!=0)
        return 0
    endif
    // Resolve automatic axes only at explicit panel/view synchronization. Do
    // not redraw from the deferred modified-event observer itself.
    DoUpdate/W=XRDWorkbench#Pattern
    Make/O/D/N=4 $(path+":viewBaseline")
    Wave baseline=$(path+":viewBaseline")
    return XRD_ViewBox(path,baseline)
End

Function XRD_SaveViewBox(path,entry)
    String path,entry
    Make/O/D/N=4 $(entry+":viewBox")=NaN
    Wave box=$(entry+":viewBox")
    if(XRD_ViewBox(path,box)<0)
        Wave/Z baseline=$(path+":viewBaseline")
        if(WaveExists(baseline))
            box=baseline[p]
        endif
    endif
End

Function XRD_RecordPendingZoom(path)
    String path
    Wave/Z baseline=$(path+":viewBaseline")
    if(!strlen(path) || !WaveExists(baseline) || cmpstr(GetUserData("XRDWorkbench","","XRDLayoutBusy"),"1")==0)
        return 0
    endif
    Make/FREE/D/N=4 current
    if(XRD_ViewBox(path,current)<0 || numtype(sum(baseline))!=0)
        return 0
    endif
    Variable i,different=0
    for(i=0;i<4;i+=1)
        different=max(different,abs(current[i]-baseline[i])>1e-7*max(1,abs(baseline[i])))
    endfor
    if(!different)
        return 0
    endif
    String project=XRD_Project()
    XRD_UndoSettings(project)
    XRD_EnsureNumeric(project+":Undo:redoCount",0)
    NVAR sequence=$(project+":Undo:sequence"),count=$(project+":Undo:count"),redo=$(project+":Undo:redoCount")
    String entry=project+":Undo:Entry"+num2istr(mod(sequence,20))
    NewDataFolder/O $entry
    String/G $(entry+":kind")="view"
    String/G $(entry+":target")=path
    String/G $(entry+":label")="表示範囲（拡大・縮小）"
    Duplicate/O baseline,$(entry+":viewBox")
    XRD100_PushView(path,baseline)
    baseline=current[p]
    sequence+=1;count=min(20,count+1);redo=0
    XRD_UpdateHistoryUI()
    XRD_RequestLive()
    return 1
End

Function XRD_ScheduleViewCheck()
    if(cmpstr(GetUserData("XRDWorkbench","","XRDLayoutReady"),"1")!=0 || cmpstr(GetUserData("XRDWorkbench","","XRDViewPending"),"1")==0)
        return 0
    endif
    SetWindow XRDWorkbench userdata(XRDViewPending)="1"
    Execute/P/Q "XRD_ViewDeferred()"
End

Function XRD_ViewDeferred()
    if(WinType("XRDWorkbench"))
        XRD120_LockY()
        XRD_RecordPendingZoom(GetUserData("XRDWorkbench","","XRDData"))
        SetWindow XRDWorkbench userdata(XRDViewPending)="0"
    endif
End

Function XRD_ApplyViewEntry(entry)
    String entry
    SVAR path=$(entry+":target")
    if(cmpstr(path,XRD_Data())!=0)
        SVAR active=$(XRD_Project()+":activeData")
        active=path
        XRD_Panel()
    endif
    Wave box=$(entry+":viewBox")
    if(numtype(sum(box))!=0 || box[0]>=box[1] || box[2]>=box[3])
        return -1
    endif
    SetAxis/W=XRDWorkbench#Pattern bottom box[0],box[1]
    SetAxis/W=XRDWorkbench#Pattern left box[2],box[3]
    XRD_CaptureView()
    XRD_ViewSync(path)
    XRD_UpdateHistoryUI()
    return 0
End

Function XRD_LegendEntryWidth(text,font)
    String text
    Variable font
    Variable width=FontSizeStringWidth("Times New Roman",font*ScreenResolution/72,0,text)*72/ScreenResolution
    if(numtype(width)!=0)
        width=strlen(text)*font*0.65
    endif
    return width+font*1.8
End

Function XRD_PhaseLegend(win)
    String win
    return XRD110_RenderLegend(win)
End

Function XRD_FitFigureToWorkspace(win)
    String win
    // Screen magnification never changes physical export dimensions or fonts.
    ModifyGraph/W=$win expand=1
    DoUpdate/W=$win
    GetWindow $win gsize
    Variable w=V_right-V_left,h=V_bottom-V_top
    GetWindow kwFrameInner wsize
    Variable scale=max(0.25,min(1,min((V_right-32)/max(1,w),(V_bottom-48)/max(1,h))))
    ModifyGraph/W=$win expand=scale
    DoUpdate/W=$win
    return 0
End

Function/S XRD_FigureList()
    String all=WinList("*",";","WIN:1"),out="",win
    Variable i
    for(i=0;i<ItemsInList(all);i+=1)
        win=StringFromList(i,all)
        if(strlen(GetUserData(win,"","XRDGraphData")) && cmpstr(GetUserData(win,"","XRDReview"),"1")!=0)
            out+=win+";"
        endif
    endfor
    return out
End

Function XRD_FigurePanel()
    String wins=XRD_FigureList()
    if(!ItemsInList(wins))
        DoAlert 0,"先に『5 図を完成』から単独図または比較図を作成してください。"
        return -1
    endif
    XRD_UISettings()
    String base="root:Packages:XRDWorkbench:UI:"
    Variable i
    String vars="figureWidth;figureHeight;figureFont;legendFont",values="340.157;255.118;24;24"
    for(i=0;i<4;i+=1)
        Variable/G $(base+StringFromList(i,vars))=str2num(StringFromList(i,values))
    endfor
    String/G $(base+"figureTarget")=StringFromList(0,wins)
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDFigureSettings")
    DoWindow/K XRDFigureSettings
    NewPanel/FLT=1/K=1/N=XRDFigureSettings/W=(50,50,700,405) as "完成図の書式（印刷・出力サイズ）"
    ModifyPanel/W=XRDFigureSettings fixedSize=0
    DefaultGUIFont/W=XRDFigureSettings all={"Segoe UI",12,0}
    PopupMenu figureTarget,pos={15,18},title="図",value=XRD_FigureList(),proc=XRD_FigureTarget
    SetVariable figureWidth,pos={15,62},size={600,24},title="プロット幅 (pt)",limits={200,1200,10},value=$(base+"figureWidth")
    SetVariable figureHeight,pos={15,104},size={600,24},title="プロット高さ (pt)",limits={150,2400,10},value=$(base+"figureHeight")
    SetVariable figureFont,pos={15,146},size={290,24},title="軸の文字 (pt)",limits={12,48,1},value=$(base+"figureFont")
    SetVariable legendFont,pos={325,146},size={290,24},title="凡例の文字 (pt)",limits={12,48,1},value=$(base+"legendFont")
    TitleBox note,pos={15,194},frame=0,title="画面倍率と出力の書式を分離します。凡例は文字幅で改行します。\r図の凡例・軸・線はIgorでダブルクリックして編集できます。\rこのボタンは指定図の書式を更新します。手動の凡例編集は置き換わります。"
    Button applyFigure,pos={15,282},size={280,30},title="この図のサイズと凡例を更新",proc=XRD_V51Button
    Button fitFigure,pos={320,282},size={280,30},title="書式を変えず画面に収める",proc=XRD_V51Button
    Button dragFigure,pos={15,320},size={585,26},title="この図を端のドラッグで伸縮できるようにする",proc=XRD_V51Button
    XRD_ReadFigureSettings(StringFromList(0,wins))
    XRD123_FinishPanel("XRDFigureSettings",panelState123)
    return 0
End

Function XRD_ReadFigureSettings(win)
    String win
    String base="root:Packages:XRDWorkbench:UI:"
    String/G $(base+"figureTarget")=win
    GetWindow $win expand
    Variable scale=V_value
    if(numtype(scale)!=0 || scale<=0)
        scale=1
    endif
    GetWindow $win psize
    Variable w=V_right-V_left,h=V_bottom-V_top
    Variable/G $(base+"figureWidth")=w
    Variable/G $(base+"figureHeight")=h
End

Function XRD_FigureTarget(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        XRD_ReadFigureSettings(pa.popStr)
    endif
End

Function XRD_ApplyFigureSettings()
    String base="root:Packages:XRDWorkbench:UI:",win=StrVarOrDefault(base+"figureTarget","")
    Variable w=NumVarOrDefault(base+"figureWidth",0),h=NumVarOrDefault(base+"figureHeight",0),font=NumVarOrDefault(base+"figureFont",0),legend=NumVarOrDefault(base+"legendFont",0)
    if(WinType(win)!=1 || numtype(w+h+font+legend)!=0 || w<200 || h<150 || font<12 || legend<12 || w>1200 || h>2400 || font>48 || legend>48)
        return -1
    endif
    SetWindow $win userdata(XRDFlexible)="0"
    SetWindow $win sizeLimit={0,0,inf,inf},doScroll=0
    SetWindow $win userdata(XRDFigureWidth)=num2str(w)
    SetWindow $win userdata(XRDFigureHeight)=num2str(h)
    ModifyGraph/W=$win width=w,height=h,gfSize=font,fSize=font
    ModifyGraph/W=$win margin(left)=max(70,font*3.25),margin(bottom)=max(70,font*3.25),margin(right)=28
    ModifyGraph/W=$win lblMargin(left)=15,lblMargin(bottom)=12,lblLatPos(bottom)=0
    SetWindow $win userdata(XRDFigureLegendFont)=num2str(legend)
    XRD_PhaseLegend(win)
    XRD_EnableFigureResize(win)
    return 0
End

Function XRD_BeginnerControls(project,path)
    String project,path
    NVAR step=$(project+":activeStep")
    if(step==3 && strlen(path))
        XRD_EnsureNumeric(project+":detailControls",0)
        NVAR details=$(project+":detailControls")
        TitleBox stepHelp,title="左の測定ピーク → 右の候補をダブルクリック。\r赤棒で全体を確認します。\rCtrl+Zは拡大・解析を順に戻します。"
        Button scoreCandidates,pos={16,132}
        Button adoptCandidate,pos={16,158}
        Button overlapCandidate,pos={104,158}
        Button unknownPeak,pos={16,182},title="不明にする"
        Button clearAssignment,pos={104,182}
        Button evidence,pos={16,207}
        Button audit,pos={16,232}
        Button resetZoom,pos={16,257}
        Button tableView,pos={16,286}
        Button deletePeak2,pos={16,315}
        Button details,pos={16,345},size={175,20},title=SelectString(details,"詳細設定を開く ▼","詳細設定を閉じる ▲"),proc=XRD_V51Button
        SetVariable candidateRadius,pos={16,489},size={175,18},title="候補探索幅 ±deg",limits={0.01,5,0.05},value=$(project+":candidateRadius")
        String controls="matchTolerance;maxShift;previewMin;opacity;lineWidth;candidateRadius",control
        Variable i
        for(i=0;i<6;i+=1)
            control=StringFromList(i,controls)
            ModifyControl $control,pos={16,370+i*21},disable=SelectNumber(details,1,0)
        endfor
    elseif(step==5)
        Button figureSettings,pos={16,410},size={175,20},title="完成図のサイズ・凡例を調整",proc=XRD_V51Button
        Button deleteData,pos={16,435},size={175,20}
        Button restoreData,pos={16,457},size={175,20}
    endif
End

Function XRD_QuickGuide()
    DoWindow/K XRDGuide
    NewNotebook/K=1/N=XRDGuide/F=1/V=1/W=(50,50,760,670) as "XRD Workbench v1.2.0 操作ガイド"
    Notebook XRDGuide font="Segoe UI",fSize=13
    Notebook XRDGuide text="1 プロジェクトを追加\rXRD Workbench → プロジェクトを追加。名前を入力します。F6は現在の画面へ戻ります。\r\r"
    Notebook XRDGuide text="2 測定データとピーク\r測定データを追加して名前を付けます。自動検出または外部ピークを登録します。グラフからは『点を選ぶ（追加用）』→点を選択→『選択点を追加』。追加後は登録ピーク選択へ戻ります。通常モードのカーソルは登録ピークだけを選びます。削除ボタンで選択ピークを削除します。Ctrl+Iも使用できます。\r\r"
    Notebook XRDGuide text="3 参照と同定\r参照値メニューでライブラリを開き、使用するカードをチェックします。測定ピークを選択し、右の候補をダブルクリックして採用。赤棒が参照パターン、赤矢印が選択中の参照反射、黒い点線が測定側の選択位置です。不明はUnknown。全ピークが対応済みになると試料単位で解析完了です。\r\r"
    Notebook XRDGuide text="4 作図\r上部『作図』→作図ウィンドウ。プロジェクトから完了試料を選択し、一覧の名前の列を上下にドラッグして順番を決めます。作成後、軸・凡例・記号の設定を変更すると図へ反映します。記号の色・形・サイズはExperiment共通で保存します。グラフを右クリックするとPNG保存を選べます。\r\r"
    Notebook XRDGuide text="5 保存・戻す\r通常保存はFile → Save Experiment As...で.pxpへ。自動保存は初期ON、5分おき、復旧コピー3世代です。保存設定でON/OFFと間隔を変更できます。Ctrl+Zで拡大・解析を戻し、Ctrl+Shift+Zでやり直します。\r\r"
    Notebook XRDGuide text="詳細マニュアルは配布フォルダのMANUAL_ja.htmlです。初めての方向け／旧版からの方向けの2種類があります。"
    Notebook XRDGuide selection={startOfFile,startOfFile}
    return 0
End

Function XRD_V51Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    strswitch(ba.ctrlName)
        case "helpGuide":
            Execute/P/Q "XRD_QuickGuide()"
            break
        case "details":
            NVAR detail=$(XRD_Project()+":detailControls")
            detail=!detail
            Execute/P/Q "XRD_Panel()"
            break
        case "figureSettings":
            Execute/P/Q "XRD_FigurePanel()"
            break
        case "applyFigure":
            XRD_ApplyFigureSettings()
            break
        case "fitFigure":
            XRD_FitFigureToWorkspace(StrVarOrDefault("root:Packages:XRDWorkbench:UI:figureTarget",""))
            break
        case "dragFigure":
            XRD_EnableFigureResize(StrVarOrDefault("root:Packages:XRDWorkbench:UI:figureTarget",""))
            break
    endswitch
End
