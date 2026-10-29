#pragma rtGlobals=3
// XRD Workbench v1.2.0. Labels, view persistence, periodic selection and figure layout.
Function XRD_V4Settings(project)
    String project
    XRD_EnsureNumeric(project+":stackGap",30)
    XRD_EnsureNumeric(project+":figureHeadroom",30)
    SVAR protected=$(project+":protectedClasses")
    protected="Z-type;X-type;M-type;QS-type;W-type;T-type;Y-type;U-type"
End

Function/S XRD_TypeName(text)
    String text
    String types="QS;Z;X;M;W;T;Y;U",token
    Variable i
    text=ReplaceString("_",text,"-")
    text=ReplaceString("－",text,"-")
    text=ReplaceString("–",text,"-")
    text=ReplaceString("−",text,"-")
    text=ReplaceString("型",text,"-type")
    for(i=0;i<ItemsInList(types);i+=1)
        token=StringFromList(i,types)
        if(GrepString(text,"(?i)(^|[^A-Za-z])"+token+"[- ]*type([^A-Za-z]|$)") || cmpstr(LowerStr(TrimString(text)),LowerStr(token))==0)
            return token+"-type"
        endif
    endfor
    return ""
End

Function/S XRD_FormulaLabel(formula)
    String formula
    String out="",ch,charge,subs="₀;₁;₂;₃;₄;₅;₆;₇;₈;₉",supers="⁰;¹;²;³;⁴;⁵;⁶;⁷;⁸;⁹"
    Variable i=0,c,j
    do
        if(i>=strlen(formula))
            break
        endif
        ch=formula[i]
        c=char2num(ch)
        if(c==32 || c==9)
            i+=1
            continue
        endif
        if(cmpstr(ch,"+")==0 || cmpstr(ch,"-")==0)
            charge=""
            j=i+1
            do
                if(j>=strlen(formula))
                    break
                endif
                c=char2num(formula[j])-48
                if(c<0 || c>9)
                    break
                endif
                charge+=StringFromList(c,supers)
                j+=1
            while(1)
            if(j>i+1)
                out+=charge+SelectString(cmpstr(ch,"+")==0,"⁻","⁺")
                i=j
                continue
            endif
        endif
        if(c>=48 && c<=57)
            out+=StringFromList(c-48,subs)
        else
            out+=ch
        endif
        i+=1
    while(1)
    return out
End

Function/S XRD_PhaseLabel(refIndex)
    Variable refIndex
    String rp=XRD_ReferencePath(refIndex),typeName
    SVAR name=$(rp+":phaseName"),formula=$(rp+":formula"),phase=$(rp+":phaseClass")
    String override=StrVarOrDefault(rp+":displayOverride","")
    if(strlen(TrimString(override)))
        return override
    endif
    typeName=XRD_ReferenceType(refIndex)
    if(strlen(typeName)>0)
        return typeName
    endif
    if(strlen(TrimString(formula))>0)
        return XRD_FormulaLabel(formula)
    endif
    return name
End

Function XRD_CaptureView()
    if(!WinType("XRDWorkbench"))
        return 0
    endif
    String path=GetUserData("XRDWorkbench","","XRDData")
    if(strlen(path)==0 || !DataFolderExists(path))
        return 0
    endif
    DoUpdate
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    if(V_flag)
        return 0
    endif
    Variable/G $(path+":viewXMin")=V_min
    Variable/G $(path+":viewXMax")=V_max
    GetAxis/W=XRDWorkbench#Pattern/Q left
    Variable/G $(path+":viewYMin")=V_min
    Variable/G $(path+":viewYMax")=V_max
    Variable/G $(path+":hasView")=1
    XRD_CacheModeView(path)
End

Function XRD_RestoreView(path)
    String path
    if(XRD_RestoreModeView(path))
        return 0
    endif
    NVAR/Z saved=$(path+":hasView")
    if(!NVAR_Exists(saved))
        return 0
    endif
    if(saved)
        NVAR xmin=$(path+":viewXMin"),xmax=$(path+":viewXMax"),ymin=$(path+":viewYMin"),ymax=$(path+":viewYMax")
        SetAxis/W=XRDWorkbench#Pattern bottom xmin,xmax
        SetAxis/W=XRDWorkbench#Pattern left ymin,ymax
    endif
End

Function XRD_ResetView()
    String path=XRD_Data()
    if(strlen(path))
        Variable/G $(path+":followPeak")=0
        ControlInfo/W=XRDWorkbench followPeak
        if(V_flag)
            ControlUpdate/W=XRDWorkbench followPeak
        endif
    endif
    if(strlen(path)==0)
        return 0
    endif
    Wave xx=$(path+":Raw:twoTheta")
    SetAxis/W=XRDWorkbench#Pattern bottom xx[0],xx[numpnts(xx)-1]
    Variable upper=110
    if(cmpstr(GetUserData("XRDWorkbench#Pattern","","XRDCompare"),"1")==0)
        upper=140+135*(ItemsInList(XRD_MeasurementOrderList(XRD_Project()))-1)
    endif
    SetAxis/W=XRDWorkbench#Pattern left -30,upper
    XRD_CaptureView()
End

Function XRD_RestoreReferencePath(project)
    String project
    SVAR hint=$(project+":referenceFolderHint")
    if(strlen(hint)>0 && cmpstr(hint,"未選択")!=0)
        NewPath/O/Q/Z XRDReferencePath,hint
        Variable result=V_flag
        if(result)
            KillPath/Z XRDReferencePath
        endif
        return result
    endif
    return -1
End

Function/S XRD_LatticeChoices(path)
    String path
    NewDataFolder/O $(path+":Lattice")
    Wave refs=$(path+":Assignments:refIndex"),ids=$(path+":Assignments:peakID")
    Make/O/D/N=0 $(path+":Lattice:phaseMap"),$(path+":Lattice:phaseCounts")
    Wave map=$(path+":Lattice:phaseMap"),counts=$(path+":Lattice:phaseCounts")
    Variable i,j,n=0,row,k,duplicate
    String labels="",rp
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]<=0)
            continue
        endif
        duplicate=0
        for(k=0;k<i;k+=1)
            if(refs[k]==refs[i] && ids[k]==ids[i])
                duplicate=1
            endif
        endfor
        if(duplicate)
            continue
        endif
        row=-1
        for(j=0;j<n;j+=1)
            if(map[j]==refs[i])
                row=j
                break
            endif
        endfor
        if(row<0)
            row=n
            n+=1
            Redimension/N=(n) map,counts
            map[row]=refs[i]
            counts[row]=0
        endif
        counts[row]+=1
    endfor
    for(i=0;i<n;i+=1)
        rp=XRD_ReferencePath(map[i])
        SVAR card=$(rp+":cardNumber")
        labels+=num2istr(i+1)+": "+XRD_PhaseLabel(map[i])+" / "+num2istr(counts[i])+" peaks ["+card+"];"
    endfor
    return labels
End

Function XRD_ElementPanel()
    String project=XRD_Project(),symbols=XRD_PeriodicSymbols(),positions=XRD_PeriodicPositions(),symbol,entry,control
    SVAR allowed=$(project+":allowedElements")
    Variable i,row,col,selected
    PauseUpdate; Silent 1
    String panelState123=XRD123_PanelState("XRDElements")
    DoWindow/K XRDElements
    NewPanel/FLT=1/K=1/N=XRDElements/W=(25,25,885,520) as "元素周期表：試料に含まれる元素を選択"
    SetWindow XRDElements userdata(XRDProject)=project
    TitleBox help,pos={12,10},frame=0,title="✓が付いた元素で候補を絞ります。Oなどの構成元素も選択してください。未選択なら全候補。"
    CheckBox enabled,pos={12,35},title="元素フィルターを使う",variable=$(project+":elementFilterMode"),proc=XRD_ElementEnabled
    TitleBox pending,pos={260,35},frame=0,title="変更後は下の「候補を更新」を押してください"
    for(i=0;i<ItemsInList(symbols);i+=1)
        symbol=StringFromList(i,symbols)
        entry=StringFromList(i,positions)
        row=str2num(StringFromList(0,entry,","))
        col=str2num(StringFromList(1,entry,","))
        control="el"+symbol
        selected=WhichListItem(symbol,allowed)>=0
        Button $control,pos={12+(col-1)*46,65+(row-1)*35},size={43,30},title=SelectString(selected,"","✓")+symbol,proc=XRD_ElementButton
        if(selected)
            Button $control,fColor=(42000,54000,65535)
        endif
    endfor
    TitleBox exception,pos={12,390},frame=0,title="Z・X・M・QS・W・T・Y・U-typeは除外しません。認識できない組成も候補に残します。"
    Button clear,pos={12,430},size={180,30},title="選択をすべて解除",proc=XRD_ElementButton
    Button apply,pos={210,430},size={220,30},title="選択した元素で候補を更新",proc=XRD_ElementButton
    XRD110_ElementAttach()
    XRD123_FinishPanel("XRDElements",panelState123)
    return 0
End

Function XRD_ElementButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(cmpstr(GetUserData("XRDElements","","XRDProject"),XRD_Project())!=0)
        return -1
    endif
    SVAR allowed=$(XRD_Project()+":allowedElements")
    NVAR mode=$(XRD_Project()+":elementFilterMode")
    String symbol=ba.ctrlName,path=XRD_Data()
    symbol=symbol[2,inf]
    if(cmpstr(ba.ctrlName,"clear")==0)
        allowed=""
    elseif(cmpstr(ba.ctrlName,"apply")==0)
        XRD_InvalidateFilterCandidates()
        if(strlen(path)>0)
            NVAR selected=$(path+":selectedPeakRow")
            XRD_ScoreCandidates(path,selected)
        endif
        XRD_Panel()
        DoWindow/K XRDElements
        return 0
    else
        if(WhichListItem(symbol,allowed)>=0)
            allowed=RemoveFromList(symbol,allowed)
        else
            allowed+=symbol+";"
        endif
        mode=1
    endif
    XRD_UpdateElementButtons(ba.ctrlName)
    CheckBox enabled,win=XRDElements,value=mode
    TitleBox pending,win=XRDElements,title="選択を変更しました → 下の「候補を更新」で反映"
    return 0
End

Function/S XRD_PeriodicSymbols()
    return "H;He;Li;Be;B;C;N;O;F;Ne;Na;Mg;Al;Si;P;S;Cl;Ar;K;Ca;Sc;Ti;V;Cr;Mn;Fe;Co;Ni;Cu;Zn;Ga;Ge;As;Se;Br;Kr;Rb;Sr;Y;Zr;Nb;Mo;Tc;Ru;Rh;Pd;Ag;Cd;In;Sn;Sb;Te;I;Xe;Cs;Ba;La;Ce;Pr;Nd;Pm;Sm;Eu;Gd;Tb;Dy;Ho;Er;Tm;Yb;Lu;Hf;Ta;W;Re;Os;Ir;Pt;Au;Hg;Tl;Pb;Bi;Po;At;Rn;Fr;Ra;Ac;Th;Pa;U;Np;Pu;Am;Cm;Bk;Cf;Es;Fm;Md;No;Lr;Rf;Db;Sg;Bh;Hs;Mt;Ds;Rg;Cn;Nh;Fl;Mc;Lv;Ts;Og"
End

Function/S XRD_PeriodicPositions()
    return "1,1;1,18;2,1;2,2;2,13;2,14;2,15;2,16;2,17;2,18;3,1;3,2;3,13;3,14;3,15;3,16;3,17;3,18;4,1;4,2;4,3;4,4;4,5;4,6;4,7;4,8;4,9;4,10;4,11;4,12;4,13;4,14;4,15;4,16;4,17;4,18;5,1;5,2;5,3;5,4;5,5;5,6;5,7;5,8;5,9;5,10;5,11;5,12;5,13;5,14;5,15;5,16;5,17;5,18;6,1;6,2;8,4;8,5;8,6;8,7;8,8;8,9;8,10;8,11;8,12;8,13;8,14;8,15;8,16;8,17;8,18;6,4;6,5;6,6;6,7;6,8;6,9;6,10;6,11;6,12;6,13;6,14;6,15;6,16;6,17;6,18;7,1;7,2;9,4;9,5;9,6;9,7;9,8;9,9;9,10;9,11;9,12;9,13;9,14;9,15;9,16;9,17;9,18;7,4;7,5;7,6;7,7;7,8;7,9;7,10;7,11;7,12;7,13;7,14;7,15;7,16;7,17;7,18"
End
