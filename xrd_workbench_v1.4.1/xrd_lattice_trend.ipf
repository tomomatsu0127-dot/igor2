#pragma rtGlobals=3

Function XRD133_FinishFit(path,workspace,batch)
    String path,workspace
    Variable batch
    if(batch)
        XRD_RecordLatticeQuality(path,workspace=workspace)
        XRD130_ReferenceComparison(path,refresh=1,workspace=workspace)
        XRD80_RecordLatticeRun(path,workspace=workspace)
    else
        XRD_RecordLatticeQuality(path)
        XRD130_ReferenceComparison(path,refresh=1)
        XRD80_RecordLatticeRun(path)
    endif
End

Function/S XRD133_TrendFigures()
    return "root:Packages:XRDWorkbench:LatticeTrendFigures"
End

Function/S XRD133_TrendSettings(project)
    String project
    String base=project+":LatticeTrend"
    NewDataFolder/O $base
    NewDataFolder/O $(base+":UI")
    XRD_EnsureNumeric(base+":axis",1)
    XRD_EnsureNumeric(base+":ref",0)
    XRD_EnsureNumeric(base+":crystal",1)
    XRD_EnsureNumeric(base+":allProjects",0)
    XRD_EnsureNumeric(base+":referenceLines",1)
    SVAR/Z temperature=$(base+":temperatureLabel141"),composition=$(base+":compositionLabel141")
    if(!SVAR_Exists(temperature))
        String/G $(base+":temperatureLabel141")=""
    endif
    if(!SVAR_Exists(composition))
        String/G $(base+":compositionLabel141")=""
    endif
    if(!WaveExists($(base+":draft")))
        // Columns: measurement UID, selected, temperature, composition, custom x.
        Make/T/N=(0,5) $(base+":draft")
        String/G $(base+":customLabel")="横軸"
        String/G $(base+":customUnit")=""
    endif
    return base
End

Function/S XRD133_TrendOwner()
    if(!WinType("XRDLatticeTrend"))
        return ""
    endif
    return XRD100_ProjectByUID(GetUserData("XRDLatticeTrend","","ownerUID"))
End

Function/S XRD133_AxisLabel(base)
    String base
    Variable axis=NumVarOrDefault(base+":axis",1)
    String title=TrimString(StrVarOrDefault(XRD141_AxisLabelPath(base),""))
    if(axis==1)
        return SelectString(strlen(title)>0,"温度 (°C)",title)
    elseif(axis==2)
        return SelectString(strlen(title)>0,"組成 x",title)
    endif
    title=SelectString(strlen(title)>0,"横軸",title)
    String unit=TrimString(StrVarOrDefault(base+":customUnit",""))
    return SelectString(strlen(unit)>0,title,title+" ("+unit+")")
End

Function XRD133_ParseX(value)
    String value
    value=TrimString(ReplaceString("－",ReplaceString("−",value,"-"),"-"))
    if(!GrepString(value,"^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$"))
        return NaN
    endif
    Variable number=str2num(value)
    return SelectNumber(numtype(number)==0,NaN,number)
End

Function/S XRD133_CompositionX(path)
    String path
    String label=TrimString(StrVarOrDefault(path+":composition","")),number=""
    SplitString/E="^x[ \\t]*=[ \\t]*(.*)$" label,number
    if(V_flag!=1)
        number=label
    endif
    return SelectString(numtype(XRD133_ParseX(number))==0,"",TrimString(number))
End

Function XRD133_DraftRow(base,uid,create)
    String base,uid
    Variable create
    Wave/T draft=$(base+":draft")
    Variable i,n=DimSize(draft,0)
    for(i=0;i<n;i+=1)
        if(cmpstr(draft[i][0],uid)==0)
            return i
        endif
    endfor
    if(!create || !strlen(uid))
        return -1
    endif
    Redimension/N=(n+1,5) draft
    draft[n][0]=uid
    draft[n][1]="0"
    draft[n][3]=XRD133_CompositionX(XRD80_ResolveMeasurement(uid))
    return n
End

Function XRD133_ValidRun(run,path,ref,crystal)
    String run,path,crystal
    Variable ref
    if(!strlen(run) || NumVarOrDefault(run+":refIndex",-1)!=ref || cmpstr(StrVarOrDefault(run+":crystalSystem",""),crystal)!=0 || NumVarOrDefault(run+":stale",0))
        return 0
    endif
    Variable rev=NumVarOrDefault(path+":analysisRevision",0),a=NumVarOrDefault(run+":a",NaN),c=NumVarOrDefault(run+":c",NaN)
    if(NumVarOrDefault(run+":analysisRevision",rev)!=rev || numtype(a)!=0 || a<=0 || strsearch(StrVarOrDefault(run+":state",""),"変更あり",0)>=0)
        return 0
    endif
    String revision=StrVarOrDefault(XRD_ReferencePath(ref)+":revisionUID","")
    if(cmpstr(StrVarOrDefault(run+":referenceRevisionUID",revision),revision)!=0)
        return 0
    endif
    return cmpstr(crystal,"立方晶")==0 || (numtype(c)==0 && c>0)
End

Function/S XRD133_CurrentRun(path,ref,crystal)
    String path,crystal
    Variable ref
    if(!strlen(path) || !DataFolderExists(path) || NumVarOrDefault(path+":deleted",0))
        return ""
    endif
    Wave/Z refs=$(path+":Assignments:refIndex")
    if(!WaveExists(refs) || !XRD_PhaseAdopted(path,ref))
        return ""
    endif
    String latest=XRD80_LatticeResultPath(path,ref)
    if(XRD133_ValidRun(latest,path,ref,crystal))
        return latest
    endif
    String folder=path+":LatticeRuns",run,name,best=""
    if(!DataFolderExists(folder))
        return ""
    endif
    DFREF runs=$folder
    Variable i,seq,bestSeq=-1
    for(i=0;i<CountObjectsDFR(runs,4);i+=1)
        name=GetIndexedObjNameDFR(runs,4,i)
        run=folder+":"+PossiblyQuoteName(name)
        seq=NumVarOrDefault(run+":runSequence",0)
        if(seq>=bestSeq && XRD133_ValidRun(run,path,ref,crystal))
            bestSeq=seq
            best=run
        endif
    endfor
    return best
End

Function XRD133_Compute(path,ref,crystal)
    String path,crystal
    Variable ref
    if(!strlen(path) || !DataFolderExists(path) || ref<1 || !DataFolderExists(XRD_ReferencePath(ref)) || NumVarOrDefault(path+":deleted",0))
        return -1
    endif
    if(strlen(XRD133_CurrentRun(path,ref,crystal)))
        return 0
    endif
    if(!XRD_PhaseAdopted(path,ref))
        return -1
    endif
    // Work on a separate fit folder so this operation never replaces the
    // single-measurement editor or its current result.
    String workspace="root:Packages:XRDWorkbench:LatticeBatchFit",previous=path+":Lattice"
    if(NumVarOrDefault(previous+":refIndex",-1)!=ref)
        previous=XRD80_LatticeResultPath(path,ref)
    endif
    if(!strlen(previous))
        previous=workspace
    endif
    KillDataFolder/Z $workspace
    Variable result
    try
        XRD_PrepareLattice(path,ref,workspace=workspace,previous=previous); AbortOnRTE
        String/G $(workspace+":crystalSystem")=crystal
        if(cmpstr(crystal,"立方晶")==0)
            result=XRD_FitCubic(path,workspace=workspace); AbortOnRTE
        else
            result=XRD_FitHexagonal(path,workspace=workspace); AbortOnRTE
        endif
        result=SelectNumber(result==0,result-10,1)
    catch
        Print "XRD lattice batch error",GetRTError(1)
        result=-2
    endtry
    KillDataFolder/Z $workspace
    return result
End

Function/S XRD133_Crystal(base)
    String base
    return StringFromList(NumVarOrDefault(base+":crystal",1)-1,"六方晶;立方晶")
End

Function/S XRD133_PhaseCaption(ref)
    Variable ref
    String rp=XRD_ReferencePath(ref)
    return XRD_PhaseLabel(ref)+" / "+StrVarOrDefault(rp+":cardNumber","カード番号なし")+" [参照 "+num2istr(ref)+"]"
End

Function/S XRD133_PhaseMenu(base)
    String base
    String list="相を選択…;"
    Wave/Z phases=$(base+":UI:phases")
    Variable i
    if(WaveExists(phases))
        for(i=0;i<numpnts(phases);i+=1)
            list+=ReplaceString(";",XRD133_PhaseCaption(phases[i]),"；")+";"
        endfor
    endif
    return list
End

Function XRD133_PhaseMode(base)
    String base
    Wave phases=$(base+":UI:phases")
    Variable i,ref=NumVarOrDefault(base+":ref",0)
    for(i=0;i<numpnts(phases);i+=1)
        if(phases[i]==ref)
            return i+2
        endif
    endfor
    return 1
End

Function XRD133_TrendTable(project)
    String project
    String base=XRD133_TrendSettings(project),ui=base+":UI",owner,path,uid,names,run
    String projects=project+";",crystal=XRD133_Crystal(base)
    if(NumVarOrDefault(base+":allProjects",0))
        projects+=RemoveFromList(project,XRD_ProjectList())
    endif
    Variable i,j,k,n=0,capacity=0,record,phase,axis=NumVarOrDefault(base+":axis",1)
    Variable ref=NumVarOrDefault(base+":ref",0),referenceCount=NumVarOrDefault(XRD80_Library()+":referenceCount",0)
    Make/FREE/B/U/N=(referenceCount+1) used=0
    if(ref>0 && ref<=referenceCount)
        used[ref]=1
    endif
    for(i=0;i<ItemsInList(projects);i+=1)
        capacity+=ItemsInList(XRD127_MeasurementList(StringFromList(i,projects)))
    endfor
    Make/O/T/N=(max(1,capacity),7) $(ui+":table")=""
    Make/O/B/U/N=(max(1,capacity),7) $(ui+":flags")=0
    Make/O/T/N=(max(1,capacity)) $(ui+":uids")=""
    Make/O/D/N=0 $(ui+":phases")
    Wave/T table=$(ui+":table"),uids=$(ui+":uids"),draft=$(base+":draft")
    Wave flags=$(ui+":flags"),phases=$(ui+":phases")
    SetDimLabel 1,0,'作図',table
    SetDimLabel 1,1,'プロジェクト',table
    SetDimLabel 1,2,'測定データ',table
    SetDimLabel 1,3,'横軸の値',table
    SetDimLabel 1,4,'選択相の計算状態',table
    SetDimLabel 1,5,'a (Å)',table
    SetDimLabel 1,6,'c (Å)',table
    for(i=0;i<ItemsInList(projects);i+=1)
        owner=StringFromList(i,projects)
        names=XRD127_MeasurementList(owner)
        for(j=0;j<ItemsInList(names);j+=1)
            path=owner+":Measurements:"+StringFromList(j,names)
            uid=StrVarOrDefault(path+":measurementUID","")
            if(!strlen(uid))
                uid=XRD80_MeasurementUID(path)
            endif
            uids[n]=uid
            record=XRD133_DraftRow(base,uid,0)
            table[n][1]=XRD_ProjectDisplayName(owner)
            table[n][2]=XRD110_SampleLabel(path)
            flags[n][0]=32
            flags[n][3]=6
            if(record>=0)
                flags[n][0]+=16*(str2num(draft[record][1])==1)
                table[n][3]=draft[record][axis+1]
            elseif(axis==2)
                table[n][3]=XRD133_CompositionX(path)
            endif
            Wave/Z refs=$(path+":Assignments:refIndex")
            if(WaveExists(refs))
                for(k=0;k<numpnts(refs);k+=1)
                    phase=refs[k]
                    if(phase>0 && phase<=referenceCount && phase==trunc(phase))
                        used[phase]=1
                    endif
                endfor
            endif
            table[n][4]="相を選択"
            if(ref>0)
                run=XRD133_CurrentRun(path,ref,crystal)
                table[n][4]=SelectString(XRD_PhaseAdopted(path,ref),"相の同定なし","未計算・要再計算")
                if(strlen(run))
                    table[n][4]="計算済み"
                    table[n][5]=num2str(NumVarOrDefault(run+":a",NaN))
                    if(cmpstr(crystal,"六方晶")==0)
                        table[n][6]=num2str(NumVarOrDefault(run+":c",NaN))
                    endif
                endif
            endif
            n+=1
        endfor
    endfor
    if(n==0)
        table[0][2]="測定データがありません"
    endif
    Variable pCount=0
    for(i=1;i<=referenceCount;i+=1)
        if(used[i])
            Redimension/N=(pCount+1) phases
            phases[pCount]=i
            pCount+=1
        endif
    endfor
    return n
End

Function/S XRD133_SavedFigures(project)
    String project
    String base=project+":LatticeTrend:UI",figures=XRD133_TrendFigures(),uid=StrVarOrDefault(project+":projectUID",""),name,recipe
    String result="保存済みの図を選択…;",paths=""
    if(DataFolderExists(figures))
        DFREF folder=$figures
        Variable i
        for(i=0;i<CountObjectsDFR(folder,4);i+=1)
            name=GetIndexedObjNameDFR(folder,4,i)
            recipe=figures+":"+PossiblyQuoteName(name)
            if(cmpstr(StrVarOrDefault(recipe+":ownerUID",""),uid)==0)
                paths+=recipe+";"
                result+=ReplaceString(";",StrVarOrDefault(recipe+":displayName",name),"；")+" / "+StrVarOrDefault(recipe+":created","")+";";
            endif
        endfor
    endif
    String/G $(base+":figures")=paths
    return result
End


Function/S XRD133_ActivePhaseMenu()
    String project=XRD133_TrendOwner()
    if(!strlen(project))
        return "相を選択…;"
    endif
    return XRD133_PhaseMenu(project+":LatticeTrend")
End

Function/S XRD133_ActiveFigureMenu()
    String project=XRD133_TrendOwner()
    if(!strlen(project))
        return "保存済みの図を選択…;"
    endif
    return XRD133_SavedFigures(project)
End

Function XRD133_RefreshTrend(project)
    String project
    String base=project+":LatticeTrend"
    Variable first=0
    if(WinType("XRDLatticeTrend"))
        ControlInfo/W=XRDLatticeTrend samples
        first=V_startRow
    endif
    Variable n=XRD133_TrendTable(project)
    if(WinType("XRDLatticeTrend"))
        Variable phaseMode=XRD133_PhaseMode(base)
        PopupMenu phase,win=XRDLatticeTrend,value=XRD133_ActivePhaseMenu(),mode=phaseMode
        TitleBox axisHint,win=XRDLatticeTrend,title="横軸  "+XRD133_AxisLabel(base)+"  ／  「横軸の値」をダブルクリックで編集"
        Variable showCustom=SelectNumber(NumVarOrDefault(base+":axis",1)==3,1,0)
        SetVariable customLabel,win=XRDLatticeTrend,value=$(XRD141_AxisLabelPath(base))
        SetVariable customUnit,win=XRDLatticeTrend,disable=showCustom
        Variable ref=NumVarOrDefault(base+":ref",0)
        String selected=StrVarOrDefault(base+":UI:selectedFigure141","")
        Variable canEdit=ref>0 || (strlen(selected) && DataFolderExists(selected))
        Variable aDisabled=SelectNumber(canEdit,2,0)
        Variable cDisabled=SelectNumber(canEdit && NumVarOrDefault(base+":crystal",1)==1,2,0)
        String refs=XRD141_RefDraft(base,ref)
        SetVariable refA,win=XRDLatticeTrend,value=$(refs+":aOverride"),disable=aDisabled
        SetVariable refC,win=XRDLatticeTrend,value=$(refs+":cOverride"),disable=cDisabled
        TitleBox refHint,win=XRDLatticeTrend,title=XRD141_ReferenceHint(ref,canEdit)
        ListBox samples,win=XRDLatticeTrend,row=max(0,min(first,n-1))
    endif
    return n
End

Function XRD133_TrendPanel()
    if(!XRD131_ReadyPanel())
        XRD_Init()
    endif
    String project=XRD_Project()
    if(!strlen(project))
        return -1
    endif
    String base=XRD133_TrendSettings(project),ui=base+":UI",owner=StrVarOrDefault(project+":projectUID","")
    if(WinType("XRDLatticeTrend") && cmpstr(owner,GetUserData("XRDLatticeTrend","","ownerUID"))==0)
        XRD133_RefreshTrend(project)
        XRD131_KeepPanelSize()
        DoWindow/F XRDLatticeTrend
        return 0
    endif
    XRD133_TrendTable(project)
    PauseUpdate; Silent 1
    String state=XRD123_PanelState("XRDLatticeTrend")
    KillWindow/Z XRDLatticeTrend
    XRD131_KeepPanelSize()
    NewPanel/K=1/N=XRDLatticeTrend/W=(40,40,1080,650) as "格子定数の系列図 — "+XRD_ProjectDisplayName(project)
    SetWindow XRDLatticeTrend userdata(ownerUID)=owner
    DefaultGUIFont/W=XRDLatticeTrend all={"Segoe UI",12,0}
    Variable phaseMode=XRD133_PhaseMode(base),crystalMode=NumVarOrDefault(base+":crystal",1),axisMode=NumVarOrDefault(base+":axis",1)
    PopupMenu phase,pos={16,18},title="計算する相",value=XRD133_ActivePhaseMenu(),mode=phaseMode,proc=XRD133_TrendPopup
    PopupMenu crystal,pos={600,18},title="晶系",value="六方晶;立方晶;",mode=crystalMode,proc=XRD133_TrendPopup
    PopupMenu axis,pos={16,60},title="横軸",value="温度 (°C);組成 x;任意の数値;",mode=axisMode,proc=XRD133_TrendPopup
    SetVariable customLabel,pos={260,62},size={300,24},title="横軸ラベル（空欄＝自動）",value=$(XRD141_AxisLabelPath(base)),proc=XRD133_TrendAxisChanged
    SetVariable customUnit,pos={578,62},size={180,24},title="単位",value=$(base+":customUnit"),proc=XRD133_TrendAxisChanged
    CheckBox allProjects,pos={16,104},title="別のプロジェクトの測定も対象にする",variable=$(base+":allProjects"),proc=XRD133_TrendCheck
    CheckBox referenceLines,pos={362,104},title="参照値を点線で表示",variable=$(base+":referenceLines")
    String refSettings=XRD141_RefDraft(base,NumVarOrDefault(base+":ref",0))
    SetVariable refA,pos={562,102},size={174,24},title="参照 a (Å)",value=$(refSettings+":aOverride")
    SetVariable refC,pos={752,102},size={174,24},title="参照 c (Å)",value=$(refSettings+":cOverride")
    TitleBox refHint,pos={16,134},frame=0,title=""
    TitleBox axisHint,pos={16,159},frame=0,title=""
    ListBox samples,pos={16,187},size={1002,267},listWave=$(ui+":table"),selWave=$(ui+":flags"),mode=5,widths={52,162,250,108,215,100,100},proc=XRD133_TrendList
    Button calculate,pos={16,470},size={330,35},title="選んだ測定の未計算・要再計算を一括計算",proc=XRD133_TrendButton
    Button create,pos={358,470},size={270,35},title="選んだ測定から系列図を作成",proc=XRD133_TrendButton
    Button refresh,pos={640,470},size={218,35},title="測定と計算結果を更新",proc=XRD133_TrendButton
    PopupMenu figures,pos={16,522},title="保存した図",value=XRD133_ActiveFigureMenu(),mode=1,proc=XRD133_TrendPopup
    Button restyle,pos={676,522},size={340,28},title="選んだ保存図をこの書式で複製",proc=XRD133_TrendButton
    TitleBox status,pos={16,563},frame=0,title="測定にチェックを入れて、相・晶系・横軸の値を指定します。"
    XRD133_RefreshTrend(project)
    XRD123_FinishPanel("XRDLatticeTrend",state)
    return 0
End

Function XRD133_TrendList(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(!((lba.eventCode==13 && lba.col==0) || (lba.eventCode==7 && lba.col==3)))
        return 0
    endif
    String project=XRD133_TrendOwner()
    if(!strlen(project))
        return 0
    endif
    String base=project+":LatticeTrend"
    Wave/T uids=$(base+":UI:uids"),draft=$(base+":draft")
    if(lba.row<0 || lba.row>=numpnts(uids) || !strlen(uids[lba.row]))
        return 0
    endif
    Variable record=XRD133_DraftRow(base,uids[lba.row],1)
    if(lba.col==0)
        draft[record][1]=num2istr((lba.selWave[lba.row][0] & 16)!=0)
    else
        Variable axis=NumVarOrDefault(base+":axis",1)
        draft[record][axis+1]=TrimString(lba.listWave[lba.row][3])
    endif
    return 0
End

Function XRD133_TrendCheck(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    String project=XRD133_TrendOwner()
    if(cba.eventCode==2 && strlen(project))
        XRD133_RefreshTrend(project)
    endif
    return 0
End

Function XRD133_TrendAxisChanged(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva
    String project=XRD133_TrendOwner()
    if(strlen(project) && sva.eventCode>=1 && sva.eventCode<=3)
        TitleBox axisHint,win=XRDLatticeTrend,title="横軸  "+XRD133_AxisLabel(project+":LatticeTrend")+"  ／  「横軸の値」をダブルクリックで編集"
    endif
    return 0
End

Function XRD133_TrendPopup(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    String project=XRD133_TrendOwner()
    if(pa.eventCode!=2 || !strlen(project))
        return 0
    endif
    String base=project+":LatticeTrend"
    if(cmpstr(pa.ctrlName,"figures")==0)
        String recipe=StringFromList(pa.popNum-2,StrVarOrDefault(base+":UI:figures",""))
        if(strlen(recipe))
            String/G $(base+":UI:selectedFigure141")=recipe
            Variable/G $(base+":ref")=XRD141_RefForFigure(recipe)
            Variable/G $(base+":axis")=NumVarOrDefault(recipe+":axisKind",1)
            Variable/G $(base+":crystal")=SelectNumber(cmpstr(StrVarOrDefault(recipe+":crystal",""),"立方晶")==0,1,2)
            PopupMenu axis,win=XRDLatticeTrend,mode=NumVarOrDefault(base+":axis",1)
            PopupMenu crystal,win=XRDLatticeTrend,mode=NumVarOrDefault(base+":crystal",1)
            XRD133_RefreshTrend(project)
            XRD133_DrawTrend(recipe)
        endif
        return 0
    endif
    if(cmpstr(pa.ctrlName,"phase")==0)
        Wave phases=$(base+":UI:phases")
        Variable ref=0
        if(pa.popNum>1 && pa.popNum-2<numpnts(phases))
            ref=phases[pa.popNum-2]
        endif
        Variable/G $(base+":ref")=ref
    else
        Variable/G $(base+":"+pa.ctrlName)=pa.popNum
    endif
    XRD133_RefreshTrend(project)
    return 0
End

Function XRD133_TrendButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode==2)
        strswitch(ba.ctrlName)
            case "calculate":
                Execute/P/Q "XRD133_TrendAction(1)"
                break
            case "create":
                Execute/P/Q "XRD133_TrendAction(2)"
                break
            case "restyle":
                Execute/P/Q "XRD133_TrendAction(3)"
                break
            case "refresh":
                Execute/P/Q "XRD133_TrendAction(0)"
                break
        endswitch
    endif
    return 0
End

Function XRD133_TrendAction(action)
    Variable action
    String project=XRD133_TrendOwner(),message="",recipe
    if(!strlen(project))
        return -1
    endif
    XRD133_RefreshTrend(project)
    if(action==3)
        recipe=XRD141_CopyTrend(StrVarOrDefault(project+":LatticeTrend:UI:selectedFigure141",""),project,message)
        if(strlen(recipe))
            PopupMenu figures,win=XRDLatticeTrend,value=XRD133_ActiveFigureMenu(),mode=1
            XRD133_DrawTrend(recipe)
        endif
    elseif(action==1)
        message=XRD133_BatchTrend(project)
    elseif(action==2)
        recipe=XRD133_SaveTrend(project,message)
        if(strlen(recipe))
            PopupMenu figures,win=XRDLatticeTrend,value=XRD133_ActiveFigureMenu(),mode=1
            XRD133_DrawTrend(recipe)
        endif
    else
        message="測定と計算結果を更新しました。"
    endif
    TitleBox status,win=XRDLatticeTrend,title=message
    return 0
End

Function/S XRD133_BatchTrend(project)
    String project
    String base=project+":LatticeTrend",ui=base+":UI",crystal=XRD133_Crystal(base)
    Variable ref=NumVarOrDefault(base+":ref",0),i,calculated=0,reused=0,failed=0
    if(ref<=0)
        return "計算する相を選んでください。"
    endif
    Wave/T uids=$(ui+":uids"),table=$(ui+":table")
    Wave flags=$(ui+":flags")
    Make/FREE/D/N=(numpnts(uids)) results=NaN
    for(i=0;i<numpnts(uids);i+=1)
        if(flags[i][0] & 16)
            results[i]=XRD133_Compute(XRD80_ResolveMeasurement(uids[i]),ref,crystal)
            calculated+=results[i]==1
            reused+=results[i]==0
            failed+=results[i]<0
        endif
    endfor
    if(calculated+reused+failed==0)
        return "一括計算する測定にチェックを入れてください。"
    endif
    XRD133_RefreshTrend(project)
    for(i=0;i<numpnts(results);i+=1)
        if(results[i]<0)
            table[i][4]=SelectString(results[i]==-1,"計算不可（本数・hkl・波長）","相の同定なし")
        endif
    endfor
    return "新規計算 "+num2istr(calculated)+" 件  ／  既存結果 "+num2istr(reused)+" 件  ／  計算不可 "+num2istr(failed)+" 件"
End

Function/S XRD133_SaveTrend(project,message)
    String project,&message
    String base=project+":LatticeTrend",ui=base+":UI",crystal=XRD133_Crystal(base),path,run
    Variable ref=NumVarOrDefault(base+":ref",0),i,n=0,badX=0,badRun=0
    Wave/T uids=$(ui+":uids"),table=$(ui+":table")
    Wave flags=$(ui+":flags")
    if(ref<=0)
        message="作図する相を選んでください。"
        return ""
    endif
    Make/FREE/D/N=(numpnts(uids)) values,aa,cc,sa,sc
    Make/FREE/T/N=(numpnts(uids)) ids,runIDs
    for(i=0;i<numpnts(uids);i+=1)
        if(!(flags[i][0] & 16))
            continue
        endif
        path=XRD80_ResolveMeasurement(uids[i])
        run=XRD133_CurrentRun(path,ref,crystal)
        values[n]=XRD133_ParseX(table[i][3])
        badX+=numtype(values[n])!=0
        badRun+=!strlen(run)
        ids[n]=uids[i]
        runIDs[n]=StrVarOrDefault(run+":runUID","")
        aa[n]=NumVarOrDefault(run+":a",NaN)
        cc[n]=NumVarOrDefault(run+":c",NaN)
        sa[n]=NumVarOrDefault(run+":aSigma",NaN)
        sc[n]=NumVarOrDefault(run+":cSigma",NaN)
        n+=1
    endfor
    if(n<2 || badX || badRun)
        message="作図には2測定以上と全行の計算結果・横軸値が必要です。横軸要確認 "+num2istr(badX)+" 件、計算結果なし "+num2istr(badRun)+" 件"
        return ""
    endif
    Redimension/N=(n) values,aa,cc,sa,sc,ids,runIDs
    Sort values,values,aa,cc,sa,sc,ids,runIDs
    Variable pad=XRD133_PlotPadding(values[0],values[n-1])
    if(numtype(values[0]-pad)!=0 || numtype(values[n-1]+pad)!=0)
        message="横軸の値が大きすぎます。入力値と単位を確認してください。"
        return ""
    endif
    String rootPath=XRD133_TrendFigures(),uid="LTrend_"+XRD80_NewUID("F"),recipe=rootPath+":"+uid,rp=XRD_ReferencePath(ref)
    NewDataFolder/O $rootPath
    NewDataFolder $recipe
    Duplicate values,$(recipe+":horizontal")
    Duplicate aa,$(recipe+":latticeA")
    Duplicate cc,$(recipe+":latticeC")
    Duplicate sa,$(recipe+":aSigma")
    Duplicate sc,$(recipe+":cSigma")
    Duplicate ids,$(recipe+":sourceUIDs")
    Duplicate runIDs,$(recipe+":runUIDs")
    SetScale d,0,0,"Å",$(recipe+":latticeA"),$(recipe+":latticeC"),$(recipe+":aSigma"),$(recipe+":cSigma")
    Variable axisKind=NumVarOrDefault(base+":axis",1)
    String unit=SelectString(axisKind==3,StringFromList(axisKind-1,"°C;1"),TrimString(StrVarOrDefault(base+":customUnit","")))
    SetScale d,0,0,unit,$(recipe+":horizontal")
    String/G $(recipe+":plotUID")=uid
    String/G $(recipe+":ownerUID")=StrVarOrDefault(project+":projectUID","")
    String/G $(recipe+":displayName")=XRD141_FigureName("格子定数",project)
    String/G $(recipe+":ownerName141")=XRD_ProjectDisplayName(project)
    String/G $(recipe+":crystal")=crystal
    String/G $(recipe+":referenceUID")=StrVarOrDefault(rp+":refUID","")
    String/G $(recipe+":referenceRevisionUID")=StrVarOrDefault(rp+":revisionUID","")
    String/G $(recipe+":created")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    if(XRD141_TrendStyle(base,recipe,ref,message)<0)
        KillDataFolder/Z $recipe
        return ""
    endif
    Variable/G $(recipe+":axisKind")=NumVarOrDefault(base+":axis",1)
    message="系列図を作成しました。測定 "+num2istr(n)+" 件"
    return recipe
End

Function XRD133_DrawTrend(recipe)
    String recipe
    if(!strlen(recipe) || !DataFolderExists(recipe))
        return -1
    endif
    String win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    XRD131_KeepPanelSize()
    if(WinType(win))
        DoWindow/F $win
        return 0
    endif
    if(XRD_PlotRestoreNative(recipe,win)==0)
        DoWindow/F $win
        return 0
    endif
    Wave xx=$(recipe+":horizontal"),aa=$(recipe+":latticeA"),cc=$(recipe+":latticeC")
    Variable i,mode=4,hasC=cmpstr(StrVarOrDefault(recipe+":crystal",""),"六方晶")==0
    for(i=1;i<numpnts(xx);i+=1)
        if(xx[i]==xx[i-1])
            mode=3
            break
        endif
    endfor
    Display/K=1/N=$win aa/TN=LatticeA vs xx as StrVarOrDefault(recipe+":displayName","格子定数の系列図")
    ModifyGraph/W=$win mode(LatticeA)=mode,marker(LatticeA)=19,rgb(LatticeA)=(55000,0,0)
    if(hasC)
        AppendToGraph/W=$win/R cc/TN=LatticeC vs xx
        ModifyGraph/W=$win mode(LatticeC)=mode,marker(LatticeC)=16,rgb(LatticeC)=(0,0,54000)
        Label/W=$win right "\\f02c\\f00 (Å)"
    endif
    Variable xmin=xx[0],xmax=xx[numpnts(xx)-1],xPad=0
    if(xmin==xmax)
        xPad=XRD133_PlotPadding(xmin,xmax)
    endif
    Variable aRef=NumVarOrDefault(recipe+":referenceA",NaN),cRef=NumVarOrDefault(recipe+":referenceC",NaN)
    if((numtype(aRef)==0 && aRef>0) || (hasC && numtype(cRef)==0 && cRef>0))
        Make/O/D/N=2 $(recipe+":referenceX")
        Wave rx=$(recipe+":referenceX")
        rx[0]=xmin-xPad;rx[1]=xmax+xPad
        if(numtype(aRef)==0 && aRef>0)
            Make/O/D/N=2 $(recipe+":lineA")=aRef
            Wave ar=$(recipe+":lineA")
            AppendToGraph/W=$win ar/TN=ReferenceA vs rx
            ModifyGraph/W=$win lStyle(ReferenceA)=3,rgb(ReferenceA)=(55000,0,0)
        endif
        if(hasC && numtype(cRef)==0 && cRef>0)
            Make/O/D/N=2 $(recipe+":lineC")=cRef
            Wave cr=$(recipe+":lineC")
            AppendToGraph/W=$win/R cr/TN=ReferenceC vs rx
            ModifyGraph/W=$win lStyle(ReferenceC)=3,rgb(ReferenceC)=(0,0,54000)
        endif
    endif
    ModifyGraph/W=$win gFont="Times New Roman",gfSize=24,width=255.118,height=255.118,tick=2,mirror(bottom)=1,standoff=0,useLongMinus=1,tickUnit=1
    ModifyGraph/W=$win lblPosMode=1,lblMargin=24,tlOffset=-2
    ModifyGraph/W=$win lblMargin(left)=33
    if(hasC)
        ModifyGraph/W=$win lblMargin(right)=33
    endif
    ModifyGraph/W=$win fSize(bottom)=19
    XRD141_TrendXAxis(win,recipe,xx)
    XRD133_PlotYRange(win,"left",aa,aRef)
    if(hasC)
        XRD133_PlotYRange(win,"right",cc,cRef)
        ModifyGraph/W=$win lblRot(right)=180
        XRD141_Arrow(win,xx,cc,1)
    endif
    XRD141_Arrow(win,xx,aa,0)
    Label/W=$win left "\\f02a\\f00 (Å)"
    String axisLabel=StrVarOrDefault(recipe+":axisLabel","横軸")
    Variable axis=NumVarOrDefault(recipe+":axisKind",3)
    if(axis==1)
        axisLabel="\\f02T\\f00 (°C)"
    elseif(axis==2)
        axisLabel="\\f02x\\f00"
    endif
    axisLabel=StrVarOrDefault(recipe+":axisText141",axisLabel)
    Label/W=$win bottom "\\Z24"+axisLabel
    SetWindow $win userdata(XRDPlotRecipe)=recipe
    SetWindow $win hook(XRDPlot)=XRD_PlotWindowHook
    XRD_PlotCaptureNative(recipe)
    DoWindow/F $win
    return 0
End



Function XRD133_PlotPadding(lower,upper)
    Variable lower,upper
    return max((upper-lower)*0.06,max(abs(lower),abs(upper))*0.0001,1e-9)
End

Function XRD133_PlotYRange(win,axis,values,reference)
    String win,axis
    Wave values
    Variable reference
    Variable lower=WaveMin(values),upper=WaveMax(values)
    if(numtype(reference)==0 && reference>0)
        lower=min(lower,reference)
        upper=max(upper,reference)
    endif
    Variable padding=XRD133_PlotPadding(lower,upper)
    SetAxis/W=$win $axis lower-padding,upper+padding
End

Function XRD133_UpdateTrendSelection(uid,newUID)
    String uid,newUID
    String projects=XRD_ProjectList(),project,base
    Variable i,row
    for(i=0;i<ItemsInList(projects);i+=1)
        project=StringFromList(i,projects)
        base=project+":LatticeTrend"
        Wave/T/Z draft=$(base+":draft")
        if(!WaveExists(draft))
            continue
        endif
        row=XRD133_DraftRow(base,uid,0)
        if(row>=0)
            if(strlen(newUID))
                draft[row][0]=newUID
            else
                DeletePoints/M=0 row,1,draft
            endif
        endif
    endfor
    project=XRD133_TrendOwner()
    if(strlen(project))
        XRD133_RefreshTrend(project)
        PopupMenu figures,win=XRDLatticeTrend,value=XRD133_ActiveFigureMenu(),mode=1
    endif
End
