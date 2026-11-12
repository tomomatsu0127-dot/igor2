#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
// Legacy XRD migration add-on v0.1.0 for XRD Workbench v1.4.4.

Menu "XRD Workbench"
    "手作業の実験を取り込む (.pxp)...", XRDLegacy_Open()
    "選択中の測定の移行記録...", XRDLegacy_ShowEvidence()
End

Function/S XRDLegacy_Base()
    return "root:Packages:XRDLegacyMigration"
End

Function XRDLegacy_Load(file)
    String file
    DFREF prior=GetDataFolderDFR()
    String base=XRDLegacy_Base(),data=base+":Input"
    NewDataFolder/O root:Packages
    NewDataFolder/O $base
    KillDataFolder/Z $data
    if(DataFolderExists(data))
        return -1
    endif
    NewDataFolder/S $data
    Variable loaded=-1
    try
        LoadData/Q/R/L=1 file
        AbortOnRTE
        loaded=V_flag
    catch
        Print "XRD migration: "+GetRTErrMessage()
        Variable error=GetRTError(1)
    endtry
    SetDataFolder prior
    if(loaded<=0 || !DataFolderExists(data))
        KillDataFolder/Z $data
        return -1
    endif
    String/G $(base+":source")=file
    Make/O/T/N=0 $(base+":measurements")
    Wave/T measurements=$(base+":measurements")
    Make/O/T/N=0 $(base+":numericWaves")
    Wave/T numericWaves=$(base+":numericWaves")
    XRDLegacy_Scan(data,measurements,numericWaves)
    return numpnts(numericWaves)
End

Function XRDLegacy_Scan(folder,measurements,numericWaves)
    String folder
    Wave/T measurements,numericWaves
    DFREF df=$folder
    Variable i,n
    String name,stem,xpath
    for(i=0;i<CountObjectsDFR(df,1);i+=1)
        name=GetIndexedObjNameDFR(df,1,i)
        Wave/Z yy=$(folder+":"+PossiblyQuoteName(name))
        if(WaveExists(yy) && numpnts(yy)>=3 && XRDLegacy_PhaseWave(yy,numpnts(yy)))
            n=numpnts(numericWaves)
            Redimension/N=(n+1) numericWaves
            numericWaves[n]=folder+":"+PossiblyQuoteName(name)
        endif
        if(!GrepString(name,"^int_[0-9]+(_.+)?$"))
            continue
        endif
        stem=name[4,inf]
        xpath=folder+":"+PossiblyQuoteName("tt_"+stem)
        Wave/Z xx=$xpath
        if(XRDLegacy_ValidXY(xx,yy))
            n=numpnts(measurements)
            Redimension/N=(n+1) measurements
            measurements[n]=folder+":"+PossiblyQuoteName(stem)
        endif
    endfor
    for(i=0;i<CountObjectsDFR(df,4);i+=1)
        name=GetIndexedObjNameDFR(df,4,i)
        if(cmpstr(name,"Packages")!=0)
            XRDLegacy_Scan(folder+":"+PossiblyQuoteName(name),measurements,numericWaves)
        endif
    endfor
End

Function XRDLegacy_ValidXY(xx,yy)
    Wave/Z xx,yy
    if(!WaveExists(xx) || !WaveExists(yy))
        return 0
    endif
    if((WaveType(xx)&1) || (WaveType(yy)&1) || WaveType(xx)==0 || WaveType(yy)==0)
        return 0
    endif
    Variable i,n=numpnts(xx)
    if(n<3 || n!=numpnts(yy) || WaveDims(xx)!=1 || WaveDims(yy)!=1)
        return 0
    endif
    if(numtype(xx[0]) || numtype(yy[0]) || xx[0]<0 || xx[n-1]>180)
        return 0
    endif
    for(i=1;i<n;i+=1)
        if(numtype(xx[i]) || numtype(yy[i]) || xx[i]<=xx[i-1])
            return 0
        endif
    endfor
    return 1
End

Function/S XRDLegacy_WavePath(key,prefix)
    String key,prefix
    if(cmpstr(key,XRDLegacy_Base()+":Manual")==0)
        return StrVarOrDefault(XRDLegacy_Base()+":manual_"+prefix,"")
    endif
    Variable colon=strsearch(key,":",strlen(key),1)
    String stem=ReplaceString("'",key[colon+1,inf],"")
    return key[0,colon]+PossiblyQuoteName(prefix+"_"+stem)
End

Function/S XRDLegacy_OriginalPath(path)
    String path
    return ReplaceString(XRDLegacy_Base()+":Input:",path,"root:")
End

Function XRDLegacy_Point(xx,yy,angle,height)
    Wave xx,yy
    Variable angle,height
    if(numtype(angle) || numtype(height) || angle<xx[0] || angle>xx[numpnts(xx)-1])
        return -1
    endif
    Variable low=0,high=numpnts(xx)-1,mid,i,hit=-1
    do
        if(high-low<=1)
            break
        endif
        mid=floor((high+low)/2)
        if(xx[mid]<angle)
            low=mid
        else
            high=mid
        endif
    while(1)
    for(i=low;i<=high;i+=1)
        if(abs(xx[i]-angle)<=0.011 && abs(yy[i]-height)<=0.0011)
            if(hit>=0)
                return -1
            endif
            hit=i
        endif
    endfor
    return hit
End

Function XRDLegacy_MatchingReflection(tt,hh,kk,ll,angle,h,k,l)
    Wave tt,hh,kk,ll
    Variable angle,h,k,l
    Variable i,hit=-1,distance=0.3,delta
    if(!XRD82_ValidIndex(h) || !XRD82_ValidIndex(k) || !XRD82_ValidIndex(l) || h^2+k^2+l^2==0)
        return -1
    endif
    for(i=0;i<numpnts(tt);i+=1)
        if(hh[i]==h && kk[i]==k && ll[i]==l)
            delta=abs(tt[i]-angle)
            if(delta<distance-1e-7)
                hit=i
                distance=delta
            elseif(distance<0.3 && abs(delta-distance)<=1e-7)
                hit=-2
            endif
        endif
    endfor
    return hit
End

Function XRDLegacy_PhaseWave(w,n)
    Wave/Z w
    Variable n
    if(!WaveExists(w))
        return 0
    endif
    return WaveDims(w)==1 && WaveType(w)>0 && !(WaveType(w)&1) && numpnts(w)==n
End

Function XRDLegacy_Preview(key)
    String key
    String base=XRDLegacy_Base(),serial,phase,number
    Variable colon=strsearch(key,":",strlen(key),1)
    String folder=key[0,colon-1],name,overlay,pattern="^int_(.+)_([0-9]+)(?:_[A-Za-z]+)?$"
    Wave yy=$XRDLegacy_WavePath(key,"int")
    String stem=NameOfWave(yy)
    SplitString/E="^int_([0-9]+)" stem,serial
    DFREF df=$folder
    Wave xx=$XRDLegacy_WavePath(key,"tt")
    Wave/T measurements=$(base+":measurements")
    Make/O/T/N=(0,6) $(base+":preview")
    Make/O/D/N=(0,4) $(base+":rows")
    Wave/T preview=$(base+":preview")
    Wave rows=$(base+":rows")
    Variable i,j,k,n,r,point,reflection,matchCount,conflict
    if(cmpstr(key,base+":Manual")!=0)
        for(i=0;i<CountObjectsDFR(df,1);i+=1)
            name=GetIndexedObjNameDFR(df,1,i)
            SplitString/E=(pattern) name,phase,number
            if(V_flag!=2 || cmpstr(number,serial)!=0 || GrepString(phase,"^[0-9]"))
                continue
            endif
            overlay=name[4,inf]
            Wave intOverlay=$(folder+":"+PossiblyQuoteName(name))
            Wave/Z ttOverlay=$(folder+":"+PossiblyQuoteName("tt_"+overlay))
            Wave/Z hOverlay=$(folder+":"+PossiblyQuoteName("h_"+overlay))
            Wave/Z kOverlay=$(folder+":"+PossiblyQuoteName("k_"+overlay))
            Wave/Z lOverlay=$(folder+":"+PossiblyQuoteName("l_"+overlay))
            n=numpnts(intOverlay)
            if(!XRDLegacy_PhaseWave(intOverlay,n) || !XRDLegacy_PhaseWave(ttOverlay,n))
                continue
            endif
            String reference=folder+":"+PossiblyQuoteName(phase)
            Wave/Z rt=$XRDLegacy_WavePath(reference,"tt"),ri=$XRDLegacy_WavePath(reference,"int")
            Wave/Z rh=$XRDLegacy_WavePath(reference,"h"),rk=$XRDLegacy_WavePath(reference,"k"),rl=$XRDLegacy_WavePath(reference,"l")
            Variable refSize=0
            if(WaveExists(rt))
                refSize=numpnts(rt)
            endif
            Variable indexed=XRDLegacy_PhaseWave(hOverlay,n) && XRDLegacy_PhaseWave(kOverlay,n) && XRDLegacy_PhaseWave(lOverlay,n)
            Variable validRef=refSize>0 && XRDLegacy_PhaseWave(ri,refSize) && XRDLegacy_PhaseWave(rh,refSize) && XRDLegacy_PhaseWave(rk,refSize) && XRDLegacy_PhaseWave(rl,refSize)
            if(validRef && XRD80_SameReferenceWave(rt,ttOverlay) && XRD80_SameReferenceWave(ri,intOverlay))
                continue
            endif
            for(j=0;j<n;j+=1)
                if(numtype(ttOverlay[j]) || numtype(intOverlay[j]))
                    continue
                endif
                point=XRDLegacy_Point(xx,yy,ttOverlay[j],intOverlay[j])
                reflection=-1
                if(validRef && indexed)
                    reflection=XRDLegacy_MatchingReflection(rt,rh,rk,rl,ttOverlay[j],hOverlay[j],kOverlay[j],lOverlay[j])
                    if(reflection>=0 && rt[reflection]==ttOverlay[j] && ri[reflection]==intOverlay[j])
                        continue
                    endif
                endif
                matchCount=0
                if(point>=0)
                    for(k=0;k<numpnts(measurements);k+=1)
                        String other=measurements[k]
                        Variable otherColon=strsearch(other,":",strlen(other),1)
                        if(cmpstr(other[0,otherColon-1],folder)!=0)
                            continue
                        endif
                        Wave ox=$XRDLegacy_WavePath(measurements[k],"tt"),oy=$XRDLegacy_WavePath(measurements[k],"int")
                        String otherSerial,otherName=NameOfWave(oy)
                        SplitString/E="^int_([0-9]+)" otherName,otherSerial
                        if(cmpstr(otherSerial,serial)==0 && XRDLegacy_Point(ox,oy,ttOverlay[j],intOverlay[j])>=0)
                            matchCount+=1
                        endif
                    endfor
                endif
                String result="測定曲線上に一致点なし"
                if(point>=0 && matchCount!=1)
                    result="同じ番号の別測定にも一致"
                elseif(point>=0 && reflection<0)
                    result="ピークのみ（参照反射を特定できない）"
                elseif(point>=0)
                    result="移行候補"
                endif
                r=DimSize(preview,0)
                Redimension/N=(r+1,6) preview
                Redimension/N=(r+1,4) rows
                preview[r][0]=phase
                preview[r][1]=num2str(ttOverlay[j])
                preview[r][2]=num2str(intOverlay[j])
                preview[r][3]=name+" ["+num2istr(j)+"]"
                preview[r][4]=result
                preview[r][5]=reference
                rows[r][0]=point
                rows[r][1]=reflection
                rows[r][2]=ttOverlay[j]
                rows[r][3]=intOverlay[j]
            endfor
        endfor
        for(i=0;i<DimSize(rows,0);i+=1)
            if(cmpstr(preview[i][4],"移行候補")!=0)
                continue
            endif
            conflict=0
            for(j=0;j<DimSize(rows,0);j+=1)
                if(i==j || rows[i][1]!=rows[j][1] || cmpstr(preview[i][5],preview[j][5])!=0)
                    continue
                endif
                if(rows[j][0]>=0 && rows[i][0]!=rows[j][0])
                    conflict=1
                    break
                endif
            endfor
            if(conflict)
                preview[i][4]="ピークのみ（同じ参照反射が複数点に一致）"
            endif
        endfor
    endif
    SetDimLabel 1,0,Phase,preview
    SetDimLabel 1,1,'元の2θ',preview
    SetDimLabel 1,2,'元の強度',preview
    SetDimLabel 1,3,'元Waveと行',preview
    SetDimLabel 1,4,'照合結果',preview
    SetDimLabel 1,5,'参照元',preview
    String/G $(base+":key")=key
    return DimSize(preview,0)
End

Function XRDLegacy_Reference(key)
    String key
    Wave tt=$XRDLegacy_WavePath(key,"tt"),ii=$XRDLegacy_WavePath(key,"int")
    Wave hh=$XRDLegacy_WavePath(key,"h"),kk=$XRDLegacy_WavePath(key,"k"),ll=$XRDLegacy_WavePath(key,"l")
    Wave/Z sourceD=$XRDLegacy_WavePath(key,"d")
    Variable n=numpnts(tt),i
    Make/FREE/D/N=(n) dd
    dd=NaN
    if(XRDLegacy_PhaseWave(sourceD,n))
        dd=(numtype(sourceD[p])==0 && sourceD[p]>0) ? sourceD[p] : NaN
    endif
    String phase=NameOfWave(tt)
    phase=phase[3,inf]
    String card="Legacy "+phase,source=XRDLegacy_OriginalPath(XRDLegacy_WavePath(key,"tt"))
    Variable index=XRD80_FindIdenticalReference(card,"",phase,"",source,tt,ii,hh,kk,ll,dd)
    if(index>0)
        return index
    endif
    for(i=0;i<n;i+=1)
        if(numtype(tt[i]) || numtype(ii[i]) || tt[i]<=0 || tt[i]>=180 || ii[i]<0)
            return -1
        endif
    endfor
    NVAR count=$(XRD80_Library()+":referenceCount")
    index=count+1
    String path=XRD_ReferencePath(index)
    if(DataFolderExists(path))
        return -1
    endif
    NewDataFolder $path
    Duplicate tt,$(path+":twoTheta")
    Duplicate ii,$(path+":intensity")
    Duplicate hh,$(path+":h")
    Duplicate kk,$(path+":k")
    Duplicate ll,$(path+":l")
    Duplicate dd,$(path+":d")
    String/G $(path+":cardNumber")=card
    String/G $(path+":phaseName")=phase
    String/G $(path+":formula")=""
    String/G $(path+":phaseClass")=""
    String/G $(path+":source")=source
    String/G $(path+":fileName")=ParseFilePath(0,StrVarOrDefault(XRDLegacy_Base()+":source",""),":",1,0)
    String/G $(path+":importPolicy")="legacy PXP reference; original reflection order"
    Variable/G $(path+":enabled")=1
    WaveStats/Q ii
    Variable/G $(path+":intensityMaximum")=V_max
    XRD80_StampReference(path,"")
    count=index
    XRD100_ReferenceAliases(index)
    XRD_StyleIndex(index)
    return index
End

Function/S XRDLegacy_Previous(project,file,origin)
    String project,file,origin
    String list=XRD_MeasurementOrderList(project),path
    Variable i
    for(i=0;i<ItemsInList(list);i+=1)
        path=project+":Measurements:"+StringFromList(i,list)
        if(cmpstr(StrVarOrDefault(path+":legacyFile",""),file)==0 && cmpstr(StrVarOrDefault(path+":legacyWave",""),origin)==0)
            return path
        endif
    endfor
    return ""
End

Function XRDLegacy_Apply(key,number,composition,label,[withEvidence])
    String key,number,composition,label
    Variable withEvidence
    if(ParamIsDefault(withEvidence))
        withEvidence=1
    endif
    String base=XRDLegacy_Base(),project=XRD_Project(),file=StrVarOrDefault(base+":source","")
    if(!strlen(project) || !strlen(file) || !XRD100_ValidPart(composition) || !strlen(label))
        return -1
    endif
    Wave/Z xx=$XRDLegacy_WavePath(key,"tt"),yy=$XRDLegacy_WavePath(key,"int")
    if(!XRDLegacy_ValidXY(xx,yy))
        return -1
    endif
    String origin=XRDLegacy_OriginalPath(XRDLegacy_WavePath(key,"int"))
    String path=XRDLegacy_Previous(project,file,origin)
    if(strlen(path) && NumVarOrDefault(path+":legacyDone",0))
        return -2
    endif
    if(!XRD110_SerialAvailable(project,path,number))
        return -3
    endif
    XRDLegacy_Preview(key)
    if(!strlen(path))
        path=XRD_Store(xx,yy,file)
        String/G $(path+":legacyFile")=file
        String/G $(path+":legacyWave")=origin
        String/G $(path+":legacyAngleWave")=XRDLegacy_OriginalPath(XRDLegacy_WavePath(key,"tt"))
    endif
    String uid=XRD80_MeasurementUID(path)
    if(cmpstr(StrVarOrDefault(path+":sampleNumber",""),number)!=0 || cmpstr(StrVarOrDefault(path+":composition",""),composition)!=0 || cmpstr(StrVarOrDefault(path+":displayName",""),label)!=0)
        Variable sampleResult=XRD100_SetSample(path,number,composition,label)
        if(sampleResult<0)
            Print "Sample registration error:",sampleResult
            return -4
        endif
    endif
    path=XRD80_ResolveMeasurement(uid)
    Wave/T preview=$(base+":preview")
    Wave rows=$(base+":rows")
    Variable i,point,reflection,ref,added=0,oldCount=NumVarOrDefault(XRD80_Library()+":referenceCount",0)
    for(i=0;i<DimSize(rows,0);i+=1)
        if(!withEvidence)
            if(cmpstr(preview[i][4],"移行候補")==0 || StringMatch(preview[i][4],"ピークのみ*"))
                preview[i][4]="測定曲線のみ登録（選択）"
            endif
            continue
        endif
        if(StringMatch(preview[i][4],"ピークのみ*"))
            XRD_AddPoint(path,rows[i][0],"Legacy")
            continue
        endif
        if(cmpstr(preview[i][4],"移行候補")!=0)
            continue
        endif
        point=rows[i][0]
        reflection=rows[i][1]
        ref=XRDLegacy_Reference(preview[i][5])
        if(ref<1)
            XRD_AddPoint(path,point,"Legacy")
            preview[i][4]="ピークのみ（参照カードを作成できない）"
            continue
        endif
        if(XRDLegacy_Assign(path,point,ref,reflection))
            added+=1
        endif
        preview[i][4]="登録済み"
    endfor
    Duplicate/O preview,$(path+":legacyEvidence")
    Wave/T evidence=$(path+":legacyEvidence")
    evidence[][5]=XRDLegacy_OriginalPath(evidence[p][5])
    Duplicate/O rows,$(path+":legacyEvidenceRows")
    Variable/G $(path+":legacyDone")=1
    if(NumVarOrDefault(XRD80_Library()+":referenceCount",0)!=oldCount)
        XRD80_LibraryChanged()
    endif
    XRD_RefreshAssignmentTable(path)
    XRD_PeakTable(path)
    XRD_UpdateAssignedPlot(path)
    XRD_UpdateAnalysisState(path)
    XRD100_RefreshNamed(project)
    return added
End

Function XRDLegacy_Assign(path,point,ref,reflection)
    String path
    Variable point,ref,reflection
    XRD_AddPoint(path,point,"Legacy")
    Wave indices=$(path+":Peaks:pointIndex"),ids=$(path+":Peaks:peakID")
    Wave xx=$(path+":Raw:twoTheta"),tt=$(XRD_ReferencePath(ref)+":twoTheta")
    Wave aid=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex")
    Wave refl=$(path+":Assignments:refPeakIndex"),shift=$(path+":Assignments:shift")
    Wave/T mode=$(path+":Assignments:mode"),created=$(path+":Assignments:created")
    Variable i,id=-1,overlap=0,n=numpnts(aid)
    for(i=0;i<numpnts(indices);i+=1)
        if(indices[i]==point)
            id=ids[i]
            break
        endif
    endfor
    if(id<0)
        return 0
    endif
    for(i=0;i<n;i+=1)
        if(refs[i]==ref && refl[i]==reflection)
            return 0
        endif
        overlap=overlap || aid[i]==id
    endfor
    Redimension/N=(n+1) aid,refs,refl,shift,mode,created
    aid[n]=id
    refs[n]=ref
    refl[n]=reflection
    shift[n]=xx[point]-tt[reflection]
    mode[n]=SelectString(overlap,"Primary","Overlap")
    created[n]=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    return 1
End

Function XRDLegacy_Open()
    if(WinType("XRDLegacyMigration"))
        DoWindow/F XRDLegacyMigration
        return 0
    endif
    XRD_Init()
    if(!strlen(XRD_Project()))
        DoAlert 0,"先に登録先のプロジェクトを選択してください。"
        return -1
    endif
    Variable ref
    Open/D/R/Z=2/F="Igor Packed Experiment:.pxp;" ref as ""
    if(V_flag || !strlen(S_fileName))
        return -1
    endif
    return XRDLegacy_Panel(S_fileName)
End

Function XRDLegacy_Panel(file)
    String file
    Variable n=XRDLegacy_Load(file)
    if(n<1)
        XRDLegacy_Clear()
        DoAlert 0,"読み込める1次元の数値Waveがありません。"
        return -1
    endif
    String base=XRDLegacy_Base()
    Wave/T measurements=$(base+":measurements")
    n=numpnts(measurements)
    String/G $(base+":options")="測定を選択;"
    SVAR options=$(base+":options")
    Variable i
    for(i=0;i<n;i+=1)
        options+=XRDLegacy_OriginalPath(XRDLegacy_WavePath(measurements[i],"int"))+";"
    endfor
    String/G $(base+":projectUID")=XRD80_ProjectUID(XRD_Project())
    String/G $(base+":number")=""
    String/G $(base+":composition")=""
    String/G $(base+":label")=""
    Make/O/T/N=(0,6) $(base+":preview")
    Wave/T preview=$(base+":preview")
    String/G $(base+":key")=""
    NewPanel/N=XRDLegacyMigration/K=1/W=(65,70,1075,655) as "手作業の XRD 実験を取り込む"
    DefaultGUIFont all={"Segoe UI",12,0}
    TitleBox project,pos={16,12},frame=0,title="登録先："+XRD_ProjectDisplayName(XRD_Project())
    PopupMenu measurement,pos={16,40},title="元の測定 Wave",value=#"root:Packages:XRDLegacyMigration:options",proc=XRDLegacy_Select
    Button manual,pos={730,37},size={260,27},title="2θ と強度の Wave を手動選択...",proc=XRDLegacy_ManualButton
    SetVariable number,pos={16,78},size={180,22},title="通し番号",value=$(base+":number")
    SetVariable composition,pos={215,78},size={230,22},title="組成",value=$(base+":composition")
    SetVariable label,pos={465,78},size={510,22},title="表示名",value=$(base+":label")
    TitleBox note,pos={16,113},frame=0,title="角度・強度・hklが一意に一致した行を相同定として登録します。照合結果は測定内に保存します。"
    TitleBox summary,pos={16,140},frame=0,title=""
    ListBox result,pos={16,165},size={975,335},listWave=preview,mode=1,widths={100,85,85,220,285,190}
    CheckBox includeEvidence,pos={16,511},title="照合できたピーク・相も登録",value=1
    Button apply,pos={16,540},size={245,31},title="この測定を登録",proc=XRDLegacy_Commit
    TitleBox status,pos={280,546},frame=0,title=""
    Button close,pos={895,540},size={96,31},title="閉じる",proc=XRDLegacy_CloseButton
    SetWindow XRDLegacyMigration hook(cleanup)=XRDLegacy_Close
    if(n>0)
        PopupMenu measurement,win=XRDLegacyMigration,mode=2
        XRDLegacy_SelectRow(0)
    else
        TitleBox status,win=XRDLegacyMigration,title="Wave を手動で選択してください。"
    endif
    return n
End

Function XRDLegacy_SelectRow(row)
    Variable row
    String base=XRDLegacy_Base()
    Wave/T measurements=$(base+":measurements")
    String key=measurements[row],stem
    Wave source=$XRDLegacy_WavePath(key,"int")
    stem=NameOfWave(source)
    String/G $(base+":number")=""
    String/G $(base+":label")=stem[4,inf]
    XRDLegacy_UpdatePreview(key)
    ControlUpdate/W=XRDLegacyMigration number
    ControlUpdate/W=XRDLegacyMigration label
    TitleBox status,win=XRDLegacyMigration,title=""
    return 0
End

Function XRDLegacy_Select(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2 && pa.popNum>=2)
        XRDLegacy_SelectRow(pa.popNum-2)
    endif
    return 0
End

Function XRDLegacy_Commit(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode==2)
        Execute/P/Q "XRDLegacy_CommitNow()"
    endif
    return 0
End

Function XRDLegacy_CommitNow()
    String base=XRDLegacy_Base()
    if(!strlen(StrVarOrDefault(base+":key","")))
        TitleBox status,win=XRDLegacyMigration,title="先に測定 Wave を選択してください。"
        return -1
    endif
    if(cmpstr(StrVarOrDefault(base+":projectUID",""),XRD80_ProjectUID(XRD_Project()))!=0)
        DoAlert 0,"登録先が変わりました。移行画面を開き直してください。"
        return -1
    endif
    ControlInfo/W=XRDLegacyMigration includeEvidence
    Variable n=XRDLegacy_Apply(StrVarOrDefault(base+":key",""),TrimString(StrVarOrDefault(base+":number","")),TrimString(StrVarOrDefault(base+":composition","")),TrimString(StrVarOrDefault(base+":label","")),withEvidence=V_value)
    String message
    switch(n)
        case -4:
            message="登録情報を保存できませんでした。測定を保持しています。"
            break
        case -3:
            message="通し番号が空欄か、登録先で重複しています。"
            break
        case -2:
            message="同じファイルの同じ測定は登録済みです。"
            break
        case -1:
            message="測定、組成、表示名を確認してください。"
            break
        default:
            message="測定を登録。相同定 "+num2istr(n)+" 件。"
            if(WinType("XRDWorkbench"))
                XRD_Panel()
                DoWindow/F XRDLegacyMigration
            endif
    endswitch
    TitleBox status,win=XRDLegacyMigration,title=message
    return n
End

Function XRDLegacy_Close(s)
    STRUCT WMWinHookStruct &s
    if(s.eventCode==2)
        Execute/P/Q "XRDLegacy_Clear()"
    endif
    return 0
End

Function XRDLegacy_Clear()
    if(WinType("XRDLegacyMigration"))
        return 0
    endif
    DoWindow/K XRDLegacyManual
    String base=XRDLegacy_Base()
    KillDataFolder/Z $base
    return 0
End


Function XRDLegacy_ManualButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String base=XRDLegacy_Base()
    Wave/T paths=$(base+":numericWaves")
    String/G $(base+":manualOptions")="選択;"
    SVAR options=$(base+":manualOptions")
    Variable i
    for(i=0;i<numpnts(paths);i+=1)
        options+=XRDLegacy_OriginalPath(paths[i])+";"
    endfor
    DoWindow/K XRDLegacyManual
    NewPanel/N=XRDLegacyManual/K=1/W=(90,100,840,280) as "測定 Wave の指定"
    DefaultGUIFont all={"Segoe UI",12,0}
    PopupMenu angles,pos={16,16},title="2θ（度）",value=#"root:Packages:XRDLegacyMigration:manualOptions"
    PopupMenu intensities,pos={16,50},title="強度",value=#"root:Packages:XRDLegacyMigration:manualOptions"
    TitleBox note,pos={16,85},frame=0,title="同じ点数の Wave を選択。手動指定は測定曲線を登録します。"
    Button use,pos={16,119},size={220,28},title="この組を使う",proc=XRDLegacy_ManualSelect
    return 0
End

Function XRDLegacy_ManualSelect(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    ControlInfo/W=XRDLegacyManual angles
    Variable x=V_value-2
    ControlInfo/W=XRDLegacyManual intensities
    Variable y=V_value-2
    String base=XRDLegacy_Base()
    Wave/T paths=$(base+":numericWaves")
    if(x<0 || y<0 || x==y || x>=numpnts(paths) || y>=numpnts(paths))
        DoAlert 0,"角度と強度の Wave を1本ずつ選択してください。"
        return -1
    endif
    Wave xx=$paths[x],yy=$paths[y]
    if(!XRDLegacy_ValidXY(xx,yy))
        DoAlert 0,"2θ が増加し、点数が等しい有限値の Wave を選んでください。"
        return -1
    endif
    String/G $(base+":manual_tt")=paths[x]
    String/G $(base+":manual_int")=paths[y]
    String/G $(base+":label")=NameOfWave(yy)
    String/G $(base+":number")=""
    XRDLegacy_UpdatePreview(base+":Manual")
    PopupMenu measurement,win=XRDLegacyMigration,mode=1
    ControlUpdate/W=XRDLegacyMigration label
    ControlUpdate/W=XRDLegacyMigration number
    TitleBox status,win=XRDLegacyMigration,title="手動選択："+NameOfWave(yy)
    DoWindow/K XRDLegacyManual
    return 0
End

Function XRDLegacy_ShowEvidence()
    String path=XRD_Data()
    Wave/T/Z evidence=$(path+":legacyEvidence")
    if(!WaveExists(evidence))
        DoAlert 0,"選択中の測定に移行記録がありません。"
        return -1
    endif
    DoWindow/K XRDLegacyEvidence
    NewPanel/N=XRDLegacyEvidence/K=1/W=(90,100,1100,560) as "手作業 XRD の移行記録"
    DefaultGUIFont all={"Segoe UI",12,0}
    TitleBox source,pos={16,16},frame=0,title=StrVarOrDefault(path+":legacyWave","")
    ListBox result,pos={16,48},size={975,380},listWave=evidence,mode=1,widths={100,85,85,220,285,190}
    return 0
End


Function XRDLegacy_UpdatePreview(key)
    String key
    String base=XRDLegacy_Base()
    XRDLegacy_Preview(key)
    Wave/T preview=$(base+":preview")
    Wave xx=$XRDLegacy_WavePath(key,"tt")
    Variable i,matched=0,peakOnly=0
    for(i=0;i<DimSize(preview,0);i+=1)
        matched+=cmpstr(preview[i][4],"移行候補")==0
        peakOnly+=StringMatch(preview[i][4],"ピークのみ*")
    endfor
    String summary=num2istr(numpnts(xx))+" 点　|　2θ "+num2str(xx[0])+" ～ "+num2str(xx[numpnts(xx)-1])+"°"
    if(cmpstr(key,base+":Manual")==0)
        summary+="　|　手動選択した測定曲線"
    else
        summary+="　|　相同定候補 "+num2istr(matched)+" 件　ピークのみ "+num2istr(peakOnly)+" 件"
    endif
    ListBox result,win=XRDLegacyMigration,listWave=preview
    TitleBox summary,win=XRDLegacyMigration,title=summary
    return 0
End

Function XRDLegacy_CloseButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode==2)
        DoWindow/K XRDLegacyMigration
    endif
    return 0
End
