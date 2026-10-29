#pragma rtGlobals=3
// XRD Workbench v1.2.0: evidence, review, reference metadata and recovery.
Function XRD_V50Project(project)
    String project
    NewDataFolder/O $(project+":Undo")
    XRD_EnsureNumeric(project+":analysisRevision",0)
    XRD_EnsureNumeric(project+":referenceShiftMode",0)
    XRD_EnsureNumeric(project+":Undo:redoCount",0)
End

Function XRD_V50Measurement(path)
    String path
    XRD_DetectionSettings(path)
    XRD_EnsureNumeric(path+":candidateMode",0)
    XRD_EnsureNumeric(path+":measurementWavelength",NumVarOrDefault(XRD_Project()+":wavelength",1.5406))
    XRD_EnsureNumeric(path+":zeroCorrection",0)
    XRD_EnsureNumeric(path+":profileHalfWidth",0.4)
    XRD_EnsureNumeric(path+":profileModel",1)
    XRD_EnsureNumeric(path+":profileBackground",1)
    SVAR/Z radiation=$(path+":radiation")
    if(!SVAR_Exists(radiation))
        String/G $(path+":radiation")="Cu-Kα"
        String/G $(path+":calibrationNote")="未校正（ゼロ補正0 deg）"
    endif
    NewDataFolder/O $(path+":Peaks:Profiles")
    XRD_EnsureEvidence(path)
End

Function XRD_EnsureEvidence(path)
    String path
    NewDataFolder/O $(path+":Evidence")
    Wave/T/Z table=$(path+":Evidence:table")
    if(!WaveExists(table))
        Make/T/N=(0,7) $(path+":Evidence:table")
        Make/D/N=0 $(path+":Evidence:angle"),$(path+":Evidence:matchRow"),$(path+":Evidence:class")
        Make/D/N=0 $(path+":Evidence:missingX"),$(path+":Evidence:missingY"),$(path+":Evidence:overlapX"),$(path+":Evidence:overlapY")
        String/G $(path+":Evidence:summary")="候補スコアは確率・含有率ではありません"
    endif
End

Function XRD_PhaseAdopted(path,index)
    String path
    Variable index
    Wave refs=$(path+":Assignments:refIndex")
    Variable i
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==index)
            return 1
        endif
    endfor
    return 0
End

Function XRD_CandidateAllowed(path,index)
    String path
    Variable index
    if(!XRD_MaterialAllowed(index) || !XRD_TypeCardAllowed(index))
        return 0
    endif
    NVAR mode=$(path+":candidateMode")
    if(mode==1)
        return XRD_PhaseAdopted(path,index)
    elseif(mode==2)
        return !XRD_PhaseAdopted(path,index)
    endif
    return 1
End

Function XRD_RefineShift(path,index,initial)
    String path
    Variable index,initial
    Wave rx=$(XRD_ReferencePath(index)+":twoTheta"),ri=$(XRD_ReferencePath(index)+":intensity"),mx=$(path+":Peaks:angle")
    NVAR tol=$(XRD_Project()+":matchTolerance"),limit=$(XRD_Project()+":maxCommonShift")
    Variable shift=max(-limit,min(limit,initial)),iteration,j,best,delta,n
    Make/FREE/D/N=(numpnts(rx)) offsets,order=p
    Duplicate/FREE ri,weights
    Sort/R weights,weights,order
    // Two robust median updates; an unresolved singleton is explicitly labelled.
    for(iteration=0;iteration<2;iteration+=1)
        Make/FREE/B/U/N=(numpnts(mx)) used=0
        n=0
        for(j=0;j<numpnts(rx);j+=1)
            best=XRD_FindMeasuredMatch(mx,used,rx[order[j]]+shift,tol,delta)
            if(best>=0)
                used[best]=1
                offsets[n]=mx[best]-rx[order[j]]
                n+=1
            endif
        endfor
        if(n<2)
            break
        endif
        Redimension/N=(n) offsets
        Sort offsets,offsets
        shift=(offsets[floor((n-1)/2)]+offsets[floor(n/2)])/2
        shift=max(-limit,min(limit,shift))
        Redimension/N=(numpnts(rx)) offsets
    endfor
    return shift
End

Function XRD_AssignedToOther(path,id,index)
    String path
    Variable id,index
    Wave ids=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex")
    Variable i
    for(i=0;i<numpnts(ids);i+=1)
        if(ids[i]==id && refs[i]>0 && refs[i]!=index)
            return 1
        endif
    endfor
    return 0
End

Function XRD_BuildEvidence(path,index,shift)
    String path
    Variable index,shift
    XRD_EnsureEvidence(path)
    String rp=XRD_ReferencePath(index)
    Wave rx=$(rp+":twoTheta"),ri=$(rp+":intensity"),hh=$(rp+":h"),kk=$(rp+":k"),ll=$(rp+":l")
    Wave mx=$(path+":Peaks:angle"),ids=$(path+":Peaks:peakID"),rawX=$(path+":Raw:twoTheta")
    NVAR tol=$(XRD_Project()+":matchTolerance")
    Wave/T table=$(path+":Evidence:table")
    Wave angles=$(path+":Evidence:angle"),rows=$(path+":Evidence:matchRow"),classes=$(path+":Evidence:class")
    Wave missingX=$(path+":Evidence:missingX"),missingY=$(path+":Evidence:missingY"),overlapX=$(path+":Evidence:overlapX"),overlapY=$(path+":Evidence:overlapY")
    Redimension/N=(numpnts(rx),7) table
    Redimension/N=(numpnts(rx)) angles,rows,classes,missingX,missingY,overlapX,overlapY
    WaveStats/Q ri
    Variable maximum=max(V_max,1e-12),i,j,best,delta,n=0,matches=0,missing=0,overlaps=0,target,relative
    Make/FREE/B/U/N=(numpnts(mx)) used=0
    Make/FREE/D/N=(numpnts(ri)) order=p
    Duplicate/FREE ri,weights
    Sort/R weights,weights,order
    String state
    for(j=0;j<numpnts(rx);j+=1)
        i=order[j];target=rx[i]+shift
        if(target<rawX[0] || target>rawX[numpnts(rawX)-1])
            continue
        endif
        relative=100*ri[i]/maximum
        best=XRD_FindMeasuredMatch(mx,used,target,tol,delta)
        state="未一致";classes[n]=0
        if(best>=0)
            used[best]=1;matches+=1;state="一致";classes[n]=1
            if(XRD_AssignedToOther(path,ids[best],index))
                state="重なり候補（他相に採用済み）";classes[n]=2
                overlapX[overlaps]=target;overlapY[overlaps]=relative;overlaps+=1
            endif
        elseif(relative>=70)
            state="強い参照ピークが未一致";classes[n]=3
            missingX[missing]=target;missingY[missing]=relative;missing+=1
        endif
        angles[n]=target;rows[n]=best
        table[n][0]=num2str(target);table[n][1]=num2str(relative);table[n][2]=state
        table[n][3]="-";table[n][4]="-"
        if(best>=0)
            table[n][3]=num2str(mx[best]);table[n][4]=num2str(mx[best]-target)
        endif
        table[n][5]=XRD_HKL(hh[i],kk[i],ll[i]);table[n][6]=num2istr(i)
        n+=1
    endfor
    Redimension/N=(n,7) table
    Redimension/N=(n) angles,rows,classes
    Redimension/N=(missing) missingX,missingY
    Redimension/N=(overlaps) overlapX,overlapY
    SetDimLabel 1,0,'参照2theta+shift',table
    SetDimLabel 1,1,'相対強度(%)',table
    SetDimLabel 1,2,'一致・重なり・未一致',table
    SetDimLabel 1,3,'測定2theta',table
    SetDimLabel 1,4,'差(deg)',table
    SetDimLabel 1,5,hkl,table
    SetDimLabel 1,6,RefRow,table
    Variable/G $(path+":Evidence:refIndex")=index
    Variable/G $(path+":Evidence:shift")=shift
    Variable/G $(path+":Evidence:matched")=matches
    Variable/G $(path+":Evidence:missingStrong")=missing
    Variable/G $(path+":Evidence:overlaps")=overlaps
    String/G $(path+":Evidence:summary")="一致 "+num2istr(matches)+"/"+num2istr(n)+"本 / 強い未一致 "+num2istr(missing)+"本 / 重なり候補 "+num2istr(overlaps)+"本 / shift "+num2str(shift)+" deg"
    if(matches<2)
        SVAR summary=$(path+":Evidence:summary")
        summary+="（1本以下：ずれの裏付けが不足）"
    endif
    return matches
End

Function XRD_ClearEvidence(path)
    String path
    XRD_EnsureEvidence(path)
    Wave mx=$(path+":Evidence:missingX"),my=$(path+":Evidence:missingY"),ox=$(path+":Evidence:overlapX"),oy=$(path+":Evidence:overlapY")
    Wave/T table=$(path+":Evidence:table")
    Redimension/N=0 mx,my,ox,oy
    Redimension/N=(0,7) table
    String/G $(path+":Evidence:summary")="候補を選択してください。スコアは確率・含有率ではありません。"
    XRD_UpdateEvidenceUI(path)
End

Function XRD_AddEvidenceTraces(path)
    String path
    Wave mx=$(path+":Evidence:missingX"),my=$(path+":Evidence:missingY"),ox=$(path+":Evidence:overlapX"),oy=$(path+":Evidence:overlapY")
    AppendToGraph/W=XRDWorkbench#Pattern my/TN=XRDWB_Missing vs mx
    AppendToGraph/W=XRDWorkbench#Pattern oy/TN=XRDWB_Overlap vs ox
    ModifyGraph/W=XRDWorkbench#Pattern mode(XRDWB_Missing)=1,lstyle(XRDWB_Missing)=3,rgb(XRDWB_Missing)=(25000,25000,25000),lsize(XRDWB_Missing)=1.5
    ModifyGraph/W=XRDWorkbench#Pattern mode(XRDWB_Overlap)=3,marker(XRDWB_Overlap)=17,rgb(XRDWB_Overlap)=(0,18000,45000),msize(XRDWB_Overlap)=3
End

Function XRD_UpdateEvidenceUI(path)
    String path
    if(WinType("XRDEvidence") && cmpstr(GetUserData("XRDEvidence","","XRDData"),path)==0)
        TitleBox evidenceSummary,win=XRDEvidence,title=StrVarOrDefault(path+":Evidence:summary","")
        ControlUpdate/W=XRDEvidence evidenceList
    endif
End

Function XRD_EvidencePanel()
    String path=XRD_Data()
    if(!strlen(path))
        return -1
    endif
    XRD_EnsureEvidence(path)
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDEvidence")
    DoWindow/K XRDEvidence
    NewPanel/FLT=1/K=1/N=XRDEvidence/W=(40,40,980,600) as "候補の根拠 — 強いピーク・重なりを確認"
    SetWindow XRDEvidence userdata(XRDData)=path
    DefaultGUIFont/W=XRDEvidence all={"Segoe UI",12,0}
    TitleBox evidenceSummary,pos={15,15},frame=0,title=StrVarOrDefault(path+":Evidence:summary","")
    TitleBox explanation,pos={15,48},frame=0,title="赤棒=参照 / 黒破線=強い未一致 / 青い三角=他相と重なる候補\rCoverageは検出ピークの一致点です。曲線全体のフィット・確率・含有率ではありません。\r同定済み相との重なりは欠落として数えません。反応・配向で強度が変わる場合も確認してください。"
    Wave/T table=$(path+":Evidence:table")
    ListBox evidenceList,pos={15,120},size={905,370},listWave=table,mode=1,widths={140,90,280,120,100,100,60},proc=XRD_EvidenceSelection
    Button close,pos={15,510},size={160,28},title="Workbenchへ戻る",proc=XRD_V50Button
    XRD123_FinishPanel("XRDEvidence",panelState123)
    return 0
End

Function XRD_EvidenceSelection(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode==3 || lba.eventCode==4)
        String path=GetUserData(lba.win,"","XRDData")
        Wave angles=$(path+":Evidence:angle")
        if(lba.row>=0 && lba.row<numpnts(angles))
            XRD_JumpAngle(path,angles[lba.row])
        endif
    endif
End

Function XRD_CandidateModeAction(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2)
        return 0
    endif
    String path=XRD_Data()
    NVAR mode=$(path+":candidateMode"),row=$(path+":selectedPeakRow")
    mode=pa.popNum-1
    XRD_ScoreCandidates(path,row)
    XRD_Panel()
End

Function XRD_BuildAudit(path)
    String path
    NewDataFolder/O $(path+":Audit")
    Make/O/T/N=(0,4) $(path+":Audit:table")
    Make/O/D/N=0 $(path+":Audit:angles"),$(path+":Audit:peakRows")
    Wave/T table=$(path+":Audit:table")
    Wave angles=$(path+":Audit:angles"),peakRows=$(path+":Audit:peakRows")
    Wave px=$(path+":Peaks:angle"),py=$(path+":Peaks:height"),ids=$(path+":Peaks:peakID"),refs=$(path+":Assignments:refIndex"),aids=$(path+":Assignments:peakID"),shifts=$(path+":Assignments:shift")
    Variable i,j,n=0,count,index
    for(i=0;i<numpnts(px);i+=1)
        count=0
        for(j=0;j<numpnts(aids);j+=1)
            count+=(aids[j]==ids[i] && refs[j]>0)
        endfor
        if(!XRD_PeakHasReview(path,ids[i]) || !XRD_PeakExplained(path,ids[i]) || count>1)
            Redimension/N=(n+1,4) table
            Redimension/N=(n+1) angles,peakRows
            table[n][0]=SelectString(count>1,"未同定 / Unknown","重なり同定")
            table[n][1]=num2str(px[i]);table[n][2]=XRD_AssignmentSummary(path,ids[i])
            table[n][3]=SelectString(py[i]>=20,"弱いピークも残して確認","強い測定ピーク")
            angles[n]=px[i];peakRows[n]=i;n+=1
        endif
    endfor
    NVAR refCount=$(XRD_Project()+":referenceCount")
    for(index=1;index<=refCount;index+=1)
        if(!XRD_PhaseAdopted(path,index))
            continue
        endif
        Make/FREE/D/N=(numpnts(refs)) offsets
        count=0
        for(i=0;i<numpnts(refs);i+=1)
            if(refs[i]==index)
                offsets[count]=shifts[i];count+=1
            endif
        endfor
        Redimension/N=(count) offsets
        Sort offsets,offsets
        Variable shift=offsets[floor(count/2)]
        XRD_BuildEvidence(path,index,shift)
        Wave classes=$(path+":Evidence:class"),evAngles=$(path+":Evidence:angle")
        for(i=0;i<numpnts(classes);i+=1)
            if(classes[i]==3)
                Redimension/N=(n+1,4) table
                Redimension/N=(n+1) angles,peakRows
                table[n][0]="強い参照ピークが未一致";table[n][1]=num2str(evAngles[i]);table[n][2]=XRD_PhaseLabel(index)
                table[n][3]="未検出・配向・参照違いを確認（自動で不採用にしません）"
                angles[n]=evAngles[i];peakRows[n]=-1;n+=1
            endif
        endfor
    endfor
    SetDimLabel 1,0,'確認項目',table
    SetDimLabel 1,1,'2theta(deg)',table
    SetDimLabel 1,2,'相・割り当て',table
    SetDimLabel 1,3,'確認する理由',table
    // Restore the selected candidate's overlay/evidence after preparing the audit.
    NVAR selected=$(path+":selectedCandidateRow")
    XRD_PreviewCandidate(path,selected)
    return n
End

Function XRD_AuditPanel()
    String path=XRD_Data()
    if(!strlen(path))
        return -1
    endif
    XRD_BuildAudit(path)
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDAudit")
    DoWindow/K XRDAudit
    NewPanel/FLT=1/K=1/N=XRDAudit/W=(40,40,1000,580) as "同定内容と解析状態の確認"
    SetWindow XRDAudit userdata(XRDData)=path
    DefaultGUIFont/W=XRDAudit all={"Segoe UI",12,0}
    TitleBox note,pos={15,15},frame=0,title="行をクリックすると該当角度へ移動します。強い参照ピークの欠落・重なりも確認できます。\r全ピークに相またはUnknownが付くと自動で解析完了です。"
    Wave/T table=$(path+":Audit:table")
    ListBox auditList,pos={15,80},size={925,380},listWave=table,mode=1,widths={210,120,300,450},proc=XRD_AuditSelection
    Button confirmComplete,pos={15,485},size={260,30},title="現在の解析状態を再確認",proc=XRD_V50Button
    Button close,pos={295,485},size={220,30},title="同定作業へ戻る",proc=XRD_V50Button
    XRD123_FinishPanel("XRDAudit",panelState123)
    return 0
End

Function XRD_AuditSelection(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode!=3 && lba.eventCode!=4)
        return 0
    endif
    String path=GetUserData(lba.win,"","XRDData")
    Wave angles=$(path+":Audit:angles"),rows=$(path+":Audit:peakRows")
    if(lba.row<0 || lba.row>=numpnts(angles))
        return 0
    endif
    if(rows[lba.row]>=0)
        NVAR selected=$(path+":selectedPeakRow")
        selected=rows[lba.row]
        XRD_SelectedPeakGuide(path)
    endif
    XRD_JumpAngle(path,angles[lba.row])
End

Function XRD_JumpAngle(path,angle)
    String path
    Variable angle
    if(cmpstr(path,XRD_Data())!=0 || !WinType("XRDWorkbench#Pattern"))
        return -1
    endif
    SetAxis/W=XRDWorkbench#Pattern bottom angle-0.8,angle+0.8
    XRD_CaptureView()
    return 0
End

Function XRD_ReferenceError(file,reason)
    String file,reason
    String base=XRD80_Library()+":References:errors"
    Wave/T/Z table=$base
    if(!WaveExists(table))
        Make/T/N=(0,2) $base
        Wave/T newTable=$base
    endif
    Wave/T errors=$base
    Variable n=DimSize(errors,0)
    Redimension/N=(n+1,2) errors
    errors[n][0]=file;errors[n][1]=reason
    SetDimLabel 1,0,File,errors
    SetDimLabel 1,1,Reason,errors
End

Function/S XRD_FilterReason(index)
    Variable index
    String rp=XRD_ReferencePath(index),family=XRD_ReferenceType(index),formula=StrVarOrDefault(rp+":formula","")
    if(NumVarOrDefault(XRD_Project()+":elementFilterMode",0)==0)
        return "元素フィルターOFF"
    endif
    if(strlen(family))
        return family+"：置換可能なtype相として除外しません"
    endif
    if(XRD_FormulaCompatible(formula,family))
        return "許可元素に適合 / 組成不明なら候補に残します"
    endif
    return "組成 "+formula+" に許可されていない元素を含むため候補から除外"
End

Function XRD_ReferenceEditor()
    return XRD80_LibraryPanel()
End
Function XRD_ReferenceEditorTarget(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2 && cmpstr(GetUserData(pa.win,"","XRDProject"),XRD_Project())==0)
        XRD_ApplyReferenceMetadata()
        NVAR selected=$(XRD_Project()+":selectedReference")
        selected=pa.popNum-1
        XRD_ReferenceEditor()
    endif
End

Function XRD_ApplyReferenceMetadata()
    return XRD80_SaveReferenceDraft()
End

Function XRD_MetadataPanel()
    String path=XRD_Data()
    if(!strlen(path))
        return -1
    endif
    XRD_V50Measurement(path)
    // Drafts avoid silently committing partial calibration edits.
    String base=path+":Evidence:"
    Variable/G $(base+"draftWavelength")=NumVarOrDefault(path+":measurementWavelength",1.5406)
    Variable/G $(base+"draftZero")=NumVarOrDefault(path+":zeroCorrection",0)
    String/G $(base+"draftRadiation")=StrVarOrDefault(path+":radiation","Cu-Kα")
    String/G $(base+"draftCalibration")=StrVarOrDefault(path+":calibrationNote","")
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDMetadata")
    DoWindow/K XRDMetadata
    NewPanel/FLT=1/K=1/N=XRDMetadata/W=(40,40,790,365) as "現在の測定条件・既知の角度補正"
    SetWindow XRDMetadata userdata(XRDData)=path
    DefaultGUIFont/W=XRDMetadata all={"Segoe UI",12,0}
    SetVariable lambda,pos={15,20},size={700,24},title="波長 (Å)",limits={0.1,5,0.0001},value=$(base+"draftWavelength")
    SetVariable radiation,pos={15,56},size={700,24},title="線源・波長の区分",value=$(base+"draftRadiation")
    SetVariable zero,pos={15,92},size={700,24},title="既知のゼロ補正 (deg)",limits={-5,5,0.001},value=$(base+"draftZero")
    SetVariable calibration,pos={15,128},size={700,24},title="校正方法・標準試料",value=$(base+"draftCalibration")
    TitleBox note,pos={15,175},frame=0,title="補正角度 = 測定2theta − ゼロ補正。格子定数計算へ適用し、Rawは変更しません。\r候補表示のshiftは別の整合量です。参照2thetaは波長変換しません。\r参照と測定の線源を確認してください。試料変位の自動補正は行いません。"
    Button applyMetadata,pos={15,260},size={270,30},title="この測定へ適用・再計算を必要にする",proc=XRD_V50Button
    Button close,pos={310,260},size={180,30},title="キャンセル",proc=XRD_V50Button
    XRD123_FinishPanel("XRDMetadata",panelState123)
    return 0
End

Function XRD_ApplyMetadata(path)
    String path
    Variable wavelength=NumVarOrDefault(path+":Evidence:draftWavelength",NaN),zero=NumVarOrDefault(path+":Evidence:draftZero",NaN)
    if(numtype(wavelength+zero)!=0 || wavelength<0.1 || wavelength>5 || abs(zero)>5)
        return -1
    endif
    XRD_RecordUndo(path,"測定条件・ゼロ補正")
    Variable/G $(path+":measurementWavelength")=wavelength
    Variable/G $(path+":zeroCorrection")=zero
    String/G $(path+":radiation")=StrVarOrDefault(path+":Evidence:draftRadiation","Cu-Kα")
    String/G $(path+":calibrationNote")=StrVarOrDefault(path+":Evidence:draftCalibration","")
    XRD_InvalidateFit(path)
    return 0
End

Function XRD_RecordLatticeQuality(path)
    String path
    Wave input=$(path+":Lattice:inputs"),residual=$(path+":Lattice:residual"),ids=$(path+":Peaks:peakID")
    Make/O/T/N=(numpnts(residual),5) $(path+":Lattice:quality")
    Make/O/D/N=(numpnts(residual)) $(path+":Lattice:usedAngle")
    Wave/T table=$(path+":Lattice:quality")
    Wave xx=$(path+":Lattice:usedAngle")
    Variable i,n=0,row
    for(i=0;i<DimSize(input,0);i+=1)
        if(input[i][0]!=1)
            continue
        endif
        row=XRD_FindPeakRowByID(ids,input[i][5])
        xx[n]=input[i][1]
        table[n][0]=num2str(xx[n]);table[n][1]=XRD_HKL(input[i][2],input[i][3],input[i][4])
        table[n][2]=num2str(residual[n]);table[n][3]=XRD_PeakAngleSource(path,row)
        table[n][4]=SelectString(XRD_PeakAssignmentCount(path,input[i][5])>1,"","重なり：使用の妥当性を確認")
        n+=1
    endfor
    SetDimLabel 1,0,'使用2theta',table
    SetDimLabel 1,1,hkl,table
    SetDimLabel 1,2,'回帰残差(変換式の単位)',table
    SetDimLabel 1,3,'角度の出所',table
    SetDimLabel 1,4,'確認',table
    Variable/G $(path+":Lattice:usedCount")=n
    Variable/G $(path+":Lattice:zeroCorrection")=NumVarOrDefault(path+":zeroCorrection",0)
    Variable/G $(path+":Lattice:revision")=NumVarOrDefault(XRD_Project()+":analysisRevision",0)
    NewDataFolder/O $(path+":LatticeResults")
    Variable index=NumVarOrDefault(path+":Lattice:refIndex",-1)
    if(index>0)
        DuplicateDataFolder/O=1 $(path+":Lattice"),$(path+":LatticeResults:Ref"+num2istr(index))
    endif
End

Function XRD_InvalidateLatticeResults(path)
    String path
    if(!DataFolderExists(path+":LatticeResults"))
        return 0
    endif
    DFREF folder=$(path+":LatticeResults")
    String name
    Variable i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        String/G $(path+":LatticeResults:"+name+":state")="同定・条件変更あり：再計算してください"
        i+=1
    while(1)
End

Function/S XRD_RadiationLabel(win)
    String win
    String path=XRD_Data(),label=StrVarOrDefault(path+":radiation","Cu-Kα"),list
    if(StringMatch(win,"XRDStackGraph*"))
        list=XRD_MeasurementOrderList(XRD_Project())
        Variable i
        label=""
        for(i=0;i<ItemsInList(list);i+=1)
            path=XRD_Project()+":Measurements:"+StringFromList(i,list)
            if(!NumVarOrDefault(path+":visibleInStack",1))
                continue
            endif
            String nextLabel=StrVarOrDefault(path+":radiation","Cu-Kα")
            if(!strlen(label))
                label=nextLabel
            elseif(cmpstr(label,nextLabel)!=0)
                return ""
            endif
        endfor
    endif
    return label
End

Function XRD_PeakAssignmentCount(path,id)
    String path
    Variable id
    Wave ids=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex")
    Variable i,n=0
    for(i=0;i<numpnts(ids);i+=1)
        n+=(ids[i]==id && refs[i]>0)
    endfor
    return n
End

Function XRD_LatticeQualityPanel()
    String path=XRD_Data()
    Wave/T/Z quality=$(path+":Lattice:quality")
    if(!WaveExists(quality))
        DoAlert 0,"格子定数を計算してから結果を確認してください。"
        return -1
    endif
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDLatticeQuality")
    DoWindow/K XRDLatticeQuality
    NewPanel/FLT=1/K=1/N=XRDLatticeQuality/W=(40,40,980,590) as "格子定数 — 使用ピークと残差"
    DefaultGUIFont/W=XRDLatticeQuality all={"Segoe UI",12,0}
    TitleBox result,pos={15,15},frame=0,title=StrVarOrDefault(path+":Lattice:state","")+"\r"+XRD_LatticeResultText(path)
    TitleBox conditions,pos={15,175},frame=0,title="波長 "+num2str(NumVarOrDefault(path+":Lattice:wavelength",NaN))+" Å / ゼロ補正 "+num2str(NumVarOrDefault(path+":Lattice:zeroCorrection",0))+" deg\r残差は角度差ではなくPDF変換式の回帰残差です。ピーク中心の誤差による重み付けは未使用です。"
    ListBox qualityList,pos={15,235},size={925,240},listWave=quality,mode=1,widths={150,100,240,180,350}
    Button residualGraph,pos={15,500},size={210,30},title="残差を角度に対して表示",proc=XRD_V50Button
    SetWindow XRDLatticeQuality userdata(XRDData)=path
    XRD123_FinishPanel("XRDLatticeQuality",panelState123)
    return 0
End

Function XRD_Snapshot(path,entry,label)
    String path,entry,label
    NewDataFolder/O $entry
    String/G $(entry+":kind")="analysis"
    XRD_SaveViewBox(path,entry)
    DuplicateDataFolder/O=1 $(path+":Peaks"),$(entry+":Peaks")
    DuplicateDataFolder/O=1 $(path+":Assignments"),$(entry+":Assignments")
    String/G $(entry+":target")=path
    String/G $(entry+":label")=label
    String vars="nextPeakID;selectedPeakRow;lastThreshold;lastMinDistance;deleted;measurementWavelength;zeroCorrection",v
    Variable i
    for(i=0;i<ItemsInList(vars);i+=1)
        v=StringFromList(i,vars)
        Variable/G $(entry+":"+v)=NumVarOrDefault(path+":"+v,0)
    endfor
    vars="status;radiation;calibrationNote;algorithm;detectionRunDescription"
    for(i=0;i<ItemsInList(vars);i+=1)
        v=StringFromList(i,vars)
        String/G $(entry+":"+v)=StrVarOrDefault(path+":"+v,"")
    endfor
End

Function XRD_ApplySnapshot(entry)
    String entry
    SVAR path=$(entry+":target")
    if(cmpstr(StrVarOrDefault(entry+":kind","analysis"),"view")==0)
        return XRD_ApplyViewEntry(entry)
    endif
    XRD_CaptureView()
    XRD_CapturePanelState(1)
    XRD_ResetProfileValidity(path)
    DuplicateDataFolder/O=2 $(entry+":Peaks"),$(path+":Peaks")
    DuplicateDataFolder/O=2 $(entry+":Assignments"),$(path+":Assignments")
    String vars="nextPeakID;selectedPeakRow;lastThreshold;lastMinDistance;deleted;measurementWavelength;zeroCorrection",v
    Variable i
    for(i=0;i<ItemsInList(vars);i+=1)
        v=StringFromList(i,vars)
        NVAR/Z saved=$(entry+":"+v)
        if(NVAR_Exists(saved))
            Variable/G $(path+":"+v)=saved
        endif
    endfor
    vars="status;radiation;calibrationNote;algorithm;detectionRunDescription"
    for(i=0;i<ItemsInList(vars);i+=1)
        v=StringFromList(i,vars)
        SVAR/Z savedText=$(entry+":"+v)
        if(SVAR_Exists(savedText))
            String/G $(path+":"+v)=savedText
        endif
    endfor
    SVAR active=$(XRD_Project()+":activeData")
    active=path
    if(NumVarOrDefault(path+":deleted",0))
        active=""
        String list=XRD_MeasurementOrderList(XRD_Project())
        if(ItemsInList(list))
            active=XRD_Project()+":Measurements:"+StringFromList(0,list)
        endif
    endif
    XRD_InvalidateFit(path)
    XRD_PeakTable(path)
    XRD_RefreshAssignmentTable(path)
    XRD_UpdateAssignedPlot(path)
    XRD_ResetCandidates(path)
    XRD_ClearPreview(path)
    NVAR selected=$(path+":selectedPeakRow")
    XRD_ScoreCandidates(path,selected)
    XRD_Panel()
    return 0
End

Function XRD_Redo()
    XRD_RecordPendingZoom(XRD_Data())
    String project=XRD_Project()
    XRD_UndoSettings(project)
    XRD_EnsureNumeric(project+":Undo:redoCount",0)
    NVAR redo=$(project+":Undo:redoCount"),sequence=$(project+":Undo:sequence"),count=$(project+":Undo:count"),pending=$(project+":Undo:pending")
    pending=0
    if(redo<=0)
        return 0
    endif
    String entry=project+":Undo:Redo"+num2istr(redo-1)
    SVAR path=$(entry+":target"),label=$(entry+":label")
    if(!DataFolderExists(path))
        return -1
    endif
    XRD_Snapshot(path,project+":Undo:Entry"+num2istr(mod(sequence,20)),label)
    String/G $(project+":Undo:Entry"+num2istr(mod(sequence,20))+":kind")=StrVarOrDefault(entry+":kind","analysis")
    sequence+=1;count=min(20,count+1);redo-=1
    XRD_ApplySnapshot(entry)
    Print "やり直しました："+label
    return 1
End

Function XRD_UpdateHistoryUI()
    if(!WinType("XRDWorkbench"))
        return 0
    endif
    ControlInfo/W=XRDWorkbench undoAction
    if(V_flag!=1)
        return 0
    endif
    String project=XRD_Project(),label="元に戻す (Ctrl+Z)",redoLabel="やり直す (Ctrl+Shift+Z)",message=StrVarOrDefault("root:Packages:XRDWorkbench:Recovery:message","自動保存：起動中")
    Variable sequence=NumVarOrDefault(project+":Undo:sequence",0),count=NumVarOrDefault(project+":Undo:count",0),redo=NumVarOrDefault(project+":Undo:redoCount",0)
    if(count>0)
        label="戻す："+StrVarOrDefault(project+":Undo:Entry"+num2istr(mod(sequence-1,20))+":label","")
    endif
    if(redo>0)
        redoLabel="やり直す："+StrVarOrDefault(project+":Undo:Redo"+num2istr(redo-1)+":label","")
    endif
    Button undoAction,win=XRDWorkbench,title="戻す (Ctrl+Z)",help={label}
    Button redoAction,win=XRDWorkbench,title="やり直す",help={redoLabel}
    TitleBox recoveryState,win=XRDWorkbench,title=message,help={label+" / "+redoLabel+" / "+StrVarOrDefault("root:Packages:XRDWorkbench:Recovery:lastFile","")}
End

Function XRD_MarkGraphsStale()
    String project=XRD_Project()
    XRD_EnsureNumeric(project+":analysisRevision",0)
    XRD_EnsureNumeric(project+":referenceShiftMode",0)
    NVAR revision=$(project+":analysisRevision")
    revision+=1
    String wins=WinList("*",";","WIN:1"),win
    Variable i
    for(i=0;i<ItemsInList(wins);i+=1)
        win=StringFromList(i,wins)
        if(cmpstr(GetUserData(win,"","XRDProject"),project)==0 && cmpstr(GetUserData(win,"","XRDReview"),"1")!=0 && cmpstr(GetUserData(win,"","XRDExperimentPlot"),"1")!=0)
            TextBox/W=$win/C/N=XRDNeedsUpdate/F=0/B=1/A=LT "\\Z12同定・条件に変更あり：完成図を再作成してください"
        endif
    endfor
End

Function XRD_StampGraph(win)
    String win
    SetWindow $win userdata(XRDProject)=XRD_Project()
    SetWindow $win userdata(XRDRevision)=num2str(NumVarOrDefault(XRD_Project()+":analysisRevision",0))
End

Function XRD_RecoveryList()
    XRD_RecoverySettings()
    String file=StrVarOrDefault("root:Packages:XRDWorkbench:Recovery:lastFile",""),folder,files,name
    if(!strlen(file))
        DoAlert 0,"まだ復旧コピーがありません。保存設定から作成できます。"
        return -1
    endif
    folder=ParseFilePath(1,file,":",1,0)
    NewPath/O/Q/Z XRDRecoveryBrowsePath,folder
    if(V_flag)
        return -1
    endif
    files=IndexedFile(XRDRecoveryBrowsePath,-1,".pxp")
    String base="root:Packages:XRDWorkbench:Recovery:"
    Make/O/T/N=(ItemsInList(files),3) $(base+"table")
    Wave/T table=$(base+"table")
    Variable i
    for(i=0;i<ItemsInList(files);i+=1)
        name=StringFromList(i,files)
        if(StringMatch(name,"*.pending.pxp"))
            files=RemoveListItem(i,files)
            i-=1
        endif
    endfor
    Redimension/N=(ItemsInList(files),3) table
    for(i=0;i<ItemsInList(files);i+=1)
        name=StringFromList(i,files)
        GetFileFolderInfo/Q/Z folder+name
        table[i][0]=name;table[i][1]=Secs2Date(V_modificationDate,-2)+" "+Secs2Time(V_modificationDate,3);table[i][2]=folder+name
    endfor
    SetDimLabel 1,0,File,table
    SetDimLabel 1,1,'更新日時',table
    SetDimLabel 1,2,'フルパス',table
    Edit/K=1/N=XRDRecoveryCopies table as "復旧コピー一覧：選んだパスをFile > Open Experimentで開く"
    DoAlert 0,"復旧するときは、現在のExperimentを保存してから、一覧の.pxpをFile → Open Experimentで開いてください。最新コピー以外のセッションも一覧に含まれます。"
    return 0
End

Function XRD_BuildComparison()
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project),path,rp
    NewDataFolder/O $(project+":Comparison")
    Make/O/T/N=(0,9) $(project+":Comparison:table")
    Wave/T table=$(project+":Comparison:table")
    Variable i,j,n=0,index
    for(i=0;i<ItemsInList(list);i+=1)
        path=project+":Measurements:"+StringFromList(i,list)
        Wave refs=$(path+":Assignments:refIndex"),ids=$(path+":Assignments:peakID"),peakIDs=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle")
        for(j=0;j<numpnts(refs);j+=1)
            if(refs[j]<=0)
                continue
            endif
            index=refs[j];rp=XRD_ReferencePath(index)
            Redimension/N=(n+1,9) table
            table[n][0]=StrVarOrDefault(path+":displayName","");table[n][1]=StrVarOrDefault(path+":conditionLabel","")
            table[n][2]=XRD_PhaseLabel(index);table[n][3]=StrVarOrDefault(rp+":cardNumber","")
            Variable row=XRD_FindPeakRowByID(peakIDs,ids[j])
            table[n][4]=SelectString(row>=0,"削除済",num2str(angles[max(0,row)]))
            table[n][5]="-";table[n][6]="-"
            String resultPath=XRD80_LatticeResultPath(path,index)
            if(!DataFolderExists(resultPath) && NumVarOrDefault(path+":Lattice:refIndex",-1)==index)
                resultPath=path+":Lattice"
            endif
            if(!NumVarOrDefault(resultPath+":stale",0) && strsearch(StrVarOrDefault(resultPath+":state",""),"計算済",0)==0)
                table[n][5]=num2str(NumVarOrDefault(resultPath+":a",NaN))
                table[n][6]=num2str(NumVarOrDefault(resultPath+":c",NaN))
            endif
            table[n][7]=StrVarOrDefault(path+":status","");table[n][8]=XRD_PeakAngleSource(path,row)
            n+=1
        endfor
    endfor
    String labels="測定;条件;相;Card;2theta(deg);a(Å);c(Å);同定状態;角度の出所"
    for(i=0;i<9;i+=1)
        String label=StringFromList(i,labels)
        SetDimLabel 1,i,$label,table
    endfor
    return n
End

Function XRD_ComparisonPanel()
    XRD_BuildComparison()
    Wave/T table=$(XRD_Project()+":Comparison:table")
    DoWindow/K XRDComparison
    Edit/K=1/N=XRDComparison table as "試料別の同定・格子定数一覧（1行=1ピーク割り当て）"
End

Function XRD_WriteReport(destination)
    String destination
    String project=XRD_Project(),path,list=XRD_MeasurementOrderList(project),rp
    Variable file,i,j,index
    Open/Z=2 file as destination
    if(V_flag)
        return -1
    endif
    fprintf file,"# XRD Workbench v1.2.0 解析レポート\r\n作成日時: %s %s\r\n\r\n",Secs2Date(DateTime,-2),Secs2Time(DateTime,3)
    fprintf file,"候補スコアは確率・含有率ではありません。参照shiftは装置の校正値ではありません。\r\n\r\n"
    fprintf file,"一致幅: %g deg / shift上限: %g deg / 元素条件: %s\r\n\r\n",NumVarOrDefault(project+":matchTolerance",NaN),NumVarOrDefault(project+":maxCommonShift",NaN),StrVarOrDefault(project+":allowedElements","")
    for(i=0;i<ItemsInList(list);i+=1)
        path=project+":Measurements:"+StringFromList(i,list)
        XRD_PeakTable(path)
        fprintf file,"## %s\r\n状態: %s\r\n元ファイル: %s\r\n波長: %g Å / 線源: %s / ゼロ補正: %g deg\r\n校正: %s\r\nピーク検出: %s / しきい値%%（旧:高さ・改善:突出量）: %g / 間隔deg: %g\r\n\r\n",StrVarOrDefault(path+":displayName",""),StrVarOrDefault(path+":status",""),StrVarOrDefault(path+":source",""),NumVarOrDefault(path+":measurementWavelength",NaN),StrVarOrDefault(path+":radiation",""),NumVarOrDefault(path+":zeroCorrection",0),StrVarOrDefault(path+":calibrationNote",""),StrVarOrDefault(path+":algorithm",""),NumVarOrDefault(path+":lastThreshold",NaN),NumVarOrDefault(path+":lastMinDistance",NaN)
        fprintf file,"実行時の検出条件: %s\r\n\r\n",StrVarOrDefault(path+":detectionRunDescription","")
        Wave/T peaks=$(path+":Peaks:table")
        fprintf file,"2theta\tIntensity%%\tAssignment\tStatus\tOrigin\tAngle source\r\n"
        for(j=0;j<DimSize(peaks,0);j+=1)
            fprintf file,"%s\t%s\t%s\t%s\t%s\t%s\r\n",peaks[j][0],peaks[j][1],peaks[j][2],peaks[j][3],peaks[j][4],XRD_PeakAngleSource(path,j)
        endfor
        if(strsearch(StrVarOrDefault(path+":Lattice:state",""),"計算済",0)==0)
            fprintf file,"\r\n格子定数: %s\r\n",ReplaceString("\r",XRD_LatticeResultText(path),"\r\n")
        else
            fprintf file,"\r\n格子定数: %s\r\n",StrVarOrDefault(path+":Lattice:state","未計算")
        endif
        fprintf file,"\r\n"
    endfor
    fprintf file,"## 参照データ（Experiment内のコピー）\r\n"
    for(index=1;index<=NumVarOrDefault(project+":referenceCount",0);index+=1)
        rp=XRD_ReferencePath(index)
        fprintf file,"%s\t%s\t%s\t%s\t%s\r\n",StrVarOrDefault(rp+":cardNumber",""),XRD_PhaseLabel(index),StrVarOrDefault(rp+":formula",""),StrVarOrDefault(rp+":phaseName",""),StrVarOrDefault(rp+":source","")
    endfor
    Close file
    return 0
End

Function XRD_ReportDialog()
    Variable file
    Open/D/Z=2/F="Markdown (*.md):.md;" file as "XRD_report_v1.2.0.md"
    if(V_flag || !strlen(S_fileName))
        return -1
    endif
    return XRD_WriteReport(S_fileName)
End

Function XRD_V50Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String path=XRD_Data()
    strswitch(ba.ctrlName)
        case "profileFit":
            XRD_ProfilePanel()
            break
        case "evidence":
            XRD_EvidencePanel()
            break
        case "audit":
            XRD_AuditPanel()
            break
        case "confirmComplete":
            path=GetUserData(ba.win,"","XRDData")
            if(cmpstr(path,XRD_Data())!=0)
                return -1
            endif
            Variable result=XRD_SetMeasurementComplete(path)
            if(result<0)
                DoAlert 0,"未確認のピークがあります。割り当て・重なり・Unknownを設定してください。"
            else
                DoWindow/K XRDAudit
                XRD_Panel()
            endif
            break
        case "referenceInfo":
            XRD_ReferenceEditor()
            break
        case "applyReference":
            XRD_ApplyReferenceMetadata()
            break
        case "referenceStyle":
            XRD_StylePanel()
            break
        case "referenceErrors":
            Wave/T/Z errors=$(XRD80_Library()+":References:errors")
            if(WaveExists(errors))
                Edit/K=1 errors as "参照TXTのエラー：ファイル名・理由・行"
            endif
            break
        case "metadata":
            XRD_MetadataPanel()
            break
        case "applyMetadata":
            path=GetUserData(ba.win,"","XRDData")
            if(cmpstr(path,XRD_Data())==0 && XRD_ApplyMetadata(path)==0)
                DoWindow/K XRDMetadata
                XRD_Panel()
            endif
            break
        case "latticeQuality":
            XRD_LatticeQualityPanel()
            break
        case "residualGraph":
            path=GetUserData(ba.win,"","XRDData")
            Wave residual=$(path+":Lattice:residual"),angles=$(path+":Lattice:usedAngle")
            Display/K=1 residual vs angles as "格子定数：回帰残差と測定角度"
            ModifyGraph mode=3,marker=19
            Label bottom "2\\f02θ\\f00 (deg.)"
            Label left "Residual (transformed coordinates)"
            break
        case "comparison":
            XRD80_ProjectLatticeSummary()
            break
        case "report":
            XRD_ReportDialog()
            break
        case "redoAction":
            XRD_Redo()
            break
        case "recoveryList":
            XRD_RecoveryList()
            break
        case "close":
            DoWindow/K $ba.win
            break
    endswitch
    return 0
End
