#pragma TextEncoding = "UTF-8"
// ---- MH_VSM_Analyzer ----
#pragma rtGlobals=3
#pragma version=2.20

// MH VSM analyser for Igor Pro 9. Independent of MT and SQUID add-ons.
// Source .VSM files are read only. All imported waves live in root:MHApp.

Menu "MH解析"
    "データ・グラフ管理を開く", HMG_OpenManager()
    "操作パネルを開く", HMH_OpenPanel()
    "VSMファイルを追加", HMH_ChooseFiles()
    "軸・目盛り・桁数を調整", HMH_AxisDialog()
    "図のサイズ・凡例・フォント", HMH_FigurePanel()
    "見本の書式を現在の図に適用", HMH_ReferenceLast()
    "書式を変えず画面に収める", HMH_FitLastFigure()
    "使い方", HMH_Guide()
End

Function HMH_Init()
    NewDataFolder/O root:MHApp
    NVAR/Z count=root:MHApp:count
    if (!NVAR_Exists(count))
        Variable/G root:MHApp:count=0
        String/G root:MHApp:lastGraph=""
        Make/O/T/N=1 root:MHApp:paths,root:MHApp:names
        Make/O/T/N=(1,2) root:MHApp:listText
        Make/O/N=(1,2) root:MHApp:listState
        Wave/T listText=root:MHApp:listText
        Wave listState=root:MHApp:listState
        listText=""
        listState=0
        listText[0][1]="VSMファイルを追加してください"
    endif
End

Function HMH_OpenPanel()
    HMH_Init()
    if (WinType("HMH_Panel")!=0)
        if(cmpstr(GetUserData("HMH_Panel","","HMHPanelVersion"),"2.2.0")==0)
            DoWindow/F HMH_Panel
            return 0
        endif
        // Recreate a v2.01 panel when explicitly opened from the menu.
        DoWindow/K HMH_Panel
    endif
    NewPanel/N=HMH_Panel/W=(80,80,730,535) as "MH VSM Analyzer v2.2.0"
    SetWindow HMH_Panel userdata(HMHPanelVersion)="2.2.0"
    DefaultGUIFont/W=HMH_Panel all={"Segoe UI",12,0}
    TitleBox title0,win=HMH_Panel,pos={16,12},title="MH：比較に入れる行をチェック／名前はダブルクリックで変更"
    ListBox dataList,win=HMH_Panel,pos={16,42},size={615,235},listWave=root:MHApp:listText,selWave=root:MHApp:listState,mode=1,widths={48,550},proc=HMH_List
    Button add,win=HMH_Panel,pos={16,295},size={100,28},title="VSMを追加",proc=HMH_Button
    Button one,win=HMH_Panel,pos={125,295},size={115,28},title="選択行を単独表示",proc=HMH_Button
    Button compare,win=HMH_Panel,pos={249,295},size={120,28},title="チェック分を比較",proc=HMH_Button
    Button axes,win=HMH_Panel,pos={378,295},size={130,28},title="軸・目盛り・桁数",proc=HMH_Button
    Button figure,win=HMH_Panel,pos={16,338},size={235,30},title="図のサイズ・凡例・フォント",proc=HMH_Button
    Button referenceStyle,win=HMH_Panel,pos={263,338},size={180,30},title="見本の書式にする",proc=HMH_Button
    Button manager,win=HMH_Panel,pos={16,378},size={235,30},title="データ・グラフ管理",proc=HMH_Button
    Button guide,win=HMH_Panel,pos={455,338},size={170,30},title="使い方を開く",proc=HMH_Button
    TitleBox saveHint,win=HMH_Panel,pos={16,420},frame=0,title="保存：File → Save Experiment（.pxp）。完成図はIgor上で編集できます。"
    return 0
End

Function HMH_Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode!=2)
        return 0
    endif
    strswitch (ba.ctrlName)
        case "add":
            HMH_ChooseFiles()
            break
        case "one":
            HMH_ShowSelected()
            break
        case "compare":
            HMH_DrawGraph(-1)
            break
        case "axes":
            HMH_AxisDialog()
            break
        case "figure":
            HMH_FigurePanel()
            break
        case "manager":
            HMG_OpenManager()
            break
        case "guide":
            HMH_Guide()
            break
        case "referenceStyle":
            HMH_ReferenceLast()
            break
    endswitch
    return 0
End

Function HMH_List(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if (lba.eventCode==7)
        HMH_SaveNames()
    endif
    return 0
End

Function HMH_SaveNames()
    HMH_Init()
    NVAR count=root:MHApp:count
    Wave/T names=root:MHApp:names
    Wave/T listText=root:MHApp:listText
    Variable i
    for (i=0;i<count;i+=1)
        if (strlen(listText[i][1])>0)
            names[i]=listText[i][1]
        endif
    endfor
End

Function HMH_ChooseFiles()
    HMH_Init()
    String folderUID=HMG_TargetFolder()
    if(strlen(folderUID)==0)
        return -1
    endif
    Variable refNum,i
    String paths,filePath
    Open/D/R/MULT=1/M="MH の .VSM を選択" refNum
    paths=S_fileName
    if (strlen(paths)==0)
        return 0
    endif
    for (i=0;i<ItemsInList(paths,"\r");i+=1)
        filePath=StringFromList(i,paths,"\r")
        if (strlen(filePath)>0)
            HMH_Import(filePath,folderUID=folderUID)
        endif
    endfor
    return 0
End

Function HMH_Import(filePath,[folderUID])
    String filePath,folderUID
    if(ParamIsDefault(folderUID))
        folderUID=HMG_TargetFolder()
    endif
    if(HMG_Init()!=0 || HMG_Find("folder",folderUID)<0)
        return -3
    endif
    HMH_Init()
    String savedDF=GetDataFolder(1)
    String line,low,runName,runPath,label,winPath
    Variable refNum=0,n=0,cap=2048,found=0,mass=NaN,h,m
    NewDataFolder/O root:MHApp
    SetDataFolder root:MHApp
    runName=UniqueName("Run",11,0)
    NewDataFolder/S $runName
    runPath=GetDataFolder(1)
    Make/O/D/N=(cap) H_Oe,M_emu
    Open/R/Z=1 refNum as filePath
    if (V_flag!=0)
        Print "MH: ファイルを開けません: ",filePath
        SetDataFolder savedDF
        KillDataFolder/Z $runPath
        return -1
    endif
    do
        FReadLine refNum,line
        if (strlen(line)==0)
            break
        endif
        low=LowerStr(line)
        if (strsearch(low,"sample weight=",0)==0)
            mass=str2num(StringFromList(1,line,","))
        endif
        if (!found)
            if (strsearch(low,"h(oe)",0)>=0 && strsearch(low,"m(emu)",0)>=0)
                found=1
            endif
            continue
        endif
        h=str2num(StringFromList(1,line,","))
        m=str2num(StringFromList(2,line,","))
        if (numtype(h)!=0 || numtype(m)!=0)
            continue
        endif
        if (n>=cap)
            cap+=2048
            Redimension/N=(cap) H_Oe,M_emu
        endif
        H_Oe[n]=h
        M_emu[n]=m
        n+=1
    while (1)
    Close refNum
    if (!found || n<5 || numtype(mass)!=0 || mass<=0)
        Print "MH: 列見出し・点数・試料質量を確認してください: ",filePath
        SetDataFolder savedDF
        KillDataFolder/Z $runPath
        return -2
    endif
    Redimension/N=(n) H_Oe,M_emu
    Make/O/D/N=(n) H_kOe,M_emu_g
    H_kOe=H_Oe/1000
    M_emu_g=M_emu/mass
    Note/K H_kOe,"source="+filePath+"; Oe / 1000"
    Note/K M_emu_g,"source="+filePath+"; emu / sample mass(g)"
    Variable/G sampleMassG=mass
    String/G sourceFile=filePath
    winPath=ParseFilePath(5,filePath,"\\",0,0)
    label=ParseFilePath(3,winPath,"\\",0,0)
    SetDataFolder savedDF
    NVAR count=root:MHApp:count
    Wave/T paths=root:MHApp:paths
    Wave/T names=root:MHApp:names
    Wave/T listText=root:MHApp:listText
    Wave listState=root:MHApp:listState
    HMH_SaveNames()
    Redimension/N=(count+1) paths,names
    Redimension/N=(count+1,2) listText,listState
    paths[count]=runPath
    names[count]=label
    listText[count][0]="比較"
    listText[count][1]=label
    listState[count][0]=32
    listState[count][1]=6
    count+=1
    HMG_RegisterImport(count-1,folderUID)
    Print "MH: ",label," / ",n," 点 / ",mass," g"
    if (WinType("HMH_Panel")==0)
        HMH_OpenPanel()
    endif
    return 0
End

Function HMH_ShowSelected()
    if (WinType("HMH_Panel")==0)
        return -1
    endif
    ControlInfo/W=HMH_Panel dataList
    NVAR count=root:MHApp:count
    if (V_Value<0 || V_Value>=count)
        DoAlert 0,"表示する行を選んでください。"
        return -1
    endif
    HMH_SaveNames()
    return HMH_DrawGraph(V_Value)
End

// index=-1: checked datasets; index>=0: one dataset.
Function HMH_DrawGraph(index)
    Variable index
    HMH_Init()
    HMH_SaveNames()
    NVAR count=root:MHApp:count
    Wave/T paths=root:MHApp:paths
    Wave/T names=root:MHApp:names
    Wave listState=root:MHApp:listState
    Variable i,j,shown=0,lo=inf,hi=-inf,xlo=inf,xhi=-inf,pad
    String graphName,traces,trace,runPath
    if (index>=count)
        return -1
    endif
    if (index<0)
        graphName=UniqueName("MH_Compare",6,0)
    else
        graphName=UniqueName("MH_Single",6,0)
    endif
    for (i=0;i<count;i+=1)
        if (index>=0 && i!=index)
            continue
        endif
        if (index<0 && !(listState[i][0] & 16))
            continue
        endif
        runPath=paths[i]
        Wave/Z x=$(runPath+"H_kOe")
        Wave/Z y=$(runPath+"M_emu_g")
        if (!WaveExists(x) || !WaveExists(y))
            continue
        endif
        if (shown==0)
            Display/N=$graphName/W=(100,70,900,650) y vs x
        else
            AppendToGraph/W=$graphName y vs x
        endif
        traces=TraceNameList(graphName,";",1)
        trace=StringFromList(ItemsInList(traces)-1,traces)
        HMH_Color(graphName,trace,shown,index>=0)
        SetWindow $graphName userdata($("HMHLabel_"+trace))=names[i]
        for (j=0;j<numpnts(y);j+=1)
            if (numtype(y[j])==0 && numtype(x[j])==0)
                lo=min(lo,y[j])
                hi=max(hi,y[j])
                xlo=min(xlo,x[j])
                xhi=max(xhi,x[j])
            endif
        endfor
        shown+=1
    endfor
    if (shown==0)
        DoAlert 0,"比較するデータをチェックしてください。"
        return -1
    endif
    ModifyGraph/W=$graphName mirror=1,tick=2,standoff=0
    ModifyGraph/W=$graphName zero(bottom)=1,zero(left)=1
    Label/W=$graphName bottom "Magnetic field (kOe)"
    Label/W=$graphName left "Magnetization (emu/g)"
    pad=max(0.1*(hi-lo),1e-9)
    SetAxis/W=$graphName left lo-pad,hi+pad
    pad=max(0.03*(xhi-xlo),1e-9)
    SetAxis/W=$graphName bottom xlo-pad,xhi+pad
    SVAR lastGraph=root:MHApp:lastGraph
    lastGraph=graphName
    SetWindow $graphName userdata(HMHFigure)="2.2.0"
    HMH_FigureInit()
    if(HMH_ApplyDefaults(graphName)!=0)
        // A saved whole-canvas size may be too small for this sample's longer name.
        // Keep the new graph usable, with the lab's 12 x 9 cm plot rectangle.
        HMH_Layout(graphName,1,12,4/3,24,24,2,2.5)
        Print "MH: 指定サイズに凡例が収まらないため、この図は描画枠12×9 cmで作成しました。"
    endif
    HMH_NewGraphAxes(graphName,xlo,xhi,lo,hi)
    HMH_FitFigure(graphName)
    HMG_AdoptGraph(graphName)
    SetIgorHook BeforeExperimentSaveHook=HMG_BeforeSave
    HMG_Refresh()
    return shown
End

Function HMH_Color(graphName,trace,index,isSingle)
    String graphName,trace
    Variable index,isSingle
    if (isSingle)
        ModifyGraph/W=$graphName rgb($trace)=(0,0,0)
    else
        switch(mod(index,6))
            case 0:
                ModifyGraph/W=$graphName rgb($trace)=(65535,0,0)
                break
            case 1:
                ModifyGraph/W=$graphName rgb($trace)=(47000,47000,0)
                break
            case 2:
                ModifyGraph/W=$graphName rgb($trace)=(0,42000,0)
                break
            case 3:
                ModifyGraph/W=$graphName rgb($trace)=(0,0,55000)
                break
            case 4:
                ModifyGraph/W=$graphName rgb($trace)=(60000,13000,55000)
                break
            default:
                ModifyGraph/W=$graphName rgb($trace)=(36000,0,55000)
        endswitch
    endif
End

Function HMH_AxisDialog()
    return HMH_AxisPanel()
End

// ---- mh_figure ----

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
    Display/HIDE=1/N=$stage x
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
    String wins=WinList("*",";","WIN:1"),out="",win
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
    NewPanel/N=HMH_FigureSettings/W=(70,70,750,605) as "MH：図のサイズ・凡例・フォント v2.2.0"
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
    NewNotebook/N=HMHGuide/F=1/V=1/W=(80,60,820,640) as "MH VSM Analyzer v2.2.0：使い方"
    Notebook HMHGuide font="Segoe UI",fSize=13
    Notebook HMHGuide text="管理：MH解析 → データ・グラフ管理を開く。フォルダを作成し、選んだ場所へVSMを追加できます。測定・フォルダ・図の名前変更と移動は、測定Waveや既存図の書式を変更しません。\r保存した図はツリーから開けます。矢印の数値調整は補助機能のチェックを入れた場合だけ使えます。\r\r"
    Notebook HMHGuide text="MH VSM Analyzer v2.2.0\r\r1  MH解析 → 操作パネルを開く → VSMを追加。\r磁場をOeからkOeへ変換し、磁化を試料質量(g)で割ってemu/gにします。元のH_Oe・M_emuも保持します。\r\r"
    Notebook HMHGuide text="2  比較する試料をチェックし、名前をダブルクリックして条件名に変更します。\r例：900°C pre、1200°C、x = 0.2。『チェック分を比較』で図を作成します。\r\r"
    Notebook HMHGuide text="3  図のサイズ・凡例・フォントを開きます。\r描画枠モード：枠を12×9 cmなどに保ち、凡例の余白を外へ追加します。\r図全体モード：凡例・軸ラベルを含む白いキャンバスの横÷縦を指定します。タイトルバーは含みません。両方の比率を同時に固定する設定ではありません。\r\r"
    Notebook HMHGuide text="4  軸・目盛り・桁数。比較範囲は実測値に合わせて指定してください。\r例：磁場 -15〜15 kOe、主目盛り5 kOe、磁化 -80〜80 emu/g、主目盛り40 emu/g。小目盛りは0で非表示です。\r\r"
    Notebook HMHGuide text="新規図は整数の主目盛りを設定します。英数字はTimes New Roman、日本語の凡例は明朝体です。既存図も『見本の書式にする』で戻せます。\r\r"
    Notebook HMHGuide text="完成図はIgor標準のグラフです。軸・曲線・凡例はダブルクリックで編集でき、Graphメニューの機能も使えます。凡例は列ごとの編集です。『設定を反映』を押すと、この拡張の凡例は一覧の名前に戻ります。\r\r"
    Notebook HMHGuide text="図が大きい場合は『書式を変えず画面に収める』で表示倍率だけを変更します。出力寸法とフォントは保たれます。\rFile → Save Experimentで.pxpに保存します。元のVSMファイルを消しても保存済みWaveは残ります。\rこの版は作図書式の改良です。Ms・Hc等の新しい解析や平滑化は追加していません。\r"
    return 0
End

// ---- mh_axis ----

// MH v2.1.2: non-modal axis editor. Tick digits are independent for X and Y.
Function HMH_AxisDigits(step)
    Variable step
    Variable d
    for(d=0;d<6;d+=1)
        if(abs(step*10^d-round(step*10^d))<1e-7)
            return d
        endif
    endfor
    return 6
End

Function HMH_NiceStep(span)
    Variable span
    Variable raw=span/6,unit=10^floor(log(raw)),m=raw/unit
    if(m<=1)
        return unit
    elseif(m<=2)
        return 2*unit
    elseif(m<=5)
        return 5*unit
    endif
    return 10*unit
End

Function/S HMH_AxisSetting(win,axis,key)
    String win,axis,key
    String info=AxisInfo(win,axis)
    Variable start=strsearch(info,"RECREATION:",0)
    if(start>=0)
        info=info[start+11,inf]
    endif
    String needle=key+"(x)="
    start=strsearch(LowerStr(info),LowerStr(needle),0)
    if(start<0)
        return ""
    endif
    info=info[start+strlen(needle),inf]
    if(cmpstr(info[0],"{")==0)
        return info[0,strsearch(info,"}",0)]
    endif
    return StringFromList(0,info)
End

Function HMH_ReadAxes(win)
    String win
    if(WinType(win)!=1)
        return -1
    endif
    HMH_Init()
    NewDataFolder/O root:MHApp:Axes
    String base="root:MHApp:Axes:",axes="bottom;left",prefix="x;y",axis,pre,tick,minor
    String saved=GetUserData(win,"","HMHAxes")
    String/G $(base+"target")=win
    Variable i,step,digits,exponent
    for(i=0;i<2;i+=1)
        axis=StringFromList(i,axes);pre=StringFromList(i,prefix)
        GetAxis/Q/W=$win $axis
        Variable/G $(base+pre+"Min")=V_min
        Variable/G $(base+pre+"Max")=V_max
        step=HMH_NiceStep(V_max-V_min); digits=-1
        tick=HMH_AxisSetting(win,axis,"manTick")
        if(strsearch(tick,"{",0)>=0)
            tick=ReplaceString("}",ReplaceString("{",tick,""),"")
            exponent=str2num(StringFromList(2,tick,","))
            step=str2num(StringFromList(1,tick,","))*10^exponent
            digits=str2num(StringFromList(3,tick,","))
            if(NumberByKey(pre+"Digits",saved)==-1 && abs(NumberByKey(pre+"Step",saved)-step)<1e-9 && digits==HMH_AxisDigits(step))
                digits=-1
            endif
        endif
        Variable/G $(base+pre+"Step")=step
        Variable/G $(base+pre+"Digits")=digits
        minor=HMH_AxisSetting(win,axis,"manMinor")
        minor=ReplaceString("}",ReplaceString("{",minor,""),"")
        Variable/G $(base+pre+"Minor")=max(0,str2num(StringFromList(0,minor,",")))
        NVAR small=$(base+pre+"Minor")
        if(numtype(small)!=0)
            small=0
        endif
    endfor
    return 0
End

Function HMH_AxisPanel()
    HMH_Init()
    SVAR last=root:MHApp:lastGraph
    String wins=HMH_FigureList(),win=last
    if(WinType(win)!=1)
        win=StringFromList(0,wins)
    endif
    if(HMH_ReadAxes(win)!=0)
        DoAlert 0,"先に単独表示または比較グラフを作ってください。"
        return -1
    endif
    DoWindow/K HMH_AxisSettings
    NewPanel/N=HMH_AxisSettings/W=(60,60,800,577) as "MH：軸・目盛り・小数桁数 v2.2.0"
    DefaultGUIFont/W=HMH_AxisSettings all={"Segoe UI",12,0}
    PopupMenu axisTarget,pos={18,15},title="対象の図",value=HMH_FigureList(),mode=(WhichListItem(win,wins)+1),proc=HMH_AxisTarget
    String base="root:MHApp:Axes:",pre,head
    Variable i,x
    for(i=0;i<2;i+=1)
        pre=StringFromList(i,"x;y");x=18+i*356
        head=SelectString(i,"横軸：Magnetic field (kOe)","縦軸：Magnetization (emu/g)")
        GroupBox $(pre+"Group"),pos={x,54},size={344,253},title=head
        SetVariable $(pre+"Min"),pos={x+14,87},size={310,22},title="最小値",limits={-inf,inf,1},value=$(base+pre+"Min")
        SetVariable $(pre+"Max"),pos={x+14,122},size={310,22},title="最大値",limits={-inf,inf,1},value=$(base+pre+"Max")
        SetVariable $(pre+"Step"),pos={x+14,157},size={310,22},title="主目盛りの間隔",limits={0,inf,1},value=$(base+pre+"Step")
        SetVariable $(pre+"Minor"),pos={x+14,192},size={310,22},title="間に入れる小目盛りの数",limits={0,20,1},value=$(base+pre+"Minor")
        NVAR digits=$(base+pre+"Digits")
        PopupMenu $(pre+"Digits"),pos={x+14,229},title="小数点以下",value="自動（間隔に合わせる）;0桁：15;1桁：15.0;2桁：15.00;3桁：15.000;4桁：15.0000;5桁;6桁",mode=(digits+2),proc=HMH_AxisDecimal
        Button $(pre+"Preset"),pos={x+14,270},size={310,25},title=SelectString(i,"横軸：−15～15、5刻みにする","縦軸：−30～30、10刻みにする"),proc=HMH_AxisButton
    endfor
    Button integers,pos={20,325},size={216,30},title="両軸を整数表示にする",proc=HMH_AxisButton
    Button suggest,pos={250,325},size={466,30},title="数字の重なりを避ける目盛り間隔を提案",proc=HMH_AxisButton
    TitleBox axisHint,pos={22,372},frame=0,title="小数桁数：自動なら5刻みは15、0.5刻みは15.0。小目盛りは0で非表示。\r『提案』と『整数表示』は入力欄を変更します。下の『反映』で図に適用します。"
    Button applyAxes,pos={20,435},size={340,34},title="図へ反映（この画面は開いたまま）",proc=HMH_AxisButton
    Button readAxes,pos={376,435},size={340,34},title="現在の図の設定を読み直す",proc=HMH_AxisButton
    TitleBox axisStatus,pos={22,483},frame=0,title="調整後は『反映』を押してください。測定データと凡例は変更しません。"
    return 0
End

Function HMH_AxisTarget(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        HMH_ReadAxes(pa.popStr)
        HMH_AxisRefresh()
    endif
    return 0
End

Function HMH_AxisRefresh()
    NVAR xd=root:MHApp:Axes:xDigits,yd=root:MHApp:Axes:yDigits
    PopupMenu xDigits,win=HMH_AxisSettings,mode=(xd+2)
    PopupMenu yDigits,win=HMH_AxisSettings,mode=(yd+2)
End

Function HMH_AxisDecimal(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        Variable/G $("root:MHApp:Axes:"+pa.ctrlName)=pa.popNum-2
    endif
    return 0
End

Function HMH_TickTextWidth(win,axis,lo,hi,step,digits)
    String win,axis
    Variable lo,hi,step,digits
    String info=AxisInfo(win,axis),font=StringByKey("FONT",info),text,fmt="%."+num2istr(digits)+"f"
    Variable size=NumberByKey("FONTSIZE",info),i,width=0,value
    // Include endpoints as a conservative bound; check all ticks up to 500.
    for(i=-2;i<min(500,ceil((hi-lo)/step)+1);i+=1)
        value=ceil(lo/step)*step+i*step
        if(i==-2)
            value=lo
        elseif(i==-1)
            value=hi
        endif
        sprintf text,fmt,value
        // Igor's long minus is wider than the ASCII hyphen used by sprintf.
        // Measure the displayed sign so negative labels do not touch the title.
        text=ReplaceString("-",text,"−")
        width=max(width,FontSizeStringWidth(font,size*ScreenResolution/72,0,text)*72/ScreenResolution)
    endfor
    return width
End

Function HMH_AxisSuggest()
    String base="root:MHApp:Axes:"
    SVAR win=$(base+"target")
    NVAR xmin=$(base+"xMin"),xmax=$(base+"xMax"),ymin=$(base+"yMin"),ymax=$(base+"yMax")
    NVAR xs=$(base+"xStep"),ys=$(base+"yStep"),xd=$(base+"xDigits"),yd=$(base+"yDigits")
    if(numtype(xmin+xmax+ymin+ymax)!=0 || xmax<=xmin || ymax<=ymin || WinType(win)!=1)
        return -1
    endif
    GetWindow $win psize
    Variable w=V_right-V_left,h=V_bottom-V_top,i,d,spacing,font=NumberByKey("FONTSIZE",AxisInfo(win,"left"))
    xs=HMH_NiceStep(xmax-xmin);ys=HMH_NiceStep(ymax-ymin)
    for(i=0;i<12;i+=1)
        d=SelectNumber(xd<0,xd,HMH_AxisDigits(xs))
        spacing=w*xs/(xmax-xmin)
        if(spacing>=HMH_TickTextWidth(win,"bottom",xmin,xmax,xs,d)+10)
            break
        endif
        xs=HMH_NiceStep(xs*6*1.01)
    endfor
    for(i=0;i<12;i+=1)
        if(h*ys/(ymax-ymin)>=font*1.5)
            break
        endif
        ys=HMH_NiceStep(ys*6*1.01)
    endfor
    return 0
End

Function HMH_ApplyAxes(win,xmin,xmax,xstep,xminor,xdigits,ymin,ymax,ystep,yminor,ydigits)
    String win
    Variable xmin,xmax,xstep,xminor,xdigits,ymin,ymax,ystep,yminor,ydigits
    if(WinType(win)!=1 || numtype(xmin+xmax+xstep+xminor+xdigits+ymin+ymax+ystep+yminor+ydigits)!=0)
        return -1
    endif
    if(xmax<=xmin || ymax<=ymin || xstep<=0 || ystep<=0 || xminor<0 || yminor<0 || xminor>20 || yminor>20 || xminor!=round(xminor) || yminor!=round(yminor))
        return -1
    endif
    if(xdigits< -1 || ydigits< -1 || xdigits>6 || ydigits>6 || xdigits!=round(xdigits) || ydigits!=round(ydigits))
        return -1
    endif
    Variable xd=SelectNumber(xdigits<0,xdigits,HMH_AxisDigits(xstep)),yd=SelectNumber(ydigits<0,ydigits,HMH_AxisDigits(ystep))
    if(xstep*10^xd<1-1e-8 || ystep*10^yd<1-1e-8 || (xmax-xmin)/xstep>500 || (ymax-ymin)/ystep>500)
        return -2
    endif
    // Reserve room for numeric labels without rebuilding user-edited legends.
    GetWindow $win psize
    Variable pw=V_right-V_left,ph=V_bottom-V_top,leftMargin=V_left
    Variable plotRight=V_right,topMargin=V_top,bottomOfPlot=V_bottom
    GetWindow $win gsize
    Variable cw=V_right-V_left,ch=V_bottom-V_top,rightMargin=cw-plotRight
    // Read fixed physical margins from the native recreation, not the pixel-rounded
    // window rectangle (which changes with monitor DPI).
    String rec=WinRecreation(win,0),marginKeys="left;right;top;bottom",key
    Make/FREE/D/N=4 margins
    margins[0]=leftMargin;margins[1]=rightMargin;margins[2]=topMargin;margins[3]=ch-bottomOfPlot
    Variable k,offset,value
    for(k=0;k<4;k+=1)
        key="margin("+StringFromList(k,marginKeys)+")="
        offset=strsearch(rec,key,0)
        if(offset>=0)
            value=str2num(rec[offset+strlen(key),inf])
            if(numtype(value)==0 && value>0)
                margins[k]=value
            endif
        endif
    endfor
    leftMargin=margins[0];rightMargin=margins[1];topMargin=margins[2]
    Variable font=NumberByKey("FONTSIZE",AxisInfo(win,"left"))
    Variable yw=HMH_TickTextWidth(win,"left",ymin,ymax,ystep,yd)
    Variable xw=HMH_TickTextWidth(win,"bottom",xmin,xmax,xstep,xd)
    Variable newLeft=ceil(max(leftMargin,yw+font*1.5+28)),newRight=ceil(max(rightMargin,xw/2+8))
    Variable whole=NumberByKey("mode",GetUserData(win,"","HMHLayout"))==2
    if(whole)
        String layout=GetUserData(win,"","HMHLayout")
        Variable canvasW=NumberByKey("widthCM",layout)*72/2.54,canvasH=canvasW/NumberByKey("ratio",layout)
        pw=canvasW-newLeft-newRight
        ph=canvasH-topMargin-margins[3]
        if(pw<font*5)
            return -3
        endif
    else
        // Preserve the native physical dimensions rather than rounded screen pixels.
        offset=strsearch(rec,"width=",0)
        if(offset>=0 && str2num(rec[offset+6,inf])>0)
            pw=str2num(rec[offset+6,inf])
        endif
        offset=strsearch(rec,"height=",0)
        if(offset>=0 && str2num(rec[offset+7,inf])>0)
            ph=str2num(rec[offset+7,inf])
        endif
    endif
    SetAxis/W=$win bottom xmin,xmax
    SetAxis/W=$win left ymin,ymax
    ModifyGraph/W=$win manTick(bottom)={0,xstep,0,xd},manMinor(bottom)={xminor,0}
    ModifyGraph/W=$win manTick(left)={0,ystep,0,yd},manMinor(left)={yminor,0}
    ModifyGraph/W=$win width=pw,height=ph,margin(left)=newLeft,margin(right)=newRight
    ModifyGraph/W=$win lblPosMode(left)=3,lblPos(left)=(yw+font+18)
    DoUpdate/W=$win
    // Keep physical canvas dimensions; a screen rectangle is pixel-rounded.
    SetWindow $win userdata(HMHCanvasWidth)=num2str(pw+newLeft+newRight)
    SetWindow $win userdata(HMHCanvasHeight)=num2str(ph+topMargin+margins[3])
    String settings
    sprintf settings,"xStep:%.12g;yStep:%.12g;xDigits:%d;yDigits:%d;",xstep,ystep,xdigits,ydigits
    SetWindow $win userdata(HMHAxes)=settings
    return 0
End

Function HMH_AxisButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String base="root:MHApp:Axes:"
    SVAR win=$(base+"target")
    NVAR xmin=$(base+"xMin"),xmax=$(base+"xMax"),xs=$(base+"xStep"),xm=$(base+"xMinor"),xd=$(base+"xDigits")
    NVAR ymin=$(base+"yMin"),ymax=$(base+"yMax"),ys=$(base+"yStep"),ym=$(base+"yMinor"),yd=$(base+"yDigits")
    Variable result=0
    strswitch(ba.ctrlName)
        case "integers":
            xd=0;yd=0
            HMH_AxisRefresh()
            break
        case "suggest":
            result=HMH_AxisSuggest()
            break
        case "xPreset":
            xmin=-15;xmax=15;xs=5;xm=0;xd=0
            HMH_AxisRefresh()
            break
        case "yPreset":
            ymin=-30;ymax=30;ys=10;ym=0;yd=0
            HMH_AxisRefresh()
            break
        case "readAxes":
            result=HMH_ReadAxes(win)
            HMH_AxisRefresh()
            break
        case "applyAxes":
            result=HMH_ApplyAxes(win,xmin,xmax,xs,xm,xd,ymin,ymax,ys,ym,yd)
            break
    endswitch
    String status="入力欄を更新しました。『図へ反映』で適用します。"
    if(cmpstr(ba.ctrlName,"applyAxes")==0 && result==0)
        status="反映しました。この画面を開いたまま続けて調整できます。"
    elseif(result==-2)
        status="桁数が不足しているか目盛りが多すぎます。小数桁を増やすか間隔を広げてください。"
    elseif(result==-3)
        status="図全体の幅が足りません。図のサイズ設定で幅を広げてください。"
    elseif(result!=0)
        status="範囲・間隔・桁数を確認してください。最小値＜最大値、間隔＞0です。"
    endif
    TitleBox axisStatus,win=HMH_AxisSettings,title=status
    return 0
End

// ---- mh_store ----

// Persistent identities and logical folders. Raw waves never move during a move.
Function HMG_Init()
    HMH_Init()
    NVAR/Z schema=root:MHApp:Manager:schemaVersion
    if(NVAR_Exists(schema))
        if(schema!=1)
            Print "MH: この管理データの版には対応していません。"
            return -1
        endif
        return HMG_SyncDatasets()
    endif
    NVAR count=root:MHApp:count
    Wave/T paths=root:MHApp:paths,names=root:MHApp:names
    Wave state=root:MHApp:listState
    if(count<0 || count!=round(count) || numpnts(paths)<count || numpnts(names)<count || DimSize(state,0)<count)
        Print "MH: 既存一覧が不整合のため管理データを作成しません。"
        return -1
    endif
    Variable i,j
    for(i=0;i<count;i+=1)
        if(!DataFolderExists(paths[i]))
            Print "MH: 測定フォルダが見つかりません: ",paths[i]
            return -1
        endif
        for(j=0;j<i;j+=1)
            if(cmpstr(paths[i],paths[j])==0)
                Print "MH: 同じ測定フォルダが重複登録されています。"
                return -1
            endif
        endfor
    endfor
    NewDataFolder/O root:MHApp:Manager
    NewDataFolder/O root:MHApp:Manager:Graphs
    NewDataFolder/O root:MHApp:Manager:Scratch
    Make/O/T/N=(1,4) root:MHApp:Manager:folders
    Wave/T folders=root:MHApp:Manager:folders
    folders[0][0]="home";folders[0][1]="";folders[0][2]="測定・グラフ";folders[0][3]="1"
    Make/O/T/N=0 root:MHApp:Manager:datasetUID,root:MHApp:Manager:datasetFolder
    Make/O/T/N=(0,4) root:MHApp:Manager:graphs
    String/G root:MHApp:Manager:selectedUID="home"
    String/G root:MHApp:Manager:selectedKind="folder"
    String/G root:MHApp:Manager:importFolder="home"
    Variable/G root:MHApp:Manager:serial=0
    Variable/G root:MHApp:Manager:busy=0
    Variable/G root:MHApp:Manager:arrowOption=0
    Variable/G root:MHApp:Manager:schemaVersion=1
    return HMG_SyncDatasets()
End

Function HMG_SyncDatasets()
    NVAR count=root:MHApp:count
    Wave/T paths=root:MHApp:paths,names=root:MHApp:names
    Wave/T/Z ids=root:MHApp:Manager:datasetUID,parents=root:MHApp:Manager:datasetFolder
    if(!WaveExists(ids) || !WaveExists(parents) || numpnts(ids)>count || numpnts(parents)!=numpnts(ids) || numpnts(paths)<count || numpnts(names)<count)
        Print "MH: 管理一覧と測定一覧が一致しません。"
        return -1
    endif
    Variable i,n=numpnts(ids)
    for(i=n;i<count;i+=1)
        if(!DataFolderExists(paths[i]))
            return -1
        endif
    endfor
    if(n<count)
        Redimension/N=(count) ids,parents
        for(i=n;i<count;i+=1)
            ids[i]=HMG_NewUID("d")
            parents[i]="home"
        endfor
    endif
    return 0
End

Function/S HMG_NewUID(prefix)
    String prefix
    NVAR serial=root:MHApp:Manager:serial
    String uid
    do
        serial+=1
        sprintf uid,"%s_%.0f_%.0f",prefix,DateTime,serial
    while(HMG_Find("folder",uid)>=0 || HMG_Find("data",uid)>=0 || HMG_Find("graph",uid)>=0)
    return uid
End

Function HMG_Find(kind,uid)
    String kind,uid
    Variable i
    if(cmpstr(kind,"data")==0)
        Wave/T/Z ids=root:MHApp:Manager:datasetUID
        if(WaveExists(ids))
            for(i=0;i<numpnts(ids);i+=1)
                if(cmpstr(ids[i],uid)==0)
                    return i
                endif
            endfor
        endif
    else
        String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
        Wave/T/Z records=$path
        if(WaveExists(records))
            for(i=0;i<DimSize(records,0);i+=1)
                if(cmpstr(records[i][0],uid)==0)
                    return i
                endif
            endfor
        endif
    endif
    return -1
End

Function/S HMG_Name(kind,uid)
    String kind,uid
    Variable i=HMG_Find(kind,uid)
    if(i<0)
        return ""
    endif
    if(cmpstr(kind,"data")==0)
        Wave/T names=root:MHApp:names
        return names[i]
    endif
    String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
    Wave/T records=$path
    return records[i][2]
End

Function/S HMG_Parent(kind,uid)
    String kind,uid
    Variable i=HMG_Find(kind,uid)
    if(i<0)
        return ""
    endif
    if(cmpstr(kind,"data")==0)
        Wave/T parents=root:MHApp:Manager:datasetFolder
        return parents[i]
    endif
    String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
    Wave/T records=$path
    return records[i][1]
End

Function HMG_NameAvailable(kind,parent,name,exceptUID)
    String kind,parent,name,exceptUID
    if(strlen(TrimString(name))==0 || strsearch(name,"\r",0)>=0 || strsearch(name,"\n",0)>=0)
        return 0
    endif
    Variable i,n
    String uid
    if(cmpstr(kind,"data")==0)
        Wave/T ids=root:MHApp:Manager:datasetUID
        n=numpnts(ids)
        for(i=0;i<n;i+=1)
            uid=ids[i]
            if(cmpstr(uid,exceptUID)!=0 && cmpstr(HMG_Parent(kind,uid),parent)==0 && cmpstr(HMG_Name(kind,uid),name)==0)
                return 0
            endif
        endfor
    else
        String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
        Wave/T records=$path
        for(i=0;i<DimSize(records,0);i+=1)
            if(cmpstr(records[i][0],exceptUID)!=0 && cmpstr(records[i][1],parent)==0 && cmpstr(records[i][2],name)==0)
                return 0
            endif
        endfor
    endif
    return 1
End

Function/S HMG_AddFolder(parent,name)
    String parent,name
    if(HMG_Init()!=0 || HMG_Find("folder",parent)<0 || !HMG_NameAvailable("folder",parent,name,""))
        return ""
    endif
    String uid=HMG_NewUID("f")
    Wave/T folders=root:MHApp:Manager:folders
    Variable n=DimSize(folders,0)
    Redimension/N=(n+1,4) folders
    folders[n][0]=uid;folders[n][1]=parent;folders[n][2]=name;folders[n][3]="1"
    return uid
End

Function HMG_Rename(kind,uid,name)
    String kind,uid,name
    if(HMG_Init()!=0)
        return -1
    endif
    Variable i=HMG_Find(kind,uid)
    if(i<0 || !HMG_NameAvailable(kind,HMG_Parent(kind,uid),name,uid))
        return -1
    endif
    if(cmpstr(kind,"data")==0)
        Wave/T names=root:MHApp:names,listText=root:MHApp:listText
        names[i]=name;listText[i][1]=name
    else
        String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
        Wave/T records=$path
        records[i][2]=name
    endif
    return 0
End

Function HMG_Move(kind,uid,parent)
    String kind,uid,parent
    if(HMG_Init()!=0 || cmpstr(uid,"home")==0)
        return -1
    endif
    Variable i=HMG_Find(kind,uid),limit=0
    if(i<0 || HMG_Find("folder",parent)<0 || !HMG_NameAvailable(kind,parent,HMG_Name(kind,uid),uid))
        return -1
    endif
    String ancestor=parent
    Wave/T folders=root:MHApp:Manager:folders
    if(cmpstr(kind,"folder")==0)
        do
            if(cmpstr(ancestor,uid)==0 || limit>DimSize(folders,0))
                return -1
            endif
            ancestor=HMG_Parent("folder",ancestor)
            limit+=1
        while(strlen(ancestor))
    endif
    if(cmpstr(kind,"data")==0)
        Wave/T parents=root:MHApp:Manager:datasetFolder
        parents[i]=parent
    else
        String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
        Wave/T records=$path
        records[i][1]=parent
    endif
    return 0
End

Function/S HMG_TargetFolder()
    if(HMG_Init()!=0)
        return ""
    endif
    SVAR target=root:MHApp:Manager:importFolder
    if(HMG_Find("folder",target)<0)
        target="home"
    endif
    return target
End

Function HMG_RegisterImport(index,parent)
    Variable index
    String parent
    if(HMG_Init()!=0 || HMG_Find("folder",parent)<0)
        return -1
    endif
    Wave/T parents=root:MHApp:Manager:datasetFolder
    if(index<0 || index>=numpnts(parents))
        return -1
    endif
    parents[index]=parent
    HMG_Refresh()
    return 0
End

Function/S HMG_FolderPath(uid)
    String uid
    String result="",name
    Variable i=0
    Wave/T folders=root:MHApp:Manager:folders
    do
        name=HMG_Name("folder",uid)
        if(strlen(name)==0 || i>DimSize(folders,0))
            return "[所属不明]"
        endif
        result=name+SelectString(strlen(result)>0,""," / ")+result
        uid=HMG_Parent("folder",uid)
        i+=1
    while(strlen(uid))
    return result
End

// ---- mh_graph_store ----

Function/S HMG_GraphPath(uid)
    String uid
    return "root:MHApp:Manager:Graphs:"+uid+":"
End

Function/S HMG_SnapshotPath(uid)
    String uid
    String base=HMG_GraphPath(uid)
    SVAR/Z active=$(base+"activeSnapshot")
    if(SVAR_Exists(active))
        return base+active+":"
    endif
    return base
End

Function/S HMG_GraphWindow(uid)
    String uid
    Wave/T/Z graphs=root:MHApp:Manager:graphs
    Variable row=HMG_Find("graph",uid)
    String owner=""
    if(row>=0 && WaveExists(graphs))
        owner=graphs[row][3]
        if(WinType(owner)==1 && cmpstr(GetUserData(owner,"","HMHGraphUID"),uid)==0)
            return owner
        endif
    endif
    String wins=WinList("*",";","WIN:1"),win
    Variable i
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(cmpstr(GetUserData(win,"","HMHGraphUID"),uid)==0)
            return win
        endif
    endfor
    return ""
End

Function/S HMG_DatasetFromWave(w)
    Wave w
    Wave/T paths=root:MHApp:paths,ids=root:MHApp:Manager:datasetUID
    String folder=GetWavesDataFolder(w,1)
    Variable i
    for(i=0;i<numpnts(ids);i+=1)
        if(cmpstr(folder,paths[i])==0)
            return ids[i]
        endif
    endfor
    return ""
End

Function/S HMG_AdoptGraph(win,[parent])
    String win,parent
    if(HMG_Init()!=0 || WinType(win)!=1)
        return ""
    endif
    if(ParamIsDefault(parent))
        parent=HMG_TargetFolder()
    endif
    if(HMG_Find("folder",parent)<0)
        return ""
    endif
    Wave/T graphs=root:MHApp:Manager:graphs
    String uid=GetUserData(win,"","HMHGraphUID"),base,owner
    Variable row=HMG_Find("graph",uid),n=DimSize(graphs,0)
    if(row>=0)
        owner=graphs[row][3]
        if(WinType(owner)==1 && cmpstr(owner,win)!=0 && cmpstr(GetUserData(owner,"","HMHGraphUID"),uid)==0)
            // Preserve the original owner's identity when a native graph is duplicated.
            row=-1
        endif
    endif
    if(row<0)
        uid=HMG_NewUID("g")
        base=HMG_GraphPath(uid)
        NewDataFolder/O $(RemoveEnding(base,":"))
        String/G $(base+"recreation")=""
        Make/O/T/N=(0,4) $(base+"bindings")
        Make/O/T/N=(0,4) $(base+"traces")
        Redimension/N=(n+1,4) graphs
        graphs[n][0]=uid;graphs[n][1]=parent;graphs[n][2]=win;graphs[n][3]=win
        row=n
    endif
    SetWindow $win userdata(HMHGraphUID)=uid
    SetWindow $win hook(HMGStore)=HMG_WindowHook
    graphs[row][3]=win
    if(HMG_Capture(win)!=0)
        Print "MH: 図の状態を保存できませんでした: ",win
    endif
    return uid
End

Function HMG_Capture(win)
    String win
    if(WinType(win)!=1)
        return -1
    endif
    String uid=GetUserData(win,"","HMHGraphUID"),base=HMG_GraphPath(uid)
    Variable row=HMG_Find("graph",uid)
    if(row<0)
        return -1
    endif
    NVAR busy=root:MHApp:Manager:busy
    if(busy)
        return 0
    endif
    busy=1
    String savedDF=GetDataFolder(1),rec,traceNames,trace,full,ds,path,nextName="state0",stage
    Variable i,n,error=0
    try
        SetDataFolder root:MHApp:Manager:Scratch
        // Native tokens have meaning only inside this capture and binding table.
        rec=WinRecreation(win,2)
        GetWindow $win wavelist
        Wave/T waveList=W_WaveList
        n=DimSize(waveList,0)
        Make/FREE/T/N=(n,4) bindings
        for(i=0;i<n;i+=1)
            Wave/Z w=$waveList[i][1]
            if(!WaveExists(w))
                Abort "グラフのWaveを取得できません。"
            endif
            bindings[i][0]=waveList[i][2]
            ds=HMG_DatasetFromWave(w)
            bindings[i][1]=ds
            bindings[i][2]=NameOfWave(w)
            bindings[i][3]=GetWavesDataFolder(w,2)
        endfor
        traceNames=TraceNameList(win,";",1)
        Make/FREE/T/N=(ItemsInList(traceNames),4) traceBindings
        for(i=0;i<ItemsInList(traceNames);i+=1)
            trace=StringFromList(i,traceNames)
            Wave/Z yw=TraceNameToWaveRef(win,trace),xw=XWaveRefFromTrace(win,trace)
            traceBindings[i][0]=trace
            if(WaveExists(yw))
                traceBindings[i][1]=HMG_DatasetFromWave(yw)
                traceBindings[i][2]=GetWavesDataFolder(yw,2)
            endif
            if(WaveExists(xw))
                traceBindings[i][3]=GetWavesDataFolder(xw,2)
            endif
        endfor
        if(strlen(rec)==0)
            Abort "再構築情報が空です。"
        endif
        // Write the inactive generation first, then switch a single pointer.
        // Allocation or capture errors cannot mix new bindings with old commands.
        SVAR/Z active=$(base+"activeSnapshot")
        if(SVAR_Exists(active))
            nextName=SelectString(cmpstr(active,"state0")==0,"state0","state1")
        endif
        stage=base+nextName+":"
        NewDataFolder/O $(RemoveEnding(stage,":"))
        Duplicate/O bindings,$(stage+"bindings")
        Duplicate/O traceBindings,$(stage+"traces")
        String/G $(stage+"recreation")=rec
        Variable/G $(stage+"savedAt")=DateTime
        String/G $(base+"activeSnapshot")=nextName
        Wave/T graphs=root:MHApp:Manager:graphs
        graphs[row][3]=win
    catch
        error=GetRTError(1)
        if(error==0)
            error=-1
        endif
    endtry
    SetDataFolder $savedDF
    busy=0
    return error
End

Function HMG_OpenGraph(uid)
    String uid
    if(HMG_Init()!=0 || HMG_Find("graph",uid)<0)
        return -1
    endif
    String win=HMG_GraphWindow(uid),base=HMG_SnapshotPath(uid)
    if(strlen(win))
        DoWindow/F $win
        String/G root:MHApp:lastGraph=win
        return 0
    endif
    SVAR/Z saved=$(base+"recreation")
    Wave/T/Z bindings=$(base+"bindings")
    if(!SVAR_Exists(saved) || strlen(saved)==0 || !WaveExists(bindings))
        return -2
    endif
    String rec=saved,full,savedDF=GetDataFolder(1),oldWins=WinList("*",";","WIN:1"),after,created
    Variable i,index,error=0
    Wave/T paths=root:MHApp:paths,graphs=root:MHApp:Manager:graphs
    for(i=0;i<DimSize(bindings,0);i+=1)
        full=bindings[i][3]
        if(strlen(bindings[i][1]))
            index=HMG_Find("data",bindings[i][1])
            if(index<0)
                Print "MH: 図で使う測定IDが見つかりません: ",bindings[i][1]
                return -3
            endif
            full=paths[index]+PossiblyQuoteName(bindings[i][2])
        endif
        Wave/Z w=$full
        if(!WaveExists(w))
            Print "MH: 図で使うWaveが見つかりません: ",full
            return -3
        endif
        rec=ReplaceString(bindings[i][0],rec,GetWavesDataFolder(w,2))
    endfor
    // The native recreation macro runs as a whole, including user annotations.
    // Do not call DrawGraph, Layout, NewGraphAxes or FitFigure on this path.
    NVAR busy=root:MHApp:Manager:busy
    busy=1
    SetDataFolder root:MHApp:Manager:Scratch
    V_flag=0
    Execute/Z rec
    error=V_flag
    after=WinList("*",";","WIN:1");created=""
    for(i=0;i<ItemsInList(after);i+=1)
        win=StringFromList(i,after)
        if(WhichListItem(win,oldWins)<0)
            if(error)
                DoWindow/K $win
            else
                created=win
            endif
        endif
    endfor
    SetDataFolder $savedDF
    busy=0
    if(error || strlen(created)==0)
        Print "MH: 保存図の復元に失敗しました。元の保存状態を保持します。"
        return -4
    endif
    SetWindow $created userdata(HMHGraphUID)=uid
    SetWindow $created hook(HMGStore)=HMG_WindowHook
    index=HMG_Find("graph",uid)
    graphs[index][3]=created
    String/G root:MHApp:lastGraph=created
    DoWindow/F $created
    return 0
End

Function HMG_SaveAll()
    NVAR/Z schema=root:MHApp:Manager:schemaVersion
    if(!NVAR_Exists(schema))
        return 0
    endif
    if(schema!=1)
        return -1
    endif
    String wins=HMH_FigureList(),win,uid
    Variable i,failures=0
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        uid=GetUserData(win,"","HMHGraphUID")
        if(HMG_Find("graph",uid)<0)
            uid=HMG_AdoptGraph(win)
        endif
        if(strlen(uid)==0 || HMG_Capture(win)!=0)
            failures+=1
            Print "MH: 図の保存失敗: ",win
        endif
    endfor
    return failures
End

Function HMG_BeforeSave(refNum,fileName,pathName,fileType,creator,fileKind)
    Variable refNum,fileKind
    String fileName,pathName,fileType,creator
    Variable failed=HMG_SaveAll()
    if(failed)
        Print "MH: 保存状態を更新できなかった図があります。開いている図を保持して確認してください。"
    endif
    return 0
End

Function HMG_WindowHook(s)
    STRUCT WMWinHookStruct &s
    NVAR/Z schema=root:MHApp:Manager:schemaVersion,busy=root:MHApp:Manager:busy
    if(!NVAR_Exists(schema) || !NVAR_Exists(busy))
        return 0
    endif
    if(busy)
        return 0
    endif
    String uid=GetUserData(s.winName,"","HMHGraphUID")
    Variable row=HMG_Find("graph",uid)
    if(row<0)
        return 0
    endif
    Wave/T graphs=root:MHApp:Manager:graphs
    strswitch(s.eventName)
        case "killVote":
            if(HMG_Capture(s.winName)!=0)
                Print "MH: 保存できないため図を閉じませんでした: ",s.winName
                return 2
            endif
            break
        case "kill":
            graphs[row][3]=""
            break
        case "renamed":
            graphs[row][3]=s.winName
            break
    endswitch
    return 0
End

Function HMG_CloseGraph(uid)
    String uid
    String win=HMG_GraphWindow(uid)
    if(strlen(win)==0)
        return 0
    endif
    if(HMG_Capture(win)!=0)
        return -1
    endif
    DoWindow/K $win
    return 0
End

Function/S HMG_GraphSources(uid)
    String uid
    String base=HMG_SnapshotPath(uid),text="",ds,name,seen=""
    Wave/T/Z traces=$(base+"traces")
    if(!WaveExists(traces))
        return "関連情報なし"
    endif
    Variable i
    for(i=0;i<DimSize(traces,0);i+=1)
        ds=traces[i][1]
        if(strlen(ds) && WhichListItem(ds,seen)<0)
            seen+=ds+";"
            name=HMG_Name("data",ds)
            text+="・"+name+"\r"
        elseif(strlen(ds)==0)
            text+="・管理外のWave: "+traces[i][2]+"\r"
        endif
    endfor
    return text
End

// ---- mh_tree ----

Function HMG_OpenManager()
    if(HMG_Init()!=0)
        DoAlert 0,"管理情報と測定一覧の整合性を確認してください。元データは変更していません。"
        return -1
    endif
    HMG_SaveAll()
    SetIgorHook BeforeExperimentSaveHook=HMG_BeforeSave
    if(WinType("HMG_Manager"))
        HMG_Refresh()
        DoWindow/F HMG_Manager
        return 0
    endif
    NewPanel/N=HMG_Manager/W=(60,55,1010,655) as "MH：データ・グラフ管理 v2.2.0"
    DefaultGUIFont/W=HMG_Manager all={"Segoe UI",12,0}
    TitleBox heading,pos={18,12},frame=0,title="フォルダを選んで追加・整理。保存した図はダブルクリックで開けます。"
    ListBox tree,pos={18,44},size={550,384},mode=1,widths={45,395,90},proc=HMG_TreeAction
    TitleBox selection,pos={590,50},size={330,55},frame=0,title=""
    TitleBox details,pos={590,115},size={330,305},frame=0,title=""
    Button folder,pos={18,442},size={164,30},title="フォルダを作成",proc=HMG_ManagerButton
    Button rename,pos={194,442},size={164,30},title="名前を変更",proc=HMG_ManagerButton
    Button move,pos={370,442},size={198,30},title="移動先を選ぶ",proc=HMG_ManagerButton
    Button importVSM,pos={18,484},size={262,32},title="このフォルダにVSMを追加",proc=HMG_ManagerButton
    Button show,pos={292,484},size={276,32},title="選択した測定・図を開く",proc=HMG_ManagerButton
    Button compare,pos={590,442},size={330,30},title="チェックした測定で比較図を作成",proc=HMG_ManagerButton
    Button saveGraph,pos={590,484},size={158,32},title="図の状態を記録",proc=HMG_ManagerButton
    Button closeGraph,pos={760,484},size={160,32},title="選択した図を閉じる",proc=HMG_ManagerButton
    NVAR arrowOption=root:MHApp:Manager:arrowOption
    CheckBox arrows,pos={18,537},title="補助機能：矢印の位置調整",value=arrowOption,proc=HMG_ArrowOption
    Button arrowEdit,pos={285,533},size={230,28},title="矢印の調整画面を開く",proc=HMG_ManagerButton
    TitleBox status,pos={590,535},frame=0,title="保存：File → Save Experiment（.pxp）"
    HMG_Refresh()
    return 0
End

Function HMG_Refresh()
    if(WinType("HMG_Manager")==0)
        return 0
    endif
    if(HMG_Init()!=0)
        return -1
    endif
    Make/O/T/N=(0,3) root:MHApp:Manager:treeText
    Make/O/N=(0,3) root:MHApp:Manager:treeState
    Make/O/T/N=0 root:MHApp:Manager:treeUID,root:MHApp:Manager:treeKind
    HMG_AppendFolder("home",0)
    ListBox tree,win=HMG_Manager,listWave=root:MHApp:Manager:treeText,selWave=root:MHApp:Manager:treeState
    SVAR selected=root:MHApp:Manager:selectedUID,kind=root:MHApp:Manager:selectedKind
    Wave/T ids=root:MHApp:Manager:treeUID,kinds=root:MHApp:Manager:treeKind
    Variable i
    for(i=0;i<numpnts(ids);i+=1)
        if(cmpstr(ids[i],selected)==0 && cmpstr(kinds[i],kind)==0)
            ListBox tree,win=HMG_Manager,selRow=i
            break
        endif
    endfor
    NVAR option=root:MHApp:Manager:arrowOption
    Button arrowEdit,win=HMG_Manager,disable=SelectNumber(option!=0,2,0)
    HMG_Details()
    return 0
End

Function HMG_AppendRow(uid,kind,label,typeName,checked)
    String uid,kind,label,typeName
    Variable checked
    Wave/T ids=root:MHApp:Manager:treeUID,kinds=root:MHApp:Manager:treeKind,text=root:MHApp:Manager:treeText
    Wave state=root:MHApp:Manager:treeState
    Variable row=numpnts(ids)
    Redimension/N=(row+1) ids,kinds
    Redimension/N=(row+1,3) text,state
    ids[row]=uid;kinds[row]=kind
    text[row][0]="";text[row][1]=label;text[row][2]=typeName
    state[row][]=0
    if(cmpstr(kind,"data")==0)
        state[row][0]=32+16*(checked!=0)
    endif
    return row
End

Function HMG_AppendFolder(uid,depth)
    String uid
    Variable depth
    Wave/T folders=root:MHApp:Manager:folders,ids=root:MHApp:Manager:datasetUID,parents=root:MHApp:Manager:datasetFolder
    Wave/T graphs=root:MHApp:Manager:graphs,names=root:MHApp:names
    Wave state=root:MHApp:listState
    Variable row=HMG_Find("folder",uid),i,expanded
    if(row<0 || depth>DimSize(folders,0))
        return -1
    endif
    String indent="",label
    for(i=0;i<depth;i+=1)
        indent+="    "
    endfor
    expanded=cmpstr(folders[row][3],"1")==0
    label=indent+SelectString(expanded,"▶ ","▼ ")+folders[row][2]
    HMG_AppendRow(uid,"folder",label,"フォルダ",0)
    if(!expanded)
        return 0
    endif
    for(i=1;i<DimSize(folders,0);i+=1)
        if(cmpstr(folders[i][1],uid)==0)
            HMG_AppendFolder(folders[i][0],depth+1)
        endif
    endfor
    for(i=0;i<numpnts(ids);i+=1)
        if(cmpstr(parents[i],uid)==0)
            HMG_AppendRow(ids[i],"data",indent+"    "+names[i],"測定",state[i][0]&16)
        endif
    endfor
    for(i=0;i<DimSize(graphs,0);i+=1)
        if(cmpstr(graphs[i][1],uid)==0)
            HMG_AppendRow(graphs[i][0],"graph",indent+"    "+graphs[i][2],"グラフ",0)
        endif
    endfor
    return 0
End

Function HMG_TreeAction(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(WhichListItem(num2istr(lba.eventCode),"1;2;3;4;5;13")<0 || lba.row<0)
        return 0
    endif
    Wave/T ids=root:MHApp:Manager:treeUID,kinds=root:MHApp:Manager:treeKind
    Wave state=root:MHApp:Manager:treeState,legacy=root:MHApp:listState
    if(lba.row>=numpnts(ids))
        return 0
    endif
    Variable i,index
    for(i=0;i<numpnts(ids);i+=1)
        if(cmpstr(kinds[i],"data")==0)
            index=HMG_Find("data",ids[i])
            if(index>=0)
                legacy[index][0]=32+(state[i][0]&16)
            endif
        endif
    endfor
    String/G root:MHApp:Manager:selectedUID=ids[lba.row]
    String/G root:MHApp:Manager:selectedKind=kinds[lba.row]
    String folder=ids[lba.row]
    if(cmpstr(kinds[lba.row],"folder")!=0)
        folder=HMG_Parent(kinds[lba.row],folder)
    endif
    String/G root:MHApp:Manager:importFolder=folder
    HMG_Details()
    if(lba.eventCode==3)
        if(cmpstr(kinds[lba.row],"folder")==0)
            index=HMG_Find("folder",ids[lba.row])
            Wave/T folders=root:MHApp:Manager:folders
            folders[index][3]=SelectString(cmpstr(folders[index][3],"1")==0,"1","0")
            HMG_Refresh()
        else
            HMG_ShowSelection()
        endif
    endif
    return 0
End

Function HMG_Details()
    if(WinType("HMG_Manager")==0)
        return 0
    endif
    SVAR uid=root:MHApp:Manager:selectedUID,kind=root:MHApp:Manager:selectedKind
    String name=HMG_Name(kind,uid),text="",heading=name,folder=HMG_TargetFolder(),base,gs,win
    Variable i,j,index=HMG_Find(kind,uid)
    if(index<0)
        heading="選択した項目が見つかりません"
    elseif(cmpstr(kind,"folder")==0)
        text="取込先：\r"+HMG_FolderPath(uid)+"\r\rダブルクリックで開閉します。\rフォルダ内に測定とグラフを整理できます。"
    elseif(cmpstr(kind,"graph")==0)
        text="所属："+HMG_FolderPath(HMG_Parent(kind,uid))+"\r\r作図に使用した測定：\r"+HMG_GraphSources(uid)
        win=HMG_GraphWindow(uid)
        text+="\r状態："+SelectString(strlen(win)>0,"保存済み（閉じています）","開いています")
    else
        Wave/T paths=root:MHApp:paths,graphs=root:MHApp:Manager:graphs
        NVAR/Z mass=$(paths[index]+"sampleMassG")
        text="所属："+HMG_FolderPath(HMG_Parent(kind,uid))+"\r単位：kOe / emu/g\r"
        if(NVAR_Exists(mass))
            text+="試料質量："+num2str(mass)+" g\r"
        endif
        text+="\rこの測定を使用するグラフ：\r"
        for(i=0;i<DimSize(graphs,0);i+=1)
            base=HMG_SnapshotPath(graphs[i][0])
            Wave/T/Z traces=$(base+"traces")
            if(WaveExists(traces))
                for(j=0;j<DimSize(traces,0);j+=1)
                    if(cmpstr(traces[j][1],uid)==0)
                        text+="・"+graphs[i][2]+"\r"
                        break
                    endif
                endfor
            endif
        endfor
    endif
    TitleBox selection,win=HMG_Manager,title=heading
    TitleBox details,win=HMG_Manager,title=text
    Button importVSM,win=HMG_Manager,help={"取込先："+HMG_FolderPath(folder)}
    return 0
End

Function HMG_ShowSelection()
    SVAR uid=root:MHApp:Manager:selectedUID,kind=root:MHApp:Manager:selectedKind
    Variable result=-1
    if(cmpstr(kind,"graph")==0)
        result=HMG_OpenGraph(uid)
    elseif(cmpstr(kind,"data")==0)
        result=HMH_DrawGraph(HMG_Find("data",uid))
    endif
    HMG_Refresh()
    if(result<0)
        Print "MH: 開く対象の測定・グラフと依存データを確認してください。"
    endif
    return result
End

Function HMG_MoveDialog()
    SVAR uid=root:MHApp:Manager:selectedUID,kind=root:MHApp:Manager:selectedKind
    Wave/T folders=root:MHApp:Manager:folders
    String choices="",folder,name
    Variable i,choice=1
    for(i=0;i<DimSize(folders,0);i+=1)
        name=ReplaceString(";",HMG_FolderPath(folders[i][0]),"；")
        choices+=num2istr(i+1)+": "+name+";"
    endfor
    Prompt choice,"移動先のフォルダ",popup choices
    DoPrompt "選択した項目を移動",choice
    if(V_flag)
        return 0
    endif
    if(HMG_Move(kind,uid,folders[choice-1][0])!=0)
        DoAlert 0,"移動できません。同名の項目、自分自身や子フォルダへの移動を確認してください。"
        return -1
    endif
    String/G root:MHApp:Manager:importFolder=folders[choice-1][0]
    return HMG_Refresh()
End

Function HMG_ManagerButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    SVAR uid=root:MHApp:Manager:selectedUID,kind=root:MHApp:Manager:selectedKind
    String name,newUID,parent=HMG_TargetFolder()
    Variable result
    strswitch(ba.ctrlName)
        case "folder":
            name="新しいフォルダ"
            Prompt name,"フォルダ名"
            DoPrompt "フォルダを作成",name
            if(!V_flag)
                newUID=HMG_AddFolder(parent,name)
                if(strlen(newUID))
                    uid=newUID;kind="folder"
                    String/G root:MHApp:Manager:importFolder=newUID
                else
                    DoAlert 0,"フォルダ名が空か、同じ場所に同名のフォルダがあります。"
                endif
            endif
            break
        case "rename":
            name=HMG_Name(kind,uid)
            Prompt name,"新しい名前"
            DoPrompt "名前を変更",name
            if(!V_flag && HMG_Rename(kind,uid,name)!=0)
                DoAlert 0,"名前を変更できません。同じ場所の同名項目や空の名前を確認してください。"
            endif
            break
        case "move":
            HMG_MoveDialog()
            break
        case "importVSM":
            HMH_ChooseFiles()
            break
        case "show":
            HMG_ShowSelection()
            break
        case "compare":
            HMH_DrawGraph(-1)
            break
        case "saveGraph":
            result=HMG_SaveAll()
            TitleBox status,win=HMG_Manager,title=SelectString(result==0,"保存できない図があります。履歴を確認してください。","図の状態を記録しました。次にExperimentを保存してください。")
            break
        case "closeGraph":
            if(cmpstr(kind,"graph")==0)
                HMG_CloseGraph(uid)
            endif
            break
        case "arrowEdit":
            HMG_ArrowPanel()
            break
    endswitch
    HMG_Refresh()
    return 0
End

Function HMG_ArrowOption(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    if(cba.eventCode==2)
        Variable/G root:MHApp:Manager:arrowOption=cba.checked
        HMG_Refresh()
    endif
    return 0
End

// ---- mh_arrow ----

// Optional: only this editor's named arrows are changed. Native user drawings
// remain in the full graph snapshot and can always be edited with Igor tools.
Function HMG_ArrowPanel()
    if(HMG_Init()!=0)
        return -1
    endif
    NVAR option=root:MHApp:Manager:arrowOption
    if(!option)
        return 0
    endif
    String win=WinName(0,1),uid,base,choices="新しい矢印を追加;",aid
    SVAR kind=root:MHApp:Manager:selectedKind,selected=root:MHApp:Manager:selectedUID
    if(cmpstr(kind,"graph")==0)
        win=HMG_GraphWindow(selected)
        if(strlen(win)==0)
            if(HMG_OpenGraph(selected)!=0)
                return -1
            endif
            win=HMG_GraphWindow(selected)
        endif
    endif
    if(WinType(win)!=1 || WhichListItem(win,HMH_FigureList())<0)
        DoAlert 0,"先にMHグラフを選んでください。"
        return -1
    endif
    uid=HMG_AdoptGraph(win);base=HMG_GraphPath(uid)
    Wave/T/Z arrows=$(base+"arrowIDs")
    if(!WaveExists(arrows))
        Make/O/T/N=0 $(base+"arrowIDs")
        Wave/T arrows=$(base+"arrowIDs")
    endif
    Variable i,choice=1,x1,x2,y1,y2
    for(i=0;i<numpnts(arrows);i+=1)
        choices+="矢印 "+num2istr(i+1)+";"
    endfor
    Prompt choice,"調整する矢印",popup choices
    DoPrompt "補助機能：矢印の位置",choice
    if(V_flag)
        return 0
    endif
    Make/FREE/D/N=4 coords
    if(choice==1)
        GetAxis/Q/W=$win bottom
        x1=V_min+0.65*(V_max-V_min);x2=V_min+0.55*(V_max-V_min)
        GetAxis/Q/W=$win left
        y1=V_min+0.8*(V_max-V_min);y2=V_min+0.65*(V_max-V_min)
    else
        aid=arrows[choice-2]
        if(HMG_ReadArrow(win,aid,coords)!=0)
            DoAlert 0,"この矢印を数値で読み取れません。Igor標準の描画ツールで編集してください。"
            return -1
        endif
        x1=coords[0];y1=coords[1];x2=coords[2];y2=coords[3]
    endif
    Prompt x1,"始点：磁場 (kOe)"
    Prompt y1,"始点：磁化 (emu/g)"
    Prompt x2,"終点：磁場 (kOe)"
    Prompt y2,"終点：磁化 (emu/g)"
    DoPrompt "矢印の始点・終点（取消で変更なし）",x1,y1,x2,y2
    if(V_flag)
        return 0
    endif
    if(choice==1)
        aid=HMG_NewUID("a")
    endif
    if(HMG_SetArrow(win,aid,x1,y1,x2,y2)!=0)
        return -1
    endif
    if(choice==1)
        i=numpnts(arrows)
        Redimension/N=(i+1) arrows
        arrows[i]=aid
    endif
    return HMG_Capture(win)
End

Function HMG_ReadArrow(win,aid,coords)
    String win,aid
    Wave coords
    DrawAction/W=$win/L=UserFront getgroup=$aid,commands
    if(!V_flag)
        return -1
    endif
    String commands=S_recreation,compact=ReplaceString(" ",S_recreation,"")
    Variable start=strsearch(commands,"DrawLine ",0),i
    if(start<0 || strsearch(compact,"xcoord=bottom",0)<0 || strsearch(compact,"ycoord=left",0)<0)
        return -1
    endif
    String line=StringFromList(0,commands[start+9,inf],"\r")
    for(i=0;i<4;i+=1)
        coords[i]=str2num(StringFromList(i,line,","))
    endfor
    return SelectNumber(numtype(sum(coords))==0,-1,0)
End

Function HMG_SetArrow(win,aid,x1,y1,x2,y2)
    String win,aid
    Variable x1,y1,x2,y2
    if(WinType(win)!=1 || numtype(x1+y1+x2+y2)!=0)
        return -1
    endif
    DrawAction/W=$win/L=UserFront getgroup=$aid,commands
    String original=S_recreation,line,commands
    Variable existsGroup=V_flag,start,stop,error
    sprintf line,"DrawLine %.17g,%.17g,%.17g,%.17g",x1,y1,x2,y2
    if(existsGroup)
        Make/FREE/D/N=4 coords
        if(HMG_ReadArrow(win,aid,coords)!=0)
            return -1
        endif
        start=strsearch(original,"DrawLine ",0)
        stop=strsearch(original,"\r",start)
        if(stop<0)
            return -1
        endif
        commands=original[0,start-1]+line+original[stop,inf]
        DrawAction/W=$win/L=UserFront getgroup=$aid,delete,beginInsert
    else
        commands="SetDrawEnv gstart,gname="+aid+"\rSetDrawEnv xcoord=bottom,ycoord=left,arrow=1,linethick=1.5\r"+line+"\rSetDrawEnv gstop\r"
    endif
    DoWindow/F $win
    SetDrawLayer/W=$win UserFront
    V_flag=0
    Execute/Z "Macro HMGArrowEdit()\r"+commands+"End\r"
    error=V_flag
    if(existsGroup)
        DrawAction/W=$win/L=UserFront endInsert
    endif
    if(error && existsGroup)
        Execute/Z "Macro HMGArrowRestore()\r"+original+"End\r"
    endif
    return error
End
