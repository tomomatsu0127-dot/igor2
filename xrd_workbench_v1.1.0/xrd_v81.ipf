#pragma rtGlobals=3
// v1.1.0: in-place peak editing and explicit cursor modes.
Function XRD81_PeakControls(project,path)
    String project,path
    Variable step=NumVarOrDefault(project+":activeStep",1)
    if(!strlen(path) || (step!=1 && step!=3))
        return 0
    endif
    XRD_EnsureNumeric(path+":pickMode81",0)
    if(step==1)
        KillControl cursorPick
        Button pointMode,pos={16,306},size={175,23},title="グラフの点を選ぶ（追加用）",proc=XRD81_PeakButton
        Button pointAdd,pos={16,333},size={175,23},title="選んだ点をピークに追加",proc=XRD81_PeakButton
        Button detectorSettings,pos={16,360},size={175,23}
        Button externalPeaks,pos={16,387},size={175,23}
        KillControl rawNote
    else
        // Compact toolbar above the live comparison; registered peaks only by default.
        Button pointMode,pos={16,136},size={130,20},title="点を選ぶ（追加用）",proc=XRD81_PeakButton
        Button pointAdd,pos={150,136},size={146,20},title="選択点を追加",proc=XRD81_PeakButton
        Button deletePeak2,pos={16,160},size={130,20},title="選択ピークを削除",proc=XRD_Button
        Button peakMode,pos={150,160},size={146,20},title="ピーク選択へ戻る",proc=XRD81_PeakButton
        KillControl sideRange
    endif
    return 0
End

Function XRD81_AttachPicker(path)
    String path
    String win="XRDWorkbench#Pattern"
    Variable step=NumVarOrDefault(XRD_Project()+":activeStep",1)
    if(!strlen(path) || !WinType(win) || (step!=1 && step!=3))
        return 0
    endif
    Wave px=$(path+":Peaks:angle"),py=$(path+":Peaks:height")
    if(WhichListItem("XRDWB_Select",TraceNameList(win,";",1))<0)
        AppendToGraph/W=$win py/TN=XRDWB_Select vs px
        ModifyGraph/W=$win mode(XRDWB_Select)=3,marker(XRDWB_Select)=19,msize(XRDWB_Select)=1.5,rgb(XRDWB_Select)=(0,0,0)
    endif
    SetWindow $win userdata(XRDData)=path
    SetWindow XRDWorkbench hook(XRDPoint)=XRD100_PointHook
    XRD81_SyncPeakCursor(path)
    XRD81_UpdatePickerButtons(path)
    return 0
End

Function XRD81_SyncPeakCursor(path)
    String path
    // Native Ctrl+I cursors belong to the user; peak selection does not move them.
    return 0
End

Function XRD81_SelectPeak(path,row)
    String path
    Variable row
    return XRD100_Select(path,row,1)
End

Function XRD81_PointHook(s)
    STRUCT WMWinHookStruct &s
    String win=s.winName,path=GetUserData(win,"","XRDData"),hit,trace
    Variable row,point,adding
    if(!strlen(path) || cmpstr(path,XRD_Data())!=0 || cmpstr(GetUserData(win,"","XRDCursorBusy"),"1")==0)
        return 0
    endif
    adding=NumVarOrDefault(path+":pickMode81",0)
    Wave px=$(path+":Peaks:angle"),xx=$(path+":Raw:twoTheta")
    if(s.eventCode==5 && !(s.eventMod & 16))
        trace=SelectString(adding,"XRDWB_Select","XRDWB_Measured")
        hit=TraceFromPixel(s.mouseLoc.h,s.mouseLoc.v,"WINDOW:"+win+";ONLY:"+trace+";DELTAX:8;DELTAY:8;")
        if(!strlen(hit))
            return 0
        endif
        point=NumberByKey("HITPOINT",hit)
        if(adding)
            Cursor/P/H=2/S=1/N=1/DGTS=8/W=$win A XRDWB_Measured point
            Variable/G $(path+":manualAngle")=xx[point]
        else
            XRD81_SelectPeak(path,point)
        endif
    elseif(s.eventCode==7 && (cmpstr(s.cursorName,"A")==0 || cmpstr(s.cursorName,"B")==0))
        if(adding)
            if(cmpstr(s.cursorName,"A")==0 && cmpstr(s.traceName,"XRDWB_Measured")==0 && s.pointNumber>=0 && s.pointNumber<numpnts(xx))
                Variable/G $(path+":manualAngle")=xx[s.pointNumber]
            endif
        elseif(numpnts(px))
            Variable angle=hcsr($s.cursorName,win)
            row=XRD_NearestPoint(px,angle)
            if(cmpstr(s.cursorName,"B")==0)
                SetWindow $win userdata(XRDCursorBusy)="1"
                Cursor/P/H=2/N=1/W=$win B XRDWB_Select row
                SetWindow $win userdata(XRDCursorBusy)="0"
            else
                XRD81_SelectPeak(path,row)
            endif
        else
            Cursor/K/W=$win $s.cursorName
        endif
    endif
    return 0
End

Function XRD81_SetPickMode(adding)
    Variable adding
    String path=XRD_Data(),win="XRDWorkbench#Pattern"
    if(!strlen(path) || !WinType(win))
        return -1
    endif
    Variable/G $(path+":pickMode81")=adding
    if(adding)
        Wave xx=$(path+":Raw:twoTheta")
        GetAxis/W=$win/Q bottom
        Variable point=XRD_NearestPoint(xx,(V_min+V_max)/2)
        Cursor/P/H=2/S=1/N=1/DGTS=8/W=$win A XRDWB_Measured point
        Variable/G $(path+":manualAngle")=xx[point]
        SetActiveSubwindow $win
        ShowInfo
    else
        XRD81_SyncPeakCursor(path)
    endif
    XRD81_UpdatePickerButtons(path)
    return 0
End

Function XRD81_AddCursorPoint()
    String path=XRD_Data(),win="XRDWorkbench#Pattern"
    if(!strlen(path) || !WinType(win) )
        return -1
    endif
    if(cmpstr(StringByKey("TNAME",CsrInfo(A,win)),"XRDWB_Measured")!=0)
        return -1
    endif
    Variable point=pcsr(A,win)
    Wave xx=$(path+":Raw:twoTheta")
    if(numtype(point)!=0 || point<0 || point>=numpnts(xx))
        return -1
    endif
    XRD_AddPoint(path,point,"Manual")
    Wave indices=$(path+":Peaks:pointIndex")
    FindValue/V=(point) indices
    Variable/G $(path+":selectedPeakRow")=V_value
    Variable/G $(path+":pickMode81")=0
    XRD81_RefreshPeaks(path)
    XRD81_UpdatePickerButtons(path)
    return point
End

Function XRD81_UpdatePickerButtons(path)
    String path
    if(WinType("XRDWorkbench#Pattern"))
        Variable ready=cmpstr(StringByKey("TNAME",CsrInfo(A,"XRDWorkbench#Pattern")),"XRDWB_Measured")==0
        ControlInfo/W=XRDWorkbench pointAdd
        if(V_flag==1)
            Button pointAdd,win=XRDWorkbench,disable=SelectNumber(ready,2,0)
        endif
    endif
    return 0
End

Function XRD81_PeakButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    strswitch(ba.ctrlName)
        case "pointMode":
            XRD81_SetPickMode(1-NumVarOrDefault(XRD_Data()+":pickMode81",0))
            break
        case "peakMode":
            XRD81_SetPickMode(0)
            break
        case "pointAdd":
            if(XRD81_AddCursorPoint()<0)
                DoAlert 0,"先に『グラフの点を選ぶ』を押して、測定曲線の点を選んでください。"
            endif
            break
    endswitch
    return 0
End

Function XRD81_RefreshPeaks(path,[rescore])
    String path
    Variable rescore
    if(ParamIsDefault(rescore))
        rescore=1
    endif
    String win="XRDWorkbench#Pattern",project=XRD_Project(),traces,trace
    Variable i,step=NumVarOrDefault(project+":activeStep",1)
    if(!strlen(path) || !WinType(win) || cmpstr(GetUserData("XRDWorkbench","","XRDData"),path)!=0)
        return 0
    endif
    // Do not recreate the panel, resize it or change axes during data edits.
    PauseUpdate; Silent 1
    XRD_PeakTable(path)
    if(step==1)
        XRD_DetectionTable(path)
    else
        XRD_UpdateAssignedPlot(path)
        XRD_UnassignedPlot(path)
        traces=TraceNameList(win,";",1)
        for(i=0;i<ItemsInList(traces);i+=1)
            trace=StringFromList(i,traces)
            if(strlen(GetUserData(win,"","Ref_"+trace)))
                RemoveFromGraph/W=$win $trace
            endif
        endfor
        XRD_AddPhaseTraces(win,path,0)
        NVAR selected=$(path+":selectedPeakRow")
        if(rescore)
            XRD_ScoreCandidates(path,selected)
        endif
        ListBox candidateList,win=XRDWorkbench,selRow=NumVarOrDefault(path+":selectedCandidateRow",0),row=0
        ControlUpdate/W=XRDWorkbench candidateList
    endif
    Variable row=NumVarOrDefault(path+":selectedPeakRow",-1)
    ListBox peakList,win=XRDWorkbench,selRow=row,row=max(0,row-3)
    ControlUpdate/W=XRDWorkbench peakList
    XRD_SelectedPeakGuide(path)
    XRD_ReferenceArrow(path)
    XRD81_SyncPeakCursor(path)
    XRD_StatusBar(project,path)
    String name=StrVarOrDefault(path+":displayName","")+"  ["+StrVarOrDefault(path+":analysisState","")+"]"
    XRD110_DataChooser()
    XRD_UpdateHistoryUI()
    XRD_RequestLive()
    return 0
End

Function XRD81_CreateNamedWaves(path)
    String path
    String stem=StrVarOrDefault(path+":namedWaveStem81",""),owner=XRD_PlotOwner(path)
    if(!strlen(stem))
        // Igor's 31-byte limit requires a short readable stem and stable ID suffix.
        String label=StrVarOrDefault(path+":displayName","sample"),project=XRD_ProjectDisplayName(owner)
        String a=CleanupName(label,1),b=CleanupName(project,1)
        String uid=StrVarOrDefault(path+":measurementUID","")
        // Reserve the complete unique suffix instead of truncating it away.
        stem=XRD81_NamePrefix(a,7)+"_"+XRD81_NamePrefix(b,8)+"_"+uid[max(0,strlen(uid)-10),inf]
        String/G $(path+":namedWaveStem81")=stem
    endif
    String keys="tt;int",source
    Variable i
    for(i=0;i<2;i+=1)
        source=SelectString(i,path+":Raw:twoTheta",path+":Processed:intensity")
        Wave original=$source
        String alias=path+":Waves:"+PossiblyQuoteName(StringFromList(i,keys)+"_"+stem)
        Wave/Z exists=$alias
        if(!WaveExists(exists))
            Make/D/N=(numpnts(original)) $alias
            Wave made=$alias
            made=original[p]
            SetFormula made,GetWavesDataFolder(original,2)+"[p]"
        endif
    endfor
    return 0
End

Function/S XRD81_NamePrefix(text,limitBytes)
    String text
    Variable limitBytes
    Variable i=0,width,b
    do
        if(i>=strlen(text))
            break
        endif
        b=char2num(text[i])
        if(b<0)
            b+=256
        endif
        width=1+(b>=192)+(b>=224)+(b>=240)
        if(i+width>limitBytes)
            break
        endif
        i+=width
    while(1)
    if(i==0)
        return "s"
    endif
    return text[0,i-1]
End

Function XRD_NearestPoint(xx,x)
    Wave xx
    Variable x
    Variable i,best=-1,distance=inf
    for(i=0;i<numpnts(xx);i+=1)
        if(abs(xx[i]-x)<distance)
            best=i;distance=abs(xx[i]-x)
        endif
    endfor
    return best
End

Function XRD81_MarkerSize(row)
    Variable row
    String base=XRD80_Styles()
    Wave values=$(base+":values")
    Wave/Z sizes=$(base+":sizes81")
    Variable old=0
    if(!WaveExists(sizes))
        Make/D/N=(DimSize(values,0)) $(base+":sizes81")=3
        Wave sizes=$(base+":sizes81")
    elseif(numpnts(sizes)<DimSize(values,0))
        old=numpnts(sizes)
        Redimension/N=(DimSize(values,0)) sizes
        sizes[old,inf]=3
    endif
    if(row<0 || row>=numpnts(sizes))
        return 3
    endif
    return max(1,min(20,sizes[row]))
End

Function XRD81_SetMarkerSize(row,size)
    Variable row,size
    XRD81_MarkerSize(row)
    Wave sizes=$(XRD80_Styles()+":sizes81")
    if(row>=0 && row<numpnts(sizes) && numtype(size)==0)
        sizes[row]=max(1,min(20,size))
    endif
    return 0
End

Function/S XRD81_StyleTargets()
    XRD_UISettings()
    XRD_EnsureNumeric("root:Packages:XRDWorkbench:UI:styleUsedOnly81",1)
    Variable used=NumVarOrDefault("root:Packages:XRDWorkbench:UI:styleUsedOnly81",1),i,j,index
    String paths=XRD_AllMeasurementPaths(0),seen="",out="",key
    if(used)
        for(i=0;i<ItemsInList(paths);i+=1)
            Wave refs=$(StringFromList(i,paths)+":Assignments:refIndex")
            for(j=0;j<numpnts(refs);j+=1)
                index=refs[j]
                if(index>0)
                    key=StrVarOrDefault(XRD_ReferencePath(index)+":styleGroup",XRD_PhaseLabel(index))
                    if(WhichListItem(key,seen)<0)
                        seen+=key+";";out+=num2istr(index)+";"
                    endif
                endif
            endfor
        endfor
    else
        for(i=1;i<=NumVarOrDefault(XRD80_Library()+":referenceCount",0);i+=1)
            key=StrVarOrDefault(XRD_ReferencePath(i)+":styleGroup",XRD_PhaseLabel(i))
            if(WhichListItem(key,seen)<0)
                seen+=key+";";out+=num2istr(i)+";"
            endif
        endfor
    endif
    // Before the first assignment show references so the filter can be switched.
    if(!strlen(out) && used)
        Variable/G root:Packages:XRDWorkbench:UI:styleUsedOnly81=0
        return XRD81_StyleTargets()
    endif
    return out
End

Function XRD81_StyleFilter(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba
    if(cba.eventCode==2)
        Execute/P/Q "XRD_StylePanel()"
    endif
    return 0
End

Function XRD81_StyleSize(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva
    if(sva.eventCode>=1 && sva.eventCode<=3)
        Variable index=str2num(GetUserData("XRDStyles","","XRDRef"))
        XRD81_SetMarkerSize(XRD_StyleIndex(index),sva.dval)
        XRD_RefreshStyles()
        XRD_RequestLive()
    endif
    return 0
End

Function XRD81_StylePopup(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        STRUCT WMButtonAction ba
        ba.eventCode=2
        XRD_ApplyStyleButton(ba)
    endif
    return 0
End

Menu "作図"
    "作図ウィンドウを開く...", XRD_PlotWorkspace()
    "相のマーカー・色・サイズ...", XRD_StylePanel()
    "凡例の順番...", XRD_LegendOrderPanel()
    "完成図のサイズ・凡例...", XRD_FigurePanel()
End

Menu "GraphPopup"
    "画像として保存（PNG）...", /Q, XRD81_ExportContext()
End
Menu "TracePopup"
    "画像として保存（PNG）...", /Q, XRD81_ExportContext()
End

Function XRD81_ExportContext()
    GetLastUserMenuInfo
    String win=S_graphName
    if(!strlen(win))
        win=WinName(0,1)
    endif
    return XRD81_ExportGraph(win,"")
End

Function XRD81_ExportGraph(win,file)
    String win,file
    if(WinType(win)!=1)
        return -1
    endif
    SavePICT/E=-5/RES=300/WIN=$win as file
    return 0
End
