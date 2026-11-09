#pragma TextEncoding = "UTF-8"
// ---- MH_VSM_Analyzer ----
#pragma rtGlobals=3
#pragma version=2.40

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
        if(cmpstr(GetUserData("HMH_Panel","","HMHPanelVersion"),"2.4.0")==0)
            DoWindow/F HMH_Panel
            return 0
        endif
        // Recreate a v2.01 panel when explicitly opened from the menu.
        DoWindow/K HMH_Panel
    endif
    NewPanel/N=HMH_Panel/W=(80,80,730,535) as "MH VSM Analyzer v2.4.0"
    SetWindow HMH_Panel userdata(HMHPanelVersion)="2.4.0"
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
        if (strlen(listText[i][1])>0 && cmpstr(names[i],listText[i][1])!=0)
            names[i]=HMM_NormalizeLabel(listText[i][1])
            listText[i][1]=names[i]
        endif
    endfor
End

Function HMH_ChooseFiles()
    String folderUID=HMG_TargetFolder()
    if(strlen(folderUID)==0)
        return -1
    endif
    Variable refNum,added
    Open/D/R/MULT=1/F="VSM measurement (*.VSM):.VSM;"/M="追加する .VSM 測定ファイルを選択" refNum
    if(strlen(S_fileName)==0)
        return 0
    endif
    added=HMM_ImportBatch(S_fileName,folderUID)
    if(added>0)
        HMM_ReviewPanel()
    endif
    return added
End

Function HMH_ReadVSM(filePath,runPath)
    String filePath,&runPath
    if(!StringMatch(LowerStr(filePath),"*.vsm"))
        Print "MH: .VSM ファイルを選んでください。"
        return -4
    endif
    String savedDF=GetDataFolder(1)
    String line,low,runName
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
    SetDataFolder savedDF
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
    String runPath,label,winPath
    Variable result=HMH_ReadVSM(filePath,runPath)
    if(result!=0)
        return result
    endif
    winPath=ParseFilePath(5,filePath,"\\",0,0)
    label=ParseFilePath(3,winPath,"\\",0,0)
    String sampleNumber,composition
    if(HMM_ParseName(filePath,sampleNumber,composition))
        label=composition
    endif
    label=HMM_NormalizeLabel(label)
    NVAR count=root:MHApp:count
    Wave/T paths=root:MHApp:paths
    Wave/T names=root:MHApp:names
    Wave/T listText=root:MHApp:listText
    Wave listState=root:MHApp:listState
    if(!NumVarOrDefault("root:MHApp:Manager:batchImporting",0))
        HMH_SaveNames()
    endif
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
    Wave raw=$(runPath+"H_Oe")
    Print "MH: ",label," / ",numpnts(raw)," 点 / ",NumVarOrDefault(runPath+"sampleMassG",NaN)," g"
    if (WinType("HMH_Panel")==0 && WinType("HMG_Manager")==0 && !NumVarOrDefault("root:MHApp:Manager:batchImporting",0))
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
    String graphName,traces,trace,runPath,host="",title
    Variable startIndex=0,endIndex=count
    if (index>=count)
        return -1
    endif
    if (index<0)
        graphName=UniqueName("MH_Compare",6,0)
    else
        graphName=UniqueName("MH_Single",6,0)
        startIndex=index;endIndex=index+1
    endif
    PauseUpdate
    for (i=startIndex;i<endIndex;i+=1)
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
            title=SelectString(index<0,"MH： "+names[i],"MH：比較グラフ")
            if(HMP_NeedsOverlay())
                host=HMP_NewHost(title)
                Display/HOST=$host/N=Plot/FG=(FL,FT,FR,FB) y vs x
                graphName=host+"#Plot"
                SetActiveSubwindow _endfloat_
            else
                Display/K=(HMP_CloseMode())/N=$graphName/W=(100,70,900,650) y vs x as title
            endif
        else
            AppendToGraph/W=$graphName y vs x
        endif
        traces=TraceNameList(graphName,";",1)
        trace=StringFromList(ItemsInList(traces)-1,traces)
        HMH_Color(graphName,trace,shown,index>=0)
        SetWindow $graphName userdata($("HMHLabel_"+trace))=names[i]
        for (j=0;j<min(numpnts(x),numpnts(y));j+=1)
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
    SetWindow $graphName userdata(HMHFigure)="2.4.0"
    HMH_FigureInit()
    if(HMH_ApplyDefaults(graphName)!=0)
        // A saved whole-canvas size may be too small for this sample's longer name.
        // Keep the new graph usable, with the lab's 12 x 9 cm plot rectangle.
        HMH_Layout(graphName,1,12,4/3,24,24,2,2.5)
        Print "MH: 指定サイズに凡例が収まらないため、この図は描画枠12×9 cmで作成しました。"
    endif
    HMH_NewGraphAxes(graphName,xlo,xhi,lo,hi)
    HMH_FitFigure(graphName)
    HMP_Front(graphName)
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
    NewPanel/N=HMH_AxisSettings/W=(60,60,800,577) as "MH：軸・目盛り・小数桁数 v2.4.0"
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
    HMP_ResizeOverlay(win,pw+newLeft+newRight,ph+topMargin+margins[3])
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
        if(HMG_SyncDatasets()!=0)
            return -1
        endif
        if(HMM_Init()!=0)
            return -1
        endif
        NVAR/Z autoEnabled=root:MHApp:Manager:Autosave:enabled
        if(!NVAR_Exists(autoEnabled))
            HMA_Init()
            HMA_Arm()
        endif
        return 0
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
    HMG_SyncDatasets()
    HMM_Init()
    HMA_Init()
    HMA_Arm()
    return 0
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
    if(cmpstr(kind,"data")==0)
        // Composition labels may legitimately repeat across different samples.
        return 1
    endif
    String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
    Wave/T records=$path
    Variable i
    for(i=0;i<DimSize(records,0);i+=1)
        if(cmpstr(records[i][0],exceptUID)!=0 && cmpstr(records[i][1],parent)==0 && cmpstr(records[i][2],name)==0)
            return 0
        endif
    endfor
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
    name=HMM_NormalizeLabel(name)
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
    if(!NumVarOrDefault("root:MHApp:Manager:batchImporting",0))
        HMG_Refresh()
    endif
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
    String wins=HMP_PlotList(),win
    Variable i
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(cmpstr(GetUserData(win,"","HMHGraphUID"),uid)==0)
            return win
        endif
    endfor
    return ""
End

Function HMG_OpenGraph(uid)
    String uid
    if(HMG_Init()!=0 || HMG_Find("graph",uid)<0)
        return -1
    endif
    String live=HMG_GraphWindow(uid),base=HMG_SnapshotPath(uid)
    Variable overlay=HMP_NeedsOverlay()
    if(strlen(live) && (!overlay || strsearch(live,"#",0)>=0))
        String/G root:MHApp:lastGraph=live
        return HMP_Front(live)
    endif
    String rec,full,savedDF=GetDataFolder(1),oldWins=WinList("*",";","WIN:1"),created
    Variable i,index,error=0
    Wave/T paths=root:MHApp:paths,graphs=root:MHApp:Manager:graphs
    if(strlen(live))
        // Keep the current edits when an already-open plot moves into the overlay.
        SetDataFolder root:MHApp:Manager:Scratch
        rec=WinRecreation(live,0)
        SetDataFolder $savedDF
    else
        SVAR/Z saved=$(base+"recreation")
        Wave/T/Z bindings=$(base+"bindings")
        if(!SVAR_Exists(saved) || strlen(saved)==0 || !WaveExists(bindings))
            return -2
        endif
        rec=saved
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
    endif
    rec=ReplaceString("\tSetWindow kwTopWin,hook(HMGStore)=HMG_WindowHook\r",rec,"")
    String host="",title=HMG_Name("graph",uid)
    if(overlay)
        host=HMP_NewHost(title)
        rec="Macro HMPRestore()"+rec[strsearch(rec,"\r",0),inf]
        rec=ReplaceString("\tDisplay ",rec,"\tDisplay /HOST="+host+"/N=Plot/FG=(FL,FT,FR,FB) ")
        rec=ReplaceString("kwTopWin",rec,host+"#Plot")
    else
        rec=ReplaceString("\tDisplay ",rec,"\tDisplay /K="+num2istr(HMP_CloseMode())+" ")
    endif
    SetDataFolder root:MHApp:Manager:Scratch
    Execute/Z rec
    error=V_flag
    SetDataFolder $savedDF
    if(strlen(host))
        SetActiveSubwindow _endfloat_
        created=host+"#Plot"
    else
        created=StringFromList(0,WinList("*",";","WIN:1"))
        if(WhichListItem(created,oldWins)>=0)
            created=""
        endif
    endif
    if(error || WinType(created)!=1)
        if(strlen(host))
            DoWindow/K $host
        elseif(strlen(created))
            DoWindow/K $created
        endif
        Print "MH: 保存図を開けませんでした。"
        return -4
    endif
    if(strlen(host))
        Variable width=str2num(GetUserData(created,"","HMHCanvasWidth"))
        Variable height=str2num(GetUserData(created,"","HMHCanvasHeight"))
        if(numtype(width+height)==0 && width>0 && height>0)
            HMP_ResizeOverlay(created,width,height)
        endif
    endif
    if(strlen(live))
        HMP_Close(live)
    endif
    SetWindow $created userdata(HMHGraphUID)=uid
    index=HMG_Find("graph",uid)
    graphs[index][3]=created
    String/G root:MHApp:lastGraph=created
    return HMP_Front(created)
End

// v2.3 saved hooks resolve on reopen. Existing snapshots are read-only.
Function HMG_BeforeSave(refNum,fileName,pathName,fileType,creator,fileKind)
    Variable refNum,fileKind
    String fileName,pathName,fileType,creator
    return 0
End

Function HMG_WindowHook(s)
    STRUCT WMWinHookStruct &s
    return 0
End

Function HMG_CloseGraph(uid)
    String uid
    return HMP_Close(HMG_GraphWindow(uid))
End

Function HMG_DeleteGraph(uid)
    String uid
    Variable row=HMG_Find("graph",uid)
    if(row<0)
        return -1
    endif
    if(HMG_CloseGraph(uid)!=0)
        return -2
    endif
    String base=HMG_GraphPath(uid)
    if(DataFolderExists(base))
        KillDataFolder/Z $base
        if(DataFolderExists(base))
            return -2
        endif
    endif
    Wave/T graphs=root:MHApp:Manager:graphs
    DeletePoints/M=0 row,1,graphs
    return 0
End

Function HMG_GraphUsesData(graph,uid,runPath)
    String graph,uid,runPath
    String base=HMG_SnapshotPath(graph)
    Wave/T/Z bindings=$(base+"bindings")
    Variable i
    if(WaveExists(bindings))
        for(i=0;i<DimSize(bindings,0);i+=1)
            if(cmpstr(bindings[i][1],uid)==0 || strsearch(bindings[i][3],runPath,0)==0)
                return 1
            endif
        endfor
    endif
    return 0
End

Function HMG_ClosePlotsUsing(runPath)
    String runPath
    String wins=HMH_FigureList(),win,traces,trace
    Variable i,j
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        traces=TraceNameList(win,";",1)
        for(j=0;j<ItemsInList(traces);j+=1)
            trace=StringFromList(j,traces)
            Wave/Z yw=TraceNameToWaveRef(win,trace),xw=XWaveRefFromTrace(win,trace)
            if(HMG_WaveUsesRun(yw,runPath) || HMG_WaveUsesRun(xw,runPath))
                HMP_Close(win)
                break
            endif
        endfor
    endfor
    return 0
End

Function HMG_WaveUsesRun(w,runPath)
    Wave/Z w
    String runPath
    if(!WaveExists(w))
        return 0
    endif
    return cmpstr(GetWavesDataFolder(w,1),runPath)==0
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
            if(strlen(HMM_SampleNumber(ds)))
                name=HMM_SampleNumber(ds)+" | "+name
            endif
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
        DoAlert 0,"管理情報と測定一覧の整合性を確認してください。"
        return -1
    endif
    HMA_EnsureArmed()
    Variable left=45,top=45,right=1095,bottom=705,maximized=0
    if(WinType("HMG_Manager"))
        if(cmpstr(GetUserData("HMG_Manager","","HMGManagerVersion"),"2.4.0")==0)
            HMG_Refresh()
            DoWindow/F HMG_Manager
            return 0
        endif
        GetWindow HMG_Manager maximize
        maximized=V_value
        if(!maximized)
            GetWindow HMG_Manager wsize
            left=V_left;top=V_top;right=V_right;bottom=V_bottom
        endif
        DoWindow/K HMG_Manager
    endif
    NewPanel/N=HMG_Manager/W=(left,top,right,bottom) as "MH：データ・グラフ管理 v2.4.0"
    SetWindow HMG_Manager userdata(HMGManagerVersion)="2.4.0"
    DefaultGUIFont/W=HMG_Manager all={"Segoe UI",12,0}
    TitleBox heading,pos={18,14},frame=0,title="1  フォルダを選ぶ → VSMを追加 → 2  測定をチェック → 3  比較図を作成"
    TitleBox scope,pos={18,45},frame=0,title=""
    ListBox tree,pos={18,76},size={620,360},mode=1,widths={38,65,425,75},proc=HMG_TreeAction
    TitleBox selection,pos={660,25},size={370,40},frame=0,title="選択した項目"
    TitleBox details,pos={660,78},size={370,235},frame=0,title=""
    Button folderCheck,pos={18,448},size={190,30},title="フォルダ内を全チェック",proc=HMG_ManagerButton
    Button folderClear,pos={220,448},size={190,30},title="フォルダ内を解除",proc=HMG_ManagerButton
    Button clearAll,pos={422,448},size={216,30},title="すべてのチェックを解除",proc=HMG_ManagerButton
    Button folder,pos={18,490},size={190,30},title="子フォルダを作成",proc=HMG_ManagerButton
    Button rename,pos={220,490},size={190,30},title="名前・試料番号を編集",proc=HMG_ManagerButton
    Button move,pos={422,490},size={216,30},title="選択した項目を移動",proc=HMG_ManagerButton
    Button importVSM,pos={18,532},size={300,32},title="このフォルダに .VSM を追加",proc=HMG_ManagerButton
    Button review,pos={330,532},size={308,32},title="今回追加した測定の名前を確認",proc=HMG_ManagerButton
    Button show,pos={18,574},size={300,32},title="選択した測定・図を開く",proc=HMG_ManagerButton
    Button compare,pos={330,574},size={308,32},title="チェックした測定で比較図を作成",proc=HMG_ManagerButton
    TitleBox hint,pos={18,620},frame=0,title="右クリックで整理。フォルダのチェックは子フォルダを含みます。"
    GroupBox graphs,pos={652,326},size={382,134},title="グラフ"
    Button closeGraph,pos={666,356},size={174,30},title="グラフを閉じる",proc=HMG_ManagerButton
    Button exportGraph,pos={850,356},size={170,30},title="画像を保存…",proc=HMG_ManagerButton
    TitleBox status,pos={666,401},frame=0,title="図を右クリックしてPNGで保存できます。"
    NVAR arrowOption=root:MHApp:Manager:arrowOption,autosave=root:MHApp:Manager:Autosave:enabled
    CheckBox arrows,pos={666,477},title="補助機能：矢印の位置調整を表示",value=arrowOption,proc=HMG_ArrowOption
    Button arrowEdit,pos={666,507},size={354,28},title="矢印の調整画面を開く",proc=HMG_ManagerButton
    CheckBox autosave,pos={666,562},title="5分ごとに復旧用コピーを自動保存",value=autosave,proc=HMA_Toggle
    Button saveNow,pos={666,591},size={174,29},title="今すぐ復旧用に保存",proc=HMG_ManagerButton
    Button autoDirectory,pos={850,591},size={170,29},title="自動保存先を選ぶ",proc=HMG_ManagerButton
    TitleBox autoStatus,pos={666,633},frame=0,title=""
    if(maximized)
        MoveWindow/W=HMG_Manager 2,2,2,2
    endif
    HMG_Refresh()
    return 0
End

Function HMG_BuildFolderCounts(head,nextData)
    Wave head,nextData
    Wave/T folders=root:MHApp:Manager:folders,parents=root:MHApp:Manager:datasetFolder
    Wave state=root:MHApp:listState
    Variable n=DimSize(folders,0),i,index,ancestor,limit
    Make/O/D/N=(n) root:MHApp:Manager:folderTotal,root:MHApp:Manager:folderChecked,root:MHApp:Manager:folderTreeRow
    Wave totals=root:MHApp:Manager:folderTotal,checked=root:MHApp:Manager:folderChecked,map=root:MHApp:Manager:folderTreeRow
    totals=0;checked=0;map=-1;head=-1;nextData=-1
    String folderKeys=""
    for(i=0;i<n;i+=1)
        folderKeys+=folders[i][0]+";"
    endfor
    // Build each folder's ordered measurement chain once, including hidden rows.
    for(i=numpnts(parents)-1;i>=0;i-=1)
        index=WhichListItem(parents[i],folderKeys)
        if(index>=0)
            totals[index]+=1;checked[index]+=(state[i][0]&16)!=0
            nextData[i]=head[index];head[index]=i
        endif
    endfor
    Duplicate/FREE totals,directTotal
    Duplicate/FREE checked,directChecked
    for(i=1;i<n;i+=1)
        ancestor=HMG_Find("folder",folders[i][1]);limit=0
        do
            if(ancestor<0 || limit>n)
                break
            endif
            totals[ancestor]+=directTotal[i];checked[ancestor]+=directChecked[i]
            ancestor=HMG_Find("folder",folders[ancestor][1]);limit+=1
        while(ancestor>=0)
    endfor
End

Function HMG_Refresh()
    if(WinType("HMG_Manager")==0 || NumVarOrDefault("root:MHApp:Manager:batchImporting",0))
        return 0
    endif
    if(HMG_Init()!=0)
        return -1
    endif
    Wave/T folders=root:MHApp:Manager:folders,graphs=root:MHApp:Manager:graphs,ids=root:MHApp:Manager:datasetUID
    Variable capacity=DimSize(folders,0)+DimSize(graphs,0)+numpnts(ids),i
    Make/O/T/N=(capacity,4) root:MHApp:Manager:treeText
    Make/O/N=(capacity,4) root:MHApp:Manager:treeState=0
    Make/O/T/N=(capacity) root:MHApp:Manager:treeUID,root:MHApp:Manager:treeKind,root:MHApp:Manager:treeBaseLabel
    Make/O/D/N=(capacity) root:MHApp:Manager:treeObjectIndex
    Make/O/T/N=4 root:MHApp:Manager:treeTitles={"比較","試料番号","表示名 / フォルダ","種類"}
    Variable/G root:MHApp:Manager:treeRows=0
    Make/FREE/D/N=(DimSize(folders,0)) head
    Make/FREE/D/N=(numpnts(ids)) nextData
    HMG_BuildFolderCounts(head,nextData)
    HMG_AppendFolder("home",0,head,nextData)
    NVAR rows=root:MHApp:Manager:treeRows
    Wave/T treeText=root:MHApp:Manager:treeText,treeUID=root:MHApp:Manager:treeUID,kinds=root:MHApp:Manager:treeKind,labels=root:MHApp:Manager:treeBaseLabel
    Wave treeState=root:MHApp:Manager:treeState,indexes=root:MHApp:Manager:treeObjectIndex
    Redimension/N=(rows,4) treeText,treeState
    Redimension/N=(rows) treeUID,kinds,labels,indexes
    ListBox tree,win=HMG_Manager,listWave=treeText,selWave=treeState,titleWave=root:MHApp:Manager:treeTitles
    SVAR selected=root:MHApp:Manager:selectedUID,kind=root:MHApp:Manager:selectedKind
    for(i=0;i<rows;i+=1)
        if(cmpstr(treeUID[i],selected)==0 && cmpstr(kinds[i],kind)==0)
            ListBox tree,win=HMG_Manager,selRow=i
            break
        endif
    endfor
    NVAR option=root:MHApp:Manager:arrowOption
    Button arrowEdit,win=HMG_Manager,disable=SelectNumber(option!=0,1,0)
    HMG_Details()
    HMA_UpdateStatus()
    return 0
End

Function HMG_AppendRow(uid,kind,label,typeName,isChecked,[index])
    String uid,kind,label,typeName
    Variable isChecked,index
    NVAR rows=root:MHApp:Manager:treeRows
    Wave/T ids=root:MHApp:Manager:treeUID,kinds=root:MHApp:Manager:treeKind,text=root:MHApp:Manager:treeText,labels=root:MHApp:Manager:treeBaseLabel
    Wave state=root:MHApp:Manager:treeState,indexes=root:MHApp:Manager:treeObjectIndex
    Variable row=rows
    rows+=1
    ids[row]=uid;kinds[row]=kind;labels[row]=label;indexes[row]=index
    text[row][0]="";text[row][1]="";text[row][2]=label;text[row][3]=typeName
    state[row][]=0
    if(cmpstr(kind,"data")==0)
        Wave/T numbers=root:MHApp:Manager:sampleNumber
        text[row][1]=numbers[index]
        state[row][0]=32+16*(isChecked!=0)
    endif
    return row
End

Function HMG_FolderRow(index)
    Variable index
    Wave totals=root:MHApp:Manager:folderTotal,checked=root:MHApp:Manager:folderChecked,map=root:MHApp:Manager:folderTreeRow
    Wave/T text=root:MHApp:Manager:treeText,labels=root:MHApp:Manager:treeBaseLabel
    Wave state=root:MHApp:Manager:treeState
    Variable row=map[index]
    if(row<0)
        return 0
    endif
    text[row][2]=labels[row]
    state[row][0]=0
    if(totals[index]>0)
        text[row][2]+="  ("+num2istr(checked[index])+"/"+num2istr(totals[index])+")"
        state[row][0]=32+16*(checked[index]==totals[index])
    endif
    return 0
End

Function HMG_AppendFolder(uid,depth,head,nextData)
    String uid
    Variable depth
    Wave head,nextData
    Wave/T folders=root:MHApp:Manager:folders,ids=root:MHApp:Manager:datasetUID,parents=root:MHApp:Manager:datasetFolder
    Wave/T graphs=root:MHApp:Manager:graphs,names=root:MHApp:names
    Wave state=root:MHApp:listState,map=root:MHApp:Manager:folderTreeRow
    Variable row=HMG_Find("folder",uid),i,expanded
    if(row<0 || depth>DimSize(folders,0))
        return -1
    endif
    String indent=""
    for(i=0;i<depth;i+=1)
        indent+="    "
    endfor
    expanded=cmpstr(folders[row][3],"1")==0
    map[row]=HMG_AppendRow(uid,"folder",indent+SelectString(expanded,"▶ ","▼ ")+folders[row][2],"フォルダ",0,index=row)
    HMG_FolderRow(row)
    if(!expanded)
        return 0
    endif
    for(i=1;i<DimSize(folders,0);i+=1)
        if(cmpstr(folders[i][1],uid)==0)
            HMG_AppendFolder(folders[i][0],depth+1,head,nextData)
        endif
    endfor
    // Bind display waves once per folder instead of once per measurement.
    Wave/T treeUID=root:MHApp:Manager:treeUID,kinds=root:MHApp:Manager:treeKind,text=root:MHApp:Manager:treeText
    Wave/T labels=root:MHApp:Manager:treeBaseLabel,numbers=root:MHApp:Manager:sampleNumber
    Wave treeState=root:MHApp:Manager:treeState,indexes=root:MHApp:Manager:treeObjectIndex
    NVAR rows=root:MHApp:Manager:treeRows
    Variable cursor=rows
    i=head[row]
    do
        if(i<0)
            break
        endif
        treeUID[cursor]=ids[i];kinds[cursor]="data";indexes[cursor]=i
        text[cursor][0]="";text[cursor][1]=numbers[i];text[cursor][2]=indent+"    "+names[i];text[cursor][3]="測定"
        labels[cursor]=text[cursor][2]
        treeState[cursor][0]=32+(state[i][0]&16)
        cursor+=1;i=nextData[i]
    while(1)
    rows=cursor
    for(i=0;i<DimSize(graphs,0);i+=1)
        if(cmpstr(graphs[i][1],uid)==0)
            HMG_AppendRow(graphs[i][0],"graph",indent+"    "+graphs[i][2],"グラフ",0,index=i)
        endif
    endfor
    return 0
End

Function HMG_AdjustFolderChecks(parent,delta)
    String parent
    Variable delta
    Wave/T folders=root:MHApp:Manager:folders
    Wave checked=root:MHApp:Manager:folderChecked
    Variable index=HMG_Find("folder",parent),limit=0
    do
        if(index<0 || limit>DimSize(folders,0))
            break
        endif
        checked[index]+=delta
        HMG_FolderRow(index)
        index=HMG_Find("folder",folders[index][1]);limit+=1
    while(index>=0)
End

Function HMG_TreeAction(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(WhichListItem(num2istr(lba.eventCode),"1;2;3;4;5;13")<0 || lba.row<0)
        return 0
    endif
    Wave/T ids=root:MHApp:Manager:treeUID,kinds=root:MHApp:Manager:treeKind
    Wave state=root:MHApp:Manager:treeState,legacy=root:MHApp:listState,indexes=root:MHApp:Manager:treeObjectIndex
    if(lba.row>=numpnts(ids))
        return 0
    endif
    String selected=ids[lba.row],kind=kinds[lba.row],folder=selected
    Variable index=indexes[lba.row],delta
    if(lba.eventCode==1 && (lba.eventMod&16))
        HMG_Select(kind,selected)
        ListBox tree,win=HMG_Manager,selRow=lba.row
        HMG_Details()
        HMG_TreeMenu(kind,selected)
        return 0
    endif
    if(lba.eventCode==13)
        if(cmpstr(kind,"folder")==0)
            HMG_SetFolderChecks(selected,(state[lba.row][0]&16)!=0)
            return 0
        elseif(cmpstr(kind,"data")==0)
            delta=((state[lba.row][0]&16)!=0)-((legacy[index][0]&16)!=0)
            legacy[index][0]=(legacy[index][0]&~16)+(state[lba.row][0]&16)
            Wave/T parents=root:MHApp:Manager:datasetFolder
            HMG_AdjustFolderChecks(parents[index],delta)
        endif
    endif
    HMG_Select(kind,selected)
    HMG_Details()
    if(lba.eventCode==3)
        if(cmpstr(kind,"folder")==0)
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
    String name=HMG_Name(kind,uid),text="",heading=name,folder=HMG_TargetFolder(),base,win
    Variable i,j,index=HMG_Find(kind,uid)
    if(index<0)
        heading="選択した項目が見つかりません"
    elseif(cmpstr(kind,"folder")==0)
        Wave totals=root:MHApp:Manager:folderTotal,checked=root:MHApp:Manager:folderChecked
        text="取込先：\r"+HMG_FolderPath(uid)+"\r\r測定 "+num2istr(totals[index])+" 件 ／ チェック "+num2istr(checked[index])+" 件\r（子フォルダを含みます）\r\rフォルダのチェックで一括選択。\rダブルクリックで開閉します。"
    elseif(cmpstr(kind,"graph")==0)
        text="作図に使用した測定：\r"+HMG_GraphSources(uid)
        win=HMG_GraphWindow(uid)
        text+="\r状態："+SelectString(strlen(win)>0,"保存済み（閉じています）","開いています")
    else
        Wave/T paths=root:MHApp:paths,graphs=root:MHApp:Manager:graphs,numbers=root:MHApp:Manager:sampleNumber
        text="試料番号："+SelectString(strlen(numbers[index])>0,"未設定",numbers[index])+"\r表示名："+name+"\r単位：kOe / emu/g\r\r使用するグラフ：\r"
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
    TitleBox scope,win=HMG_Manager,title="取込先："+HMG_FolderPath(folder)
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
    HMG_Details()
    return result
End

Function/S HMG_ChooseFolder(title)
    String title
    Wave/T folders=root:MHApp:Manager:folders
    String choices="",name
    Variable i,choice=1
    for(i=0;i<DimSize(folders,0);i+=1)
        name=ReplaceString(";",HMG_FolderPath(folders[i][0]),"；")
        choices+=num2istr(i+1)+": "+name+";"
    endfor
    Prompt choice,"移動先のフォルダ",popup choices
    DoPrompt title,choice
    if(V_flag)
        return ""
    endif
    return folders[choice-1][0]
End

Function HMG_MoveDialog()
    SVAR uid=root:MHApp:Manager:selectedUID,kind=root:MHApp:Manager:selectedKind
    String parent=HMG_ChooseFolder("選択した項目を移動")
    if(strlen(parent)==0)
        return 0
    endif
    if(HMG_Move(kind,uid,parent)!=0)
        DoAlert 0,"移動できません。同名フォルダや、自分自身・子フォルダへの移動を確認してください。"
        return -1
    endif
    String/G root:MHApp:Manager:importFolder=parent
    return HMG_Refresh()
End

Function HMG_ManagerButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    SVAR uid=root:MHApp:Manager:selectedUID,kind=root:MHApp:Manager:selectedKind
    String name,newUID,parent=HMG_TargetFolder(),number
    Variable result
    strswitch(ba.ctrlName)
        case "folderCheck":
            return HMG_SetFolderChecks(parent,1)
        case "folderClear":
            return HMG_SetFolderChecks(parent,0)
        case "clearAll":
            return HMG_SetFolderChecks("home",0)
        case "folder":
            name="新しいフォルダ"
            Prompt name,"フォルダ名"
            DoPrompt "子フォルダを作成",name
            if(!V_flag)
                newUID=HMG_AddFolder(parent,name)
                if(strlen(newUID))
                    uid=newUID;kind="folder"
                    String/G root:MHApp:Manager:importFolder=newUID
                else
                    DoAlert 0,"同名のフォルダや空の名前を確認してください。"
                endif
            endif
            break
        case "rename":
            return HMG_RenameDialog(kind,uid)
        case "move":
            return HMG_MoveDialog()
        case "importVSM":
            HMH_ChooseFiles()
            return 0
        case "review":
            return HMM_ReviewPanel()
        case "show":
            HMG_ShowSelection()
            return 0
        case "compare":
            HMH_DrawGraph(-1)
            return 0
        case "closeGraph":
            return HMP_Close(StrVarOrDefault("root:MHApp:lastGraph",""))
        case "exportGraph":
            return HMP_ExportDialog(StrVarOrDefault("root:MHApp:lastGraph",""))
        case "arrowEdit":
            HMG_ArrowPanel()
            break
        case "saveNow":
            HMA_SaveRecovery()
            return 0
        case "autoDirectory":
            return HMA_ChooseDirectory()
    endswitch
    HMG_Refresh()
    return 0
End

Function HMG_ArrowOption(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    if(cba.eventCode==2)
        Variable/G root:MHApp:Manager:arrowOption=cba.checked
        Button arrowEdit,win=HMG_Manager,disable=SelectNumber(cba.checked!=0,1,0)
    endif
    return 0
End

Function HMG_IsWithin(parent,ancestor)
    String parent,ancestor
    Wave/T folders=root:MHApp:Manager:folders
    Variable limit=0
    do
        if(cmpstr(parent,ancestor)==0)
            return 1
        endif
        parent=HMG_Parent("folder",parent);limit+=1
    while(strlen(parent)>0 && limit<=DimSize(folders,0))
    return 0
End

Function HMG_SetFolderChecks(parent,isChecked)
    String parent
    Variable isChecked
    if(HMG_Find("folder",parent)<0)
        return -1
    endif
    Wave/T parents=root:MHApp:Manager:datasetFolder
    Wave state=root:MHApp:listState
    Wave/T folders=root:MHApp:Manager:folders
    String included=""
    Variable i
    if(cmpstr(parent,"home")==0)
        state[][0]=(state[p][0]&~16)+16*(isChecked!=0)
    else
        for(i=0;i<DimSize(folders,0);i+=1)
            if(HMG_IsWithin(folders[i][0],parent))
                included+=folders[i][0]+";"
            endif
        endfor
        for(i=0;i<numpnts(parents);i+=1)
            if(WhichListItem(parents[i],included)>=0)
                state[i][0]=(state[i][0]&~16)+16*(isChecked!=0)
            endif
        endfor
    endif
    return HMG_Refresh()
End

Function HMG_RenameDialog(kind,uid)
    String kind,uid
    String name,number
    name=HMG_Name(kind,uid)
    Prompt name,"表示名"
    if(cmpstr(kind,"data")==0)
        number=HMM_SampleNumber(uid)
        Prompt number,"試料番号（表示名とは別に保存）"
        DoPrompt "測定の名前と番号",name,number
        if(!V_flag && HMG_Rename(kind,uid,name)==0)
            Wave/T numbers=root:MHApp:Manager:sampleNumber
            numbers[HMG_Find("data",uid)]=TrimString(number)
        endif
    else
        DoPrompt "名前を変更",name
        if(!V_flag && HMG_Rename(kind,uid,name)!=0)
            DoAlert 0,"同名の項目や空の名前を確認してください。"
        endif
    endif
    return HMG_Refresh()
End


Function HMG_TreeMenu(kind,uid)
    String kind,uid
    String choices
    strswitch(kind)
        case "folder":
            if(cmpstr(uid,"home")==0)
                return 0
            endif
            choices="名前を変更…;移動…;順番を上へ;順番を下へ;-;フォルダを削除…;"
            break
        case "data":
            choices="名前・試料番号を変更…;移動…;順番を上へ;順番を下へ;データを差し替え…;-;測定データを削除…;元の .VSM ファイルを削除…;"
            break
        case "graph":
            choices="開く;名前を変更…;移動…;画像を保存…;グラフを削除;"
            break
        default:
            return 0
    endswitch
    PopupContextualMenu choices
    if(V_flag==0)
        return 0
    endif
    Variable result=0,refNum
    String path
    strswitch(S_selection)
        case "名前を変更…":
        case "名前・試料番号を変更…":
            return HMG_RenameDialog(kind,uid)
        case "移動…":
            return HMG_MoveDialog()
        case "順番を上へ":
            result=HMG_Reorder(kind,uid,-1)
            break
        case "順番を下へ":
            result=HMG_Reorder(kind,uid,1)
            break
        case "フォルダを削除…":
            DoAlert 1,"フォルダを削除しますか？ 中の項目は親フォルダに移ります。"
            if(V_flag==1)
                result=HMG_DeleteFolder(uid)
            endif
            break
        case "測定データを削除…":
            DoAlert 1,"Experiment内の測定と、関連する保存図を削除しますか？ 元の .VSM は残ります。"
            if(V_flag==1)
                result=HMG_DeleteData(uid)
            endif
            break
        case "データを差し替え…":
            Open/D/R/F="VSM measurement (*.VSM):.VSM;"/M="差し替える .VSM を選択" refNum
            if(strlen(S_fileName))
                result=HMG_ReplaceData(uid,S_fileName)
            endif
            break
        case "元の .VSM ファイルを削除…":
            Wave/T paths=root:MHApp:paths
            path=StrVarOrDefault(paths[HMG_Find("data",uid)]+"sourceFile","")
            DoAlert 1,"次の原本をディスクから削除します。元に戻せません。\r"+path
            if(V_flag==1)
                result=HMG_DeleteSource(uid)
                if(result!=0)
                    result=-1
                endif
            endif
            break
        case "グラフを削除":
            path=HMG_Parent("graph",uid)
            result=HMG_DeleteGraph(uid)
            if(result==0)
                HMG_Select("folder",path)
            endif
            break
        case "画像を保存…":
            if(HMG_OpenGraph(uid)==0)
                return HMP_ExportDialog(HMG_GraphWindow(uid))
            endif
            return -1
        case "開く":
            return HMG_ShowSelection()
    endswitch
    if(result<0)
        DoAlert 0,"操作できませんでした。使用中のデータ、同名のフォルダ、元ファイルの場所を確認してください。"
    endif
    HMG_Refresh()
    return result
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
    String win=StrVarOrDefault("root:MHApp:lastGraph",""),uid,choices="新しい矢印を追加;",aid
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
    String arrows=GetUserData(win,"","HMPArrows")
    if(strlen(arrows)==0)
        uid=GetUserData(win,"","HMHGraphUID")
        Wave/T/Z stored=$(HMG_GraphPath(uid)+"arrowIDs")
        if(strlen(uid) && WaveExists(stored))
            Variable a
            for(a=0;a<numpnts(stored);a+=1)
                arrows+=stored[a]+";"
            endfor
        endif
    endif
    Variable i,choice=1,x1,x2,y1,y2
    for(i=0;i<ItemsInList(arrows);i+=1)
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
        aid=StringFromList(choice-2,arrows)
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
        SetWindow $win userdata(HMPArrows)=arrows+aid+";"
    endif
    return 0
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
    HMP_Front(win)
    SetActiveSubwindow $win
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

// ---- mh_metadata ----

Function/S HMM_NormalizeLabel(label)
    String label
    String result="",ch
    Variable i=0
    do
        if(i>=strlen(label))
            break
        endif
        ch=label[i]
        if(cmpstr(ch,"=")==0 || cmpstr(ch,",")==0)
            if(cmpstr(ch,"=")==0)
                result=RemoveEnding(RemoveEnding(result," "),"\t")
                do
                    if(strlen(result)==0 || (cmpstr(result[strlen(result)-1]," ")!=0 && cmpstr(result[strlen(result)-1],"\t")!=0))
                        break
                    endif
                    result=RemoveEnding(result,result[strlen(result)-1])
                while(1)
                result+=" = "
            else
                result+=", "
            endif
            i+=1
            do
                if(i>=strlen(label) || (cmpstr(label[i]," ")!=0 && cmpstr(label[i],"\t")!=0))
                    break
                endif
                i+=1
            while(1)
        else
            result+=ch;i+=1
        endif
    while(1)
    return TrimString(result)
End

Function/S HMM_FileName(path)
    String path
    String normalized=ReplaceString("\\",path,":")
    return StringFromList(ItemsInList(normalized,":")-1,normalized,":")
End

Function HMM_ParseName(path,sample,composition)
    String path
    String &sample,&composition
    String file=HMM_FileName(path),body,condition
    sample="";composition=""
    SplitString/E="(?i)^MH-([0-9]+)-(.+)-([0-9]+(?:[.][0-9]+)?in[^_]*)_[0-9].*[.]VSM$" file,sample,body,condition
    if(V_flag!=3)
        sample="";composition=""
        return 0
    endif
    composition=HMM_NormalizeLabel(body)
    return 1
End

Function HMM_Init()
    NVAR count=root:MHApp:count
    Wave/T paths=root:MHApp:paths
    Wave/T/Z numbers=root:MHApp:Manager:sampleNumber
    Variable old=0,i
    if(!WaveExists(numbers))
        Make/O/T/N=0 root:MHApp:Manager:sampleNumber,root:MHApp:Manager:composition,root:MHApp:Manager:sourceName
    endif
    Wave/T numbers=root:MHApp:Manager:sampleNumber,compositions=root:MHApp:Manager:composition,sources=root:MHApp:Manager:sourceName
    old=numpnts(numbers)
    if(old>count || numpnts(compositions)!=old || numpnts(sources)!=old)
        return -1
    endif
    String sample,composition,file
    if(old<count)
        Redimension/N=(count) numbers,compositions,sources
        for(i=old;i<count;i+=1)
            SVAR/Z source=$(paths[i]+"sourceFile")
            file=""
            if(SVAR_Exists(source))
                file=source
            endif
            HMM_ParseName(file,sample,composition)
            numbers[i]=sample;compositions[i]=composition;sources[i]=HMM_FileName(file)
        endfor
    endif
    return 0
End

Function/S HMM_SampleNumber(uid)
    String uid
    Variable i=HMG_Find("data",uid)
    Wave/T/Z numbers=root:MHApp:Manager:sampleNumber
    if(i<0 || !WaveExists(numbers) || i>=numpnts(numbers))
        return ""
    endif
    return numbers[i]
End

Function HMM_ImportBatch(fileList,parent)
    String fileList,parent
    if(HMG_Init()!=0 || HMG_Find("folder",parent)<0)
        return -1
    endif
    if(WinType("HMM_ImportReview"))
        if(HMM_ApplyReview()!=0)
            DoAlert 0,"追加分の名前を確認してから次のファイルを追加してください。"
            return -1
        endif
        DoWindow/K HMM_ImportReview
    endif
    NewDataFolder/O root:MHApp:Manager:ImportReview
    Variable total=ItemsInList(fileList,"\r")
    Make/O/T/N=(total) root:MHApp:Manager:ImportReview:ids
    Wave/T batch=root:MHApp:Manager:ImportReview:ids
    NVAR count=root:MHApp:count
    Variable i,before,added=0,failed=0
    String file
    // Suppress tree construction per file; redraw once at the end of the batch.
    HMH_SaveNames()
    Variable/G root:MHApp:Manager:batchImporting=1
    try
    for(i=0;i<total;i+=1)
        file=StringFromList(i,fileList,"\r")
        if(strlen(file)==0)
            continue
        endif
        before=count
        if(HMH_Import(file,folderUID=parent)==0 && count==before+1)
            Wave/T ids=root:MHApp:Manager:datasetUID
            batch[added]=ids[before]
            added+=1
        else
            failed+=1
        endif
    endfor
    catch
        Variable err=GetRTError(1)
        failed+=total-i
        Print "MH: 読込を中断しました: ",err
    endtry
    Variable/G root:MHApp:Manager:batchImporting=0
    Redimension/N=(added) batch
    Variable/G root:MHApp:Manager:ImportReview:failures=failed
    HMM_PrepareReview()
    HMG_Refresh()
    return added
End

Function HMM_PrepareReview()
    Wave/T batch=root:MHApp:Manager:ImportReview:ids
    Wave/T names=root:MHApp:names,numbers=root:MHApp:Manager:sampleNumber,sources=root:MHApp:Manager:sourceName
    Variable n=numpnts(batch),i,index
    Make/O/T/N=(n,3) root:MHApp:Manager:ImportReview:text
    Make/O/N=(n,3) root:MHApp:Manager:ImportReview:state
    Make/O/T/N=3 root:MHApp:Manager:ImportReview:titles={"試料番号","表示名（凡例）","今回追加したファイル"}
    Wave/T text=root:MHApp:Manager:ImportReview:text
    Wave state=root:MHApp:Manager:ImportReview:state
    for(i=0;i<n;i+=1)
        index=HMG_Find("data",batch[i])
        if(index<0)
            return -1
        endif
        text[i][0]=numbers[index];text[i][1]=names[index];text[i][2]=sources[index]
        state[i][0]=6;state[i][1]=6;state[i][2]=0
    endfor
    return 0
End

Function HMM_ReviewPanel()
    Wave/T/Z batch=root:MHApp:Manager:ImportReview:ids
    if(!WaveExists(batch))
        return 0
    endif
    Variable n=numpnts(batch)
    if(n==0)
        return 0
    endif
    if(WinType("HMM_ImportReview"))
        DoWindow/F HMM_ImportReview
        return 0
    endif
    HMM_PrepareReview()
    NewPanel/N=HMM_ImportReview/W=(70,70,1080,540) as "MH：今回追加した測定の名前を確認"
    DefaultGUIFont/W=HMM_ImportReview all={"Segoe UI",12,0}
    Variable failed=NumVarOrDefault("root:MHApp:Manager:ImportReview:failures",0)
    String heading="今回追加した "+num2istr(n)+" 件。試料番号と表示名は別々に編集できます。"
    if(failed)
        heading+="　未読込 "+num2istr(failed)+" 件（履歴を確認）"
    endif
    TitleBox title,pos={18,15},frame=0,title=heading
    ListBox imported,pos={18,50},size={972,304},widths={95,315,540},mode=1,listWave=root:MHApp:Manager:ImportReview:text,selWave=root:MHApp:Manager:ImportReview:state,titleWave=root:MHApp:Manager:ImportReview:titles
    TitleBox hint,pos={18,367},frame=0,title="セルをダブルクリックして編集。例：044 ／ x = 0。元のファイル名は変更しません。"
    Button apply,pos={18,407},size={280,32},title="名前・試料番号を反映",proc=HMM_ReviewButton
    Button moveBatch,pos={310,407},size={300,32},title="今回追加分だけを別フォルダへ移動",proc=HMM_ReviewButton
    Button done,pos={622,407},size={368,32},title="反映して閉じる",proc=HMM_ReviewButton
    return 0
End

Function HMM_ApplyReview()
    Wave/T/Z batch=root:MHApp:Manager:ImportReview:ids,text=root:MHApp:Manager:ImportReview:text
    if(!WaveExists(batch) || !WaveExists(text))
        return 0
    endif
    Variable i,index,n=numpnts(batch)
    for(i=0;i<n;i+=1)
        if(HMG_Find("data",batch[i])<0 || strlen(TrimString(text[i][1]))==0 || strsearch(text[i][0]+text[i][1],"\r",0)>=0 || strsearch(text[i][0]+text[i][1],"\n",0)>=0)
            return -1
        endif
    endfor
    Wave/T names=root:MHApp:names,list=root:MHApp:listText,numbers=root:MHApp:Manager:sampleNumber
    for(i=0;i<n;i+=1)
        index=HMG_Find("data",batch[i])
        numbers[index]=TrimString(text[i][0])
        names[index]=HMM_NormalizeLabel(text[i][1])
        list[index][1]=names[index];text[i][0]=numbers[index];text[i][1]=names[index]
    endfor
    return 0
End

Function HMM_MoveBatch(parent)
    String parent
    if(HMG_Find("folder",parent)<0 || HMM_ApplyReview()!=0)
        return -1
    endif
    Wave/T batch=root:MHApp:Manager:ImportReview:ids,parents=root:MHApp:Manager:datasetFolder
    Variable i
    for(i=0;i<numpnts(batch);i+=1)
        if(HMG_Find("data",batch[i])<0)
            return -1
        endif
    endfor
    for(i=0;i<numpnts(batch);i+=1)
        parents[HMG_Find("data",batch[i])]=parent
    endfor
    HMG_Refresh()
    return 0
End

Function HMM_ReviewButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(HMM_ApplyReview()!=0)
        DoAlert 0,"表示名が空の行や改行を確認してください。反映していません。"
        return 0
    endif
    if(cmpstr(ba.ctrlName,"moveBatch")==0)
        String parent=HMG_ChooseFolder("今回追加した測定だけを移動")
        if(strlen(parent))
            HMM_MoveBatch(parent)
        endif
    elseif(cmpstr(ba.ctrlName,"done")==0)
        DoWindow/K HMM_ImportReview
    endif
    HMG_Refresh()
    return 0
End

// ---- mh_autosave ----

Function HMA_Init()
    NewDataFolder/O root:MHApp:Manager:Autosave
    String base="root:MHApp:Manager:Autosave:"
    HMH_DefaultNumber(base+"enabled",1)
    HMH_DefaultNumber(base+"interval",300)
    HMH_DefaultNumber(base+"saving",0)
    HMH_DefaultNumber(base+"nextDue",DateTime+300)
    HMH_DefaultNumber(base+"lastSavedAt",0)
    HMH_DefaultNumber(base+"saveCount",0)
    SVAR/Z directory=$(base+"directory"),session=$(base+"session")
    if(!SVAR_Exists(directory))
        String/G $(base+"directory")=SpecialDirPath("Documents",0,0,0)+"MH_Autosave:"
        String/G $(base+"lastPath")=""
        String/G $(base+"status")="5分ごとに復旧用コピーを保存します"
    endif
    if(!SVAR_Exists(session))
        String/G $(base+"session")=HMG_NewUID("recovery")
    endif
    return 0
End

Function HMA_Arm()
    HMA_Init()
    NVAR enabled=root:MHApp:Manager:Autosave:enabled,saving=root:MHApp:Manager:Autosave:saving,nextDue=root:MHApp:Manager:Autosave:nextDue
    saving=0;nextDue=DateTime+300
    CtrlNamedBackground HMARecovery,period=18000,proc=HMA_Background,dialogsOK=0,burst=0
    if(enabled)
        CtrlNamedBackground HMARecovery,start
    else
        CtrlNamedBackground HMARecovery,stop
    endif
    return 0
End

Function HMA_EnsureArmed()
    NVAR enabled=root:MHApp:Manager:Autosave:enabled
    if(!enabled)
        return 0
    endif
    CtrlNamedBackground HMARecovery,status
    if(NumberByKey("RUN",S_info)!=1)
        HMA_Arm()
    endif
    return 0
End

// Only already-initialized autosave state is resumed on compile/reopen.
// Loading the new Procedure into a legacy Experiment does not migrate its data.
static Function AfterCompiledHook()
    NVAR/Z enabled=root:MHApp:Manager:Autosave:enabled
    if(NVAR_Exists(enabled))
        HMA_Arm()
    endif
    return 0
End

Function HMA_Background(s)
    STRUCT WMBackgroundStruct &s
    NVAR/Z schema=root:MHApp:Manager:schemaVersion,enabled=root:MHApp:Manager:Autosave:enabled
    if(!NVAR_Exists(schema) || !NVAR_Exists(enabled))
        return 1
    endif
    HMA_Tick(DateTime)
    return 0
End

Function HMA_Tick(now)
    Variable now
    NVAR enabled=root:MHApp:Manager:Autosave:enabled,nextDue=root:MHApp:Manager:Autosave:nextDue
    NVAR saving=root:MHApp:Manager:Autosave:saving,busy=root:MHApp:Manager:busy
    if(!enabled || saving || busy || now<nextDue)
        return 0
    endif
    nextDue=now+300
    return HMA_SaveRecovery()
End

Function HMA_SaveRecovery()
    NVAR saving=root:MHApp:Manager:Autosave:saving,busy=root:MHApp:Manager:busy
    if(saving || busy)
        return -1
    endif
    SVAR directory=root:MHApp:Manager:Autosave:directory,session=root:MHApp:Manager:Autosave:session
    SVAR lastPath=root:MHApp:Manager:Autosave:lastPath,status=root:MHApp:Manager:Autosave:status
    NVAR lastSaved=root:MHApp:Manager:Autosave:lastSavedAt,count=root:MHApp:Manager:Autosave:saveCount
    Variable oldTime=lastSaved,oldCount=count,error=0,slot
    String oldPath=lastPath,oldSession=session,target
    // A recovery file may itself be open as the working Experiment.
    // Give that run a new recovery series so neither generation can overwrite it.
    if(StringMatch(LowerStr(HMM_FileName(IgorInfo(1))),LowerStr(session)+"_*"))
        session=HMG_NewUID("recovery")
        count=0
    endif
    slot=mod(count,2)+1
    target=directory+session+"_"+num2istr(slot)+".pxp"
    saving=1
    try
        NewPath/C/O/Q/Z HMARecoveryPath,directory
        if(V_flag!=0)
            Abort "自動保存先を作成できませんでした。"
        endif
        lastSaved=DateTime;count+=1;lastPath=target
        status="最終保存 "+Secs2Time(lastSaved,3)+"（復旧用コピー）"
        // /C preserves the user's original Experiment file and its save identity.
        SaveExperiment/C/F={1,"",0} as target
    catch
        error=GetRTError(1)
        if(error==0)
            error=-1
        endif
        lastSaved=oldTime;count=oldCount;lastPath=oldPath;session=oldSession
        status="自動保存に失敗しました。保存先を確認してください。"
        Print "MH: "+status
    endtry
    saving=0
    HMA_UpdateStatus()
    if(error)
        return -1
    endif
    return 1
End

Function HMA_UpdateStatus()
    if(WinType("HMG_Manager")==0)
        return 0
    endif
    SVAR status=root:MHApp:Manager:Autosave:status,directory=root:MHApp:Manager:Autosave:directory
    NVAR enabled=root:MHApp:Manager:Autosave:enabled
    String label=SelectString(enabled!=0,"自動保存：停止中",status)
    TitleBox autoStatus,win=HMG_Manager,title=label,help={directory}
    return 0
End

Function HMA_Toggle(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    if(cba.eventCode==2)
        Variable/G root:MHApp:Manager:Autosave:enabled=cba.checked
        HMA_Arm()
        HMA_UpdateStatus()
    endif
    return 0
End

Function HMA_ChooseDirectory()
    NewPath/O/M="復旧用コピーの保存先を選んでください" HMAChosenPath
    if(V_flag)
        return 0
    endif
    PathInfo HMAChosenPath
    String/G root:MHApp:Manager:Autosave:directory=S_path
    String/G root:MHApp:Manager:Autosave:status="保存先を設定しました。5分ごとに保存します。"
    HMA_UpdateStatus()
    return 0
End

// ---- mh_manage_actions ----

Function HMG_Reorder(kind,uid,direction)
    String kind,uid
    Variable direction
    if(HMG_Init()!=0 || cmpstr(uid,"home")==0 || abs(direction)!=1)
        return -1
    endif
    Variable row=HMG_Find(kind,uid),other
    if(row<0)
        return -1
    endif
    String parent=HMG_Parent(kind,uid)
    if(cmpstr(kind,"folder")==0)
        Wave/T folders=root:MHApp:Manager:folders
        for(other=row+direction;other>0 && other<DimSize(folders,0);other+=direction)
            if(cmpstr(folders[other][1],parent)==0)
                Make/FREE/T/N=4 entry=folders[row][p]
                folders[row][]=folders[other][q]
                folders[other][]=entry[q]
                return 0
            endif
        endfor
    elseif(cmpstr(kind,"data")==0)
        Wave/T parents=root:MHApp:Manager:datasetFolder
        for(other=row+direction;other>=0 && other<numpnts(parents);other+=direction)
            if(cmpstr(parents[other],parent)==0)
                HMG_SwapDatasetRows(row,other)
                return 0
            endif
        endfor
    endif
    return 1
End

Function HMG_SwapDatasetRows(first,second)
    Variable first,second
    String keys="root:MHApp:paths;root:MHApp:names;root:MHApp:Manager:datasetUID;root:MHApp:Manager:sampleNumber;root:MHApp:Manager:composition;root:MHApp:Manager:sourceName;"
    Variable i,column,flags
    String value
    for(i=0;i<ItemsInList(keys);i+=1)
        Wave/T field=$StringFromList(i,keys)
        value=field[first]
        field[first]=field[second]
        field[second]=value
    endfor
    Wave/T text=root:MHApp:listText
    Wave state=root:MHApp:listState
    for(column=0;column<DimSize(text,1);column+=1)
        value=text[first][column]
        text[first][column]=text[second][column]
        text[second][column]=value
        flags=state[first][column]
        state[first][column]=state[second][column]
        state[second][column]=flags
    endfor
End

Function HMG_Select(kind,uid)
    String kind,uid
    String/G root:MHApp:Manager:selectedKind=kind
    String/G root:MHApp:Manager:selectedUID=uid
    String/G root:MHApp:Manager:importFolder=SelectString(cmpstr(kind,"folder")==0,HMG_Parent(kind,uid),uid)
    return 0
End

Function HMG_DeleteFolder(uid)
    String uid
    Variable row=HMG_Find("folder",uid),i
    if(row<=0)
        return -1
    endif
    String parent=HMG_Parent("folder",uid)
    Wave/T folders=root:MHApp:Manager:folders,parents=root:MHApp:Manager:datasetFolder,graphs=root:MHApp:Manager:graphs
    // Check collisions before promoting anything to the parent.
    for(i=1;i<DimSize(folders,0);i+=1)
        if(cmpstr(folders[i][1],uid)==0 && !HMG_NameAvailable("folder",parent,folders[i][2],uid))
            return -2
        endif
    endfor
    for(i=0;i<DimSize(graphs,0);i+=1)
        if(cmpstr(graphs[i][1],uid)==0 && !HMG_NameAvailable("graph",parent,graphs[i][2],graphs[i][0]))
            return -2
        endif
    endfor
    folders[][1]=SelectString(cmpstr(folders[p][1],uid)==0,folders[p][1],parent)
    graphs[][1]=SelectString(cmpstr(graphs[p][1],uid)==0,graphs[p][1],parent)
    parents=SelectString(cmpstr(parents[p],uid)==0,parents[p],parent)
    DeletePoints/M=0 row,1,folders
    return HMG_Select("folder",parent)
End

Function HMG_DeleteData(uid)
    String uid
    Variable row=HMG_Find("data",uid)
    if(row<0)
        return -1
    endif
    Wave/T paths=root:MHApp:paths,parents=root:MHApp:Manager:datasetFolder
    String runPath=paths[row],parent=parents[row]
    // Never delete outside the application's registered measurement folders.
    if(!StringMatch(runPath,"root:MHApp:Run*:") || ItemsInList(runPath,":")!=3)
        return -1
    endif
    HMG_ClosePlotsUsing(runPath)
    KillDataFolder/Z $runPath
    if(DataFolderExists(runPath))
        Variable blockedError=GetRTError(1)
        return -2
    endif
    Wave/T graphs=root:MHApp:Manager:graphs
    Variable i
    for(i=DimSize(graphs,0)-1;i>=0;i-=1)
        if(HMG_GraphUsesData(graphs[i][0],uid,runPath))
            HMG_DeleteGraph(graphs[i][0])
        endif
    endfor
    Wave/T names=root:MHApp:names,text=root:MHApp:listText,ids=root:MHApp:Manager:datasetUID
    Wave/T numbers=root:MHApp:Manager:sampleNumber,compositions=root:MHApp:Manager:composition,sources=root:MHApp:Manager:sourceName
    Wave state=root:MHApp:listState
    DeletePoints/M=0 row,1,paths,names,text,state,ids,parents,numbers,compositions,sources
    NVAR count=root:MHApp:count
    count-=1
    if(count==0)
        Redimension/N=1 paths,names
        Redimension/N=(1,2) text,state
        text="";state=0
    endif
    Wave/T/Z review=root:MHApp:Manager:ImportReview:ids
    if(WaveExists(review))
        FindValue/TEXT=uid/TXOP=4 review
        if(V_value>=0)
            i=V_value
            Wave/T reviewText=root:MHApp:Manager:ImportReview:text
            Wave reviewState=root:MHApp:Manager:ImportReview:state
            DeletePoints/M=0 i,1,review,reviewText,reviewState
            if(numpnts(review)==0)
                DoWindow/K HMM_ImportReview
            endif
        endif
    endif
    return HMG_Select("folder",parent)
End

Function HMG_ReplaceData(uid,file)
    String uid,file
    Variable row=HMG_Find("data",uid)
    if(row<0)
        return -1
    endif
    Wave/T paths=root:MHApp:paths
    String target=paths[row],staged="",number,composition
    if(HMH_ReadVSM(file,staged)!=0)
        return -2
    endif
    Wave rawH=$(staged+"H_Oe"),rawM=$(staged+"M_emu"),field=$(staged+"H_kOe"),moment=$(staged+"M_emu_g")
    NVAR mass=$(staged+"sampleMassG")
    Duplicate/O rawH,$(target+"H_Oe")
    Duplicate/O rawM,$(target+"M_emu")
    Duplicate/O field,$(target+"H_kOe")
    Duplicate/O moment,$(target+"M_emu_g")
    Variable/G $(target+"sampleMassG")=mass
    String/G $(target+"sourceFile")=file
    HMM_ParseName(file,number,composition)
    Wave/T compositions=root:MHApp:Manager:composition,sources=root:MHApp:Manager:sourceName
    compositions[row]=composition
    sources[row]=HMM_FileName(file)
    KillDataFolder/Z $staged
    Wave/T/Z review=root:MHApp:Manager:ImportReview:ids,reviewText=root:MHApp:Manager:ImportReview:text
    if(WaveExists(review) && WaveExists(reviewText))
        FindValue/TEXT=uid/TXOP=4 review
        if(V_value>=0)
            reviewText[V_value][2]=sources[row]
        endif
    endif
    return 0
End

Function HMG_DeleteSource(uid)
    String uid
    Variable row=HMG_Find("data",uid)
    if(row<0)
        return -1
    endif
    Wave/T paths=root:MHApp:paths
    String source=StrVarOrDefault(paths[row]+"sourceFile","")
    if(!StringMatch(LowerStr(source),"*.vsm") || strsearch(source,":",0)<0)
        return -1
    endif
    GetFileFolderInfo/Q/Z source
    if(V_flag!=0 || !V_isFile)
        return -1
    endif
    DeleteFile/Z=1 source
    return V_flag
End

// ---- mh_preview ----

Function HMP_CloseMode()
    // Igor 9 supports a silent close. Igor 10 can also omit open previews from a PXP.
    return SelectNumber(IgorVersion()>=10,1,4)
End

Function HMP_NeedsOverlay()
    if(WinType("HMG_Manager"))
        GetWindow HMG_Manager maximize
        if(V_value)
            return 1
        endif
    endif
    if(WinType("HMH_Panel"))
        GetWindow HMH_Panel maximize
        return V_value
    endif
    return 0
End

Function/S HMP_NewHost(title)
    String title
    String host=UniqueName("MH_Preview",6,0)
    NewPanel/FLT/K=(HMP_CloseMode())/N=$host/W=(110,100,735,625) as title
    ModifyPanel/W=$host fixedSize=0
    SetWindow $host userdata(HMPHost)="1",activeChildFrame=0
    return host
End

Function/S HMP_PlotList()
    String wins=WinList("*",";","WIN:1"),hosts=WinList("MH_Preview*",";","FLT:1")
    String host,plot
    Variable i
    for(i=0;i<ItemsInList(hosts);i+=1)
        host=StringFromList(i,hosts)
        if(cmpstr(GetUserData(host,"","HMPHost"),"1")==0)
            plot=host+"#Plot"
            if(WinType(plot)==1)
                wins+=plot+";"
            endif
        endif
    endfor
    return wins
End

Function HMP_Front(win)
    String win
    if(WinType(win)!=1)
        return -1
    endif
    String host=StringFromList(0,win,"#")
    DoWindow/F $host
    return 0
End

Function HMP_Close(win)
    String win
    if(WinType(win)==1)
        String host=StringFromList(0,win,"#")
        KillWindow/Z $host
        if(WinType(win)==1)
            return -1
        endif
        SVAR/Z last=root:MHApp:lastGraph
        if(SVAR_Exists(last) && cmpstr(last,win)==0)
            last=""
        endif
    endif
    return 0
End

Function HMP_ResizeOverlay(win,width,height)
    String win
    Variable width,height
    if(strsearch(win,"#",0)<0)
        return 0
    endif
    String host=StringFromList(0,win,"#")
    if(cmpstr(GetUserData(host,"","HMPHost"),"1")!=0)
        return 0
    endif
    GetWindow $host wsize
    Variable left=V_left,top=V_top
    MoveWindow/W=$host left,top,left+width,top+height
    return 0
End

Function/S HMP_DefaultExportName(win)
    String win
    String traces=TraceNameList(win,";",1),name=""
    if(strlen(traces))
        Wave/Z y=TraceNameToWaveRef(win,StringFromList(0,traces))
        if(WaveExists(y))
            name=HMM_FileName(StrVarOrDefault(GetWavesDataFolder(y,1)+"sourceFile",""))
        endif
    endif
    if(StringMatch(LowerStr(name),"*.vsm"))
        return name[0,strlen(name)-5]+".png"
    endif
    String uid=GetUserData(win,"","HMHGraphUID")
    name=HMG_Name("graph",uid)
    if(strlen(name)==0)
        name=StringFromList(0,win,"#")
    endif
    String illegal=num2char(92)+num2char(34)+"/:*?<>|"
    Variable i
    for(i=0;i<strlen(illegal);i+=1)
        name=ReplaceString(illegal[i],name,"_")
    endfor
    return name+".png"
End

Function HMP_WritePNG(win,path)
    String win,path
    if(WinType(win)!=1 || !StringMatch(LowerStr(path),"*.png"))
        return -1
    endif
    SavePICT/O/E=-5/B=288/WIN=$win as path
    return V_flag
End

Function HMP_ExportDialog(win)
    String win
    if(WinType(win)!=1)
        return -1
    endif
    Variable refNum
    String file=HMP_DefaultExportName(win)
    Open/D/F="PNG image (*.png):.png;"/M="MHグラフをPNGで保存" refNum as file
    if(strlen(S_fileName)==0)
        return 0
    endif
    if(HMP_WritePNG(win,S_fileName)!=0)
        DoAlert 0,"画像を保存できませんでした。保存先を確認してください。"
        return -1
    endif
    return 0
End

Menu "GraphPopup", dynamic
    HMP_GraphMenuItem("画像を保存…"), /Q, HMP_RunGraphMenu(0)
    HMP_GraphMenuItem("グラフを閉じる"), /Q, HMP_RunGraphMenu(1)
End

Menu "TracePopup", dynamic
    HMP_GraphMenuItem("画像を保存…"), /Q, HMP_RunGraphMenu(0)
    HMP_GraphMenuItem("グラフを閉じる"), /Q, HMP_RunGraphMenu(1)
End

Function/S HMP_GraphMenuItem(label)
    String label
    GetLastUserMenuInfo
    String win=S_graphName
    if(strlen(win)==0 || WinType(win)!=1)
        return ""
    endif
    return SelectString(strlen(GetUserData(win,"","HMHFigure")) || strlen(GetUserData(win,"","HMHGraphUID")),"",label)
End

Function HMP_RunGraphMenu(closePlot)
    Variable closePlot
    GetLastUserMenuInfo
    String win=S_graphName
    if(WinType(win)!=1)
        return -1
    endif
    if(closePlot)
        return HMP_Close(win)
    endif
    return HMP_ExportDialog(win)
End
