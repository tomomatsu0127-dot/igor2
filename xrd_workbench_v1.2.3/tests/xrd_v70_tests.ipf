#pragma rtGlobals=3
Function XRD_V70Adopt(path,peak,index)
    String path
    Variable peak,index
    XRD_ScoreCandidates(path,peak)
    Wave refs=$(path+":Candidates:refIndex")
    Variable i
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==index)
            return XRD_AssignCandidate(path,peak,i,0)
        endif
    endfor
    return -10
End

Function XRD_RunV70Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    XRD_NewProject()
    String project=XRD_Project()
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_TestCheck(XRD_LoadReferenceFile("01_QS.txt",1)==0 && XRD_LoadReferenceFile("02_Y.txt",2)==0 && XRD_LoadReferenceFile("03_Cu.txt",3)==0,"workflow fixtures load distinct cards")
    Make/FREE/D/N=4001 xx=20+0.01*p,yy=5+100*exp(-((xx[p]-30.1)/0.08)^2)+60*exp(-((xx[p]-40.1)/0.08)^2)+30*exp(-((xx[p]-50.1)/0.08)^2)
    String path=XRD_Store(xx,yy,"first.xy")
    XRD_Manual(path,30.1);XRD_Manual(path,40.1);XRD_Manual(path,50.1)
    Wave raw=$(path+":Raw:intensity"),rawX=$(path+":Raw:twoTheta"),angles=$(path+":Peaks:angle")
    Variable crc=WaveCRC(0,raw),xcrc=WaveCRC(0,rawX),i,shift
    XRD_TestCheck(XRD_ReferenceShift(path,1)==0,"default reference preview uses original card angles")
    Variable/G $(project+":referenceShiftMode")=1
    shift=XRD_ReferenceShift(path,1)
    XRD_TestCheck(abs(shift-0.1)<0.001,"whole-pattern optional shift recovers common 0.1 degree offset")
    XRD_ScoreCandidates(path,0)
    Wave shifts=$(path+":Candidates:shift"),refs=$(path+":Candidates:refIndex")
    Variable firstShift=NaN
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==1)
            firstShift=shifts[i]
            break
        endif
    endfor
    XRD_ScoreCandidates(path,1)
    Variable secondShift=NaN
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==1)
            secondShift=shifts[i]
            break
        endif
    endfor
    XRD_TestCheck(abs(firstShift-secondShift)<1e-12,"card shift is independent of selected measured anchor")
    XRD_PreviewReference(path,1,XRD_ReferenceShift(path,1))
    Wave preview=$(path+":Preview:angle")
    XRD_TestCheck(abs(preview[0]-30.1)<0.001,"reference tab policy and candidate policy use same shift")
    String singleton=XRD_Store(xx,yy,"singleton.xy")
    XRD_Manual(singleton,30.12)
    XRD_TestCheck(XRD_ReferenceShift(singleton,1)==0,"a single matched reflection cannot create an automatic shift")
    SVAR active=$(project+":activeData")
    active=path
    Variable/G $(project+":referenceShiftMode")=0
    XRD_TestCheck(XRD_V70Adopt(path,0,1)==0 && XRD_V70Adopt(path,1,2)==0,"two used phases can be adopted without unused copper phase")
    String targets=XRD_UsedStyleTargets()
    XRD_TestCheck(ItemsInList(targets)==2 && WhichListItem("3",targets)<0,"style selector lists only phases used in this project")
    XRD_StylePanel()
    XRD_TestCheck(cmpstr(GetUserData("XRDStyles","","XRDTargetMap"),targets)==0,"native marker panel uses a stable filtered reference map")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDStyles as output+"used_styles_v070.png"
    XRD_CreateEditableGraph()
    String figure=WinName(0,1)
    String legacyInfo=AnnotationInfo(figure,"Phases",1)
    SetWindow $figure userdata(XRDManagedLegend)=StringByKey("FLAGS",legacyInfo)+legacyInfo[4,inf]
    DoUpdate
    XRD_TestCheck(XRD_IsManagedLegend(figure)==1,"old geometry-containing legend signature migrates by exact text and flags")
    XRD_TestCheck(XRD_LegendOrderPanel()==0,"legend order panel opens without requiring a prior Workbench window")
    XRD_MoveLegend(1)
    XRD_TestCheck(XRD_ApplyLegendOrder()==0,"legend order can be saved and applied")
    String text=StringByKey("TEXT",AnnotationInfo(figure,"Phases",1))
    XRD_TestCheck(strsearch(text,"Y-type",0)<strsearch(text,"QS-type",0),"existing managed figure follows user legend order")
    XRD_TestCheck(cmpstr(StringFromList(0,XRD_UsedStyleTargets()),"2")==0,"used-phase choices follow common project legend order")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDLegendOrder as output+"legend_order_v070.png"
    SavePICT/O/E=-5/WIN=$figure as output+"ordered_figure_v070.png"
    Legend/W=$figure/C/N=Phases "CUSTOM LEGEND"
    XRD_MoveLegend(-1)
    XRD_ApplyLegendOrder()
    text=StringByKey("TEXT",AnnotationInfo(figure,"Phases",1))
    XRD_TestCheck(cmpstr(text,"CUSTOM LEGEND")==0,"applying legend order preserves manual Igor legend edits")
    NVAR step=$(project+":activeStep"),selected=$(path+":selectedPeakRow")
    step=3;selected=1
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_TestCheck(XRD_ZoomSelectedPeak()==0,"selected-peak zoom button applies")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-35.1)<1e-6 && abs(V_max-45.1)<1e-6,"selected-peak zoom covers plus/minus five degrees")
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_min==-30 && V_max==110,"selected-peak zoom retains intensity scale")
    XRD_Undo()
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==20 && V_max==60,"one-click zoom is undoable")
    XRD_Redo()
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-35.1)<1e-6,"one-click zoom is redoable")
    XRD_OpenReview()
    XRD_TestCheck(WinType("XRDReviewGraph")==1 && ItemsInList(TraceNameList("XRDReviewGraph",";",1))>=4,"review graph contains both samples and assigned phase markers")
    XRD_ReviewGuide(1)
    GetAxis/W=XRDReviewGraph/Q bottom
    XRD_TestCheck(abs(V_min-35.1)<1e-6 && abs(V_max-45.1)<1e-6,"stacked review zoom shares selected peak angle")
    XRD_OpenReview()
    GetAxis/W=XRDReviewGraph/Q bottom
    XRD_TestCheck(abs(V_min-35.1)<1e-6,"refreshing comparison retains review zoom")
    Wave top=$(project+":LiveReview:intensity0"),bottom=$(project+":LiveReview:intensity1")
    XRD_TestCheck(abs(top[0]-bottom[0]-135)<1e-6,"review keeps measurement-list order from top to bottom")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDReviewGraph as output+"review_v070.png"
    DoWindow/K XRDReviewGraph
    XRD_ScoreCandidates(path,1)
    XRD_PreviewCandidate(path,0)
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"identification_v070.png"
    XRD_MaterialPanel()
    Wave material=root:Packages:XRDWorkbench:UI:MaterialDraft:selection
    material[][0]=32;material[0][0]=48;material[2][0]=48
    XRD_TestCheck(XRD_CandidateAllowed(path,2)==1,"material draft has no live effect until apply")
    Wave candidateRefs=$(path+":Candidates:refIndex")
    Variable excludedRow=-1
    for(i=0;i<numpnts(candidateRefs);i+=1)
        if(candidateRefs[i]==2)
            excludedRow=i
        endif
    endfor
    XRD_TestCheck(XRD_ApplyMaterials()==0 && XRD_CandidateAllowed(path,1) && !XRD_CandidateAllowed(path,2) && XRD_CandidateAllowed(path,3),"general material selection handles type and fixed-composition phases")
    XRD_TestCheck(excludedRow>=0 && XRD_AssignCandidate(path,1,excludedRow,0)==-3,"stale excluded ordinary/type candidate cannot be adopted after material apply")
    XRD_ScoreCandidates(path,1)
    Variable foundExcluded=0
    for(i=0;i<numpnts(refs);i+=1)
        foundExcluded+=refs[i]==2
    endfor
    XRD_TestCheck(foundExcluded==0,"unselected phases are absent from candidate rows")
    Wave assignments=$(path+":Assignments:refIndex")
    XRD_TestCheck(numpnts(assignments)==2 && assignments[1]==2,"material selection does not delete existing identification")
    SVAR allowed=$(project+":allowedElements")
    NVAR elementMode=$(project+":elementFilterMode")
    allowed="Ba,Fe,Mg,O";elementMode=2
    XRD_TestCheck(XRD_FormulaCompatible("Cu O","")==0 && XRD_FormulaCompatible("Ba Zn Fe O","QS-type")==1,"material choices combine with elemental exclusion and replaceable type exceptions")
    elementMode=0
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDMaterials as output+"materials_v070.png"
    DoWindow/K XRDMaterials
    Variable before=numpnts(angles),history=NumVarOrDefault(project+":Undo:sequence",0)
    XRD_TestCheck(XRD_ExternalPeaks(path,fixtures+"bad_peaks.csv")==-2 && numpnts(angles)==before && NumVarOrDefault(project+":Undo:sequence",0)==history,"malformed external peak file rejects atomically before Undo")
    XRD_TestCheck(XRD_ExternalPeaks(path,fixtures+"unknown_header.txt")==-2 && numpnts(angles)==before,"q-space input is not silently treated as two-theta")
    XRD_TestCheck(XRD_ExternalPeaks(path,fixtures+"peaks.csv")==2 && numpnts(angles)==before+2,"external headers map angle column and skip duplicate raw point/out-of-range angle")
    XRD_TestCheck(XRD_TestNearestError(path,45.123)<1e-9 && XRD_TestNearestError(path,55.456)<1e-9,"external fitted angles retain original sub-step precision")
    Wave/T origin=$(path+":Peaks:origin")
    Variable externalCount=0
    for(i=0;i<numpnts(origin);i+=1)
        externalCount+=cmpstr(origin[i],"External")==0
        if(cmpstr(origin[i],"External")==0)
            XRD_TestCheck(strsearch(XRD_PeakAngleSource(path,i),"外部ピーク",0)>=0,"lattice/report angle source identifies external origin row "+num2istr(i))
        endif
    endfor
    XRD_TestCheck(externalCount==2,"external peak origin remains distinct and is preserved by redetection")
    XRD_Undo()
    XRD_TestCheck(numpnts(angles)==before,"external import is one undo operation")
    XRD_Redo()
    XRD_TestCheck(numpnts(angles)==before+2,"external import can be redone")
    history=NumVarOrDefault(project+":Undo:sequence",0)
    XRD_TestCheck(XRD_ExternalPeaks(path,fixtures+"peaks.csv")==0 && NumVarOrDefault(project+":Undo:sequence",0)==history,"reimporting existing external peaks does not consume Undo history")
    XRD_TestCheck(XRD_ExternalPeaks(path,fixtures+"one_column.txt")==2,"plain angle-only peak lists are supported")
    XRD_TestCheck(WaveCRC(0,raw)==crc && WaveCRC(0,rawX)==xcrc,"workflow changes preserve raw intensity and angle waves")
    step=1
    XRD_TestDisableFollow()
    XRD_Panel()
    ControlInfo/W=XRDWorkbench threshold
    XRD_TestCheck(V_disable==0,"active detection threshold is editable in improved mode")
    XRD_DetectionPanel()
    STRUCT WMPopupAction preset
    preset.eventCode=2;preset.popNum=3
    XRD_DetectionPreset(preset)
    XRD_TestCheck(NumVarOrDefault(path+":detectSNR",0)==3 && NumVarOrDefault(path+":detectProminence",0)==0.2,"weak-peak preset applies active thresholds")
    preset.popNum=5
    XRD_DetectionPreset(preset)
    XRD_TestCheck(NumVarOrDefault(path+":minDistance",0)==0.06 && NumVarOrDefault(path+":autoSmoothFactor",0)==1,"close-peak preset reduces distance and native smoothing")
    preset.popNum=2
    XRD_DetectionPreset(preset)
    XRD_TestCheck(NumVarOrDefault(path+":detectSNR",0)==4 && NumVarOrDefault(path+":detectBaselineDeg",0)==1.2,"standard preset restores complete consistent settings")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDDetectionSettings as output+"detection_settings_v070.png"
    DoWindow/K XRDDetectionSettings
    step=3
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"workbench_v070.png"
    SaveExperiment/C/F={1,"",0} as output+"workflow.pxp"
    XRD_TestCheck(GetRTError(1)==0,"new workflow and UI leave no native runtime error")
    NVAR failures=root:XRDTestFailures
    Print "v0.7.0 workflow failures="+num2istr(failures)
End

Function XRD_V70Persistence(saved)
    String saved
    LoadData/O/Q/R saved
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    String project=XRD_Project(),path=XRD_Data()
    XRD_TestCheck(strlen(StrVarOrDefault(XRD80_Styles()+":legendOrder",""))>0,"legend order survives experiment data reload")
    XRD_TestCheck(XRD_MaterialAllowed(1) && !XRD_MaterialAllowed(2) && XRD_MaterialAllowed(3),"material choices survive experiment data reload")
    XRD_TestCheck(XRD_TestNearestError(path,45.123)<1e-9 && DataFolderExists(path+":ExternalPeaks"),"external angles and provenance survive reload")
    XRD_TestCheck(NumVarOrDefault(project+":referenceShiftMode",-1)==0,"explicit reference-shift policy survives reload")
End

Function XRD_RunV70Detector(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    XRD_NewProject()
    XRD_ImportFile(fixtures+"noisy_uniform.csv")
    String path=XRD_Data(),project=XRD_Project()
    Wave xx=$(path+":Raw:twoTheta"),raw=$(path+":Raw:intensity"),angles=$(path+":Peaks:angle"),ids=$(path+":Peaks:peakID")
    Variable crc=WaveCRC(0,raw),xcrc=WaveCRC(0,xx),result,i,hits=0,history=NumVarOrDefault(project+":Undo:sequence",0)
    result=XRD_DetectAutoFind(path,0)
    XRD_TestCheck(result>=0 && numpnts(angles)==0 && NumVarOrDefault(project+":Undo:sequence",0)==history,"native Peak AutoFind preview leaves peaks and Undo unchanged")
    Variable/G $(path+":detectorMode")=2
    result=XRD_Detect(path)
    XRD_TestCheck(result>0 && cmpstr(StrVarOrDefault(path+":algorithm",""),"igor-peak-autofind-v1")==0,"detector dispatcher registers native AutoFind results and algorithm")
    Make/FREE/D truth={30,33,40,40.22,50}
    for(i=0;i<5;i+=1)
        hits+=XRD_TestNearestError(path,truth[i])<0.06
    endfor
    Print "AUTOFIND FIXTURE: "+num2istr(hits)+"/5 true; registered="+num2istr(numpnts(angles))
    XRD_TestCheck(hits>=4,"native alternative finds at least four synthetic reference peaks")
    XRD_TestCheck(WaveCRC(0,raw)==crc && WaveCRC(0,xx)==xcrc,"native AutoFind leaves original measurements bit-identical")
    XRD_Undo()
    XRD_TestCheck(numpnts(angles)==0,"native detector registration is undoable")
    XRD_Redo()
    XRD_TestCheck(numpnts(angles)==result,"native detector registration is redoable")
    XRD_Manual(path,56)
    Variable before=numpnts(angles),manualID=ids[numpnts(ids)-1],found=0
    XRD_Detect(path)
    for(i=0;i<numpnts(ids);i+=1)
        found+=ids[i]==manualID
    endfor
    XRD_TestCheck(found==1,"native redetection retains stable manual peak identity")
    Variable/G $(path+":autoMinHeight")=NaN
    before=numpnts(angles);history=NumVarOrDefault(project+":Undo:sequence",0)
    XRD_TestCheck(XRD_Detect(path)==-1 && numpnts(angles)==before && NumVarOrDefault(project+":Undo:sequence",0)==history,"invalid native threshold rejects without mutation")
    Variable/G $(path+":autoMinHeight")=1
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_DetectionPanel()
    ControlInfo/W=XRDWorkbench threshold
    XRD_TestCheck(V_disable==0,"native mode active minimum-height threshold remains editable")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDDetectionSettings as output+"native_settings_v070.png"
    XRD_ShowDetection(path)
    DoUpdate
    SavePICT/O/E=-5/WIN=XRDDetectionPreview as output+"native_preview_v070.png"
    Variable/G $(path+":autoMinHeight")=1.7
    Variable/G $(path+":autoSmoothFactor")=2.25
    XRD_Detect(path)
    SaveExperiment/C/F={1,"",0} as output+"native_detection.pxp"
    DoWindow/K XRDDetectionSettings
    DoWindow/K XRDDetectionPreview
    XRD_ImportFile(fixtures+"noisy_uneven.csv")
    String uneven=XRD_Data()
    Variable/G $(uneven+":detectorMode")=2
    result=XRD_Detect(uneven)
    hits=0
    for(i=0;i<5;i+=1)
        hits+=XRD_TestNearestError(uneven,truth[i])<0.06
    endfor
    XRD_TestCheck(result>0 && hits>=4,"native alternative also handles nonuniform angular sampling")
    Make/FREE/D/N=501 fx=20+0.01*p,fy=8
    String flat=XRD_Store(fx,fy,"flat_native.xy")
    Variable/G $(flat+":detectorMode")=2
    XRD_TestCheck(XRD_Detect(flat)==0,"native detector returns zero peaks for a flat measurement")
    Make/FREE/D/N=12 sx=p+20,sy=exp(-((p-6)/2)^2)
    String shortPath=XRD_Store(sx,sy,"short_native.xy")
    Variable/G $(shortPath+":detectorMode")=2
    XRD_TestCheck(XRD_Detect(shortPath)==-2 && numpnts($(shortPath+":Peaks:angle"))==0,"native alternative rejects undersampled input without modifying peaks")
    XRD_TestCheck(GetRTError(1)==0,"native detection integration leaves no runtime error")
    NVAR failures=root:XRDTestFailures
    Print "v0.7.0 native detector failures="+num2istr(failures)
End

Function XRD_V70NativePersistence(saved)
    String saved
    LoadData/O/Q/R saved
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    String path=XRD_Data()
    XRD_TestCheck(NumVarOrDefault(path+":detectorMode",0)==2 && NumVarOrDefault(path+":autoMinHeight",0)==1.7 && NumVarOrDefault(path+":autoSmoothFactor",0)==2.25,"custom native detector mode and numeric settings survive reload")
    String run=StrVarOrDefault(path+":detectionRunDescription","")
    XRD_TestCheck(strsearch(run,"minHeight=1.7",0)>=0 && strsearch(run,"derivativeSmoothFactor=2.25",0)>=0,"actual native detector parameters persist separately from previews")
    XRD_TestCheck(numpnts($(path+":Peaks:angle"))>0 && DataFolderExists(path+":Detection:Native"),"native registered results and diagnostics survive reload")
End

Function XRD_RunV70Challenge(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    XRD_NewProject()
    Variable c,mode,i,result,hits,crc,xcrc
    Make/FREE/D/N=3 truth
    for(c=0;c<3;c+=1)
        XRD_ImportFile(fixtures+StringFromList(c,"ramp.csv;close.csv;broad.csv"))
        String path=XRD_Data()
        Wave yy=$(path+":Raw:intensity"),xx=$(path+":Raw:twoTheta"),peaks=$(path+":Peaks:angle")
        crc=WaveCRC(0,yy);xcrc=WaveCRC(0,xx)
        if(c==0)
            truth={27,38,48}
        elseif(c==1)
            truth={30,30.12,45}
            Variable/G $(path+":minDistance")=0.06
            Variable/G $(path+":detectSmoothDeg")=0.03
            Variable/G $(path+":autoSmoothFactor")=1
            Variable/G $(path+":detectMinWidth")=0.02
        else
            truth={26,35,52}
        endif
        for(mode=1;mode<=2;mode+=1)
            Variable/G $(path+":detectorMode")=mode
            result=XRD_Detect(path)
            hits=0
            for(i=0;i<3;i+=1)
                hits+=XRD_TestNearestError(path,truth[i])<=0.06
            endfor
            Print "CHALLENGE case="+num2istr(c)+" detector="+num2istr(mode)+" hits="+num2istr(hits)+"/3 extra="+num2istr(numpnts(peaks)-hits)
            XRD_TestCheck(result>=0,"challenge detector completes case "+num2istr(c)+" mode "+num2istr(mode))
            if(c==1)
                XRD_TestCheck(hits==3,"close-peak settings separate resolvable 0.12 degree pair mode "+num2istr(mode))
            endif
            Variable ordered=1
            for(i=1;i<numpnts(peaks);i+=1)
                ordered=ordered && peaks[i]>peaks[i-1]
            endfor
            XRD_TestCheck(ordered && WaveCRC(0,yy)==crc && WaveCRC(0,xx)==xcrc,"challenge output stays sorted and preserves source case "+num2istr(c)+" mode "+num2istr(mode))
        endfor
    endfor
    XRD_TestCheck(GetRTError(1)==0,"independent challenge cases leave no native runtime error")
    NVAR failures=root:XRDTestFailures
    Print "v0.7.0 challenge failures="+num2istr(failures)
End

Function XRD_RunV70UI(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    XRD_NewProject()
    String project=XRD_Project()
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_LoadReferenceFile("01_QS.txt",1)
    XRD_LoadReferenceFile("02_Y.txt",2)
    Make/FREE/D/N=4001 xx=20+0.01*p,yy=5+100*exp(-((xx[p]-30)/0.06)^2)+50*exp(-((xx[p]-40)/0.06)^2)
    String path=XRD_Store(xx,yy,"UI_check.xy")
    XRD_Manual(path,30)
    XRD_Manual(path,40)
    XRD_V70Adopt(path,0,1)
    XRD_V70Adopt(path,1,2)
    XRD_MaterialPanel()
    MoveWindow/W=XRDMaterials 10,10,650,430
    XRD_MaterialLayout()
    GetWindow XRDMaterials wsizeForControls
    Variable w=V_right,h=V_bottom
    ControlInfo/W=XRDMaterials materialApply
    XRD_TestCheck(V_left>=0 && V_left+V_width<=w && V_top+V_height<h,"material chooser apply button stays inside laptop-sized window")
    ControlInfo/W=XRDMaterials materials
    XRD_TestCheck(V_left+V_width<w && V_top+V_height<h-90,"material list scrolls within available space above buttons")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDMaterials as output+"material_small_v070.png"
    DoWindow/K XRDMaterials
    XRD_DetectionPanel()
    GetWindow XRDDetectionSettings wsizeForControls
    h=V_bottom
    ControlInfo/W=XRDDetectionSettings applyDetection
    XRD_TestCheck(V_top+V_height<h,"basic detector registration button stays inside compact window")
    Variable/G $(path+":detectionAdvanced")=1
    XRD_DetectionControls(path)
    ControlInfo/W=XRDDetectionSettings width
    XRD_TestCheck(V_disable==0,"advanced detector fields open without shrinking text")
    ControlInfo/W=XRDDetectionSettings prominence
    XRD_TestCheck(V_disable==1,"advanced detector page hides overlapping basic fields")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDDetectionSettings as output+"detector_advanced_v070.png"
    DoWindow/K XRDDetectionSettings
    NVAR step=$(project+":activeStep")
    step=2
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"reference_step_v070.png"
    step=3
    Variable/G $(project+":detailControls")=1
    XRD_ScoreCandidates(path,1)
    XRD_TestDisableFollow()
    XRD_Panel()
    ControlInfo/W=XRDWorkbench candidateMode
    XRD_TestCheck(V_disable==0,"adopted/new/all candidate filter remains available under advanced settings")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"match_details_v070.png"
    step=5
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"figure_step_v070.png"
    ControlInfo/W=XRDWorkbench legendOrder
    XRD_TestCheck(V_flag==1 && V_top>0,"completion screen exposes legend-order action")
    ControlInfo/W=XRDWorkbench moveUp
    Variable moveBottom=V_top+V_height
    ControlInfo/W=XRDWorkbench referenceStyle
    XRD_TestCheck(V_top>moveBottom,"sample-order buttons do not overlap common-style button")
    XRD_TestCheck(GetRTError(1)==0,"compact UI and advanced pages leave no native runtime error")
    NVAR failures=root:XRDTestFailures
    Print "v0.7.0 UI failures="+num2istr(failures)
End

Function XRD_RunV70External(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    XRD_NewProject()
    String project=XRD_Project()
    Make/FREE/D/N=4001 xx=20+0.01*p,yy=2+exp(-((xx[p]-30)/0.1)^2)+exp(-((xx[p]-40)/0.1)^2)+exp(-((xx[p]-50)/0.1)^2)
    String path=XRD_Store(xx,yy,"external_replace.xy")
    XRD_AddPoint(path,1000,"Auto")
    XRD_AddPoint(path,2000,"Auto")
    XRD_AddPoint(path,3000,"Auto")
    XRD_Manual(path,45)
    XRD_SetUnknown(path,1)
    Wave angles=$(path+":Peaks:angle"),ids=$(path+":Peaks:peakID"),raw=$(path+":Raw:intensity")
    Variable reviewed=ids[1],manual=ids[2],history=NumVarOrDefault(project+":Undo:sequence",0),crc=WaveCRC(0,raw),i,found=0
    XRD_TestCheck(XRD_ExternalPeaks(path,fixtures+"bad_peaks.csv",replaceAuto=1)==-2 && numpnts(angles)==4,"replace mode validates entire external file before removing Auto peaks")
    XRD_TestCheck(NumVarOrDefault(project+":Undo:sequence",0)==history,"invalid replacement leaves Undo history unchanged")
    XRD_TestCheck(XRD_ExternalPeaks(path,fixtures+"one_column.txt",replaceAuto=1)==2 && numpnts(angles)==4,"external replacement removes two unreviewed Auto and adds two input centers")
    for(i=0;i<numpnts(ids);i+=1)
        found+=(ids[i]==manual || ids[i]==reviewed)
    endfor
    XRD_TestCheck(found==2 && XRD_TestNearestError(path,40)<1e-9 && XRD_TestNearestError(path,45)<1e-9,"external replacement preserves manual and reviewed stable IDs")
    XRD_TestCheck(XRD_TestNearestError(path,30)>1 && XRD_TestNearestError(path,50)>1,"unreviewed automatic positions are replaced rather than retained")
    XRD_TestCheck(NumVarOrDefault(project+":Undo:sequence",0)==history+1,"external replacement consumes exactly one Undo action")
    XRD_TestCheck(cmpstr(StrVarOrDefault(path+":algorithm",""),"external-peak-list-v1")==0,"external replacement records its method and report")
    XRD_Undo()
    XRD_TestCheck(XRD_TestNearestError(path,30)<1e-9 && XRD_TestNearestError(path,50)<1e-9 && XRD_TestNearestError(path,48.321)>1,"Undo restores removed Auto and removes imported centers together")
    XRD_Redo()
    XRD_TestCheck(XRD_TestNearestError(path,48.321)<1e-9 && XRD_TestNearestError(path,58.123)<1e-9,"Redo restores original external precision")
    history=NumVarOrDefault(project+":Undo:sequence",0)
    Variable before=WaveCRC(0,ids)
    XRD_TestCheck(XRD_ExternalPeaks(path,fixtures+"outside_peaks.txt",replaceAuto=1)==0 && WaveCRC(0,ids)==before && NumVarOrDefault(project+":Undo:sequence",0)==history,"entirely out-of-range list cannot clear existing peaks")
    XRD_TestCheck(WaveCRC(0,raw)==crc && GetRTError(1)==0,"external replacement leaves Raw and native runtime state intact")
    NVAR failures=root:XRDTestFailures
    Print "v0.7.0 external replacement failures="+num2istr(failures)
End
