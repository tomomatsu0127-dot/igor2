#pragma rtGlobals=3
#pragma version=2.40
#include ":mh_figure"
#include ":mh_axis"
#include ":mh_store"
#include ":mh_graph_store"
#include ":mh_tree"
#include ":mh_arrow"
#include ":mh_metadata"
#include ":mh_autosave"
#include ":mh_manage_actions"
#include ":mh_preview"

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
