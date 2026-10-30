#pragma rtGlobals=3
// v1.2.0 plain text registration fields; no numeric conversion of sample serials.
Function/S XRD110_Entry()
    String base="root:Packages:XRDWorkbench:UI:Entry110"
    XRD_UISettings()
    NewDataFolder/O $base
    return base
End

Function XRD110_RegisterPanel(path)
    String path
    String base=XRD110_Entry(),owner=XRD_Project()
    if(strlen(path) && DataFolderExists(path))
        owner=XRD80_ProjectForMeasurement(path)
    endif
    if(WinType("XRDRegister110"))
        DoWindow/F XRDRegister110
        return 0
    endif
    String/G $(base+":ownerUID")=XRD80_ProjectUID(owner)
    String/G $(base+":sampleUID")=StrVarOrDefault(path+":measurementUID","")
    String/G $(base+":file")=""
    String/G $(base+":copyUID120")=""
    String/G $(base+":number")=StrVarOrDefault(path+":sampleNumber","")
    String/G $(base+":composition")=StrVarOrDefault(path+":composition","")
    String/G $(base+":label")=StrVarOrDefault(path+":displayName","")
    String/G $(base+":lastSyncedLabel120")=StrVarOrDefault(path+":displayName","")
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDRegister110")
    NewPanel/FLT=1/N=XRDRegister110/K=1/W=(60,60,760,490) as "測定データを登録：番号・表示名・組成"
    ModifyPanel/W=XRDRegister110 fixedSize=0
    DefaultGUIFont all={"Segoe UI",12,0}
    TitleBox owner,pos={18,15},frame=0,title="登録先："+XRD_ProjectDisplayName(owner)
    SetVariable number,pos={18,60},size={650,25},title="通し番号（015など）",value=$(base+":number"),proc=XRD110_EntryChanged
    SetVariable composition,pos={18,148},size={650,25},title="組成（x=-0.1など）",value=$(base+":composition"),proc=XRD110_EntryChanged
    SetVariable label,pos={18,104},size={650,25},title="表示名",value=$(base+":label"),proc=XRD110_EntryChanged
    Button file,pos={18,194},size={180,28},title="測定ファイルを選ぶ…",proc=XRD110_EntryButton
    Button copy120,pos={210,194},size={458,28},title="他プロジェクトの同定済み試料から追加…",proc=XRD120_CopyButton
    TitleBox fileName,pos={18,226},size={650,18},frame=0,title=SelectString(strlen(path)>0,"未選択","登録済み測定の情報を変更")
    TitleBox preview,pos={18,246},size={650,85},frame=0,title=""
    TitleBox note,pos={18,335},frame=0,title="引用符は入力不要。015は文字として保持。int_normは0〜100に規格化した強度です。"
    Button register,pos={18,365},size={650,30},title="この内容で登録（重複は上書きしません）",proc=XRD110_EntryButton
    if(strlen(path))
        Button file,disable=2
        Button copy120,disable=2
    endif
    XRD110_EntryPreview()
    XRD123_FinishPanel("XRDRegister110",panelState123)
    return 0
End

Function XRD110_EntryPreview()
    String base=XRD110_Entry(),owner=XRD100_ProjectByUID(StrVarOrDefault(base+":ownerUID","")),number=TrimString(StrVarOrDefault(base+":number","")),composition=TrimString(StrVarOrDefault(base+":composition","")),stem
    stem=number+"_"+composition+"_"+XRD_ProjectDisplayName(owner)
    TitleBox preview,win=XRDRegister110,title="生成名：\rtt_"+stem+"\rint_"+stem+"\rint_norm_"+stem
End

Function XRD110_EntryChanged(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva
    if((sva.eventCode>=1 && sva.eventCode<=3) || sva.eventCode==8 || sva.eventCode==-2)
        if(cmpstr(sva.ctrlName,"label")==0)
            String base=XRD110_Entry(),label=StrVarOrDefault(base+":label","")
            if(cmpstr(label,StrVarOrDefault(base+":lastSyncedLabel120",""))!=0)
                String/G $(base+":composition")=label
                String/G $(base+":lastSyncedLabel120")=label
                ControlUpdate/W=XRDRegister110 composition
            endif
        endif
        XRD110_EntryPreview()
    endif
    return 0
End

Function XRD110_EntryButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(cmpstr(ba.ctrlName,"file")==0)
        Execute/P/Q "XRD110_ChooseFile()"
    else
        Execute/P/Q "XRD110_CommitEntry()"
    endif
    return 0
End

Function XRD110_ChooseFile()
    Variable ref
    Open/D/R/Z=2/F="XRD data (*.txt,*.csv,*.xy,*.dat):.txt,.csv,.xy,.dat;All files:.*;" ref as ""
    if(V_flag || !strlen(S_fileName))
        return -1
    endif
    String base=XRD110_Entry()
    String/G $(base+":file")=S_fileName
    String/G $(base+":copyUID120")=""
    TitleBox fileName,win=XRDRegister110,title=ParseFilePath(0,S_fileName,":",1,0)
    return 0
End

Function XRD110_CommitEntry()
    String base=XRD110_Entry(),owner=XRD100_ProjectByUID(StrVarOrDefault(base+":ownerUID","")),number=TrimString(StrVarOrDefault(base+":number","")),composition=TrimString(StrVarOrDefault(base+":composition","")),label=TrimString(StrVarOrDefault(base+":label","")),path=XRD80_ResolveMeasurement(StrVarOrDefault(base+":sampleUID","")),file=StrVarOrDefault(base+":file","")
    if(!strlen(owner) || !GrepString(number,"^[0-9]+$") || !XRD100_ValidPart(composition) || !strlen(label))
        XRD124_Alert(0,"登録先、通し番号、組成、表示名を確認してください。引用符は不要です。")
        return -1
    endif
    if(!XRD110_SerialAvailable(owner,path,number))
        XRD124_Alert(0,"このプロジェクトには同じ通し番号があります。番号を確認してください。既存データは変更していません。")
        return -1
    endif
    String name="int_norm_"+number+"_"+composition+"_"+XRD_ProjectDisplayName(owner),old=XRD100_ExistingAlias(owner,StrVarOrDefault(path+":measurementUID",""),"int_norm")
    if(strlen(name)>255 || (WaveExists($(owner+":"+PossiblyQuoteName(name))) && cmpstr(old,owner+":"+PossiblyQuoteName(name))!=0))
        XRD124_Alert(0,"生成Wave名が重複するか、255バイトを超えています。変更していません。")
        return -1
    endif
    String/G root:Packages:XRDWorkbench:activeProject=owner
    if(!strlen(path) && strlen(StrVarOrDefault(base+":copyUID120","")))
        String copySource=XRD80_ResolveMeasurement(StrVarOrDefault(base+":copyUID120",""))
        path=XRD120_CopyMeasurement(copySource,owner,number,composition,label)
        if(!strlen(path))
            XRD124_Alert(0,"同定済み試料を複製できません。元データは変更していません。")
            return -1
        endif
        String/G $(base+":sampleUID")=XRD80_MeasurementUID(path)
    elseif(!strlen(path))
        if(!strlen(file) || XRD_ImportFile(file)!=0)
            XRD124_Alert(0,"測定ファイルを選び、形式を確認してください。")
            return -1
        endif
        path=XRD_Data()
        // Keep the imported sample reachable even if a backup or metadata operation fails.
        String/G $(base+":sampleUID")=XRD80_MeasurementUID(path)
    endif
    String sampleUID=XRD80_MeasurementUID(path)
    if(XRD100_SetSample(path,number,composition,label)<0)
        XRD124_Alert(0,"登録情報を保存できません。バックアップ先・生成名を確認してください。読み込んだ試料は保持しています。")
        return -1
    endif
    path=XRD80_ResolveMeasurement(sampleUID)
    String/G $(owner+":activeData")=path
    DoWindow/K XRDRegister110
    XRD_Panel()
    return 0
End

// Display serials independently of the stable, experiment-wide measurement UID.
Function/S XRD110_MeasurementPath(project,name)
    String project,name
    if(strlen(name)>1 && cmpstr(name[0],"'")==0 && cmpstr(name[strlen(name)-1],"'")==0)
        name=name[1,strlen(name)-2]
    endif
    return project+":Measurements:"+PossiblyQuoteName(name)
End

Function/S XRD110_SampleLabel(path)
    String path
    String number=StrVarOrDefault(path+":sampleNumber",""),label=StrVarOrDefault(path+":displayName","")
    if(!strlen(number))
        return "番号未登録 / "+label
    endif
    return number+" / "+label
End

Function XRD110_SerialAvailable(project,path,number)
    String project,path,number
    if(!GrepString(number,"^[0-9]+$") || strlen(number)>255)
        return 0
    endif
    DFREF folder=$(project+":Measurements")
    String name,other,target=XRD110_MeasurementPath(project,number)
    Variable i=0
    if(DataFolderExists(target) && cmpstr(target,path)!=0)
        return 0
    endif
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        other=XRD110_MeasurementPath(project,name)
        if(cmpstr(other,path)!=0 && cmpstr(StrVarOrDefault(other+":sampleNumber",""),number)==0)
            return 0
        endif
        i+=1
    while(1)
    return 1
End
