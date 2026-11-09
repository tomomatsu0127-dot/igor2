#pragma rtGlobals=3
#pragma version=2.12

// Shared figure settings are stored with the Experiment. Dimensions are in physical points.
Function HMH_FigureInit()
    NewDataFolder/O root:MHApp
    NewDataFolder/O root:MHApp:Figure
    String base="root:MHApp:Figure:"
    HMH_DefaultNumber(base+"targetMode",1)
    HMH_DefaultNumber(base+"widthCM",12)
    HMH_DefaultNumber(base+"ratio",4/3)
    HMH_DefaultNumber(base+"axisFont",24)
    HMH_DefaultNumber(base+"legendFont",24)
    HMH_DefaultNumber(base+"columns",2)
    HMH_DefaultNumber(base+"lineWidth",2.5)
    HMH_DefaultNumber(base+"legendStyle",1)
    HMH_DefaultNumber(base+"rtVisible",1)
    HMH_DefaultNumber(base+"rtRight",8)
    HMH_DefaultNumber(base+"rtBottom",12)
    HMH_DefaultNumber(base+"rtFont",24)
    HMH_DefaultNumber(base+"sharedApplied",0)
    SVAR/Z target=$(base+"target")
    if(!SVAR_Exists(target))
        String/G $(base+"target")=""
    endif
End

Function/S HMH_JapaneseLegendFont()
    String fonts=FontList(";"),choices="ＭＳ 明朝;MS Mincho;游明朝;Yu Mincho;ＭＳ Ｐ明朝;MS PMincho",name
    Variable i
    for(i=0;i<ItemsInList(choices);i+=1)
        name=StringFromList(i,choices)
        if(WhichListItem(name,fonts)>=0)
            return name
        endif
    endfor
    return "Times New Roman"
End

// Select Mincho for Japanese runs; Latin, digits, degree signs and Greek stay TNR.
// Preserve explicit user font commands and other Igor annotation escape sequences.
Function/S HMH_LegendLabel(label)
    String label
    if(strsearch(label,"\\F",0)>=0)
        return label
    endif
    String out="",jpFont=HMH_JapaneseLegendFont()
    Variable i=0,cp,lead,n,japanese=0,nextJapanese
    do
        if(i>=strlen(label))
            break
        endif
        lead=char2num(label[i]) & 255
        n=1
        if(lead>=240)
            n=4
        elseif(lead>=224)
            n=3
        elseif(lead>=192)
            n=2
        endif
        cp=char2num(label[i,inf])
        nextJapanese=(cp>=0x3000 && cp<=0x9FFF) || (cp>=0xFF00 && cp<=0xFFEF) || (cp>=0x20000 && cp<=0x323AF)
        if(numtype(cp)!=0)
            n=1;nextJapanese=japanese
        endif
        if(nextJapanese!=japanese)
            out+="\\F'"+SelectString(nextJapanese,"Times New Roman",jpFont)+"'"
            japanese=nextJapanese
        endif
        out+=label[i,i+n-1]
        i+=n
    while(1)
    if(japanese)
        out+="\\F'Times New Roman'"
    endif
    return out
End

Function HMH_NewGraphAxes(win,xlo,xhi,ylo,yhi)
    String win
    Variable xlo,xhi,ylo,yhi
    if(numtype(xlo+xhi+ylo+yhi)!=0)
        return -1
    endif
    Variable hx=max(abs(xlo),abs(xhi)),hy=max(abs(ylo),abs(yhi))
    if(hx<=0)
        hx=1
    endif
    if(hy<=0)
        hy=1
    endif
    // Instrument endpoint overshoot (e.g. 15.0016 kOe for a 15 kOe run)
    // may be rounded at 0.05% of a major interval. Source waves are untouched.
    Variable xs=HMH_NiceStep(2*hx*(1-0.0005)),ys=HMH_NiceStep(2*hy)
    Variable xb=xs*max(1,ceil(hx/xs-0.0005)),yb=ys*max(1,ceil(hy/ys))
    return HMH_ApplyAxes(win,-xb,xb,xs,0,-1,-yb,yb,ys,0,-1)
End

Function HMH_ReferenceLast()
    HMF_BeginDraft()
    NVAR mode=root:MHApp:FigureDraft:targetMode,width=root:MHApp:FigureDraft:widthCM,ratio=root:MHApp:FigureDraft:ratio
    NVAR axisFont=root:MHApp:FigureDraft:axisFont,legendFont=root:MHApp:FigureDraft:legendFont
    NVAR columns=root:MHApp:FigureDraft:columns,lineWidth=root:MHApp:FigureDraft:lineWidth
    mode=1; width=12; ratio=4/3
    axisFont=24; legendFont=24; columns=2; lineWidth=2.5
    return HMF_CommitDraft()
End

Function HMH_DefaultNumber(path,initial)
    String path
    Variable initial
    NVAR/Z existing=$path
    if(!NVAR_Exists(existing))
        Variable/G $path=initial
    endif
End

Function HMH_ApplyDefaults(win)
    String win
    HMH_FigureInit()
    return HMF_LayoutFrom(win,"root:MHApp:Figure:",0)
End

Function HMF_LayoutFrom(win,base,previewOnly)
    String win,base
    Variable previewOnly
    NVAR mode=$(base+"targetMode"),width=$(base+"widthCM"),ratio=$(base+"ratio")
    NVAR axisFont=$(base+"axisFont"),legendFont=$(base+"legendFont"),cols=$(base+"columns"),lineWidth=$(base+"lineWidth"),style=$(base+"legendStyle")
    return HMH_Layout(win,mode,width,ratio,axisFont,legendFont,cols,lineWidth,legendStyle=style,previewOnly=previewOnly)
End

// Returns the bounding rectangle of an annotation in physical points.
// AnnotationInfo RECT is in graph points; do not convert it using screen DPI.
Function HMH_AnnotationSize(win,name,which)
    String win,name
    Variable which
    String info=AnnotationInfo(win,name,1),rect=StringByKey("RECT",info)
    GetWindow $win expand
    Variable scale=V_value
    Variable a=str2num(StringFromList(which,rect,",")),b=str2num(StringFromList(which+2,rect,","))
    return (b-a)/max(scale,0.01)
End

// mode 1: width and W/H describe the plot rectangle. mode 2: the entire canvas.
// Invalid dimensions return before changing the target. A staging graph measures
// native legend text, including Igor escape sequences, before committing layout.
Function HMH_Layout(win,mode,widthCM,ratio,axisFont,legendFont,columns,lineWidth,[legendStyle,previewOnly])
    String win
    Variable mode,widthCM,ratio,axisFont,legendFont,columns,lineWidth,legendStyle,previewOnly
    if(ParamIsDefault(legendStyle))
        legendStyle=NumVarOrDefault("root:MHApp:Figure:legendStyle",1)
    endif
    if(WinType(win)!=1 || numtype(mode+widthCM+ratio+axisFont+legendFont+columns+lineWidth)!=0)
        return -1
    endif
    if((mode!=1 && mode!=2) || widthCM<6 || widthCM>60 || ratio<0.25 || ratio>4)
        return -1
    endif
    if(axisFont<12 || axisFont>48 || legendFont<12 || legendFont>48 || columns<1 || columns>3 || columns!=round(columns) || lineWidth<0.25 || lineWidth>8)
        return -1
    endif
    String traces=TraceNameList(win,";",1),annotation,text,centersList=""
    Variable n=ItemsInList(traces),i,boxW,boxH
    if(n==0)
        return -1
    endif
    if(legendStyle==3)
        traces=HMD_RightTraceOrder(win,traces)
    endif
    Make/FREE/D/N=10 tabs
    Make/FREE/D/N=(n) centers
    if(HMD_MeasureLegend(win,traces,legendStyle,columns,legendFont,tabs,centers,text,boxW,boxH)!=0)
        return -2
    endif
    Variable leftMargin=ceil(axisFont*3.5+12),rightMargin=ceil(axisFont),bottomMargin=ceil(axisFont*3+15)
    Variable topMargin=ceil(boxH+16),plotW,plotH,canvasW,canvasH
    if(legendStyle==2)
        topMargin=ceil(boxH+36)
    elseif(legendStyle==3)
        topMargin=16
        rightMargin=ceil(max(rightMargin,boxW+40))
    endif
    if(mode==1)
        plotW=widthCM*72/2.54
        plotH=plotW/ratio
        if(legendStyle!=3)
            rightMargin=ceil(max(rightMargin,boxW+16-plotW-leftMargin))
        else
            bottomMargin=ceil(max(bottomMargin,boxH+16-plotH-topMargin))
        endif
        canvasW=plotW+leftMargin+rightMargin
        canvasH=plotH+topMargin+bottomMargin
    else
        canvasW=widthCM*72/2.54
        canvasH=canvasW/ratio
        plotW=canvasW-leftMargin-rightMargin
        plotH=canvasH-topMargin-bottomMargin
        if((legendStyle!=3 && boxW>canvasW-16) || (legendStyle==3 && boxH>canvasH-16))
            return -2
        endif
    endif
    if(plotW<axisFont*5 || plotH<axisFont*4)
        return -3
    endif
    if(previewOnly)
        return 0
    endif
    // Capture axes: changing typography or physical dimensions must not reset zoom.
    GetAxis/Q/W=$win bottom
    Variable xMin=V_min,xMax=V_max
    GetAxis/Q/W=$win left
    Variable yMin=V_min,yMax=V_max
    ModifyGraph/W=$win expand=1,gFont="Times New Roman",gfSize=axisFont,fSize=axisFont
    ModifyGraph/W=$win width=plotW,height=plotH,margin(left)=leftMargin,margin(right)=rightMargin
    ModifyGraph/W=$win margin(top)=topMargin,margin(bottom)=bottomMargin
    HMP_ResizeOverlay(win,canvasW,canvasH)
    ModifyGraph/W=$win mirror=1,tick=2,standoff=0,axThick=1.2,lsize=lineWidth
    ModifyGraph/W=$win zero(left)=1,zero(bottom)=1,grid=0
    ModifyGraph/W=$win lblMargin(left)=12,lblMargin(bottom)=12,lblLatPos(bottom)=0
    // Only the built-in legend annotations are replaced.
    for(i=1;i<=3;i+=1)
        annotation="HMHLegend"+num2istr(i)
        if(WhichListItem(annotation,AnnotationList(win))>=0)
            TextBox/W=$win/K/N=$annotation
        endif
    endfor
    HMD_ClearLeaders(win)
    HMD_Box(win,text,legendFont,tabs,0,0)
    if(legendStyle==2)
        for(i=0;i<n;i+=1)
            centersList+=num2str(centers[i])+";"
        endfor
    endif
    SetWindow $win userdata(HMDStyle)=num2istr(legendStyle)
    SetWindow $win userdata(HMDCenters)=centersList
    SetWindow $win userdata(HMDTraces)=traces
    HMD_RoomTemperature(win)
    SetAxis/W=$win bottom xMin,xMax
    SetAxis/W=$win left yMin,yMax
    String settings
    sprintf settings,"mode:%d;widthCM:%.12g;ratio:%.12g;axisFont:%d;legendFont:%d;columns:%d;lineWidth:%.12g;",mode,widthCM,ratio,axisFont,legendFont,columns,lineWidth
    SetWindow $win userdata(HMHLayout)=settings
    SetWindow $win userdata(HMHCanvasWidth)=num2str(canvasW)
    SetWindow $win userdata(HMHCanvasHeight)=num2str(canvasH)
    SetWindow $win userdata(HMHLegendRows)=num2istr(SelectNumber(legendStyle==2,SelectNumber(legendStyle==3,ceil(n/min(columns,n)),n),1))
    HMH_FitFigure(win)
    return 0
End

Function/S HMH_TraceLabel(win,trace)
    String win,trace
    String label=GetUserData(win,"","HMHLabel_"+trace)
    if(strlen(label))
        return label
    endif
    // Support graphs made by v2.01 in an already saved experiment.
    Wave y=TraceNameToWaveRef(win,trace)
    String path=GetWavesDataFolder(y,1)
    Wave/T/Z paths=root:MHApp:paths,names=root:MHApp:names
    if(WaveExists(paths) && WaveExists(names))
        Variable i
        for(i=0;i<numpnts(paths);i+=1)
            if(cmpstr(paths[i],path)==0)
                return names[i]
            endif
        endfor
    endif
    return trace
End

Function HMH_FitFigure(win)
    String win
    if(WinType(win)!=1)
        return -1
    endif
    if(strsearch(win,"#",0)>=0)
        DoUpdate/W=$win
        HMD_Reposition(win)
        return 0
    endif
    ModifyGraph/W=$win expand=1
    DoUpdate/W=$win
    GetWindow $win gsize
    Variable w=V_right-V_left,h=V_bottom-V_top
    GetWindow kwFrameInner wsize
    Variable scale=max(0.2,min(1,min((V_right-40)/max(1,w),(V_bottom-60)/max(1,h))))
    ModifyGraph/W=$win expand=scale
    DoUpdate/W=$win
    HMD_Reposition(win)
    return 0
End

Function HMH_FitLastFigure()
    HMH_Init()
    SVAR win=root:MHApp:lastGraph
    return HMH_FitFigure(win)
End

Function/S HMH_FigureList()
    String wins=HMP_PlotList(),out="",win
    Variable i
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(strlen(GetUserData(win,"","HMHFigure")) || strlen(GetUserData(win,"","HMHGraphUID")) || WhichListItem("HMHLegend",AnnotationList(win))>=0)
            out+=win+";"
        endif
    endfor
    return out
End

Function HMF_CopyValues(from,to)
    String from,to
    String keys="targetMode;widthCM;ratio;axisFont;legendFont;columns;lineWidth;legendStyle;rtVisible;rtRight;rtBottom;rtFont"
    Variable i
    String key
    for(i=0;i<ItemsInList(keys);i+=1)
        key=StringFromList(i,keys)
        NVAR v=$(from+key)
        Variable/G $(to+key)=v
    endfor
End

Function HMF_BeginDraft()
    HMH_FigureInit()
    NewDataFolder/O root:MHApp:FigureDraft
    HMF_CopyValues("root:MHApp:Figure:","root:MHApp:FigureDraft:")
End

Function HMF_CommitDraft()
    String base="root:MHApp:FigureDraft:",shared="root:MHApp:Figure:"
    NVAR mode=$(base+"targetMode"),width=$(base+"widthCM"),ratio=$(base+"ratio")
    NVAR axisFont=$(base+"axisFont"),legendFont=$(base+"legendFont"),cols=$(base+"columns"),lineWidth=$(base+"lineWidth"),style=$(base+"legendStyle")
    NVAR rtFont=$(base+"rtFont"),rtRight=$(base+"rtRight"),rtBottom=$(base+"rtBottom")
    if(numtype(width+ratio+axisFont+legendFont+cols+lineWidth+style+rtFont+rtRight+rtBottom)!=0 || width<6 || width>60 || ratio<0.25 || ratio>4)
        return -1
    endif
    if(rtRight<0 || rtRight>60 || rtBottom<0 || rtBottom>60 || rtFont<12 || rtFont>48)
        return -1
    endif
    if(axisFont<12 || axisFont>48 || legendFont<12 || legendFont>48 || lineWidth<0.25 || lineWidth>8 || cols<1 || cols>3 || style<1 || style>3 || (mode!=1 && mode!=2))
        return -1
    endif
    Variable points=width*72/2.54
    if(mode==1 && (points<axisFont*5 || points/ratio<axisFont*4))
        return -3
    endif
    if(mode==2 && (points<axisFont*9.5+12 || points/ratio<axisFont*7+31))
        return -3
    endif
    String wins=HMH_FigureList(),win
    Variable i,result
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        result=HMF_LayoutFrom(win,base,1)
        if(result!=0)
            return result
        endif
    endfor
    HMF_CopyValues(base,shared)
    Variable/G $(shared+"sharedApplied")=1
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        HMF_LayoutFrom(win,shared,0)
    endfor
    return 0
End

Function HMH_FigurePanel()
    HMH_Init()
    HMF_BeginDraft()
    String base="root:MHApp:FigureDraft:"
    NVAR mode=$(base+"targetMode"),cols=$(base+"columns"),style=$(base+"legendStyle"),rt=$(base+"rtVisible")
    DoWindow/K HMH_FigureSettings
    NewPanel/K=1/N=HMH_FigureSettings/W=(70,70,750,630) as "MH：Experiment共通の図設定"
    DefaultGUIFont/W=HMH_FigureSettings all={"Segoe UI",12,0}
    TitleBox header,pos={20,15},frame=0,title="開いているMH図と、これから作るMH図に共通の書式を使います。"
    GroupBox geometry,pos={14,48},size={650,132},title="図の大きさ"
    PopupMenu targetMode,pos={28,74},title="寸法の基準",value="描画枠（軸で囲まれた部分）;図全体（凡例・軸ラベルを含む）",mode=mode,proc=HMF_Popup
    SetVariable widthCM,pos={28,109},size={280,24},title="幅 (cm)",limits={6,60,0.5},value=$(base+"widthCM")
    SetVariable ratio,pos={325,109},size={303,24},title="縦横比（横 ÷ 縦）",limits={0.25,4,0.05},value=$(base+"ratio")
    Button reference,pos={28,140},size={254,25},title="描画枠 12 × 9 cm",proc=HMF_Button
    GroupBox appearance,pos={14,190},size={650,131},title="凡例と文字"
    PopupMenu legendStyle,pos={28,215},title="凡例",value="上・線見本;上・矢印;右・矢印",mode=style,proc=HMF_Popup
    PopupMenu columns,pos={325,215},title="線見本の列数",value="1列;2列;3列",mode=cols,proc=HMF_Popup
    SetVariable axisFont,pos={28,251},size={280,24},title="軸の文字 (pt)",limits={12,48,1},value=$(base+"axisFont")
    SetVariable legendFont,pos={325,251},size={303,24},title="凡例の文字 (pt)",limits={12,48,1},value=$(base+"legendFont")
    SetVariable lineWidth,pos={28,286},size={280,24},title="曲線の太さ (pt)",limits={0.25,8,0.25},value=$(base+"lineWidth")
    GroupBox room,pos={14,332},size={650,126},title="R.T. 枠"
    CheckBox rtVisible,pos={28,359},title="R.T. 枠を表示",value=rt,proc=HMF_Check
    SetVariable rtFont,pos={325,357},size={303,24},title="R.T. の文字 (pt)",limits={12,48,1},value=$(base+"rtFont")
    SetVariable rtRight,pos={28,402},size={280,24},title="右端から (%)",limits={0,60,1},value=$(base+"rtRight")
    SetVariable rtBottom,pos={325,402},size={303,24},title="下端から (%)",limits={0,60,1},value=$(base+"rtBottom")
    Button apply,pos={20,476},size={420,34},title="Experiment全体に適用",proc=HMF_Button
    TitleBox note,pos={20,525},frame=0,title="適用後にExperimentを保存すると、次回も同じ設定を使います。"
    return 0
End

Function HMF_Popup(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        Variable/G $("root:MHApp:FigureDraft:"+pa.ctrlName)=pa.popNum
    endif
    return 0
End

Function HMF_Check(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    if(cba.eventCode==2)
        Variable/G root:MHApp:FigureDraft:rtVisible=cba.checked
    endif
    return 0
End

Function HMF_Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(cmpstr(ba.ctrlName,"reference")==0)
        Variable/G root:MHApp:FigureDraft:targetMode=1
        Variable/G root:MHApp:FigureDraft:widthCM=12
        Variable/G root:MHApp:FigureDraft:ratio=4/3
        PopupMenu targetMode,win=HMH_FigureSettings,mode=1
        return 0
    endif
    if(HMF_CommitDraft()!=0)
        DoAlert 0,"寸法内に図や凡例が収まりません。幅、縦横比、凡例の形式を調整してください。上の矢印凡例は11項目までです。"
        return -1
    endif
    TitleBox note,win=HMH_FigureSettings,title="適用しました。Experimentを保存すると設定が残ります。"
    return 0
End

Function HMH_Guide()
    DoWindow/K HMHGuide
    NewNotebook/N=HMHGuide/F=1/V=1/W=(80,60,820,640) as "MH VSM Analyzer v2.5.0：使い方"
    Notebook HMHGuide font="Segoe UI",fSize=13
    Notebook HMHGuide text="管理：MH解析 → データ・グラフ管理を開く。フォルダを作成し、選んだ場所へVSMを追加できます。測定・フォルダ・図の名前変更と移動は、測定Waveや既存図の書式を変更しません。\r保存した図はツリーから開けます。矢印の数値調整は補助機能のチェックを入れた場合だけ使えます。\r\r"
    Notebook HMHGuide text="MH VSM Analyzer v2.5.0\r\r1  MH解析 → 操作パネルを開く → VSMを追加。\r磁場をOeからkOeへ変換し、磁化を試料質量(g)で割ってemu/gにします。元のH_Oe・M_emuも保持します。\r\r"
    Notebook HMHGuide text="2  比較する試料をチェックし、名前をダブルクリックして条件名に変更します。\r例：900°C pre、1200°C、x = 0.2。『チェック分を比較』で図を作成します。\r\r"
    Notebook HMHGuide text="3  Experiment共通の図設定を開きます。\r描画枠モード：枠を12×9 cmなどに保ち、凡例の余白を外へ追加します。\r図全体モード：凡例・軸ラベルを含む白いキャンバスの横÷縦を指定します。タイトルバーは含みません。両方の比率を同時に固定する設定ではありません。\r\r"
    Notebook HMHGuide text="4  軸・目盛り・桁数。比較範囲は実測値に合わせて指定してください。\r例：磁場 -15〜15 kOe、主目盛り5 kOe、磁化 -80〜80 emu/g、主目盛り40 emu/g。小目盛りは0で非表示です。\r\r"
    Notebook HMHGuide text="新規図は整数の主目盛りを設定します。英数字はTimes New Roman、日本語の凡例は明朝体です。既存図も『見本の書式にする』で戻せます。\r\r"
    Notebook HMHGuide text="完成図はIgor標準のグラフです。軸・曲線・凡例はダブルクリックで編集でき、Graphメニューの機能も使えます。凡例は一つのテキストボックスです。『設定を反映』を押すと、この拡張の凡例は一覧の名前に戻ります。\r\r"
    Notebook HMHGuide text="図が大きい場合は『書式を変えず画面に収める』で表示倍率だけを変更します。出力寸法とフォントは保たれます。\rFile → Save Experimentで.pxpに保存します。元のVSMファイルを消しても保存済みWaveは残ります。\rこの版は作図書式の改良です。Ms・Hc等の新しい解析や平滑化は追加していません。\r"
    return 0
End
