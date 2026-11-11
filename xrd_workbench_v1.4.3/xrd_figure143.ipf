#pragma rtGlobals=3

Function/S XRD143_FigureDefaults()
    String base=XRD_PlotRoot()+":FigureDefaults143"
    NewDataFolder/O $base
    XRD_EnsureNumeric(base+":widthCM",16)
    XRD_EnsureNumeric(base+":heightCM",12)
    XRD_EnsureNumeric(base+":yMin",-30)
    XRD_EnsureNumeric(base+":yMax",140)
    XRD_EnsureNumeric(base+":opacity",40)
    return base
End

Function XRD143_Default(key)
    String key
    strswitch(key)
        case "width":
            return 72*NumVarOrDefault(XRD143_FigureDefaults()+":widthCM",16)/2.54
        case "height":
            return 72*NumVarOrDefault(XRD143_FigureDefaults()+":heightCM",12)/2.54
        case "yMin":
            return NumVarOrDefault(XRD143_FigureDefaults()+":yMin",-30)
        case "yMax143":
            return NumVarOrDefault(XRD143_FigureDefaults()+":yMax",140)
        case "opacity":
            return NumVarOrDefault(XRD143_FigureDefaults()+":opacity",40)
    endswitch
    return 0
End

Function XRD143_SetDefaults(widthCM,heightCM,lower,upper,opacity)
    Variable widthCM,heightCM,lower,upper,opacity
    if(numtype(widthCM+heightCM+lower+upper+opacity) || widthCM<200*2.54/72 || widthCM>1600*2.54/72 || heightCM<150*2.54/72 || heightCM>3000*2.54/72 || lower>=upper || opacity<10 || opacity>100)
        return -1
    endif
    String base=XRD143_FigureDefaults(),projects=XRD_ProjectList(),project,win="XRDWorkbench#Pattern"
    Variable i
    Variable/G $(base+":widthCM")=widthCM
    Variable/G $(base+":heightCM")=heightCM
    Variable/G $(base+":yMin")=lower
    Variable/G $(base+":yMax")=upper
    Variable/G $(base+":opacity")=opacity
    for(i=0;i<ItemsInList(projects);i+=1)
        project=StringFromList(i,projects)
        Variable/G $(project+":previewOpacity")=opacity
    endfor
    if(WinType(win) && WhichListItem("XRDWB_Preview",TraceNameList(win,";",1))>=0)
        ModifyGraph/W=$win rgb(XRDWB_Preview)=(60000,0,0,65535*opacity/100)
    endif
    XRD_RequestLive()
    return 0
End

Function XRD143_DefaultsUI()
    String base=XRD143_FigureDefaults()
    Variable widthCM=NumVarOrDefault(base+":widthCM",16),heightCM=NumVarOrDefault(base+":heightCM",12)
    Variable lower=XRD143_Default("yMin"),upper=XRD143_Default("yMax143"),opacity=XRD143_Default("opacity")
    Prompt widthCM,"新しい図の幅 (cm)"
    Prompt heightCM,"新しい図の高さ (cm)"
    Prompt lower,"強度の下限"
    Prompt upper,"強度の上限（縦並びは最上段の基準）"
    Prompt opacity,"重ね描き・参照線の濃さ (%)"
    DoPrompt "Experiment全体のグラフ初期値",widthCM,heightCM,lower,upper,opacity
    if(V_flag)
        return 0
    endif
    if(XRD143_SetDefaults(widthCM,heightCM,lower,upper,opacity)<0)
        XRD124_Alert(0,"幅は約7.1～56.4 cm、高さは約5.3～105.8 cm、濃さは10～100%で、下限は上限未満にしてください。")
    endif
    return 0
End

Function XRD143_LoadNewFigureDefaults()
    String ui=XRD_PlotRoot()+":UI",keys="width;height;yMin;yMax143",key
    Variable i
    for(i=0;i<ItemsInList(keys);i+=1)
        key=StringFromList(i,keys)
        Variable/G $(ui+":"+key)=XRD143_Default(key)
    endfor
    Variable/G $(ui+":opacity143")=XRD143_Default("opacity")
End

Function XRD143_PlotUpper(base,count,spacing)
    String base
    Variable count,spacing
    return NumVarOrDefault(base+":yMax143",140)+max(0,count-1)*spacing
End

Function/S XRD143_CompareLabel(path,[formatted])
    String path
    Variable formatted
    String number=StrVarOrDefault(path+":sampleNumber",""),label=TrimString(StrVarOrDefault(path+":composition",""))
    if(!strlen(label))
        label=TrimString(StrVarOrDefault(path+":conditionLabel",""))
    endif
    if(!strlen(label))
        String display=TrimString(StrVarOrDefault(path+":displayName",""))
        if(GrepString(display,"^[xX][ ]*="))
            label=display
        endif
    endif
    if(!strlen(number))
        number="番号未登録"
    endif
    if(ParamIsDefault(formatted) || formatted)
        label=XRD132_CompositionLabel(label)
    endif
    return number+SelectString(strlen(label)>0,""," / "+label)
End

Function XRD143_LabelY(rank,count,spacing,lower,upper,offset)
    Variable rank,count,spacing,lower,upper,offset
    if(!spacing)
        return 3+min(8,90/max(1,count))*rank
    endif
    return max(1,min(96,100*(upper-offset-90)/(upper-lower)))
End

Function XRD143_DefaultRange(win,offset)
    String win
    Variable offset
    SetAxis/W=$win left XRD143_Default("yMin"),XRD143_Default("yMax143")+offset
End

Function XRD143_SetRange(win,lower,upper)
    String win
    Variable lower,upper
    if(WinType(win)!=1 || numtype(lower+upper) || lower>=upper)
        return -1
    endif
    SetAxis/W=$win left lower,upper
    ModifyGraph/W=$win tick(bottom)=0,btLen(bottom)=6,stLen(bottom)=3
    if(cmpstr(win,"XRDWorkbench#Pattern")==0)
        String path=GetUserData("XRDWorkbench","","XRDData")
        XRD_RecordPendingZoom(path)
        XRD_CaptureView()
        XRD_ViewSync(path)
    endif
    String recipe=GetUserData(win,"","XRDPlotRecipe")
    Wave/T/Z uids=$(recipe+":sourceUIDs")
    if(WaveExists(uids) && strsearch(recipe,XRD_PlotRoot()+":Plots:",0)==0)
        Variable spacing=NumVarOrDefault(recipe+":spacing",135)*NumVarOrDefault(recipe+":offsetMode",1)
        Variable/G $(recipe+":yMin")=lower
        Variable/G $(recipe+":yMax143")=upper-max(0,numpnts(uids)-1)*spacing
        String ui=XRD_PlotRoot()+":UI"
        if(cmpstr(StrVarOrDefault(ui+":recipe",""),recipe)==0)
            Variable/G $(ui+":yMin")=lower
            Variable/G $(ui+":yMax143")=NumVarOrDefault(recipe+":yMax143",140)
        endif
        XRD_PlotCaptureNative(recipe)
    elseif(cmpstr(GetUserData(win,"","XRDReview"),"1")==0)
        XRD_RequestLive()
    endif
    return 0
End

Function XRD143_RangeUI(win)
    String win
    if(WinType(win)!=1 || WhichListItem("left",AxisList(win))<0)
        return -1
    endif
    GetAxis/W=$win/Q left
    Variable lower=V_min,upper=V_max
    Prompt lower,"強度 下限"
    Prompt upper,"強度 上限"
    DoPrompt "グラフの強度軸",lower,upper
    if(!V_flag && XRD143_SetRange(win,lower,upper)<0)
        XRD124_Alert(0,"下限は上限より小さくしてください。")
    endif
    return 0
End

Function XRD143_GraphContext(action)
    Variable action
    GetLastUserMenuInfo
    String win=S_graphName
    if(!strlen(win))
        win=WinName(0,1)
    endif
    if(action==0)
        return XRD143_RangeUI(win)
    endif
    return XRD143_SyncUI(GetUserData(win,"","XRDPlotRecipe"),action)
End

Function/S XRD143_TraceOwner(win)
    String win
    String traces=TraceNameList(win,";",1),projects=XRD_ProjectList(),folder,project
    Variable i,j
    for(i=0;i<ItemsInList(traces);i+=1)
        Wave/Z data=TraceNameToWaveRef(win,StringFromList(i,traces))
        if(!WaveExists(data))
            continue
        endif
        folder=GetWavesDataFolder(data,1)
        for(j=0;j<ItemsInList(projects);j+=1)
            project=XRD100_ProjectAt(projects,j)
            if(strsearch(folder,project+":",0)==0)
                return project
            endif
        endfor
    endfor
    return ""
End
