#pragma rtGlobals=3

// Persistent identities and logical folders. Raw waves never move during a move.
Function HMG_Init()
    HMH_Init()
    NVAR/Z schema=root:MHApp:Manager:schemaVersion
    if(NVAR_Exists(schema))
        if(schema!=1)
            Print "MH: この管理データの版には対応していません。"
            return -1
        endif
        return HMG_SyncDatasets()
    endif
    NVAR count=root:MHApp:count
    Wave/T paths=root:MHApp:paths,names=root:MHApp:names
    Wave state=root:MHApp:listState
    if(count<0 || count!=round(count) || numpnts(paths)<count || numpnts(names)<count || DimSize(state,0)<count)
        Print "MH: 既存一覧が不整合のため管理データを作成しません。"
        return -1
    endif
    Variable i,j
    for(i=0;i<count;i+=1)
        if(!DataFolderExists(paths[i]))
            Print "MH: 測定フォルダが見つかりません: ",paths[i]
            return -1
        endif
        for(j=0;j<i;j+=1)
            if(cmpstr(paths[i],paths[j])==0)
                Print "MH: 同じ測定フォルダが重複登録されています。"
                return -1
            endif
        endfor
    endfor
    NewDataFolder/O root:MHApp:Manager
    NewDataFolder/O root:MHApp:Manager:Graphs
    NewDataFolder/O root:MHApp:Manager:Scratch
    Make/O/T/N=(1,4) root:MHApp:Manager:folders
    Wave/T folders=root:MHApp:Manager:folders
    folders[0][0]="home";folders[0][1]="";folders[0][2]="測定・グラフ";folders[0][3]="1"
    Make/O/T/N=0 root:MHApp:Manager:datasetUID,root:MHApp:Manager:datasetFolder
    Make/O/T/N=(0,4) root:MHApp:Manager:graphs
    String/G root:MHApp:Manager:selectedUID="home"
    String/G root:MHApp:Manager:selectedKind="folder"
    String/G root:MHApp:Manager:importFolder="home"
    Variable/G root:MHApp:Manager:serial=0
    Variable/G root:MHApp:Manager:busy=0
    Variable/G root:MHApp:Manager:arrowOption=0
    Variable/G root:MHApp:Manager:schemaVersion=1
    return HMG_SyncDatasets()
End

Function HMG_SyncDatasets()
    NVAR count=root:MHApp:count
    Wave/T paths=root:MHApp:paths,names=root:MHApp:names
    Wave/T/Z ids=root:MHApp:Manager:datasetUID,parents=root:MHApp:Manager:datasetFolder
    if(!WaveExists(ids) || !WaveExists(parents) || numpnts(ids)>count || numpnts(parents)!=numpnts(ids) || numpnts(paths)<count || numpnts(names)<count)
        Print "MH: 管理一覧と測定一覧が一致しません。"
        return -1
    endif
    Variable i,n=numpnts(ids)
    for(i=n;i<count;i+=1)
        if(!DataFolderExists(paths[i]))
            return -1
        endif
    endfor
    if(n<count)
        Redimension/N=(count) ids,parents
        for(i=n;i<count;i+=1)
            ids[i]=HMG_NewUID("d")
            parents[i]="home"
        endfor
    endif
    return 0
End

Function/S HMG_NewUID(prefix)
    String prefix
    NVAR serial=root:MHApp:Manager:serial
    String uid
    do
        serial+=1
        sprintf uid,"%s_%.0f_%.0f",prefix,DateTime,serial
    while(HMG_Find("folder",uid)>=0 || HMG_Find("data",uid)>=0 || HMG_Find("graph",uid)>=0)
    return uid
End

Function HMG_Find(kind,uid)
    String kind,uid
    Variable i
    if(cmpstr(kind,"data")==0)
        Wave/T/Z ids=root:MHApp:Manager:datasetUID
        if(WaveExists(ids))
            for(i=0;i<numpnts(ids);i+=1)
                if(cmpstr(ids[i],uid)==0)
                    return i
                endif
            endfor
        endif
    else
        String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
        Wave/T/Z records=$path
        if(WaveExists(records))
            for(i=0;i<DimSize(records,0);i+=1)
                if(cmpstr(records[i][0],uid)==0)
                    return i
                endif
            endfor
        endif
    endif
    return -1
End

Function/S HMG_Name(kind,uid)
    String kind,uid
    Variable i=HMG_Find(kind,uid)
    if(i<0)
        return ""
    endif
    if(cmpstr(kind,"data")==0)
        Wave/T names=root:MHApp:names
        return names[i]
    endif
    String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
    Wave/T records=$path
    return records[i][2]
End

Function/S HMG_Parent(kind,uid)
    String kind,uid
    Variable i=HMG_Find(kind,uid)
    if(i<0)
        return ""
    endif
    if(cmpstr(kind,"data")==0)
        Wave/T parents=root:MHApp:Manager:datasetFolder
        return parents[i]
    endif
    String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
    Wave/T records=$path
    return records[i][1]
End

Function HMG_NameAvailable(kind,parent,name,exceptUID)
    String kind,parent,name,exceptUID
    if(strlen(TrimString(name))==0 || strsearch(name,"\r",0)>=0 || strsearch(name,"\n",0)>=0)
        return 0
    endif
    Variable i,n
    String uid
    if(cmpstr(kind,"data")==0)
        Wave/T ids=root:MHApp:Manager:datasetUID
        n=numpnts(ids)
        for(i=0;i<n;i+=1)
            uid=ids[i]
            if(cmpstr(uid,exceptUID)!=0 && cmpstr(HMG_Parent(kind,uid),parent)==0 && cmpstr(HMG_Name(kind,uid),name)==0)
                return 0
            endif
        endfor
    else
        String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
        Wave/T records=$path
        for(i=0;i<DimSize(records,0);i+=1)
            if(cmpstr(records[i][0],exceptUID)!=0 && cmpstr(records[i][1],parent)==0 && cmpstr(records[i][2],name)==0)
                return 0
            endif
        endfor
    endif
    return 1
End

Function/S HMG_AddFolder(parent,name)
    String parent,name
    if(HMG_Init()!=0 || HMG_Find("folder",parent)<0 || !HMG_NameAvailable("folder",parent,name,""))
        return ""
    endif
    String uid=HMG_NewUID("f")
    Wave/T folders=root:MHApp:Manager:folders
    Variable n=DimSize(folders,0)
    Redimension/N=(n+1,4) folders
    folders[n][0]=uid;folders[n][1]=parent;folders[n][2]=name;folders[n][3]="1"
    return uid
End

Function HMG_Rename(kind,uid,name)
    String kind,uid,name
    if(HMG_Init()!=0)
        return -1
    endif
    Variable i=HMG_Find(kind,uid)
    if(i<0 || !HMG_NameAvailable(kind,HMG_Parent(kind,uid),name,uid))
        return -1
    endif
    if(cmpstr(kind,"data")==0)
        Wave/T names=root:MHApp:names,listText=root:MHApp:listText
        names[i]=name;listText[i][1]=name
    else
        String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
        Wave/T records=$path
        records[i][2]=name
    endif
    return 0
End

Function HMG_Move(kind,uid,parent)
    String kind,uid,parent
    if(HMG_Init()!=0 || cmpstr(uid,"home")==0)
        return -1
    endif
    Variable i=HMG_Find(kind,uid),limit=0
    if(i<0 || HMG_Find("folder",parent)<0 || !HMG_NameAvailable(kind,parent,HMG_Name(kind,uid),uid))
        return -1
    endif
    String ancestor=parent
    Wave/T folders=root:MHApp:Manager:folders
    if(cmpstr(kind,"folder")==0)
        do
            if(cmpstr(ancestor,uid)==0 || limit>DimSize(folders,0))
                return -1
            endif
            ancestor=HMG_Parent("folder",ancestor)
            limit+=1
        while(strlen(ancestor))
    endif
    if(cmpstr(kind,"data")==0)
        Wave/T parents=root:MHApp:Manager:datasetFolder
        parents[i]=parent
    else
        String path=SelectString(cmpstr(kind,"folder")==0,"root:MHApp:Manager:graphs","root:MHApp:Manager:folders")
        Wave/T records=$path
        records[i][1]=parent
    endif
    return 0
End

Function/S HMG_TargetFolder()
    if(HMG_Init()!=0)
        return ""
    endif
    SVAR target=root:MHApp:Manager:importFolder
    if(HMG_Find("folder",target)<0)
        target="home"
    endif
    return target
End

Function HMG_RegisterImport(index,parent)
    Variable index
    String parent
    if(HMG_Init()!=0 || HMG_Find("folder",parent)<0)
        return -1
    endif
    Wave/T parents=root:MHApp:Manager:datasetFolder
    if(index<0 || index>=numpnts(parents))
        return -1
    endif
    parents[index]=parent
    HMG_Refresh()
    return 0
End

Function/S HMG_FolderPath(uid)
    String uid
    String result="",name
    Variable i=0
    Wave/T folders=root:MHApp:Manager:folders
    do
        name=HMG_Name("folder",uid)
        if(strlen(name)==0 || i>DimSize(folders,0))
            return "[所属不明]"
        endif
        result=name+SelectString(strlen(result)>0,""," / ")+result
        uid=HMG_Parent("folder",uid)
        i+=1
    while(strlen(uid))
    return result
End
