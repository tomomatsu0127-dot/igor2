#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

Function MHP_Run(n)
    Variable n
    HMH_Init()
    NVAR count=root:MHApp:count
    count=n
    Wave/T paths=root:MHApp:paths,names=root:MHApp:names,list=root:MHApp:listText
    Wave checks=root:MHApp:listState
    Redimension/N=(n) paths,names
    Redimension/N=(n,2) list,checks
    Variable i,j,clock,ms,row=-1
    String folder
    for(i=0;i<n;i+=1)
        folder="root:MHApp:Bench"+num2istr(i)
        NewDataFolder/O $folder
        Make/O/D/N=5 $(folder+":H_kOe"),$(folder+":M_emu_g")
        Wave x=$(folder+":H_kOe"),y=$(folder+":M_emu_g")
        x=p;y=p+i
        paths[i]=folder+":";names[i]="x = "+num2str(i/100)
        list[i][0]="";list[i][1]=names[i]
        checks[i][0]=32;checks[i][1]=6
    endfor
    HMG_Init()
    Wave/T parents=root:MHApp:Manager:datasetFolder,ids=root:MHApp:Manager:datasetUID
    for(i=0;i<10;i+=1)
        folder=HMG_AddFolder("home","Folder "+num2istr(i))
        for(j=i;j<n;j+=10)
            parents[j]=folder
        endfor
    endfor
    HMG_OpenManager()
    HMG_Refresh()
    for(j=0;j<3;j+=1)
        clock=StartMSTimer
        HMG_Refresh()
        ms=StopMSTimer(clock)/1000
        Print "TREE_MS",n,j,ms
    endfor
    Wave/T tree=root:MHApp:Manager:treeUID
    Wave treeState=root:MHApp:Manager:treeState
    for(i=0;i<numpnts(tree);i+=1)
        if(cmpstr(tree[i],ids[n-1])==0)
            row=i
        endif
    endfor
    STRUCT WMListboxAction action
    action.eventCode=13;action.row=row;action.col=0
    for(j=0;j<3;j+=1)
        treeState[row][0]=48
        clock=StartMSTimer
        HMG_TreeAction(action)
        ms=StopMSTimer(clock)/1000
        Print "CHECK_MS",n,j,ms
    endfor
    Variable before=CountObjects("root:MHApp:Manager",1)
    for(j=0;j<10;j+=1)
        HMG_Refresh()
    endfor
    Print "MANAGER_WAVES",before,CountObjects("root:MHApp:Manager",1)
    Print "BENCH_ERROR",GetRTError(1)
End
#pragma rtGlobals=3
Function MHB_Bulk(n)
    Variable n
    MHP_Run(n)
    Wave/T folders=root:MHApp:Manager:folders
    Variable i,clock
    for(i=0;i<5;i+=1)
        clock=StartMSTimer
        HMG_SetFolderChecks(folders[9][0],mod(i,2))
        Print "FOLDER_MS",StopMSTimer(clock)/1000
    endfor
    for(i=0;i<5;i+=1)
        clock=StartMSTimer
        HMG_SetFolderChecks("home",0)
        Print "CLEAR_MS",StopMSTimer(clock)/1000
    endfor
    for(i=0;i<5;i+=1)
        clock=StartMSTimer
        HMH_DrawGraph(5)
        Print "DRAW_MS",StopMSTimer(clock)/1000
        SVAR win=root:MHApp:lastGraph
        DoWindow/K $win
    endfor
    Print "BULK_ERROR",GetRTError(1)
End
