#pragma rtGlobals=3
// XRD Workbench v1.2.0: reference family resolution and responsive controls.
Function/S XRD_ReferenceType(index)
    Variable index
    String rp=XRD_ReferencePath(index),value,typeName,source
    value=StrVarOrDefault(rp+":typeOverride","自動")
    if(cmpstr(value,"通常相")==0)
        return ""
    endif
    typeName=XRD_TypeName(value)
    if(strlen(typeName))
        return typeName
    endif
    typeName=XRD_TypeName(StrVarOrDefault(rp+":phaseClass",""))
    if(strlen(typeName))
        return typeName
    endif
    source=ReplaceString("\\",StrVarOrDefault(rp+":source",""),"/")
    source=StringFromList(ItemsInList(source,"/")-1,source,"/")
    value=StrVarOrDefault(rp+":phaseName","")+" "+StrVarOrDefault(rp+":fileName","")+" "+source
    typeName=XRD_TypeName(value)
    if(strlen(typeName))
        return typeName
    endif
    // Explicit, project-local group names are also accepted as user classification.
    typeName=XRD_TypeName(StrVarOrDefault(rp+":styleGroup",""))
    if(strlen(typeName))
        return typeName
    endif
    // Card identities verified against the user's original named TXT references.
    value=StrVarOrDefault(rp+":cardNumber","")
    strswitch(value)
        case "00-054-0099":
            return "Y-type"
        case "01-073-2034":
            return "X-type"
        case "00-039-1433":
            return "M-type"
        case "01-072-8381":
            return "Z-type"
    endswitch
    return XRD_FormulaFamily(StrVarOrDefault(rp+":formula",""))
End

Function/S XRD_FormulaFamily(formula)
    String formula
    formula=ReplaceString(" ",formula,"")
    formula=ReplaceString("(",formula,"")
    formula=ReplaceString(")",formula,"")
    // Narrow composition hints used by the previous HTML. This is a UI family
    // hint, not structural identification; the user can override with 通常相.
    if(GrepString(formula,"^Ba2(Co|Zn|Ni|Cu|Mg|Mn|Fe|Me)2Fe12O22$"))
        return "Y-type"
    endif
    if(GrepString(formula,"^Ba((Co|Zn|Ni|Cu|Mg|Mn|Me)2Fe16|Fe18)O27$"))
        return "W-type"
    endif
    if(cmpstr(formula,"BaFe28O46")==0)
        return "X-type"
    endif
    if(cmpstr(formula,"BaFe12O19")==0)
        return "M-type"
    endif
    if(GrepString(formula,"^Ba3(Co|Zn|Ni|Cu|Mg|Mn|Fe|Me)2Fe24O41$"))
        return "Z-type"
    endif
    if(cmpstr(formula,"BaSn0.9Fe5.47O11")==0)
        return "QS-type"
    endif
    return ""
End

Function XRD_FilledSymbol(index)
    Variable index
    return str2num(StringFromList(mod(index,5),"19;16;17;18;23"))
End

Function XRD_RepairAutoStyles(project)
    String project
    Wave vals=$(XRD80_Styles()+":values")
    Variable i,r,g,b
    for(i=0;i<DimSize(vals,0);i+=1)
        XRD_PhaseColor(i+1,r,g,b)
        // Only replace the exact old auto-generated slash styles. User-selected
        // colors/symbols are preserved; no guessing based on marker alone.
        if(vals[i][0]==19+mod(i,3) && (vals[i][0]==20 || vals[i][0]==21) && vals[i][1]==r && vals[i][2]==g && vals[i][3]==b)
            vals[i][0]=XRD_FilledSymbol(i)
            vals[i][1]=0.75*r;vals[i][2]=0.75*g;vals[i][3]=0.75*b
        endif
    endfor
End

Function/S XRD_StyleChoices()
    String project=XRD_Project(),labels="",rp
    NVAR count=$(project+":referenceCount")
    Variable i
    for(i=1;i<=count;i+=1)
        rp=XRD_ReferencePath(i)
        labels+=XRD_PhaseLabel(i)+" ["+StrVarOrDefault(rp+":cardNumber","")+"];"
    endfor
    return labels
End

Function XRD_StyleTargetAction(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2 || cmpstr(GetUserData("XRDStyles","","XRDProject"),XRD_Project())!=0)
        return 0
    endif
    STRUCT WMButtonAction save
    save.eventCode=2
    XRD_ApplyStyleButton(save)
    NVAR selected=$(XRD_Project()+":selectedReference")
    selected=str2num(StringFromList(pa.popNum-1,GetUserData("XRDStyles","","XRDTargetMap")))-1
    XRD_StylePanel()
    return 0
End

Function XRD_StyleTypeAction(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2 || cmpstr(GetUserData("XRDStyles","","XRDProject"),XRD_Project())!=0)
        return 0
    endif
    Variable index=str2num(GetUserData("XRDStyles","","XRDRef"))
    String rp=XRD_ReferencePath(index)
    String/G $(rp+":typeOverride")=pa.popStr
    // Replace only this reference's group; other existing groups are retained.
    String/G $(rp+":styleGroup")=""
    String/G $(rp+":styleGroup")=XRD_PhaseLabel(index)
    XRD_InvalidateFilterCandidates()
    XRD_RebuildReferenceTable(XRD_Project())
    XRD_RefreshStyles()
    XRD_Panel()
    XRD_StylePanel()
    return 0
End

Function XRD_UpdateElementButtons(control)
    String control
    String symbols=XRD_PeriodicSymbols(),symbol,name
    SVAR allowed=$(XRD_Project()+":allowedElements")
    Variable i,selected
    for(i=0;i<ItemsInList(symbols);i+=1)
        symbol=StringFromList(i,symbols)
        name="el"+symbol
        if(cmpstr(control,"clear")!=0 && cmpstr(control,name)!=0)
            continue
        endif
        selected=WhichListItem(symbol,allowed)>=0
        Button $name,win=XRDElements,title=SelectString(selected,"","✓")+symbol
        if(selected)
            Button $name,win=XRDElements,fColor=(42000,54000,65535)
        else
            Button $name,win=XRDElements,fColor=(60000,60000,60000)
        endif
    endfor
End

Function XRD_ElementEnabled(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    if(cba.eventCode==2)
        TitleBox pending,win=XRDElements,title="変更しました → 下の「候補を更新」で反映"
    endif
    return 0
End

Function XRD_InvalidateFilterCandidates()
    String project=XRD_Project(),name
    DFREF measurements=$(project+":Measurements")
    Variable i=0
    do
        name=GetIndexedObjNameDFR(measurements,4,i)
        if(strlen(name)==0)
            break
        endif
        String/G $(XRD110_MeasurementPath(project,name)+":candidateFilterKey")=""
        i+=1
    while(1)
End

Function XRD_EnsureFilterCurrent(path)
    String path
    if(strlen(path)==0)
        return 0
    endif
    String project=XRD_Project()
    NVAR mode=$(project+":elementFilterMode"),selected=$(path+":selectedPeakRow")
    SVAR allowed=$(project+":allowedElements")
    String key=num2istr(mode)+":"+allowed+":"+num2str(NumVarOrDefault(project+":typeSelectionRevision",0))+":"+num2str(NumVarOrDefault(project+":candidateRadius",0.6))+":"+num2str(NumVarOrDefault(project+":matchTolerance",0.2))+":"+num2str(NumVarOrDefault(project+":maxCommonShift",0.3))
    key+="|library="+num2str(NumVarOrDefault(XRD80_Library()+":revision",0))
    key+="|shift="+num2str(NumVarOrDefault(project+":referenceShiftMode",0))
    if(cmpstr(StrVarOrDefault(path+":candidateFilterKey",""),key)!=0)
        XRD_ResetCandidates(path)
        XRD_ScoreCandidates(path,selected)
        String/G $(path+":candidateFilterKey")=key
    endif
End

Function XRD_SelectedPeakGuide(path)
    String path
    XRD_FollowSelection(path)
    String win="XRDWorkbench#Pattern"
    Wave xx=$(path+":Peaks:angle")
    NVAR selected=$(path+":selectedPeakRow")
    DrawAction/W=$win/L=UserBack getgroup=XRDSelectedPeak
    if(V_flag)
        DrawAction/W=$win/L=UserBack getgroup=XRDSelectedPeak,delete
    endif
    DrawAction/W=$win/L=UserFront getgroup=XRDSelectedArrow
    if(V_flag)
        DrawAction/W=$win/L=UserFront getgroup=XRDSelectedArrow,delete
    endif
    SetWindow $win userdata(XRDSelectedAngle)=""
    if(selected<0 || selected>=numpnts(xx))
        return 0
    endif
    SetDrawLayer/W=$win UserBack
    SetDrawEnv/W=$win gstart,gname=XRDSelectedPeak
    SetDrawEnv/W=$win push
    SetDrawEnv/W=$win xcoord=prel,ycoord=prel,clipRect=(0,0,1,1),save
    SetDrawEnv/W=$win xcoord=bottom,ycoord=prel,linefgc=(0,0,0),linethick=1.5,dash=3
    DrawLine/W=$win xx[selected],0,xx[selected],1
    SetDrawEnv/W=$win pop
    SetDrawEnv/W=$win gstop
    SetWindow $win userdata(XRDSelectedAngle)=num2str(xx[selected])
    XRD_RequestLive()
End
