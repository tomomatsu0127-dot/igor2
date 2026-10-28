#pragma rtGlobals=3
// XRD Workbench v1.2.2. Japanese guided workflow UI.

Function XRD_Panel()
    PauseUpdate; Silent 1
    if(XRD120_CanRefresh())
        return XRD120_RefreshPanel()
    endif
    XRD_CapturePanelState(1)
    XRD_CaptureView()
    XRD_Init()
    if(!strlen(XRD_Project()))
        return XRD80_ProjectManager()
    endif
    XRD_V50Project(XRD_Project())
    XRD_V72Settings(XRD_Project())
    String project=XRD_Project(),path=XRD_Data(),projectName,measurementTitle="測定データ未選択"
    XRD_EnsureFilterCurrent(path)
    DFREF projectDF=$project
    projectName=XRD_ProjectDisplayName(project)
    NVAR step=$(project+":activeStep")
    step=max(1,min(4,step))
    Variable newFrame=!WinType("XRDWorkbench")
    if(newFrame)
        NewPanel/K=1/EXP=1/N=XRDWorkbench/W=(10,10,868,520) as "XRD Workbench v1.2.2 - "+projectName
    else
        // Invalidate old geometry before constructing the next screen.
        SetWindow XRDWorkbench userdata(XRDLayoutReady)="0"
        XRD120_ClearContents()
        DoWindow/T XRDWorkbench,"XRD Workbench v1.2.2 - "+projectName
    endif
    ModifyPanel/W=XRDWorkbench fixedSize=0
    XRD_UISettings()
    SetWindow XRDWorkbench userdata(XRDProject)=project
    SetWindow XRDWorkbench userdata(XRDData)=path
    SetWindow XRDWorkbench userdata(XRDStep)=num2istr(step)
    if(newFrame || !strlen(GetUserData("XRDWorkbench","","XRDInstance")))
        SetWindow XRDWorkbench userdata(XRDInstance)=num2str(ticks)+num2str(enoise(1))
    endif
    SetWindow XRDWorkbench userdata(XRDUIVersion)="1.2.2"
    DefaultGUIFont/W=XRDWorkbench all={"Segoe UI",10,0},popup={"Segoe UI",10,0}
    SetWindow XRDWorkbench hook(wheel)=XRD_PanelHook
    SetWindow XRDWorkbench hook(undo)=XRD_UndoHook
    Button importData,pos={8,6},size={88,16},title="測定データを追加",proc=XRD_Button
    Button switchData,pos={101,6},size={88,16},title="測定データを選択",proc=XRD_Button
    Button completeData,pos={194,6},size={75,16},title="解析状態を確認",proc=XRD_Button
    Button reference,pos={274,6},size={88,16},title="共通参照値",proc=XRD_Button
    Button saveHelp,pos={367,6},size={62,16},title="保存設定",proc=XRD_Button
    Button helpGuide,pos={434,6},size={88,16},title="操作ガイド",proc=XRD_V51Button
    TitleBox projectLabel,pos={530,10},frame=0,title="プロジェクト: "+projectName
    if(strlen(path)>0)
        XRD_EnsureMeasurement(path)
        SVAR displayName=$(path+":displayName"),status=$(path+":status")
        measurementTitle=displayName+"  ["+StrVarOrDefault(path+":analysisState",status)+"]"
    endif
    SetVariable measurementLabel,pos={670,8},size={180,17},title="",noedit=1,value=_STR:measurementTitle,help={measurementTitle}

    XRD_StepButton("step1",6,"1  測定ピーク",step==1)
    XRD_StepButton("step2",175,"2  参照候補",step==2)
    XRD_StepButton("step3",344,"3  ピーク同定",step==3)
    XRD_StepButton("step4",513,"4  格子定数",step==4)


    GroupBox workGroup,pos={6,53},size={195,439},title="現在の作業"
    if(step==1)
        XRD_PanelStep1(path)
    elseif(step==2)
        XRD_PanelStep2(project)
    elseif(step==3)
        XRD_PanelStep3(project,path)
    elseif(step==4)
        XRD_PanelStep4(path)
    else
        XRD_PanelStep5(project,path)
    endif
    if(strlen(path)>0)
        XRD_DrawMeasurementGraph(path)
    else
        TitleBox empty,pos={231,117},frame=0,title="最初に『測定データを追加』を押してください。"
        Button restoreEmpty,pos={231,155},size={190,25},title="削除した測定データを戻す",proc=XRD_Button
    endif
    // Step 5 is a new layout. Legacy overlays create missing buttons titled New.
    if(step!=5)
        XRD_BeginnerControls(project,path)
        XRD_V70Controls(project,path)
        XRD_V71Controls(project,path)
        XRD_V72Controls(project,path)
    endif
    XRD81_PeakControls(project,path)
    XRD100_ViewControls(project,path)
    XRD_StatusBar(project,path)
    Button redoAction,pos={670,475},size={95,16},title="やり直す",proc=XRD_V50Button
    TitleBox recoveryState,pos={210,475},size={425,14},frame=0,title=""
    NVAR textMode=root:Packages:XRDWorkbench:UI:textMode
    PopupMenu uiText,pos={675,494},title="文字",mode=(textMode+1),value="自動;少し大きく;大きく",proc=XRD_TextSizeAction
    Button undoAction,pos={565,494},size={95,16},title="元に戻す (Ctrl+Z)",proc=XRD_UndoButton
    XRD_UpdateHistoryUI()
    XRD110_Controls(project,path)
    XRD120_Controls()
    XRD_RememberControls()
    if(newFrame)
        XRD_RestorePanelState()
    endif
    XRD_ResizePanel()
    XRD_RestorePanelCursors(path)
    XRD81_AttachPicker(path)
    XRD120_LockY()
    XRD120_UpdateWarning(path)
    // Resolve axes only after the controls and subwindows reach final geometry.
    XRD_ViewSync(path)
    XRD_StartAutoSave()
    XRD_RequestLive()
    return 0
End

Function XRD_StepButton(name,xPos,titleText,selected)
    String name,titleText
    Variable xPos,selected
    Button $name,pos={xPos,29},size={166,20},title=titleText,proc=XRD_Button
    if(selected)
        Button $name,fColor=(18000,36000,54000),title=titleText+"  ●"
    endif
End

Function XRD_PanelStep1(path)
    String path
    TitleBox stepHelp,pos={16,68},size={172,29},frame=0,title="この測定データだけを表示し、\rピークを検出・修正します。"
    if(strlen(path)==0)
        return 0
    endif
    NVAR detectorMode=$(path+":detectorMode")
    SetVariable threshold,pos={16,107},size={169,13},title="高さしきい値 (%)",limits={0,100,1},value=$(path+":threshold")
    SetVariable minDistance,pos={16,130},size={169,13},title="最小間隔 (deg)",limits={0,inf,0.01},value=$(path+":minDistance")
    if(detectorMode==1)
        SetVariable threshold,title="最小突出量 (%)",limits={0,100,0.1},value=$(path+":detectProminence")
    elseif(detectorMode==2)
        SetVariable threshold,title="最小高さ (%)",limits={0,100,0.1},value=$(path+":autoMinHeight")
    endif
    Button detect,pos={16,153},size={169,18},title="検出してピークを登録",proc=XRD_Button
    SetVariable manualAngle,pos={16,192},size={169,13},title="追加する2theta",value=$(path+":manualAngle")
    Button addPeak,pos={16,214},size={81,18},title="手動で追加",proc=XRD_Button
    Button deletePeak,pos={104,214},size={81,18},title="選択を削除",proc=XRD_Button
    Button resetZoom,pos={16,267},size={175,24},title="全範囲に戻す",proc=XRD_Button
    Button cursorPick,pos={16,310},size={175,24},title="カーソルで角度確認・追加",proc=XRD_Button
    Button profileFit,pos={16,242},size={175,20},title="選択ピークをCurveFit",proc=XRD_V50Button
    Button detectorSettings,pos={16,346},size={175,24},title="検出方式・精度を調整／確認",proc=XRD_DetectionButton
    TitleBox rawNote,pos={16,378},size={175,29},frame=0,title="手動・同定済みピークは保持。\r改善方式では背景とノイズも判定。"
    Button deleteData,pos={16,415},size={175,24},title="この測定データを削除",proc=XRD_Button
    Button restoreData,pos={16,451},size={175,24},title="削除を取り消す",proc=XRD_Button
    XRD_AddPeakList(path,210,280,630,210)
End

Function XRD_PanelStep2(project)
    String project
    SVAR summary=$(XRD80_Library()+":referenceLoadSummary"),hint=$(XRD80_Library()+":referenceFolderHint")
    NVAR filterMode=$(project+":elementFilterMode")
    TitleBox stepHelp,pos={16,68},size={172,32},frame=0,title="参照TXTを読み込み、名前・色・\rIgor標準記号を設定します。"
    Button loadReferences,pos={16,107},size={169,18},title="参照フォルダを読み込む",proc=XRD_Button
    TitleBox referenceSummary,pos={16,133},size={169,26},frame=0,title=summary,help={hint}
    Button referenceInfo,pos={16,147},size={175,20},title="参照情報・出典・除外理由",proc=XRD_V50Button
    Button elementTable,pos={16,175},size={175,25},title="周期表で元素を選択",proc=XRD_Button
    TitleBox filterNote,pos={16,208},frame=0,title="使用チェックはExperiment全体で共通"
    Button typeCards,pos={16,233},size={175,25},title="同定に使う物質を選ぶ",proc=XRD_V70Button
    Button referenceStyle,pos={16,271},size={175,24},title="相の色・記号を共通設定",proc=XRD_Button
    TitleBox overlayNote,pos={16,307},frame=0,title="右の相をクリックして参照棒を比較。\r角度は通常、参照元の値です。"
    SetVariable opacity,pos={16,385},size={175,18},title="参照濃さ (%)",limits={10,100,5},value=$(project+":previewOpacity"),proc=XRD_PreviewSetting
    SetVariable lineWidth,pos={16,414},size={175,18},title="参照線幅",limits={0.5,5,0.5},value=$(project+":previewWidth"),proc=XRD_PreviewSetting
    Wave/T refTable=$(XRD80_Library()+":References:table")
    ListBox referenceList,pos={210,280},size={630,210},listWave=refTable,mode=1,proc=XRD_ReferenceSelection,widths={175,115,110,220,240,50}
    NVAR selected=$(project+":selectedReference")
    ListBox referenceList,selRow=selected,row=max(0,selected-3)
    String path=XRD_Data()
    if(strlen(path)>0)
        XRD_PreviewReference(path,selected+1,XRD_ReferenceShift(path,selected+1))
    endif
End

Function XRD_PanelStep3(project,path)
    String project,path
    TitleBox stepHelp,pos={16,68},size={172,42},frame=0,title="ピークを1本選び、候補相の\r薄赤スティックを全範囲で確認して\r採用・重なり・Unknownを決めます。"
    if(strlen(path)==0)
        return 0
    endif
    NVAR candidateMode=$(path+":candidateMode")
    PopupMenu candidateMode,pos={16,107},title="候補",mode=(candidateMode+1),value="すべて;採用済みの相;新しい相",proc=XRD_CandidateModeAction
    SetVariable matchTolerance,pos={16,134},size={169,13},title="一致幅 ±deg",limits={0.001,5,0.01},value=$(project+":matchTolerance")
    SetVariable maxShift,pos={16,156},size={169,13},title="共通シフト上限",limits={0,5,0.01},value=$(project+":maxCommonShift")
    SetVariable previewMin,pos={16,178},size={169,13},title="表示強度下限 (%)",limits={0,100,1},value=$(project+":previewMinIntensity")
    Button scoreCandidates,pos={16,195},size={169,18},title="選択ピークの候補を更新",proc=XRD_Button
    Button adoptCandidate,pos={16,224},size={81,18},title="置き換えて採用",proc=XRD_Button
    Button overlapCandidate,pos={104,224},size={81,18},title="重なり追加",proc=XRD_Button
    Button unknownPeak,pos={16,247},size={81,18},title="Unknown",proc=XRD_Button
    Button clearAssignment,pos={104,247},size={81,18},title="同定を解除",proc=XRD_Button
    Button resetZoom,pos={16,280},size={175,24},title="全範囲に戻す",proc=XRD_Button
    SetVariable opacity,pos={16,317},size={175,18},title="参照濃さ (%)",limits={10,100,5},value=$(project+":previewOpacity"),proc=XRD_PreviewSetting
    SetVariable lineWidth,pos={16,343},size={175,18},title="参照線幅",limits={0.5,5,0.5},value=$(project+":previewWidth"),proc=XRD_PreviewSetting
    Button tableView,pos={16,378},size={175,24},title="表を大きく / グラフと半分",proc=XRD_Button
    Button evidence,pos={16,443},size={175,20},title="候補の根拠・強い未一致を見る",proc=XRD_V50Button
    Button audit,pos={16,470},size={175,18},title="同定の確認一覧",proc=XRD_V50Button
    Button deletePeak2,pos={16,412},size={175,24},title="選択した測定ピークを削除",proc=XRD_Button
    XRD_AddPeakList(path,210,280,290,210)
    Wave/T candidates=$(path+":Candidates:table")
    ListBox candidateList,pos={505,280},size={335,210},listWave=candidates,mode=1,widths={140,110,65,120,55,65,50,55,210,70,60},fSize=10,proc=XRD_CandidateListAction
    NVAR selectedCandidate=$(path+":selectedCandidateRow")
    ListBox candidateList,selRow=selectedCandidate
End

Function XRD_PanelStep4(path)
    String path
    TitleBox fitHelp,pos={16,70},size={175,70},frame=0,title="全ピーク対応後、参照相を選んで\r六方晶・立方晶を計算します。\r採用ピークを表で確認できます。"
    Button metadata,pos={16,142},size={175,20},title="測定条件・角度補正",proc=XRD_V50Button
    if(strlen(path)>0)
        SetVariable wavelength,pos={16,175},size={175,20},title="波長 (Å)",limits={0.1,5,0.0001},value=$(path+":measurementWavelength"),noedit=1
    endif
    Button fitOpen,pos={16,205},size={175,26},title="計算する相・ピークを選択",proc=XRD_Button
    Button latticeQuality,pos={16,246},size={175,25},title="計算結果・残差を確認",proc=XRD_V50Button
    Button profileFit,pos={16,285},size={175,25},title="選択ピークをCurveFit",proc=XRD_V50Button
    if(strlen(path)>0)
        Wave/T assignments=$(path+":Assignments:table")
        ListBox assignmentList,pos={210,280},size={630,210},listWave=assignments,mode=1
    endif
End

Function XRD_PanelStep5(project,path)
    String project,path
    TitleBox stepHelp,pos={16,68},size={175,64},frame=0,title="作図は独立したウィンドウで行います。\r他プロジェクトの完了試料も選べます。\rこの一覧は現在のプロジェクトです。"
    Button plotWorkspace,pos={16,151},size={175,32},title="作図ウィンドウを開く",proc=XRD80_WorkspaceButton
    Button editGraph2,pos={16,199},size={175,25},title="この完了試料の単独図",proc=XRD_Button
    Button referenceStyle,pos={16,244},size={175,25},title="使用相の色・記号",proc=XRD_Button
    Button latticeSummary,pos={16,289},size={175,25},title="格子定数の計算履歴",proc=XRD80_WorkspaceButton
    Button projectManager,pos={16,334},size={175,25},title="プロジェクト・試料一覧",proc=XRD80_WorkspaceButton
    Button report,pos={16,379},size={175,22},title="解析レポートを保存",proc=XRD_V50Button
    Button deleteData,pos={16,421},size={175,24},title="この測定データを削除",proc=XRD_Button
    Button restoreData,pos={16,456},size={175,24},title="削除を取り消す",proc=XRD_Button
    XRD_BuildMeasurementTable(project)
    Wave/T measurements=$(project+":measurementTable")
    ListBox measurementList,pos={210,280},size={630,210},listWave=measurements,mode=1,widths={90,310,150,120,120},proc=XRD_MeasurementListAction
End

Function XRD_AddPeakList(path,xPos,yPos,width,height)
    String path
    Variable xPos,yPos,width,height
    XRD_PeakTable(path)
    Wave/T peakTable=$(path+":Peaks:table")
    ListBox peakList,pos={xPos,yPos},size={width,height},listWave=peakTable,mode=1,widths={70,65,175,60,55},fSize=10,proc=XRD_PeakListAction
    NVAR selected=$(path+":selectedPeakRow")
    ListBox peakList,selRow=selected,row=max(0,selected-3)
End

Function XRD_DrawMeasurementGraph(path)
    String path
    Variable step=NumVarOrDefault(XRD_Project()+":activeStep",1)
    if(step==1)
        return XRD_DrawPeakFocus(path)
    elseif(step==3 && NumVarOrDefault(XRD_Project()+":liveCompare",0))
        return XRD_DrawLiveStack("XRDWorkbench#Pattern",1)
    endif
    Wave xx=$(path+":Raw:twoTheta"),yy=$(path+":Processed:intensity")
    Wave px=$(path+":Peaks:angle"),py=$(path+":Peaks:height")
    Wave previewX=$(path+":Preview:angle"),previewY=$(path+":Preview:height")
    XRD_EnsureEvidence(path)
    XRD_UpdateAssignedPlot(path)
    XRD_UnassignedPlot(path)
    Wave ux=$(path+":Preview:unassignedX"),uy=$(path+":Preview:unassignedY")
    Wave assignedX=$(path+":Assignments:plotAngle"),assignedY=$(path+":Assignments:plotHeight")
    Display/HOST=XRDWorkbench/N=Pattern/W=(210,60,840,270) yy/TN=XRDWB_Measured vs xx
    AppendToGraph/W=XRDWorkbench#Pattern uy/TN=XRDWB_Peaks vs ux
    AppendToGraph/W=XRDWorkbench#Pattern previewY/TN=XRDWB_Preview vs previewX
    XRD_AddEvidenceTraces(path)
    XRD_AddPhaseTraces("XRDWorkbench#Pattern",path,0)
    ModifyGraph/W=XRDWorkbench#Pattern rgb(XRDWB_Measured)=(0,0,0),lsize(XRDWB_Measured)=1.2
    ModifyGraph/W=XRDWorkbench#Pattern mode(XRDWB_Peaks)=3,marker(XRDWB_Peaks)=19,msize(XRDWB_Peaks)=3,rgb(XRDWB_Peaks)=(0,0,0)
    NVAR opacity=$(XRD_Project()+":previewOpacity"),lineWidth=$(XRD_Project()+":previewWidth")
    Variable alpha=65535*opacity/100
    ModifyGraph/W=XRDWorkbench#Pattern mode(XRDWB_Preview)=1,rgb(XRDWB_Preview)=(60000,0,0,alpha),lsize(XRDWB_Preview)=lineWidth
    ModifyGraph/W=XRDWorkbench#Pattern mirror=1,tick=2,fSize=12
    Label/W=XRDWorkbench#Pattern bottom "2\F'Symbol'q\F'Arial' (deg)"
    Label/W=XRDWorkbench#Pattern left "Intensity (source units)"
    XRD_GraphStyle("XRDWorkbench#Pattern",110,0)
    XRD_RestoreView(path)
    XRD_SelectedPeakGuide(path)
    XRD_ShiftNotice(path)
    XRD_ReferenceArrow(path)
    XRD_ViewSync(path)
    SetActiveSubwindow XRDWorkbench
End

Function XRD_StatusBar(project,path)
    String project,path
    Variable total=XRD_TotalMeasurementCount(),completed=XRD_CompletedMeasurementCount()
    String text="測定データ "+num2istr(total)+"件  |  解析完了 "+num2istr(completed)+"件  |  元データ保護"
    if(strlen(path)>0)
        Wave peaks=$(path+":Peaks:angle")
        text+="  |  現在のピーク "+num2istr(numpnts(peaks))+"本"
    endif
    ControlInfo/W=XRDWorkbench statusBar
    if(V_flag==0)
        TitleBox statusBar,win=XRDWorkbench,pos={10,495},size={832,12},frame=0,title=text
    else
        TitleBox statusBar,win=XRDWorkbench,title=text
    endif
End

Function XRD_Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String project=XRD_Project(),path=XRD_Data(),name=ba.ctrlName
    Variable result
    strswitch(name)
        case "deleteData":
            XRD_DeleteMeasurementUI()
            break
        case "restoreData":
        case "restoreEmpty":
            XRD_RestoreMeasurementUI()
            break
        case "resetZoom":
            XRD_ResetView()
            break
        case "elementTable":
            XRD_ElementPanel()
            break
        case "fitOpen":
            XRD_LatticePanel()
            break
        case "cursorPick":
            XRD_OpenPicker()
            break
        case "referenceStyle":
            XRD_StylePanel()
            break
        case "tableView":
            NVAR tableOnly=$(project+":tablesOnly")
            tableOnly=1-tableOnly
            XRD_TableLayout(project)
            break
        case "importData":
            Execute/P/Q "XRD_ImportDialog()"
            break
        case "switchData":
            XRD_SelectData()
            break
        case "completeData":
            if(strlen(path))
                XRD_AuditPanel()
                return 0
                result=XRD_SetMeasurementComplete(path)
                if(result==-2)
                    DoAlert 0,"未確認のピークがあります。相、重なり、またはUnknownを設定してください。"
                elseif(result<0)
                    DoAlert 0,"ピークがありません。"
                endif
                XRD_Panel()
            endif
            break
        case "reference":
            XRD80_LibraryPanel()
            return 0
        case "loadReferences":
            XRD_ChooseReference()
            XRD_Panel()
            break
        case "saveHelp":
            XRD_SaveSettingsPanel()
            break
        case "editGraph":
        case "editGraph2":
            XRD_CreateEditableGraph()
            break
        case "stackGraph":
            XRD_CreateStackGraph()
            break
        case "moveUp":
            XRD_MoveMeasurement(path,-1)
            XRD_Panel()
            break
        case "moveDown":
            XRD_MoveMeasurement(path,1)
            XRD_Panel()
            break
        case "step1":
        case "step2":
        case "step3":
        case "step4":
        case "step5":
            NVAR step=$(project+":activeStep")
            step=str2num(name[4,4])
            XRD_Panel()
            break
        case "detect":
            if(strlen(path))
                result=XRD_Detect(path)
                if(result<0)
                    DoAlert 0,"検出方式・精度の設定を確認してください。改善方式は7点以上が必要です。背景幅は平滑化幅の4倍以上、突出量の評価幅は最小ピーク幅の2倍以上にします。"
                endif
                XRD_Panel()
            endif
            break
        case "addPeak":
            if(strlen(path))
                NVAR angle=$(path+":manualAngle")
                result=XRD_Manual(path,angle)
                if(result<0)
                    DoAlert 0,"測定範囲内の有限な角度を入力してください。"
                endif
                XRD81_RefreshPeaks(path)
            endif
            break
        case "deletePeak2":
        case "deletePeak":
            if(strlen(path))
                NVAR selectedPeak=$(path+":selectedPeakRow")
                XRD_Delete(path,selectedPeak)
                Wave remaining=$(path+":Peaks:angle")
                selectedPeak=min(selectedPeak,numpnts(remaining)-1)
                XRD81_RefreshPeaks(path)
            endif
            break
        case "scoreCandidates":
            XRD_UpdateCandidatesFromSelection(path)
            break
        case "adoptCandidate":
            XRD_ApplySelectedCandidate(path,0)
            break
        case "overlapCandidate":
            XRD_ApplySelectedCandidate(path,1)
            break
        case "unknownPeak":
            if(strlen(path))
                NVAR selectedPeak=$(path+":selectedPeakRow")
                XRD_SetUnknown(path,selectedPeak)
                XRD81_RefreshPeaks(path)
            endif
            break
        case "clearAssignment":
            if(strlen(path))
                NVAR selectedPeak=$(path+":selectedPeakRow")
                XRD_ClearPeakReview(path,selectedPeak)
                XRD81_RefreshPeaks(path)
            endif
            break
    endswitch
    return 0
End

Function XRD_UpdateCandidatesFromSelection(path)
    String path
    if(strlen(path)==0)
        return -1
    endif
    NVAR selectedPeak=$(path+":selectedPeakRow")
    Variable result=XRD_ScoreCandidates(path,selectedPeak)
    if(result==-2)
        DoAlert 0,"参照TXTを読み込むか、一致幅の設定を確認してください。"
    elseif(result==0)
        DoAlert 0,"このピークに一致する候補がありません。"
    endif
    XRD81_RefreshPeaks(path,rescore=0)
    return result
End

Function XRD_ApplySelectedCandidate(path,overlap)
    String path
    Variable overlap
    if(strlen(path)==0)
        return -1
    endif
    NVAR selectedPeak=$(path+":selectedPeakRow"),selectedCandidate=$(path+":selectedCandidateRow")
    if(!XRD120_ConfirmCandidate(path,selectedCandidate))
        return -4
    endif
    Variable result=XRD_AssignCandidate(path,selectedPeak,selectedCandidate,overlap)
    if(result<0)
        if(result==-2)
            Wave refs=$(path+":Candidates:refIndex"),refPeaks=$(path+":Candidates:refPeakIndex"),ids=$(path+":Peaks:peakID"),angles=$(path+":Peaks:angle")
            Variable owner=XRD_ReferencePeakOwner(path,refs[selectedCandidate],refPeaks[selectedCandidate],ids[selectedPeak])
            DoAlert 0,"この参照ピークは、同じ測定の "+num2str(angles[owner])+"° に採用済みです。先にそのピークの同定を解除するか、別の参照ピークを選んでください。"
        elseif(result==-3)
            DoAlert 0,"この参照カードは現在のtype選択では候補対象外です。参照候補の画面で選択を確認してください。"
        else
            DoAlert 0,"ピークと候補相を選択してください。"
        endif
        return result
    endif
    if(!overlap)
        Wave angles=$(path+":Peaks:angle")
        selectedPeak=min(selectedPeak+1,numpnts(angles)-1)
        XRD_ScoreCandidates(path,selectedPeak)
    endif
    XRD81_RefreshPeaks(path,rescore=overlap)
    return 0
End

Function XRD_PeakListAction(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode==3 || lba.eventCode==4)
        String path=XRD_Data()
        if(strlen(path))
            return XRD100_Select(path,lba.row,1)
        endif
    endif
    return 0
End

Function XRD_CandidateListAction(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode!=3 && lba.eventCode!=4)
        return 0
    endif
    String path=XRD_Data()
    if(strlen(path)==0 || lba.row<0)
        return 0
    endif
    XRD_PreviewCandidate(path,lba.row)
    if(lba.eventCode==3)
        XRD_QueueCandidateAdoption(path,lba.row)
    endif
    return 0
End

Function XRD_MeasurementListAction(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode!=3 && lba.eventCode!=4)
        return 0
    endif
    String project=XRD_Project()
    Wave/T table=$(project+":measurementTable")
    if(lba.row<0 || lba.row>=DimSize(table,0))
        return 0
    endif
    SVAR active=$(project+":activeData")
    active=project+":Measurements:"+table[lba.row][0]
    XRD_Panel()
    return 0
End

Function XRD_FilterPopup(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2)
        return 0
    endif
    NVAR mode=$(XRD_Project()+":elementFilterMode")
    mode=pa.popNum-1
    return 0
End

Function XRD_SelectData()
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project),labels="",name,path
    Variable i,choice=1
    if(ItemsInList(list)==0)
        return 0
    endif
    for(i=0;i<ItemsInList(list);i+=1)
        name=StringFromList(i,list)
        path=XRD110_MeasurementPath(project,name)
        labels+=name+" — "+ReplaceString(";",StrVarOrDefault(path+":displayName",name),",")+";"
    endfor
    Prompt choice,"測定データ",popup,labels
    DoPrompt "同定する測定データを選択",choice
    if(V_flag)
        return -1
    endif
    SVAR active=$(project+":activeData")
    active=project+":Measurements:"+StringFromList(choice-1,list)
    XRD_Panel()
    return 0
End

Function XRD_TotalMeasurementCount()
    return ItemsInList(XRD_MeasurementOrderList(XRD_Project()))
End

Function XRD_BuildMeasurementTable(project)
    String project
    String name,path,orderList=XRD_MeasurementOrderList(project)
    Variable i,n=ItemsInList(orderList)
    Make/O/T/N=(n,5) $(project+":measurementTable")
    Wave/T table=$(project+":measurementTable")
    for(i=0;i<n;i+=1)
        name=StringFromList(i,orderList)
        path=XRD110_MeasurementPath(project,name)
        XRD_EnsureMeasurement(path)
        SVAR displayName=$(path+":displayName"),status=$(path+":status")
        NVAR visible=$(path+":visibleInStack"),normalization=$(path+":normalization")
        Wave peaks=$(path+":Peaks:angle")
        table[i][0]=name
        table[i][1]=displayName
        table[i][2]=StrVarOrDefault(path+":analysisState",status)
        table[i][3]=num2istr(numpnts(peaks))+" peaks"
        table[i][4]=SelectString(visible,"比較図OFF","比較図ON")+" / 0–100"
    endfor
    SetDimLabel 1,0,Data,table
    SetDimLabel 1,1,Name,table
    SetDimLabel 1,2,Status,table
    SetDimLabel 1,3,Peaks,table
    SetDimLabel 1,4,Stack,table
End

