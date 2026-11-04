#pragma rtGlobals=3
// XRD Workbench v1.2.0. Shared reference loading; immutable scientific revisions.

Function XRD_ChooseReference()
    XRD80_InitLibrary()
    if(XRD124_Alert(1,"参照データを共通ライブラリへ追加しますか？ 取り込み後に表示名・分類を編集できます。")!=1)
        return -1
    endif
    String project=XRD80_Library()
    XRD_RestoreReferencePath(project)
    if(XRD124_ReferenceFolder()!=0)
        return -1
    endif
    PathInfo XRDReferencePath
    SVAR hint=$(project+":referenceFolderHint")
    hint=S_path
    Variable result=XRD_LoadReferences()
    if(result>=0)
        XRD80_LibraryPanel()
    endif
    return result
End

Function XRD_LoadReferences()
    XRD80_InitLibrary()
    String project=XRD80_Library(),files,fileName,errorList=""
    NVAR storedCount=$(project+":referenceCount")
    Variable i,count=0,errors=0,result
    XRD_RestoreReferencePath(project)
    PathInfo/S XRDReferencePath
    if(V_flag==0)
        Print "XRD: 参照フォルダが選択されていません。"
        return -1
    endif
    Make/O/T/N=(0,2) $(project+":References:errors")
    files=IndexedFile(XRDReferencePath,-1,".txt")+IndexedFile(XRDReferencePath,-1,".csv")+IndexedFile(XRDReferencePath,-1,".tsv")+IndexedFile(XRDReferencePath,-1,".dat")
    files=SortList(files,";",16)
    if(ItemsInList(files)==0)
        SVAR emptySummary=$(project+":referenceLoadSummary")
        emptySummary="TXTファイルがありません"
        NVAR emptyCount=$(project+":referenceCount")
        // Keep the cached references and assignments when a folder is empty.
        return -2
    endif
    for(i=0;i<ItemsInList(files);i+=1)
        fileName=StringFromList(i,files)
        result=XRD_LoadReferenceFile(fileName,storedCount+1)
        if(result==0)
            count+=1
        else
            errors+=1
            errorList+=fileName+";"
        endif
    endfor
    NVAR referenceCount=$(project+":referenceCount"),errorCount=$(project+":referenceErrorCount")
    SVAR summary=$(project+":referenceLoadSummary")
    // Loader increments the persistent count only for new cards.
    errorCount=errors
    summary=num2istr(count)+"件読込 / "+num2istr(errors)+"件エラー"
    XRD_InvalidateFilterCandidates()
    XRD80_SyncReferenceCounts()
    XRD_RebuildReferenceTable(XRD_Project())
    Print "XRD参照データ: "+summary
    if(errors>0)
        Print "読込できなかったファイル: "+errorList
    endif
    return count
End

Function XRD_LoadReferenceFile(fileName,refIndex)
    String fileName
    Variable refIndex
    XRD80_InitLibrary()
    String project=XRD80_Library(),rootPath=project+":References:Ref"+num2istr(refIndex)
    Variable ref,lineNo=0,headerSeen=0,n=0,lv,kv,hv,iv,tv,dv,parsed,columnCount
    String line,key,value,card="",formula="",phaseName="",phaseClass="",source="",errorText=""
    Open/R/P=XRDReferencePath/Z=2 ref as fileName
    if(V_flag!=0)
        XRD_ReferenceError(fileName,"ファイルを開けません")
        Print "XRD参照ファイルを開けません: "+fileName
        return -1
    endif
    Make/FREE/D/N=128 ll,kk,hh,intensities,twoTheta,dd
    Make/FREE/D/N=6 columnMap,rowValues
    do
        FReadLine ref,line
        if(strlen(line)==0)
            break
        endif
        lineNo+=1
        if(lineNo==1)
            line=ReplaceString(num2char(239)+num2char(187)+num2char(191),line,"")
        endif
        line=TrimString(line)
        if(strlen(line)==0)
            continue
        endif
        if(StringMatch(line,"#*") || StringMatch(line,"!*") || StringMatch(line,"//*"))
            if(XRD_ParseMetadata(line,key,value))
                strswitch(LowerStr(key))
                    case "card_number":
                        card=value
                        break
                    case "formula":
                        formula=value
                        break
                    case "name":
                        phaseName=value
                        break
                    case "phase_class":
                        phaseClass=value
                        break
                    case "source":
                        source=value
                        break
                endswitch
            endif
            if(!headerSeen && XRD_MapReferenceHeader(line[1,inf],columnMap,errorText)>0)
                columnCount=XRD_MapReferenceHeader(line[1,inf],columnMap,errorText)
                headerSeen=1
            endif
            errorText=""
            continue
        endif
        if(!headerSeen)
            columnCount=XRD_MapReferenceHeader(line,columnMap,errorText)
            if(columnCount<0)
                errorText+=" (行 "+num2istr(lineNo)+")"
                break
            endif
            headerSeen=1
            continue
        endif
        parsed=XRD_ParseMappedReferenceRow(line,columnCount,columnMap,rowValues,errorText)
        if(parsed!=1)
            errorText+=" (行 "+num2istr(lineNo)+")"
            break
        endif
        lv=rowValues[0];kv=rowValues[1];hv=rowValues[2]
        iv=rowValues[3];tv=rowValues[4];dv=rowValues[5]
        if(n==numpnts(ll))
            Redimension/N=(n+128) ll,kk,hh,intensities,twoTheta,dd
        endif
        ll[n]=lv
        kk[n]=kv
        hh[n]=hv
        intensities[n]=iv
        twoTheta[n]=tv
        dd[n]=dv
        n+=1
    while(1)
    Close ref
    if(strlen(errorText)==0 && !headerSeen)
        errorText="列名がありません"
    endif
    // Cards use the filename when optional metadata is absent.
    // Unknown formulas remain unknown; never invent a chemical composition.
    if(strlen(card)==0)
        card="FILE:"+fileName
    endif
    if(strlen(phaseName)==0)
        phaseName=fileName
    endif
    if(strlen(errorText)==0 && n==0)
        errorText="参照ピークがありません"
    endif
    if(strlen(errorText))
        XRD_ReferenceError(fileName,errorText)
        Print "XRD参照TXTを拒否: "+fileName+" - "+errorText
        return -2
    endif
    Redimension/N=(n) ll,kk,hh,intensities,twoTheta,dd
    Sort twoTheta,twoTheta,intensities,hh,kk,ll,dd
    NVAR existingCount=$(project+":referenceCount")
    Variable existing=XRD80_FindIdenticalReference(card,formula,phaseName,phaseClass,source,twoTheta,intensities,hh,kk,ll,dd)
    if(existing>0)
        XRD100_ReferenceAliases(existing)
        Print "同一内容の参照を保持: "+card+" (表示名・使用設定は変更しません)"
        return 0
    endif
    refIndex=existingCount+1
    rootPath=project+":References:Ref"+num2istr(refIndex)
    NewDataFolder/O $rootPath
    Duplicate/O twoTheta,$(rootPath+":twoTheta")
    Duplicate/O intensities,$(rootPath+":intensity")
    Duplicate/O hh,$(rootPath+":h")
    Duplicate/O kk,$(rootPath+":k")
    Duplicate/O ll,$(rootPath+":l")
    Duplicate/O dd,$(rootPath+":d")
    String/G $(rootPath+":cardNumber")=card
    String/G $(rootPath+":formula")=formula
    String/G $(rootPath+":phaseName")=phaseName
    String/G $(rootPath+":phaseClass")=phaseClass
    String/G $(rootPath+":source")=source
    String/G $(rootPath+":fileName")=fileName
    String/G $(rootPath+":importPolicy")="v1.2.0 named columns; shared immutable scientific data"
    Variable/G $(rootPath+":enabled")=1
    Wave storedI=$(rootPath+":intensity")
    WaveStats/Q storedI
    Variable/G $(rootPath+":intensityMaximum")=V_max
    existingCount=refIndex
    XRD80_StampReference(rootPath,"")
    XRD100_ReferenceAliases(refIndex)
    XRD80_SyncReferenceCounts()
    XRD_StyleIndex(refIndex)
    return 0
End

Function XRD_ParseMetadata(line,key,value)
    String line
    String &key,&value
    Variable colon=strsearch(line,":",0)
    if(colon<0)
        return 0
    endif
    key=TrimString(line[1,colon-1])
    value=TrimString(line[colon+1,inf])
    return strlen(key)>0
End

Function/S XRD_NormalizeSpaces(text)
    String text
    text=ReplaceString("\t",text," ")
    do
        if(strsearch(text,"  ",0)<0)
            break
        endif
        text=ReplaceString("  ",text," ")
    while(1)
    return TrimString(text)
End

Function XRD_ParseReferenceRow(line,lv,kv,hv,iv,tv,dv)
    String line
    Variable &lv,&kv,&hv,&iv,&tv,&dv
    Make/FREE/D/N=6 map={0,1,2,3,4,5},values
    String errorText=""
    if(XRD_ParseMappedReferenceRow(line,6,map,values,errorText)!=1)
        return -1
    endif
    lv=values[0];kv=values[1];hv=values[2]
    iv=values[3];tv=values[4];dv=values[5]
    return 1
End

// Map named columns to the existing internal l/k/h/intensity/angle/d waves.
// Keep XRD_ParseReferenceRow for callers of the legacy six-column helper.
Function XRD_MapReferenceHeader(line,columnMap,errorText)
    String line
    Wave columnMap
    String &errorText
    String header=XRD_ReferenceHeader(line)
    String token,required="l;k;h;intensity;2theta"
    Variable i,index,count=ItemsInList(header," ")
    columnMap=-1
    errorText=""
    for(i=0;i<count;i+=1)
        token=StringFromList(i,header," ")
        index=-1
        strswitch(token)
            case "l":
                index=0
                break
            case "k":
                index=1
                break
            case "h":
                index=2
                break
            case "i":
            case "int":
            case "intensity":
            case "rel_intensity":
            case "i_rel":
            case "i(%)":
                index=3
                break
            case "tt":
            case "2theta":
            case "two_theta":
            case "twotheta":
            case "2-theta":
            case "tth":
                index=4
                break
            case "d":
            case "d_spacing":
            case "d-spacing":
                index=5
                break
        endswitch
        if(index<0)
            // Ignore additional named columns, never infer I from |F| or M.
            continue
        endif
        if(columnMap[index]>=0)
            errorText="列名が重複しています: "+token
            return -1
        endif
        columnMap[index]=i
    endfor
    for(i=0;i<5;i+=1)
        if(columnMap[i]<0)
            errorText="必要な列がありません: "+StringFromList(i,required)
            return -1
        endif
    endfor
    return count
End

Function XRD_ParseMappedReferenceRow(line,columnCount,columnMap,values,errorText)
    String line
    Variable columnCount
    Wave columnMap,values
    String &errorText
    String normalized=XRD_ReferenceDataLine(line),token
    String number="^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$"
    Variable i,value
    values=NaN
    errorText=""
    if(ItemsInList(normalized," ")!=columnCount)
        errorText="列数がヘッダーと一致しません: 必要 "+num2istr(columnCount)+"列 / 実際 "+num2istr(ItemsInList(normalized," "))+"列"
        return -1
    endif
    for(i=0;i<6;i+=1)
        if(columnMap[i]<0)
            continue
        endif
        token=StringFromList(columnMap[i],normalized," ")
        // Only Miller-index columns accept explicit missing tokens.
        if(i<3 && (cmpstr(token,"-")==0 || cmpstr(LowerStr(token),"none")==0))
            continue
        endif
        value=str2num(token)
        if(!GrepString(token,number) || numtype(value)!=0)
            errorText="数値を読めません: "+num2istr(columnMap[i]+1)+"列目 ('"+token+"')"
            return -1
        endif
        values[i]=value
    endfor
    for(i=0;i<3;i+=1)
        if(numtype(values[i])==0 && values[i]!=round(values[i]))
            errorText="h、k、lは整数が必要です"
            return -1
        endif
    endfor
    if(values[3]<0)
        errorText="強度は0以上が必要です"
        return -1
    endif
    if(values[4]<=0 || values[4]>=180)
        errorText="2thetaは0より大きく180未満が必要です"
        return -1
    endif
    if(columnMap[5]>=0 && values[5]<=0)
        errorText="dは0より大きい値が必要です"
        return -1
    endif
    // An absent d column remains NaN; it is not inferred from a wavelength.
    return 1
End

Function XRD_RebuildReferenceTable(project)
    String project
    NVAR count=$(project+":referenceCount")
    Wave/T table=$(project+":References:table")
    Redimension/N=(count,6) table
    SetDimLabel 1,0,Phase,table
    SetDimLabel 1,1,Card,table
    SetDimLabel 1,2,Class,table
    SetDimLabel 1,3,Name,table
    SetDimLabel 1,4,File,table
    SetDimLabel 1,5,Index,table
    Variable i
    String path
    for(i=0;i<count;i+=1)
        path=XRD_ReferencePath(i+1)
        SVAR card=$(path+":cardNumber"),phaseName=$(path+":phaseName"),formula=$(path+":formula"),phaseClass=$(path+":phaseClass"),fileName=$(path+":fileName")
        table[i][0]=XRD_PhaseLabel(i+1)
        table[i][1]=card
        table[i][2]=phaseClass
        table[i][3]=phaseName
        table[i][4]=fileName
        table[i][5]=num2istr(i+1)
    endfor
    if(cmpstr(project,XRD80_Library())!=0)
        Duplicate/O table,$(XRD80_Library()+":References:table")
    endif
End

Function/S XRD_ReferencePath(refIndex)
    Variable refIndex
    return XRD80_Library()+":References:Ref"+num2istr(refIndex)
End

Function XRD_ClassProtected(phaseClass)
    String phaseClass
    if(strlen(phaseClass)==0)
        return 0
    endif
    SVAR protected=$(XRD_Project()+":protectedClasses")
    Variable i
    for(i=0;i<ItemsInList(protected);i+=1)
        if(cmpstr(LowerStr(TrimString(StringFromList(i,protected))),LowerStr(TrimString(phaseClass)))==0)
            return 1
        endif
    endfor
    return 0
End

Function XRD_FormulaCompatible(formula,phaseClass)
    String formula,phaseClass
    String project=XRD_Project(),symbol,allowedLower
    NVAR mode=$(project+":elementFilterMode")
    SVAR allowed=$(project+":allowedElements")
    if(mode==0 || strlen(TrimString(allowed))==0 || XRD_ClassProtected(phaseClass))
        return 1
    endif
    allowedLower=";"+LowerStr(ReplaceString(" ",allowed,""))+";"
    Variable i=0,n=strlen(formula),c,next,incompatible=0
    do
        if(i>=n)
            break
        endif
        c=char2num(formula[i])
        if(c>=65 && c<=90)
            symbol=formula[i]
            if(i+1<n)
                next=char2num(formula[i+1])
                if(next>=97 && next<=122)
                    symbol+=formula[i+1]
                    i+=1
                endif
            endif
            if(WhichListItem(symbol,XRD_PeriodicSymbols())<0)
                return 1
            endif
            if(strsearch(allowedLower,";"+LowerStr(symbol)+";",0)<0)
                incompatible=1
            endif
        endif
        i+=1
    while(1)
    return !incompatible
End
