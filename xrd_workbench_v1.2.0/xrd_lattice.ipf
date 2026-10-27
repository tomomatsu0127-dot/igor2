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
    Edit/N=XRDLatticeInput inputs as "使用=1 / 除外=0。2theta・hklは確認用"
    DoWindow/K XRDLatticePanel
    NewPanel/N=XRDLatticePanel/W=(80,80,510,235) as crystal+" 格子定数"
    SetWindow XRDLatticePanel userdata(XRDData)=path
    TitleBox note,pos={10,15},frame=0,title="表のUse列を1/0に設定してください。六方晶4本以上・立方晶3本以上。\rhkl不明の反射は除外: "+num2istr(NumVarOrDefault(path+":Lattice:missingHKLExcluded",0))+"本"
    SetVariable wavelength,pos={10,65},size={300,20},title="波長 (Å)",value=$(path+":measurementWavelength"),noedit=1
    Button fit,pos={10,102},size={390,27},title="CurveFitで格子定数を計算",proc=XRD_FitButton
    return 0
End

Function XRD_FitCubic(path)
    String path
    Wave input=$(path+":Lattice:inputs")
    XRD82_ExcludeMissingLatticeHKL(input)
    Variable wavelength=NumVarOrDefault(path+":measurementWavelength",NumVarOrDefault(XRD_Project()+":wavelength",1.5406))
    String/G $(path+":Lattice:state")="計算未完了"
    Variable i,n=0,theta,hkl2
    for(i=0;i<DimSize(input,0);i+=1)
        n+=(input[i][0]==1)
    endfor
    if(n<3 || wavelength<=0 || numtype(wavelength)!=0)
        return -1
    endif
    Make/O/D/N=(n) $(path+":Lattice:fitX"),$(path+":Lattice:fitY"),$(path+":Lattice:fitted"),$(path+":Lattice:residual")
    Wave xx=$(path+":Lattice:fitX"),yy=$(path+":Lattice:fitY"),fitted=$(path+":Lattice:fitted"),residual=$(path+":Lattice:residual")
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
    SetDataFolder $(path+":Lattice")
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
    Wave/Z coef=$(path+":Lattice:W_coef"),sigma=$(path+":Lattice:W_sigma")
    if(!WaveExists(coef) || !WaveExists(sigma))
        return -4
    endif
    if(numpnts(coef)!=2 || coef[0]<=0 || numtype(coef[0])!=0)
        return -4
    endif
    Variable/G $(path+":Lattice:a")=sqrt(1/coef[0])
    Variable/G $(path+":Lattice:aSigma")=0.5*sigma[0]/coef[0]^1.5
    Variable/G $(path+":Lattice:c")=NaN
    Variable/G $(path+":Lattice:cSigma")=NaN
    Variable/G $(path+":Lattice:wavelength")=wavelength
    String/G $(path+":Lattice:crystalSystem")="立方晶"
    String/G $(path+":Lattice:state")="計算済（立方晶・PDF変換式・直線回帰）"
    XRD_RecordLatticeQuality(path)
    XRD80_RecordLatticeRun(path)
    return 0
End

Function XRD_PrepareLattice(path,refIndex)
    String path
    Variable refIndex
    String rp=XRD_ReferencePath(refIndex)
    Wave ids=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex"),rows=$(path+":Assignments:refPeakIndex")
    Wave peakIDs=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle")
    Wave hh=$(rp+":h"),kk=$(rp+":k"),ll=$(rp+":l")
    NewDataFolder/O $(path+":Lattice")
    Wave/Z previousInputs=$(path+":Lattice:inputs")
    Make/FREE/D/N=(0,6) savedInputs
    if(WaveExists(previousInputs))
        Redimension/N=(DimSize(previousInputs,0),6) savedInputs
        savedInputs=previousInputs[p][q]
    endif
    Make/O/D/N=(numpnts(ids),6) $(path+":Lattice:inputs")
    Wave inputs=$(path+":Lattice:inputs")
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
    Variable/G $(path+":Lattice:refIndex")=refIndex
    Variable/G $(path+":Lattice:missingHKLExcluded")=excluded
    Variable/G $(path+":Lattice:zeroCorrection")=NumVarOrDefault(path+":zeroCorrection",0)
    String/G $(path+":Lattice:anglePolicy")="採用済みフィット中心、なければ登録位置。補正角度=2theta-zeroCorrection"
    String/G $(path+":Lattice:state")="未計算"
    return n
End

Function XRD_FitHexagonal(path)
    String path
    String/G $(path+":Lattice:state")="計算未完了"
    Wave input=$(path+":Lattice:inputs")
    XRD82_ExcludeMissingLatticeHKL(input)
    Variable wavelength=NumVarOrDefault(path+":measurementWavelength",NumVarOrDefault(XRD_Project()+":wavelength",1.5406))
    Variable i,n=0,theta,h,k,l
    for(i=0;i<DimSize(input,0);i+=1)
        if(input[i][0]==1)
            n+=1
        endif
    endfor
    if(n<4 || wavelength<=0 || numtype(wavelength)!=0)
        return -1
    endif
    Make/O/D/N=(n) $(path+":Lattice:fitX"),$(path+":Lattice:fitY"),$(path+":Lattice:fitZ"),$(path+":Lattice:fitted"),$(path+":Lattice:residual")
    Wave xx=$(path+":Lattice:fitX"),yy=$(path+":Lattice:fitY"),zz=$(path+":Lattice:fitZ"),fitted=$(path+":Lattice:fitted"),residual=$(path+":Lattice:residual")
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
    SetDataFolder $(path+":Lattice")
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
    Wave coef=$(path+":Lattice:W_coef"),sigma=$(path+":Lattice:W_sigma")
    if(numpnts(coef)<3 || coef[1]<=0 || coef[2]<=0 || numtype(coef[1]+coef[2])!=0)
        return -4
    endif
    Variable/G $(path+":Lattice:a")=sqrt(1/coef[1])
    Variable/G $(path+":Lattice:c")=sqrt(1/coef[2])
    Variable/G $(path+":Lattice:aSigma")=0.5*sigma[1]/coef[1]^1.5
    Variable/G $(path+":Lattice:cSigma")=0.5*sigma[2]/coef[2]^1.5
    Variable/G $(path+":Lattice:wavelength")=wavelength
    String/G $(path+":Lattice:state")="計算済（六方晶・PDF変換式・poly2D次数1）"
    XRD_RecordLatticeQuality(path)
    XRD80_RecordLatticeRun(path)
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
