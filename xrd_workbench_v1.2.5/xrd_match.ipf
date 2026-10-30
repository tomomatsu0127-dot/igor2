#pragma rtGlobals=3
// XRD Workbench v1.2.0. Transparent, overlap-aware peak search/match.

Function XRD_ScoreCandidates(path,peakRow)
    String path
    Variable peakRow
    XRD_EnsureMeasurement(path)
    Wave measuredX=$(path+":Peaks:angle"),measuredY=$(path+":Peaks:height"),peakIDs=$(path+":Peaks:peakID")
    if(peakRow<0 || peakRow>=numpnts(measuredX))
        return -1
    endif
    String project=XRD_Project(),refPath
    NVAR refCount=$(project+":referenceCount"),tolerance=$(project+":matchTolerance"),maxShift=$(project+":maxCommonShift"),filterMode=$(project+":elementFilterMode")
    if(refCount<=0 || tolerance<=0 || maxShift<0)
        return -2
    endif
    XRD_TypeSettings(project)
    XRD_ResetCandidates(path)
    Wave outRef=$(path+":Candidates:refIndex"),outRefPeak=$(path+":Candidates:refPeakIndex"),outShift=$(path+":Candidates:shift")
    Wave outLocal=$(path+":Candidates:localScore"),outGlobal=$(path+":Candidates:globalScore"),outNew=$(path+":Candidates:newScore"),outIntensity=$(path+":Candidates:intensityScore")
    Wave outMissing=$(path+":Candidates:missingStrong"),outTotal=$(path+":Candidates:totalScore"),outCompatible=$(path+":Candidates:compatible")
    Wave rawX=$(path+":Raw:twoTheta")
    WaveStats/Q measuredY
    Variable measuredMax=max(V_max,1e-12)
    NVAR radius=$(project+":candidateRadius")
    if(numtype(radius)!=0 || radius<0.01 || radius>5)
        return -2
    endif
    Variable refIndex,anchor,j,k,nOut=0,best,bestDelta,shift,residual,localScore
    Variable denom,globalNum,newNum,intensityNum,intensityDen,missing,refMax,refNorm,weight,delta,positionScore,total,compatible,measuredNorm
    for(refIndex=1;refIndex<=refCount;refIndex+=1)
        refPath=XRD_ReferencePath(refIndex)
        if(!DataFolderExists(refPath))
            continue
        endif
        SVAR formula=$(refPath+":formula"),phaseClass=$(refPath+":phaseClass")
        compatible=XRD_FormulaCompatible(formula,XRD_ReferenceType(refIndex))
        if(!compatible || !XRD_CandidateAllowed(path,refIndex))
            continue
        endif
        Wave refX=$(refPath+":twoTheta"),refI=$(refPath+":intensity")
        WaveStats/Q refI
        refMax=max(V_max,1e-12)
        anchor=-1
        bestDelta=inf
        for(j=0;j<numpnts(refX);j+=1)
            delta=abs(measuredX[peakRow]-refX[j])
            if(delta<bestDelta)
                bestDelta=delta
                anchor=j
            endif
        endfor
        if(anchor<0 || bestDelta>radius+maxShift)
            continue
        endif
        shift=XRD_ReferenceShift(path,refIndex)
        if(abs(shift)>maxShift)
            shift=sign(shift)*maxShift
        endif
        Make/FREE/B/U/N=(numpnts(measuredX)) used=0
        Duplicate/FREE refI,sortIntensity
        Make/FREE/D/N=(numpnts(refI)) order=p
        Sort/R sortIntensity,sortIntensity,order
        denom=0
        globalNum=0
        newNum=0
        intensityNum=0
        intensityDen=0
        missing=0
        for(j=0;j<numpnts(order);j+=1)
            k=order[j]
            if(refX[k]+shift<rawX[0] || refX[k]+shift>rawX[numpnts(rawX)-1])
                continue
            endif
            refNorm=100*refI[k]/refMax
            weight=sqrt(max(refNorm,0)/100)
            denom+=weight
            best=XRD_FindMeasuredMatch(measuredX,used,refX[k]+shift,tolerance,bestDelta)
            if(best>=0)
                used[best]=1
                positionScore=100*max(0,1-bestDelta/tolerance)
                globalNum+=weight*positionScore/100
                if(!XRD_PeakExplained(path,peakIDs[best]))
                    newNum+=weight*positionScore/100
                endif
                measuredNorm=100*measuredY[best]/measuredMax
                intensityNum+=weight*max(0,1-abs(measuredNorm-refNorm)/100)
                intensityDen+=weight
            elseif(refNorm>=70)
                missing+=1
            endif
        endfor
        if(denom<=0)
            continue
        endif
        globalNum=100*globalNum/denom
        newNum=100*newNum/denom
        if(intensityDen>0)
            intensityNum=100*intensityNum/intensityDen
        else
            intensityNum=0
        endif
        for(anchor=0;anchor<numpnts(refX);anchor+=1)
            residual=abs(measuredX[peakRow]-(refX[anchor]+shift))
            if(residual>radius)
                continue
            endif
            localScore=100*max(0,1-residual/tolerance)
            // Outside match tolerance remains a visible manual alternative.
            // A common card shift is shared by all reflection alternatives.
        NVAR searchMode=$(path+":candidateMode")
        total=0.30*localScore+0.60*globalNum+0.10*intensityNum-min(15,5*missing)
        if(searchMode==2)
            total=0.30*localScore+0.40*globalNum+0.20*newNum+0.10*intensityNum-min(15,5*missing)
        endif
        total=max(0,min(100,total))
        Redimension/N=(nOut+1) outRef,outRefPeak,outShift,outLocal,outGlobal,outNew,outIntensity,outMissing,outTotal,outCompatible
        outRef[nOut]=refIndex
        outRefPeak[nOut]=anchor
        outShift[nOut]=shift
        outLocal[nOut]=localScore
        outGlobal[nOut]=globalNum
        outNew[nOut]=newNum
        outIntensity[nOut]=intensityNum
        outMissing[nOut]=missing
        outTotal[nOut]=total
        outCompatible[nOut]=compatible
        nOut+=1
        endfor
    endfor
    if(nOut>1)
        Sort/R outTotal,outTotal,outRef,outRefPeak,outShift,outLocal,outGlobal,outNew,outIntensity,outMissing,outCompatible
    endif
    NVAR selectedPeak=$(path+":selectedPeakRow"),selectedCandidate=$(path+":selectedCandidateRow")
    selectedPeak=peakRow
    selectedCandidate=nOut>0 ? 0 : -1
    XRD_RebuildCandidateTable(path)
    if(nOut>0)
        XRD_PreviewCandidate(path,0)
    else
        XRD_ClearPreview(path)
    endif
    return nOut
End

Function XRD_FindMeasuredMatch(measuredX,used,target,tolerance,bestDelta)
    Wave measuredX,used
    Variable target,tolerance
    Variable &bestDelta
    Variable i,best=-1,delta
    bestDelta=inf
    for(i=0;i<numpnts(measuredX);i+=1)
        if(used[i])
            continue
        endif
        delta=abs(measuredX[i]-target)
        if(delta<=tolerance && delta<bestDelta)
            best=i
            bestDelta=delta
        endif
    endfor
    return best
End

Function XRD_RebuildCandidateTable(path)
    String path
    Wave refs=$(path+":Candidates:refIndex"),refPeaks=$(path+":Candidates:refPeakIndex"),shifts=$(path+":Candidates:shift")
    Wave local=$(path+":Candidates:localScore"),globalScore=$(path+":Candidates:globalScore"),newScore=$(path+":Candidates:newScore"),missing=$(path+":Candidates:missingStrong"),total=$(path+":Candidates:totalScore"),compatible=$(path+":Candidates:compatible")
    Wave/T table=$(path+":Candidates:table")
    Redimension/N=(numpnts(refs),11) table
    Variable i
    Wave measured=$(path+":Peaks:angle"),ids=$(path+":Peaks:peakID")
    Variable peakRow=NumVarOrDefault(path+":selectedPeakRow",-1),owner,delta
    String refPath,nearest
    for(i=0;i<numpnts(refs);i+=1)
        refPath=XRD_ReferencePath(refs[i])
        SVAR phaseName=$(refPath+":phaseName"),card=$(refPath+":cardNumber"),phaseClass=$(refPath+":phaseClass")
        Wave tt=$(refPath+":twoTheta"),hh=$(refPath+":h"),kk=$(refPath+":k"),ll=$(refPath+":l")
        nearest=num2str(tt[refPeaks[i]])+"  "+XRD_HKL(hh[refPeaks[i]],kk[refPeaks[i]],ll[refPeaks[i]])
        table[i][0]=XRD_PhaseLabel(refs[i])+" ["+card+"]"
        table[i][1]=nearest
        table[i][4]=num2str(round(total[i]))
        table[i][5]=num2str(round(globalScore[i]))
        table[i][6]=num2str(round(local[i]))
        table[i][7]=num2str(shifts[i])
        table[i][8]=phaseName
        table[i][9]=num2str(round(newScore[i]))
        table[i][10]=num2istr(missing[i])
        if(peakRow>=0 && peakRow<numpnts(measured))
            delta=measured[peakRow]-tt[refPeaks[i]]-shifts[i]
            table[i][2]=num2str(delta)
            owner=XRD_ReferencePeakOwner(path,refs[i],refPeaks[i],ids[peakRow])
            table[i][3]=SelectString(abs(delta)<=NumVarOrDefault(XRD_Project()+":matchTolerance",0.2),"一致幅外・手動確認","一致幅内")
            if(owner>=0)
                table[i][3]="使用中: "+num2str(measured[owner])+"°"
            endif
        else
            table[i][2]="";table[i][3]=""
        endif
    endfor
End

Function/S XRD_HKL(h,k,l)
    Variable h,k,l
    if(!XRD82_HKLKnown(h,k,l))
        return "hkl不明"
    endif
    return "("+num2istr(h)+num2istr(k)+num2istr(l)+")"
End

Function XRD_PreviewCandidate(path,candidateRow)
    String path
    Variable candidateRow
    Wave refs=$(path+":Candidates:refIndex"),shifts=$(path+":Candidates:shift")
    if(candidateRow<0 || candidateRow>=numpnts(refs))
        return XRD_ClearPreview(path)
    endif
    Variable result=XRD_PreviewReference(path,refs[candidateRow],shifts[candidateRow])
    NVAR selected=$(path+":selectedCandidateRow")
    selected=candidateRow
    Wave reflectionRows=$(path+":Candidates:refPeakIndex")
    Variable/G $(path+":Preview:reflectionIndex")=reflectionRows[candidateRow]
    XRD_ReferenceArrow(path)
    XRD_RequestLive()
    XRD_BuildEvidence(path,refs[candidateRow],shifts[candidateRow])
    XRD_UpdateEvidenceUI(path)
    return result
End

Function XRD_PreviewReference(path,refIndex,shift)
    String path
    Variable refIndex,shift
    NVAR count=$(XRD_Project()+":referenceCount")
    if(refIndex<1 || refIndex>count)
        return XRD_ClearPreview(path)
    endif
    String refPath=XRD_ReferencePath(refIndex),project=XRD_Project()
    Wave refX=$(refPath+":twoTheta"),refI=$(refPath+":intensity"),rawX=$(path+":Raw:twoTheta"),rawY=$(path+":Raw:intensity")
    Wave outX=$(path+":Preview:angle"),outY=$(path+":Preview:height")
    NVAR minimum=$(project+":previewMinIntensity")
    WaveStats/Q refI
    Variable refMax=max(V_max,1e-12)
    WaveStats/Q rawY
    Variable rawRange=max(V_max-V_min,1e-12),i,n=0,relative
    Redimension/N=(numpnts(refX)) outX,outY
    for(i=0;i<numpnts(refX);i+=1)
        relative=100*refI[i]/refMax
        if(relative<minimum || refX[i]+shift<rawX[0] || refX[i]+shift>rawX[numpnts(rawX)-1])
            continue
        endif
        outX[n]=refX[i]+shift
        outY[n]=relative
        n+=1
    endfor
    Redimension/N=(n) outX,outY
    Variable/G $(path+":Preview:reflectionIndex")=-1
    Variable/G $(path+":Preview:referenceIndex")=refIndex
    Variable/G $(path+":Preview:shift")=shift
    XRD_BuildEvidence(path,refIndex,shift)
    XRD_UpdateEvidenceUI(path)
    XRD120_UpdateWarning(path)
    XRD_ShiftNotice(path)
    XRD_RequestLive()
    return n
End

Function XRD_ClearPreview(path)
    String path
    Wave outX=$(path+":Preview:angle"),outY=$(path+":Preview:height")
    Redimension/N=0 outX,outY
    NVAR selected=$(path+":selectedCandidateRow")
    selected=-1
    XRD_ClearEvidence(path)
    Variable/G $(path+":Preview:reflectionIndex")=-1
    Variable/G $(path+":Preview:referenceIndex")=0
    XRD_ReferenceArrow(path)
    XRD_RequestLive()
    XRD_ShiftNotice(path)
    return 0
End

Function XRD_AssignCandidate(path,peakRow,candidateRow,overlap)
    String path
    Variable peakRow,candidateRow,overlap
    Wave peakIDs=$(path+":Peaks:peakID")
    Wave refs=$(path+":Candidates:refIndex"),refPeaks=$(path+":Candidates:refPeakIndex"),shifts=$(path+":Candidates:shift")
    if(peakRow<0 || peakRow>=numpnts(peakIDs) || candidateRow<0 || candidateRow>=numpnts(refs))
        return -1
    endif
    if(!XRD_MaterialAllowed(refs[candidateRow]) || !XRD_TypeCardAllowed(refs[candidateRow]))
        return -3
    endif
    Variable peakID=peakIDs[peakRow],i,n
    Variable occupied=XRD_ReferencePeakOwner(path,refs[candidateRow],refPeaks[candidateRow],peakID)
    if(occupied>=0)
        return -2
    endif
    XRD_RecordUndo(path,SelectString(overlap,"同定の採用・置換","重なり同定"))
    Wave assignID=$(path+":Assignments:peakID"),assignRef=$(path+":Assignments:refIndex"),assignPeak=$(path+":Assignments:refPeakIndex"),assignShift=$(path+":Assignments:shift")
    Wave/T assignMode=$(path+":Assignments:mode"),assignCreated=$(path+":Assignments:created")
    if(!overlap)
        XRD_RemoveAssignmentsForPeak(path,peakID)
    else
        for(i=numpnts(assignID)-1;i>=0;i-=1)
            if(assignID[i]==peakID && assignRef[i]==0)
                DeletePoints i,1,assignID,assignRef,assignPeak,assignShift,assignMode,assignCreated
            endif
        endfor
        for(i=0;i<numpnts(assignID);i+=1)
            if(assignID[i]==peakID && assignRef[i]==refs[candidateRow] && assignPeak[i]==refPeaks[candidateRow])
                return 0
            endif
        endfor
    endif
    n=numpnts(assignID)
    Redimension/N=(n+1) assignID,assignRef,assignPeak,assignShift,assignMode,assignCreated
    assignID[n]=peakID
    assignRef[n]=refs[candidateRow]
    assignPeak[n]=refPeaks[candidateRow]
    assignShift[n]=shifts[candidateRow]
    assignMode[n]=SelectString(overlap,"Primary","Overlap")
    assignCreated[n]=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    SVAR status=$(path+":status")
    status="同定中"
    XRD_InvalidateFit(path)
    XRD_RefreshAssignmentTable(path)
    XRD_PeakTable(path)
    XRD_UpdateAssignedPlot(path)
    if(strlen(StrVarOrDefault(path+":sampleNumber","")))
        XRD100_RefreshNamed(XRD80_ProjectForMeasurement(path))
    endif
    XRD_ScoreCandidates(path,peakRow)
    return 0
End

Function XRD_SetUnknown(path,peakRow)
    String path
    Variable peakRow
    Wave peakIDs=$(path+":Peaks:peakID")
    if(peakRow<0 || peakRow>=numpnts(peakIDs))
        return -1
    endif
    Variable id=peakIDs[peakRow],n
    XRD_RecordUndo(path,"Unknown設定")
    XRD_RemoveAssignmentsForPeak(path,id)
    Wave assignID=$(path+":Assignments:peakID"),assignRef=$(path+":Assignments:refIndex"),assignPeak=$(path+":Assignments:refPeakIndex"),assignShift=$(path+":Assignments:shift")
    Wave/T assignMode=$(path+":Assignments:mode"),assignCreated=$(path+":Assignments:created")
    n=numpnts(assignID)
    Redimension/N=(n+1) assignID,assignRef,assignPeak,assignShift,assignMode,assignCreated
    assignID[n]=id
    assignRef[n]=0
    assignPeak[n]=-1
    assignShift[n]=0
    assignMode[n]="Unknown"
    assignCreated[n]=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    SVAR status=$(path+":status")
    status="同定中"
    XRD_InvalidateFit(path)
    XRD_RefreshAssignmentTable(path)
    XRD_PeakTable(path)
    XRD_UpdateAssignedPlot(path)
    if(strlen(StrVarOrDefault(path+":sampleNumber","")))
        XRD100_RefreshNamed(XRD80_ProjectForMeasurement(path))
    endif
    XRD_ScoreCandidates(path,peakRow)
    return 0
End

Function XRD_ClearPeakReview(path,peakRow)
    String path
    Variable peakRow
    Wave peakIDs=$(path+":Peaks:peakID")
    if(peakRow<0 || peakRow>=numpnts(peakIDs))
        return -1
    endif
    XRD_RecordUndo(path,"同定解除")
    XRD_RemoveAssignmentsForPeak(path,peakIDs[peakRow])
    SVAR status=$(path+":status")
    status="同定中"
    XRD_InvalidateFit(path)
    XRD_RefreshAssignmentTable(path)
    XRD_PeakTable(path)
    XRD_UpdateAssignedPlot(path)
    if(strlen(StrVarOrDefault(path+":sampleNumber","")))
        XRD100_RefreshNamed(XRD80_ProjectForMeasurement(path))
    endif
    XRD_ScoreCandidates(path,peakRow)
    return 0
End

Function XRD_RemoveAssignmentsForPeak(path,peakID)
    String path
    Variable peakID
    XRD_EnsureAssignmentWaves(path)
    Wave assignID=$(path+":Assignments:peakID"),assignRef=$(path+":Assignments:refIndex"),assignPeak=$(path+":Assignments:refPeakIndex"),assignShift=$(path+":Assignments:shift")
    Wave/T assignMode=$(path+":Assignments:mode"),assignCreated=$(path+":Assignments:created")
    Variable i
    for(i=numpnts(assignID)-1;i>=0;i-=1)
        if(assignID[i]==peakID)
            DeletePoints i,1,assignID,assignRef,assignPeak,assignShift,assignMode,assignCreated
        endif
    endfor
    return 0
End

Function XRD_PeakHasReview(path,peakID)
    String path
    Variable peakID
    Wave/Z assignID=$(path+":Assignments:peakID")
    if(!WaveExists(assignID))
        return 0
    endif
    Variable i
    for(i=0;i<numpnts(assignID);i+=1)
        if(assignID[i]==peakID)
            return 1
        endif
    endfor
    return 0
End

Function XRD_PeakExplained(path,peakID)
    String path
    Variable peakID
    Wave/Z assignID=$(path+":Assignments:peakID"),assignRef=$(path+":Assignments:refIndex")
    if(!WaveExists(assignID))
        return 0
    endif
    Variable i
    for(i=0;i<numpnts(assignID);i+=1)
        if(assignID[i]==peakID && assignRef[i]>0)
            return 1
        endif
    endfor
    return 0
End

Function/S XRD_AssignmentSummary(path,peakID)
    String path
    Variable peakID
    Wave/Z assignID=$(path+":Assignments:peakID"),assignRef=$(path+":Assignments:refIndex"),assignPeak=$(path+":Assignments:refPeakIndex")
    Wave/T/Z assignMode=$(path+":Assignments:mode")
    if(!WaveExists(assignID))
        return "未同定"
    endif
    String result="",refPath
    Variable i
    for(i=0;i<numpnts(assignID);i+=1)
        if(assignID[i]!=peakID)
            continue
        endif
        if(assignRef[i]==0)
            result+="Unknown"
        else
            refPath=XRD_ReferencePath(assignRef[i])
            SVAR phaseName=$(refPath+":phaseName")
            Wave hh=$(refPath+":h"),kk=$(refPath+":k"),ll=$(refPath+":l")
            if(strlen(result)>0)
                result+=" + "
            endif
            result+=XRD_PhaseLabel(assignRef[i])+" "+XRD_HKL(hh[assignPeak[i]],kk[assignPeak[i]],ll[assignPeak[i]])
        endif
    endfor
    return SelectString(strlen(result)>0,"未同定",result)
End

Function XRD_RefreshAssignmentTable(path)
    String path
    Wave assignID=$(path+":Assignments:peakID"),assignRef=$(path+":Assignments:refIndex"),assignPeak=$(path+":Assignments:refPeakIndex"),assignShift=$(path+":Assignments:shift")
    Wave/T assignMode=$(path+":Assignments:mode"),table=$(path+":Assignments:table")
    Wave peakIDs=$(path+":Peaks:peakID"),peakX=$(path+":Peaks:angle")
    Redimension/N=(numpnts(assignID),6) table
    Variable i,row
    String refPath
    for(i=0;i<numpnts(assignID);i+=1)
        row=XRD_FindPeakRowByID(peakIDs,assignID[i])
        table[i][0]="削除済"
        if(row>=0)
            table[i][0]=num2str(peakX[row])
        endif
        if(assignRef[i]==0)
            table[i][1]="Unknown"
            table[i][2]="-"
            table[i][3]="-"
        else
            refPath=XRD_ReferencePath(assignRef[i])
            SVAR phaseName=$(refPath+":phaseName"),card=$(refPath+":cardNumber")
            Wave hh=$(refPath+":h"),kk=$(refPath+":k"),ll=$(refPath+":l")
            table[i][1]=XRD_PhaseLabel(assignRef[i])
            table[i][2]=card
            table[i][3]=XRD_HKL(hh[assignPeak[i]],kk[assignPeak[i]],ll[assignPeak[i]])
        endif
        table[i][4]=assignMode[i]
        table[i][5]=num2str(assignShift[i])
    endfor
    SetDimLabel 1,0,'2theta',table
    SetDimLabel 1,1,Phase,table
    SetDimLabel 1,2,Card,table
    SetDimLabel 1,3,hkl,table
    SetDimLabel 1,4,Mode,table
    SetDimLabel 1,5,Shift,table
End

Function XRD_FindPeakRowByID(peakIDs,peakID)
    Wave peakIDs
    Variable peakID
    Variable i
    for(i=0;i<numpnts(peakIDs);i+=1)
        if(peakIDs[i]==peakID)
            return i
        endif
    endfor
    return -1
End

Function XRD_SetMeasurementComplete(path)
    String path
    // Compatibility command. Completion follows the assignments automatically.
    if(XRD_UpdateAnalysisState(path)==1)
        return 0
    endif
    if(NumVarOrDefault(path+":registeredPeakCount",0)==0)
        return -1
    endif
    return -2
End

Function XRD_CompletedMeasurementCount()
    String project=XRD_Project(),name,path
    DFREF folder=$(project+":Measurements")
    Variable i=0,count=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(strlen(name)==0)
            break
        endif
        path=XRD110_MeasurementPath(project,name)
        if(XRD_IsAnalysisComplete(path))
            count+=1
        endif
        i+=1
    while(1)
    return count
End
