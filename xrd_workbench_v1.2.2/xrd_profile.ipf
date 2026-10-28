#pragma rtGlobals=3
// XRD Workbench v1.2.0: local Igor CurveFit with explicit center adoption.
Function/S XRD_ProfilePath(path,id)
    String path
    Variable id
    return path+":Peaks:Profiles:Peak"+num2istr(id)
End

Function XRD_ResetProfileValidity(path)
    String path
    if(!DataFolderExists(path+":Peaks:Profiles"))
        return 0
    endif
    DFREF folder=$(path+":Peaks:Profiles")
    Variable i=0
    String name
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        Variable/G $(path+":Peaks:Profiles:"+name+":accepted")=0
        Variable/G $(path+":Peaks:Profiles:"+name+":valid")=0
        i+=1
    while(1)
End

Function/S XRD_PeakAngleSource(path,row)
    String path
    Variable row
    Wave ids=$(path+":Peaks:peakID")
    if(row<0 || row>=numpnts(ids))
        return "不明"
    endif
    String rp=XRD_ProfilePath(path,ids[row])
    if(NumVarOrDefault(rp+":accepted",0) && NumVarOrDefault(rp+":valid",0))
        return StrVarOrDefault(rp+":acceptedModel",StrVarOrDefault(rp+":modelName","CurveFit"))+"中心（採用済）"
    endif
    Wave/T/Z origin=$(path+":Peaks:origin")
    if(WaveExists(origin) && cmpstr(origin[row],"External")==0)
        return "外部ピーク："+StrVarOrDefault(path+":Peaks:External:ID"+num2istr(ids[row])+":fileName","入力角度")
    endif
    return "登録位置（測定点）"
End

Function XRD_LatticeAngle(path,row)
    String path
    Variable row
    Wave ids=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle")
    String rp=XRD_ProfilePath(path,ids[row])
    if(NumVarOrDefault(rp+":accepted",0) && NumVarOrDefault(rp+":valid",0))
        return NumVarOrDefault(rp+":acceptedCenter",angles[row])
    endif
    return angles[row]
End

Function XRD_FitPeakProfile(path,row,lo,hi,model,background)
    String path
    Variable row,lo,hi,model,background
    XRD_EnsureMeasurement(path)
    Wave ids=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle"),xx=$(path+":Raw:twoTheta"),yy=$(path+":Processed:intensity")
    if(row<0 || row>=numpnts(ids) || numtype(lo+hi)!=0 || lo>=hi || lo<xx[0] || hi>xx[numpnts(xx)-1] || (model!=1 && model!=2))
        return -1
    endif
    Variable first=0,last=numpnts(xx)-1,i,n
    for(i=0;i<numpnts(xx);i+=1)
        if(xx[i]>=lo)
            first=i
            break
        endif
    endfor
    for(i=numpnts(xx)-1;i>=0;i-=1)
        if(xx[i]<=hi)
            last=i
            break
        endif
    endfor
    n=last-first+1
    if(n<9 || angles[row]<lo || angles[row]>hi)
        return -2
    endif
    // Work in a separate fit workspace. Previously accepted fit is untouched on failure.
    NewDataFolder/O $(path+":ProfileWork")
    String work=path+":ProfileWork"
    Make/O/D/N=(n) $(work+":angle"),$(work+":observed"),$(work+":background"),$(work+":signal"),$(work+":fitted"),$(work+":residual")
    Wave fx=$(work+":angle"),observed=$(work+":observed"),bg=$(work+":background"),signal=$(work+":signal"),fitted=$(work+":fitted"),residual=$(work+":residual")
    fx=xx[first+p];observed=yy[first+p]
    Variable baseline0=0,baseline1=0,edge=min(3,floor(n/4))
    if(background)
        for(i=0;i<edge;i+=1)
            baseline0+=observed[i];baseline1+=observed[n-1-i]
        endfor
        baseline0/=edge;baseline1/=edge
    endif
    bg=baseline0+(baseline1-baseline0)*(fx[p]-fx[0])/(fx[n-1]-fx[0])
    signal=observed[p]-bg[p]
    DFREF previous=GetDataFolderDFR()
    SetDataFolder $work
    Make/O/T/N=4 constraints
    constraints[0]="K1 > 0"
    constraints[1]="K2 > "+num2str(lo)
    constraints[2]="K2 < "+num2str(hi)
    constraints[3]="K3 > 0"
    Variable error=0
    try
        if(model==1)
            CurveFit/Q/N=1/W=2 gauss,signal /X=fx /D=fitted /R=residual /C=constraints; AbortOnRTE
        else
            CurveFit/Q/N=1/W=2 lor,signal /X=fx /D=fitted /R=residual /C=constraints; AbortOnRTE
        endif
    catch
        error=GetRTError(1)
        Print "XRD CurveFit error="+num2istr(error)
    endtry
    SetDataFolder previous
    Wave/Z coef=$(work+":W_coef"),sigma=$(work+":W_sigma")
    if(error || !WaveExists(coef) || !WaveExists(sigma))
        return -3
    endif
    Variable width=abs(coef[3]),center=coef[2]
    if(model==2)
        width=sqrt(abs(coef[3]))
    endif
    if(numtype(width+center+sigma[2])!=0 || width<=0 || center<=lo || center>=hi || width>hi-lo || coef[1]<=0)
        return -4
    endif
    String rp=XRD_ProfilePath(path,ids[row])
    XRD_RecordUndo(path,"ピークCurveFit")
    NewDataFolder/O $rp
    // A replacement preview must not change an already adopted center.
    Variable original=NumVarOrDefault(rp+":originalAngle",angles[row])
    Variable previousAccepted=NumVarOrDefault(rp+":accepted",0)
    Variable previousCenter=NumVarOrDefault(rp+":acceptedCenter",angles[row])
    String previousModel=StrVarOrDefault(rp+":acceptedModel",StrVarOrDefault(rp+":modelName","CurveFit"))
    DuplicateDataFolder/O=1 $work,$(rp+":Result")
    Variable/G $(rp+":valid")=1
    Variable/G $(rp+":accepted")=previousAccepted
    Variable/G $(rp+":acceptedCenter")=previousCenter
    String/G $(rp+":acceptedModel")=previousModel
    Variable/G $(rp+":center")=center
    Variable/G $(rp+":centerSigma")=sigma[2]
    Variable/G $(rp+":originalAngle")=original
    Variable/G $(rp+":model")=model
    Variable/G $(rp+":lo")=lo
    Variable/G $(rp+":hi")=hi
    Variable/G $(rp+":backgroundMode")=background
    Variable factor=SelectNumber(model==1,2,2*sqrt(ln(2)))
    Variable/G $(rp+":fwhm")=factor*width
    Variable/G $(rp+":fwhmSigma")=factor*sigma[3]
    if(model==2)
        Variable/G $(rp+":fwhmSigma")=sigma[3]/width
    endif
    WaveStats/Q residual
    Variable/G $(rp+":rmse")=V_rms
    String/G $(rp+":modelName")=SelectString(model==1,"Lorentz","Gauss")
    String/G $(rp+":backgroundPolicy")="両端3点の平均を結ぶ直線（背景OFFなら0）＋CurveFit定数項"
    String/G $(rp+":created")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    // Re-fitting does not silently revert/replace an accepted angle.
    Variable/G $(rp+":registeredAngle")=angles[row]
    String/G $(path+":profileLastMessage")="フィット完了。中心角度を確認してから採用してください。"
    return 0
End

Function XRD_AdoptProfile(path,id)
    String path
    Variable id
    Wave ids=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle"),heights=$(path+":Peaks:height"),indices=$(path+":Peaks:pointIndex")
    Wave/T origins=$(path+":Peaks:origin"),summaries=$(path+":Peaks:assignmentSummary")
    Variable row=XRD_FindPeakRowByID(ids,id)
    String rp=XRD_ProfilePath(path,id)
    if(row<0 || !NumVarOrDefault(rp+":valid",0))
        return -1
    endif
    XRD_RecordUndo(path,"フィット中心角度を採用")
    NVAR center=$(rp+":center"),accepted=$(rp+":accepted")
    angles[row]=center;accepted=1
    Variable/G $(rp+":acceptedCenter")=center
    String/G $(rp+":acceptedModel")=StrVarOrDefault(rp+":modelName","CurveFit")
    Sort angles,angles,heights,indices,ids,origins,summaries
    NVAR selected=$(path+":selectedPeakRow")
    selected=XRD_FindPeakRowByID(ids,id)
    SVAR status=$(path+":status")
    status="同定中"
    XRD_InvalidateFit(path)
    XRD_RefreshAssignmentTable(path)
    XRD_ScoreCandidates(path,selected)
    XRD_Panel()
    return 0
End

Function XRD_RestoreRegisteredAngle(path,id)
    String path
    Variable id
    Wave ids=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle"),heights=$(path+":Peaks:height"),indices=$(path+":Peaks:pointIndex")
    Wave/T origins=$(path+":Peaks:origin"),summaries=$(path+":Peaks:assignmentSummary")
    String rp=XRD_ProfilePath(path,id)
    Variable row=XRD_FindPeakRowByID(ids,id)
    if(row<0 || !NumVarOrDefault(rp+":valid",0))
        return -1
    endif
    XRD_RecordUndo(path,"測定点の登録角度に戻す")
    angles[row]=NumVarOrDefault(rp+":originalAngle",angles[row])
    Variable/G $(rp+":accepted")=0
    Sort angles,angles,heights,indices,ids,origins,summaries
    NVAR selected=$(path+":selectedPeakRow")
    selected=XRD_FindPeakRowByID(ids,id)
    String/G $(path+":status")="同定中"
    XRD_InvalidateFit(path)
    XRD_RefreshAssignmentTable(path)
    XRD_Panel()
    return 0
End

Function XRD_ProfilePanel()
    String path=XRD_Data()
    if(!strlen(path))
        return -1
    endif
    NVAR selected=$(path+":selectedPeakRow")
    Wave ids=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle"),xx=$(path+":Raw:twoTheta")
    if(selected<0 || selected>=numpnts(ids))
        DoAlert 0,"測定ピークの表からフィットするピークを選んでください。"
        return -1
    endif
    XRD_V50Measurement(path)
    Variable half=NumVarOrDefault(path+":profileHalfWidth",0.4)
    Variable/G $(path+":profileLo")=max(xx[0],angles[selected]-half)
    Variable/G $(path+":profileHi")=min(xx[numpnts(xx)-1],angles[selected]+half)
    DoWindow/K XRDProfilePanel
    NewPanel/K=1/N=XRDProfilePanel/W=(40,40,790,410) as "選択ピーク — Igor CurveFit"
    SetWindow XRDProfilePanel userdata(XRDData)=path
    SetWindow XRDProfilePanel userdata(XRDPeakID)=num2istr(ids[selected])
    DefaultGUIFont/W=XRDProfilePanel all={"Segoe UI",12,0}
    TitleBox info,pos={15,15},frame=0,title="ピークID "+num2istr(ids[selected])+" / 登録角度 "+num2str(angles[selected])+" deg\r範囲内に複数ピークがある場合は、範囲を狭めて単独ピークとして確認してください。"
    SetVariable lower,pos={15,75},size={335,24},title="範囲の下限 (deg)",value=$(path+":profileLo")
    SetVariable upper,pos={375,75},size={335,24},title="範囲の上限 (deg)",value=$(path+":profileHi")
    PopupMenu model,pos={15,115},title="形状",mode=(NumVarOrDefault(path+":profileModel",1)),value="Gauss;Lorentz",proc=XRD_ProfileModelAction
    CheckBox background,pos={375,115},title="両端から直線背景を引く",variable=$(path+":profileBackground")
    Button runProfile,pos={15,155},size={220,30},title="CurveFitして曲線・残差を表示",proc=XRD_ProfileButton
    Button adoptProfile,pos={250,155},size={220,30},title="この中心角度を採用",proc=XRD_ProfileButton
    Button restoreProfile,pos={485,155},size={220,30},title="元の測定点の角度へ戻す",proc=XRD_ProfileButton
    TitleBox profileResult,pos={15,210},size={700,75},frame=0,title="フィット後に中心角度・幅・標準誤差を表示します。"
    TitleBox note,pos={15,300},frame=0,title="Rawは変更しません。採用すると同定・格子定数の再確認が必要になります。\r半値幅は装置幅を補正していません。結晶子サイズ・含有率には変換しません。"
    return 0
End

Function XRD_ProfileModelAction(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        String path=GetUserData(pa.win,"","XRDData")
        Variable/G $(path+":profileModel")=pa.popNum
    endif
End

Function XRD_ProfileButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String path=GetUserData(ba.win,"","XRDData"),rp
    Variable id=str2num(GetUserData(ba.win,"","XRDPeakID")),result
    if(cmpstr(path,XRD_Data())!=0)
        return -1
    endif
    rp=XRD_ProfilePath(path,id)
    strswitch(ba.ctrlName)
        case "adoptProfile":
            result=XRD_AdoptProfile(path,id)
            break
        case "restoreProfile":
            result=XRD_RestoreRegisteredAngle(path,id)
            break
        case "runProfile":
            Wave ids=$(path+":Peaks:peakID")
            Variable row=XRD_FindPeakRowByID(ids,id)
            result=XRD_FitPeakProfile(path,row,NumVarOrDefault(path+":profileLo",NaN),NumVarOrDefault(path+":profileHi",NaN),NumVarOrDefault(path+":profileModel",1),NumVarOrDefault(path+":profileBackground",1))
            if(result==0)
                Wave fx=$(rp+":Result:angle"),observed=$(rp+":Result:observed"),bg=$(rp+":Result:background"),fitted=$(rp+":Result:fitted"),residual=$(rp+":Result:residual")
                Duplicate/O fitted,$(rp+":Result:fullFit")
                Wave fullFit=$(rp+":Result:fullFit")
                fullFit=fitted[p]+bg[p]
                DoWindow/K XRDProfileGraph
                Display/K=1/N=XRDProfileGraph observed/TN=Observed vs fx as "局所ピーク：測定・CurveFit・残差"
                AppendToGraph fullFit/TN=Fit vs fx
                AppendToGraph/L=Residual residual/TN=Residual vs fx
                ModifyGraph rgb(Observed)=(0,0,0),rgb(Fit)=(50000,0,0),rgb(Residual)=(0,15000,45000),axisEnab(left)={0.28,1},axisEnab(Residual)={0,0.20},freePos(Residual)=0
                Label left "Intensity (%)"
                Label bottom "2theta (deg)"
                ShowInfo
                Legend "\\s(Observed) 測定   \\s(Fit) CurveFit   \\s(Residual) 残差"
                TitleBox profileResult,win=XRDProfilePanel,title="中心 "+num2str(NumVarOrDefault(rp+":center",NaN))+" deg / 標準誤差1σ "+num2str(NumVarOrDefault(rp+":centerSigma",NaN))+" deg\r半値幅 "+num2str(NumVarOrDefault(rp+":fwhm",NaN))+" deg / RMSE "+num2str(NumVarOrDefault(rp+":rmse",NaN))+"\r曲線と残差を確認し、問題なければ『この中心角度を採用』を押してください。"
                XRD_Panel()
            endif
            break
    endswitch
    if(result<0)
        DoAlert 0,"フィットできません。範囲内に9点以上あるか、ピークを含むか、形状が適切か確認してください。エラー="+num2istr(result)
    endif
    return result
End
