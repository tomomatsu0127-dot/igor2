#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

Function MH4_Check(ok,label)
    Variable ok
    String label
    if(ok)
        Print "PASS: "+label
    else
        Print "FAIL: "+label
        NVAR failed=root:MH4Failed
        failed+=1
    endif
End

Function MH4_Test(output)
    String output
    Variable/G root:MH4Failed=0
    HMG_Init()
    String a=HMG_AddFolder("home","A"),b=HMG_AddFolder("home","B")
    String child=HMG_AddFolder(a,"子")
    String first=output+"MH-044-x=0-1200inAir_26-11-07-18_33_52.VSM",second=output+"MH-017-x=0.2-1200inAir_26-11-07-18_33_52.VSM"
    MH4_Check(HMM_ImportBatch(first+"\r"+second+"\r",a)==2,"import establishes two independent datasets")
    Wave/T ids=root:MHApp:Manager:datasetUID,paths=root:MHApp:paths,parents=root:MHApp:Manager:datasetFolder
    Wave/T folders=root:MHApp:Manager:folders,numbers=root:MHApp:Manager:sampleNumber,names=root:MHApp:names
    Wave state=root:MHApp:listState
    String uid=ids[0],other=ids[1],originalPath=paths[0],secondPath=paths[1]
    HMG_OpenManager()
    HMG_SetFolderChecks(a,1)
    MH4_Check(HMG_Reorder("folder",b,-1)==0 && cmpstr(folders[1][0],b)==0 && cmpstr(folders[3][1],a)==0,"folder order changes only among siblings")
    MH4_Check(HMG_Reorder("folder",b,1)==0 && cmpstr(folders[1][0],a)==0,"folder down restores order")
    MH4_Check(HMG_Reorder("data",other,-1)==0 && cmpstr(ids[0],other)==0 && cmpstr(numbers[0],"017")==0 && cmpstr(paths[1],originalPath)==0 && (state[1][0]&16)!=0,"measurement order keeps identity, path, number and check paired")
    MH4_Check(HMG_Reorder("data",uid,-1)==0 && cmpstr(ids[0],uid)==0,"measurement can move back")
    MH4_Check(HMG_ReplaceData(uid,output+"invalid.VSM")<0 && cmpstr(StrVarOrDefault(originalPath+"sourceFile",""),first)==0,"invalid replacement keeps old source")
    MH4_Check(HMH_DrawGraph(0)==1,"normal single plot opens")
    SVAR last=root:MHApp:lastGraph
    String regular=last
    MH4_Check(cmpstr(HMP_DefaultExportName(regular),"MH-044-x=0-1200inAir_26-11-07-18_33_52.png")==0,"single plot uses source filename as PNG default")
    MH4_Check(HMP_WritePNG(regular,output+"normal.png")==0,"normal graph exports to PNG")
    MH4_Check(HMG_ReplaceData(uid,second)==0 && cmpstr(ids[0],uid)==0 && cmpstr(paths[0],originalPath)==0 && cmpstr(names[0],"x = 0")==0 && cmpstr(numbers[0],"044")==0,"valid replacement keeps UID, folder and assigned label and number")
    String trace=StringFromList(0,TraceNameList(regular,";",1))
    Wave live=TraceNameToWaveRef(regular,trace)
    MH4_Check(abs(live[0]+20)<1e-9 && cmpstr(StrVarOrDefault(originalPath+"sourceFile",""),second)==0,"open trace uses replacement Wave and metadata")
    MH4_Check(HMP_Close(regular)==0 && WinType(regular)==0,"preview closes immediately")
    HMG_Select("folder",a)
    HMG_Refresh()
    DoWindow/F HMG_Manager
    MoveWindow/W=HMG_Manager 2,2,2,2
    GetWindow HMG_Manager maximize
    MH4_Check(V_value==1,"manager is maximized before creating graph")
    GetWindow HMG_Manager wsize
    Variable left=V_left,top=V_top,right=V_right,bottom=V_bottom
    MH4_Check(HMH_DrawGraph(0)==1,"graph opens in overlay mode")
    String overlay=last,host=StringFromList(0,overlay,"#")
    MH4_Check(WinType(overlay)==1 && strsearch(overlay,"#Plot",0)>=0,"overlay contains a native editable graph")
    GetWindow HMG_Manager maximize
    MH4_Check(V_value==1,"manager stays maximized after graph opens")
    GetWindow HMG_Manager wsize
    MH4_Check(V_left==left && V_top==top && V_right==right && V_bottom==bottom,"manager keeps exact window rectangle")
    GetWindow $overlay psize
    Print "OVERLAY_PLOT_SIZE",V_right-V_left,V_bottom-V_top
    MH4_Check(abs(V_right-V_left-12*72/2.54)<2 && abs(V_bottom-V_top-9*72/2.54)<2,"overlay keeps 12 x 9 cm plot size")
    MH4_Check(HMP_WritePNG(overlay,output+"overlay.png")==0,"overlay exports without the manager background")
    Wave/T graphs=root:MHApp:Manager:graphs
    MH4_Check(DimSize(graphs,0)==0,"new plots leave no saved-graph rows")
    HMP_Close(overlay)
    DoWindow/F HMG_Manager
    HMG_Move("data",uid,child)
    MH4_Check(HMG_DeleteFolder(a)==0 && cmpstr(parents[0],child)==0 && cmpstr(parents[1],"home")==0 && cmpstr(HMG_Parent("folder",child),"home")==0,"deleting folder promotes contents and preserves subtrees")
    HMH_Import(output+"disposable.VSM",folderUID=b)
    String disposable=ids[2]
    MH4_Check(HMG_DeleteSource(disposable)==0 && HMG_Find("data",disposable)>=0,"disk-file deletion keeps imported measurement")
    GetFileFolderInfo/Q/Z output+"disposable.VSM"
    MH4_Check(V_flag!=0,"only the designated source file is gone")
    MH4_Check(HMG_DeleteData(disposable)==0 && HMG_Find("data",disposable)<0,"dataset deletion removes imported measurement and row")
    HMM_ReviewPanel()
    MH4_Check(HM4_BlockedDelete(other,secondPath),"a non-MH graph blocks deletion without removing dataset or waves")
    DoWindow/F HMG_Manager
    MoveWindow/W=HMG_Manager 2,2,2,2
    HMH_DrawGraph(HMG_Find("data",other))
    String previewToClose=last
    MH4_Check(HMG_DeleteData(other)==0 && HMG_Find("data",other)<0 && !DataFolderExists(secondPath),"measurement delete removes its data folder")
    MH4_Check(strlen(previewToClose)>0 && WinType(previewToClose)==0,"deleting a dataset closes its open MH preview")
    GetFileFolderInfo/Q/Z second
    MH4_Check(V_flag==0 && V_isFile,"measurement deletion leaves source on disk")
    Wave/T review=root:MHApp:Manager:ImportReview:ids
    MH4_Check(numpnts(review)==1 && cmpstr(review[0],uid)==0,"pending import review remains aligned")
    String/G root:MH4UID=uid
    String/G root:MH4Folder=child
    DoWindow/K HMM_ImportReview
    HMG_Refresh()
    SaveExperiment/C/F={1,"",0} as output+"management_roundtrip.pxp"
    MH4_Check(GetRTError(1)==0,"no runtime error")
    Print "MH4_FAILURES",NumVarOrDefault("root:MH4Failed",-1)
End

Function MH4_Reopen()
    Variable/G root:MH4Failed=0
    HMG_Init()
    NVAR count=root:MHApp:count
    SVAR uid=root:MH4UID,folder=root:MH4Folder
    Wave/T ids=root:MHApp:Manager:datasetUID,numbers=root:MHApp:Manager:sampleNumber
    Wave/T paths=root:MHApp:paths
    Wave field=$(paths[0]+"M_emu_g")
    MH4_Check(count==1 && cmpstr(ids[0],uid)==0 && cmpstr(numbers[0],"044")==0 && cmpstr(HMG_Parent("data",uid),folder)==0,"saved dataset identity, number, removal and folder survived reopening")
    MH4_Check(abs(field[0]+20)<1e-9,"replacement values survived reopening")
    Print "REOPEN_FAILURES",NumVarOrDefault("root:MH4Failed",-1)
End

Function HM4_BlockedDelete(uid,runPath)
    String uid,runPath
    Wave field=$(runPath+"H_kOe")
    Display/K=1/N=UnrelatedGraph field
    Variable unchanged=HMG_DeleteData(uid)==-2 && HMG_Find("data",uid)>=0 && DataFolderExists(runPath) && WinType("UnrelatedGraph")==1
    DoWindow/K UnrelatedGraph
    return unchanged
End