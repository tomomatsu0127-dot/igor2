#pragma rtGlobals=3
// XRD Workbench v1.1.0. Peak detection and stable peak identifiers.

Function XRD_AddPoint(path,index,kind)
    String path,kind
    Variable index
    XRD_EnsureMeasurement(path)
    Wave xx=$(path+":Raw:twoTheta"),yy=$(path+":Processed:intensity")
    Wave px=$(path+":Peaks:angle"),py=$(path+":Peaks:height"),indices=$(path+":Peaks:pointIndex"),ids=$(path+":Peaks:peakID")
    Wave/T origin=$(path+":Peaks:origin"),summary=$(path+":Peaks:assignmentSummary")
    NVAR nextID=$(path+":nextPeakID")
    Variable j,n=numpnts(px)
    if(index<0 || index>=numpnts(xx) || numtype(index)!=0 || index!=trunc(index))
        return -1
    endif
    for(j=0;j<n;j+=1)
        if(indices[j]==index)
            return 0
        endif
    endfor
    if(cmpstr(kind,"Manual")==0)
        XRD_RecordUndo(path,"手動ピーク追加")
    endif
    Redimension/N=(n+1) px,py,indices,ids,origin,summary
    px[n]=xx[index]
    py[n]=yy[index]
    indices[n]=index
    ids[n]=nextID
    nextID+=1
    origin[n]=kind
    summary[n]="未同定"
    SVAR status=$(path+":status")
    status="同定中"
    XRD_InvalidateFit(path)
    Sort px,px,py,indices,ids,origin,summary
    return 1
End

Function XRD_DetectLegacy(path)
    String path
    XRD_EnsureMeasurement(path)
    Wave xx=$(path+":Raw:twoTheta"),raw=$(path+":Raw:intensity"),yy=$(path+":Processed:intensity")
    Wave px=$(path+":Peaks:angle"),py=$(path+":Peaks:height"),indices=$(path+":Peaks:pointIndex"),ids=$(path+":Peaks:peakID")
    Wave/T origin=$(path+":Peaks:origin"),summary=$(path+":Peaks:assignmentSummary")
    NVAR threshold=$(path+":threshold"),distance=$(path+":minDistance")
    if(numtype(threshold)!=0 || threshold<0 || threshold>100 || numtype(distance)!=0 || distance<0)
        return -1
    endif
    XRD_NormalizeMeasurement(path)
    XRD_RecordUndo(path,"自動ピーク検出")
    String/G $(path+":algorithm")="local-max-plateau-v1; strongest-first spacing; no smoothing"
    String/G $(path+":detectionRunDescription")="旧方式: 高さ="+num2str(threshold)+"%, 間隔="+num2str(distance)+" deg"
    Variable n=numpnts(xx),i,j,k,count=0,ok,idx,cut
    WaveStats/Q yy
    cut=V_min+(V_max-V_min)*threshold/100
    // Keep manually added and already-reviewed peaks. Replace only unassigned Auto peaks.
    for(i=numpnts(px)-1;i>=0;i-=1)
        if(cmpstr(origin[i],"Auto")==0 && !XRD_PeakHasReview(path,ids[i]))
            DeletePoints i,1,px,py,indices,ids,origin,summary
        endif
    endfor
    Make/FREE/D/N=(n) candidates,weights
    i=1
    do
        if(i>=n-1)
            break
        endif
        j=i
        do
            if(j>=n-2 || yy[j+1]!=yy[i])
                break
            endif
            j+=1
        while(1)
        if(yy[i]>yy[i-1] && yy[j]>yy[j+1] && yy[i]>=cut)
            candidates[count]=floor((i+j)/2)
            weights[count]=-yy[i]
            count+=1
        endif
        i=j+1
    while(1)
    Redimension/N=(count) candidates,weights
    if(count>1)
        Sort weights,weights,candidates
    endif
    for(i=0;i<count;i+=1)
        idx=candidates[i]
        ok=1
        for(k=0;k<numpnts(px);k+=1)
            if(abs(xx[idx]-px[k])<distance || indices[k]==idx)
                ok=0
                break
            endif
        endfor
        if(ok)
            XRD_AddPoint(path,idx,"Auto")
        endif
    endfor
    NVAR lastThreshold=$(path+":lastThreshold"),lastDistance=$(path+":lastMinDistance")
    lastThreshold=threshold
    lastDistance=distance
    SVAR status=$(path+":status")
    if(cmpstr(status,"同定完了")!=0)
        status="同定中"
    endif
    XRD_PeakTable(path)
    return 0
End

Function XRD_Manual(path,angle)
    String path
    Variable angle
    XRD_EnsureMeasurement(path)
    Wave xx=$(path+":Raw:twoTheta")
    if(numtype(angle)!=0 || angle<xx[0] || angle>xx[numpnts(xx)-1])
        return -1
    endif
    Variable i,best=0
    for(i=1;i<numpnts(xx);i+=1)
        if(abs(xx[i]-angle)<abs(xx[best]-angle))
            best=i
        endif
    endfor
    Variable result=XRD_AddPoint(path,best,"Manual")
    XRD_PeakTable(path)
    return result
End

Function XRD_Delete(path,row)
    String path
    Variable row
    XRD_EnsureMeasurement(path)
    Wave px=$(path+":Peaks:angle"),py=$(path+":Peaks:height"),indices=$(path+":Peaks:pointIndex"),ids=$(path+":Peaks:peakID")
    Wave/T origin=$(path+":Peaks:origin"),summary=$(path+":Peaks:assignmentSummary")
    if(numtype(row)!=0 || row<0 || row>=numpnts(px) || row!=trunc(row))
        return -1
    endif
    XRD_RecordUndo(path,"ピーク削除")
    XRD_RemoveAssignmentsForPeak(path,ids[row])
    DeletePoints row,1,px,py,indices,ids,origin,summary
    SVAR status=$(path+":status")
    status="同定中"
    XRD_InvalidateFit(path)
    XRD_ResetCandidates(path)
    XRD_ClearPreview(path)
    XRD_RefreshAssignmentTable(path)
    XRD_UpdateAssignedPlot(path)
    XRD_PeakTable(path)
    return 0
End

Function XRD_PeakTable(path)
    String path
    if(strlen(path)==0 || !DataFolderExists(path))
        return -1
    endif
    Wave px=$(path+":Peaks:angle"),py=$(path+":Peaks:height"),ids=$(path+":Peaks:peakID")
    Wave/T origin=$(path+":Peaks:origin"),summary=$(path+":Peaks:assignmentSummary"),table=$(path+":Peaks:table")
    Redimension/N=(numpnts(px),5) table
    Variable i
    for(i=0;i<numpnts(px);i+=1)
        summary[i]=XRD_AssignmentSummary(path,ids[i])
        table[i][0]=num2str(px[i])
        table[i][1]=num2str(py[i])
        table[i][2]=summary[i]
        table[i][3]=SelectString(XRD_PeakHasReview(path,ids[i]),"未確認","確認済")
        table[i][4]=origin[i]
    endfor
    SetDimLabel 1,0,'2theta (deg)',table
    SetDimLabel 1,1,'Intensity (%)',table
    SetDimLabel 1,2,Assignment,table
    SetDimLabel 1,3,Status,table
    SetDimLabel 1,4,Origin,table
    XRD_UpdateAnalysisState(path)
    return 0
End
