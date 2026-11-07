#pragma rtGlobals=3

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
