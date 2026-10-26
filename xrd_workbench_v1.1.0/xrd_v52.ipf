#pragma rtGlobals=3
// XRD Workbench v1.1.0: unique reflections, deferred adoption and native resize.

Function XRD_ReferencePeakOwner(path,refIndex,refPeakIndex,exceptID)
    String path
    Variable refIndex,refPeakIndex,exceptID
    Wave ids=$(path+":Peaks:peakID"),aid=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex"),rows=$(path+":Assignments:refPeakIndex")
    Variable i,j
    for(i=0;i<numpnts(aid);i+=1)
        if(aid[i]!=exceptID && refs[i]==refIndex && rows[i]==refPeakIndex)
            for(j=0;j<numpnts(ids);j+=1)
                if(ids[j]==aid[i])
                    return j
                endif
            endfor
        endif
    endfor
    return -1
End

Function/S XRD_CandidateIdentity(refIndex,row)
    Variable refIndex,row
    String rp=XRD_ReferencePath(refIndex)
    Wave/Z xx=$(rp+":twoTheta"),hh=$(rp+":h"),kk=$(rp+":k"),ll=$(rp+":l")
    if(!WaveExists(xx) || row<0 || row>=numpnts(xx))
        return ""
    endif
    if(!XRD82_HKLKnown(hh[row],kk[row],ll[row]))
        // A friendly label cannot distinguish two unindexed reflections at the same angle.
        return StrVarOrDefault(rp+":cardNumber","")+":"+num2str(numpnts(xx))+":"+XRD_ExactNumber(xx[row])+":unindexed-row-"+num2istr(row)
    endif
    return StrVarOrDefault(rp+":cardNumber","")+":"+num2str(numpnts(xx))+":"+XRD_ExactNumber(xx[row])+":"+XRD_HKL(hh[row],kk[row],ll[row])
End

Function/S XRD_ExactNumber(value)
    Variable value
    String result
    sprintf result,"%.17g",value
    return result
End

Function XRD_QueueCandidateAdoption(path,row)
    String path
    Variable row
    String win="XRDWorkbench",project=XRD_Project()
    if(!WinType(win) || NumVarOrDefault(project+":activeStep",0)!=3 || cmpstr(GetUserData(win,"","XRDAdoptPending"),"1")==0)
        return 0
    endif
    Wave ids=$(path+":Peaks:peakID"),refs=$(path+":Candidates:refIndex"),rows=$(path+":Candidates:refPeakIndex"),shifts=$(path+":Candidates:shift")
    Variable selected=NumVarOrDefault(path+":selectedPeakRow",-1)
    if(selected<0 || selected>=numpnts(ids) || row<0 || row>=numpnts(refs))
        return -1
    endif
    SetWindow $win userdata(XRDAdoptPending)="1"
    SetWindow $win userdata(XRDAdoptData)=path
    SetWindow $win userdata(XRDAdoptPeak)=num2istr(ids[selected])
    SetWindow $win userdata(XRDAdoptRef)=num2istr(refs[row])
    SetWindow $win userdata(XRDAdoptRow)=num2istr(rows[row])
    SetWindow $win userdata(XRDAdoptShift)=XRD_ExactNumber(shifts[row])
    SetWindow $win userdata(XRDAdoptIdentity)=XRD_CandidateIdentity(refs[row],rows[row])
    SetWindow $win userdata(XRDAdoptRevision)=num2str(NumVarOrDefault(project+":analysisRevision",0))
    Execute/P/Q "XRD_AdoptDeferred()"
    return 1
End

Function XRD_AdoptDeferred()
    String win="XRDWorkbench",path=XRD_Data(),project=XRD_Project()
    if(!WinType(win) || cmpstr(GetUserData(win,"","XRDAdoptPending"),"1")!=0)
        return 0
    endif
    SetWindow $win userdata(XRDAdoptPending)="0"
    if(cmpstr(path,GetUserData(win,"","XRDAdoptData"))!=0 || NumVarOrDefault(project+":activeStep",0)!=3 || str2num(GetUserData(win,"","XRDAdoptRevision"))!=NumVarOrDefault(project+":analysisRevision",0))
        return 0
    endif
    Wave ids=$(path+":Peaks:peakID"),refs=$(path+":Candidates:refIndex"),rows=$(path+":Candidates:refPeakIndex"),shifts=$(path+":Candidates:shift")
    Variable selected=NumVarOrDefault(path+":selectedPeakRow",-1),i,refIndex=str2num(GetUserData(win,"","XRDAdoptRef")),refRow=str2num(GetUserData(win,"","XRDAdoptRow"))
    if(selected<0 || selected>=numpnts(ids) || ids[selected]!=str2num(GetUserData(win,"","XRDAdoptPeak")))
        return 0
    endif
    if(cmpstr(XRD_CandidateIdentity(refIndex,refRow),GetUserData(win,"","XRDAdoptIdentity"))!=0)
        return 0
    endif
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==refIndex && rows[i]==refRow && abs(shifts[i]-str2num(GetUserData(win,"","XRDAdoptShift")))<1e-10)
            NVAR candidate=$(path+":selectedCandidateRow")
            candidate=i
            return XRD_ApplySelectedCandidate(path,0)
        endif
    endfor
    return 0
End

Function/S XRD_FigureLegendSignature(win)
    String win
    if(WhichListItem("Phases",AnnotationList(win))<0)
        return ""
    endif
    String info=AnnotationInfo(win,"Phases",1)
    return StringByKey("FLAGS",info)+info[strsearch(info,"TEXT:",0)+5,inf]
End

Function XRD_IsManagedLegend(win)
    String win
    String saved=GetUserData(win,"","XRDManagedLegend"),current=XRD_FigureLegendSignature(win)
    if(cmpstr(saved,current)==0)
        return 1
    endif
    // v0.5.2-v0.6.0 signatures accidentally included transient screen geometry.
    // Migrate only when both the saved native flags and exact text still match.
    Variable at=strsearch(saved,"TEXT:",0)
    if(at<0 || !strlen(StringByKey("FLAGS",saved)))
        return 0
    endif
    if(cmpstr(StringByKey("FLAGS",saved)+saved[at+5,inf],current)==0)
        SetWindow $win userdata(XRDManagedLegend)=current
        return 1
    endif
    return 0
End

Function XRD_EnableFigureResize(win)
    String win
    if(WinType(win)!=1)
        return -1
    endif
    SetWindow $win userdata(XRDFlexible)="1"
    SetWindow $win userdata(XRDFigurePending)="0"
    ModifyGraph/W=$win width=0,height=0
    SetWindow $win hook(XRDFigure)=XRD_FigureHook
    XRD_FigureResized(win)
    return 0
End

Function XRD_FigureHook(s)
    STRUCT WMWinHookStruct &s
    if(s.eventCode==0)
        // A saved Experiment may contain a pending flag without its queue.
        SetWindow $(s.winName) userdata(XRDFigurePending)="0"
    endif
    if(s.eventCode==6 && cmpstr(GetUserData(s.winName,"","XRDFlexible"),"1")==0 && cmpstr(GetUserData(s.winName,"","XRDFigurePending"),"1")!=0)
        SetWindow $(s.winName) userdata(XRDFigurePending)="1"
        Execute/P/Q "XRD_FigureResized(\""+s.winName+"\")"
    endif
    return 0
End

Function XRD_FigureResized(win)
    String win
    if(WinType(win)!=1 || cmpstr(GetUserData(win,"","XRDFlexible"),"1")!=0)
        return 0
    endif
    // Hold the guard through layout; never redraw or recreate a window here.
    SetWindow $win userdata(XRDFigurePending)="1"
    GetWindow $win psize
    Variable width=V_right-V_left,height=V_bottom-V_top
    if(abs(width-str2num(GetUserData(win,"","XRDFigureWidth")))>0.5)
        if(XRD_IsManagedLegend(win))
            XRD_PhaseLegend(win)
        endif
    endif
    SetWindow $win userdata(XRDFigureWidth)=num2str(width)
    SetWindow $win userdata(XRDFigureHeight)=num2str(height)
    XRD_FigureSizeLimits(win)
    SetWindow $win userdata(XRDFigurePending)="0"
    return 0
End

Function XRD_FigureSizeLimits(win)
    String win
    String traces=TraceNameList(win,";",1),trace,key,rp,project=GetUserData(win,"","XRDProject")
    Variable i,index,minPlot=200,font=str2num(GetUserData(win,"","XRDFigureLegendFont"))
    if(numtype(font)!=0 || font<8)
        font=24
    endif
    for(i=0;i<ItemsInList(traces);i+=1)
        trace=StringFromList(i,traces)
        index=str2num(GetUserData(win,"","Ref_"+trace))
        if(numtype(index)==0 && index>0)
            rp=XRD_ReferencePath(index)
            key=StrVarOrDefault(rp+":styleGroup","")
            minPlot=max(minPlot,XRD_LegendEntryWidth(key,font)+12)
        endif
    endfor
    GetWindow $win expand
    Variable scale=V_value
    if(numtype(scale)!=0 || scale<=0)
        scale=1
    endif
    Variable rows=str2num(GetUserData(win,"","XRDLegendRows"))
    if(numtype(rows)!=0)
        rows=0
    endif
    // Automatic width/height retain fixed point fonts and margins. Prevent
    // shrinking the canvas until labels or the tallest legend fill the plot.
    SetWindow $win sizeLimit={(minPlot+106)*scale,(150+78+max(24,rows*font*1.5+18))*scale,inf,inf}
End

