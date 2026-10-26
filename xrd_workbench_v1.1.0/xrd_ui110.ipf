#pragma rtGlobals=3
// v1.1.0: focused four-step UI; native cursors and marquee are left to Igor.
Function XRD110_Controls(project,path)
    String project,path
    String remove="switchData;completeData;reference;saveHelp;helpGuide;undoAction;redoAction;uiText;zoomPlus;zoomMinus;viewBack;autoZoom100;zoomPeak;resetZoom;pointMode;peakMode;profileFit;externalPeaks;cursorPick;followPeak;typeCards;typeFamilies;referenceStyle;step5;pickHint;sideRange",name
    Variable i,step=NumVarOrDefault(project+":activeStep",1)
    for(i=0;i<ItemsInList(remove);i+=1)
        name=StringFromList(i,remove)
        KillControl/W=XRDWorkbench $name
    endfor
    Button importData,win=XRDWorkbench,size={100,20}
    Button projects110,win=XRDWorkbench,pos={116,6},size={100,20},title="プロジェクト一覧",proc=XRD110_Button
    XRD110_DataChooser()
    if(step<=3)
        Button viewAll,win=XRDWorkbench,pos={210,55},size={110,21},title="全体表示",proc=XRD110_Button
    endif
    if(step==1)
        Button pointAdd,win=XRDWorkbench,pos={16,242},size={175,25},title="カーソルAの位置を追加",proc=XRD110_Button
        TitleBox cursorHelp110,win=XRDWorkbench,pos={16,280},size={175,42},frame=0,title="Ctrl+IでIgor標準カーソルを表示。\r曲線上にAを置いて追加します。"
        Button detectorSettings,win=XRDWorkbench,pos={16,340},size={175,26}
    elseif(step==2)
        TitleBox stepHelp,win=XRDWorkbench,title="参照カードを選んで棒線を比較。\r使用カードの設定は上部の参照値へ。"
        Button loadReferences,win=XRDWorkbench,disable=1
        Button referenceInfo,win=XRDWorkbench,disable=1
        Button elementTable,win=XRDWorkbench,pos={16,175}
    elseif(step==3)
        TitleBox sideHint,win=XRDWorkbench,title="候補をダブルクリックして採用"
        Button compare110,win=XRDWorkbench,pos={16,82},size={170,22},title="比較する試料を追加…",proc=XRD110_Button
        Button unknownPeak,win=XRDWorkbench,pos={192,82},size={105,22},title="不明にする"
        Button pointAdd,win=XRDWorkbench,pos={150,137},size={146,20},title="カーソルAの位置を追加",proc=XRD110_Button
        TitleBox cursorHelp110,win=XRDWorkbench,pos={16,139},size={130,20},frame=0,title="Ctrl+I → Aを曲線上へ"
        Button deletePeak2,win=XRDWorkbench,pos={16,161},size={140,20},title="選択ピークを削除",proc=XRD_Button
    endif
    if(WinType("XRDWorkbench#Pattern"))
        GraphNormal/W=XRDWorkbench#Pattern
    endif
    SetWindow XRDWorkbench hook(wheel)=XRD_PanelHook
    XRD81_UpdatePickerButtons(path)
    return 0
End

Function XRD110_Layout(scale)
    Variable scale
    GetWindow XRDWorkbench wsizeForControls
    Variable w=V_right,h=V_bottom,step=NumVarOrDefault(XRD_Project()+":activeStep",1),left=210*scale
    Button importData,win=XRDWorkbench,pos={8*scale,6*scale},size={100*scale,20*scale}
    Button projects110,win=XRDWorkbench,pos={116*scale,6*scale},size={100*scale,20*scale}
    Button measurementLabel,win=XRDWorkbench,pos={230*scale,6*scale},size={w-242*scale,20*scale},fSize=round(10*scale)
    if(step==3)
        left=min(320*scale,w*0.35)+12*scale
        Variable side=left-12*scale,inner=side-20*scale
        Button compare110,win=XRDWorkbench,pos={12*scale,82*scale},size={inner*0.62,22*scale}
        Button unknownPeak,win=XRDWorkbench,pos={12*scale+inner*0.65,82*scale},size={inner*0.35,22*scale}
        TitleBox cursorHelp110,win=XRDWorkbench,pos={12*scale,139*scale},size={inner*0.46,20*scale}
    endif
    if(step<=3)
        Button viewAll,win=XRDWorkbench,pos={left,55*scale},size={110*scale,21*scale},fSize=round(10*scale)
    endif
    TitleBox recoveryState,win=XRDWorkbench,pos={left,h-35*scale},size={w-left-12*scale,16*scale},title=StrVarOrDefault("root:Packages:XRDWorkbench:Recovery:message","自動保存：設定はExperiment設定メニューへ")
    return 0
End

Function/S XRD110_DataChoices()
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project),path,out=""
    Variable i
    for(i=0;i<ItemsInList(list);i+=1)
        path=project+":Measurements:"+StringFromList(i,list)
        out+=ReplaceString(";",XRD110_SampleLabel(path)+" ["+StrVarOrDefault(path+":analysisState","")+"]",",")+";"
    endfor
    return SelectString(strlen(out)>0,"測定データ未選択;",out)
End

Function XRD110_DataChooser()
    if(!WinType("XRDWorkbench"))
        return 0
    endif
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project),path=XRD_Data()
    Variable i,selected=1
    for(i=0;i<ItemsInList(list);i+=1)
        if(cmpstr(path,project+":Measurements:"+StringFromList(i,list))==0)
            selected=i+1
        endif
    endfor
    ControlInfo/W=XRDWorkbench measurementLabel
    if(V_flag!=1)
        KillControl/W=XRDWorkbench measurementLabel
        Button measurementLabel,win=XRDWorkbench,pos={230,6},size={610,20},fSize=10,proc=XRD110_ChooseMeasurement
    endif
    Variable scale=str2num(GetUserData("XRDWorkbench","","XRDUIScale"))
    if(numtype(scale)!=0 || scale<1)
        scale=1
    endif
    GetWindow XRDWorkbench wsizeForControls
    String fullTitle="測定："+XRD110_SampleLabel(path)+" ["+StrVarOrDefault(path+":analysisState","")+"]  ▼"
    Button measurementLabel,win=XRDWorkbench,pos={230*scale,6*scale},size={V_right-242*scale,20*scale},fSize=round(10*scale),title=fullTitle,help={fullTitle}
    return 0
End

Function XRD110_ChooseMeasurement(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    PopupContextualMenu XRD110_DataChoices()
    if(V_flag<1)
        return 0
    endif
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project)
    if(V_flag>ItemsInList(list))
        return 0
    endif
    XRD_CaptureView()
    String/G $(project+":activeData")=project+":Measurements:"+StringFromList(V_flag-1,list)
    Execute/P/Q "XRD_Panel()"
    return 0
End

Function XRD110_DataChoice(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2)
        return 0
    endif
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project)
    if(pa.popNum<1 || pa.popNum>ItemsInList(list))
        return 0
    endif
    XRD_CaptureView()
    String/G $(project+":activeData")=project+":Measurements:"+StringFromList(pa.popNum-1,list)
    Execute/P/Q "XRD_Panel()"
    return 0
End

Function XRD110_Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    strswitch(ba.ctrlName)
        case "projects110":
            Execute/P/Q "XRD80_ProjectManager()"
            break
        case "compare110":
            Execute/P/Q "XRD110_ComparePanel()"
            break
        case "viewAll":
            XRD_ResetView()
            break
        case "pointAdd":
            Execute/P/Q "XRD110_AddNativeCursor()"
            break
    endswitch
    return 0
End

Function XRD110_AddNativeCursor()
    String win="XRDWorkbench#Pattern",path=XRD_Data()
    if(!strlen(path) || cmpstr(StringByKey("TNAME",CsrInfo(A,win)),"XRDWB_Measured")!=0)
        DoAlert 0,"Ctrl+Iでカーソルを表示し、Aを測定曲線上へ置いてください。"
        return -1
    endif
    DoAlert 1,"2θ = "+num2str(hcsr(A,win))+"° の測定点を追加しますか？"
    if(V_flag!=1)
        return -1
    endif
    return XRD81_AddCursorPoint()
End

Function XRD110_PointHook(s)
    STRUCT WMWinHookStruct &s
    String path=XRD_Data(),win="XRDWorkbench#Pattern",hit
    Variable step=NumVarOrDefault(XRD_Project()+":activeStep",1)
    if(XRD100_Busy() || !strlen(path) || !WinType(win))
        return 0
    endif
    if(s.eventCode==7)
        // Native cursor movement is for reading/adding only; it never relocates a peak.
        if(cmpstr(s.cursorName,"A")==0 && cmpstr(s.traceName,"XRDWB_Measured")==0)
            Variable/G $(path+":manualAngle")=hcsr(A,win)
        endif
        XRD81_UpdatePickerButtons(path)
        return 0
    endif
    if(step!=3 || (s.eventMod & 16) || (s.eventCode!=3 && s.eventCode!=5))
        return 0
    endif
    hit=TraceFromPixel(s.mouseLoc.h,s.mouseLoc.v,"WINDOW:"+win+";ONLY:XRDWB_Select;DELTAX:8;DELTAY:8;")
    if(!strlen(hit))
        return 0
    endif
    if(s.eventCode==5)
        XRD100_Select(path,NumberByKey("HITPOINT",hit),1)
    endif
    // Consume the marker click/drag; leave marquee and native cursor gestures elsewhere.
    return 1
End

Function XRD110_WheelHook(s)
    STRUCT WMWinHookStruct &s
    if(s.eventCode!=22)
        return 0
    endif
    String win=StringFromList(0,s.winName,"#"),list=ControlNameList(win,";"),control
    Variable i,first,left,top,right,bottom,delta
    for(i=0;i<ItemsInList(list);i+=1)
        control=StringFromList(i,list)
        ControlInfo/W=$win $control
        if(V_flag!=11)
            continue
        endif
        first=V_startRow;left=V_left;top=V_top;right=left+V_width;bottom=top+V_height
        if(s.mouseLoc.h>=left && s.mouseLoc.h<right && s.mouseLoc.v>=top && s.mouseLoc.v<bottom)
            delta=SelectNumber(s.wheelDy>=0,ceil(s.wheelDy),floor(s.wheelDy))
            if(delta==0 && s.wheelDy!=0)
                delta=SelectNumber(s.wheelDy>0,-1,1)
            endif
            ListBox $control,win=$win,row=max(0,first-3*delta)
            return 1
        endif
    endfor
    return 0
End

Function XRD110_ElementAttach()
    ModifyPanel/W=XRDElements fixedSize=0
    SetWindow XRDElements hook(resize110)=XRD110_ElementHook
    SetWindow XRDElements sizeLimit={620,390,inf,inf}
    XRD110_ElementLayout()
End

Function XRD110_ElementHook(s)
    STRUCT WMWinHookStruct &s
    if(s.eventCode==6)
        XRD110_ElementLayout()
    endif
    return 0
End

Function XRD110_ElementLayout()
    if(!WinType("XRDElements"))
        return 0
    endif
    GetWindow XRDElements wsizeForControls
    Variable width=V_right,height=V_bottom,s=min(width/860,height/495),i,row,col,font=max(10,round(12*s))
    String symbols=XRD_PeriodicSymbols(),positions=XRD_PeriodicPositions(),symbol,entry,control
    for(i=0;i<ItemsInList(symbols);i+=1)
        symbol=StringFromList(i,symbols);entry=StringFromList(i,positions)
        row=str2num(StringFromList(0,entry,","));col=str2num(StringFromList(1,entry,","));control="el"+symbol
        Button $control,win=XRDElements,pos={(12+(col-1)*46)*s,(65+(row-1)*35)*s},size={43*s,30*s},fSize=font
    endfor
    TitleBox help,win=XRDElements,pos={12*s,10*s},fSize=font
    CheckBox enabled,win=XRDElements,pos={12*s,35*s},fSize=font
    TitleBox pending,win=XRDElements,pos={260*s,35*s},fSize=font
    TitleBox exception,win=XRDElements,pos={12*s,390*s},fSize=font
    Button clear,win=XRDElements,pos={12*s,430*s},size={180*s,30*s},fSize=font
    Button apply,win=XRDElements,pos={210*s,430*s},size={220*s,30*s},fSize=font
    return 0
End

Function XRD110_PlotControls()
    String ui=XRD_PlotRoot()+":UI"
    XRD_EnsureNumeric(ui+":legendColumns",2)
    XRD_EnsureNumeric(ui+":legendSeparate",0)
    KillControl/W=XRDPlotWorkspace sources
    KillControl/W=XRDPlotWorkspace samples
    Button markerSettings,win=XRDPlotWorkspace,pos={15,74},size={440,23}
    Button legendSettings,win=XRDPlotWorkspace,pos={475,74},size={475,23}
    SetVariable legendColumns,win=XRDPlotWorkspace,pos={15,710},size={210,24},title="凡例の列数",limits={1,4,1},value=$(ui+":legendColumns"),proc=XRD81_PlotSetting
    CheckBox legendSeparate,win=XRDPlotWorkspace,pos={245,710},title="凡例を別ウィンドウで出力",variable=$(ui+":legendSeparate"),proc=XRD81_PlotOffset
    Button exportLegend,win=XRDPlotWorkspace,pos={655,705},size={295,30},title="凡例だけをPNGで保存…",proc=XRD110_LegendButton
    MoveWindow/W=XRDPlotWorkspace 35,35,1005,800
    XRD110_PlotTrees()
    SetWindow XRDPlotWorkspace hook(wheel110)=XRD110_WheelHook
    return 0
End

Function XRD110_SideLegend(win,embedded)
    String win
    Variable embedded
    if(embedded!=2)
        return 0
    endif
    String traces=TraceNameList(win,";",1),trace,key,seen="",labels="",name
    Variable i,ref
    for(i=0;i<ItemsInList(traces);i+=1)
        trace=StringFromList(i,traces);ref=str2num(GetUserData(win,"","Ref_"+trace))
        if(numtype(ref)!=0 || ref<=0)
            continue
        endif
        key=XRD_PhaseLabel(ref)
        if(WhichListItem(key,seen)<0)
            seen+=key+";"
            if(strlen(labels))
                labels+="\r"
            endif
            labels+="\s("+trace+") "+XRD_LegendText(key)
        endif
    endfor
    if(strlen(labels))
        Variable rows=ceil(ItemsInList(seen)/2),c,j,n=ItemsInList(seen)
        String column,annotation
        for(c=0;c<2;c+=1)
            column=""
            for(j=0;j<rows;j+=1)
                if(c*rows+j<n)
                    if(strlen(column))
                        column+="\r"
                    endif
                    column+=StringFromList(c*rows+j,labels,"\r")
                endif
            endfor
            annotation=SelectString(c,"SidePhases110","SidePhases110_2")
            if(strlen(column))
                Legend/W=$win/C/N=$annotation/F=0/B=1/A=LT/X=(c*50)/Y=0/E=2 "\Z10"+column
            endif
        endfor
        ModifyGraph/W=$win margin(top)=max(25,rows*13+12)
    endif
    return 0
End
