#pragma rtGlobals=3
// XRD Workbench v1.2.0: Experiment-wide comparison and independent figure recipes.
// All source paths below are Igor data folders, never external file paths.
Function/S XRD_PlotRoot()
    String base="root:Packages:XRDWorkbench:PlotWorkspace"
    NewDataFolder/O $base
    NewDataFolder/O $(base+":Plots")
    NewDataFolder/O $(base+":UI")
    NewDataFolder/O $(base+":CompareUI")
    XRD_EnsureNumeric(base+":serial",0)
    return base
End

Function/S XRD_PlotOwner(path)
    String path
    Variable at=strsearch(path,":Measurements:",0)
    if(at<0)
        return ""
    endif
    return path[0,at-1]
End

Function/S XRD_AllMeasurementPaths(completedOnly)
    Variable completedOnly
    String projects=XRD_ProjectList(),project,names,path,out=""
    Variable i,j
    for(i=0;i<ItemsInList(projects);i+=1)
        project=XRD100_ProjectAt(projects,i)
        names=XRD_MeasurementOrderList(project)
        for(j=0;j<ItemsInList(names);j+=1)
            path=project+":Measurements:"+StringFromList(j,names)
            XRD_EnsureIdentity(project,path)
            if(!completedOnly || XRD_IsAnalysisComplete(path))
                out+=path+";"
            endif
        endfor
    endfor
    return out
End

Function/S XRD_ComparePaths()
    return XRD120_ComparePaths()
End

Function/S XRD_ComparisonPhases(path)
    String path
    Wave/Z refs=$(path+":Assignments:refIndex")
    String out="",label
    Variable i
    if(WaveExists(refs))
        for(i=0;i<numpnts(refs);i+=1)
            if(refs[i]>0)
                label=XRD_PhaseLabel(refs[i])
                if(WhichListItem(label,out)<0)
                    out+=label+";"
                endif
            endif
        endfor
    endif
    if(!strlen(out))
        return "同定相：未同定"
    endif
    return "同定相："+ReplaceString(";",RemoveEnding(out,";")," / ")
End

Function XRD_CompareSelection()
    return XRD110_ComparePanel()
    XRD_PlotSelectionTable(0)
    String base=XRD_PlotRoot()+":CompareUI",selected=XRD_ComparePaths()
    Wave/T paths=$(base+":paths"),table=$(base+":table")
    Wave flags=$(base+":flags")
    Variable i
    for(i=0;i<numpnts(paths);i+=1)
        flags[i][0]=32+16*(WhichListItem(paths[i],selected)>=0)
    endfor
    DoWindow/K XRDCompareSelection
    NewPanel/K=1/N=XRDCompareSelection/W=(55,55,835,555) as "同定中に見比べる試料（全プロジェクト）"
    DefaultGUIFont/W=XRDCompareSelection all={"Segoe UI",12,0}
    TitleBox help,pos={15,15},frame=0,title="解析中・未解析の試料も比較できます。編集中の試料は必ず表示します。\rプロジェクト名・試料名・同定相をグラフに表示します。"
    ListBox samples,pos={15,70},size={745,350},listWave=$(base+":table"),selWave=$(base+":flags"),mode=1,widths={45,210,300,145}
    Button apply,pos={15,440},size={745,32},title="選んだ試料をライブ比較に表示",proc=XRD_CompareSelectionButton
    return 0
End

Function XRD_CompareSelectionButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String base=XRD_PlotRoot(),ui=base+":CompareUI"
    Wave/T paths=$(ui+":paths")
    Wave flags=$(ui+":flags")
    Make/O/T/N=0 $(XRD120_CompareSettings()+":uids")
    Wave/T selected=$(XRD120_CompareSettings()+":uids")
    Variable i,n=0
    for(i=0;i<numpnts(paths);i+=1)
        if(flags[i][0] & 16)
            Redimension/N=(n+1) selected
            selected[n]=XRD80_MeasurementUID(paths[i]);n+=1
        endif
    endfor
    DoWindow/K XRDCompareSelection
    XRD_RequestLive()
    if(WinType("XRDWorkbench"))
        Execute/P/Q "XRD_UpdateSideCompare()"
    endif
    return 0
End

Function XRD_PlotSelectionTable(completedOnly)
    Variable completedOnly
    String base=XRD_PlotRoot()+SelectString(completedOnly,":CompareUI",":UI"),list=XRD_AllMeasurementPaths(completedOnly),path,owner
    Variable i,n=ItemsInList(list)
    Make/O/T/N=(n) $(base+":paths"),$(base+":labels")
    Make/O/T/N=(n,4) $(base+":table")
    Make/O/B/U/N=(n,4) $(base+":flags")=0
    Make/O/D/N=(n,4) $(base+":lineStyle")=0
    Wave/T paths=$(base+":paths"),labels=$(base+":labels"),table=$(base+":table")
    Wave flags=$(base+":flags"),styles=$(base+":lineStyle")
    for(i=0;i<n;i+=1)
        path=StringFromList(i,list);owner=XRD_PlotOwner(path)
        paths[i]=path;labels[i]=StrVarOrDefault(path+":conditionLabel",StrVarOrDefault(path+":displayName",""))
        table[i][0]="";table[i][1]=XRD_ProjectDisplayName(owner)
        table[i][2]=StrVarOrDefault(path+":displayName","")
        XRD_UpdateAnalysisState(path)
        table[i][3]=StrVarOrDefault(path+":analysisState","未解析")
        flags[i][0]=32;styles[i][0]=1
    endfor
    SetDimLabel 1,0,'使用',table
    SetDimLabel 1,1,'プロジェクト',table
    SetDimLabel 1,2,'試料',table
    SetDimLabel 1,3,'解析状態',table
    XRD_EnsureNumeric(base+":row",-1)
    return n
End

Function/S XRD_PlotChoices()
    String base=XRD_PlotRoot()+":Plots",name,out="新しい図;"
    Variable i=0
    do
        name=GetIndexedObjName(base,4,i)
        if(!strlen(name))
            break
        endif
        out+=name+" | "+StrVarOrDefault(base+":"+name+":displayName",name)+";"
        i+=1
    while(1)
    return out
End

Function XRD_PlotWorkspace()
    XRD_Init()
    XRD_PlotDefaults()
    String base=XRD_PlotRoot()+":UI"
    Variable/G $(base+":livePending81")=0
    if(WinType("XRDPlotWorkspace"))
        DoWindow/F XRDPlotWorkspace
        return 0
    endif
    XRD_PlotSelectionTable(1)
    String/G $(base+":recipe")=""
    String/G $(base+":title")="XRD 比較図"
    String/G $(base+":draftLabel")=""
    XRD_EnsureNumeric(base+":spacing",135)
    XRD_EnsureNumeric(base+":offsetMode",1)
    XRD_EnsureNumeric(base+":width",340.157)
    XRD_EnsureNumeric(base+":height",360)
    XRD_EnsureNumeric(base+":font",24)
    XRD_EnsureNumeric(base+":legendFont",24)
    XRD_EnsureNumeric(base+":xMin",20)
    XRD_EnsureNumeric(base+":xMax",70)
    XRD_EnsureNumeric(base+":yMin",-30)
    XRD_EnsureNumeric(base+":lineWidth",1)
    XRD_EnsureNumeric(base+":red",0)
    XRD_EnsureNumeric(base+":green",0)
    XRD_EnsureNumeric(base+":blue",0)
    NewPanel/K=1/N=XRDPlotWorkspace/W=(35,35,1005,760) as "作図：全プロジェクトの解析完了試料"
    SetWindow XRDPlotWorkspace hook(XRDPlotUI)=XRD81_PlotWorkspaceHook
    DefaultGUIFont/W=XRDPlotWorkspace all={"Segoe UI",12,0},popup={"Segoe UI",12,0}
    PopupMenu saved,pos={15,15},title="保存した図",value=XRD_PlotChoices(),proc=XRD_PlotChoice
    Button refresh,pos={745,12},size={205,28},title="完了試料の一覧を更新",proc=XRD_PlotButton
    TitleBox help,pos={15,48},frame=0,title="試料を選択 → 行をドラッグして順番を調整 → 図を作成。先頭が最上段です。"
    Button sources,pos={15,74},size={360,23},title="プロジェクトフォルダから試料を選ぶ",proc=XRD81_PlotButton
    Button markerSettings,pos={390,74},size={280,23},title="相のマーカー・色・サイズ",proc=XRD81_PlotButton
    Button legendSettings,pos={685,74},size={265,23},title="凡例の順番",proc=XRD81_PlotButton
    ListBox samples,pos={15,105},size={935,245},listWave=$(base+":table"),selWave=$(base+":flags"),mode=1,widths={45,250,455,145},proc=XRD_PlotSample
    Button up,pos={15,355},size={100,27},title="選択行を上へ",proc=XRD_PlotButton
    Button down,pos={125,355},size={100,27},title="選択行を下へ",proc=XRD_PlotButton
    SetVariable draftLabel,pos={245,359},size={430,24},title="図中の表示名",value=$(base+":draftLabel"),proc=XRD81_PlotSetting
    SetVariable lineWidth,pos={695,359},size={120,24},title="線幅",limits={0.1,10,0.1},value=$(base+":lineWidth"),proc=XRD81_PlotSetting
    PopupMenu color,pos={835,357},title="色",value="*COLORPOP*",proc=XRD81_PlotColor
    Button lineApply,pos={15,392},size={935,26},title="選択行に図中の表示名・線幅・色を適用",proc=XRD_PlotButton
    SetVariable title,pos={15,440},size={935,24},title="図の名前",value=$(base+":title"),proc=XRD81_PlotSetting
    CheckBox offset,pos={15,480},title="縦に並べる（OFFは重ね描き）",variable=$(base+":offsetMode"),proc=XRD81_PlotOffset
    SetVariable spacing,pos={370,479},size={250,24},title="上下の間隔",limits={120,1000,5},value=$(base+":spacing"),proc=XRD81_PlotSetting
    Button details,pos={710,478},size={240,27},title="軸・文字・サイズを設定 ▼",proc=XRD_PlotButton
    SetVariable xMin,pos={15,520},size={210,24},title="2θ 下限 (deg)",value=$(base+":xMin"),proc=XRD81_PlotSetting
    SetVariable xMax,pos={245,520},size={210,24},title="2θ 上限 (deg)",value=$(base+":xMax"),proc=XRD81_PlotSetting
    SetVariable yMin,pos={480,520},size={210,24},title="強度 下限",value=$(base+":yMin"),proc=XRD81_PlotSetting
    SetVariable width,pos={15,560},size={210,24},title="幅 (pt)",limits={200,1600,10},value=$(base+":width"),proc=XRD81_PlotSetting
    SetVariable height,pos={245,560},size={210,24},title="高さ (pt)",limits={150,3000,10},value=$(base+":height"),proc=XRD81_PlotSetting
    SetVariable font,pos={480,560},size={210,24},title="軸文字 (pt)",limits={12,48,1},value=$(base+":font"),proc=XRD81_PlotSetting
    SetVariable legendFont,pos={710,560},size={240,24},title="凡例文字 (pt)",limits={12,48,1},value=$(base+":legendFont"),proc=XRD81_PlotSetting
    Button create,pos={15,610},size={295,34},title="選んだ試料から新しい図を作成",proc=XRD_PlotButton
    Button update,pos={325,610},size={300,34},title="設定で保存図を再作成（確認あり）",proc=XRD_PlotButton
    Button open,pos={640,610},size={310,34},title="保存した図を開く",proc=XRD_PlotButton
    Button saveNative,pos={15,660},size={455,30},title="Igorで編集した現在の書式を保存",proc=XRD_PlotButton
    Button figureSettings,pos={485,660},size={465,30},title="完成図のサイズ・凡例を調整",proc=XRD_PlotButton
    XRD110_PlotControls()
    XRD_PlotDetailControls()
    return 0
End

Function XRD_PlotDefaults()
    String ui=XRD_PlotRoot()+":UI",keys="spacing;offsetMode;width;height;font;legendFont;xMin;xMax;yMin;legendColumns;legendSeparate;lineWidth;row",values="135;1;340.157;360;24;24;20;70;-30;2;0;1;-1"
    Variable i
    for(i=0;i<ItemsInList(keys);i+=1)
        XRD_EnsureNumeric(ui+":"+StringFromList(i,keys),str2num(StringFromList(i,values)))
    endfor
    SVAR/Z title=$(ui+":title")
    if(!SVAR_Exists(title))
        String/G $(ui+":title")="XRD 比較図"
    endif
    return 0
End

Function XRD_PlotQuickCreate(list,title)
    String list,title
    XRD_PlotDefaults()
    XRD_PlotSelectionTable(1)
    String ui=XRD_PlotRoot()+":UI",recipe
    Wave/T paths=$(ui+":paths")
    Wave flags=$(ui+":flags")
    Variable i,n=0
    for(i=0;i<numpnts(paths);i+=1)
        if(WhichListItem(paths[i],list)>=0)
            flags[i][0]=48;n+=1
        endif
    endfor
    if(!n)
        DoAlert 0,"解析完了の試料がありません。登録ピークをすべて同定またはUnknownにしてください。"
        return -1
    endif
    String/G $(ui+":title")=title
    Variable/G $(ui+":height")=max(255.118,n*110)
    recipe=XRD_PlotSaveDraft("")
    if(!strlen(recipe))
        return -1
    endif
    return XRD_PlotDrawRecipe(recipe,0)
End

Function XRD_PlotSample(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    XRD81_PlotDrag(lba)
    if(lba.eventCode!=3 && lba.eventCode!=4)
        if(lba.eventCode==13)
            XRD81_QueuePlotLive()
        endif
        return 0
    endif
    String base=XRD_PlotRoot()+":UI"
    Wave/T labels=$(base+":labels")
    Wave style=$(base+":lineStyle")
    if(lba.row<0 || lba.row>=numpnts(labels))
        return 0
    endif
    Variable/G $(base+":row")=lba.row
    String/G $(base+":draftLabel")=labels[lba.row]
    Variable/G $(base+":lineWidth")=style[lba.row][0]
    PopupMenu color,win=XRDPlotWorkspace,popColor=(style[lba.row][1],style[lba.row][2],style[lba.row][3])
    return 0
End

Function XRD_PlotChoice(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2)
        return 0
    endif
    String base=XRD_PlotRoot(),ui=base+":UI",name=pa.popStr
    if(pa.popNum==1)
        String/G $(ui+":recipe")=""
        return 0
    endif
    Variable separator=strsearch(name," | ",0)
    if(separator>=0)
        name=name[0,separator-1]
    endif
    return XRD_PlotLoadRecipe(base+":Plots:"+name)
End

Function XRD_PlotMoveRow(direction)
    Variable direction
    String ui=XRD_PlotRoot()+":UI"
    Wave/T paths=$(ui+":paths"),labels=$(ui+":labels"),table=$(ui+":table")
    Wave flags=$(ui+":flags"),style=$(ui+":lineStyle")
    NVAR row=$(ui+":row")
    Variable next=row+direction,j,temp
    String text
    if(row<0 || next<0 || next>=numpnts(paths))
        return 0
    endif
    text=paths[row];paths[row]=paths[next];paths[next]=text
    text=labels[row];labels[row]=labels[next];labels[next]=text
    for(j=0;j<4;j+=1)
        text=table[row][j];table[row][j]=table[next][j];table[next][j]=text
        temp=flags[row][j];flags[row][j]=flags[next][j];flags[next][j]=temp
        temp=style[row][j];style[row][j]=style[next][j];style[next][j]=temp
    endfor
    row=next
    XRD110_PlotTrees()
    ListBox samples,win=XRDPlotWorkspace,selRow=next
    return 1
End

Function XRD_PlotButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String base=XRD_PlotRoot(),ui=base+":UI",recipe=StrVarOrDefault(ui+":recipe","")
    Variable row=NumVarOrDefault(ui+":row",-1)
    strswitch(ba.ctrlName)
        case "details":
            Variable/G $(ui+":showDetails")=1-NumVarOrDefault(ui+":showDetails",0)
            XRD_PlotDetailControls()
            break
        case "refresh":
            if(strlen(recipe))
                XRD_PlotLoadRecipe(recipe)
            else
                XRD_PlotSelectionTable(1)
            endif
            break
        case "up":
            XRD_PlotMoveRow(-1)
            break
        case "down":
            XRD_PlotMoveRow(1)
            break
        case "lineApply":
            Wave/T labels=$(ui+":labels")
            Wave style=$(ui+":lineStyle")
            if(row>=0 && row<numpnts(labels))
                labels[row]=StrVarOrDefault(ui+":draftLabel","")
                style[row][0]=NumVarOrDefault(ui+":lineWidth",1)
                ControlInfo/W=XRDPlotWorkspace color
                style[row][1]=V_red;style[row][2]=V_green;style[row][3]=V_blue
            endif
            break
        case "create":
            recipe=XRD_PlotSaveDraft("")
            if(strlen(recipe))
                XRD_PlotDrawRecipe(recipe,0)
            endif
            break
        case "update":
            if(strlen(recipe))
                DoAlert 1,"新しい設定と現在の解析結果から再作成します。Igorで直接編集した書式は置き換わります。続けますか？"
                if(V_flag==1)
                    recipe=XRD_PlotSaveDraft(recipe)
                    if(strlen(recipe))
                        XRD_PlotDrawRecipe(recipe,0)
                    endif
                endif
            endif
            break
        case "open":
            if(strlen(recipe))
                XRD_PlotDrawRecipe(recipe,1)
            endif
            break
        case "saveNative":
            if(strlen(recipe))
                XRD_PlotCaptureNative(recipe)
            endif
            break
        case "figureSettings":
            XRD_FigurePanel()
            break
    endswitch
    if(cmpstr(ba.ctrlName,"up")==0 || cmpstr(ba.ctrlName,"down")==0 || cmpstr(ba.ctrlName,"lineApply")==0)
        XRD81_QueuePlotLive()
    endif
    return 0
End

Function XRD_PlotDetailControls()
    String ui=XRD_PlotRoot()+":UI",controls="xMin;xMax;yMin;width;height;font;legendFont",control
    Variable i,shown=NumVarOrDefault(ui+":showDetails",0)
    for(i=0;i<ItemsInList(controls);i+=1)
        control=StringFromList(i,controls)
        ModifyControl $control,win=XRDPlotWorkspace,disable=SelectNumber(shown,1,0)
    endfor
    Button details,win=XRDPlotWorkspace,title=SelectString(shown,"軸・文字・サイズを設定 ▼","軸・文字・サイズを閉じる ▲")
    Variable actionsY=535+75*shown
    Button create,win=XRDPlotWorkspace,pos={15,actionsY}
    Button update,win=XRDPlotWorkspace,pos={325,actionsY}
    Button open,win=XRDPlotWorkspace,pos={640,actionsY}
    Button saveNative,win=XRDPlotWorkspace,pos={15,actionsY+50}
    Button figureSettings,win=XRDPlotWorkspace,pos={485,actionsY+50}
    return 0
End

Function/S XRD_PlotSaveDraft(recipe)
    String recipe
    String base=XRD_PlotRoot(),ui=base+":UI",path,folder,uid
    Wave/T paths=$(ui+":paths"),labels=$(ui+":labels")
    Wave flags=$(ui+":flags"),style=$(ui+":lineStyle")
    Variable i,n=0
    for(i=0;i<numpnts(paths);i+=1)
        if(flags[i][0] & 16)
            if(!XRD_IsAnalysisComplete(paths[i]) || NumVarOrDefault(XRD80_ProjectForMeasurement(paths[i])+":projectDeleted100",0))
                DoAlert 0,"解析状態が変わった試料があります。一覧を更新して選び直してください。"
                return ""
            endif
            n+=1
        endif
    endfor
    if(n==0 || NumVarOrDefault(ui+":xMin",20)>=NumVarOrDefault(ui+":xMax",70))
        DoAlert 0,"解析完了の試料を1つ以上選び、2θの下限を上限より小さくしてください。"
        return ""
    endif
    if(!strlen(recipe))
        NVAR serial=$(base+":serial")
        do
            serial+=1
            recipe=base+":Plots:Plot"+num2istr(serial)
        while(DataFolderExists(recipe))
        NewDataFolder/O $recipe
        String/G $(recipe+":plotUID")="plot"+num2istr(serial)
    endif
    String/G $(recipe+":displayName")=StrVarOrDefault(ui+":title","XRD 比較図")
    String/G $(recipe+":savedAt")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    String/G $(recipe+":nativeMacro")=""
    String/G $(recipe+":visualOrder81")=""
    Variable/G $(recipe+":stale")=0
    String settings="spacing;offsetMode;width;height;font;legendFont;xMin;xMax;yMin;legendColumns;legendSeparate",key
    Variable j
    for(j=0;j<ItemsInList(settings);j+=1)
        key=StringFromList(j,settings)
        Variable/G $(recipe+":"+key)=NumVarOrDefault(ui+":"+key,0)
    endfor
    Make/O/T/N=(n) $(recipe+":sourceUIDs"),$(recipe+":sourceLabels"),$(recipe+":sourceNames"),$(recipe+":sourceProjects")
    Make/O/D/N=(n,4) $(recipe+":lineStyle")
    Wave/T sourceUIDs=$(recipe+":sourceUIDs"),savedLabels=$(recipe+":sourceLabels"),names=$(recipe+":sourceNames"),projects=$(recipe+":sourceProjects")
    Wave savedStyle=$(recipe+":lineStyle")
    NewDataFolder/O $(recipe+":Snapshot")
    n=0
    for(i=0;i<numpnts(paths);i+=1)
        if(!(flags[i][0] & 16))
            continue
        endif
        path=paths[i];folder=recipe+":Snapshot:Sample"+num2istr(n+1)
        NewDataFolder/O $folder
        XRD_NormalizeMeasurement(path)
        Duplicate/O $(path+":Raw:twoTheta"),$(folder+":tt")
        Duplicate/O $(path+":Processed:intensity"),$(folder+":intensity")
        Duplicate/O $(path+":Peaks:angle"),$(folder+":peakAngle")
        Duplicate/O $(path+":Peaks:height"),$(folder+":peakHeight")
        Duplicate/O $(path+":Peaks:peakID"),$(folder+":peakID")
        Duplicate/O $(path+":Assignments:peakID"),$(folder+":assignmentID")
        Duplicate/O $(path+":Assignments:refIndex"),$(folder+":refIndex")
        Wave/Z reflections=$(path+":Assignments:refPeakIndex"),shifts=$(path+":Assignments:shift")
        if(WaveExists(reflections))
            Duplicate/O reflections,$(folder+":refPeakIndex")
        endif
        if(WaveExists(shifts))
            Duplicate/O shifts,$(folder+":referenceShift")
        endif
        sourceUIDs[n]=XRD80_MeasurementUID(path);savedLabels[n]=labels[i]
        names[n]=StrVarOrDefault(path+":displayName","");projects[n]=XRD_ProjectDisplayName(XRD_PlotOwner(path))
        savedStyle[n][]=style[i][q]
        String/G $(folder+":sourceUID")=sourceUIDs[n]
        Variable/G $(folder+":analysisRevision")=NumVarOrDefault(path+":analysisRevision",0)
        Variable/G $(folder+":wavelength")=NumVarOrDefault(path+":measurementWavelength",1.5406)
        Variable/G $(folder+":zeroCorrection")=NumVarOrDefault(path+":zeroCorrection",0)
        Wave assignmentIDs=$(path+":Assignments:peakID"),referenceIDs=$(path+":Assignments:refIndex"),peakAngles=$(path+":Peaks:angle")
        String/G $(folder+":sourceRevision")=num2str(WaveCRC(0,assignmentIDs))+":"+num2str(WaveCRC(0,referenceIDs))+":"+num2str(WaveCRC(0,peakAngles))
        Make/O/T/N=(numpnts(referenceIDs)) $(folder+":phaseLabels"),$(folder+":phaseKeys"),$(folder+":referenceUIDs"),$(folder+":referenceRevisionUIDs"),$(folder+":reflectionUIDs")
        Wave/T phaseLabels=$(folder+":phaseLabels"),phaseKeys=$(folder+":phaseKeys"),referenceUIDs=$(folder+":referenceUIDs"),revisions=$(folder+":referenceRevisionUIDs"),reflectionIDs=$(folder+":reflectionUIDs")
        for(j=0;j<numpnts(referenceIDs);j+=1)
            if(referenceIDs[j]>0)
                phaseLabels[j]=XRD_PhaseLabel(referenceIDs[j])
                phaseKeys[j]=StrVarOrDefault(XRD_ReferencePath(referenceIDs[j])+":styleGroup",phaseLabels[j])
                referenceUIDs[j]=StrVarOrDefault(XRD_ReferencePath(referenceIDs[j])+":refUID","")
                revisions[j]=StrVarOrDefault(XRD_ReferencePath(referenceIDs[j])+":revisionUID","")
                Wave/T/Z reflectionMap=$(XRD_ReferencePath(referenceIDs[j])+":reflectionUID")
                if(WaveExists(reflectionMap) && WaveExists(reflections))
                    if(reflections[j]>=0 && reflections[j]<numpnts(reflectionMap))
                        reflectionIDs[j]=reflectionMap[reflections[j]]
                    endif
                endif
            endif
        endfor
        n+=1
    endfor
    String/G $(ui+":recipe")=recipe
    if(WinType("XRDPlotWorkspace"))
        PopupMenu saved,win=XRDPlotWorkspace,value=XRD_PlotChoices()
    endif
    return recipe
End

Function XRD_PlotLoadRecipe(recipe)
    String recipe
    if(!DataFolderExists(recipe))
        return -1
    endif
    String ui=XRD_PlotRoot()+":UI",key,path
    XRD_PlotSelectionTable(1)
    Wave/T paths=$(ui+":paths"),labels=$(ui+":labels"),table=$(ui+":table"),savedUIDs=$(recipe+":sourceUIDs"),savedLabels=$(recipe+":sourceLabels")
    Wave flags=$(ui+":flags"),style=$(ui+":lineStyle"),savedStyle=$(recipe+":lineStyle")
    Variable i,j,k,n=0,temp,savedIndex
    String text,visualOrder=StrVarOrDefault(recipe+":visualOrder81","")
    // Saved order is independent of both project order and current sample names.
    for(i=0;i<numpnts(savedUIDs);i+=1)
        savedIndex=i
        if(ItemsInList(visualOrder)==numpnts(savedUIDs))
            savedIndex=str2num(StringFromList(i,visualOrder))
        endif
        path=XRD80_ResolveMeasurement(savedUIDs[savedIndex]);j=-1
        for(k=n;k<numpnts(paths);k+=1)
            if(cmpstr(paths[k],path)==0)
                j=k
                break
            endif
        endfor
        if(j<0)
            continue
        endif
        text=paths[n];paths[n]=paths[j];paths[j]=text
        text=labels[n];labels[n]=labels[j];labels[j]=text
        for(k=0;k<4;k+=1)
            text=table[n][k];table[n][k]=table[j][k];table[j][k]=text
            temp=style[n][k];style[n][k]=style[j][k];style[j][k]=temp
        endfor
        labels[n]=savedLabels[savedIndex];flags[n][0]=48;style[n][]=savedStyle[savedIndex][q];n+=1
    endfor
    String/G $(ui+":recipe")=recipe
    String/G $(ui+":title")=StrVarOrDefault(recipe+":displayName","")
    String settings="spacing;offsetMode;width;height;font;legendFont;xMin;xMax;yMin;legendColumns;legendSeparate"
    for(i=0;i<ItemsInList(settings);i+=1)
        key=StringFromList(i,settings)
        Variable/G $(ui+":"+key)=NumVarOrDefault(recipe+":"+key,SelectNumber(cmpstr(key,"legendColumns")==0,0,2))
    endfor
    XRD110_PlotTrees()
    return 0
End

Function XRD_PlotSnapshotPhases(win,recipe,index,offset)
    String win,recipe
    Variable index,offset
    String folder=recipe+":Snapshot:Sample"+num2istr(index+1)
    Wave px=$(folder+":peakAngle"),py=$(folder+":peakHeight"),ids=$(folder+":peakID"),aid=$(folder+":assignmentID"),refs=$(folder+":refIndex")
    XRD_PlotPhaseWaves(win,folder,"S"+num2istr(index+1),px,py,ids,aid,refs,offset)
    Wave/T/Z labels=$(folder+":phaseLabels"),keys=$(folder+":phaseKeys")
    Variable i
    String trace
    if(WaveExists(labels) && WaveExists(keys))
        for(i=0;i<numpnts(refs);i+=1)
            if(refs[i]>0)
                trace=CleanupName("MS"+num2istr(index+1)+"R"+num2istr(refs[i]),0)
                SetWindow $win userdata($("Phase_"+trace))=labels[i]
                SetWindow $win userdata($("PhaseKey_"+trace))=keys[i]
            endif
        endfor
    endif
    return 0
End

Function XRD_PlotAddPhases(win,path,offset,folder)
    String win,path,folder
    Variable offset
    Wave px=$(path+":Peaks:angle"),py=$(path+":Peaks:height"),ids=$(path+":Peaks:peakID"),aid=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex")
    return XRD_PlotPhaseWaves(win,folder,XRD80_MeasurementUID(path),px,py,ids,aid,refs,offset)
End

Function XRD_PlotPhaseWaves(win,folder,prefix,px,py,ids,aid,refs,offset)
    String win,folder,prefix
    Wave px,py,ids,aid,refs
    Variable offset
    Variable i,j,index,n,maximum=0
    String seen="",trace,rp
    for(i=0;i<numpnts(refs);i+=1)
        index=refs[i]
        if(index<=0 || WhichListItem(num2istr(index),seen)>=0)
            continue
        endif
        seen+=num2istr(index)+";";rp=XRD_ReferencePath(index)
        if(!DataFolderExists(rp))
            continue
        endif
        trace=CleanupName("M"+prefix+"R"+num2istr(index),0)
        Make/O/D/N=(numpnts(px)) $(folder+":"+trace+"X"),$(folder+":"+trace+"Y")
        Wave xx=$(folder+":"+trace+"X"),yy=$(folder+":"+trace+"Y")
        n=0
        for(j=0;j<numpnts(aid);j+=1)
            if(refs[j]!=index)
                continue
            endif
            FindValue/V=(aid[j]) ids
            if(V_value>=0)
                xx[n]=px[V_value];yy[n]=py[V_value]+offset;n+=1
            endif
        endfor
        Redimension/N=(n) xx,yy
        if(!n)
            continue
        endif
        AppendToGraph/W=$win yy/TN=$trace vs xx
        SetWindow $win userdata($("Ref_"+trace))=num2istr(index)
        SetWindow $win userdata($("Phase_"+trace))=XRD_PhaseLabel(index)
        XRD_ApplyPhaseStyle(win,trace,index)
    endfor
    return 0
End

Function XRD_PlotLegend(win)
    String win
    return XRD110_RenderLegend(win)
End

Function XRD_PlotDrawRecipe(recipe,preserveNative)
    String recipe
    Variable preserveNative
    if(!DataFolderExists(recipe))
        return -1
    endif
    String win="XRDP_"+StrVarOrDefault(recipe+":plotUID","unknown")
    if(preserveNative && WinType(win))
        XRD80_RefreshPlotPalette(recipe,win)
        DoWindow/F $win
        return 0
    endif
    DoWindow/K $win
    if(preserveNative && XRD_PlotRestoreNative(recipe,win)==0)
        XRD80_RefreshPlotPalette(recipe,win)
        return 0
    endif
    Wave/T labels=$(recipe+":sourceLabels")
    Wave style=$(recipe+":lineStyle")
    Variable i,n=numpnts(labels),spacing=NumVarOrDefault(recipe+":spacing",135)*NumVarOrDefault(recipe+":offsetMode",1),offset,upper=140+(n-1)*spacing
    String folder,trace,visualOrder=StrVarOrDefault(recipe+":visualOrder81","")
    Variable savedIndex
    for(i=0;i<n;i+=1)
        savedIndex=i
        if(ItemsInList(visualOrder)==n)
            savedIndex=str2num(StringFromList(i,visualOrder))
        endif
        folder=recipe+":Snapshot:Sample"+num2istr(savedIndex+1)
        Wave xx=$(folder+":tt"),yy=$(folder+":intensity")
        Duplicate/O yy,$(folder+":displayIntensity")
        Wave gy=$(folder+":displayIntensity")
        offset=(n-1-i)*spacing;gy=yy[p]+offset;trace="Measurement"+num2istr(savedIndex+1)
        if(i==0)
            Display/K=1/N=$win gy/TN=$trace vs xx as StrVarOrDefault(recipe+":displayName","XRD 比較図")
            SetWindow $win userdata(XRDGraphData)=recipe
            SetWindow $win userdata(XRDPlotRecipe)=recipe
            SetWindow $win userdata(XRDExperimentPlot)="1"
        else
            AppendToGraph/W=$win gy/TN=$trace vs xx
        endif
        ModifyGraph/W=$win rgb($trace)=(style[savedIndex][1],style[savedIndex][2],style[savedIndex][3]),lsize($trace)=style[savedIndex][0]
        XRD_PlotSnapshotPhases(win,recipe,savedIndex,offset)
        TextBox/W=$win/C/N=$("Condition"+num2istr(savedIndex+1))/F=0/B=1/A=RT/X=2/Y=(100*(upper-offset-90)/(upper-NumVarOrDefault(recipe+":yMin",-30))) "\\Z16"+labels[savedIndex]
    endfor
    if(n==0)
        return -1
    endif
    XRD_GraphStyle(win,upper,1)
    ModifyGraph/W=$win width=NumVarOrDefault(recipe+":width",340.157),height=NumVarOrDefault(recipe+":height",360),gfSize=NumVarOrDefault(recipe+":font",24)
    SetAxis/W=$win bottom NumVarOrDefault(recipe+":xMin",20),NumVarOrDefault(recipe+":xMax",70)
    SetAxis/W=$win left NumVarOrDefault(recipe+":yMin",-30),upper
    SetWindow $win userdata(XRDFigureWidth)=num2str(NumVarOrDefault(recipe+":width",340.157))
    SetWindow $win userdata(XRDFigureHeight)=num2str(NumVarOrDefault(recipe+":height",360))
    SetWindow $win userdata(XRDFigureLegendFont)=num2str(NumVarOrDefault(recipe+":legendFont",24))
    XRD_PlotLegend(win)
    XRD_StampGraph(win)
    XRD_EnableFigureResize(win)
    SetWindow $win hook(XRDPlot)=XRD_PlotWindowHook
    Variable/G $(recipe+":paletteRevision")=NumVarOrDefault(XRD80_Styles()+":revision",0)
    XRD_PlotCaptureNative(recipe)
    return 0
End

Function XRD_PlotCaptureNative(recipe)
    String recipe
    String win="XRDP_"+StrVarOrDefault(recipe+":plotUID","unknown")
    if(!WinType(win))
        return -1
    endif
    DFREF old=GetDataFolderDFR()
    SetDataFolder root:
    String/G $(recipe+":nativeMacro")=WinRecreation(win,4)
    SetDataFolder old
    return 0
End

Function XRD_PlotRestoreNative(recipe,win)
    String recipe,win
    String script=StrVarOrDefault(recipe+":nativeMacro",""),line
    if(!strlen(script))
        return -1
    endif
    Variable i,k,created=0,error=0
    String/G $(recipe+":nativeReplayError")=""
    Variable/G $(recipe+":replaying")=1
    DFREF old=GetDataFolderDFR()
    SetDataFolder root:
    // Replay only locally generated Igor recreation commands, never imported text.
    // Complex third-party annotations may require reopening the saved .pxp itself.
    try
        for(i=0;i<ItemsInList(script,"\r");i+=1)
            line=TrimString(StringFromList(i,script,"\r"))
            if(!strlen(line) || strsearch(line,"Window ",0)==0 || strsearch(line,"EndMacro",0)==0 || strsearch(line,"PauseUpdate",0)==0 || strsearch(line,"Silent ",0)==0)
                continue
            endif
            // The recreation macro's local DFREF cannot survive separate Execute calls.
            // This function already saves and restores the caller's data folder.
            if(strsearch(line,"DFREF ",0)==0 || strsearch(line,"SetDataFolder fldrSav",0)==0)
                continue
            endif
            // Stored recreation scripts from older releases may use /K=0.
            // Keep manual graph edits while adopting the package close policy.
            if(!created && strsearch(line,"Display",0)==0)
                for(k=0;k<=4;k+=1)
                    line=ReplaceString("/K="+num2istr(k),line,"")
                endfor
                line="Display/K=1 "+line[7,inf]
            endif
            Execute/Q/Z line
            if(V_flag)
                error=1
                String/G $(recipe+":nativeReplayError")=line+" / error="+num2istr(V_flag)
                break
            endif
            if(!created && strsearch(line,"Display",0)==0)
                DoWindow/C $win
                created=1
            endif
        endfor
    catch
        error=GetRTError(1)
        String/G $(recipe+":nativeReplayError")=line+" / runtime="+num2istr(error)
    endtry
    SetDataFolder old
    if(error || !WinType(win))
        DoWindow/K $win
        Variable/G $(recipe+":replaying")=0
        return -1
    endif
    Variable/G $(recipe+":replaying")=0
    SetWindow $win hook(XRDPlot)=XRD_PlotWindowHook
    return 0
End

Function XRD_PlotWindowHook(info)
    STRUCT WMWinHookStruct &info
    if(info.eventCode==2)
        String recipe=GetUserData(info.winName,"","XRDPlotRecipe")
        if(strlen(recipe) && DataFolderExists(recipe) && !NumVarOrDefault(recipe+":replaying",0))
            XRD_PlotCaptureNative(recipe)
        endif
    endif
    return 0
End

Function XRD_PlotRefreshStyles()
    String wins=WinList("*",";","WIN:1"),win,traces,trace
    Variable i,j,index
    wins+="XRDWorkbench#Pattern;XRDWorkbench#SideCompare;"
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(!WinType(win))
            continue
        endif
        traces=TraceNameList(win,";",1)
        for(j=0;j<ItemsInList(traces);j+=1)
            trace=StringFromList(j,traces);index=str2num(GetUserData(win,"","Ref_"+trace))
            if(numtype(index)==0 && index>0)
                XRD_ApplyPhaseStyle(win,trace,index)
            endif
        endfor
        // Legend text, axes, annotations and dimensions edited by the user stay intact.
        String recipe=GetUserData(win,"","XRDPlotRecipe")
        if(strlen(recipe) && DataFolderExists(recipe))
            Variable/G $(recipe+":paletteRevision")=NumVarOrDefault(XRD80_Styles()+":revision",0)
            XRD_PlotCaptureNative(recipe)
        endif
    endfor
    return 0
End

Function XRD80_RefreshPlotPalette(recipe,win)
    String recipe,win
    Variable revision=NumVarOrDefault(XRD80_Styles()+":revision",0),i,index
    if(NumVarOrDefault(recipe+":paletteRevision",0)>=revision)
        return 0
    endif
    String traces=TraceNameList(win,";",1),trace
    for(i=0;i<ItemsInList(traces);i+=1)
        trace=StringFromList(i,traces)
        index=str2num(GetUserData(win,"","Ref_"+trace))
        if(numtype(index)==0 && index>0)
            XRD_ApplyPhaseStyle(win,trace,index)
        endif
    endfor
    Variable/G $(recipe+":paletteRevision")=revision
    XRD_PlotCaptureNative(recipe)
    return 0
End

Function XRD80_MarkPlotsStale(path)
    String path
    String plots=XRD_PlotRoot()+":Plots",uid=XRD80_MeasurementUID(path),name,recipe,win
    Variable i=0,j
    do
        name=GetIndexedObjName(plots,4,i)
        if(!strlen(name))
            break
        endif
        recipe=plots+":"+name
        Wave/T/Z sources=$(recipe+":sourceUIDs")
        if(WaveExists(sources))
            for(j=0;j<numpnts(sources);j+=1)
                if(cmpstr(sources[j],uid)==0)
                    Variable/G $(recipe+":stale")=1
                    win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
                    if(WinType(win))
                        TextBox/W=$win/C/N=XRDNeedsUpdate/F=0/B=1/A=LT "\\Z12元の解析に変更あり：この図は作成時の結果を保持しています"
                    endif
                    break
                endif
            endfor
        endif
        i+=1
    while(1)
    return 0
End
