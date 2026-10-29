#pragma rtGlobals=3
// XRD Workbench v1.2.0: native Peak AutoFind alternative and atomic external peak import.
Function XRD_DetectAutoFind(path,apply)
    String path
    Variable apply
    XRD_DetectionSettings(path)
    Variable minimum=NumVarOrDefault(path+":autoMinHeight",1),factor=NumVarOrDefault(path+":autoSmoothFactor",0)
    if(numtype(minimum+factor)!=0 || minimum<0 || minimum>100 || factor<0 || factor>100)
        return -1
    endif
    // Reuse only the non-destructive resampling/background preparation.
    Variable result=XRD_DetectRobust(path,0)
    if(result<0)
        return result
    endif
    String d=path+":Detection",native=d+":Native"
    Wave net=$(d+":net"),gx=$(d+":angle"),xx=$(path+":Raw:twoTheta"),yy=$(path+":Processed:intensity")
    if(numpnts(net)<22)
        return -2
    endif
    NewDataFolder/O $native
    Duplicate/O net,$(native+":searchSignal")
    Wave input=$(native+":searchSignal")
    DFREF previous=GetDataFolderDFR()
    SetDataFolder $native
    Variable/C estimates=EstPeakNoiseAndSmfact(input,0,numpnts(input)-1)
    Variable noise=max(0.000001,real(estimates)),actualFactor=SelectNumber(factor>0,imag(estimates),factor),error=0,count=0
    if(numtype(noise+actualFactor)!=0)
        SetDataFolder previous
        return -3
    endif
    try
        count=AutoFindPeaks(input,0,numpnts(input)-1,noise,max(1,actualFactor),500)
    catch
        error=GetRTError(1)
    endtry
    SetDataFolder previous
    Wave/Z info=$(native+":W_AutoPeakInfo")
    if(error || !WaveExists(info) || count<0)
        return -3
    endif
    Wave out=$(d+":selectedIndices"),px=$(d+":peakAngle"),py=$(d+":peakHeight")
    Redimension/N=(count) out,px,py
    Make/FREE/D/N=(count) order=p,strength=info[p][2]
    Sort/R strength,strength,order
    Wave oldAngles=$(path+":Peaks:angle"),oldIDs=$(path+":Peaks:peakID"),oldIndices=$(path+":Peaks:pointIndex")
    Wave/T origin=$(path+":Peaks:origin")
    Variable i,j,k,index,kept=0,ok,angle,gridStep=NumVarOrDefault(d+":gridStep",0.01),distance=NumVarOrDefault(path+":minDistance",0.15)
    for(i=0;i<count;i+=1)
        k=order[i]
        if(info[k][2]<minimum || info[k][1]*gridStep<NumVarOrDefault(path+":detectMinWidth",0.03))
            continue
        endif
        angle=gx[0]+info[k][0]*gridStep
        index=max(0,min(numpnts(xx)-2,BinarySearch(xx,angle)))
        index+=abs(xx[index+1]-angle)<abs(xx[index]-angle)
        ok=1
        for(j=0;j<kept;j+=1)
            if(index==out[j] || abs(xx[index]-xx[out[j]])<distance)
                ok=0
            endif
        endfor
        for(j=0;j<numpnts(oldIDs);j+=1)
            if(cmpstr(origin[j],"Auto")!=0 || XRD_PeakHasReview(path,oldIDs[j]))
                if(index==oldIndices[j] || abs(xx[index]-oldAngles[j])<distance)
                    ok=0
                endif
            endif
        endfor
        if(ok)
            out[kept]=index;px[kept]=xx[index];py[kept]=yy[index];kept+=1
        endif
    endfor
    Redimension/N=(kept) out,px,py
    if(kept>1)
        Sort px,px,py,out
    endif
    String description="igor-peak-autofind-v1; minHeight="+num2str(minimum)+"%; noise="+num2str(noise)+"; derivativeSmoothFactor="+num2str(max(1,actualFactor))+"; minWidth="+num2str(NumVarOrDefault(path+":detectMinWidth",0.03))+"deg; spacing="+num2str(distance)+"deg; cap=500; background="+num2str(NumVarOrDefault(path+":detectBaselineDeg",1.2))+"deg"
    String/G $(d+":settings")=description
    Variable/G $(d+":count")=kept
    Variable/G $(d+":nativeRawCount")=count
    if(apply)
        XRD_RegisterDetection(path,"igor-peak-autofind-v1",description)
    endif
    return kept
End

Function XRD_RegisterDetection(path,algorithm,description)
    String path,algorithm,description
    Wave out=$(path+":Detection:selectedIndices"),angles=$(path+":Peaks:angle"),height=$(path+":Peaks:height"),indices=$(path+":Peaks:pointIndex"),ids=$(path+":Peaks:peakID")
    Wave/T origin=$(path+":Peaks:origin"),summary=$(path+":Peaks:assignmentSummary")
    Variable i,row=NumVarOrDefault(path+":selectedPeakRow",-1),selectedID=-1
    if(row>=0 && row<numpnts(ids))
        selectedID=ids[row]
    endif
    XRD_RecordUndo(path,"Igor標準方式でピーク検出")
    for(i=numpnts(ids)-1;i>=0;i-=1)
        if(cmpstr(origin[i],"Auto")==0 && !XRD_PeakHasReview(path,ids[i]))
            DeletePoints i,1,angles,height,indices,ids,origin,summary
        endif
    endfor
    for(i=0;i<numpnts(out);i+=1)
        XRD_AddPoint(path,out[i],"Auto")
    endfor
    String/G $(path+":algorithm")=algorithm
    String/G $(path+":detectionRunDescription")=description
    NVAR selected=$(path+":selectedPeakRow")
    selected=min(max(row,0),numpnts(ids)-1)
    for(i=0;i<numpnts(ids);i+=1)
        if(ids[i]==selectedID)
            selected=i
        endif
    endfor
    XRD_PeakTable(path)
    XRD_ResetCandidates(path)
    XRD_ClearPreview(path)
    String/G $(path+":candidateFilterKey")=""
    XRD_InvalidateFit(path)
End

Function XRD_DetectionControls(path)
    String path
    Variable mode=NumVarOrDefault(path+":detectorMode",1),advanced=NumVarOrDefault(path+":detectionAdvanced",0),i
    PopupMenu preset,win=XRDDetectionSettings,pos={15,100},title="まず試す設定",mode=1,value="設定を選ぶ;標準;弱いピークを探す;ノイズを抑える;近接ピークを探す",proc=XRD_DetectionPreset,disable=advanced
    TitleBox note,win=XRDDetectionSettings,pos={15,55},title="①方式と設定 → ②候補だけ確認 → ③良ければ登録。\r外部ピークはWorkbenchの『外部ピークリストを追加』から使えます。"
    String controls="prominence;snr;width;spacing;smooth;baseline;search"
    for(i=0;i<7;i+=1)
        ModifyControl $(StringFromList(i,controls)),win=XRDDetectionSettings,disable=1
    endfor
    SetVariable prominence,win=XRDDetectionSettings,pos={15,135},disable=SelectNumber(mode==1 && !advanced,1,0)
    SetVariable snr,win=XRDDetectionSettings,pos={15,170},disable=SelectNumber(mode==1 && !advanced,1,0)
    SetVariable spacing,win=XRDDetectionSettings,pos={15,SelectNumber(advanced,205,250)},disable=0
    SetVariable width,win=XRDDetectionSettings,pos={15,100},disable=SelectNumber(advanced && mode!=0,1,0)
    SetVariable smooth,win=XRDDetectionSettings,pos={15,135},disable=SelectNumber(advanced && mode==1,1,0)
    SetVariable baseline,win=XRDDetectionSettings,pos={15,170},disable=SelectNumber(advanced && mode!=0,1,0)
    SetVariable search,win=XRDDetectionSettings,pos={15,205},disable=SelectNumber(advanced && mode==1,1,0)
    SetVariable oldHeight,win=XRDDetectionSettings,pos={15,135},size={635,25},title="高さしきい値 (%)",limits={0,100,0.1},value=$(path+":threshold"),disable=SelectNumber(mode==0 && !advanced,1,0)
    SetVariable autoHeight,win=XRDDetectionSettings,pos={15,135},size={635,25},title="背景からの最小高さ (%)",limits={0,100,0.1},value=$(path+":autoMinHeight"),disable=SelectNumber(mode==2 && !advanced,1,0)
    SetVariable autoSmooth,win=XRDDetectionSettings,pos={15,SelectNumber(advanced,170,135)},size={635,25},title="二次微分の平滑化係数 (0=自動)",limits={0,100,0.1},value=$(path+":autoSmoothFactor"),disable=SelectNumber(mode==2,1,0)
    Button detectionDetails,win=XRDDetectionSettings,pos={15,SelectNumber(advanced,240,285)},size={635,26},title=SelectString(advanced,"詳細設定を開く ▼","基本設定に戻る ▲"),proc=XRD_DetectionDetails
    TitleBox result,win=XRDDetectionSettings,pos={15,279},title="設定と結果を比較して選びます。手動・外部・同定済みピークは保持。",disable=advanced
    Button previewDetection,win=XRDDetectionSettings,pos={15,325},disable=SelectNumber(mode==0,0,2),title=SelectString(mode==0,"候補だけ確認（登録しない）","旧方式は直接登録のみ")
    Button applyDetection,win=XRDDetectionSettings,pos={295,325}
End

Function XRD_DetectionDetails(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode==2)
        String path=GetUserData("XRDDetectionSettings","","XRDData")
        if(cmpstr(path,XRD_Data())==0)
            NVAR advanced=$(path+":detectionAdvanced")
            advanced=!advanced
            XRD_DetectionControls(path)
        endif
    endif
    return 0
End

Function XRD_DetectionPreset(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2 || pa.popNum<=1)
        return 0
    endif
    String path=GetUserData("XRDDetectionSettings","","XRDData")
    if(cmpstr(path,XRD_Data())!=0)
        return -1
    endif
    NVAR prom=$(path+":detectProminence"),snr=$(path+":detectSNR"),spacing=$(path+":minDistance"),smoothDeg=$(path+":detectSmoothDeg"),width=$(path+":detectMinWidth"),height=$(path+":autoMinHeight"),factor=$(path+":autoSmoothFactor"),legacy=$(path+":threshold"),background=$(path+":detectBaselineDeg"),search=$(path+":detectSearchDeg")
    prom=0.5;snr=4;spacing=0.15;smoothDeg=0.05;width=0.03;height=1;factor=0;legacy=5;background=1.2;search=1.2
    if(pa.popNum==3)
        prom=0.2;snr=3;height=0.3;legacy=1
    elseif(pa.popNum==4)
        prom=1;snr=6;width=0.05;height=2;legacy=10
    elseif(pa.popNum==5)
        spacing=0.06;smoothDeg=0.03;width=0.02;height=0.5;factor=1;legacy=3
    endif
    ControlUpdate/W=XRDDetectionSettings/A
    return 0
End

Function XRD_ExternalPeaks(path,fileName,[replaceAuto])
    String path,fileName
    Variable replaceAuto
    if(!strlen(path))
        return -1
    endif
    Variable ref,lineNo=0,n=0,column=-1,columns=0,i,j,value,index,added=0,duplicates=0,outside=0,headers=0,recorded=0,removed=0
    String line,normalized,token,errorText="",source
    Open/R/Z=2/F="Peak list (*.txt,*.csv,*.tsv,*.dat):.txt,.csv,.tsv,.dat;All files:.*;" ref as fileName
    if(V_flag)
        return -1
    endif
    source=S_fileName
    Make/FREE/D/N=0 angles
    do
        FReadLine ref,line
        if(!strlen(line))
            break
        endif
        lineNo+=1
        line=ReplaceString(num2char(239)+num2char(187)+num2char(191),line,"")
        if(!strlen(TrimString(line)) || StringMatch(TrimString(line),"#*") || StringMatch(TrimString(line),"//*"))
            continue
        endif
        normalized=XRD_ReferenceHeader(line)
        if(column<0)
            for(i=0;i<ItemsInList(normalized," ");i+=1)
                token=StringFromList(i,normalized," ")
                if(WhichListItem(token,"2theta;tt;two_theta;twotheta;2-theta;tth;position;angle")>=0)
                    column=i;headers=1;columns=ItemsInList(normalized," ")
                    break
                endif
            endfor
            if(column>=0)
                continue
            endif
            if(!GrepString(normalized,"^[+-.0-9]"))
                errorText="2theta列の見出しが見つかりません。角度は2theta（deg）で指定してください。"
                break
            endif
            columns=ItemsInList(normalized," ")
            if(columns>2)
                errorText="見出しなしは角度1列、または角度・強度の2列のみです。"
                break
            endif
            column=0
        endif
        normalized=XRD_ReferenceDataLine(line)
        token=StringFromList(column,normalized," ")
        if(ItemsInList(normalized," ")!=columns || !GrepString(token,"^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$"))
            errorText="数値または列数が不正です。"
            break
        endif
        value=str2num(token)
        if(numtype(value)!=0)
            errorText="有限の角度を指定してください。"
            break
        endif
        Redimension/N=(n+1) angles
        angles[n]=value;n+=1
        if(n>5000)
            errorText="5000行を超えました。測定曲線ではなくピークリストを選んでください。"
            break
        endif
    while(1)
    Close ref
    if(strlen(errorText) || n==0)
        Print "ピークリスト読込中止（既存ピークは保持）: 行"+num2istr(lineNo)+" "+errorText
        return -2
    endif
    Sort angles,angles
    Wave xx=$(path+":Raw:twoTheta"),py=$(path+":Peaks:height"),px=$(path+":Peaks:angle"),indices=$(path+":Peaks:pointIndex"),ids=$(path+":Peaks:peakID")
    Wave/T origin=$(path+":Peaks:origin"),summary=$(path+":Peaks:assignmentSummary")
    Variable usable=0
    for(i=0;i<n;i+=1)
        usable+=angles[i]>=xx[0] && angles[i]<=xx[numpnts(xx)-1]
    endfor
    if(!ParamIsDefault(replaceAuto) && replaceAuto && usable>0)
        for(i=numpnts(ids)-1;i>=0;i-=1)
            if(cmpstr(origin[i],"Auto")==0 && !XRD_PeakHasReview(path,ids[i]))
                if(!recorded)
                    XRD_RecordUndo(path,"外部ピークで未確認Autoを置き換える")
                    recorded=1
                endif
                DeletePoints i,1,px,py,indices,ids,origin,summary
                removed+=1
            endif
        endfor
    endif
    NewDataFolder/O $(path+":ExternalPeaks")
    Duplicate/O angles,$(path+":ExternalPeaks:sourceAngles")
    for(i=0;i<n;i+=1)
        if(angles[i]<xx[0] || angles[i]>xx[numpnts(xx)-1])
            outside+=1
            continue
        endif
        index=max(0,min(numpnts(xx)-2,BinarySearch(xx,angles[i])))
        index+=abs(xx[index+1]-angles[i])<abs(xx[index]-angles[i])
        Variable exists=0
        for(j=0;j<numpnts(indices);j+=1)
            exists=max(exists,indices[j]==index)
        endfor
        if(exists)
            duplicates+=1
            continue
        endif
        if(!recorded)
            XRD_RecordUndo(path,"外部ピークリストを追加")
            recorded=1
        endif
        value=XRD_AddPoint(path,index,"External")
        if(value==1)
            for(j=0;j<numpnts(indices);j+=1)
                if(indices[j]==index)
                    // Preserve the external input angle; nearest raw point supplies height.
                    px[j]=angles[i]
                    NewDataFolder/O $(path+":Peaks:External")
                    String provenance=path+":Peaks:External:ID"+num2istr(ids[j])
                    NewDataFolder/O $provenance
                    String/G $(provenance+":fileName")=ParseFilePath(0,source,":",1,0)
                    Variable/G $(provenance+":inputAngle")=angles[i]
                    break
                endif
            endfor
            added+=1
        else
            duplicates+=1
        endif
    endfor
    Sort px,px,py,indices,ids,origin,summary
    String/G $(path+":ExternalPeaks:fileName")=ParseFilePath(0,source,":",1,0)
    String report=num2istr(added)+"本追加 / 未確認Auto "+num2istr(removed)+"本を置換 / 重複 "+num2istr(duplicates)+"本保持 / 範囲外 "+num2istr(outside)+"本除外"
    String/G $(path+":ExternalPeaks:report")=report
    Print "外部ピークリスト: "+report
    XRD_ResetCandidates(path)
    XRD_ClearPreview(path)
    XRD_PeakTable(path)
    if(removed>0)
        XRD_InvalidateFit(path)
    endif
    if(!ParamIsDefault(replaceAuto) && replaceAuto && recorded)
        String/G $(path+":algorithm")="external-peak-list-v1"
        String/G $(path+":detectionRunDescription")="外部ピーク入力（原角度を保持）: "+ParseFilePath(0,source,":",1,0)+"; "+report
    endif
    return added
End

Function XRD_ExternalPeakDialog()
    String path=XRD_Data()
    if(!strlen(path))
        return -1
    endif
    String mode="未確認Autoを置き換える"
    Prompt mode,"読込方法（手動・外部・同定済みピークは保持）",popup,"未確認Autoを置き換える;追加だけ行う"
    DoPrompt "外部ピークリストの取り込み",mode
    if(V_flag)
        return -1
    endif
    Variable result=XRD_ExternalPeaks(path,"",replaceAuto=cmpstr(mode,"未確認Autoを置き換える")==0)
    if(result>=0)
        XRD_Panel()
        DoAlert 0,StrVarOrDefault(path+":ExternalPeaks:report","")+"\r外部の角度を保持し、測定値から強度を表示します。Ctrl+Zで取り消せます。"
    elseif(result==-2)
        DoAlert 0,"ピークリストを読めませんでした。Historyの行番号・理由を確認してください。\r2theta列（deg）を含む表、または角度のみの1列TXTに対応します。"
    endif
    return result
End
