#pragma rtGlobals=3
// v1.3.0: view-only peak markers, registration and reference-cell comparison.
Function/S XRD130_FileSerial(file)
    String file
    String name=ParseFilePath(0,ReplaceString("\\",file,":"),":",1,0),serial=""
    SplitString/E="^([0-9]+)" name,serial
    return serial
End

Function XRD130_RawMaximum(xx,yy,center,radius)
    Wave xx,yy
    Variable center,radius
    Variable nearest=XRD_NearestPoint(xx,center),i,best=nearest
    Variable first=max(0,BinarySearch(xx,center-radius)),last=min(numpnts(xx)-1,max(first,BinarySearch(xx,center+radius)+1))
    for(i=first;i<=last;i+=1)
        if(xx[i]<center-radius || xx[i]>center+radius || numtype(yy[i])!=0)
            continue
        endif
        if(yy[i]>yy[best] || (yy[i]==yy[best] && abs(xx[i]-center)<abs(xx[best]-center)))
            best=i
        endif
    endfor
    return best
End

Function XRD130_PeakDisplay(path)
    String path
    Wave px=$(path+":Peaks:angle"),xx=$(path+":Raw:twoTheta"),yy=$(path+":Processed:intensity")
    Make/O/D/N=(numpnts(px)) $(path+":Preview:peakDisplay130")
    Wave display=$(path+":Preview:peakDisplay130")
    display=interp(px[p],xx,yy)
    return 0
End

Function XRD130_LatticeSide(path)
    String path
    GroupBox workGroup,win=XRDWorkbench,title="格子定数・同定結果の比較"
    TitleBox fitHelp,win=XRDWorkbench,title="採用した相の記号を見ながら計算。\r参照の棒グラフは表示しません。"
    Button compare110,win=XRDWorkbench,pos={16,240},size={175,24},title="比較の追加・除外…",proc=XRD110_Button
    XRD_DrawLiveStack("XRDWorkbench#SideCompare",2)
    XRD_TrimSideAnnotation()
    SetActiveSubwindow XRDWorkbench
    return 0
End

Function XRD130_LatticeLayout(w,h,scale)
    Variable w,h,scale
    Variable side=min(320*scale,w*0.35),inner=side-24*scale
    GroupBox workGroup,win=XRDWorkbench,size={side-4*scale,h-73*scale}
    TitleBox fitHelp,win=XRDWorkbench,pos={12*scale,65*scale},size={inner,42*scale}
    Button metadata,win=XRDWorkbench,pos={12*scale,112*scale},size={inner,22*scale}
    SetVariable wavelength,win=XRDWorkbench,pos={12*scale,141*scale},size={inner,20*scale}
    Button fitOpen,win=XRDWorkbench,pos={12*scale,169*scale},size={inner,25*scale}
    Button latticeQuality,win=XRDWorkbench,pos={12*scale,201*scale},size={inner,25*scale}
    Button compare110,win=XRDWorkbench,pos={12*scale,236*scale},size={inner,25*scale}
    MoveSubwindow/W=XRDWorkbench#SideCompare fnum=(12*scale,275*scale,side-4*scale,h-48*scale)
    ModifyGraph/W=XRDWorkbench#SideCompare gfSize=round(12*scale),fSize=round(12*scale),margin(left)=48*scale,margin(right)=10*scale,margin(bottom)=35*scale,margin(top)=16*scale
    XRD110_SideLegend("XRDWorkbench#SideCompare",2)
    return 0
End

Function/S XRD130_IncompletePlot(paths,flags)
    Wave/T paths
    Wave flags
    String result=""
    Variable i
    for(i=0;i<numpnts(paths);i+=1)
        if((flags[i][0] & 16) && !XRD_IsAnalysisComplete(paths[i]))
            result+=XRD80_MeasurementUID(paths[i])+";"
        endif
    endfor
    return result
End

// Only explicit cell-length metadata is used. No inference from hkl/peaks.
Function XRD130_CellAxis(key)
    String key
    key=LowerStr(ReplaceString(" ",ReplaceString("_",ReplaceString("-",key,""),""),""))
    strswitch(key)
        case "a":
        case "latticea":
        case "cella":
        case "celllengtha":
        case "latticeconstanta":
        case "anm":
            return 0
        case "b":
        case "latticeb":
        case "cellb":
        case "celllengthb":
        case "latticeconstantb":
        case "bnm":
            return 1
        case "c":
        case "latticec":
        case "cellc":
        case "celllengthc":
        case "latticeconstantc":
        case "cnm":
            return 2
    endswitch
    return -1
End

Function XRD130_CellNumber(key,value)
    String key,value
    Variable number=NaN
    sscanf value,"%g",number
    if(number<=0 || numtype(number)!=0)
        return NaN
    endif
    if(GrepString(LowerStr(key),"nm$") || GrepString(LowerStr(value),"(^|[^a-z])nm"))
        number*=10
    endif
    return number
End

Function XRD130_ReadCell(file,cell)
    String file
    Wave cell
    Variable ref,i,axis
    String line,key,value
    Open/R/Z=2 ref as file
    if(V_flag)
        return -1
    endif
    for(i=0;i<200;i+=1)
        FReadLine ref,line
        if(!strlen(line))
            break
        endif
        line=TrimString(line)
        if((StringMatch(line,"#*") || StringMatch(line,"!*")) && XRD_ParseMetadata(line,key,value))
            axis=XRD130_CellAxis(key)
            if(axis>=0)
                cell[axis]=XRD130_CellNumber(key,value)
            endif
        endif
    endfor
    Close ref
    return 0
End

Function XRD130_ReferenceComparison(path,[refresh])
    String path
    Variable refresh
    String lattice=path+":Lattice",rp=XRD_ReferencePath(NumVarOrDefault(lattice+":refIndex",0)),file,hint
    Wave/T/Z existing=$(lattice+":comparison130")
    if(WaveExists(existing) && !refresh)
        return 0
    endif
    Make/FREE/D/N=3 cell=NaN
    Variable i,rows=2,computed,sigma,reference
    for(i=0;i<3;i+=1)
        cell[i]=NumVarOrDefault(rp+":lattice"+StringFromList(i,"A;B;C")+"130",NaN)
    endfor
    if(numtype(cell[0])!=0 || numtype(cell[2])!=0)
        hint=StrVarOrDefault(XRD80_Library()+":referenceFolderHint","")
        file=StrVarOrDefault(rp+":fileName","")
        if(strlen(hint) && strlen(file) && cmpstr(hint,"未選択")!=0)
            XRD130_ReadCell(hint+file,cell)
        endif
    endif
    if(cmpstr(StrVarOrDefault(lattice+":crystalSystem",""),"立方晶")==0)
        rows=1
    endif
    Make/O/T/N=(rows,5) $(lattice+":comparison130")
    Wave/T table=$(lattice+":comparison130")
    for(i=0;i<rows;i+=1)
        String key=StringFromList(i,"a;c")
        computed=NumVarOrDefault(lattice+":"+key,NaN)
        sigma=NumVarOrDefault(lattice+":"+key+"Sigma",NaN)
        reference=cell[SelectNumber(i==0,2,0)]
        table[i][0]=key+" (Å)"
        table[i][1]=num2str(computed)
        table[i][2]=num2str(sigma)
        table[i][3]=SelectString(numtype(reference)==0,"未収録",num2str(reference))
        table[i][4]=SelectString(numtype(reference)==0,"—",num2str(100*(computed/reference-1)))
    endfor
    SetDimLabel 1,0,'格子定数',table
    SetDimLabel 1,1,'計算値 (Å)',table
    SetDimLabel 1,2,'標準誤差 (Å)',table
    SetDimLabel 1,3,'参照の明記値 (Å)',table
    SetDimLabel 1,4,'差 (%)',table
    Variable/G $(lattice+":referenceA130")=cell[0]
    Variable/G $(lattice+":referenceC130")=cell[2]
    String/G $(lattice+":referenceCellSource130")=SelectString(numtype(cell[0])==0 || numtype(cell[2])==0,"参照格子定数は未収録（推定値は表示しません）","参照TXTに明記された格子定数 / Å")
    return 0
End
