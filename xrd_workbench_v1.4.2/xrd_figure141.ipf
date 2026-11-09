#pragma rtGlobals=3

Function/S XRD141_FigureName(kind,project)
    String kind,project
    String name=""
    if(strlen(project) && DataFolderExists(project))
        name=XRD_ProjectDisplayName(project)
    endif
    return SelectString(strlen(name)>0,kind,kind+" "+name)
End

Function/S XRD141_ExportName(win)
    String win
    String recipe=GetUserData(win,"","XRDPlotRecipe"),kind="XRD",name="",project=""
    if(strlen(recipe) && DataFolderExists(recipe))
        if(strsearch(recipe,XRD133_TrendFigures()+":",0)==0)
            kind="格子定数"
        endif
        project=XRD100_ProjectByUID(StrVarOrDefault(recipe+":ownerUID",""))
        name=StrVarOrDefault(recipe+":ownerName141","")
        if(!strlen(name))
            Wave/T/Z names=$(recipe+":sourceProjects")
            if(WaveExists(names) && numpnts(names)>0)
                name=names[0]
            endif
        endif
    endif
    if(strlen(project))
        name=XRD_ProjectDisplayName(project)
    elseif(!strlen(name) && strlen(XRD_Project()))
        name=XRD_ProjectDisplayName(XRD_Project())
    endif
    name=TrimString(name)
    String invalid="<>:/|?*"+num2char(34)+num2char(92)
    Variable i
    for(i=0;i<strlen(invalid);i+=1)
        name=ReplaceString(invalid[i],name,"_")
    endfor
    return kind+SelectString(strlen(name)>0,""," "+name)+".png"
End

Function/S XRD141_AxisLabelPath(base)
    String base
    return base+":"+StringFromList(NumVarOrDefault(base+":axis",1)-1,"temperatureLabel141;compositionLabel141;customLabel")
End

Function/S XRD141_TrendAxisText(base)
    String base
    Variable axis=NumVarOrDefault(base+":axis",1)
    String text=TrimString(StrVarOrDefault(XRD141_AxisLabelPath(base),""))
    if(!strlen(text) && axis==1)
        return "\\f02T\\f00 (°C)"
    elseif(!strlen(text) && axis==2)
        return "\\f02x\\f00"
    elseif(axis==3)
        return XRD133_AxisLabel(base)
    endif
    return text
End

Function XRD141_ReadCardCell(file,cell)
    String file
    Wave cell
    Variable ref
    Open/R/Z=2 ref as file
    if(V_flag)
        return -1
    endif
    FStatus ref
    String json=PadString("",min(V_logEOF,65536),0),lattice,value,pattern
    FBinRead ref,json
    Close ref
    SplitString/E="\"lattice\"\\s*:\\s*\\{([^{}]*)\\}" json,lattice
    if(V_flag!=1)
        return -1
    endif
    Variable i,length
    for(i=0;i<3;i+=1)
        if(numtype(cell[i])==0)
            continue
        endif
        pattern="\""+StringFromList(i,"a;b;c")+"\"\\s*:\\s*([0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\\s*(?:,|$)"
        SplitString/E=(pattern) lattice,value
        if(V_flag==1)
            length=str2num(value)
            if(numtype(length)==0 && length>0)
                cell[i]=length
            endif
        endif
    endfor
    return 0
End

Function XRD141_FillReferenceCell(ref,cell)
    Variable ref
    Wave cell
    cell=NaN
    if(ref<=0)
        return -1
    endif
    String rp=XRD_ReferencePath(ref)
    if(!DataFolderExists(rp))
        return -1
    endif
    Variable i
    for(i=0;i<3;i+=1)
        cell[i]=NumVarOrDefault(rp+":lattice"+StringFromList(i,"A;B;C")+"130",NaN)
    endfor
    if(numtype(cell[0])==0 && numtype(cell[2])==0)
        return 0
    endif
    String hint=StrVarOrDefault(XRD80_Library()+":referenceFolderHint","")
    String filename=StrVarOrDefault(rp+":fileName",""),full
    if(strlen(hint) && strlen(filename) && cmpstr(hint,"未選択")!=0)
        full=RemoveEnding(hint,":")+":"+filename
        GetFileFolderInfo/Q/Z full
        if(V_flag==0 && V_isFile)
            Make/FREE/D/N=3 parsed=NaN
            XRD130_ReadCell(full,parsed)
            for(i=0;i<3;i+=1)
                if(numtype(cell[i])!=0 && numtype(parsed[i])==0 && parsed[i]>0)
                    cell[i]=parsed[i]
                endif
            endfor
        endif
    endif
    if(numtype(cell[0])!=0 || numtype(cell[2])!=0)
        // The reference library pairs txt/<card>.txt with cards/<card>.json.
        String txtFolder=RemoveEnding(hint,":"),library=RemoveEnding(txtFolder,":txt")
        if(cmpstr(txtFolder,library)!=0 && cmpstr(filename,RemoveEnding(filename,".txt"))!=0)
            XRD141_ReadCardCell(library+":cards:"+RemoveEnding(filename,".txt")+".json",cell)
        endif
    endif
    return 0
End

Function/S XRD141_RefDraft(base,ref)
    String base
    Variable ref
    String parent=base+":PlotReferences141"
    String key=StrVarOrDefault(XRD_ReferencePath(ref)+":revisionUID","")
    String folder=parent+":"+PossiblyQuoteName(SelectString(strlen(key)>0,"Ref"+num2istr(max(0,ref)),key))
    NewDataFolder/O $parent
    if(!DataFolderExists(folder))
        NewDataFolder $folder
        String/G $(folder+":aOverride")=""
        String/G $(folder+":cOverride")=""
    endif
    return folder
End

Function/S XRD141_ReferenceHint(ref,canEdit)
    Variable ref,canEdit
    if(ref<=0)
        return SelectString(canEdit,"参照値は相を選ぶと確認できます。","参照カードを特定できません。参照 a・c を入力すると点線に使います。")
    endif
    Make/FREE/D/N=3 cell
    XRD141_FillReferenceCell(ref,cell)
    String a=SelectString(numtype(cell[0])==0,"未収録",num2str(cell[0])+" Å")
    String c=SelectString(numtype(cell[2])==0,"未収録",num2str(cell[2])+" Å")
    return "参照カードの値   a: "+a+"     c: "+c+"   ／   空欄は自動。入力した数値を点線に使います。"
End

Function XRD141_TrendStyle(base,recipe,ref,message)
    String base,recipe,&message
    Variable ref
    String folder=XRD141_RefDraft(base,ref)
    String aText=TrimString(StrVarOrDefault(folder+":aOverride","")),cText=TrimString(StrVarOrDefault(folder+":cOverride",""))
    Variable a=XRD133_ParseX(aText),c=XRD133_ParseX(cText)
    Variable hasC=cmpstr(StrVarOrDefault(recipe+":crystal",XRD133_Crystal(base)),"六方晶")==0
    if(strlen(aText) && (numtype(a)!=0 || a<=0))
        message="参照 a には Å 単位で正の数値を入力してください。"
        return -1
    endif
    if(hasC && strlen(cText) && (numtype(c)!=0 || c<=0))
        message="参照 c には Å 単位で正の数値を入力してください。"
        return -1
    endif
    Make/FREE/D/N=3 cell
    XRD141_FillReferenceCell(ref,cell)
    if(!strlen(aText))
        a=SelectNumber(numtype(cell[0])==0,NumVarOrDefault(recipe+":referenceA",NaN),cell[0])
    endif
    if(hasC && !strlen(cText))
        c=SelectNumber(numtype(cell[2])==0,NumVarOrDefault(recipe+":referenceC",NaN),cell[2])
    endif
    Variable lines=NumVarOrDefault(base+":referenceLines",1)
    Variable/G $(recipe+":referenceA")=SelectNumber(lines,NaN,a)
    Variable/G $(recipe+":referenceC")=SelectNumber(lines && hasC,NaN,c)
    String/G $(recipe+":axisLabel")=XRD133_AxisLabel(base)
    String/G $(recipe+":axisText141")=XRD141_TrendAxisText(base)
    return 0
End

Function XRD141_TickStep(xx)
    Wave xx
    Variable n=numpnts(xx),span=xx[n-1]-xx[0],gap=Inf,i,delta
    for(i=1;i<n;i+=1)
        delta=xx[i]-xx[i-1]
        if(delta>span*1e-9)
            gap=min(gap,delta)
        endif
    endfor
    Variable raw=max(span/8,min(gap,span/4)),factor=10^floor(log(raw))
    Variable ratio=raw/factor,step=10
    if(ratio<=1.000000001)
        step=1
    elseif(ratio<=2.000000001)
        step=2
    elseif(ratio<=2.500000001)
        step=2.5
    elseif(ratio<=5.000000001)
        step=5
    endif
    return step*factor
End

Function/S XRD141_TickLabel(value,step,endpoint)
    Variable value,step,endpoint
    Variable digits=0,scaled
    do
        scaled=step*10^digits
        if(digits>=12 || abs(scaled-round(scaled))<1e-7)
            break
        endif
        digits+=1
    while(1)
    if(endpoint)
        do
            scaled=value*10^digits
            if(digits>=12 || abs(scaled-round(scaled))<1e-7)
                break
            endif
            digits+=1
        while(1)
    endif
    String label
    sprintf label,"%.*f",digits,value
    return ReplaceString("-",label,"−")
End

Function XRD141_TrendXAxis(win,recipe,xx)
    String win,recipe
    Wave xx
    Variable low=xx[0],high=xx[numpnts(xx)-1],i,value,count=1
    if(high==low)
        Variable pad=XRD133_PlotPadding(low,high)
        SetAxis/W=$win bottom low-pad,high+pad
        return 0
    endif
    Variable step=XRD141_TickStep(xx)
    Make/O/D/N=11 $(recipe+":tickPositions141")
    Make/O/T/N=11 $(recipe+":tickLabels141")
    Wave positions=$(recipe+":tickPositions141")
    Wave/T labels=$(recipe+":tickLabels141")
    positions[0]=low
    labels[0]=XRD141_TickLabel(low,step,1)
    for(i=ceil(low/step);i*step<high && count<10;i+=1)
        value=i*step
        if(value-low<0.55*step || high-value<0.55*step)
            continue
        endif
        positions[count]=value
        labels[count]=XRD141_TickLabel(value,step,0)
        count+=1
    endfor
    positions[count]=high
    labels[count]=XRD141_TickLabel(high,step,1)
    Redimension/N=(count+1) positions,labels
    SetAxis/W=$win bottom low,high
    ModifyGraph/W=$win userticks(bottom)={positions,labels}
    return 0
End

Function XRD141_ArrowSpan(win,axis,xx,values,x0,x1,top,bottom)
    String win,axis
    Wave xx,values
    Variable x0,x1,&top,&bottom
    GetAxis/W=$win/Q $axis
    if(x1<xx[0] || x0>xx[numpnts(xx)-1])
        return 0
    endif
    x0=max(x0,xx[0])
    x1=min(x1,xx[numpnts(xx)-1])
    Variable low=interp(x0,xx,values),high=interp(x1,xx,values),i
    Variable yMin=min(low,high),yMax=max(low,high)
    for(i=0;i<numpnts(xx);i+=1)
        if(xx[i]>=x0 && xx[i]<=x1)
            yMin=min(yMin,values[i])
            yMax=max(yMax,values[i])
        endif
    endfor
    if(numtype(yMin)==0 && numtype(yMax)==0)
        Variable first=(V_max-yMax)/(V_max-V_min),last=(V_max-yMin)/(V_max-V_min)
        if(max(first,last)>=0 && min(first,last)<=1)
            top=min(top,max(0,min(first,last)))
            bottom=max(bottom,min(1,max(first,last)))
        endif
    endif
End

Function XRD142_AutoArrow(win,xx,aa,cc,rightSide,hasC,x,y,direction)
    String win
    Wave xx,aa,cc
    Variable rightSide,hasC,&x,&y,&direction
    x=SelectNumber(rightSide,0.15,0.85)
    Variable tip=SelectNumber(rightSide,0.05,0.95)
    GetAxis/W=$win/Q bottom
    Variable xA=V_min+(V_max-V_min)*x,xB=V_min+(V_max-V_min)*tip
    Variable top=1,bottom=0
    XRD141_ArrowSpan(win,"left",xx,aa,min(xA,xB),max(xA,xB),top,bottom)
    if(hasC)
        XRD141_ArrowSpan(win,"right",xx,cc,min(xA,xB),max(xA,xB),top,bottom)
    endif
    if(top>bottom)
        top=0.5
        bottom=0.5
    endif
    Variable above=top>=0.17 || (bottom>0.83 && top>=1-bottom)
    direction=SelectNumber(above,1,-1)
    y=SelectNumber(above,min(0.94,bottom+0.14),max(0.06,top-0.14))
End

Function XRD141_Arrow(win,xx,aa,cc,rightSide,hasC)
    String win
    Wave xx,aa,cc
    Variable rightSide,hasC
    Variable x,y,direction
    XRD142_AutoArrow(win,xx,aa,cc,rightSide,hasC,x,y,direction)
    XRD142_DrawArrow(win,rightSide,x,y,direction)
End

Function XRD141_RefForFigure(recipe)
    String recipe
    String revision=StrVarOrDefault(recipe+":referenceRevisionUID","")
    if(!strlen(revision))
        return 0
    endif
    Variable i,n=NumVarOrDefault(XRD80_Library()+":referenceCount",0)
    for(i=1;i<=n;i+=1)
        if(cmpstr(StrVarOrDefault(XRD_ReferencePath(i)+":revisionUID",""),revision)==0)
            return i
        endif
    endfor
    return 0
End

Function/S XRD141_CopyTrend(source,project,message)
    String source,project,&message
    if(!strlen(source) || !DataFolderExists(source) || cmpstr(StrVarOrDefault(source+":ownerUID",""),StrVarOrDefault(project+":projectUID",""))!=0)
        message="複製する保存図を選んでください。"
        return ""
    endif
    String base=XRD133_TrendSettings(project)
    Variable ref=XRD141_RefForFigure(source)
    Variable/G $(base+":axis")=NumVarOrDefault(source+":axisKind",1)
    String id="LTrend_"+XRD80_NewUID("F"),copy=XRD133_TrendFigures()+":"+id
    DuplicateDataFolder $source,$copy
    if(XRD141_TrendStyle(base,copy,ref,message)<0)
        KillDataFolder/Z $copy
        return ""
    endif
    String/G $(copy+":nativeMacro")=""
    String/G $(copy+":plotUID")=id
    String/G $(copy+":displayName")=XRD141_FigureName("格子定数",project)
    String/G $(copy+":ownerName141")=XRD_ProjectDisplayName(project)
    String/G $(copy+":created")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    message="保存図を新しい書式で複製しました。"
    return copy
End
