#pragma rtGlobals=3

Function XRD143_UpgradePatternRange(path)
    String path
    String win="XRDWorkbench#Pattern"
    if(NumVarOrDefault(XRD_Project()+":activeStep",1)!=3 || NumVarOrDefault(path+":patternRange143",0))
        return 0
    endif
    GetAxis/W=$win/Q left
    if(abs(V_min+30)<1e-8 && abs(V_max-110)<1e-8)
        XRD143_DefaultRange(win,0)
    endif
    Variable/G $(path+":patternRange143")=1
End

Function XRD143_ResetReferenceName(index,draft)
    Variable index
    String draft
    String rp=XRD_ReferencePath(index),keys="phaseName;phaseClass;formula",key
    if(!DataFolderExists(rp) || !DataFolderExists(draft))
        return -1
    endif
    String/G $(draft+":displayOverride")=""
    Variable i
    for(i=0;i<ItemsInList(keys);i+=1)
        key=StringFromList(i,keys)
        String/G $(draft+":"+key)=StrVarOrDefault(rp+":origin_"+key,StrVarOrDefault(rp+":"+key,""))
    endfor
    return 0
End

Function XRD143_StyleResetButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2 || cmpstr(GetUserData(ba.win,"","XRDProject"),XRD_Project())!=0)
        return 0
    endif
    Variable index=str2num(GetUserData(ba.win,"","XRDRef"))
    String rp=XRD_ReferencePath(index)
    if(XRD143_ResetReferenceName(index,rp)<0)
        return -1
    endif
    String/G $(rp+":typeOverride")="自動"
    return XRD143_RefreshReferenceStyle(index)
End

Function XRD143_SameReflection(ref,reflection,otherRef,otherReflection)
    Variable ref,reflection,otherRef,otherReflection
    if(ref==otherRef)
        return reflection==otherReflection
    endif
    String rp=XRD_ReferencePath(ref),other=XRD_ReferencePath(otherRef),uid=StrVarOrDefault(rp+":refUID","")
    if(!strlen(uid) || cmpstr(uid,StrVarOrDefault(other+":refUID",""))!=0)
        return 0
    endif
    Wave/Z h=$(rp+":h"),k=$(rp+":k"),l=$(rp+":l"),oh=$(other+":h"),ok=$(other+":k"),ol=$(other+":l")
    if(!WaveExists(h) || !WaveExists(k) || !WaveExists(l) || !WaveExists(oh) || !WaveExists(ok) || !WaveExists(ol))
        return 0
    endif
    if(reflection<0 || otherReflection<0 || reflection>=numpnts(h) || otherReflection>=numpnts(oh))
        return 0
    endif
    if(numtype(h[reflection]+k[reflection]+l[reflection]+oh[otherReflection]+ok[otherReflection]+ol[otherReflection]))
        Wave/Z angles=$(rp+":twoTheta"),otherAngles=$(other+":twoTheta")
        return WaveExists(angles) && WaveExists(otherAngles) && abs(angles[reflection]-otherAngles[otherReflection])<1e-6
    endif
    return h[reflection]==oh[otherReflection] && k[reflection]==ok[otherReflection] && l[reflection]==ol[otherReflection]
End

Function/S XRD143_AssignmentConflicts(path,angle,ref,reflection)
    String path
    Variable angle,ref,reflection
    String project=XRD80_ProjectForMeasurement(path)
    if(!strlen(project) || ref<=0 || numtype(angle))
        return ""
    endif
    DFREF samples=$(project+":Measurements")
    String name,sample,message="",label
    Variable i=0,j,count=0,tolerance=max(0,NumVarOrDefault(project+":matchTolerance",0.2)),row
    do
        name=GetIndexedObjNameDFR(samples,4,i)
        if(!strlen(name))
            break
        endif
        i+=1
        sample=project+":Measurements:"+PossiblyQuoteName(name)
        if(cmpstr(sample,path)==0 || NumVarOrDefault(sample+":deleted",0))
            continue
        endif
        Wave/Z angles=$(sample+":Peaks:angle"),ids=$(sample+":Peaks:peakID")
        Wave/Z assigned=$(sample+":Assignments:peakID"),refs=$(sample+":Assignments:refIndex"),refPeaks=$(sample+":Assignments:refPeakIndex")
        if(!WaveExists(angles) || !WaveExists(ids) || !WaveExists(assigned) || !WaveExists(refs) || !WaveExists(refPeaks))
            continue
        endif
        for(j=0;j<numpnts(angles);j+=1)
            if(numtype(angles[j]) || abs(angles[j]-angle)>tolerance)
                continue
            endif
            for(row=0;row<numpnts(assigned);row+=1)
                if(assigned[row]!=ids[j] || refs[row]<=0 || XRD143_SameReflection(ref,reflection,refs[row],refPeaks[row]))
                    continue
                endif
                if(count<5)
                    label=XRD_ReferencePath(refs[row])
                    if(DataFolderExists(label))
                        message+="\r"+XRD110_SampleLabel(sample)+"　"+num2str(angles[j])+"°　"+XRD_AssignmentSummary(sample,ids[j])
                    endif
                endif
                count+=1
                break
            endfor
        endfor
    while(1)
    if(count>5)
        message+="\rほか "+num2istr(count-5)+" 件"
    endif
    return message
End

Function XRD143_ConfirmAssignment(path,peakRow,candidateRow)
    String path
    Variable peakRow,candidateRow
    Wave/Z angles=$(path+":Peaks:angle"),refs=$(path+":Candidates:refIndex"),refPeaks=$(path+":Candidates:refPeakIndex")
    if(!WaveExists(angles) || !WaveExists(refs) || !WaveExists(refPeaks) || peakRow<0 || peakRow>=numpnts(angles) || candidateRow<0 || candidateRow>=numpnts(refs))
        return 1
    endif
    String conflicts=XRD143_AssignmentConflicts(path,angles[peakRow],refs[candidateRow],refPeaks[candidateRow])
    if(!strlen(conflicts))
        return 1
    endif
    String tolerance=num2str(NumVarOrDefault(XRD80_ProjectForMeasurement(path)+":matchTolerance",0.2))
    return XRD124_Alert(1,"同じプロジェクトの別試料に異なる同定があります（±"+tolerance+"°）。\r採用する候補："+num2str(angles[peakRow])+"°　"+XRD_PhaseLabel(refs[candidateRow])+conflicts+"\r\rこの候補を採用しますか？")==1
End
