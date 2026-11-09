#pragma rtGlobals=3

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
