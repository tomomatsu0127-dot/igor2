#pragma rtGlobals=3
// XRD Workbench v1.2.0: project/sample navigator and independent plotting entry.
Function XRD80_ShowProjectManager()
    return XRD110_Manager()
    XRD_Init()
    NewDataFolder/O root:Packages:XRDWorkbench:UI:Manager
    String ui="root:Packages:XRDWorkbench:UI:Manager",list=XRD_ProjectList(),project
    Variable i,n=ItemsInList(list),selected=0
    Make/O/T/N=(n,2) $(ui+":projects")
    Make/O/T/N=(n) $(ui+":projectPaths")
    Wave/T projects=$(ui+":projects"),paths=$(ui+":projectPaths")
    for(i=0;i<n;i+=1)
        project=XRD100_ProjectAt(list,i)
        paths[i]=project
        projects[i][0]=XRD_ProjectDisplayName(project)
        projects[i][1]=XRD80_ProjectProgress(project)
        if(cmpstr(project,XRD_Project())==0)
            selected=i
        endif
    endfor
    Variable/G $(ui+":projectRow")=selected
    Variable/G $(ui+":sampleRow")=-1
    SetDimLabel 1,0,'プロジェクト',projects
    SetDimLabel 1,1,'進捗',projects
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDProjectManager")
    DoWindow/K XRDProjectManager
    NewPanel/FLT=1/K=1/N=XRDProjectManager/W=(35,35,1015,620) as "プロジェクトと測定データ"
    ModifyPanel/W=XRDProjectManager fixedSize=0
    DefaultGUIFont/W=XRDProjectManager all={"Segoe UI",12,0}
    TitleBox help,pos={15,15},frame=0,title="左でプロジェクト、右で測定データを選択します。右の試料をダブルクリックすると解析を開きます。"
    ListBox projects,pos={15,55},size={330,390},listWave=projects,mode=1,widths={245,75},selRow=selected,proc=XRD80_ManagerList
    Make/O/T/N=(0,3) $(ui+":samples")
    ListBox samples,pos={365,55},size={590,390},listWave=$(ui+":samples"),mode=1,widths={300,130,140},proc=XRD80_ManagerList
    Button openProject,pos={15,465},size={155,30},title="選択プロジェクトを開く",proc=XRD80_ManagerButton
    Button addProject,pos={185,465},size={160,30},title="新しいプロジェクト",proc=XRD80_ManagerButton
    Button openSample,pos={365,465},size={280,30},title="選択した測定データを開く",proc=XRD80_ManagerButton
    Button renameSample,pos={665,465},size={285,30},title="選択した測定データ名を変更",proc=XRD80_ManagerButton
    Button renameProject,pos={15,510},size={330,30},title="選択プロジェクト名を変更",proc=XRD80_ManagerButton
    Button figures,pos={365,510},size={590,30},title="全プロジェクトから完了試料を選んで作図",proc=XRD80_ManagerButton
    TitleBox policy,pos={15,550},frame=0,title="解析完了：登録ピークが1本以上あり、全ピークに相またはUnknownが設定済み。格子定数は任意です。"
    XRD80_ManagerSamples()
    XRD100_ManagerControls()
    XRD123_FinishPanel("XRDProjectManager",panelState123)
    return 0
End

Function XRD80_ManagerSamples()
    String ui="root:Packages:XRDWorkbench:UI:Manager",project,list,path
    Wave/T paths=$(ui+":projectPaths"),samples=$(ui+":samples")
    Variable row=NumVarOrDefault(ui+":projectRow",0),i
    if(row<0 || row>=numpnts(paths))
        return -1
    endif
    project=paths[row];list=XRD_MeasurementOrderList(project)
    Make/O/T/N=(ItemsInList(list)) $(ui+":samplePaths")
    Wave/T samplePaths=$(ui+":samplePaths")
    Redimension/N=(ItemsInList(list),3) samples
    for(i=0;i<numpnts(samplePaths);i+=1)
        path=project+":Measurements:"+StringFromList(i,list)
        samplePaths[i]=path
        XRD_UpdateAnalysisState(path)
        samples[i][0]=XRD110_SampleLabel(path)
        samples[i][1]=StrVarOrDefault(path+":analysisState","未解析")
        samples[i][2]=num2istr(NumVarOrDefault(path+":reviewedPeakCount",0))+" / "+num2istr(NumVarOrDefault(path+":registeredPeakCount",0))+" 対応済"
    endfor
    Variable/G $(ui+":sampleRow")=-1
    SetDimLabel 1,0,'測定データ',samples
    SetDimLabel 1,1,'解析状態',samples
    SetDimLabel 1,2,'ピーク',samples
    return 0
End

Function XRD80_ManagerList(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.row<0 || (lba.eventCode!=3 && lba.eventCode!=4))
        return 0
    endif
    String ui="root:Packages:XRDWorkbench:UI:Manager"
    if(cmpstr(lba.ctrlName,"projects")==0)
        Variable/G $(ui+":projectRow")=lba.row
        XRD80_ManagerSamples()
    else
        Variable/G $(ui+":sampleRow")=lba.row
        if(lba.eventCode==3)
            Execute/P/Q "XRD80_OpenManagerSelection(1)"
        endif
    endif
    return 0
End

Function XRD80_OpenManagerSelection(withSample)
    Variable withSample
    String ui="root:Packages:XRDWorkbench:UI:Manager"
    Wave/T projects=$(ui+":projectPaths"),samples=$(ui+":samplePaths")
    Variable row=NumVarOrDefault(ui+":projectRow",0),sample=NumVarOrDefault(ui+":sampleRow",-1)
    if(row<0 || row>=numpnts(projects) || (withSample && (sample<0 || sample>=numpnts(samples))))
        return -1
    endif
    String shownProject=GetUserData("XRDWorkbench","","XRDProject"),shownData=GetUserData("XRDWorkbench","","XRDData")
    if(WinType("XRDWorkbench")==7 && cmpstr(shownProject,projects[row])==0)
        if(!withSample || cmpstr(shownData,samples[sample])==0)
            DoWindow/F XRDWorkbench
            return 0
        endif
    endif
    XRD_CaptureView()
    SVAR active=root:Packages:XRDWorkbench:activeProject
    active=projects[row]
    if(withSample)
        String/G $(active+":activeData")=samples[sample]
    endif
    XRD_CloseEditors()
    XRD_UpgradeProject(active)
    XRD_Panel()
    return 0
End

Function XRD80_ManagerButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    strswitch(ba.ctrlName)
        case "openProject":
            XRD80_OpenManagerSelection(0)
            break
        case "openSample":
            XRD80_OpenManagerSelection(1)
            break
        case "addProject":
            XRD_NewProjectUI()
            XRD80_ShowProjectManager()
            break
        case "renameProject":
            XRD100_QueueManager("renameProject")
            break
        case "renameSample":
            if(XRD80_OpenManagerSelection(1)==0)
                XRD80_RenameMeasurementUI()
                XRD80_ShowProjectManager()
            endif
            break
        case "figures":
            XRD_PlotWorkspace()
            break
    endswitch
    return 0
End

Function XRD80_WorkspaceButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    strswitch(ba.ctrlName)
        case "plotWorkspace":
            XRD_PlotWorkspace()
            break
        case "latticeSummary":
            XRD80_ProjectLatticeSummary()
            break
        case "projectManager":
            XRD80_ProjectManager()
            break
    endswitch
    return 0
End
