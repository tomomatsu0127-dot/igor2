#pragma rtGlobals=3
#pragma version=2.12

// MH figure layout v2.1.2. Dimensions are physical points, independent of screen DPI.
// No window hooks or background tasks: a figure changes only on an explicit command.
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
    HMH_Init()
    SVAR last=root:MHApp:lastGraph
    String win=WinName(0,1)
    if(WhichListItem(win,HMH_FigureList())<0)
        win=last
    endif
    if(WinType(win)!=1)
        DoAlert 0,"先に単独表示または比較グラフを作成してください。"
        return -1
    endif
    String traces=TraceNameList(win,";",1),trace
    Variable i,j,xlo=inf,xhi=-inf,ylo=inf,yhi=-inf
    for(i=0;i<ItemsInList(traces);i+=1)
        trace=StringFromList(i,traces)
        Wave/Z y=TraceNameToWaveRef(win,trace),x=XWaveRefFromTrace(win,trace)
        if(!WaveExists(x) || !WaveExists(y))
            continue
        endif
        for(j=0;j<min(numpnts(x),numpnts(y));j+=1)
            if(numtype(x[j]+y[j])==0)
                xlo=min(xlo,x[j]);xhi=max(xhi,x[j])
                ylo=min(ylo,y[j]);yhi=max(yhi,y[j])
            endif
        endfor
    endfor
    if(numtype(xlo+xhi+ylo+yhi)!=0)
        return -1
    endif
    Variable result=HMH_Layout(win,1,12,4/3,24,24,2,2.5)
    if(result!=0)
        return result
    endif
    result=HMH_NewGraphAxes(win,xlo,xhi,ylo,yhi)
    last=win
    HMH_ReadLayout(win)
    HMH_FitFigure(win)
    return result
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
    String base="root:MHApp:Figure:"
    return HMH_Layout(win,NumVarOrDefault(base+"targetMode",1),NumVarOrDefault(base+"widthCM",12),NumVarOrDefault(base+"ratio",4/3),NumVarOrDefault(base+"axisFont",24),NumVarOrDefault(base+"legendFont",24),NumVarOrDefault(base+"columns",2),NumVarOrDefault(base+"lineWidth",2))
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
Function HMH_Layout(win,mode,widthCM,ratio,axisFont,legendFont,columns,lineWidth)
    String win
    Variable mode,widthCM,ratio,axisFont,legendFont,columns,lineWidth
    if(WinType(win)!=1 || numtype(mode+widthCM+ratio+axisFont+legendFont+columns+lineWidth)!=0)
        return -1
    endif
    if((mode!=1 && mode!=2) || widthCM<6 || widthCM>60 || ratio<0.25 || ratio>4)
        return -1
    endif
    if(axisFont<12 || axisFont>48 || legendFont<12 || legendFont>48 || columns<1 || columns>3 || columns!=round(columns) || lineWidth<0.25 || lineWidth>8)
        return -1
    endif
    String traces=TraceNameList(win,";",1),trace,label,an,text,stage=UniqueName("HMH_Measure",6,0)
    Variable n=ItemsInList(traces),i,c,r,cols=min(columns,n),rows=ceil(n/max(1,cols))
    if(n==0)
        return -1
    endif
    Make/FREE/T/N=(cols) texts
    Make/FREE/D/N=(cols) colWidths
    texts=""
    // Build columns in row order: 1,2 / 3,4 / 5,6.
    for(i=0;i<n;i+=1)
        c=mod(i,cols)
        trace=StringFromList(i,traces)
        label=HMH_LegendLabel(HMH_TraceLabel(win,trace))
        if(strlen(texts[c]))
            texts[c]+="\r"
        endif
        texts[c]+="\\s("+trace+") "+label
    endfor
    // A hidden, independent graph is closed on every return. The actual data waves
    // are referenced read-only; legend symbol style affects width but not data.
    Wave x=TraceNameToWaveRef(win,StringFromList(0,traces))
    Display/HIDE=1/K=1/N=$stage x
    ModifyGraph/W=$stage gFont="Times New Roman",gfSize=legendFont,width=400,height=300,expand=1
    Variable topHeight=0,totalLegendWidth=0,gap=legendFont,pad=12
    for(c=0;c<cols;c+=1)
        an="HMHLegend"+num2istr(c+1)
        // Resolve symbols against the target graph when measuring: absent symbol
        // names on the staging graph are replaced by one known trace of same width.
        text=texts[c]
        for(i=0;i<n;i+=1)
            trace=StringFromList(i,traces)
            text=ReplaceString("\\s("+trace+")",text,"\\s("+NameOfWave(x)+")")
        endfor
        text="\\F'Times New Roman'\\Z"+num2istr(legendFont)+"\\[0"+text
        Legend/W=$stage/C/N=$an/A=LT/E=2/F=0/B=1/H=(legendFont*1.8)/LS=(legendFont*0.12)/X=0/Y=0 text
        DoUpdate/W=$stage
        colWidths[c]=HMH_AnnotationSize(stage,an,0)
        topHeight=max(topHeight,HMH_AnnotationSize(stage,an,1))
        totalLegendWidth+=colWidths[c]
    endfor
    DoWindow/K $stage
    totalLegendWidth+=(cols-1)*gap
    // Igor stores fixed graph margins in whole points. Use those same values in
    // the canvas calculation instead of mixing them with fractional text metrics.
    Variable leftMargin=ceil(axisFont*3.5+12),rightMargin=ceil(axisFont),bottomMargin=ceil(axisFont*3+15)
    Variable topMargin=ceil(topHeight+24),plotW,plotH,canvasW,canvasH
    if(mode==1)
        plotW=widthCM*72/2.54
        plotH=plotW/ratio
        canvasW=max(plotW+leftMargin+rightMargin,totalLegendWidth+2*pad)
        // Long legends may add side space; the requested plot rectangle is exact.
        rightMargin=ceil(canvasW-plotW-leftMargin)
        canvasW=plotW+leftMargin+rightMargin
        canvasH=plotH+topMargin+bottomMargin
    else
        canvasW=widthCM*72/2.54
        canvasH=canvasW/ratio
        plotW=canvasW-leftMargin-rightMargin
        plotH=canvasH-topMargin-bottomMargin
        if(totalLegendWidth>canvasW-2*pad)
            return -2
        endif
    endif
    if(plotW<axisFont*5 || plotH<axisFont*4)
        return -3
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
    // Remove only this extension's managed legends, never user annotations.
    if(WhichListItem("HMHLegend",AnnotationList(win))>=0)
        Legend/W=$win/K/N=HMHLegend
    endif
    for(c=1;c<=3;c+=1)
        an="HMHLegend"+num2istr(c)
        if(WhichListItem(an,AnnotationList(win))>=0)
            Legend/W=$win/K/N=$an
        endif
    endfor
    Variable cursorX=(canvasW-totalLegendWidth)/2
    for(c=0;c<cols;c+=1)
        an="HMHLegend"+num2istr(c+1)
        text="\\F'Times New Roman'\\Z"+num2istr(legendFont)+"\\[0"+texts[c]
        Legend/W=$win/C/N=$an/A=LT/E=2/F=0/B=1/H=(legendFont*1.8)/LS=(legendFont*0.12)/X=(100*cursorX/canvasW)/Y=(100*pad/canvasH) text
        cursorX+=colWidths[c]+gap
    endfor
    SetAxis/W=$win bottom xMin,xMax
    SetAxis/W=$win left yMin,yMax
    String settings
    sprintf settings,"mode:%d;widthCM:%.12g;ratio:%.12g;axisFont:%d;legendFont:%d;columns:%d;lineWidth:%.12g;",mode,widthCM,ratio,axisFont,legendFont,columns,lineWidth
    SetWindow $win userdata(HMHLayout)=settings
    SetWindow $win userdata(HMHCanvasWidth)=num2str(canvasW)
    SetWindow $win userdata(HMHCanvasHeight)=num2str(canvasH)
    SetWindow $win userdata(HMHLegendRows)=num2istr(rows)
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
        if(strlen(GetUserData(win,"","HMHFigure")) || strlen(GetUserData(win,"","HMHGraphUID")) || strlen(AnnotationInfo(win,"HMHLegend",0)))
            out+=win+";"
        endif
    endfor
    return out
End

Function HMH_ReadLayout(win)
    String win
    HMH_FigureInit()
    String base="root:MHApp:Figure:",settings=GetUserData(win,"","HMHLayout")
    String/G $(base+"target")=win
    String keys="targetMode;widthCM;ratio;axisFont;legendFont;columns;lineWidth"
    String fields="mode;widthCM;ratio;axisFont;legendFont;columns;lineWidth"
    Variable i,v
    for(i=0;i<ItemsInList(keys);i+=1)
        v=NumberByKey(StringFromList(i,fields),settings)
        if(numtype(v)==0)
            Variable/G $(base+StringFromList(i,keys))=v
        endif
    endfor
End

Function HMH_FigurePanel()
    HMH_Init()
    HMH_FigureInit()
    String wins=HMH_FigureList(),base="root:MHApp:Figure:"
    if(!strlen(wins))
        DoAlert 0,"先に単独表示または比較グラフを作成してください。"
        return -1
    endif
    SVAR last=root:MHApp:lastGraph
    String target=SelectString(WhichListItem(last,wins)>=0,StringFromList(0,wins),last)
    HMH_ReadLayout(target)
    NVAR mode=$(base+"targetMode"),columns=$(base+"columns")
    DoWindow/K HMH_FigureSettings
    NewPanel/N=HMH_FigureSettings/W=(70,70,750,605) as "MH：図のサイズ・凡例・フォント v2.4.0"
    DefaultGUIFont/W=HMH_FigureSettings all={"Segoe UI",12,0}
    PopupMenu target,pos={18,15},size={630,24},title="対象の図",value=HMH_FigureList(),mode=(WhichListItem(target,wins)+1),proc=HMH_LayoutTarget
    GroupBox geometry,pos={14,53},size={650,165},title="1  縦横比を指定する範囲"
    PopupMenu targetMode,pos={28,80},title="範囲",value="描画枠（軸で囲まれた部分）;図全体（凡例・軸ラベルを含む）",mode=mode,proc=HMH_LayoutChoice
    SetVariable widthCM,pos={28,122},size={285,24},title="指定範囲の幅 (cm)",limits={6,60,0.5},value=$(base+"widthCM")
    SetVariable ratio,pos={335,122},size={300,24},title="縦横比（横 ÷ 縦）",limits={0.25,4,0.05},value=$(base+"ratio")
    Button reference,pos={28,170},size={270,28},title="資料の描画枠：12 × 9 cm",proc=HMH_LayoutButton
    Button square,pos={318,170},size={318,28},title="図全体の例：16.5 × 15 cm",proc=HMH_LayoutButton
    GroupBox typography,pos={14,232},size={650,125},title="2  文字・凡例（英数：Times New Roman／日本語：明朝）"
    SetVariable axisFont,pos={28,262},size={285,24},title="軸の文字 (pt)",limits={12,48,1},value=$(base+"axisFont")
    SetVariable legendFont,pos={335,262},size={300,24},title="凡例の文字 (pt)",limits={12,48,1},value=$(base+"legendFont")
    PopupMenu columns,pos={28,306},title="凡例の列数",value="1列;2列;3列",mode=columns,proc=HMH_LayoutChoice
    SetVariable lineWidth,pos={335,306},size={300,24},title="曲線の太さ (pt)",limits={0.25,8,0.25},value=$(base+"lineWidth")
    TitleBox note,pos={20,372},frame=0,title="凡例を上へ配置し、描画枠を縮めずに余白を追加します。\r図全体モードでは、図全体の比率を優先して描画枠の高さを計算します。\r設定の反映では凡例を一覧の名前から作り直します。手動編集後はご注意ください。"
    Button apply,pos={20,452},size={308,32},title="対象の図に設定を反映",proc=HMH_LayoutButton
    Button fit,pos={345,452},size={310,32},title="書式を変えず画面に収める",proc=HMH_LayoutButton
    TitleBox save,pos={20,500},frame=0,title="設定は実験（.pxp）に保存され、次に作る図にも適用されます。"
    return 0
End

Function HMH_LayoutTarget(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2)
        return 0
    endif
    HMH_ReadLayout(pa.popStr)
    NVAR mode=root:MHApp:Figure:targetMode,columns=root:MHApp:Figure:columns
    PopupMenu targetMode,win=HMH_FigureSettings,mode=mode
    PopupMenu columns,win=HMH_FigureSettings,mode=columns
    return 0
End

Function HMH_LayoutChoice(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        Variable/G $("root:MHApp:Figure:"+pa.ctrlName)=pa.popNum
        if(cmpstr(pa.ctrlName,"targetMode")==0)
            SVAR win=root:MHApp:Figure:target
            if(WinType(win)==1)
                // Switching the measurement scope starts from the actual figure,
                // so the previous plot width is not mistaken for total width.
                DoUpdate/W=$win
                if(pa.popNum==1)
                    GetWindow $win psize
                else
                    GetWindow $win gsize
                endif
                Variable w=V_right-V_left,h=V_bottom-V_top
                Variable/G root:MHApp:Figure:widthCM=w*2.54/72
                Variable/G root:MHApp:Figure:ratio=w/h
            endif
        endif
    endif
    return 0
End

Function HMH_LayoutButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String base="root:MHApp:Figure:"
    SVAR win=$(base+"target")
    NVAR mode=$(base+"targetMode"),widthCM=$(base+"widthCM"),ratio=$(base+"ratio")
    strswitch(ba.ctrlName)
        case "reference":
            mode=1; widthCM=12; ratio=4/3
            PopupMenu targetMode,win=HMH_FigureSettings,mode=1
            break
        case "square":
            mode=2; widthCM=16.5; ratio=16.5/15
            PopupMenu targetMode,win=HMH_FigureSettings,mode=2
            break
        case "fit":
            HMH_FitFigure(win)
            break
        case "apply":
            Variable result=HMH_ApplyDefaults(win)
            if(result!=0)
                DoAlert 0,"このサイズには文字・凡例と描画枠が収まりません。幅を広げる、縦横比を小さくする、または凡例の列数を変更してください。図は変更していません。"
            endif
            break
    endswitch
    return 0
End

Function HMH_Guide()
    DoWindow/K HMHGuide
    NewNotebook/N=HMHGuide/F=1/V=1/W=(80,60,820,640) as "MH VSM Analyzer v2.4.0：使い方"
    Notebook HMHGuide font="Segoe UI",fSize=13
    Notebook HMHGuide text="管理：MH解析 → データ・グラフ管理を開く。フォルダを作成し、選んだ場所へVSMを追加できます。測定・フォルダ・図の名前変更と移動は、測定Waveや既存図の書式を変更しません。\r保存した図はツリーから開けます。矢印の数値調整は補助機能のチェックを入れた場合だけ使えます。\r\r"
    Notebook HMHGuide text="MH VSM Analyzer v2.4.0\r\r1  MH解析 → 操作パネルを開く → VSMを追加。\r磁場をOeからkOeへ変換し、磁化を試料質量(g)で割ってemu/gにします。元のH_Oe・M_emuも保持します。\r\r"
    Notebook HMHGuide text="2  比較する試料をチェックし、名前をダブルクリックして条件名に変更します。\r例：900°C pre、1200°C、x = 0.2。『チェック分を比較』で図を作成します。\r\r"
    Notebook HMHGuide text="3  図のサイズ・凡例・フォントを開きます。\r描画枠モード：枠を12×9 cmなどに保ち、凡例の余白を外へ追加します。\r図全体モード：凡例・軸ラベルを含む白いキャンバスの横÷縦を指定します。タイトルバーは含みません。両方の比率を同時に固定する設定ではありません。\r\r"
    Notebook HMHGuide text="4  軸・目盛り・桁数。比較範囲は実測値に合わせて指定してください。\r例：磁場 -15〜15 kOe、主目盛り5 kOe、磁化 -80〜80 emu/g、主目盛り40 emu/g。小目盛りは0で非表示です。\r\r"
    Notebook HMHGuide text="新規図は整数の主目盛りを設定します。英数字はTimes New Roman、日本語の凡例は明朝体です。既存図も『見本の書式にする』で戻せます。\r\r"
    Notebook HMHGuide text="完成図はIgor標準のグラフです。軸・曲線・凡例はダブルクリックで編集でき、Graphメニューの機能も使えます。凡例は列ごとの編集です。『設定を反映』を押すと、この拡張の凡例は一覧の名前に戻ります。\r\r"
    Notebook HMHGuide text="図が大きい場合は『書式を変えず画面に収める』で表示倍率だけを変更します。出力寸法とフォントは保たれます。\rFile → Save Experimentで.pxpに保存します。元のVSMファイルを消しても保存済みWaveは残ります。\rこの版は作図書式の改良です。Ms・Hc等の新しい解析や平滑化は追加していません。\r"
    return 0
End
