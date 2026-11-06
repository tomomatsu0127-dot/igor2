#pragma rtGlobals=3
// v1.2.6: ordered comparison draft and readable live display waves.
Function/S XRD126_Draft()
    String base=XRD_PlotRoot()+":CompareUI"
    return base
End

Function XRD126_ComparePanel()
    XRD_PlotSelectionTable(0)
    String base=XRD126_Draft(),settings=XRD120_CompareSettings(),selected=XRD_ComparePaths(),state=XRD123_PanelState("XRDCompareSelection")
    Wave/T paths=$(base+":paths")
    Wave flags=$(base+":flags")
    String/G $(base+":settings126")=settings
    Make/O/T/N=(ItemsInList(selected)) $(base+":order126")
    Wave/T order=$(base+":order126")
    Variable i
    for(i=0;i<numpnts(order);i+=1)
        order[i]=StringFromList(i,selected)
    endfor
    Variable/G $(base+":spacing126")=NumVarOrDefault(settings+":spacing126",135)
    Variable/G $(base+":references126")=NumVarOrDefault(settings+":references126",1)
    Variable/G $(base+":peaks126")=NumVarOrDefault(settings+":peaks126",1)
    Variable/G $(base+":phases126")=NumVarOrDefault(settings+":phases126",1)
    KillWindow/Z XRDCompareSelection
    XRD126_SyncDraft()
    PauseUpdate; Silent 1
    NewPanel/FLT=1/FLTH=1/N=XRDCompareSelection/K=1/W=(55,55,1085,675) as "比較する試料の追加・除外と表示設定"
    ModifyPanel/W=XRDCompareSelection fixedSize=0
    DefaultGUIFont all={"Segoe UI",12,0}
    TitleBox help,pos={15,12},frame=0,title="左で試料を追加。右で除外・並べ替えができます。変更は「比較図に反映」で確定します。"
    TitleBox sources,pos={15,46},frame=0,title="全プロジェクト（プロジェクト名を押して展開）"
    TitleBox selected,pos={530,46},frame=0,title="比較に表示する試料（上からの順番）"
    String tree=XRD110_TreeBase(2)
    ListBox samples,pos={15,75},size={495,360},mode=1,listWave=$(tree+":table"),selWave=$(tree+":flags"),widths={35,315,125},proc=XRD126_CompareList
    ListBox selected126,pos={530,75},size={480,285},mode=1,listWave=$(base+":orderTable126"),widths={285,175}
    Button remove126,pos={530,372},size={155,28},title="選択した試料を除外",proc=XRD126_Button
    Button up126,pos={695,372},size={150,28},title="上へ移動",proc=XRD126_Button
    Button down126,pos={855,372},size={155,28},title="下へ移動",proc=XRD126_Button
    Button clear126,pos={530,410},size={155,28},title="すべて除外",proc=XRD126_Button
    TitleBox count126,pos={700,417},frame=0,title=num2istr(numpnts(order))+" 試料"
    GroupBox display126,pos={15,455},size={995,80},title="比較図の表示"
    SetVariable spacing126,pos={30,484},size={200,22},title="試料間の間隔",limits={20,1000,5},value=$(base+":spacing126")
    CheckBox references126,pos={270,485},title="参照線",variable=$(base+":references126")
    CheckBox phases126,pos={420,485},title="同定マーク",variable=$(base+":phases126")
    CheckBox peaks126,pos={600,485},title="未同定ピーク",variable=$(base+":peaks126")
    Button apply126,pos={530,558},size={300,32},title="比較図に反映",proc=XRD126_Button
    Button cancel126,pos={845,558},size={165,32},title="キャンセル",proc=XRD126_Button
    SetWindow XRDCompareSelection hook(wheel110)=XRD110_WheelHook
    SetWindow XRDCompareSelection hook(resize126)=XRD126_ResizeHook
    SetWindow XRDCompareSelection sizeLimit={900,540,inf,inf}
    XRD123_FinishPanel("XRDCompareSelection",state)
    XRD126_Layout()
    return 0
End

Function XRD126_ResizeHook(s)
    STRUCT WMWinHookStruct &s
    if(s.eventCode==6)
        XRD126_Layout()
    endif
    return 0
End

Function XRD126_Layout()
    if(!WinType("XRDCompareSelection"))
        return 0
    endif
    GetWindow XRDCompareSelection wsizeForControls
    Variable width=V_right,height=V_bottom,col=(width-45)/2,right=30+col,body=height-260
    TitleBox help,win=XRDCompareSelection,size={width-30,32},fixedSize=1
    TitleBox selected,win=XRDCompareSelection,pos={right,46}
    ListBox samples,win=XRDCompareSelection,size={col,body},widths={35,col-175,120}
    ListBox selected126,win=XRDCompareSelection,pos={right,75},size={col,body-75},widths={col*0.6,col*0.36}
    Button remove126,win=XRDCompareSelection,pos={right,body+12},size={col*0.33-5,28}
    Button up126,win=XRDCompareSelection,pos={right+col*0.34,body+12},size={col*0.33-5,28}
    Button down126,win=XRDCompareSelection,pos={right+col*0.68,body+12},size={col*0.32,28}
    Button clear126,win=XRDCompareSelection,pos={right,body+50},size={col*0.33-5,28}
    TitleBox count126,win=XRDCompareSelection,pos={right+col*0.36,body+55}
    GroupBox display126,win=XRDCompareSelection,pos={15,height-165},size={width-30,80}
    SetVariable spacing126,win=XRDCompareSelection,pos={30,height-136}
    CheckBox references126,win=XRDCompareSelection,pos={270,height-135}
    CheckBox phases126,win=XRDCompareSelection,pos={420,height-135}
    CheckBox peaks126,win=XRDCompareSelection,pos={600,height-135}
    Button apply126,win=XRDCompareSelection,pos={right,height-62},size={col*0.62,32}
    Button cancel126,win=XRDCompareSelection,pos={right+col*0.65,height-62},size={col*0.35,32}
    return 0
End

Function XRD126_SyncDraft()
    String base=XRD126_Draft()
    Wave/T paths=$(base+":paths"),order=$(base+":order126"),labels=$(base+":labels")
    Wave flags=$(base+":flags")
    Variable i,j
    flags[][0]=32
    Make/O/T/N=(numpnts(order),2) $(base+":orderTable126")
    Wave/T table=$(base+":orderTable126")
    for(i=0;i<numpnts(order);i+=1)
        table[i][0]=XRD110_SampleLabel(order[i])
        table[i][1]=XRD_ProjectDisplayName(XRD_PlotOwner(order[i]))
        for(j=0;j<numpnts(paths);j+=1)
            if(cmpstr(paths[j],order[i])==0)
                flags[j][0]=48
            endif
        endfor
    endfor
    SetDimLabel 1,0,'試料',table
    SetDimLabel 1,1,'プロジェクト',table
    XRD110_TreeBuild(2)
    if(WinType("XRDCompareSelection"))
        ControlUpdate/W=XRDCompareSelection samples
        ControlUpdate/W=XRDCompareSelection selected126
        TitleBox count126,win=XRDCompareSelection,title=num2istr(numpnts(order))+" 試料"
    endif
    return 0
End

Function XRD126_CompareList(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(!((lba.eventCode==4 && lba.col!=0) || lba.eventCode==13))
        return 0
    endif
    Variable source=XRD110_CheckTree(2,lba.row),i,n
    if(source<0)
        return 0
    endif
    String base=XRD126_Draft()
    Wave/T paths=$(base+":paths"),order=$(base+":order126")
    Wave flags=$(base+":flags")
    n=numpnts(order)
    for(i=0;i<n;i+=1)
        if(cmpstr(order[i],paths[source])==0)
            break
        endif
    endfor
    if((flags[source][0] & 16) && i==n)
        Redimension/N=(n+1) order
        order[n]=paths[source]
    elseif(!(flags[source][0] & 16) && i<n)
        DeletePoints i,1,order
    endif
    XRD126_SyncDraft()
    return 0
End

Function XRD126_EditOrder(action,row)
    String action
    Variable row
    Wave/T order=$(XRD126_Draft()+":order126")
    Variable n=numpnts(order),target=row
    String tmp
    if(cmpstr(action,"clear126")==0)
        Redimension/N=0 order
    elseif(row>=0 && row<n)
        if(cmpstr(action,"remove126")==0)
            DeletePoints row,1,order
            target=min(row,n-2)
        else
            target=row+SelectNumber(cmpstr(action,"up126")==0,1,-1)
            if(target>=0 && target<n)
                tmp=order[target];order[target]=order[row];order[row]=tmp
            else
                target=row
            endif
        endif
    endif
    XRD126_SyncDraft()
    if(WinType("XRDCompareSelection"))
        ListBox selected126,win=XRDCompareSelection,selRow=target
    endif
    return 0
End

Function XRD126_Apply()
    String base=XRD126_Draft(),settings=StrVarOrDefault(base+":settings126","")
    if(!strlen(settings) || !DataFolderExists(settings))
        return -1
    endif
    Wave/T order=$(base+":order126")
    Make/O/T/N=(numpnts(order)) $(settings+":uids")
    Wave/T uids=$(settings+":uids")
    Variable i,spacing=NumVarOrDefault(base+":spacing126",135)
    if(numtype(spacing)!=0)
        spacing=135
    endif
    for(i=0;i<numpnts(order);i+=1)
        uids[i]=XRD80_MeasurementUID(order[i])
    endfor
    Variable/G $(settings+":spacing126")=max(20,min(1000,spacing))
    Variable/G $(settings+":references126")=NumVarOrDefault(base+":references126",1)!=0
    Variable/G $(settings+":peaks126")=NumVarOrDefault(base+":peaks126",1)!=0
    Variable/G $(settings+":phases126")=NumVarOrDefault(base+":phases126",1)!=0
    KillWindow/Z XRDCompareSelection
    XRD_RequestLive()
    Execute/P/Q "XRD_UpdateSideCompare()"
    return 0
End

Function XRD126_Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(cmpstr(ba.ctrlName,"cancel126")==0)
        KillWindow/Z XRDCompareSelection
    elseif(cmpstr(ba.ctrlName,"apply126")==0)
        XRD126_Apply()
    else
        ControlInfo/W=XRDCompareSelection selected126
        XRD126_EditOrder(ba.ctrlName,V_value)
    endif
    return 0
End

Function/S XRD126_Source(data,role,fallback)
    String data,role,fallback
    String alias=XRD100_ExistingAlias(XRD_PlotOwner(data),XRD80_MeasurementUID(data),role)
    if(strlen(alias) && WaveExists($alias))
        return alias
    endif
    return data+fallback
End

Function/S XRD126_Name(data,ref,suffix)
    String data,suffix
    Variable ref
    String role="int_norm",name,stem=XRD100_Stem(data,XRD_ProjectDisplayName(XRD_PlotOwner(data)))
    if(ref>0)
        role="int_R"+num2istr(ref)
    endif
    String alias=XRD100_ExistingAlias(XRD_PlotOwner(data),XRD80_MeasurementUID(data),role)
    if(strlen(alias) && WaveExists($alias))
        Wave w=$alias
        name=NameOfWave(w)
    else
        if(!strlen(stem))
            stem=XRD110_SampleLabel(data)+"_"+XRD_ProjectDisplayName(XRD_PlotOwner(data))
        endif
        name="int_"+stem
        if(ref>0)
            name="int_"+XRD_PhaseLabel(ref)+"_"+stem
        endif
    endif
    // Preserve room for a role and card discriminator even for 255-byte aliases.
    return CleanupName(name,1,200)+suffix
End

Function/S XRD126_Trace(win,name)
    String win,name
    String digits="₀;₁;₂;₃;₄;₅;₆;₇;₈;₉",list=""
    Variable digit
    for(digit=0;digit<10;digit+=1)
        name=ReplaceString(StringFromList(digit,digits),name,num2istr(digit))
    endfor
    String base=CleanupName(name,0,220),trace=base
    Variable i=2
    if(WinType(win))
        list=TraceNameList(win,";",1)
    endif
    do
        if(WhichListItem(trace,list)<0)
            return trace
        endif
        trace=base+"_"+num2istr(i);i+=1
    while(1)
End

Function/S XRD126_Cache(folder,data,ref,suffix)
    String folder,data,suffix
    Variable ref
    String child=folder+":"+CleanupName(XRD80_MeasurementUID(data),0)
    NewDataFolder/O $child
    return child+":"+PossiblyQuoteName(XRD126_Name(data,ref,suffix))
End

Function XRD126_Phases(win,data,offset,folder)
    String win,data,folder
    Variable offset
    Wave px=$(data+":Peaks:angle"),py=$(data+":Peaks:height"),ids=$(data+":Peaks:peakID"),aid=$(data+":Assignments:peakID"),refs=$(data+":Assignments:refIndex")
    Variable i,j,ref,n
    String seen="",trace,xname,yname,suffix
    for(i=0;i<numpnts(refs);i+=1)
        ref=refs[i]
        if(ref<=0 || WhichListItem(num2istr(ref),seen)>=0 || !DataFolderExists(XRD_ReferencePath(ref)))
            continue
        endif
        seen+=num2istr(ref)+";"
        suffix="_identified_R"+num2istr(ref)
        yname=XRD126_Cache(folder,data,ref,suffix)
        xname=XRD126_Cache(folder,data,ref,suffix+"_2theta")
        Make/O/D/N=(numpnts(px)) $xname,$yname
        Wave xx=$xname,yy=$yname
        n=0
        for(j=0;j<numpnts(aid);j+=1)
            if(refs[j]!=ref)
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
        trace=XRD126_Trace(win,NameOfWave(yy))
        AppendToGraph/W=$win yy/TN=$trace vs xx
        SetWindow $win userdata($("Ref_"+trace))=num2istr(ref)
        SetWindow $win userdata($("Phase_"+trace))=XRD_PhaseLabel(ref)
        XRD_ApplyPhaseStyle(win,trace,ref)
    endfor
    return 0
End
