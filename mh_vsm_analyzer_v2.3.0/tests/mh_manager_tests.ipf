#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

Function MHT_Check(ok,label)
    Variable ok
    String label
    if(ok)
        Print "PASS: "+label
    else
        Print "FAIL: "+label
        Variable/G root:MHTFailures=NumVarOrDefault("root:MHTFailures",0)+1
    endif
End

Function MHT_Run(output)
    String output
    Variable/G root:MHTFailures=0
    MHT_Check(HMG_Init()==0,"manager initializes on empty Experiment")
    MHT_Check(NumVarOrDefault("root:MHApp:Manager:arrowOption",-1)==0,"arrow editor is off by default")
    String a=HMG_AddFolder("home","合成条件 空気"),b=HMG_AddFolder(a,"1150 ℃"),c=HMG_AddFolder("home","窒素"),uid,graph,base,oldRec,newRec
    MHT_Check(strlen(a)>0 && strlen(b)>0 && strlen(c)>0,"nested Japanese folders created")
    MHT_Check(strlen(HMG_AddFolder(a,"1150 ℃"))==0,"duplicate sibling folder rejected")
    MHT_Check(strlen(HMG_AddFolder(c,"1150 ℃"))>0,"same folder name under different parent allowed")
    MHT_Check(HMG_Move("folder",a,b)!=0,"moving folder into descendant rejected")
    MHT_Check(HMG_Move("folder","home",a)!=0,"root move rejected")
    MHT_Check(HMG_Rename("folder",b,"1200 ℃") ==0,"folder renamed")
    MHT_Check(HMH_Import(output+"fixture.VSM",folderUID=b)==0,"VSM imported into selected folder")
    Wave/T ids=root:MHApp:Manager:datasetUID,parents=root:MHApp:Manager:datasetFolder,paths=root:MHApp:paths
    uid=ids[0]
    String originalPath=paths[0]
    MHT_Check(cmpstr(parents[0],b)==0,"import destination persisted by folder UID")
    Wave h=$(paths[0]+"H_Oe"),m=$(paths[0]+"M_emu"),x=$(paths[0]+"H_kOe"),y=$(paths[0]+"M_emu_g")
    Duplicate/FREE h,hBefore
    Duplicate/FREE m,mBefore
    Duplicate/FREE x,xBefore
    Duplicate/FREE y,yBefore
    String noteBefore=note(y)
    MHT_Check(numpnts(h)==11 && h[0]==-5000 && h[10]==5000,"raw field values retained")
    MHT_Check(abs(m[0]+0.2)<1e-12 && x[10]==5 && abs(y[10]-10)<1e-12,"original magnetic conversion retained")
    MHT_Check(HMH_DrawGraph(0)==1,"single graph created with current format")
    SVAR last=root:MHApp:lastGraph
    String win=last
    graph=GetUserData(win,"","HMHGraphUID");base=HMG_SnapshotPath(graph)
    MHT_Check(strlen(graph)>0,"new graph receives stable UID")
    Wave/T traces=$(base+"traces")
    MHT_Check(DimSize(traces,0)==1 && cmpstr(traces[0][1],uid)==0,"graph trace linked to dataset UID")
    String trace=StringFromList(0,TraceNameList(win,";",1))
    // Deliberately edit native graph state, including non-default typography.
    ModifyGraph/W=$win gfSize=28,lsize($trace)=3,rgb($trace)=(11000,22000,33000)
    SetAxis/W=$win bottom -3.25,4.75
    SetAxis/W=$win left -8,12
    Legend/W=$win/C/N=HMHLegend1/A=RT/X=9/Y=7 "手編集した凡例"
    TextBox/W=$win/C/N=UserNote/A=LB/X=5/Y=6 "Keep this annotation"
    SetDrawLayer/W=$win UserBack
    SetDrawEnv/W=$win linefgc=(50000,0,0),arrow=1,xcoord=bottom,ycoord=left
    DrawLine/W=$win -2,5,-1,2
    oldRec=WinRecreation(win,2)
    MHT_Check(HMG_Rename("data",uid,"試料 x = 0.2") ==0,"dataset display name changed")
    MHT_Check(HMG_Move("data",uid,c)==0,"dataset moved logically")
    MHT_Check(HMG_Move("folder",b,c)==0,"nested folder moved")
    MHT_Check(HMG_Move("graph",graph,a)==0,"graph moved independently")
    MHT_Check(HMG_Rename("graph",graph,"比較図 1")==0,"graph display name changed")
    newRec=WinRecreation(win,2)
    MHT_Check(cmpstr(oldRec,newRec)==0,"management operations leave native graph state unchanged")
    MHT_Check(cmpstr(paths[0],originalPath)==0,"logical move keeps physical wave path")
    MHT_Check(EqualWaves(h,hBefore,1)==1 && EqualWaves(m,mBefore,1)==1 && EqualWaves(x,xBefore,1)==1 && EqualWaves(y,yBefore,1)==1,"all raw and converted wave values unchanged")
    MHT_Check(cmpstr(note(y),noteBefore)==0,"wave Note unchanged by management")
    MHT_Check(cmpstr(traces[0][1],uid)==0,"graph association survives rename and move")
    MHT_Check(HMG_Capture(win)==0,"native graph snapshot captured")
    MHT_Check(HMG_CloseGraph(graph)==0 && WinType(win)==0,"graph closes while catalog entry remains")
    MHT_Check(HMG_Find("graph",graph)>=0,"closed graph stays in catalog")
    MHT_Check(HMG_OpenGraph(graph)==0,"closed graph reopens from snapshot")
    win=HMG_GraphWindow(graph)
    MHT_Check(WinType(win)==1,"reopened graph exists")
    GetAxis/Q/W=$win bottom
    MHT_Check(abs(V_min+3.25)<1e-12 && abs(V_max-4.75)<1e-12,"custom horizontal range restored")
    MHT_Check(strsearch(WinRecreation(win,0),"gfSize=28",0)>=0,"custom font size restored")
    MHT_Check(strsearch(AnnotationInfo(win,"HMHLegend1",1),"手編集した凡例",0)>=0,"manually edited legend restored")
    MHT_Check(WhichListItem("UserNote",AnnotationList(win))>=0,"independent TextBox restored")
    String drawing=WinRecreation(win,0)
    MHT_Check(strsearch(drawing,"DrawLine",0)>=0,"user-drawn arrow restored")
    String nativeBefore=WinRecreation(win,2)
    MHT_Check(HMG_OpenGraph(graph)==0 && cmpstr(nativeBefore,WinRecreation(win,2))==0,"opening an already-open graph preserves latest state")
    DoWindow/C $"CustomMHWindow"
    win="CustomMHWindow"
    MHT_Check(WhichListItem(win,HMH_FigureList())>=0,"renamed native window remains discoverable")
    MHT_Check(cmpstr(HMG_GraphWindow(graph),win)==0,"renamed window found by UID")
    MHT_Check(HMG_SaveAll()==0,"all open graph edits synchronized")
    TextBox/W=$win/C/N=LatestClose "last native close edit"
    DoWindow/K $win
    MHT_Check(HMG_OpenGraph(graph)==0,"native close path can reopen managed graph")
    win=HMG_GraphWindow(graph)
    MHT_Check(WhichListItem("LatestClose",AnnotationList(win))>=0,"native close captures final edits")
    // Optional arrow editor must leave unrelated drawings intact.
    String aid=HMG_NewUID("a")
    MHT_Check(HMG_SetArrow(win,aid,1,9,2,4)==0,"optional named arrow created")
    Make/FREE/D/N=4 coords
    MHT_Check(HMG_ReadArrow(win,aid,coords)==0 && coords[0]==1 && coords[3]==4,"optional arrow endpoints readable")
    MHT_Check(HMG_SetArrow(win,aid,1.25,9,2,4.5)==0,"optional arrow endpoints edited")
    MHT_Check(HMG_ReadArrow(win,aid,coords)==0 && coords[0]==1.25 && coords[3]==4.5,"edited arrow coordinates retained")
    MHT_Check(WhichListItem("UserNote",AnnotationList(win))>=0,"arrow editor retains unrelated annotation")
    HMG_OpenManager()
    MHT_Check(WinType("HMG_Manager")==7,"management panel opens")
    Wave/T treeIDs=root:MHApp:Manager:treeUID,kinds=root:MHApp:Manager:treeKind
    MHT_Check(numpnts(treeIDs)>=7,"tree contains folders, measurement, and graph")
    String uidBefore=ids[0]
    MHT_Check(HMG_Init()==0 && cmpstr(uidBefore,ids[0])==0,"reinitialization does not replace measurement identity")
    Wave/T graphRows=root:MHApp:Manager:graphs
    Variable countBefore=DimSize(graphRows,0)
    HMG_SaveAll()
    MHT_Check(DimSize(graphRows,0)==countBefore,"refresh does not duplicate graph records")
    String/G root:MHTFolderA=a
    String/G root:MHTFolderC=c
    String/G root:MHTDataset=uid
    String/G root:MHTGraph=graph
    String/G root:MHTArrow=aid
    String/G root:MHTOriginalPath=originalPath
    Variable/G root:MHTExpectedN=DimSize(graphRows,0)
    // A second graph remains open at save, while the customized one is closed.
    MHT_Check(HMH_DrawGraph(0)==1,"another graph using same measurement created")
    MHT_Check(HMG_CloseGraph(graph)==0,"custom graph closed before saving Experiment")
    SaveExperiment/C/F={1,"",0} as output+"managed_roundtrip.pxp"
    MHT_Check(GetRTError(1)==0,"manager run ends without runtime errors")
    Print "MANAGER_FAILURES",NumVarOrDefault("root:MHTFailures",-1)
End

Function MHT_Reopen(output)
    String output
    Variable/G root:MHTFailures=0
    SVAR uid=root:MHTDataset,graph=root:MHTGraph,aid=root:MHTArrow,originalPath=root:MHTOriginalPath,c=root:MHTFolderC
    MHT_Check(HMG_Init()==0,"manager initializes after full process restart")
    Wave/T ids=root:MHApp:Manager:datasetUID,parents=root:MHApp:Manager:datasetFolder,paths=root:MHApp:paths
    MHT_Check(cmpstr(ids[0],uid)==0 && cmpstr(parents[0],c)==0,"dataset identity and moved folder survive restart")
    MHT_Check(cmpstr(paths[0],originalPath)==0,"original physical data location survives restart")
    MHT_Check(cmpstr(HMG_Name("data",uid),"試料 x = 0.2")==0,"renamed measurement survives restart")
    MHT_Check(cmpstr(HMG_Name("graph",graph),"比較図 1")==0,"renamed graph survives restart")
    Wave h=$(paths[0]+"H_Oe"),m=$(paths[0]+"M_emu"),x=$(paths[0]+"H_kOe"),y=$(paths[0]+"M_emu_g")
    MHT_Check(numpnts(h)==11 && h[0]==-5000 && h[10]==5000 && abs(m[10]-0.2)<1e-12,"raw measurements survive process restart")
    MHT_Check(x[10]==5 && abs(y[10]-10)<1e-12,"converted measurements survive process restart")
    MHT_Check(HMG_OpenGraph(graph)==0,"graph closed before save restores after full restart")
    String win=HMG_GraphWindow(graph)
    GetAxis/Q/W=$win bottom
    MHT_Check(abs(V_min+3.25)<1e-12 && abs(V_max-4.75)<1e-12,"custom axis survives full restart")
    MHT_Check(strsearch(WinRecreation(win,0),"gfSize=28",0)>=0,"custom font survives full restart")
    MHT_Check(strsearch(AnnotationInfo(win,"HMHLegend1",1),"手編集した凡例",0)>=0,"custom legend survives full restart")
    Make/FREE/D/N=4 coords
    MHT_Check(HMG_ReadArrow(win,aid,coords)==0 && coords[0]==1.25 && coords[3]==4.5,"optional arrow coordinates survive full restart")
    Wave/T traces=$(HMG_SnapshotPath(graph)+"traces")
    MHT_Check(cmpstr(traces[0][1],uid)==0,"graph source measurement UID survives full restart")
    SavePICT/WIN=$win/O/E=-5/B=72 as output+"restored_graph.png"
    HMG_OpenManager()
    DoWindow/F HMG_Manager
    SavePICT/SNAP=1/WIN=HMG_Manager/O/E=-5 as output+"manager_panel.png"
    MHT_Check(GetRTError(1)==0,"restart run ends without runtime errors")
    Print "REOPEN_FAILURES",NumVarOrDefault("root:MHTFailures",-1)
End

Function MHT_OtherSave(refNum,fileName,pathName,fileType,creator,fileKind)
    Variable refNum,fileKind
    String fileName,pathName,fileType,creator
    Variable/G root:MHTOtherSaves=NumVarOrDefault("root:MHTOtherSaves",0)+1
    return 0
End

Function MHT_Edges(output)
    String output
    Variable/G root:MHTFailures=0
    HMG_Init()
    String a=HMG_AddFolder("home","A"),b=HMG_AddFolder("home","B")
    MHT_Check(HMH_Import(output+"tests:fixture.VSM",folderUID=a)==0,"first import succeeds")
    MHT_Check(HMH_Import(output+"tests:fixture.VSM",folderUID=b)==0,"continued import succeeds")
    Wave/T ids=root:MHApp:Manager:datasetUID,paths=root:MHApp:paths
    String uid0=ids[0],uid1=ids[1]
    MHT_Check(cmpstr(uid0,uid1)!=0,"separately imported measurements have distinct identities")
    MHT_Check(HMG_Move("data",uid0,"missing")!=0,"nonexistent destination rejected")
    MHT_Check(HMG_Rename("data",uid0,"")!=0,"empty dataset name rejected")
    MHT_Check(HMG_Move("data",uid0,b)==0 && cmpstr(HMG_Parent("data",uid0),b)==0,"same composition may coexist in a folder")
    HMG_Move("data",uid0,a)
    NVAR count=root:MHApp:count
    Variable oldCount=count,oldFolders=CountObjects("root:MHApp",4)
    MHT_Check(HMH_Import(output+"missing.VSM",folderUID=a)<0,"missing source file rejected")
    MHT_Check(count==oldCount && CountObjects("root:MHApp",4)==oldFolders,"failed import leaves no partial dataset or folder")
    MHT_Check(HMH_Import(output+"invalid.VSM",folderUID=a)<0,"invalid VSM rejected")
    MHT_Check(count==oldCount && CountObjects("root:MHApp",4)==oldFolders,"invalid VSM leaves no partial dataset or folder")
    HMG_OpenManager()
    Wave/T treeIDs=root:MHApp:Manager:treeUID,kinds=root:MHApp:Manager:treeKind
    Wave treeState=root:MHApp:Manager:treeState,legacyState=root:MHApp:listState
    Variable i,row=-1
    for(i=0;i<numpnts(treeIDs);i+=1)
        if(cmpstr(treeIDs[i],uid1)==0)
            row=i
        endif
    endfor
    STRUCT WMListboxAction action
    action.eventCode=13;action.row=row;action.col=0
    treeState[row][0]=48
    HMG_TreeAction(action)
    MHT_Check((legacyState[1][0]&16)!=0,"tree checkbox selects the intended measurement")
    SVAR currentSelection=root:MHApp:Manager:selectedUID
    String selected=currentSelection
    action.eventCode=8;action.row=0
    HMG_TreeAction(action)
    MHT_Check(cmpstr(selected,currentSelection)==0,"scroll event does not change selection or import target")
    HMG_Rename("data",uid1,"second measurement")
    HMG_Move("data",uid1,a)
    HMG_Refresh()
    MHT_Check((legacyState[1][0]&16)!=0 && cmpstr(ids[1],uid1)==0,"check state follows dataset identity after rename and move")
    legacyState[0][0]=48
    MHT_Check(HMH_DrawGraph(-1)==2,"checked measurements from different tree positions form comparison")
    SVAR win=root:MHApp:lastGraph
    String graph=GetUserData(win,"","HMHGraphUID")
    Wave/T traces=$(HMG_SnapshotPath(graph)+"traces")
    MHT_Check(DimSize(traces,0)==2 && cmpstr(traces[0][1],uid0)==0 && cmpstr(traces[1][1],uid1)==0,"comparison retains ordered source identities")
    HMG_CloseGraph(graph)
    // Deliberately make one dependency unavailable in this synthetic fixture.
    Wave y=$(paths[0]+"M_emu_g")
    Rename y,temporarilyUnavailable
    String beforeWins=WinList("*",";","WIN:1")
    MHT_Check(HMG_OpenGraph(graph)<0,"missing graph dependency is reported")
    MHT_Check(cmpstr(beforeWins,WinList("*",";","WIN:1"))==0,"failed graph restore leaves no partial window")
    Rename y,M_emu_g
    MHT_Check(HMG_OpenGraph(graph)==0,"graph restores after dependency is available again")
    SetIgorHook BeforeExperimentSaveHook=MHT_OtherSave
    Variable/G root:MHTOtherSaves=0
    SaveExperiment/C/F={1,"",0} as output+"edge_roundtrip.pxp"
    MHT_Check(NumVarOrDefault("root:MHTOtherSaves",0)==1,"manager save hook coexists with another registered hook")
    MHT_Check(GetRTError(1)==0,"edge tests end without runtime errors")
    Print "EDGE_FAILURES",NumVarOrDefault("root:MHTFailures",-1)
End

Function MHT_Duplicate(output)
    String output
    Variable/G root:MHTFailures=0
    HMH_Import(output+"tests:fixture.VSM")
    HMH_DrawGraph(0)
    SVAR last=root:MHApp:lastGraph
    String original=last,uid=GetUserData(original,"","HMHGraphUID"),rec=WinRecreation(original,0)
    String wins=WinList("*",";","WIN:1"),after,copy="",copyUID
    Variable i
    Execute/Z rec
    after=WinList("*",";","WIN:1")
    for(i=0;i<ItemsInList(after);i+=1)
        if(WhichListItem(StringFromList(i,after),wins)<0)
            copy=StringFromList(i,after)
        endif
    endfor
    MHT_Check(WinType(copy)==1,"native duplicate graph created")
    copyUID=HMG_AdoptGraph(copy)
    MHT_Check(strlen(copyUID)>0 && cmpstr(copyUID,uid)!=0,"duplicate receives its own graph identity")
    MHT_Check(cmpstr(GetUserData(original,"","HMHGraphUID"),uid)==0 && cmpstr(HMG_GraphWindow(uid),original)==0,"original graph keeps its identity and owner")
    MHT_Check(HMG_SaveAll()==0,"both graph snapshots save independently")
    MHT_Check(GetRTError(1)==0,"duplication test ends without runtime errors")
    Print "DUPLICATE_FAILURES",NumVarOrDefault("root:MHTFailures",-1)
End
