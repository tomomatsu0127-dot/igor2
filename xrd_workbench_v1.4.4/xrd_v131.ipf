#pragma rtGlobals=3
// v1.3.1: ordinary windows, safe remeasurement and permanent sample removal.

Function XRD131_ReadyPanel()
    return WinType("XRDWorkbench") && cmpstr(GetUserData("XRDWorkbench","","XRDUIVersion"),"1.4.4")==0 && cmpstr(GetUserData("XRDWorkbench","","XRDProject"),XRD_Project())==0 && NumVarOrDefault("root:Packages:XRDWorkbench:Schema:schemaVersion",0)>=800
End

Function XRD131_KeepPanelSize()
    if(!WinType("XRDWorkbench") || cmpstr(IgorInfo(2),"Windows")!=0)
        return 0
    endif
    GetWindow XRDWorkbench maximize
    if(!V_Value)
        return 0
    endif
    // Activating another MDI child restores the previous maximized child.
    // Use its large rectangle as an ordinary window before changing focus.
    GetWindow XRDWorkbench wsize
    Variable l=V_left,t=V_top,r=V_right,b=V_bottom
    // A single move restores the window without drawing the old small size.
    MoveWindow/W=XRDWorkbench l,t,r,b
    return 0
End

Function/S XRD131_RegisteredSample(project,number)
    String project,number
    if(!DataFolderExists(project+":Measurements"))
        return ""
    endif
    DFREF folder=$(project+":Measurements")
    String name,path,result=""
    Variable i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        path=XRD110_MeasurementPath(project,name)
        if(cmpstr(StrVarOrDefault(path+":sampleNumber",""),number)==0 || cmpstr(name,number)==0)
            if(strlen(result))
                return ""
            endif
            result=path
        endif
        i+=1
    while(1)
    return result
End

Function XRD131_ReplaceEntry(project,number,composition,label,file)
    String project,number,composition,label,file
    String old=XRD131_RegisteredSample(project,number)
    if(!strlen(old) || strlen("int_norm_"+number+"_"+composition+"_"+XRD_ProjectDisplayName(project))>255)
        XRD124_Alert(0,"差し替える測定を特定できないか、生成するWave名が長すぎます。入力を確認してください。")
        return -1
    endif
    if(XRD124_Alert(1,"試料 "+XRD110_SampleLabel(old)+" の測定を差し替えますか？\r新しい測定を未解析で登録します。旧測定のピーク・同定・格子計算と操作履歴は引き継ぎません。\r保存した図と元ファイルは残ります。")!=1)
        return 0
    endif
    Variable result=XRD131_Replace(old,number,composition,label,file)
    if(result==-2)
        XRD124_Alert(0,"新しい測定ファイルを読み込めませんでした。既存の測定は保持しています。")
    elseif(result<0)
        XRD131_ChangeError(result)
    else
        KillWindow/Z XRDRegister110
        DoWindow/F XRDWorkbench
    endif
    return result
End

Function XRD131_Replace(old,number,composition,label,file)
    String old,number,composition,label,file
    if(!strlen(file) || !GrepString(number,"^[0-9]+$") || !XRD100_ValidPart(composition) || !strlen(label) || cmpstr(XRD131_RegisteredSample(XRD80_ProjectForMeasurement(old),number),old)!=0)
        return -1
    endif
    Make/FREE/D/N=1024 xx,yy
    String source=""
    Variable headers
    if(XRD131_ReadMeasurement(file,xx,yy,source,headers)!=0)
        return -2
    endif
    return XRD131_ChangeMeasurement(old,xx,yy,source,number,composition,label,headers)
End

Function XRD131_PurgeUI()
    String project=XRD_Project()
    if(!strlen(project))
        return -1
    endif
    DFREF folder=$(project+":Measurements")
    String name,path,choices="",paths="",current=XRD_Data()
    Variable i=0,choice=1
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        path=XRD110_MeasurementPath(project,name)
        paths+=path+";"
        choices+=ReplaceString(";",XRD110_SampleLabel(path),"；")+SelectString(NumVarOrDefault(path+":deleted",0),""," [一覧から削除済み]")+";"
        if(cmpstr(current,path)==0)
            choice=i+1
        endif
        i+=1
    while(1)
    if(!i)
        XRD124_Alert(0,"このプロジェクトに削除できる測定はありません。")
        return 0
    endif
    Prompt choice,"完全削除する測定",popup,choices
    DoPrompt "測定データを完全削除",choice
    if(V_flag)
        return 0
    endif
    path=StringFromList(choice-1,paths)
    String uid=StrVarOrDefault(path+":measurementUID","")
    String plots=XRD131_SamplePlots(uid+";"+StrVarOrDefault(path+":replacedUIDs131",""))
    String message="試料 "+XRD110_SampleLabel(path)+" をこのExperimentから完全に削除しますか？\r測定、ピーク、同定、格子計算とこの測定の操作履歴が消えます。"
    if(strlen(plots))
        message+="\rこの測定を含む保存図 "+num2istr(ItemsInList(plots))+" 件も図全体を削除します。"
    endif
    message+="\rCtrl+Zでは戻せません。元ファイル、共通参照、実行前バックアップは残ります。"
    if(XRD124_Alert(1,message)!=1)
        return 0
    endif
    Variable result=XRD131_Purge(path)
    if(result<0)
        XRD131_ChangeError(result)
    endif
    return result
End

Function XRD131_Purge(path)
    String path
    Wave/Z empty=$""
    return XRD131_ChangeMeasurement(path,empty,empty,"","","","",0)
End

Function XRD131_ChangeError(result)
    Variable result
    if(result==-5)
        XRD124_Alert(0,"測定を使っている図・表・計算式があるか、登録名が衝突しました。元の測定に戻しました。関連する手作成の図や表などを閉じ、登録名を確認してください。")
    elseif(result==-6)
        XRD124_Alert(0,"元の状態に戻せませんでした。これ以上変更する前に、実行前バックアップを開いてください。")
    else
        XRD124_Alert(0,"測定を変更できませんでした。対象と実行前バックアップの保存先を確認してください。")
    endif
End

Function/S XRD131_SamplePlots(sampleUIDs)
    String sampleUIDs
    if(!ItemsInList(sampleUIDs))
        return ""
    endif
    return XRD133_PlotsForUIDs(XRD_PlotRoot()+":Plots",sampleUIDs)+XRD133_PlotsForUIDs(XRD133_TrendFigures(),sampleUIDs)
End

Function/S XRD133_PlotsForUIDs(plots,sampleUIDs)
    String plots,sampleUIDs
    if(!DataFolderExists(plots))
        return ""
    endif
    String name,recipe,result=""
    Variable i=0,j
    do
        name=GetIndexedObjName(plots,4,i)
        if(!strlen(name))
            break
        endif
        recipe=plots+":"+PossiblyQuoteName(name)
        Wave/T/Z uids=$(recipe+":sourceUIDs")
        if(WaveExists(uids))
            for(j=0;j<numpnts(uids);j+=1)
                if(WhichListItem(uids[j],sampleUIDs)>=0)
                    result+=recipe+";"
                    break
                endif
            endfor
        endif
        i+=1
    while(1)
    return result
End

Function XRD131_StageWave(w,tx)
    Wave w
    String tx
    String formula=GetFormula(w)
    if(strlen(formula))
        Wave/T formulas=$(tx+":formulas")
        Variable row=DimSize(formulas,0)
        Redimension/N=(row+1,2) formulas
        formulas[row][0]=GetWavesDataFolder(w,2)
        formulas[row][1]=formula
        SetFormula w,""; AbortOnRTE
    endif
End

Function XRD131_ClearStageFormulas(base,tx)
    String base,tx
    DFREF folder=$base
    Variable i
    for(i=0;i<CountObjectsDFR(folder,1);i+=1)
        Wave w=WaveRefIndexedDFR(folder,i)
        XRD131_StageWave(w,tx)
    endfor
    for(i=0;i<CountObjectsDFR(folder,4);i+=1)
        XRD131_ClearStageFormulas(base+":"+PossiblyQuoteName(GetIndexedObjNameDFR(folder,4,i)),tx)
    endfor
End

Function XRD131_StageFolder(path,bin,tx)
    String path,bin,tx
    String name=PossiblyQuoteName(XRD100_Leaf(path))
    XRD131_ClearStageFormulas(path,tx)
    NewDataFolder/O $bin
    MoveDataFolder $path,$bin; AbortOnRTE
    XRD100_Op(tx,"move",path,bin+":"+name)
End

Function XRD131_StageAliases(project,uid,bin,tx)
    String project,uid,bin,tx
    Wave/T/Z names=$(project+":namedIndex100")
    if(!WaveExists(names))
        return 0
    endif
    NewDataFolder/O $bin
    String name,path
    Variable i
    for(i=DimSize(names,0)-1;i>=0;i-=1)
        if(cmpstr(names[i][0],uid)!=0)
            continue
        endif
        name=PossiblyQuoteName(names[i][2])
        path=project+":"+name
        Wave/Z alias=$path
        if(WaveExists(alias))
            XRD131_StageWave(alias,tx)
            MoveWave alias,$(bin+":"+name); AbortOnRTE
            XRD100_Op(tx,"moveWave",path,bin+":"+name)
        endif
        DeletePoints/M=0 i,1,names
    endfor
    return 0
End

Function XRD131_StageHistory(project,path,bin,tx)
    String project,path,bin,tx
    String undo=project+":Undo",entry,name
    Variable i=0
    do
        name=GetIndexedObjName(undo,4,i)
        if(!strlen(name))
            break
        endif
        entry=undo+":"+PossiblyQuoteName(name)
        if(cmpstr(StrVarOrDefault(entry+":target",""),path)==0)
            XRD131_StageFolder(entry,bin,tx)
        else
            i+=1
        endif
    while(1)
End

Function XRD131_CloseSampleViews(path)
    String path
    if(WinType("XRDWorkbench") && cmpstr(GetUserData("XRDWorkbench","","XRDData"),path)==0)
        XRD_CapturePanelState(1)
        XRD_CaptureView()
        XRD_CloseEditors()
        SetWindow XRDWorkbench userdata(XRDLayoutReady)="0"
        SetWindow XRDWorkbench userdata(XRDUIVersion)=""
        XRD120_ClearContents()
    elseif(WinType("XRDWorkbench#SideCompare") && WhichListItem(path,GetUserData("XRDWorkbench#SideCompare","","XRDLivePaths"))>=0)
        KillWindow XRDWorkbench#SideCompare
    endif
    if(WinType("XRDReviewGraph") && WhichListItem(path,GetUserData("XRDReviewGraph","","XRDLivePaths"))>=0)
        KillWindow XRDReviewGraph
    endif
    DoWindow/K XRDComparison
    DoWindow/K XRDProjectLatticeSummary
End

Function XRD131_ChangeMeasurement(path,xx,yy,source,number,composition,label,headers)
    String path,source,number,composition,label
    Wave/Z xx,yy
    Variable headers
    String project=XRD80_ProjectForMeasurement(path),uid=StrVarOrDefault(path+":measurementUID","")
    if(!strlen(uid) || !DataFolderExists(project) || cmpstr(XRD80_ResolveMeasurement(uid),path)!=0)
        return -1
    endif
    Variable replacing=WaveExists(xx),error=0
    String priorUIDs=uid+";"+StrVarOrDefault(path+":replacedUIDs131","")
    String plots=XRD131_SamplePlots(priorUIDs),oldActive=StrVarOrDefault(project+":activeData","")
    String oldProject=XRD_Project(),target=XRD110_MeasurementPath(project,number),recipe,win,newUID=""
    Variable stackOrder=NumVarOrDefault(path+":stackOrder",0),visible=NumVarOrDefault(path+":visibleInStack",1),i
    String tx=XRD100_TxStart(SelectString(replacing,"測定を完全削除","測定を差し替え"),project)
    if(!strlen(tx))
        return -3
    endif
    String bin=tx+":Removing"
    NewDataFolder $bin
    try
        XRD131_CloseSampleViews(path)
        XRD131_StageAliases(project,uid,bin+":Aliases",tx)
        XRD131_StageFolder(path,bin+":Measurements",tx)
        XRD131_StageHistory(project,path,bin+":Undo",tx)
        Wave/T registry=root:Packages:XRDWorkbench:Registry:objects
        for(i=DimSize(registry,0)-1;i>=0;i-=1)
            if(cmpstr(registry[i][1],uid)==0)
                DeletePoints/M=0 i,1,registry
            endif
        endfor
        if(replacing)
            String/G root:Packages:XRDWorkbench:activeProject=project
            if(DataFolderExists(target))
                AbortOnValue 1,10001
            endif
            XRD100_Op(tx,"createdFolder","",target)
            XRD_Store(xx,yy,source,target=target); AbortOnRTE
            String/G $(target+":sampleNumber")=number
            String/G $(target+":composition")=composition
            String/G $(target+":displayName")=label
            String/G $(target+":replacedUIDs131")=priorUIDs
            Variable/G $(target+":skippedHeaderLines")=headers
            Variable/G $(target+":stackOrder")=stackOrder
            Variable/G $(target+":visibleInStack")=visible
            if(XRD100_PlanNames(project,XRD_ProjectDisplayName(project))<0)
                AbortOnValue 1,10001
            endif
            XRD100_ExecuteNamePlan(tx,project,project)
            XRD100_CommitNames(project,XRD_ProjectDisplayName(project),tx=tx)
            newUID=StrVarOrDefault(target+":measurementUID","")
            if(cmpstr(XRD80_ResolveMeasurement(newUID),target)!=0)
                AbortOnValue 1,10001
            endif
        else
            for(i=0;i<ItemsInList(plots);i+=1)
                recipe=StringFromList(i,plots)
                win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
                DoWindow/K $win
                win="XRDLegend_"+StrVarOrDefault(recipe+":plotUID","")
                DoWindow/K $win
                XRD131_StageFolder(recipe,bin+":Plots",tx)
            endfor
        endif
        // Igor removes all of this folder or leaves it intact when a wave is in use.
        KillDataFolder $bin; AbortOnRTE
    catch
        error=max(1,GetRTError(1))
        String/G $(tx+":errorDetail")=GetErrMessage(error)
        Print "XRD measurement change stopped",error,GetErrMessage(error)
    endtry
    if(error)
        Variable rollback=XRD100_Rollback(tx)
        if(!rollback)
            KillDataFolder/Z $tx
            String/G $(XRD100_Admin()+":activeTransaction")=""
            if(WinType("XRDWorkbench"))
                XRD_Panel()
            endif
        endif
        return SelectNumber(rollback==0,-6,-5)
    endif
    XRD100_Commit(tx)
    KillDataFolder/Z $tx
    String/G $(XRD100_Admin()+":activeTransaction")=""
    if(replacing)
        Variable/G $(project+":activeStep")=1
        XRD131_MarkReplacedPlots(XRD131_SamplePlots(uid))
    elseif(cmpstr(oldActive,path)==0)
        String list=XRD_MeasurementOrderList(project)
        String/G $(project+":activeData")=""
        if(ItemsInList(list))
            String/G $(project+":activeData")=project+":Measurements:"+StringFromList(0,list)
        endif
    endif
    XRD131_UpdateSelections(uid,newUID)
    XRD133_UpdateTrendSelection(uid,newUID)
    XRD131_UpdatePlotList()
    if(WinType("XRDWorkbench") || replacing || cmpstr(oldProject,project)==0)
        XRD_Panel()
        XRD_SyncSideRange()
    endif
    return 0
End

Function XRD131_MarkReplacedPlots(plots)
    String plots
    String recipe,win
    Variable i
    for(i=0;i<ItemsInList(plots);i+=1)
        recipe=StringFromList(i,plots)
        Variable/G $(recipe+":stale")=1
        win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
        if(WinType(win))
            TextBox/W=$win/C/N=XRDNeedsUpdate/F=0/B=1/A=LT "\Z12元の測定を差し替えました：この図は作成時の結果です"
        endif
    endfor
End

Function XRD131_UpdateSelections(uid,newUID)
    String uid,newUID
    String projects=XRD_ProjectList(),project
    Variable i,j
    for(i=0;i<ItemsInList(projects);i+=1)
        project=StringFromList(i,projects)
        Wave/T/Z uids=$(project+":Comparison120:uids")
        if(!WaveExists(uids))
            continue
        endif
        for(j=numpnts(uids)-1;j>=0;j-=1)
            if(cmpstr(uids[j],uid)==0)
                if(strlen(newUID))
                    uids[j]=newUID
                else
                    DeletePoints j,1,uids
                endif
            endif
        endfor
    endfor
End

Function XRD131_UpdatePlotList()
    if(!WinType("XRDPlotWorkspace"))
        return 0
    endif
    String ui=XRD_PlotRoot()+":UI",recipe=StrVarOrDefault(ui+":recipe","")
    if(strlen(recipe) && DataFolderExists(recipe))
        XRD_PlotLoadRecipe(recipe)
    else
        String/G $(ui+":recipe")=""
        XRD_PlotSelectionTable(1)
        PopupMenu saved,win=XRDPlotWorkspace,mode=1
    endif
    PopupMenu saved,win=XRDPlotWorkspace,value=XRD_PlotChoices()
    return 0
End
