#pragma rtGlobals=3
// XRD Workbench v1.2.0. Hexagonal fit using supplied PDF p15 and Igor CurveFit.
Function XRD_LatticePanel()
    String path=XRD_Data(),list="",rp,choice
    if(strlen(path)==0)
        return -1
    endif
    if(!XRD_IsAnalysisComplete(path))
        DoAlert 0,"先にこの測定データの同定を完了してください。"
        return -1
    endif
    list=XRD_LatticeChoices(path)
    Variable selected
    String crystal="六方晶"
    if(strlen(list)==0)
        DoAlert 0,"相に割り当てたピークがありません。"
        return -1
    endif
    choice=StringFromList(0,list)
    Prompt choice,"この試料で計算する相（連番 / 採用ピーク数）",popup,list
    Prompt crystal,"晶系",popup,"六方晶;立方晶"
    DoPrompt "格子定数：相と晶系",choice,crystal
    if(V_flag)
        return -1
    endif
    selected=str2num(StringFromList(0,choice,":"))
    Wave phaseMap=$(path+":Lattice:phaseMap")
    selected=phaseMap[selected-1]
    XRD_PrepareLattice(path,selected)
    String/G $(path+":Lattice:crystalSystem")=crystal
    Wave inputs=$(path+":Lattice:inputs")
    DoWindow/K XRDLatticeInput
    XRD131_KeepPanelSize()
    Edit/K=1/N=XRDLatticeInput inputs as "使用=1 / 除外=0。2theta・hklは確認用"
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDLatticePanel")
    DoWindow/K XRDLatticePanel
    XRD131_KeepPanelSize()
    NewPanel/K=1/N=XRDLatticePanel/W=(80,80,510,235) as crystal+" 格子定数"
    ModifyPanel/W=XRDLatticePanel fixedSize=0
    SetWindow XRDLatticePanel userdata(XRDData)=path
    TitleBox note,pos={10,15},frame=0,title="表のUse列を1/0に設定してください。六方晶4本以上・立方晶3本以上。\rhkl不明の反射は除外: "+num2istr(NumVarOrDefault(path+":Lattice:missingHKLExcluded",0))+"本"
    SetVariable wavelength,pos={10,65},size={300,20},title="波長 (Å)",value=$(path+":measurementWavelength"),noedit=1
    Button fit,pos={10,102},size={390,27},title="CurveFitで格子定数を計算",proc=XRD_FitButton
    XRD123_FinishPanel("XRDLatticePanel",panelState123)
    return 0
End

Function XRD_FitCubic(path,[workspace])
    String path,workspace
    Variable batch=!ParamIsDefault(workspace)
    if(!batch)
        workspace=path+":Lattice"
    endif
    Wave input=$(workspace+":inputs")
    XRD82_ExcludeMissingLatticeHKL(input)
    String owner=SelectString(batch,XRD_Project(),XRD80_ProjectForMeasurement(path))
    Variable wavelength=NumVarOrDefault(path+":measurementWavelength",NumVarOrDefault(owner+":wavelength",1.5406))
    String/G $(workspace+":state")="計算未完了"
    Variable i,n=0,theta,hkl2
    for(i=0;i<DimSize(input,0);i+=1)
        n+=(input[i][0]==1)
    endfor
    if(n<3 || wavelength<=0 || numtype(wavelength)!=0)
        return -1
    endif
    Make/O/D/N=(n) $(workspace+":fitX"),$(workspace+":fitY"),$(workspace+":fitted"),$(workspace+":residual")
    Wave xx=$(workspace+":fitX"),yy=$(workspace+":fitY"),fitted=$(workspace+":fitted"),residual=$(workspace+":residual")
    n=0
    for(i=0;i<DimSize(input,0);i+=1)
        if(input[i][0]!=1)
            continue
        endif
        theta=(input[i][1]-NumVarOrDefault(path+":zeroCorrection",0))*pi/360
        hkl2=input[i][2]^2+input[i][3]^2+input[i][4]^2
        if(theta<=0 || theta>=pi/2 || hkl2<=0 || numtype(theta+hkl2)!=0)
            return -2
        endif
        // Provided cubic PDF p9-p15: intercept is 1/a^2.
        xx[n]=8*sin(theta)*cos(theta)^2/(wavelength^2*hkl2)
        yy[n]=4*sin(theta)^2/(wavelength^2*hkl2)
        n+=1
    endfor
    WaveStats/Q xx
    if(V_max-V_min<1e-12)
        return -3
    endif
    DFREF previous=GetDataFolderDFR()
    SetDataFolder $workspace
    Variable fitError=0
    try
        CurveFit/Q/N=1 line,yy /X=xx /D=fitted /R=residual
    catch
        fitError=GetRTError(1)
    endtry
    SetDataFolder previous
    if(fitError)
        return -3
    endif
    Wave/Z coef=$(workspace+":W_coef"),sigma=$(workspace+":W_sigma")
    if(!WaveExists(coef) || !WaveExists(sigma))
        return -4
    endif
    if(numpnts(coef)!=2 || coef[0]<=0 || numtype(coef[0])!=0)
        return -4
    endif
    Variable/G $(workspace+":a")=sqrt(1/coef[0])
    Variable/G $(workspace+":aSigma")=0.5*sigma[0]/coef[0]^1.5
    Variable/G $(workspace+":c")=NaN
    Variable/G $(workspace+":cSigma")=NaN
    Variable/G $(workspace+":wavelength")=wavelength
    String/G $(workspace+":crystalSystem")="立方晶"
    String/G $(workspace+":state")="計算済（立方晶・PDF変換式・直線回帰）"
    XRD133_FinishFit(path,workspace,batch)
    return 0
End

Function XRD_PrepareLattice(path,refIndex,[workspace,previous])
    String path,workspace,previous
    Variable refIndex
    String rp=XRD_ReferencePath(refIndex)
    Wave ids=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex"),rows=$(path+":Assignments:refPeakIndex")
    Wave peakIDs=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle")
    Wave hh=$(rp+":h"),kk=$(rp+":k"),ll=$(rp+":l")
    if(ParamIsDefault(workspace))
        workspace=path+":Lattice"
    endif
    if(ParamIsDefault(previous))
        previous=workspace
    endif
    NewDataFolder/O $workspace
    Wave/Z previousInputs=$(previous+":inputs")
    Make/FREE/D/N=(0,6) savedInputs
    if(WaveExists(previousInputs))
        Redimension/N=(DimSize(previousInputs,0),6) savedInputs
        savedInputs=previousInputs[p][q]
    endif
    Make/O/D/N=(numpnts(ids),6) $(workspace+":inputs")
    Wave inputs=$(workspace+":inputs")
    Variable i,n=0,row,previousRow,excluded=0,reflection
    for(i=0;i<numpnts(ids);i+=1)
        if(refs[i]!=refIndex)
            continue
        endif
        row=XRD_FindPeakRowByID(peakIDs,ids[i])
        if(row<0)
            continue
        endif
        reflection=rows[i]
        if(reflection<0 || reflection>=numpnts(hh))
            continue
        endif
        if(!XRD82_HKLKnown(hh[reflection],kk[reflection],ll[reflection]))
            excluded+=1
            continue
        endif
        inputs[n][0]=1
        for(previousRow=0;previousRow<DimSize(savedInputs,0);previousRow+=1)
            if(savedInputs[previousRow][5]==ids[i] && savedInputs[previousRow][2]==hh[rows[i]] && savedInputs[previousRow][3]==kk[rows[i]] && savedInputs[previousRow][4]==ll[rows[i]])
                inputs[n][0]=savedInputs[previousRow][0]
                break
            endif
        endfor
        inputs[n][1]=XRD_LatticeAngle(path,row)
        inputs[n][2]=hh[rows[i]]
        inputs[n][3]=kk[rows[i]]
        inputs[n][4]=ll[rows[i]]
        inputs[n][5]=ids[i]
        n+=1
    endfor
    Redimension/N=(n,6) inputs
    SetDimLabel 1,0,Use,inputs
    SetDimLabel 1,1,'2theta',inputs
    SetDimLabel 1,2,h,inputs
    SetDimLabel 1,3,k,inputs
    SetDimLabel 1,4,l,inputs
    SetDimLabel 1,5,PeakID,inputs
    Variable/G $(workspace+":refIndex")=refIndex
    Variable/G $(workspace+":missingHKLExcluded")=excluded
    Variable/G $(workspace+":zeroCorrection")=NumVarOrDefault(path+":zeroCorrection",0)
    String/G $(workspace+":anglePolicy")="採用済みフィット中心、なければ登録位置。補正角度=2theta-zeroCorrection"
    String/G $(workspace+":state")="未計算"
    return n
End

Function XRD_FitHexagonal(path,[workspace])
    String path,workspace
    Variable batch=!ParamIsDefault(workspace)
    if(!batch)
        workspace=path+":Lattice"
    endif
    String/G $(workspace+":state")="計算未完了"
    Wave input=$(workspace+":inputs")
    XRD82_ExcludeMissingLatticeHKL(input)
    String owner=SelectString(batch,XRD_Project(),XRD80_ProjectForMeasurement(path))
    Variable wavelength=NumVarOrDefault(path+":measurementWavelength",NumVarOrDefault(owner+":wavelength",1.5406))
    Variable i,n=0,theta,h,k,l
    for(i=0;i<DimSize(input,0);i+=1)
        if(input[i][0]==1)
            n+=1
        endif
    endfor
    if(n<4 || wavelength<=0 || numtype(wavelength)!=0)
        return -1
    endif
    Make/O/D/N=(n) $(workspace+":fitX"),$(workspace+":fitY"),$(workspace+":fitZ"),$(workspace+":fitted"),$(workspace+":residual")
    Wave xx=$(workspace+":fitX"),yy=$(workspace+":fitY"),zz=$(workspace+":fitZ"),fitted=$(workspace+":fitted"),residual=$(workspace+":residual")
    n=0
    for(i=0;i<DimSize(input,0);i+=1)
        if(input[i][0]!=1)
            continue
        endif
        theta=(input[i][1]-NumVarOrDefault(path+":zeroCorrection",0))*pi/360
        h=input[i][2];k=input[i][3];l=input[i][4]
        if(theta<=0 || theta>=pi/2 || numtype(theta+h+k+l)!=0)
            return -2
        endif
        xx[n]=(h*h+h*k+k*k)*wavelength^2/(6*sin(theta)*cos(theta)^2)
        yy[n]=l*l*wavelength^2/(8*sin(theta)*cos(theta)^2)
        zz[n]=sin(theta)/(2*cos(theta)^2)
        n+=1
    endfor
    // Keep all Igor fit outputs in this measurement's Lattice folder.
    DFREF previous=GetDataFolderDFR()
    SetDataFolder $workspace
    Variable fitError=0
    try
        CurveFit/Q/N=1 poly2D 1,zz /X={xx,yy} /D=fitted /R=residual
    catch
        fitError=GetRTError(1)
    endtry
    SetDataFolder previous
    if(fitError)
        return -3
    endif
    Wave coef=$(workspace+":W_coef"),sigma=$(workspace+":W_sigma")
    if(numpnts(coef)<3 || coef[1]<=0 || coef[2]<=0 || numtype(coef[1]+coef[2])!=0)
        return -4
    endif
    Variable/G $(workspace+":a")=sqrt(1/coef[1])
    Variable/G $(workspace+":c")=sqrt(1/coef[2])
    Variable/G $(workspace+":aSigma")=0.5*sigma[1]/coef[1]^1.5
    Variable/G $(workspace+":cSigma")=0.5*sigma[2]/coef[2]^1.5
    Variable/G $(workspace+":wavelength")=wavelength
    String/G $(workspace+":state")="計算済（六方晶・PDF変換式・poly2D次数1）"
    XRD133_FinishFit(path,workspace,batch)
    return 0
End

Function XRD_FitButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String path=GetUserData("XRDLatticePanel","","XRDData")
    Variable refIndex=NumVarOrDefault(path+":Lattice:refIndex",0)
    if(refIndex<=0 || !XRD_IsAnalysisComplete(path))
        DoAlert 0,"未対応のピークがあります。各ピークを同定、またはUnknownにしてください。"
        return -1
    endif
    // Refresh angles/hkl after assignment or zero-correction edits; keep each Use flag.
    XRD_PrepareLattice(path,refIndex)
    SVAR crystal=$(path+":Lattice:crystalSystem")
    Variable result
    if(cmpstr(crystal,"立方晶")==0)
        result=XRD_FitCubic(path)
    else
        result=XRD_FitHexagonal(path)
    endif
    if(result<0)
        DoAlert 0,"計算できません。必要本数のピーク、hklの独立性、波長を確認してください。エラー="+num2istr(result)
    else
        XRD_LatticeQualityPanel()
    endif
    return 0
End
