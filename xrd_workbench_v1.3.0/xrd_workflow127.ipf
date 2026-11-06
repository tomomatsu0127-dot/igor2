#pragma rtGlobals=3
// v1.2.7: serial-sorted choosers, stable project order, plain text creation,
// new-measurement defaults and navigation of unexplained measured peaks.
Function/S XRD127_Settings()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:XRDWorkbench
    NewDataFolder/O root:Packages:XRDWorkbench:Preferences127
    String base="root:Packages:XRDWorkbench:Preferences127"
    XRD_EnsureNumeric(base+":prominence",5)
    return base
End

Function XRD127_DefaultProminence()
    Variable value=NumVarOrDefault("root:Packages:XRDWorkbench:Preferences127:prominence",5)
    if(numtype(value)!=0 || value<0 || value>100)
        return 5
    endif
    return value
End

Function/S XRD127_SerialKey(number,index)
    String number
    Variable index
    String prefix
    if(!GrepString(number,"^[0-9]+$"))
        sprintf prefix,"1_%010d",index
        return prefix
    endif
    String original=number
    do
        if(strlen(number)<=1 || cmpstr(number[0],"0")!=0)
            break
        endif
        number=number[1,inf]
    while(1)
    sprintf prefix,"0_%03d_",strlen(number)
    return prefix+number+"_"+original
End

Function/S XRD127_MeasurementList(project)
    String project
    String list=XRD_MeasurementOrderList(project),path,out=""
    Variable n=ItemsInList(list),i
    Make/FREE/T/N=(n) keys,names
    for(i=0;i<n;i+=1)
        names[i]=StringFromList(i,list)
        path=project+":Measurements:"+names[i]
        keys[i]=XRD127_SerialKey(StrVarOrDefault(path+":sampleNumber",""),i)
    endfor
    if(n>1)
        Sort keys,keys,names
    endif
    for(i=0;i<n;i+=1)
        out+=names[i]+";"
    endfor
    return out
End

Function/S XRD127_OrderedProjects(list)
    String list
    Wave/T/Z uids=root:Packages:XRDWorkbench:Preferences127:projectUIDs
    if(!WaveExists(uids))
        return list
    endif
    String out="",path
    Variable i,j
    for(i=0;i<numpnts(uids);i+=1)
        for(j=0;j<ItemsInList(list);j+=1)
            path=StringFromList(j,list)
            if(cmpstr(StrVarOrDefault(path+":projectUID",""),uids[i])==0 && WhichListItem(path,out)<0)
                out+=path+";"
            endif
        endfor
    endfor
    for(j=0;j<ItemsInList(list);j+=1)
        path=StringFromList(j,list)
        if(WhichListItem(path,out)<0)
            out+=path+";"
        endif
    endfor
    return out
End

Function XRD127_MoveProject(project,direction)
    String project
    Variable direction
    String list=XRD_ProjectList(),base=XRD127_Settings(),tmp
    Variable row=WhichListItem(project,list),other=row+direction,i,n=ItemsInList(list)
    if((direction!=-1 && direction!=1) || row<0 || other<0 || other>=n)
        return -1
    endif
    Make/FREE/T/N=(n) order
    for(i=0;i<n;i+=1)
        order[i]=StrVarOrDefault(StringFromList(i,list)+":projectUID","")
        if(!strlen(order[i]))
            return -2
        endif
    endfor
    tmp=order[row];order[row]=order[other];order[other]=tmp
    Duplicate/O order,$(base+":projectUIDs")
    return other
End

Function XRD127_ManagerControls()
    ListBox projects,win=XRDProjectManager,size={935,350}
    Button projectUp127,win=XRDProjectManager,pos={15,420},size={300,28},title="選択プロジェクトを上へ",proc=XRD127_ProjectOrderButton
    Button projectDown127,win=XRDProjectManager,pos={335,420},size={300,28},title="選択プロジェクトを下へ",proc=XRD127_ProjectOrderButton
    TitleBox orderHelp127,win=XRDProjectManager,pos={655,426},frame=0,title="測定データは通し番号順"
End

Function XRD127_ProjectOrderButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String base="root:Packages:XRDWorkbench:UI:Manager",project=XRD100_ManagerProject()
    String/G $(base+":reorderUID127")=StrVarOrDefault(project+":projectUID","")
    Variable/G $(base+":direction127")=SelectNumber(cmpstr(ba.ctrlName,"projectUp127")==0,1,-1)
    Execute/P/Q "XRD127_ProjectOrderDeferred()"
    return 0
End

Function XRD127_ProjectOrderDeferred()
    String base="root:Packages:XRDWorkbench:UI:Manager",project=XRD100_ProjectByUID(StrVarOrDefault(base+":reorderUID127",""))
    if(!strlen(project) || !WinType("XRDProjectManager"))
        return -1
    endif
    if(XRD127_MoveProject(project,NumVarOrDefault(base+":direction127",0))<0)
        return 0
    endif
    XRD110_Manager()
    String tree=XRD110_TreeBase(0)
    Wave/T owners=$(tree+":owners")
    Wave types=$(tree+":types")
    Variable i
    for(i=0;i<numpnts(owners);i+=1)
        if(!types[i] && cmpstr(owners[i],project)==0)
            XRD110_ManagerSelect(i)
            ListBox projects,win=XRDProjectManager,selRow=i,row=max(0,i-2)
            break
        endif
    endfor
    return 0
End

Function XRD127_DefaultsPanel()
    String prefs=XRD127_Settings(),base="root:Packages:XRDWorkbench:UI:Defaults127"
    XRD_UISettings()
    NewDataFolder/O $base
    Variable/G $(base+":prominence")=XRD127_DefaultProminence()
    KillWindow/Z XRDDefaults127
    NewPanel/FLT=1/FLTH=1/K=1/N=XRDDefaults127/W=(70,70,700,330) as "新しく追加する測定のピーク検出初期値"
    ModifyPanel/W=XRDDefaults127 fixedSize=0
    DefaultGUIFont all={"Segoe UI",12,0}
    TitleBox help,pos={18,18},frame=0,title="これから追加する測定に使います。既存の測定条件・同定は変更しません。"
    GroupBox detector,pos={18,55},size={590,90},title="背景・ノイズ・突出量方式"
    SetVariable prominence,pos={35,90},size={550,25},title="最小突出量 (%)",limits={0,100,0.5},value=$(base+":prominence")
    Button reset,pos={18,163},size={180,28},title="5%に戻す",proc=XRD127_DefaultsButton
    Button save,pos={213,163},size={235,28},title="初期値を保存",proc=XRD127_DefaultsButton
    Button cancel,pos={463,163},size={145,28},title="キャンセル",proc=XRD127_DefaultsButton
    TitleBox result,pos={18,213},frame=0,title="Experimentを保存すると、初期値も一緒に保存されます。"
    XRD123_FinishPanel("XRDDefaults127","")
    return 0
End

Function XRD127_SaveDefault(value)
    Variable value
    if(numtype(value)!=0 || value<0 || value>100)
        return -1
    endif
    Variable/G $(XRD127_Settings()+":prominence")=value
    return 0
End

Function XRD127_DefaultsButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String base="root:Packages:XRDWorkbench:UI:Defaults127"
    if(cmpstr(ba.ctrlName,"reset")==0)
        Variable/G $(base+":prominence")=5
        ControlUpdate/W=XRDDefaults127 prominence
        return 0
    elseif(cmpstr(ba.ctrlName,"save")==0)
        if(XRD127_SaveDefault(NumVarOrDefault(base+":prominence",NaN))<0)
            TitleBox result,win=XRDDefaults127,title="0〜100%の数値を入力してください。"
            return -1
        endif
    endif
    KillWindow/Z XRDDefaults127
    return 0
End

Function XRD127_OpenDefaultsButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode==2)
        Execute/P/Q "XRD127_DefaultsPanel()"
    endif
    return 0
End

Function XRD127_NewProjectPanel()
    XRD_UISettings()
    String base="root:Packages:XRDWorkbench:UI:NewProject127"
    NewDataFolder/O $base
    if(WinType("XRDNewProject127"))
        DoWindow/F XRDNewProject127
        return 0
    endif
    String/G $(base+":name")=""
    Variable/G $(base+":manager")=WinType("XRDProjectManager")!=0
    NewPanel/FLT=1/FLTH=1/K=1/N=XRDNewProject127/W=(75,75,715,335) as "プロジェクトを追加"
    ModifyPanel/W=XRDNewProject127 fixedSize=0
    DefaultGUIFont all={"Segoe UI",12,0}
    TitleBox help,pos={18,18},frame=0,title="プロジェクト名を入力してください。引用符は不要です。"
    SetVariable name,pos={18,65},size={595,25},title="プロジェクト名",value=$(base+":name")
    TitleBox result,pos={18,112},size={595,45},fixedSize=1,frame=0,title="同名のプロジェクトは上書きしません。"
    Button create,pos={18,180},size={390,30},title="この名前でプロジェクトを作成",proc=XRD127_NewProjectButton
    Button cancel,pos={428,180},size={185,30},title="キャンセル",proc=XRD127_NewProjectButton
    XRD123_FinishPanel("XRDNewProject127","")
    SetVariable name,win=XRDNewProject127,activate
    return 0
End

Function XRD127_NewProjectButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(cmpstr(ba.ctrlName,"cancel")==0)
        KillWindow/Z XRDNewProject127
    else
        Execute/P/Q "XRD127_CreateProjectDeferred()"
    endif
    return 0
End

Function XRD127_CreateProjectDeferred()
    if(!WinType("XRDNewProject127"))
        return -1
    endif
    String base="root:Packages:XRDWorkbench:UI:NewProject127",label=TrimString(StrVarOrDefault(base+":name",""))
    if(XRD127_CreateProject(label)<0)
        TitleBox result,win=XRDNewProject127,title="同名のプロジェクト、使えない文字、名前の長さを確認してください。"
        return -1
    endif
    Variable manager=NumVarOrDefault(base+":manager",0)
    KillWindow/Z XRDNewProject127
    XRD_Panel()
    if(manager)
        XRD110_Manager()
    endif
    return 0
End

Function XRD127_CreateProject(label)
    String label
    label=TrimString(label)
    if(!strlen(label))
        return -1
    endif
    Variable hadProject=strlen(StrVarOrDefault("root:Packages:XRDWorkbench:activeProject",""))>0
    XRD_Init()
    String owner=SelectString(hadProject,XRD_Project(),"")
    if(XRD100_ValidProjectName(owner,label)<0)
        return -1
    endif
    if(hadProject || !strlen(XRD_Project()))
        XRD_NewProject()
    endif
    String created=XRD_Project(),destination=XRD100_Management()+":"+PossiblyQuoteName(label)
    if(cmpstr(created,destination,1)!=0)
        RenameDataFolder $created,$label
    endif
    String/G root:Packages:XRDWorkbench:activeProject=destination
    String/G $(destination+":displayName")=label
    XRD100_RefreshRegistry(destination)
    return 0
End

Function XRD127_FindUnknown(path,direction)
    String path
    Variable direction
    if(!strlen(path) || (direction!=-1 && direction!=1))
        return -1
    endif
    Wave ids=$(path+":Peaks:peakID"),aid=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex")
    Variable n=numpnts(ids),current=NumVarOrDefault(path+":selectedPeakRow",-1),i,j,row,assigned
    if(!n)
        return -1
    endif
    if(current<0 || current>=n)
        current=SelectNumber(direction==1,0,-1)
    endif
    for(i=1;i<=n;i+=1)
        row=mod(current+direction*i+n,n);assigned=0
        for(j=0;j<numpnts(aid);j+=1)
            if(aid[j]==ids[row] && refs[j]>0)
                assigned=1
                break
            endif
        endfor
        if(!assigned)
            return row
        endif
    endfor
    return -1
End

Function XRD127_GotoUnknown(direction)
    Variable direction
    String path=XRD_Data()
    Variable row=XRD127_FindUnknown(path,direction)
    if(row<0)
        XRD124_Alert(0,"未同定ピークはありません。")
        return -1
    endif
    XRD100_Select(path,row,1)
    XRD_RequestLive()
    return row
End
