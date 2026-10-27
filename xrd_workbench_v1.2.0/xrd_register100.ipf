#pragma rtGlobals=3
// v1.2.0: manually supplied sample numbers, separate composition and named Waves.
Function/S XRD100_Stem(path,projectName)
    String path,projectName
    String number=StrVarOrDefault(path+":sampleNumber",""),composition=StrVarOrDefault(path+":composition","")
    if(!strlen(number) || !strlen(composition))
        return ""
    endif
    return number+"_"+composition+"_"+projectName
End

Function XRD100_ValidPart(value)
    String value
    return strlen(TrimString(value))>0 && !GrepString(value,"[\"':;\\x00-\\x1f]")
End

Function XRD100_AddPlan(project,oldPath,newName,source,relativeParent,uid,role)
    String project,oldPath,newName,source,relativeParent,uid,role
    Wave/T plan=$(XRD100_Admin()+":namePlan")
    Variable i,n=DimSize(plan,0),error
    String full=project+relativeParent+":"+PossiblyQuoteName(newName)
    if(strlen(newName)>255 || !XRD100_ValidPart(newName))
        return -1
    endif
    for(i=0;i<n;i+=1)
        if(strlen(oldPath) && cmpstr(plan[i][0],oldPath)==0)
            return 0
        endif
        if(cmpstr(LowerStr(plan[i][1]+plan[i][3]),LowerStr(newName+relativeParent))==0)
            return -2
        endif
    endfor
    DFREF previous=GetDataFolderDFR()
    SetDataFolder $(project+relativeParent)
    error=CheckName(newName,1)
    SetDataFolder previous
    if(error && cmpstr(LowerStr(oldPath),LowerStr(full))!=0)
        return -2
    endif
    Redimension/N=(n+1,6) plan
    plan[n][0]=oldPath;plan[n][1]=newName;plan[n][2]=source
    plan[n][3]=relativeParent;plan[n][4]=uid;plan[n][5]=role
    return 0
End

Function/S XRD100_ExistingAlias(project,uid,role)
    String project,uid,role
    Wave/T/Z index=$(project+":namedIndex100")
    Variable i
    if(WaveExists(index))
        for(i=0;i<DimSize(index,0);i+=1)
            if(cmpstr(index[i][0],uid)==0 && cmpstr(index[i][1],role)==0)
                return project+":"+PossiblyQuoteName(index[i][2])
            endif
        endfor
    endif
    return ""
End

Function XRD100_PlanNames(project,newName)
    String project,newName
    Make/O/T/N=(0,6) $(XRD100_Admin()+":namePlan")
    DFREF folder=$(project+":Measurements")
    String name,path,stem,uid,keys="tt;int;int_norm",source,role,old,legacy,newStem,token
    Variable i=0,j,k,ref,duplicate,result
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        path=project+":Measurements:"+PossiblyQuoteName(name)
        uid=StrVarOrDefault(path+":measurementUID","")
        stem=XRD100_Stem(path,newName)
        if(strlen(stem))
            for(j=0;j<3;j+=1)
                role=StringFromList(j,keys)
                strswitch(role)
                    case "tt":
                        source=path+":Raw:twoTheta"
                        break
                    case "int":
                        source=path+":Raw:intensity"
                        break
                    case "int_norm":
                        source=path+":Processed:intensity"
                        break
                endswitch
                old=XRD100_ExistingAlias(project,uid,role)
                if(XRD100_AddPlan(project,old,role+"_"+stem,source,"",uid,role)<0)
                    return -1
                endif
            endfor
            Wave refs=$(path+":Assignments:refIndex")
            String seen=""
            for(j=0;j<numpnts(refs);j+=1)
                ref=refs[j]
                if(ref<=0 || WhichListItem(num2istr(ref),seen)>=0)
                    continue
                endif
                seen+=num2istr(ref)+";"
                token=XRD_PhaseLabel(ref)
                duplicate=0
                for(k=0;k<numpnts(refs);k+=1)
                    if(refs[k]>0 && refs[k]!=ref && cmpstr(XRD_PhaseLabel(refs[k]),token)==0)
                        duplicate=1
                    endif
                endfor
                if(duplicate)
                    token+="_R"+num2istr(ref)
                endif
                for(k=0;k<2;k+=1)
                    role=SelectString(k,"tt","int")+"_R"+num2istr(ref)
                    source=XRD_ReferencePath(ref)+SelectString(k,":twoTheta",":intensity")
                    old=XRD100_ExistingAlias(project,uid,role)
                    if(XRD100_AddPlan(project,old,SelectString(k,"tt","int")+"_"+token+"_"+stem,source,"",uid,role)<0)
                        return -1
                    endif
                endfor
            endfor
        endif
        legacy=StrVarOrDefault(path+":namedWaveStem81","")
        if(strlen(legacy))
            newStem=stem
            if(!strlen(newStem))
                newStem=uid+"__"+newName
            endif
            for(j=0;j<2;j+=1)
                role=SelectString(j,"tt","int")
                old=path+":Waves:"+PossiblyQuoteName(role+"_"+legacy)
                if(WaveExists($old))
                    if(XRD100_AddPlan(project,old,role+"_"+newStem,"",":Measurements:"+PossiblyQuoteName(name)+":Waves",uid,"legacy")<0)
                        return -1
                    endif
                endif
            endfor
        endif
        i+=1
    while(1)
    // Retain aliases for previously adopted cards, so re-adoption never collides.
    Wave/T/Z previousIndex=$(project+":namedIndex100")
    Wave/T plan=$(XRD100_Admin()+":namePlan")
    if(WaveExists(previousIndex))
        for(j=0;j<DimSize(previousIndex,0);j+=1)
            old=project+":"+PossiblyQuoteName(previousIndex[j][2])
            duplicate=0
            for(k=0;k<DimSize(plan,0);k+=1)
                duplicate=duplicate || cmpstr(plan[k][0],old)==0
            endfor
            if(!duplicate && WaveExists($old))
                token=previousIndex[j][2]
                String suffix="_"+XRD_ProjectDisplayName(project)
                if(strlen(token)>strlen(suffix) && cmpstr(token[strlen(token)-strlen(suffix),inf],suffix)==0)
                    token=token[0,strlen(token)-strlen(suffix)-1]+"_"+newName
                endif
                if(XRD100_AddPlan(project,old,token,"","",previousIndex[j][0],previousIndex[j][1])<0)
                    return -1
                endif
            endif
        endfor
    endif
    return XRD100_PlanSuffix(project,project,XRD_ProjectDisplayName(project),newName)
End

Function XRD100_PlanSuffix(base,project,oldName,newName)
    String base,project,oldName,newName
    DFREF folder=$base
    String name,path,suffix="_"+oldName,newWave,relative=base[strlen(project),inf]
    Variable i=0
    do
        name=GetIndexedObjNameDFR(folder,1,i)
        if(!strlen(name))
            break
        endif
        if(strlen(name)>strlen(suffix) && cmpstr(name[strlen(name)-strlen(suffix),inf],suffix)==0)
            path=base+":"+PossiblyQuoteName(name)
            newWave=name[0,strlen(name)-strlen(suffix)-1]+"_"+newName
            if(XRD100_AddPlan(project,path,newWave,"",relative,"","other")<0)
                return -1
            endif
        endif
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        if(XRD100_PlanSuffix(base+":"+PossiblyQuoteName(name),project,oldName,newName)<0)
            return -1
        endif
        i+=1
    while(1)
    return 0
End

Function XRD100_ExecuteNamePlan(tx,oldProject,newProject)
    String tx,oldProject,newProject
    Wave/T plan=$(XRD100_Admin()+":namePlan")
    String old,destination,temp,source,parent
    Variable i
    for(i=0;i<DimSize(plan,0);i+=1)
        parent=newProject+plan[i][3]
        destination=parent+":"+PossiblyQuoteName(plan[i][1])
        old=XRD100_Repath(plan[i][0],oldProject,newProject)
        if(strlen(old))
            if(cmpstr(old,destination,1)==0)
                continue
            endif
            Wave w=$old
            temp="WTemp100_"+num2istr(i)+"_"+num2istr(ticks)
            Rename w,$temp; AbortOnRTE
            XRD100_Op(tx,"wave",old,parent+":"+temp)
            Rename w,$(plan[i][1]); AbortOnRTE
            XRD100_Op(tx,"wave",parent+":"+temp,destination)
        else
            source=XRD100_Repath(plan[i][2],oldProject,newProject)
            Wave original=$source
            Make/D/N=(numpnts(original)) $destination; AbortOnRTE
            XRD100_Op(tx,"created","",destination)
            Wave created=$destination
            created=original[p]
            SetFormula created,GetWavesDataFolder(original,2)+"[p]"; AbortOnRTE
        endif
    endfor
End

Function XRD100_CommitNames(project,name,[tx])
    String project,name,tx
    Wave/T plan=$(XRD100_Admin()+":namePlan")
    Variable existed=WaveExists($(project+":namedIndex100"))
    Make/O/T/N=(0,3) $(project+":namedIndex100")
    if(!existed && !ParamIsDefault(tx))
        XRD100_Op(tx,"created","",project+":namedIndex100")
    endif
    Wave/T index=$(project+":namedIndex100")
    String path,stem,uid
    Variable i,n=0
    for(i=0;i<DimSize(plan,0);i+=1)
        if(strlen(plan[i][4]) && cmpstr(plan[i][5],"legacy")!=0)
            Redimension/N=(n+1,3) index
            index[n][0]=plan[i][4];index[n][1]=plan[i][5];index[n][2]=plan[i][1]
            n+=1
        endif
    endfor
    DFREF folder=$(project+":Measurements")
    i=0
    do
        uid=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(uid))
            break
        endif
        path=project+":Measurements:"+PossiblyQuoteName(uid)
        SVAR/Z legacy=$(path+":namedWaveStem81")
        if(SVAR_Exists(legacy))
            stem=XRD100_Stem(path,name)
            if(!strlen(stem))
                stem=StrVarOrDefault(path+":measurementUID","")+"__"+name
            endif
            legacy=stem
        endif
        i+=1
    while(1)
End

Function XRD100_RefreshNamed(project)
    String project
    if(!DataFolderExists(project) || XRD100_Busy())
        return -1
    endif
    if(XRD100_PlanNames(project,XRD_ProjectDisplayName(project))<0)
        return -1
    endif
    // Scientific assignment updates may only append new aliases; never overwrite data.
    String tx=XRD100_Admin()+":AliasRefresh"
    NewDataFolder/O $tx
    Make/O/T/N=(0,3) $(tx+":ops")
    Variable error=0
    try
        XRD100_ExecuteNamePlan(tx,project,project)
        XRD100_CommitNames(project,XRD_ProjectDisplayName(project),tx=tx)
    catch
        error=max(1,GetRTError(1))
    endtry
    return -error
End

Function XRD100_SetSample(path,number,composition,label)
    String path,number,composition,label
    String project=XRD80_ProjectForMeasurement(path),tx
    number=TrimString(number);composition=TrimString(composition);label=TrimString(label)
    if(!GrepString(number,"^[0-9]+$") || !XRD100_ValidPart(composition) || !strlen(label) || !DataFolderExists(path))
        return -1
    endif
    if(strlen("int_norm_"+number+"_"+composition+"_"+XRD_ProjectDisplayName(project))>255)
        return -2
    endif
    if(!XRD110_SerialAvailable(project,path,number))
        return -5
    endif
    String newPath=XRD110_MeasurementPath(project,number),sampleUID=XRD80_MeasurementUID(path)
    String testName="int_"+number+"_"+composition+"_"+XRD_ProjectDisplayName(project),old=XRD100_ExistingAlias(project,StrVarOrDefault(path+":measurementUID",""),"int")
    if(WaveExists($(project+":"+PossiblyQuoteName(testName))) && cmpstr(old,project+":"+PossiblyQuoteName(testName))!=0)
        return -2
    endif
    tx=XRD100_TxStart("通し番号・組成登録",project)
    if(!strlen(tx))
        return -3
    endif
    Variable error=0
    try
        XRD100_SetString(tx,path+":sampleNumber",number)
        XRD100_SetString(tx,path+":composition",composition)
        XRD100_SetString(tx,path+":displayName",label)
        if(cmpstr(path,newPath)!=0)
            RenameDataFolder $path,$number; AbortOnRTE
            XRD100_Op(tx,"folder",path,newPath)
            XRD100_Rebind(tx,path,newPath); AbortOnRTE
            path=newPath
            XRD100_RefreshRegistry(project); AbortOnRTE
        endif
        if(XRD100_PlanNames(project,XRD_ProjectDisplayName(project))<0)
            AbortOnValue 1,10001 // Wave名の衝突または不正な名前
        endif
        XRD100_ExecuteNamePlan(tx,project,project)
        XRD100_CommitNames(project,XRD_ProjectDisplayName(project),tx=tx)
        if(XRD100_VerifyFingerprint(project,tx)<0 || cmpstr(XRD80_ResolveMeasurement(sampleUID),path)!=0)
            AbortOnValue 1,10001 // 通し番号フォルダと数値データの整合性を確認
        endif
        XRD100_Commit(tx)
    catch
        String/G $(tx+":errorDetail")=GetRTErrMessage()
        error=max(1,GetRTError(1))
        XRD100_Rollback(tx)
    endtry
    return SelectNumber(error==0,-4,0)
End

Function XRD100_SetString(tx,path,value)
    String tx,path,value
    SVAR/Z existing=$path
    if(!SVAR_Exists(existing))
        XRD100_Op(tx,"newString","",path)
    endif
    String/G $path=value
End

Function XRD100_SampleUI()
    return XRD110_RegisterPanel(XRD_Data())
End

Function XRD100_ReferenceAliases(index)
    Variable index
    String base=XRD100_Management(),rp=XRD_ReferencePath(index),label=XRD_PhaseLabel(index),folder="root:Packages:Workbench:Reference:",source,keys="tt;int;d;h;k;l",names="twoTheta;intensity;d;h;k;l",alias
    if(!XRD100_ValidPart(label) || strlen(label)>220)
        label="Reference_R"+num2istr(index)
    endif
    folder+=PossiblyQuoteName(label)
    if(DataFolderExists(folder) && cmpstr(StrVarOrDefault(folder+":revisionUID",""),StrVarOrDefault(rp+":revisionUID",""))!=0)
        folder="root:Packages:Workbench:Reference:"+PossiblyQuoteName(label+"_R"+num2istr(index))
    endif
    NewDataFolder/O $folder
    String/G $(folder+":revisionUID")=StrVarOrDefault(rp+":revisionUID","")
    Variable i
    for(i=0;i<6;i+=1)
        source=rp+":"+StringFromList(i,names)
        alias=folder+":"+PossiblyQuoteName(StringFromList(i,keys)+"_"+label)
        Wave/Z exists=$alias
        if(!WaveExists(exists))
            Wave original=$source
            Make/D/N=(numpnts(original)) $alias
            Wave created=$alias
            created=original[p]
            SetFormula created,GetWavesDataFolder(original,2)+"[p]"; AbortOnRTE
        endif
    endfor
End
