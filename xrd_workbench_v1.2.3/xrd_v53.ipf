#pragma rtGlobals=3
// XRD Workbench v1.2.0: persistent, project-local reference-family selection.
Function/S XRD_TypeFamilies()
    return "Z-type;X-type;M-type;QS-type;W-type;T-type;Y-type;U-type"
End

Function XRD_TypeSettings(project)
    String project
    XRD_EnsureNumeric(project+":candidateRadius",0.6)
    XRD_EnsureNumeric(project+":typeSelectionRevision",0)
    NewDataFolder/O $(project+":TypeSelection")
    Wave/Z modes=$(project+":TypeSelection:modes")
    if(!WaveExists(modes))
        Make/D/N=8 $(project+":TypeSelection:modes")=0,$(project+":TypeSelection:singleRef")=0
    endif
    Wave/Z configured=$(project+":TypeSelection:configured")
    if(!WaveExists(configured))
        Make/D/N=8 $(project+":TypeSelection:configured")=0
    endif
End

Function XRD_TypeCardAllowed(index)
    Variable index
    return XRD80_LibraryReferenceEnabled(index)
End
Function XRD_TypePanel()
    String project=XRD80_Library()
    XRD_TypeSettings(project)
    XRD_UISettings()
    NewDataFolder/O root:Packages:XRDWorkbench:UI:TypeDraft
    String draft="root:Packages:XRDWorkbench:UI:TypeDraft"
    Variable n=NumVarOrDefault(project+":referenceCount",0),i
    Duplicate/O $(project+":TypeSelection:modes"),$(draft+":modes")
    Duplicate/O $(project+":TypeSelection:singleRef"),$(draft+":singleRef")
    Duplicate/O $(project+":TypeSelection:configured"),$(draft+":configured")
    Make/O/D/N=(n) $(draft+":enabled")=1
    Wave enabled=$(draft+":enabled")
    for(i=0;i<n;i+=1)
        enabled[i]=XRD_TypeCardAllowed(i+1) && XRD_MaterialAllowed(i+1)
    endfor
    Variable/G $(draft+":family")=3
    String/G $(draft+":project")=project
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDTypeCards")
    DoWindow/K XRDTypeCards
    NewPanel/FLT=1/K=1/N=XRDTypeCards/W=(40,40,960,575) as "typeごとに使用する参照カードを選択"
    DefaultGUIFont/W=XRDTypeCards all={"Segoe UI",12,0}
    PopupMenu family,pos={15,15},title="type",mode=4,value=XRD_TypeFamilies(),proc=XRD_TypeFamilyPopup
    PopupMenu useMode,pos={300,15},title="使い方",mode=1,value="複数件を使う;1件だけ使う",proc=XRD_TypeModePopup
    TitleBox note,pos={15,55},frame=0,title="チェックしたカードを同定候補に使います。typeを切り替えて複数の種類を設定できます。\r1件モードではチェックしたカード1件だけ。複数件モードではチェックした複数カードを使います。"
    Make/O/T/N=(0,5) $(draft+":table")
    Make/O/D/N=(0,5) $(draft+":selection")
    Make/O/D/N=0 $(draft+":map")
    ListBox cards,pos={15,120},size={885,285},mode=1,listWave=$(draft+":table"),selWave=$(draft+":selection"),widths={55,165,190,280,280},proc=XRD_TypeCardAction
    Button allCards,pos={15,420},size={180,30},title="このtypeをすべて選択",proc=XRD_TypeButton
    Button noCards,pos={210,420},size={180,30},title="このtypeをすべて外す",proc=XRD_TypeButton
    Button applyTypes,pos={440,465},size={225,32},title="選択を候補に反映して閉じる",proc=XRD_TypeButton
    Button cancelTypes,pos={680,465},size={210,32},title="変更せず閉じる",proc=XRD_TypeButton
    TitleBox result,pos={15,465},frame=0,title="既存の同定は残します。\r候補の選択だけを変更します。"
    XRD_TypeDraftTable()
    XRD123_FinishPanel("XRDTypeCards",panelState123)
    return 0
End

Function XRD_TypeDraftTable()
    String draft="root:Packages:XRDWorkbench:UI:TypeDraft",family
    NVAR f=$(draft+":family")
    SVAR project=$(draft+":project")
    Wave modes=$(draft+":modes"),single=$(draft+":singleRef"),enabled=$(draft+":enabled"),map=$(draft+":map"),selection=$(draft+":selection")
    Wave/T table=$(draft+":table")
    family=StringFromList(f,XRD_TypeFamilies())
    Variable i,n=0,index
    for(i=0;i<numpnts(enabled);i+=1)
        if(cmpstr(XRD_ReferenceType(i+1),family)==0)
            n+=1
        endif
    endfor
    Redimension/N=(n,5) table,selection
    Redimension/N=(n) map
    selection=0;n=0
    for(i=0;i<numpnts(enabled);i+=1)
        index=i+1
        if(cmpstr(XRD_ReferenceType(index),family)!=0)
            continue
        endif
        String rp=XRD_ReferencePath(index)
        map[n]=index
        table[n][0]=""
        table[n][1]=StrVarOrDefault(rp+":cardNumber","")
        table[n][2]=StrVarOrDefault(rp+":formula","")
        table[n][3]=StrVarOrDefault(rp+":phaseName","")
        table[n][4]=StrVarOrDefault(rp+":fileName","")
        selection[n][0]=32+16*SelectNumber(modes[f]==1,enabled[i]!=0,single[f]==index)
        n+=1
    endfor
    SetDimLabel 1,0,'使用',table
    SetDimLabel 1,1,Card,table
    SetDimLabel 1,2,'化学式',table
    SetDimLabel 1,3,'参照名',table
    SetDimLabel 1,4,'ファイル',table
    PopupMenu useMode,win=XRDTypeCards,mode=(modes[f]+1)
    ControlUpdate/W=XRDTypeCards cards
    return 0
End

Function XRD_TypeFamilyPopup(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        NVAR family=root:Packages:XRDWorkbench:UI:TypeDraft:family
        family=pa.popNum-1
        XRD_TypeDraftTable()
    endif
    return 0
End

Function XRD_TypeModePopup(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2)
        return 0
    endif
    String draft="root:Packages:XRDWorkbench:UI:TypeDraft"
    NVAR f=$(draft+":family")
    Wave modes=$(draft+":modes"),single=$(draft+":singleRef"),map=$(draft+":map"),enabled=$(draft+":enabled")
    Variable i
    Wave configured=$(draft+":configured")
    configured[f]=1
    modes[f]=pa.popNum-1
    if(modes[f]==1)
        single[f]=0
        for(i=0;i<numpnts(map);i+=1)
            if(enabled[map[i]-1])
                single[f]=map[i]
                break
            endif
        endfor
        if(single[f]==0 && numpnts(map)>0)
            single[f]=map[0]
        endif
    else
        // Carry the single selection into multiple mode; adding more is explicit.
        for(i=0;i<numpnts(map);i+=1)
            enabled[map[i]-1]=map[i]==single[f]
        endfor
    endif
    XRD_TypeDraftTable()
    return 0
End

Function XRD_TypeCardAction(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode!=13 || lba.col!=0)
        return 0
    endif
    String draft="root:Packages:XRDWorkbench:UI:TypeDraft"
    NVAR f=$(draft+":family")
    Wave map=$(draft+":map"),selection=$(draft+":selection"),enabled=$(draft+":enabled"),modes=$(draft+":modes"),single=$(draft+":singleRef")
    if(lba.row<0 || lba.row>=numpnts(map))
        return 0
    endif
    Wave configured=$(draft+":configured")
    configured[f]=1
    Variable checked=(selection[lba.row][0] & 16)!=0,i
    if(modes[f]==1)
        single[f]=SelectNumber(checked,0,map[lba.row])
        // Mutate backing selection only; do not recreate the ListBox in callback.
        for(i=0;i<numpnts(map);i+=1)
            selection[i][0]=32+16*(map[i]==single[f])
        endfor
    else
        enabled[map[lba.row]-1]=checked
    endif
    return 0
End

Function XRD_ApplyTypeDraft()
    String draft="root:Packages:XRDWorkbench:UI:TypeDraft",project=XRD80_Library()
    SVAR target=$(draft+":project")
    if(cmpstr(target,project)!=0)
        return -1
    endif
    Wave enabled=$(draft+":enabled"),modes=$(draft+":modes"),single=$(draft+":singleRef")
    if(numpnts(enabled)!=NumVarOrDefault(project+":referenceCount",0))
        return -1
    endif
    Duplicate/O modes,$(project+":TypeSelection:modes")
    Duplicate/O single,$(project+":TypeSelection:singleRef")
    Duplicate/O $(draft+":configured"),$(project+":TypeSelection:configured")
    Variable i,f
    Wave configured=$(project+":TypeSelection:configured")
    for(i=0;i<numpnts(enabled);i+=1)
        Variable use=enabled[i]
        f=WhichListItem(XRD_ReferenceType(i+1),XRD_TypeFamilies())
        if(f>=0 && configured[f] && modes[f]==1)
            use=single[f]==i+1
        endif
        Variable/G $(XRD_ReferencePath(i+1)+":enabled")=use
    endfor
    NVAR revision=$(project+":typeSelectionRevision")
    revision+=1
    XRD_EnsureNumeric(project+":revision",0)
    Variable/G $(project+":revision")=NumVarOrDefault(project+":revision",0)+1
    XRD_InvalidateFilterCandidates()
    return 0
End

Function XRD_TypeButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String draft="root:Packages:XRDWorkbench:UI:TypeDraft"
    strswitch(ba.ctrlName)
        case "typeCards":
            Execute/P/Q "XRD_TypePanel()"
            break
        case "cancelTypes":
            DoWindow/K XRDTypeCards
            break
        case "applyTypes":
            if(XRD_ApplyTypeDraft()==0)
                DoWindow/K XRDTypeCards
                Execute/P/Q "XRD_Panel()"
            else
                DoAlert 0,"参照データまたはプロジェクトが変わりました。画面を開き直してください。"
            endif
            break
        case "allCards":
        case "noCards":
            Wave map=$(draft+":map"),enabled=$(draft+":enabled"),modes=$(draft+":modes"),single=$(draft+":singleRef")
            NVAR f=$(draft+":family")
            Wave configured=$(draft+":configured")
            configured[f]=1
            Variable i,value=cmpstr(ba.ctrlName,"allCards")==0
            if(value)
                modes[f]=0
            else
                single[f]=0
            endif
            for(i=0;i<numpnts(map);i+=1)
                enabled[map[i]-1]=value
            endfor
            XRD_TypeDraftTable()
            break
    endswitch
    return 0
End
