#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

Function MH3_Check(ok,label)
    Variable ok
    String label
    if(ok)
        Print "PASS: "+label
    else
        Print "FAIL: "+label
        Variable/G root:MH3Failures=NumVarOrDefault("root:MH3Failures",0)+1
    endif
End

Function MH3_Run(output)
    String output
    Variable/G root:MH3Failures=0
    HMG_Init()
    String number,composition,a=HMG_AddFolder("home","空気"),child=HMG_AddFolder(a,"1200 ℃"),b=HMG_AddFolder("home","窒素")
    MH3_Check(HMM_ParseName("MH-044-x=0-1200inAir_26-11-07-18_33_52.VSM",number,composition)==1 && cmpstr(number,"044")==0 && cmpstr(composition,"x = 0")==0,"044 and x = 0 detected independently")
    MH3_Check(HMM_ParseName("MH-017-x=0.2-1200inair_26-10-14-11_42_34.VSM",number,composition)==1 && cmpstr(number,"017")==0 && cmpstr(composition,"x = 0.2")==0,"017 and x = 0.2 detected with leading zero")
    MH3_Check(HMM_ParseName("MH-101-x=0.1,y=0.2-1150inN2_26-11-08-18_33_52.vsm",number,composition)==1 && cmpstr(composition,"x = 0.1, y = 0.2")==0,"multiple composition variables and lowercase extension supported")
    MH3_Check(HMM_ParseName("MH-001-x=-0.1,y=1e-3-1150inV_26-11-08-18_33_52.VSM",number,composition)==1 && cmpstr(composition,"x = -0.1, y = 1e-3")==0,"negative and scientific values are not truncated")
    MH3_Check(HMM_ParseName("unknown.VSM",number,composition)==0 && strlen(number)==0 && strlen(composition)==0,"unknown filename leaves number unset")
    MH3_Check(cmpstr(HMM_NormalizeLabel("x=0.2"),"x = 0.2")==0,"equals spacing normalized without changing numeric value")
    MH3_Check(cmpstr(HMM_NormalizeLabel("x  =   0.1,y=0.2"),"x = 0.1, y = 0.2")==0,"repeated spaces normalized")
    MH3_Check(cmpstr(HMM_NormalizeLabel("試料 x=0.2"),"試料 x = 0.2")==0,"Japanese label preserved")
    MH3_Check(HMH_Import(output+"fixture.VSM",folderUID=b)==0,"existing measurement imported first")
    Wave/T ids=root:MHApp:Manager:datasetUID,names=root:MHApp:names,parents=root:MHApp:Manager:datasetFolder
    String originalUID=ids[0],oldName=names[0]
    String files=output+"MH-044-x=0-1200inAir_26-11-07-18_33_52.VSM\r"+output+"MH-017-x=0.2-1200inair_26-10-14-11_42_34.VSM\r"
    MH3_Check(HMM_ImportBatch(files,child)==2,"two selected VSM files imported as one batch")
    Wave/T batch=root:MHApp:Manager:ImportReview:ids,text=root:MHApp:Manager:ImportReview:text,numbers=root:MHApp:Manager:sampleNumber,compositions=root:MHApp:Manager:composition
    MH3_Check(numpnts(batch)==2 && cmpstr(batch[0],ids[1])==0 && cmpstr(batch[1],ids[2])==0,"review includes only the two newly added identities")
    MH3_Check(DimSize(text,0)==2 && cmpstr(text[0][0],"044")==0 && cmpstr(text[1][0],"017")==0,"review displays sample number separately")
    MH3_Check(cmpstr(names[1],"x = 0")==0 && cmpstr(names[2],"x = 0.2")==0,"composition becomes the default display name")
    MH3_Check(cmpstr(numbers[1],"044")==0 && cmpstr(numbers[2],"017")==0,"sample numbers stored as text retaining zeros")
    HMM_ReviewPanel()
    SavePICT/SNAP=1/WIN=HMM_ImportReview/O/E=-5 as output+"import_review.png"
    text[0][0]="0044";text[0][1]="x=0,y=0.1"
    MH3_Check(HMM_ApplyReview()==0 && cmpstr(names[1],"x = 0, y = 0.1")==0 && cmpstr(numbers[1],"0044")==0,"review edits number and label independently")
    MH3_Check(cmpstr(names[0],oldName)==0,"review does not rename an earlier measurement")
    MH3_Check(HMM_MoveBatch(a)==0 && cmpstr(parents[1],a)==0 && cmpstr(parents[2],a)==0 && cmpstr(parents[0],b)==0,"batch move moves only newly added measurements")
    MH3_Check(HMG_Rename("data",ids[2],"x=0")==0 && cmpstr(names[2],"x = 0")==0,"manual name edits normalize equals spacing")
    MH3_Check(HMG_Rename("data",ids[1],"x=0")==0,"repeated composition labels are allowed across sample numbers")
    MH3_Check(HMG_Move("data",ids[2],child)==0,"measurement can move under selected parent")
    HMG_OpenManager()
    DoWindow/K HMH_Panel
    MH3_Check(HMH_ShowSelected()==-1,"legacy panel selection is ignored when only the manager is open")
    Wave state=root:MHApp:listState
    HMG_SetFolderChecks("home",0)
    MH3_Check((state[0][0]&16)==0 && (state[1][0]&16)==0 && (state[2][0]&16)==0,"global clear removes every check")
    HMG_SetFolderChecks(a,1)
    MH3_Check((state[0][0]&16)==0 && (state[1][0]&16)!=0 && (state[2][0]&16)!=0,"folder check includes descendants and excludes siblings")
    HMG_SetFolderChecks(child,0)
    MH3_Check((state[1][0]&16)!=0 && (state[2][0]&16)==0,"child folder clear leaves parent measurements checked")
    Wave totals=root:MHApp:Manager:folderTotal,checked=root:MHApp:Manager:folderChecked
    MH3_Check(totals[HMG_Find("folder",a)]==2 && checked[HMG_Find("folder",a)]==1,"folder checked and total counts are accurate")
    Wave/T tree=root:MHApp:Manager:treeUID,kinds=root:MHApp:Manager:treeKind
    Wave treeState=root:MHApp:Manager:treeState
    Variable i,row=-1,graphCount
    for(i=0;i<numpnts(tree);i+=1)
        if(cmpstr(tree[i],ids[2])==0)
            row=i
        endif
    endfor
    STRUCT WMListboxAction action
    action.eventCode=13;action.row=row;action.col=0
    treeState[row][0]=48
    HMG_TreeAction(action)
    MH3_Check((state[2][0]&16)!=0 && checked[HMG_Find("folder",a)]==2,"one checkbox updates ancestor counts without rebuilding the tree")
    Wave/T folders=root:MHApp:Manager:folders
    folders[HMG_Find("folder",a)][3]="0"
    HMG_Refresh()
    FindValue/TEXT=(ids[2])/TXOP=4 tree
    MH3_Check(V_value<0,"collapsed folder hides child measurements")
    HMG_SetFolderChecks(a,0)
    MH3_Check((state[1][0]&16)==0 && (state[2][0]&16)==0,"folder clear includes collapsed descendants")
    folders[HMG_Find("folder",a)][3]="1"
    MH3_Check(HMH_Import(output+"bad.csv",folderUID=a)<0,"non-VSM extension rejected before reading")
    HMG_SetFolderChecks(a,1)
    MH3_Check(HMH_DrawGraph(-1)==2,"new metadata and batch checks retain comparison plotting")
    SVAR last=root:MHApp:lastGraph
    String graph=GetUserData(last,"","HMHGraphUID"),base=HMG_SnapshotPath(graph)
    NVAR savedAt=$(base+"savedAt")
    Variable before=savedAt
    HMG_Capture(last)
    MH3_Check(cmpstr(base,HMG_SnapshotPath(graph))==0 && savedAt==before,"unchanged graph capture avoids another snapshot generation")
    String sources=HMG_GraphSources(graph)
    MH3_Check(strsearch(sources,"0044",0)>=0 && strsearch(sources,"017",0)>=0,"graph source list includes independent sample numbers")
    String/G root:MH3Folder=a
    String/G root:MH3Child=child
    String/G root:MH3Graph=graph
    String/G root:MH3OriginalUID=originalUID
    String/G root:MH3SampleUID=ids[1]
    String/G root:MHApp:Manager:Autosave:directory=output+"autosave:"
    HMA_Init()
    NVAR due=root:MHApp:Manager:Autosave:nextDue,enabled=root:MHApp:Manager:Autosave:enabled
    NVAR saves=root:MHApp:Manager:Autosave:saveCount
    MH3_Check(enabled==1 && NumVarOrDefault("root:MHApp:Manager:Autosave:interval",0)==300,"autosave defaults enabled at five minutes")
    CtrlNamedBackground HMARecovery,status
    MH3_Check(NumberByKey("PERIOD",S_info)==18000,"native autosave timer uses five-minute tick period")
    before=saves
    MH3_Check(HMA_Tick(due-1)==0 && saves==before,"autosave does not run before five-minute deadline")
    MH3_Check(HMA_Tick(due)==1 && saves==before+1,"autosave writes a recovery copy when due")
    SVAR recovery=root:MHApp:Manager:Autosave:lastPath
    String first=recovery
    MH3_Check(HMA_SaveRecovery()==1 && cmpstr(first,recovery)!=0,"second autosave uses another generation")
    MH3_Check(HMA_SaveRecovery()==1 && cmpstr(first,recovery)==0,"third autosave rotates to first generation")
    enabled=0
    HMA_Arm()
    MH3_Check(HMA_Tick(DateTime+1000)==0,"explicitly disabled autosave does not write")
    enabled=1
    HMA_Arm()
    HMM_ReviewPanel()
    SavePICT/SNAP=1/WIN=HMG_Manager/O/E=-5 as output+"manager.png"
    SaveExperiment/C/F={1,"",0} as output+"v230_roundtrip.pxp"
    MH3_Check(GetRTError(1)==0,"v2.3.0 operations finish without runtime error")
    Print "V230_FAILURES",NumVarOrDefault("root:MH3Failures",-1)
End

Function MH3_Reopen(output)
    String output
    Variable/G root:MH3Failures=0
    HMG_Init()
    SVAR sampleUID=root:MH3SampleUID,graph=root:MH3Graph,folder=root:MH3Folder,child=root:MH3Child
    Variable index=HMG_Find("data",sampleUID)
    Wave/T numbers=root:MHApp:Manager:sampleNumber,names=root:MHApp:names
    MH3_Check(cmpstr(numbers[index],"0044")==0 && cmpstr(names[index],"x = 0")==0,"sample number and display name survive process restart")
    MH3_Check(HMG_Find("folder",child)>=0 && cmpstr(HMG_Parent("folder",child),folder)==0,"folder hierarchy survives process restart")
    MH3_Check(HMG_OpenGraph(graph)==0 && strsearch(HMG_GraphSources(graph),"0044",0)>=0,"graph links survive metadata restart")
    MH3_Check(NumVarOrDefault("root:MHApp:Manager:Autosave:saving",-1)==0,"autosave busy flag resets on reopen")
    CtrlNamedBackground HMARecovery,status
    MH3_Check(NumberByKey("RUN",S_info)==1 && NumberByKey("PERIOD",S_info)==18000,"five-minute autosave resumes after process restart")
    HMG_OpenManager()
    SavePICT/SNAP=1/WIN=HMG_Manager/O/E=-5 as output+"reopened_manager.png"
    MH3_Check(GetRTError(1)==0,"reopened metadata and autosave finish without runtime error")
    Print "REOPEN230_FAILURES",NumVarOrDefault("root:MH3Failures",-1)
End

Function MH3_StartTimed(output,session)
    String output,session
    HMG_Init()
    HMH_Import(output+"fixture.VSM")
    String/G root:MHApp:Manager:Autosave:directory=output+"timed_autosave:"
    String/G root:MHApp:Manager:Autosave:session=session
    HMA_Arm()
    Variable/G root:MH3TimedStart=DateTime
    Print "TIMED_AUTOSAVE_READY"
End
