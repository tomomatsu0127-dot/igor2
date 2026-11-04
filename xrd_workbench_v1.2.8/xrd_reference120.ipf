#pragma rtGlobals=3
// v1.2.0: warn about the two strongest reference reflections; no auto-rejection.
Function/S XRD120_StrongMissing(path,index,shift)
    String path
    Variable index,shift
    String rp=XRD_ReferencePath(index),out="",kind
    Wave/Z rx=$(rp+":twoTheta"),ri=$(rp+":intensity"),raw=$(path+":Raw:twoTheta"),measured=$(path+":Peaks:angle")
    if(!WaveExists(rx) || !WaveExists(ri) || !WaveExists(raw) || !numpnts(ri))
        return ""
    endif
    Duplicate/FREE ri,weights
    Make/FREE/D/N=(numpnts(ri)) order=p
    Sort/R weights,weights,order
    Variable i,j,target,found,tol=NumVarOrDefault(XRD80_ProjectForMeasurement(path)+":matchTolerance",0.2)
    for(i=0;i<min(2,numpnts(order));i+=1)
        target=rx[order[i]]+shift
        if(target<raw[0] || target>raw[numpnts(raw)-1] || ri[order[i]]<=0)
            continue
        endif
        found=0
        for(j=0;j<numpnts(measured);j+=1)
            if(abs(measured[j]-target)<=tol)
                found=1
                break
            endif
        endfor
        if(!found)
            kind=SelectString(i==0,"第2ピーク","主ピーク")
            if(strlen(out))
                out+="・"
            endif
            out+=kind+"("+num2str(target)+"°)"
        endif
    endfor
    return out
End

Function/S XRD120_WarningKey(path,index,shift)
    String path
    Variable index,shift
    return StrVarOrDefault(XRD_ReferencePath(index)+":revisionUID",num2istr(index))+"|"+XRD_ExactNumber(shift)+"|"+XRD120_StrongMissing(path,index,shift)
End

Function XRD120_ConfirmCandidate(path,row)
    String path
    Variable row
    Wave refs=$(path+":Candidates:refIndex"),shifts=$(path+":Candidates:shift")
    if(row<0 || row>=numpnts(refs))
        return 1
    endif
    String missing=XRD120_StrongMissing(path,refs[row],shifts[row]),key=XRD120_WarningKey(path,refs[row],shifts[row]),ack=StrVarOrDefault(path+":acknowledgedStrong120","")
    if(!strlen(missing) || WhichListItem(key,ack)>=0)
        return 1
    endif
    DoAlert 1,XRD_PhaseLabel(refs[row])+" の "+missing+" に一致する登録済み測定ピークがありません。\r主・第2ピークが見えていない可能性があります。この参照で採用して大丈夫ですか？\r\r配向、弱い信号、未登録ピークなども考えられます。他相に割り当て済みでも同じ角度に測定ピークがあれば一致としています。"
    if(V_flag!=1)
        return 0
    endif
    if(ItemsInList(ack)>=30)
        ack=RemoveListItem(0,ack)
    endif
    String/G $(path+":acknowledgedStrong120")=ack+key+";"
    return 1
End

Function XRD120_UpdateWarning(path)
    String path
    if(!WinType("XRDWorkbench") || !strlen(path) || NumVarOrDefault(XRD_Project()+":activeStep",1)!=3)
        return 0
    endif
    ControlInfo/W=XRDWorkbench strongNotice120
    if(!V_flag)
        return 0
    endif
    Wave/Z refs=$(path+":Assignments:refIndex"),shifts=$(path+":Assignments:shift")
    Variable index=NumVarOrDefault(path+":Preview:referenceIndex",0),shift=NumVarOrDefault(path+":Preview:shift",0),i,n=0
    String missing="",text="",seen=""
    if(index>0)
        missing=XRD120_StrongMissing(path,index,shift)
        seen=num2istr(index)+";"
        if(strlen(missing))
            text=XRD_PhaseLabel(index)+"："+missing+" 未確認";n+=1
        endif
    endif
    if(WaveExists(refs))
        for(i=0;i<numpnts(refs);i+=1)
            if(refs[i]<=0 || WhichListItem(num2istr(refs[i]),seen)>=0)
                continue
            endif
            seen+=num2istr(refs[i])+";"
            missing=XRD120_StrongMissing(path,refs[i],shifts[i])
            if(strlen(missing))
                if(strlen(text))
                    text+=" / "
                endif
                text+=XRD_PhaseLabel(refs[i])+"："+missing+" 未確認";n+=1
                if(n>=2)
                    break
                endif
            endif
        endfor
    endif
    if(n)
        TitleBox strongNotice120,win=XRDWorkbench,title="確認："+text+"\r未登録・配向等も考慮し、候補の根拠で全体を確認してください。",fColor=(42000,16000,0),help={text}
    else
        TitleBox strongNotice120,win=XRDWorkbench,title="主・第2参照ピーク：測定範囲内の登録ピークと照合します。",fColor=(10000,16000,22000)
    endif
    return n
End
