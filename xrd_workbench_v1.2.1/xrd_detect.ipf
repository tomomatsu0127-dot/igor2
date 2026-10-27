#pragma rtGlobals=3
// XRD Workbench v1.2.0: baseline-aware prominence detector; no external runtime.
Function XRD_DetectionSettings(path)
    String path
    XRD_EnsureNumeric(path+":detectorMode",1)
    XRD_EnsureNumeric(path+":autoMinHeight",1)
    XRD_EnsureNumeric(path+":autoSmoothFactor",0)
    XRD_EnsureNumeric(path+":detectionAdvanced",0)
    XRD_EnsureNumeric(path+":detectProminence",0.5)
    XRD_EnsureNumeric(path+":detectSNR",4)
    XRD_EnsureNumeric(path+":detectSmoothDeg",0.05)
    XRD_EnsureNumeric(path+":detectMinWidth",0.03)
    XRD_EnsureNumeric(path+":detectBaselineDeg",1.2)
    XRD_EnsureNumeric(path+":detectSearchDeg",1.2)
End

Function XRD_Detect(path)
    String path
    XRD_EnsureMeasurement(path)
    if(NumVarOrDefault(path+":detectorMode",1)==0)
        return XRD_DetectLegacy(path)
    endif
    if(NumVarOrDefault(path+":detectorMode",1)==2)
        return XRD_DetectAutoFind(path,1)
    endif
    return XRD_DetectRobust(path,1)
End

Function XRD_OddWindow(width,step,n,minimum)
    Variable width,step,n,minimum
    return min(32767,min(2*floor((n-1)/2)+1,max(minimum,2*floor(width/step/2)+1)))
End

Function XRD_DetectRobust(path,apply)
    String path
    Variable apply
    XRD_DetectionSettings(path)
    NVAR prom=$(path+":detectProminence"),snr=$(path+":detectSNR"),smoothDeg=$(path+":detectSmoothDeg"),minWidth=$(path+":detectMinWidth"),background=$(path+":detectBaselineDeg"),search=$(path+":detectSearchDeg"),distance=$(path+":minDistance")
    if(numtype(prom+snr+smoothDeg+minWidth+background+search+distance)!=0 || prom<0 || prom>100 || snr<1 || snr>30 || smoothDeg<0 || smoothDeg>1 || minWidth<0 || minWidth>2 || background<max(0.1,4*smoothDeg) || background>10 || search<max(0.05,2*minWidth) || search>10 || distance<0)
        return -1
    endif
    Wave xx=$(path+":Raw:twoTheta"),yy=$(path+":Processed:intensity")
    Variable n=numpnts(xx),i,j,k,m,step,delta,span
    if(n<7)
        return -2
    endif
    Make/FREE/D/N=(n-1) differences=xx[p+1]-xx[p]
    WaveStats/Q differences
    if(V_min<=0 || numtype(V_min+V_max)!=0)
        return -2
    endif
    Sort differences,differences
    step=differences[floor((n-2)/2)]
    span=xx[n-1]-xx[0]
    m=min(500001,max(7,round(span/step)+1))
    step=span/(m-1)
    String d=path+":Detection"
    NewDataFolder/O $d
    Make/O/D/N=(m) $(d+":angle"),$(d+":input")
    Wave gx=$(d+":angle"),gy=$(d+":input")
    gx=xx[0]+step*p
    k=0
    for(i=0;i<m;i+=1)
        do
            if(k>=n-2 || xx[k+1]>=gx[i])
                break
            endif
            k+=1
        while(1)
        gy[i]=yy[k]+(yy[k+1]-yy[k])*(gx[i]-xx[k])/(xx[k+1]-xx[k])
    endfor
    Variable sg=XRD_OddWindow(smoothDeg,step,m,5),bg=XRD_OddWindow(background,step,m,5),local=XRD_OddWindow(search,step,m,5)
    Duplicate/O gy,$(d+":filteredSignal")
    Duplicate/O gy,$(d+":baseline")
    Wave signal=$(d+":filteredSignal"),base=$(d+":baseline")
    if(smoothDeg>0)
        Smooth/S=2/E=3 sg,signal
    endif
    Smooth/M=0/MPCT=20 bg,base
    Smooth/B/E=3 max(3,2*floor(bg/8)+1),base
    Duplicate/O signal,$(d+":net")
    Duplicate/O signal,$(d+":noise")
    Wave net=$(d+":net"),noise=$(d+":noise")
    net=max(0,signal[p]-base[p])
    if(smoothDeg>0)
        Variable c0=3*(3*sg*sg-7)/(4*sg*(sg*sg-4))
        noise=abs(gy[p]-signal[p])/(0.67448975*sqrt(1-c0))
    else
        noise=abs(gy[min(p+1,m-1)]-gy[p])/0.95387255
    endif
    Smooth/M=0 bg,noise
    noise=max(noise[p],0.000001)
    Make/O/D/N=(m) $(d+":indices"),$(d+":prominences"),$(d+":widths"),$(d+":snrs")
    Wave candidates=$(d+":indices"),strength=$(d+":prominences"),widths=$(d+":widths"),ratios=$(d+":snrs")
    Variable count=0,plateauEnd,peak,lowL,lowR,level,width,left,right,half=floor(local/2),value
    i=1
    do
        if(i>=m-1)
            break
        endif
        plateauEnd=i
        do
            if(plateauEnd>=m-2 || net[plateauEnd+1]!=net[i])
                break
            endif
            plateauEnd+=1
        while(1)
        if(net[i]>net[i-1] && net[plateauEnd]>net[plateauEnd+1] && net[i]>=prom)
            peak=floor((i+plateauEnd)/2)
            lowL=net[peak];lowR=net[peak]
            for(j=peak-1;j>=max(0,peak-half);j-=1)
                if(net[j]>net[peak])
                    break
                endif
                lowL=min(lowL,net[j])
            endfor
            for(j=peak+1;j<=min(m-1,peak+half);j+=1)
                if(net[j]>net[peak])
                    break
                endif
                lowR=min(lowR,net[j])
            endfor
            value=net[peak]-max(lowL,lowR)
            if(value>=max(prom,snr*noise[peak]))
                level=net[peak]-value/2
                j=peak
                do
                    if(j<=0 || net[j-1]<=level)
                        break
                    endif
                    j-=1
                while(1)
                left=gx[j]
                if(j>0 && net[j]>net[j-1])
                    left=gx[j-1]+step*(level-net[j-1])/(net[j]-net[j-1])
                endif
                j=peak
                do
                    if(j>=m-1 || net[j+1]<=level)
                        break
                    endif
                    j+=1
                while(1)
                right=gx[j]
                if(j<m-1 && net[j]>net[j+1])
                    right=gx[j]+step*(net[j]-level)/(net[j]-net[j+1])
                endif
                width=right-left
                if(width>=minWidth)
                    candidates[count]=peak
                    strength[count]=value
                    widths[count]=width
                    ratios[count]=value/noise[peak]
                    count+=1
                endif
            endif
        endif
        i=plateauEnd+1
    while(1)
    Redimension/N=(count) candidates,strength,widths,ratios
    if(count>1)
        Sort/R strength,strength,candidates,widths,ratios
    endif
    Wave oldAngles=$(path+":Peaks:angle"),oldIDs=$(path+":Peaks:peakID"),oldIndices=$(path+":Peaks:pointIndex")
    Wave/T origins=$(path+":Peaks:origin")
    Make/O/D/N=(count) $(d+":selectedIndices"),$(d+":peakAngle"),$(d+":peakHeight")
    Wave out=$(d+":selectedIndices"),px=$(d+":peakAngle"),py=$(d+":peakHeight")
    Variable kept=0,index,ok,q
    for(i=0;i<count;i+=1)
        index=BinarySearch(xx,gx[candidates[i]])
        index=max(0,min(n-2,index))
        if(abs(xx[index+1]-gx[candidates[i]])<abs(xx[index]-gx[candidates[i]]))
            index+=1
        endif
        ok=1
        for(j=0;j<kept;j+=1)
            if(out[j]==index || abs(xx[index]-xx[out[j]])<distance)
                ok=0
                break
            endif
        endfor
        for(j=0;j<numpnts(oldAngles);j+=1)
            if(cmpstr(origins[j],"Auto")==0 && !XRD_PeakHasReview(path,oldIDs[j]))
                continue
            endif
            if(index==oldIndices[j] || abs(xx[index]-oldAngles[j])<distance)
                ok=0
                break
            endif
        endfor
        if(ok)
            out[kept]=index;px[kept]=xx[index];py[kept]=yy[index]
            kept+=1
        endif
    endfor
    Redimension/N=(kept) out,px,py
    if(kept>1)
        Sort px,px,py,out
    endif
    String description="prominence-sg-v1; prominence="+num2str(prom)+"%; SNR="+num2str(snr)+"; smooth="+num2str(smoothDeg)+"deg ("+num2istr(SelectNumber(smoothDeg>0,0,sg))+" pts); minWidth="+num2str(minWidth)+"deg; baseline="+num2str(background)+"deg ("+num2istr(bg)+" pts); search="+num2str(search)+"deg ("+num2istr(local)+" pts); spacing="+num2str(distance)+"deg; grid="+num2istr(m)+"; gridStep="+num2str(step)
    String/G $(d+":settings")=description
    Variable/G $(d+":count")=kept
    Variable/G $(d+":gridStep")=step
    if(apply)
        XRD_RecordUndo(path,"背景・ノイズを考慮してピーク検出")
        Variable selectedID=-1,oldRow=NumVarOrDefault(path+":selectedPeakRow",-1)
        if(oldRow>=0 && oldRow<numpnts(oldIDs))
            selectedID=oldIDs[oldRow]
        endif
        Wave heights=$(path+":Peaks:height")
        Wave/T summaries=$(path+":Peaks:assignmentSummary")
        for(i=numpnts(oldAngles)-1;i>=0;i-=1)
            if(cmpstr(origins[i],"Auto")==0 && !XRD_PeakHasReview(path,oldIDs[i]))
                DeletePoints i,1,oldAngles,heights,oldIndices,oldIDs,origins,summaries
            endif
        endfor
        for(i=0;i<kept;i+=1)
            XRD_AddPoint(path,out[i],"Auto")
        endfor
        String/G $(path+":algorithm")="prominence-sg-v1"
        String/G $(path+":detectionRunDescription")=description
        NVAR lastThreshold=$(path+":lastThreshold"),lastDistance=$(path+":lastMinDistance")
        lastThreshold=prom;lastDistance=distance
        XRD_PeakTable(path)
        NVAR selectedRow=$(path+":selectedPeakRow")
        selectedRow=min(max(oldRow,0),numpnts(oldIDs)-1)
        for(i=0;i<numpnts(oldIDs);i+=1)
            if(oldIDs[i]==selectedID)
                selectedRow=i
                break
            endif
        endfor
        XRD_ResetCandidates(path)
        XRD_ClearPreview(path)
        String/G $(path+":candidateFilterKey")=""
        XRD_InvalidateFit(path)
    endif
    return kept
End

Function XRD_DetectionPanel()
    String path=XRD_Data()
    if(!strlen(path))
        return -1
    endif
    XRD_DetectionSettings(path)
    DoWindow/K XRDDetectionSettings
    NewPanel/N=XRDDetectionSettings/W=(20,20,715,395) as "この測定のピーク検出方式・精度"
    DefaultGUIFont/W=XRDDetectionSettings all={"Segoe UI",12,0}
    SetWindow XRDDetectionSettings userdata(XRDData)=path
    NVAR mode=$(path+":detectorMode")
    PopupMenu detectorMode,pos={15,15},title="検出方式",mode=(mode+1),value="旧方式：高さと間隔;背景・ノイズ・突出量;Igor標準：Peak AutoFind",proc=XRD_DetectorMode
    TitleBox note,pos={15,60},frame=0,title="設定はこの測定に保存します。Rawデータ・表示曲線は変えません。\rまず『候補だけ確認』で結果を見てから登録できます。手動・同定済みピークは保持します。"
    SetVariable prominence,pos={15,120},size={635,25},title="周囲からの最小突出量 (%)",limits={0,100,0.1},value=$(path+":detectProminence")
    SetVariable snr,pos={15,160},size={635,25},title="ノイズ比の下限",limits={1,30,0.5},value=$(path+":detectSNR")
    SetVariable width,pos={15,200},size={635,25},title="最小ピーク幅 (deg)",limits={0,2,0.01},value=$(path+":detectMinWidth")
    SetVariable spacing,pos={15,240},size={635,25},title="最小ピーク間隔 (deg)",limits={0,5,0.01},value=$(path+":minDistance")
    SetVariable smooth,pos={15,280},size={635,25},title="平滑化の幅 (deg / 0で無効)",limits={0,1,0.01},value=$(path+":detectSmoothDeg")
    SetVariable baseline,pos={15,320},size={635,25},title="背景を評価する幅 (deg)",limits={0.1,10,0.1},value=$(path+":detectBaselineDeg")
    SetVariable search,pos={15,360},size={635,25},title="突出量を評価する幅 (deg)",limits={0.05,10,0.1},value=$(path+":detectSearchDeg")
    TitleBox result,pos={15,402},frame=0,title="弱いピークが少ない：突出量・ノイズ比を下げる。\r近接ピークが消える：平滑化幅・最小間隔を小さくする。"
    Button previewDetection,pos={15,465},size={260,32},title="候補だけ確認（登録しない）",proc=XRD_DetectionButton
    Button applyDetection,pos={295,465},size={350,32},title="この設定で検出してピークを登録",proc=XRD_DetectionButton
    XRD_DetectionControls(path)
    return 0
End

Function XRD_DetectorMode(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        String path=GetUserData("XRDDetectionSettings","","XRDData")
        Variable/G $(path+":detectorMode")=pa.popNum-1
        Execute/P/Q "XRD_Panel()"
        Execute/P/Q "XRD_DetectionPanel()"
    endif
    return 0
End

Function XRD_ShowDetection(path)
    String path
    String d=path+":Detection"
    Wave raw=$(path+":Processed:intensity"),xx=$(path+":Raw:twoTheta"),yy=$(d+":filteredSignal"),gx=$(d+":angle"),base=$(d+":baseline"),px=$(d+":peakAngle"),py=$(d+":peakHeight")
    DoWindow/K XRDDetectionPreview
    Display/N=XRDDetectionPreview/W=(70,70,850,510) raw/TN=Raw vs xx as "検出候補の確認（まだ登録しません）"
    AppendToGraph/W=XRDDetectionPreview yy/TN=Smoothed vs gx
    AppendToGraph/W=XRDDetectionPreview base/TN=Background vs gx
    AppendToGraph/W=XRDDetectionPreview py/TN=Peaks vs px
    ModifyGraph/W=XRDDetectionPreview rgb(Raw)=(0,0,0),rgb(Smoothed)=(0,25000,50000),rgb(Background)=(35000,35000,35000),rgb(Peaks)=(50000,0,0),mode(Peaks)=3,marker(Peaks)=19,msize(Peaks)=3
    Label/W=XRDDetectionPreview bottom "2θ (deg.)"
    Label/W=XRDDetectionPreview left "Intensity (%)"
    Legend/W=XRDDetectionPreview/C/N=Info/F=0 "\\Z12\\s(Raw) 測定値    \\s(Smoothed) 平滑化    \\s(Background) 推定背景\r\\s(Peaks) 新規登録候補: "+num2istr(NumVarOrDefault(d+":count",0))+"本（手動・同定済みは別に保持）"
    return 0
End

Function XRD_DetectionButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(cmpstr(ba.ctrlName,"detectorSettings")==0)
        Execute/P/Q "XRD_DetectionPanel()"
        return 0
    endif
    String path=GetUserData("XRDDetectionSettings","","XRDData")
    if(cmpstr(path,XRD_Data())!=0)
        DoAlert 0,"測定を切り替えました。検出設定を開き直してください。"
        return -1
    endif
    Variable result
    if(cmpstr(ba.ctrlName,"previewDetection")==0)
        if(NumVarOrDefault(path+":detectorMode",1)==0)
            DoAlert 0,"候補だけの確認は改善方式で使えます。旧方式は検出・登録ボタンで実行してください。"
            return 0
        endif
        if(NumVarOrDefault(path+":detectorMode",1)==2)
            result=XRD_DetectAutoFind(path,0)
        else
            result=XRD_DetectRobust(path,0)
        endif
        if(result>=0)
            XRD_ShowDetection(path)
        endif
    else
        result=XRD_Detect(path)
        if(result>=0)
            Execute/P/Q "XRD_Panel()"
        endif
    endif
    if(result<0)
        DoAlert 0,"検出できませんでした。7点以上のデータが必要です。背景幅は平滑化幅の4倍以上、突出量の評価幅は最小ピーク幅の2倍以上にしてください。"
    endif
    return result
End
