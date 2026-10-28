#pragma rtGlobals=3
// XRD Workbench v1.2.0: one Experiment-wide library. Old scientific revisions stay addressable.

Function/S XRD80_Library()
    return "root:Packages:XRDWorkbench:SharedLibrary"
End

Function XRD80_InitLibrary()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:XRDWorkbench
    String lib=XRD80_Library()
    NewDataFolder/O $lib
    NewDataFolder/O $(lib+":References")
    XRD_EnsureNumeric(lib+":referenceCount",0)
    XRD_EnsureNumeric(lib+":referenceErrorCount",0)
    XRD_EnsureNumeric(lib+":revision",0)
    SVAR/Z hint=$(lib+":referenceFolderHint")
    if(!SVAR_Exists(hint))
        String/G $(lib+":referenceFolderHint")="未選択"
        String/G $(lib+":referenceLoadSummary")="参照データ未読込"
    endif
    Wave/T/Z table=$(lib+":References:table")
    if(!WaveExists(table))
        Make/T/N=(0,6) $(lib+":References:table")
        Make/T/N=(0,2) $(lib+":References:errors")
    endif
    return 0
End

Function XRD80_SyncReferenceCounts()
    XRD80_InitLibrary()
    Variable count=NumVarOrDefault(XRD80_Library()+":referenceCount",0),i
    String projects=XRD_ProjectList(),project
    for(i=0;i<ItemsInList(projects);i+=1)
        project=XRD100_ProjectAt(projects,i)
        // A compatibility count is not a project-specific reference-use setting.
        Variable/G $(project+":referenceCount")=count
        Variable/G $(project+":referenceErrorCount")=NumVarOrDefault(XRD80_Library()+":referenceErrorCount",0)
    endfor
    return count
End

Function XRD80_LibraryReferenceEnabled(index)
    Variable index
    String rp=XRD_ReferencePath(index)
    return DataFolderExists(rp) && NumVarOrDefault(rp+":enabled",1)!=0 && NumVarOrDefault(rp+":isCurrent",1)!=0
End

Function XRD80_SameReferenceWave(a,b)
    Wave a,b
    if(numpnts(a)!=numpnts(b))
        return 0
    endif
    Variable i
    for(i=0;i<numpnts(a);i+=1)
        if(numtype(a[i])==2 && numtype(b[i])==2)
            continue
        endif
        if(numtype(a[i])!=numtype(b[i]) || a[i]!=b[i])
            return 0
        endif
    endfor
    return 1
End

Function XRD80_FindIdenticalReference(card,formula,phaseName,phaseClass,source,tt,intensities,hh,kk,ll,dd)
    String card,formula,phaseName,phaseClass,source
    Wave tt,intensities,hh,kk,ll,dd
    Variable i,count=NumVarOrDefault(XRD80_Library()+":referenceCount",0)
    String rp
    for(i=1;i<=count;i+=1)
        rp=XRD_ReferencePath(i)
        if(cmpstr(StrVarOrDefault(rp+":origin_cardNumber",StrVarOrDefault(rp+":cardNumber","")),card)!=0)
            continue
        endif
        if(!XRD80_ReferenceMetadataMatches(rp,formula,phaseName,phaseClass,source))
            continue
        endif
        Wave/Z rtt=$(rp+":twoTheta"),ri=$(rp+":intensity"),rh=$(rp+":h"),rk=$(rp+":k"),rl=$(rp+":l"),rd=$(rp+":d")
        if(!WaveExists(rtt) || !WaveExists(ri) || !WaveExists(rh) || !WaveExists(rk) || !WaveExists(rl) || !WaveExists(rd))
            continue
        endif
        if(XRD80_SameReferenceWave(tt,rtt) && XRD80_SameReferenceWave(intensities,ri) && XRD80_SameReferenceWave(hh,rh) && XRD80_SameReferenceWave(kk,rk) && XRD80_SameReferenceWave(ll,rl) && XRD80_SameReferenceWave(dd,rd))
            return i
        endif
    endfor
    return 0
End

Function XRD80_ReferenceMetadataMatches(rp,formula,phaseName,phaseClass,source)
    String rp,formula,phaseName,phaseClass,source
    return cmpstr(StrVarOrDefault(rp+":origin_formula",StrVarOrDefault(rp+":formula","")),formula)==0 && cmpstr(StrVarOrDefault(rp+":origin_phaseName",StrVarOrDefault(rp+":phaseName","")),phaseName)==0 && cmpstr(StrVarOrDefault(rp+":origin_phaseClass",StrVarOrDefault(rp+":phaseClass","")),phaseClass)==0 && cmpstr(StrVarOrDefault(rp+":origin_source",StrVarOrDefault(rp+":source","")),source)==0
End

Function XRD80_StampReference(rp,previous)
    String rp,previous
    String uid=StrVarOrDefault(rp+":refUID",""),revisionUID,stem,folder
    Variable revision=1,i
    String originFields="cardNumber;formula;phaseName;phaseClass;source",originField
    for(i=0;i<ItemsInList(originFields);i+=1)
        originField=StringFromList(i,originFields)
        SVAR/Z origin=$(rp+":origin_"+originField)
        if(!SVAR_Exists(origin))
            String/G $(rp+":origin_"+originField)=StrVarOrDefault(rp+":"+originField,"")
        endif
    endfor
    if(strlen(previous))
        uid=StrVarOrDefault(previous+":refUID","")
        revision=NumVarOrDefault(previous+":revision",1)+1
    endif
    if(!strlen(uid))
        uid=XRD80_NewUID("reference")
    endif
    revisionUID=XRD80_NewUID("revision")
    String/G $(rp+":refUID")=uid
    String/G $(rp+":revisionUID")=revisionUID
    String previousUID=""
    if(strlen(previous))
        previousUID=StrVarOrDefault(previous+":revisionUID","")
    endif
    String/G $(rp+":previousRevisionUID")=previousUID
    Variable/G $(rp+":revision")=revision
    Variable/G $(rp+":isCurrent")=1
    if(strlen(previous))
        Variable/G $(previous+":isCurrent")=0
        Variable/G $(previous+":enabled")=0
    endif
    folder=XRD_TypeName(StrVarOrDefault(rp+":phaseClass",""))
    if(!strlen(folder))
        folder=XRD_TypeName(StrVarOrDefault(rp+":phaseName","")+" "+StrVarOrDefault(rp+":fileName",""))
    endif
    if(!strlen(folder))
        folder="その他"
    endif
    String existingFolder=StrVarOrDefault(rp+":folder","")
    if(strlen(TrimString(existingFolder)))
        folder=existingFolder
    endif
    String/G $(rp+":folder")=folder
    stem=StrVarOrDefault(rp+":waveStem","")
    if(!strlen(stem))
        stem=StrVarOrDefault(rp+":formula","")
        if(!strlen(stem))
            stem=StrVarOrDefault(rp+":phaseClass",StrVarOrDefault(rp+":phaseName","reference"))
        endif
        stem=CleanupName(ReplaceString(" ",stem,""),0)
        stem=stem[0,15]+"_"+num2istr(NumVarOrDefault(XRD80_Library()+":referenceCount",0))
    endif
    String/G $(rp+":waveStem")=stem
    Wave tt=$(rp+":twoTheta")
    Make/O/T/N=(numpnts(tt)) $(rp+":reflectionUID")
    Wave/T reflectionUID=$(rp+":reflectionUID")
    for(i=0;i<numpnts(tt);i+=1)
        reflectionUID[i]=revisionUID+"_"+num2istr(i+1)
    endfor
    // Prefix aliases follow one canonical numeric wave, avoiding two independent masters.
    XRD80_ReferenceAlias(rp,"twoTheta","tt_"+stem)
    XRD80_ReferenceAlias(rp,"intensity","int_"+stem)
    XRD80_ReferenceAlias(rp,"d","d_"+stem)
    XRD80_ReferenceAlias(rp,"h","h_"+stem)
    XRD80_ReferenceAlias(rp,"k","k_"+stem)
    XRD80_ReferenceAlias(rp,"l","l_"+stem)
    String/G $(rp+":created")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    XRD80_RegisterObject("reference",uid,rp,"")
    XRD80_RegisterObject("referenceRevision",revisionUID,rp,"")
    NVAR libraryRevision=$(XRD80_Library()+":revision")
    libraryRevision+=1
    return 0
End

Function XRD80_ReferenceAlias(rp,sourceName,aliasName)
    String rp,sourceName,aliasName
    Wave source=$(rp+":"+sourceName)
    Duplicate/O source,$(rp+":"+aliasName)
    Wave alias=$(rp+":"+aliasName)
    SetFormula alias,GetWavesDataFolder(source,2)+"[p]"
    return 0
End

Function XRD80_ImportLegacyReferences(project)
    String project
    XRD80_InitLibrary()
    SVAR libraryHint=$(XRD80_Library()+":referenceFolderHint")
    String oldHint=StrVarOrDefault(project+":referenceFolderHint","")
    if(cmpstr(libraryHint,"未選択")==0 && strlen(oldHint) && cmpstr(oldHint,"未選択")!=0)
        libraryHint=oldHint
    endif
    String migration=project+":ReferenceMigration",source,rp
    NewDataFolder/O $migration
    Wave/Z oldMap=$(migration+":legacyToGlobal")
    Variable previous=0,n=0,i,existing,next
    if(WaveExists(oldMap))
        previous=numpnts(oldMap)
    else
        Make/D/N=0 $(migration+":legacyToGlobal")
    endif
    // Enumerate actual old Ref folders, never the synchronized compatibility count.
    do
        source=project+":References:Ref"+num2istr(n+1)
        if(!DataFolderExists(source))
            break
        endif
        n+=1
    while(1)
    Wave map=$(migration+":legacyToGlobal")
    Redimension/N=(max(n,previous)) map
    NVAR count=$(XRD80_Library()+":referenceCount")
    Variable migrated=0
    for(i=0;i<n;i+=1)
        if(map[i]>0)
            continue
        endif
        source=project+":References:Ref"+num2istr(i+1)
        Wave tt=$(source+":twoTheta"),ii=$(source+":intensity"),hh=$(source+":h"),kk=$(source+":k"),ll=$(source+":l"),dd=$(source+":d")
        existing=XRD80_FindIdenticalReference(StrVarOrDefault(source+":cardNumber",""),StrVarOrDefault(source+":formula",""),StrVarOrDefault(source+":phaseName",""),StrVarOrDefault(source+":phaseClass",""),StrVarOrDefault(source+":source",""),tt,ii,hh,kk,ll,dd)
        if(existing>0)
            map[i]=existing
            migrated+=1
            continue
        endif
        next=count+1
        rp=XRD_ReferencePath(next)
        DuplicateDataFolder $source,$rp
        count=next
        Variable/G $(rp+":enabled")=1
        String/G $(rp+":legacyOwner")=project
        Variable/G $(rp+":legacyRefIndex")=i+1
        XRD80_StampReference(rp,"")
        map[i]=next
        migrated+=1
    endfor
    String/G $(migration+":policy")="v1.2.0 exact numeric content; old folders preserved; enabled defaults ON"
    return migrated
End

Function/S XRD80_NewReferenceFiles()
    XRD80_InitLibrary()
    String lib=XRD80_Library(),hint=StrVarOrDefault(XRD80_Library()+":referenceFolderHint",""),files,unknown="",known="",name
    if(!strlen(hint) || cmpstr(hint,"未選択")==0 || XRD_RestoreReferencePath(lib)!=0)
        return ""
    endif
    files=IndexedFile(XRDReferencePath,-1,".txt")+IndexedFile(XRDReferencePath,-1,".csv")+IndexedFile(XRDReferencePath,-1,".tsv")+IndexedFile(XRDReferencePath,-1,".dat")
    Variable i,n=NumVarOrDefault(lib+":referenceCount",0)
    for(i=1;i<=n;i+=1)
        known+=StrVarOrDefault(XRD_ReferencePath(i)+":fileName","")+";"
    endfor
    for(i=0;i<ItemsInList(files);i+=1)
        name=StringFromList(i,files)
        if(WhichListItem(name,known)<0)
            unknown+=name+";"
        endif
    endfor
    return SortList(unknown)
End

Function XRD80_CheckLibraryAdditions()
    String files=XRD80_NewReferenceFiles(),lib=XRD80_Library()
    if(!strlen(files) || cmpstr(files,StrVarOrDefault(lib+":lastAdditionPrompt",""))==0)
        return 0
    endif
    String/G $(lib+":lastAdditionPrompt")=files
    DoAlert 1,num2istr(ItemsInList(files))+"件の追加参照ファイルがあります。共通ライブラリへ読み込みますか？ 取り込み後に名前・分類を編集できます。"
    if(V_flag!=1)
        return 0
    endif
    Variable first=NumVarOrDefault(lib+":referenceCount",0)+1,result=XRD_LoadReferences()
    XRD80_LibraryPanel()
    if(first<=NumVarOrDefault(lib+":referenceCount",0))
        XRD80_SelectLibraryReference(first)
    endif
    return result
End

Function XRD80_LibraryChanged()
    NVAR revision=$(XRD80_Library()+":revision")
    revision+=1
    String projects=XRD_ProjectList(),project,path,name
    Variable i,j
    XRD80_SyncReferenceCounts()
    for(i=0;i<ItemsInList(projects);i+=1)
        project=XRD100_ProjectAt(projects,i)
        XRD_RebuildReferenceTable(project)
        j=0
        do
            name=GetIndexedObjName(project+":Measurements:",4,j)
            if(!strlen(name))
                break
            endif
            path=XRD110_MeasurementPath(project,name)
            Variable/G $(path+":candidateLibraryRevision")=-1
            j+=1
        while(1)
    endfor
    XRD_InvalidateFilterCandidates()
    return 0
End

Function/S XRD80_LibraryFolders()
    String list="すべて;",folder
    Variable i,n=NumVarOrDefault(XRD80_Library()+":referenceCount",0)
    for(i=1;i<=n;i+=1)
        folder=StrVarOrDefault(XRD_ReferencePath(i)+":folder","その他")
        if(WhichListItem(folder,list)<0)
            list+=folder+";"
        endif
    endfor
    return list
End

Function XRD80_LibraryPanel()
    XRD_Init()
    XRD80_InitLibrary()
    Variable viewIndex
    for(viewIndex=1;viewIndex<=NumVarOrDefault(XRD80_Library()+":referenceCount",0);viewIndex+=1)
        XRD100_ReferenceAliases(viewIndex)
    endfor
    String ui=XRD80_Library()+":UI"
    NewDataFolder/O $ui
    String/G $(ui+":folderFilter")="すべて"
    Variable/G $(ui+":selectedIndex")=0
    Make/O/T/N=(0,6) $(ui+":table")
    Make/O/D/N=(0,6,3) $(ui+":selection")
    Make/O/W/U/N=(2,3) $(ui+":colors")
    Wave colors=$(ui+":colors")
    colors[0][]=0
    colors[1][]=38000
    Make/O/D/N=0 $(ui+":map")
    DoWindow/K XRDLibrary
    NewPanel/K=1/N=XRDLibrary/W=(30,30,1210,710) as "参照値 — Experiment共通ライブラリ"
    DefaultGUIFont/W=XRDLibrary all={"Segoe UI",12,0}
    TitleBox policy,pos={15,10},frame=0,title="使用チェックは全プロジェクトで共通です。未使用にしても過去の同定は残ります。"
    PopupMenu folder,pos={15,46},title="分類",value=XRD80_LibraryFolders(),mode=1,proc=XRD80_LibraryFolderAction
    Button importReferences,pos={300,42},size={180,30},title="参照ファイルを追加…",proc=XRD80_LibraryButton
    Button scanReferences,pos={495,42},size={195,30},title="元フォルダの追加を確認",proc=XRD80_LibraryButton
    ListBox library,pos={15,88},size={1135,240},mode=1,listWave=$(ui+":table"),selWave=$(ui+":selection"),colorWave=colors,widths={55,200,160,145,240,240},proc=XRD80_LibraryAction
    TitleBox detailHelp,pos={15,340},frame=0,title="行を選択すると詳細を編集できます。回折値の変更は新しい版として保存し、既存の同定は旧版を保持します。"
    XRD80_RefreshLibraryList()
    Wave visibleMap=$(ui+":map")
    if(numpnts(visibleMap)>0)
        XRD80_SelectLibraryReference(visibleMap[0])
    endif
    ModifyPanel/W=XRDLibrary fixedSize=0
    SetWindow XRDLibrary hook(layout)=XRD80_LibraryHook
    SetWindow XRDLibrary hook(wheel110)=XRD110_WheelHook
    XRD80_LibraryLayout()
    return 0
End

Function XRD80_RefreshLibraryList()
    String ui=XRD80_Library()+":UI",rp,folder=StrVarOrDefault(XRD80_Library()+":UI:folderFilter","すべて")
    Wave/T table=$(ui+":table")
    Wave selection=$(ui+":selection"),map=$(ui+":map")
    Variable n=NumVarOrDefault(XRD80_Library()+":referenceCount",0),i,row=0,current
    Redimension/N=(n,6) table
    Redimension/N=(n,6,3) selection
    SetDimLabel 2,1,foreColors,selection
    Redimension/N=(n) map
    selection=0
    for(i=1;i<=n;i+=1)
        rp=XRD_ReferencePath(i)
        current=NumVarOrDefault(rp+":isCurrent",1)
        if(!current || (cmpstr(folder,"すべて")!=0 && cmpstr(folder,StrVarOrDefault(rp+":folder","その他"))!=0))
            continue
        endif
        map[row]=i
        table[row][0]=""
        table[row][1]=StrVarOrDefault(rp+":displayOverride","")
        if(!strlen(table[row][1]))
            table[row][1]=XRD_PhaseLabel(i)
        endif
        table[row][2]=StrVarOrDefault(rp+":cardNumber","")
        table[row][3]=StrVarOrDefault(rp+":folder","その他")
        table[row][4]=SelectString(XRD80_LibraryReferenceEnabled(i),"未使用（保存済み）","使用中")
        table[row][5]=StrVarOrDefault(rp+":phaseName","")
        selection[row][0][0]=32+16*XRD80_LibraryReferenceEnabled(i)
        selection[row][][1]=!XRD80_LibraryReferenceEnabled(i)
        row+=1
    endfor
    Redimension/N=(row,6) table
    Redimension/N=(row,6,3) selection
    Redimension/N=(row) map
    SetDimLabel 1,0,'使用',table
    SetDimLabel 1,1,'表示名・相',table
    SetDimLabel 1,2,'PDF番号',table
    SetDimLabel 1,3,'分類',table
    SetDimLabel 1,4,'状態',table
    SetDimLabel 1,5,'物質名',table
    if(WinType("XRDLibrary"))
        ControlUpdate/W=XRDLibrary library
    endif
    return 0
End

Function XRD80_LibraryAction(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    String ui=XRD80_Library()+":UI"
    Wave map=$(ui+":map"),selection=$(ui+":selection")
    if(lba.row<0 || lba.row>=numpnts(map))
        return 0
    endif
    Variable index=map[lba.row]
    if(lba.eventCode==13 && lba.col==0)
        Variable/G $(XRD_ReferencePath(index)+":enabled")=(selection[lba.row][0][0] & 16)!=0
        XRD80_LibraryChanged()
        Wave/T table=$(ui+":table")
        table[lba.row][4]=SelectString(XRD80_LibraryReferenceEnabled(index),"未使用（保存済み）","使用中")
        selection[lba.row][][1]=!XRD80_LibraryReferenceEnabled(index)
    elseif(lba.eventCode==4 || lba.eventCode==3)
        // Defer rebuilding detail controls until the ListBox event returns.
        Execute/P/Q "XRD80_SelectLibraryReference("+num2istr(index)+")"
    endif
    return 0
End

Function XRD80_LibraryFolderAction(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        String/G $(XRD80_Library()+":UI:folderFilter")=pa.popStr
        XRD80_RefreshLibraryList()
    endif
    return 0
End

Function XRD80_SelectLibraryReference(index)
    Variable index
    if(!WinType("XRDLibrary") || !DataFolderExists(XRD_ReferencePath(index)))
        return -1
    endif
    String rp=XRD_ReferencePath(index),ui=XRD80_Library()+":UI",draft=ui+":Draft",field,fields="displayOverride;phaseName;formula;phaseClass;cardNumber;source;folder"
    NewDataFolder/O $draft
    Variable/G $(ui+":selectedIndex")=index
    Variable i
    for(i=0;i<ItemsInList(fields);i+=1)
        field=StringFromList(i,fields)
        String/G $(draft+":"+field)=StrVarOrDefault(rp+":"+field,"")
    endfor
    Duplicate/O $(rp+":twoTheta"),$(draft+":twoTheta")
    Duplicate/O $(rp+":intensity"),$(draft+":intensity")
    Duplicate/O $(rp+":d"),$(draft+":d")
    Duplicate/O $(rp+":h"),$(draft+":h")
    Duplicate/O $(rp+":k"),$(draft+":k")
    Duplicate/O $(rp+":l"),$(draft+":l")
    Variable/G $(draft+":numericTextActive82")=0
    DoWindow/K XRDLibraryNumbers
    SetVariable displayName,win=XRDLibrary,pos={15,375},size={535,24},title="表示名",value=$(draft+":displayOverride")
    SetVariable materialName,win=XRDLibrary,pos={580,375},size={565,24},title="物質名",value=$(draft+":phaseName")
    SetVariable formula,win=XRDLibrary,pos={15,410},size={535,24},title="化学式",value=$(draft+":formula")
    SetVariable phase,win=XRDLibrary,pos={580,410},size={565,24},title="相名 / type",value=$(draft+":phaseClass")
    SetVariable card,win=XRDLibrary,pos={15,445},size={535,24},title="PDF番号",value=$(draft+":cardNumber")
    SetVariable category,win=XRDLibrary,pos={580,445},size={565,24},title="所属分類",value=$(draft+":folder")
    SetVariable source,win=XRDLibrary,pos={15,480},size={1130,24},title="参照元",value=$(draft+":source")
    TitleBox file,win=XRDLibrary,pos={15,515},frame=0,title="元ファイル: "+StrVarOrDefault(rp+":fileName","")+" / 版 "+num2istr(NumVarOrDefault(rp+":revision",1))
    Button numeric,win=XRDLibrary,pos={15,550},size={250,32},title="回折角・強度・d・hklを編集",proc=XRD80_LibraryButton
    Button preview,win=XRDLibrary,pos={285,550},size={230,32},title="回折パターンを表示",proc=XRD80_LibraryButton
    Button save,win=XRDLibrary,pos={540,550},size={300,32},title="変更を新しい版として保存",proc=XRD80_LibraryButton
    TitleBox revisionHelp,win=XRDLibrary,pos={15,605},frame=0,title="詳細の編集は保存まで反映しません。保存すると過去の同定を保持して新しい版を作ります。\r使用チェックは即時に全プロジェクトへ反映します。過去の同定は変更しません。"
    XRD80_LibraryLayout()
    return 0
End

Function XRD80_LibraryHook(s)
    STRUCT WMWinHookStruct &s
    if(s.eventCode==6 && cmpstr(GetUserData("XRDLibrary","","layoutPending"),"1")!=0)
        SetWindow XRDLibrary userdata(layoutPending)="1"
        Execute/P/Q "XRD80_LibraryLayout()"
    endif
    return 0
End

Function XRD80_LibraryLayout()
    if(!WinType("XRDLibrary"))
        return 0
    endif
    SetWindow XRDLibrary userdata(layoutPending)="1"
    GetWindow XRDLibrary wsizeForControls
    Variable w=V_right,h=V_bottom,half=(w-45)/2,top=max(215,h-345),factor=PanelResolution("XRDLibrary")/ScreenResolution
    SetWindow XRDLibrary sizeLimit={950*factor,600*factor,inf,inf}
    ListBox library,win=XRDLibrary,size={w-30,top-115}
    TitleBox detailHelp,win=XRDLibrary,pos={15,top}
    ControlInfo/W=XRDLibrary displayName
    if(V_flag!=0)
        SetVariable displayName,win=XRDLibrary,pos={15,top+30},size={half,24}
        SetVariable materialName,win=XRDLibrary,pos={half+30,top+30},size={half,24}
        SetVariable formula,win=XRDLibrary,pos={15,top+65},size={half,24}
        SetVariable phase,win=XRDLibrary,pos={half+30,top+65},size={half,24}
        SetVariable card,win=XRDLibrary,pos={15,top+100},size={half,24}
        SetVariable category,win=XRDLibrary,pos={half+30,top+100},size={half,24}
        SetVariable source,win=XRDLibrary,pos={15,top+135},size={w-30,24}
        TitleBox file,win=XRDLibrary,pos={15,top+170}
        Button numeric,win=XRDLibrary,pos={15,top+205}
        Button preview,win=XRDLibrary,pos={285,top+205}
        Button save,win=XRDLibrary,pos={540,top+205}
        TitleBox revisionHelp,win=XRDLibrary,pos={15,top+250},size={w-30,55}
    endif
    SetWindow XRDLibrary userdata(layoutPending)="0"
    return 0
End

Function XRD80_ValidateReferenceDraft(draft)
    String draft
    Wave tt=$(draft+":twoTheta"),ii=$(draft+":intensity"),hh=$(draft+":h"),kk=$(draft+":k"),ll=$(draft+":l"),dd=$(draft+":d")
    Variable n=numpnts(tt),i
    if(n<1 || numpnts(ii)!=n || numpnts(hh)!=n || numpnts(kk)!=n || numpnts(ll)!=n || numpnts(dd)!=n)
        return -1
    endif
    for(i=0;i<n;i+=1)
        if(numtype(tt[i]+ii[i])!=0 || tt[i]<=0 || tt[i]>=180 || ii[i]<0 || !XRD82_ValidIndex(hh[i]) || !XRD82_ValidIndex(kk[i]) || !XRD82_ValidIndex(ll[i]) || hh[i]^2+kk[i]^2+ll[i]^2==0)
            return -2
        endif
        if(numtype(dd[i])!=2 && (numtype(dd[i])!=0 || dd[i]<=0))
            return -3
        endif
    endfor
    return 0
End

Function XRD80_SaveReferenceDraft()
    String ui=XRD80_Library()+":UI",draft=ui+":Draft",previous=XRD_ReferencePath(NumVarOrDefault(ui+":selectedIndex",0)),rp,field
    if(XRD82_CommitNumericText(draft)!=0)
        return -1
    endif
    if(!DataFolderExists(previous) || XRD80_ValidateReferenceDraft(draft)!=0)
        return -1
    endif
    if(!NumVarOrDefault(previous+":isCurrent",1))
        // Never branch from an old revision and leave two current revisions enabled.
        return -2
    endif
    NVAR count=$(XRD80_Library()+":referenceCount")
    Variable next=count+1,enabled=NumVarOrDefault(previous+":enabled",1),i
    rp=XRD_ReferencePath(next)
    DuplicateDataFolder $previous,$rp
    String fields="displayOverride;phaseName;formula;phaseClass;cardNumber;source;folder"
    for(i=0;i<ItemsInList(fields);i+=1)
        field=StringFromList(i,fields)
        String/G $(rp+":"+field)=StrVarOrDefault(draft+":"+field,"")
    endfor
    fields="twoTheta;intensity;d;h;k;l"
    for(i=0;i<ItemsInList(fields);i+=1)
        field=StringFromList(i,fields)
        Duplicate/O $(draft+":"+field),$(rp+":"+field)
    endfor
    Wave tt=$(rp+":twoTheta"),ii=$(rp+":intensity"),hh=$(rp+":h"),kk=$(rp+":k"),ll=$(rp+":l"),dd=$(rp+":d")
    Sort tt,tt,ii,hh,kk,ll,dd
    WaveStats/Q ii
    Variable/G $(rp+":intensityMaximum")=V_max
    Variable/G $(rp+":enabled")=enabled
    count=next
    XRD80_StampReference(rp,previous)
    XRD100_ReferenceAliases(next)
    XRD80_LibraryChanged()
    return next
End

Function XRD80_PreviewLibraryReference(index)
    Variable index
    String rp=XRD_ReferencePath(index),preview=XRD80_Library()+":Preview"
    if(!DataFolderExists(rp))
        return -1
    endif
    NewDataFolder/O $preview
    Duplicate/O $(rp+":twoTheta"),$(preview+":tt")
    Duplicate/O $(rp+":intensity"),$(preview+":intensity")
    Wave yy=$(preview+":intensity"),xx=$(preview+":tt")
    WaveStats/Q yy
    if(V_max>0)
        yy=100*yy/V_max
    endif
    DoWindow/K XRDLibraryPattern
    Display/K=1/N=XRDLibraryPattern/W=(50,70,850,470) yy vs xx as "参照パターン — "+XRD_PhaseLabel(index)
    ModifyGraph mode=1,rgb=(50000,5000,5000),lsize=1.5,noLabel(left)=1
    Label bottom "2\\f02θ\\f00 (deg.)"
    Label left "Relative intensity (%)"
    SetAxis left 0,110
    return 0
End

Function XRD80_CheckForNewReferences()
    XRD80_InitLibrary()
    String lib=XRD80_Library(),files,unknown="",name,known=""
    XRD_RestoreReferencePath(lib)
    PathInfo XRDReferencePath
    if(!V_flag)
        DoAlert 0,"元フォルダを確認できません。Experiment内の参照データはそのまま使用できます。追加する場合は『参照ファイルを追加』を押してください。"
        return -1
    endif
    files=IndexedFile(XRDReferencePath,-1,".txt")+IndexedFile(XRDReferencePath,-1,".csv")+IndexedFile(XRDReferencePath,-1,".tsv")+IndexedFile(XRDReferencePath,-1,".dat")
    Variable i,n=NumVarOrDefault(lib+":referenceCount",0)
    for(i=1;i<=n;i+=1)
        known+=StrVarOrDefault(XRD_ReferencePath(i)+":fileName","")+";"
    endfor
    for(i=0;i<ItemsInList(files);i+=1)
        name=StringFromList(i,files)
        if(WhichListItem(name,known)<0)
            unknown+=name+";"
        endif
    endfor
    if(!ItemsInList(unknown))
        DoAlert 0,"新しいファイル名は見つかりませんでした。同名ファイルの変更を取り込む場合は『参照ファイルを追加』で再読込してください。"
        return 0
    endif
    DoAlert 1,num2istr(ItemsInList(unknown))+"件の追加ファイルがあります。共通ライブラリへ読み込みますか？ 読み込み後に名前を変更できます。"
    if(V_flag!=1)
        return 0
    endif
    return XRD_LoadReferences()
End

Function XRD80_LibraryButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String ui=XRD80_Library()+":UI",draft=ui+":Draft"
    Variable index=NumVarOrDefault(ui+":selectedIndex",0),result
    strswitch(ba.ctrlName)
        case "importReferences":
            Execute/P/Q "XRD_ChooseReference()"
            break
        case "scanReferences":
            Execute/P/Q "XRD80_CheckForNewReferences()"
            break
        case "preview":
            XRD80_PreviewLibraryReference(index)
            break
        case "numeric":
            XRD82_OpenNumericDraft(draft)
            break
        case "save":
            result=XRD80_SaveReferenceDraft()
            if(result<1)
                DoAlert 0,"回折値を確認してください。角度は0より大きく180未満、強度は非負、既知hklは整数（000以外）です。指数不明は「hkl不明」「-」「None」、dの欠損は「欠損」と入力できます。"
            else
                XRD80_RefreshLibraryList()
                XRD80_SelectLibraryReference(result)
                PopupMenu folder,win=XRDLibrary,value=XRD80_LibraryFolders()
            endif
            break
    endswitch
    return 0
End
