#pragma rtGlobals=3

Function HMG_Reorder(kind,uid,direction)
    String kind,uid
    Variable direction
    if(HMG_Init()!=0 || cmpstr(uid,"home")==0 || abs(direction)!=1)
        return -1
    endif
    Variable row=HMG_Find(kind,uid),other
    if(row<0)
        return -1
    endif
    String parent=HMG_Parent(kind,uid)
    if(cmpstr(kind,"folder")==0)
        Wave/T folders=root:MHApp:Manager:folders
        for(other=row+direction;other>0 && other<DimSize(folders,0);other+=direction)
            if(cmpstr(folders[other][1],parent)==0)
                Make/FREE/T/N=4 entry=folders[row][p]
                folders[row][]=folders[other][q]
                folders[other][]=entry[q]
                return 0
            endif
        endfor
    elseif(cmpstr(kind,"data")==0)
        Wave/T parents=root:MHApp:Manager:datasetFolder
        for(other=row+direction;other>=0 && other<numpnts(parents);other+=direction)
            if(cmpstr(parents[other],parent)==0)
                HMG_SwapDatasetRows(row,other)
                return 0
            endif
        endfor
    endif
    return 1
End

Function HMG_SwapDatasetRows(first,second)
    Variable first,second
    String keys="root:MHApp:paths;root:MHApp:names;root:MHApp:Manager:datasetUID;root:MHApp:Manager:sampleNumber;root:MHApp:Manager:composition;root:MHApp:Manager:sourceName;"
    Variable i,column,flags
    String value
    for(i=0;i<ItemsInList(keys);i+=1)
        Wave/T field=$StringFromList(i,keys)
        value=field[first]
        field[first]=field[second]
        field[second]=value
    endfor
    Wave/T text=root:MHApp:listText
    Wave state=root:MHApp:listState
    for(column=0;column<DimSize(text,1);column+=1)
        value=text[first][column]
        text[first][column]=text[second][column]
        text[second][column]=value
        flags=state[first][column]
        state[first][column]=state[second][column]
        state[second][column]=flags
    endfor
End

Function HMG_Select(kind,uid)
    String kind,uid
    String/G root:MHApp:Manager:selectedKind=kind
    String/G root:MHApp:Manager:selectedUID=uid
    String/G root:MHApp:Manager:importFolder=SelectString(cmpstr(kind,"folder")==0,HMG_Parent(kind,uid),uid)
    return 0
End

Function HMG_DeleteFolder(uid)
    String uid
    Variable row=HMG_Find("folder",uid),i
    if(row<=0)
        return -1
    endif
    String parent=HMG_Parent("folder",uid)
    Wave/T folders=root:MHApp:Manager:folders,parents=root:MHApp:Manager:datasetFolder,graphs=root:MHApp:Manager:graphs
    // Check collisions before promoting anything to the parent.
    for(i=1;i<DimSize(folders,0);i+=1)
        if(cmpstr(folders[i][1],uid)==0 && !HMG_NameAvailable("folder",parent,folders[i][2],uid))
            return -2
        endif
    endfor
    for(i=0;i<DimSize(graphs,0);i+=1)
        if(cmpstr(graphs[i][1],uid)==0 && !HMG_NameAvailable("graph",parent,graphs[i][2],graphs[i][0]))
            return -2
        endif
    endfor
    folders[][1]=SelectString(cmpstr(folders[p][1],uid)==0,folders[p][1],parent)
    graphs[][1]=SelectString(cmpstr(graphs[p][1],uid)==0,graphs[p][1],parent)
    parents=SelectString(cmpstr(parents[p],uid)==0,parents[p],parent)
    DeletePoints/M=0 row,1,folders
    return HMG_Select("folder",parent)
End

Function HMG_DeleteData(uid)
    String uid
    Variable row=HMG_Find("data",uid)
    if(row<0)
        return -1
    endif
    Wave/T paths=root:MHApp:paths,parents=root:MHApp:Manager:datasetFolder
    String runPath=paths[row],parent=parents[row]
    // Never delete outside the application's registered measurement folders.
    if(!StringMatch(runPath,"root:MHApp:Run*:") || ItemsInList(runPath,":")!=3)
        return -1
    endif
    HMG_ClosePlotsUsing(runPath)
    KillDataFolder/Z $runPath
    if(DataFolderExists(runPath))
        Variable blockedError=GetRTError(1)
        return -2
    endif
    Wave/T graphs=root:MHApp:Manager:graphs
    Variable i
    for(i=DimSize(graphs,0)-1;i>=0;i-=1)
        if(HMG_GraphUsesData(graphs[i][0],uid,runPath))
            HMG_DeleteGraph(graphs[i][0])
        endif
    endfor
    Wave/T names=root:MHApp:names,text=root:MHApp:listText,ids=root:MHApp:Manager:datasetUID
    Wave/T numbers=root:MHApp:Manager:sampleNumber,compositions=root:MHApp:Manager:composition,sources=root:MHApp:Manager:sourceName
    Wave state=root:MHApp:listState
    DeletePoints/M=0 row,1,paths,names,text,state,ids,parents,numbers,compositions,sources
    NVAR count=root:MHApp:count
    count-=1
    if(count==0)
        Redimension/N=1 paths,names
        Redimension/N=(1,2) text,state
        text="";state=0
    endif
    Wave/T/Z review=root:MHApp:Manager:ImportReview:ids
    if(WaveExists(review))
        FindValue/TEXT=uid/TXOP=4 review
        if(V_value>=0)
            i=V_value
            Wave/T reviewText=root:MHApp:Manager:ImportReview:text
            Wave reviewState=root:MHApp:Manager:ImportReview:state
            DeletePoints/M=0 i,1,review,reviewText,reviewState
            if(numpnts(review)==0)
                DoWindow/K HMM_ImportReview
            endif
        endif
    endif
    return HMG_Select("folder",parent)
End

Function HMG_ReplaceData(uid,file)
    String uid,file
    Variable row=HMG_Find("data",uid)
    if(row<0)
        return -1
    endif
    Wave/T paths=root:MHApp:paths
    String target=paths[row],staged="",number,composition
    if(HMH_ReadVSM(file,staged)!=0)
        return -2
    endif
    Wave rawH=$(staged+"H_Oe"),rawM=$(staged+"M_emu"),field=$(staged+"H_kOe"),moment=$(staged+"M_emu_g")
    NVAR mass=$(staged+"sampleMassG")
    Duplicate/O rawH,$(target+"H_Oe")
    Duplicate/O rawM,$(target+"M_emu")
    Duplicate/O field,$(target+"H_kOe")
    Duplicate/O moment,$(target+"M_emu_g")
    Variable/G $(target+"sampleMassG")=mass
    String/G $(target+"sourceFile")=file
    HMM_ParseName(file,number,composition)
    Wave/T compositions=root:MHApp:Manager:composition,sources=root:MHApp:Manager:sourceName
    compositions[row]=composition
    sources[row]=HMM_FileName(file)
    KillDataFolder/Z $staged
    Wave/T/Z review=root:MHApp:Manager:ImportReview:ids,reviewText=root:MHApp:Manager:ImportReview:text
    if(WaveExists(review) && WaveExists(reviewText))
        FindValue/TEXT=uid/TXOP=4 review
        if(V_value>=0)
            reviewText[V_value][2]=sources[row]
        endif
    endif
    return 0
End

Function HMG_DeleteSource(uid)
    String uid
    Variable row=HMG_Find("data",uid)
    if(row<0)
        return -1
    endif
    Wave/T paths=root:MHApp:paths
    String source=StrVarOrDefault(paths[row]+"sourceFile","")
    if(!StringMatch(LowerStr(source),"*.vsm") || strsearch(source,":",0)<0)
        return -1
    endif
    GetFileFolderInfo/Q/Z source
    if(V_flag!=0 || !V_isFile)
        return -1
    endif
    DeleteFile/Z=1 source
    return V_flag
End
