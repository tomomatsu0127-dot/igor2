#pragma rtGlobals=3
// v1.2.0: one expandable project tree, with independent selection storage.
Function/S XRD110_TreeBase(kind)
    Variable kind
    String base="root:Packages:XRDWorkbench:UI:Tree110_"+num2istr(kind)
    XRD_UISettings()
    NewDataFolder/O $base
    SVAR/Z expanded=$(base+":expanded")
    if(!SVAR_Exists(expanded))
        String/G $(base+":expanded")=""
    endif
    return base
End

Function/S XRD110_Master(kind)
    Variable kind
    return XRD_PlotRoot()+SelectString(kind==2,":UI",":CompareUI")
End

Function XRD110_TreeBuild(kind)
    Variable kind
    String base=XRD110_TreeBase(kind),projects=XRD_ProjectList(),project,list,path,uid,master=XRD110_Master(kind)
    SVAR expanded=$(base+":expanded")
    Variable i,j,n=ItemsInList(projects),row=0,k,index
    for(i=0;i<ItemsInList(projects);i+=1)
        project=StringFromList(i,projects);uid=XRD80_ProjectUID(project)
        if(WhichListItem(uid,expanded)>=0)
            n+=ItemsInList(XRD_MeasurementOrderList(project))
        endif
    endfor
    Make/O/T/N=(n,3) $(base+":table")
    Make/O/T/N=(n) $(base+":map"),$(base+":owners")
    Make/O/D/N=(n) $(base+":types")
    Make/O/B/U/N=(n,3) $(base+":flags")=0
    Wave/T table=$(base+":table"),map=$(base+":map"),owners=$(base+":owners")
    Wave types=$(base+":types"),flags=$(base+":flags")
    Wave/T/Z masterPaths=$(master+":paths")
    Wave/Z masterFlags=$(master+":flags")
    for(i=0;i<ItemsInList(projects);i+=1)
        project=StringFromList(i,projects);uid=XRD80_ProjectUID(project)
        table[row][1]=SelectString(WhichListItem(uid,expanded)>=0,"▶  ","▼  ")+XRD_ProjectDisplayName(project)
        table[row][2]=XRD80_ProjectProgress(project)
        map[row]=project;owners[row]=project;types[row]=0;row+=1
        if(WhichListItem(uid,expanded)<0)
            continue
        endif
        list=XRD_MeasurementOrderList(project)
        for(j=0;j<ItemsInList(list);j+=1)
            path=project+":Measurements:"+StringFromList(j,list)
            map[row]=path;owners[row]=project;types[row]=1
            table[row][1]="      "+XRD110_SampleLabel(path)
            XRD_UpdateAnalysisState(path)
            table[row][2]=StrVarOrDefault(path+":analysisState","")
            if(kind && WaveExists(masterPaths))
                for(k=0;k<numpnts(masterPaths);k+=1)
                    if(cmpstr(masterPaths[k],path)==0)
                        flags[row][0]=masterFlags[k][0]
                    endif
                endfor
            endif
            row+=1
        endfor
    endfor
    SetDimLabel 1,0,'使用',table
    SetDimLabel 1,1,'プロジェクト / 測定データ',table
    SetDimLabel 1,2,'解析状態',table
    return row
End

Function XRD110_Toggle(kind,project)
    Variable kind
    String project
    String base=XRD110_TreeBase(kind),uid=XRD80_ProjectUID(project)
    SVAR expanded=$(base+":expanded")
    if(WhichListItem(uid,expanded)>=0)
        expanded=RemoveFromList(uid,expanded)
    else
        expanded+=uid+";"
    endif
    XRD110_TreeBuild(kind)
    return WhichListItem(uid,expanded)>=0
End

Function XRD110_Manager()
    XRD_Init()
    String ui="root:Packages:XRDWorkbench:UI:Manager",projects=XRD_ProjectList(),tree=XRD110_TreeBase(0)
    NewDataFolder/O $ui
    Make/O/T/N=(ItemsInList(projects)) $(ui+":projectPaths")
    Wave/T paths=$(ui+":projectPaths")
    Variable i
    for(i=0;i<numpnts(paths);i+=1)
        paths[i]=StringFromList(i,projects)
    endfor
    Make/O/T/N=(0,3) $(ui+":samples")
    Make/O/T/N=0 $(ui+":samplePaths")
    Variable/G $(ui+":projectRow")=-1
    Variable/G $(ui+":sampleRow")=-1
    XRD110_TreeBuild(0)
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDProjectManager")
    DoWindow/K XRDProjectManager
    NewPanel/FLT=1/N=XRDProjectManager/K=1/W=(35,35,1015,715) as "プロジェクトと測定データ"
    DefaultGUIFont all={"Segoe UI",12,0}
    TitleBox help,pos={15,15},frame=0,title="プロジェクト名で展開・折りたたみ。プロジェクト／測定データをダブルクリックして開きます。"
    ListBox projects,pos={15,55},size={935,390},mode=1,listWave=$(tree+":table"),selWave=$(tree+":flags"),widths={1,700,220},proc=XRD110_ManagerList
    Button openProject,pos={15,465},size={330,30},title="選択プロジェクトを開く",proc=XRD80_ManagerButton
    Button addProject,pos={365,465},size={285,30},title="プロジェクトを追加",proc=XRD80_ManagerButton
    Button openSample,pos={665,465},size={285,30},title="選択した測定データを開く",proc=XRD80_ManagerButton
    Button renameProject,pos={15,510},size={330,30},title="選択プロジェクト名を変更",proc=XRD80_ManagerButton
    Button figures,pos={365,510},size={590,30},title="作図ウィンドウを開く",proc=XRD80_ManagerButton
    XRD100_ManagerControls()
    SetWindow XRDProjectManager hook(wheel110)=XRD110_WheelHook
    XRD123_FinishPanel("XRDProjectManager",panelState123)
    return 0
End

Function XRD110_ManagerSelect(row)
    Variable row
    String base=XRD110_TreeBase(0),ui="root:Packages:XRDWorkbench:UI:Manager"
    Wave/T map=$(base+":map"),owners=$(base+":owners"),projects=$(ui+":projectPaths")
    Wave types=$(base+":types")
    if(row<0 || row>=numpnts(map))
        return -1
    endif
    Variable i,j
    for(i=0;i<numpnts(projects);i+=1)
        if(cmpstr(projects[i],owners[row])==0)
            Variable/G $(ui+":projectRow")=i
            XRD80_ManagerSamples()
            if(types[row])
                Wave/T samples=$(ui+":samplePaths")
                for(j=0;j<numpnts(samples);j+=1)
                    if(cmpstr(samples[j],map[row])==0)
                        Variable/G $(ui+":sampleRow")=j
                    endif
                endfor
            endif
            return types[row]
        endif
    endfor
    return -1
End

Function XRD110_ManagerList(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    String base=XRD110_TreeBase(0)
    Wave/T map=$(base+":map")
    Wave types=$(base+":types")
    if(lba.row<0 || lba.row>=numpnts(map) || (lba.eventCode!=4 && lba.eventCode!=3))
        return 0
    endif
    Variable kind=XRD110_ManagerSelect(lba.row)
    if(lba.eventCode==3)
        String/G $(base+":openUID")=SelectString(kind==1,XRD80_ProjectUID(map[lba.row]),XRD80_MeasurementUID(map[lba.row]))
        Variable/G $(base+":openKind")=kind
        Execute/P/Q "XRD110_OpenTreeSelection()"
    elseif(kind==0)
        XRD110_Toggle(0,map[lba.row])
    endif
    return 0
End

Function XRD110_OpenTreeSelection()
    String base=XRD110_TreeBase(0),uid=StrVarOrDefault(base+":openUID",""),path
    Variable kind=NumVarOrDefault(base+":openKind",0)
    if(kind==1)
        path=XRD80_ResolveMeasurement(uid)
        if(!strlen(path))
            return -1
        endif
        String/G root:Packages:XRDWorkbench:activeProject=XRD80_ProjectForMeasurement(path)
        String/G $(XRD_Project()+":activeData")=path
    else
        path=XRD100_ProjectByUID(uid)
        if(!strlen(path))
            return -1
        endif
        String/G root:Packages:XRDWorkbench:activeProject=path
    endif
    return XRD_Open()
End

Function XRD110_ComparePanel()
    XRD_PlotSelectionTable(0)
    String master=XRD110_Master(2),selected=XRD_ComparePaths(),tree=XRD110_TreeBase(2)
    Wave/T paths=$(master+":paths")
    Wave flags=$(master+":flags")
    Variable i
    for(i=0;i<numpnts(paths);i+=1)
        flags[i][0]=32+16*(WhichListItem(paths[i],selected)>=0)
    endfor
    XRD110_TreeBuild(2)
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDCompareSelection")
    DoWindow/K XRDCompareSelection
    NewPanel/FLT=1/N=XRDCompareSelection/K=1/W=(55,55,980,635) as "左の比較図を選択：全プロジェクト"
    DefaultGUIFont all={"Segoe UI",12,0}
    TitleBox help,pos={15,15},frame=0,title="プロジェクト名を押して展開し、比較する試料にチェック。\r他プロジェクトで同定済みの試料も追加できます。チェックした試料だけを表示します。"
    ListBox samples,pos={15,75},size={890,410},mode=1,listWave=$(tree+":table"),selWave=$(tree+":flags"),widths={45,630,195},proc=XRD110_CompareList
    Button apply,pos={15,510},size={890,32},title="選んだ試料を左の比較図に表示",proc=XRD_CompareSelectionButton
    SetWindow XRDCompareSelection hook(wheel110)=XRD110_WheelHook
    XRD123_FinishPanel("XRDCompareSelection",panelState123)
    return 0
End

Function XRD110_CheckTree(kind,row)
    Variable kind,row
    String tree=XRD110_TreeBase(kind),master=XRD110_Master(kind)
    Wave/T map=$(tree+":map"),paths=$(master+":paths")
    Wave flags=$(tree+":flags"),chosen=$(master+":flags"),types=$(tree+":types")
    if(row<0 || row>=numpnts(map))
        return -1
    endif
    if(!types[row])
        XRD110_Toggle(kind,map[row])
        return -2
    endif
    Variable i
    for(i=0;i<numpnts(paths);i+=1)
        if(cmpstr(paths[i],map[row])==0)
            chosen[i][0]=flags[row][0]
            return i
        endif
    endfor
    return -1
End

Function XRD110_CompareList(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if((lba.eventCode==4 && lba.col!=0) || lba.eventCode==13)
        XRD110_CheckTree(2,lba.row)
    endif
    return 0
End

Function XRD110_PlotTrees()
    if(!WinType("XRDPlotWorkspace"))
        return 0
    endif
    String ui=XRD_PlotRoot()+":UI",tree=XRD110_TreeBase(1)
    XRD110_TreeBuild(1)
    Wave/T paths=$(ui+":paths"),labels=$(ui+":labels")
    Wave flags=$(ui+":flags")
    Make/O/T/N=(0,2) $(tree+":orderTable")
    Make/O/D/N=0 $(tree+":orderMap")
    Wave/T table=$(tree+":orderTable")
    Wave map=$(tree+":orderMap")
    Variable i,n=0
    for(i=0;i<numpnts(paths);i+=1)
        if(flags[i][0] & 16)
            Redimension/N=(n+1,2) table
            Redimension/N=(n+1) map
            table[n][0]=StrVarOrDefault(paths[i]+":sampleNumber","番号未登録")+" / "+labels[i];table[n][1]=XRD_ProjectDisplayName(XRD_PlotOwner(paths[i]));map[n]=i;n+=1
        endif
    endfor
    SetDimLabel 1,0,'上からの表示順（ドラッグで変更）',table
    SetDimLabel 1,1,'プロジェクト',table
    ListBox sourceTree,win=XRDPlotWorkspace,pos={15,105},size={445,245},listWave=$(tree+":table"),selWave=$(tree+":flags"),mode=1,widths={35,285,110},proc=XRD110_PlotSourceList
    ListBox samples,win=XRDPlotWorkspace,pos={475,105},size={475,245},listWave=table,mode=1,widths={285,175},proc=XRD110_OrderList
    return 0
End

Function XRD110_PlotSourceList(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode==13 || (lba.eventCode==4 && lba.col!=0))
        Variable index=XRD110_CheckTree(1,lba.row)
        if(index>=0)
            Variable/G $(XRD_PlotRoot()+":UI:row")=index
            XRD110_PlotSelect(index)
        endif
        XRD110_PlotTrees()
        if(lba.eventCode==13)
            XRD81_QueuePlotLive()
        endif
    endif
    return 0
End

Function XRD110_PlotSelect(index)
    Variable index
    String ui=XRD_PlotRoot()+":UI"
    Wave/T labels=$(ui+":labels")
    if(index>=0 && index<numpnts(labels))
        Variable/G $(ui+":row")=index
        String/G $(ui+":draftLabel")=labels[index]
        Wave styles=$(ui+":lineStyle")
        Variable/G $(ui+":lineWidth")=styles[index][0]
        PopupMenu color,win=XRDPlotWorkspace,popColor=(styles[index][1],styles[index][2],styles[index][3])
    endif
End

Function XRD110_OrderList(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    String base=XRD110_TreeBase(1)
    Wave map=$(base+":orderMap")
    if(lba.row<0 || lba.row>=numpnts(map))
        return 0
    endif
    if(lba.eventCode==1)
        Variable/G $(base+":dragFrom")=map[lba.row]
    elseif(lba.eventCode==4)
        Variable from=NumVarOrDefault(base+":dragFrom",-1),target=map[lba.row]
        XRD110_PlotSelect(target)
        if(from>=0 && from!=target)
            XRD81_MovePlotRow(from,target)
            Variable/G $(base+":dragFrom")=target
        endif
    elseif(lba.eventCode==2 || lba.eventCode==-2)
        Variable/G $(base+":dragFrom")=-1
        XRD110_PlotTrees()
        XRD81_QueuePlotLive()
    endif
    return 0
End
