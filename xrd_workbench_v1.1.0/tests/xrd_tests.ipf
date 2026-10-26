#pragma rtGlobals=3
// Runtime checks for XRD Workbench v0.4.0. Use an empty test experiment.
#include ":xrd_v42_tests"
#include ":xrd_v43_tests"
#include ":xrd_v44_tests"
#include ":xrd_v45_tests"

Function XRD_TestCheck(condition,label)
    Variable condition
    String label
    NVAR failures=root:XRDTestFailures
    SVAR/Z liveLog=root:XRDLiveTestFile
    if(SVAR_Exists(liveLog))
        Variable file
        Open/A/Z=2 file as liveLog
        if(V_flag==0)
            fprintf file,"%d %s\r\n",condition,label
            Close file
        endif
    endif
    if(condition)
        Print "PASS: "+label
    else
        Print "FAIL: "+label
        failures+=1
    endif
End

Function XRD_VerifyRestored()
    String project=XRD_Project(),path=XRD_Data(),rp=XRD_ReferencePath(1)
    NVAR failures=root:XRDTestFailures
    failures=0
    SVAR phaseName=$(rp+":phaseName")
    XRD_TestCheck(cmpstr(phaseName,"Renamed M-type")==0,"saved reference name restored")
    Wave values=$(XRD80_Styles()+":values")
    Variable style=XRD_StyleIndex(1)
    XRD_TestCheck(values[style][0]==5 && values[style][3]==65535,"saved native symbol and color restored")
    Wave px=$(path+":Peaks:angle"),ay=$(path+":Assignments:peakID")
    XRD_TestCheck(numpnts(px)==7 && numpnts(ay)==6,"saved peaks and reviewed assignments restored")
    Wave raw=$(path+":Raw:intensity"),yy=$(path+":Processed:intensity")
    WaveStats/Q yy
    XRD_TestCheck(abs(V_max-100)<1e-9 && raw[0]!=yy[0],"saved raw and normalized data restored")
    NVAR aa=$(path+":Lattice:a"),cc=$(path+":Lattice:c"),lambda=$(path+":Lattice:wavelength")
    XRD_TestCheck(abs(aa-5.89)<1e-6 && abs(cc-23.2)<1e-6 && lambda==1.5406,"saved lattice result and wavelength restored")
    XRD_TestDisableFollow()
    XRD_Panel()
    XRD_RefreshStyles()
    XRD_TestCheck(WinType("XRDWorkbench")!=0,"restored project reopens workbench")
    Print "XRD roundtrip tests: failures="+num2istr(failures)
    return failures
End

Function XRD_RunTests(samplesPath)
    String samplesPath
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_NewProject()
    String project=XRD_Project()
    NewPath/O/Q XRDReferencePath,samplesPath
    Variable loaded=XRD_LoadReferences()
    NVAR referenceCount=$(project+":referenceCount"),referenceErrors=$(project+":referenceErrorCount")
    XRD_TestCheck(loaded==2 && referenceCount==2 && referenceErrors==4,"参照フォルダ: 有効2件、無効TXT1件と測定CSV3件を診断")

    NVAR filterMode=$(project+":elementFilterMode")
    SVAR allowed=$(project+":allowedElements")
    filterMode=1
    allowed="Fe;O"
    XRD_TestCheck(XRD_FormulaCompatible("Fe3 O4","")==1,"元素フィルター: Fe/Oを許可")
    XRD_TestCheck(XRD_FormulaCompatible("Ba2 Me2 Fe12 O22","Y-type")==1,"元素フィルター: Y-type例外を保持")
    filterMode=0

    Make/FREE/D/N=1001 xx,yy
    xx=15+0.05*p
    yy=5+8*exp(-((xx[p]-18.27)/0.10)^2)+30*exp(-((xx[p]-30.095)/0.12)^2)+100*exp(-((xx[p]-35.423)/0.13)^2)+8*exp(-((xx[p]-37.053)/0.11)^2)+20*exp(-((xx[p]-43.053)/0.14)^2)+10*exp(-((xx[p]-53.392)/0.12)^2)+30*exp(-((xx[p]-56.944)/0.16)^2)+40*exp(-((xx[p]-62.516)/0.16)^2)
    String first=XRD_Store(xx,yy,"synthetic_fe3o4.csv")
    NVAR threshold=$(first+":threshold")
    threshold=5
    XRD_TestCheck(XRD_DetectLegacy(first)==0,"ピーク検出を実行")
    Wave peakX=$(first+":Peaks:angle")
    XRD_TestCheck(numpnts(peakX)>=6,"主要ピークを検出")

    Variable row=0,i
    for(i=1;i<numpnts(peakX);i+=1)
        if(abs(peakX[i]-35.423)<abs(peakX[row]-35.423))
            row=i
        endif
    endfor
    Variable candidateCount=XRD_ScoreCandidates(first,row)
    XRD_TestCheck(candidateCount>=2,"重なり得る候補を複数提示")
    Wave candidateRefs=$(first+":Candidates:refIndex"),candidateTotals=$(first+":Candidates:totalScore")
    Print "Candidate order: ref="+num2istr(candidateRefs[0])+" score="+num2str(candidateTotals[0])+", ref="+num2istr(candidateRefs[1])+" score="+num2str(candidateTotals[1])
    XRD_TestCheck(candidateRefs[0]==1 && candidateTotals[0]>=candidateTotals[1],"Fe3O4候補を上位表示")
    Wave previewX=$(first+":Preview:angle")
    XRD_TestCheck(numpnts(previewX)>0,"選択候補の全域参照棒を生成")

    XRD_TestCheck(XRD_AssignCandidate(first,row,0,0)==0,"候補で置換同定")
    Wave assignID=$(first+":Assignments:peakID"),assignRef=$(first+":Assignments:refIndex")
    XRD_TestCheck(numpnts(assignID)==1,"置換同定は1件")
    XRD_ScoreCandidates(first,row)
    Variable otherCandidate=-1,firstRef=assignRef[0]
    for(i=0;i<numpnts(candidateRefs);i+=1)
        if(candidateRefs[i]!=firstRef)
            otherCandidate=i
            break
        endif
    endfor
    XRD_TestCheck(otherCandidate>=0 && XRD_AssignCandidate(first,row,otherCandidate,1)==0,"重なり候補を追加")
    XRD_TestCheck(numpnts(assignID)==2,"同一ピークへ2相を保持")
    XRD_TestCheck(XRD_SetUnknown(first,row)==0 && numpnts(assignID)==1,"Unknownへ後から変更")

    for(i=0;i<numpnts(peakX);i+=1)
        XRD_SetUnknown(first,i)
    endfor
    XRD_TestCheck(XRD_SetMeasurementComplete(first)==0,"全ピーク確認後に同定完了")

    Duplicate/FREE yy,yy2
    yy2=0.8*yy[p]+2
    String second=XRD_Store(xx,yy2,"synthetic_second.csv")
    XRD_DetectLegacy(second)
    Wave secondAssignments=$(second+":Assignments:peakID")
    XRD_TestCheck(cmpstr(first,second)!=0 && numpnts(secondAssignments)==0,"測定ごとに同定状態を分離")
    Wave secondPeakX=$(second+":Peaks:angle")
    for(i=0;i<numpnts(secondPeakX);i+=1)
        XRD_SetUnknown(second,i)
    endfor
    XRD_TestCheck(XRD_SetMeasurementComplete(second)==0,"2件目も個別に同定完了")
    XRD_TestCheck(XRD_CompletedMeasurementCount()==2,"完了測定数を集計")
    XRD_TestCheck(XRD_MoveMeasurement(second,-1)==1 && cmpstr(StringFromList(0,XRD_MeasurementOrderList(project)),"Data2")==0,"比較図の試料順序を変更")
    XRD_MoveMeasurement(second,1)

    XRD_TestCheck(XRD_CreateEditableGraph()==0 && WinType("XRDAnalysisGraph")==1,"標準Igor編集グラフを作成")
    XRD_TestCheck(XRD_CreateStackGraph()==0 && WinType("XRDStackGraph")==1,"2測定の縦積みグラフを作成")
    XRD_TestCheck(XRD_Panel()==0 && WinType("XRDWorkbench")!=0,"日本語メインパネルを作成")

    NVAR failures=root:XRDTestFailures
    Print "XRD baseline runtime tests: failures="+num2istr(failures)
    return failures
End

Function XRD_RunV3Tests(samplesPath,outputPath)
    String samplesPath,outputPath
    XRD_RunTests(samplesPath)
    String project=XRD_Project(),path=XRD_Data(),rp=XRD_ReferencePath(1)
    Wave raw=$(path+":Raw:intensity"),normalized=$(path+":Processed:intensity"),angles=$(path+":Peaks:angle"),ids=$(path+":Peaks:peakID")
    WaveStats/Q normalized
    XRD_TestCheck(abs(V_min)<1e-9 && abs(V_max-100)<1e-9,"import normalization 0..100")
    XRD_TestCheck(raw[0]!=normalized[0],"raw intensity remains unchanged")
    Wave/T table=$(path+":Peaks:table")
    XRD_TestCheck(cmpstr(GetDimLabel(table,1,0),"2theta (deg)")==0 && str2num(table[0][0])<str2num(table[1][0]),"peak table angle-first ascending")
    NVAR filter=$(project+":elementFilterMode"),step=$(project+":activeStep"),full=$(project+":tablesOnly")
    filter=2
    XRD_UpgradeProject(project)
    XRD_TestCheck(filter==2,"element filter setting survives refresh")
    filter=0
    SVAR phaseName=$(rp+":phaseName")
    phaseName="Renamed M-type"
    Variable countBefore=numpnts(ids)
    XRD_LoadReferences()
    XRD_TestCheck(cmpstr(phaseName,"Renamed M-type")==0 && numpnts(ids)==countBefore,"reference reload preserves names and measurements")

    NVAR selected=$(path+":selectedPeakRow"),candidate=$(path+":selectedCandidateRow")
    selected=2
    XRD_ScoreCandidates(path,selected)
    candidate=0
    step=3
    XRD_ApplySelectedCandidate(path,0)
    XRD_TestCheck(selected==3,"replace and adopt advances to next peak")
    Wave py=$(path+":Peaks:height")
    XRD_CreateEditableGraph()
    String single=WinName(0,1),trace,stack
    Wave/T keys=$(XRD80_Styles()+":keys")
    SVAR group=$(rp+":styleGroup")
    group="M-type"
    Variable style=XRD_StyleIndex(1)
    Wave values=$(XRD80_Styles()+":values")
    values[style][0]=5
    values[style][1]=0
    values[style][2]=20000
    values[style][3]=65535
    XRD_RefreshStyles()
    trace="Data2_Phase1"
    Wave/Z singleY=TraceNameToWaveRef(single,trace)
    XRD_TestCheck(WaveExists(singleY),"native assigned phase trace in single graph")
    Variable originalY=singleY[0]
    XRD_CreateStackGraph()
    stack=WinName(0,1)
    XRD_TestCheck(singleY[0]==originalY,"stack creation leaves single graph marker positions unchanged")
    Wave/Z stackY=TraceNameToWaveRef(stack,trace)
    XRD_TestCheck(abs(stackY[0]-originalY)<1e-8,"stack markers follow reversed display order: last table row has zero offset")
    XRD_TestCheck(strsearch(TraceInfo(single,trace,0),"marker(x)=5",0)>=0,"project marker selection propagated")
    SavePICT/O/E=-5/WIN=$single as outputPath+"single.png"
    SavePICT/O/E=-5/WIN=$stack as outputPath+"stack.png"

    XRD_TestDisableFollow()
    XRD_Panel()
    full=1
    XRD_TableLayout(project)
    ControlInfo/W=XRDWorkbench peakList
    Print "Expanded table width="+num2str(V_width)+" height="+num2str(V_height)
    Variable expandedWidth=V_width
    GetWindow XRDWorkbench wsizeForControls
    XRD_TestCheck(abs(expandedWidth-(V_right-min(320*str2num(GetUserData("XRDWorkbench","","XRDUIScale")),V_right*0.35)-30*str2num(GetUserData("XRDWorkbench","","XRDUIScale"))))<2,"expanded peak table uses right content width beside comparison")
    XRD_StylePanel()
    XRD_TestCheck(WinType("XRDStyles")!=0,"native marker and color selectors open")
    PopupMenu symbol,win=XRDStyles,mode=6
    PopupMenu color,win=XRDStyles,popColor=(0,20000,65535)
    STRUCT WMButtonAction styleButton
    styleButton.eventCode=2
    XRD_ApplyStyleButton(styleButton)
    XRD_TestCheck(values[style][0]==5 && values[style][3]==65535,"marker/color apply button stores native selectors")
    XRD_OpenPicker()
    Cursor/P/W=XRDPeakPicker A Measurement 150
    STRUCT WMButtonAction button
    button.eventCode=2
    XRD_PickerButton(button)
    XRD_TestCheck(numpnts(angles)==countBefore+1,"cursor registers manual peak at exact sample")
    NVAR manualAngle=$(path+":manualAngle")
    XRD_TestCheck(abs(manualAngle-22.5)<1e-8,"cursor angle matches x wave")
    Variable manualRow=BinarySearch(angles,22.5)
    XRD_Delete(path,manualRow)
    XRD_TestCheck(numpnts(angles)==countBefore,"manual peak can be removed")
    XRD_Delete(path,2)
    Wave assignIDs=$(path+":Assignments:peakID")
    XRD_TestCheck(numpnts(angles)==countBefore-1 && numpnts(assignIDs)==countBefore-1,"auto peak deletion also removes its assignment")

    // A synthetic hexagonal cell: fit must recover independent known a and c.
    NewDataFolder/O $(path+":Lattice")
    Make/O/D/N=(8,6) $(path+":Lattice:inputs")
    Wave input=$(path+":Lattice:inputs")
    Make/FREE/D hh={1,0,1,1,2,2,0,2},kk={0,0,1,0,0,1,0,0},ll={0,2,0,2,1,0,4,3}
    NVAR wavelength=$(project+":wavelength")
    Variable aa=5.89,cc=23.2
    input[][0]=1
    input[][1]=360/pi*asin(wavelength/2*sqrt(4*(hh[p]^2+hh[p]*kk[p]+kk[p]^2)/(3*aa^2)+ll[p]^2/cc^2))
    input[][2]=hh[p]
    input[][3]=kk[p]
    input[][4]=ll[p]
    String previous=GetDataFolder(1)
    Variable fit=XRD_FitHexagonal(path)
    NVAR fitA=$(path+":Lattice:a"),fitC=$(path+":Lattice:c")
    Print "Fit result="+num2str(fit)+" a="+num2str(fitA)+" c="+num2str(fitC)
    Wave fitCoef=$(path+":Lattice:W_coef")
    Print fitCoef
    XRD_TestCheck(fit==0 && abs(fitA-aa)<1e-6 && abs(fitC-cc)<1e-6,"Igor CurveFit recovers synthetic hexagonal a/c")
    XRD_TestCheck(cmpstr(previous,GetDataFolder(1))==0,"CurveFit restores current data folder")
    XRD_ClearPeakReview(path,0)
    SVAR state=$(path+":Lattice:state")
    XRD_TestCheck(strsearch(state,"再計算",0)>=0,"assignment changes invalidate lattice fit")

    // Exercise every tab, then export the identification views.
    Variable i
    for(i=1;i<=5;i+=1)
        step=i
        XRD_TestDisableFollow()
    XRD_Panel()
    endfor
    step=3
    full=0
    selected=0
    XRD_ScoreCandidates(path,0)
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as outputPath+"workbench.png"
    full=1
    XRD_TableLayout(project)
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as outputPath+"tables.png"
    XRD_TestCheck(WinType("XRDWorkbench")!=0,"all five workflow tabs render")
    Make/FREE/D/N=101 wheelX=20+p*0.1,wheelY=2+sin(p/10)
    String wheelPath=XRD_Store(wheelX,wheelY,"wheel-test.csv")
    for(i=1;i<100;i+=1)
        XRD_AddPoint(wheelPath,i,"Manual")
    endfor
    step=1
    XRD_TestDisableFollow()
    XRD_Panel()
    ControlInfo/W=XRDWorkbench peakList
    STRUCT WMWinHookStruct wheelEvent
    wheelEvent.eventCode=22
    wheelEvent.winName="XRDWorkbench"
    wheelEvent.mouseLoc.h=V_left+5
    wheelEvent.mouseLoc.v=V_top+20
    wheelEvent.wheelDy=-5
    XRD_PanelHook(wheelEvent)
    ControlInfo/W=XRDWorkbench peakList
    XRD_TestCheck(V_startRow>0,"mouse-wheel event scrolls peak table")
    String oldProject=project
    XRD_NewProject()
    Wave/T newKeys=$(XRD80_Styles()+":keys")
    XRD_TestCheck(numpnts(newKeys)==0,"style settings are isolated by project")
    SVAR active=root:Packages:XRDWorkbench:activeProject
    active=oldProject
    SVAR activeData=$(oldProject+":activeData")
    activeData=path
    step=3
    full=0
    XRD_TestDisableFollow()
    XRD_Panel()
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.3.0 runtime tests: failures="+num2istr(failures)
    return failures
End

Function XRD_RunV4Tests(samplesPath,outputPath)
    String samplesPath,outputPath
    XRD_RunV3Tests(samplesPath,outputPath)
    String project=XRD_Project(),path=XRD_Data(),first=project+":Measurements:Data1",rp=XRD_ReferencePath(1),previous,list
    NVAR step=$(project+":activeStep"),filter=$(project+":elementFilterMode"),full=$(project+":tablesOnly")
    SVAR allowed=$(project+":allowedElements"),active=$(project+":activeData"),hint=$(project+":referenceFolderHint")
    XRD_TestCheck(cmpstr(XRD_FormulaLabel("Cu Fe O2"),"CuFeO₂")==0,"formula label uses subscripts")
    XRD_TestCheck(cmpstr(XRD_FormulaLabel("Fe +2 Fe2 +3 O4"),"Fe²⁺Fe₂³⁺O₄")==0,"formula charge notation retained")
    XRD_TestCheck(cmpstr(XRD_TypeName("Zn QS-type CrystalDiffract"),"QS-type")==0,"type label recognized in descriptive name")
    filter=1
    allowed="Fe;O;"
    XRD_TestCheck(XRD_FormulaCompatible("CuFeO2","")==0,"fixed Cu phase excluded without Cu")
    XRD_TestCheck(XRD_FormulaCompatible("Fe3O4","")==1,"allowed fixed formula retained")
    String types="Z-type;X-type;M-type;QS-type;W-type;T-type;Y-type;U-type"
    Variable i,allProtected=1
    for(i=0;i<8;i+=1)
        allProtected*=XRD_FormulaCompatible("Ba2Cu2Fe12O22",StringFromList(i,types))
    endfor
    XRD_TestCheck(allProtected,"all eight substitution type families bypass filter")
    XRD_TestCheck(XRD_FormulaCompatible("Ba2Me2Fe12O22","")==1,"unknown composition retained conservatively")
    XRD_ElementPanel()
    XRD_TestCheck(ItemsInList(ControlNameList("XRDElements",";","el*"))==118,"periodic UI contains all 118 element buttons")
    STRUCT WMButtonAction element
    element.eventCode=2
    element.ctrlName="elCu"
    XRD_ElementButton(element)
    XRD_TestCheck(WhichListItem("Cu",allowed)>=0,"periodic button adds selected element")
    XRD_TestCheck(XRD_FormulaCompatible("CuFeO2","")==1,"Cu phase returns when Cu selected")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDElements as outputPath+"periodic.png"
    element.ctrlName="apply"
    XRD_ElementButton(element)
    XRD_TestCheck(WinType("XRDElements")==0,"periodic apply updates candidates and closes chooser")
    filter=0

    step=1
    full=0
    XRD_TestDisableFollow()
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 29,32
    SetAxis/W=XRDWorkbench#Pattern left -1,40
    NVAR angle=$(path+":manualAngle")
    angle=31.5
    STRUCT WMButtonAction add
    add.eventCode=2
    add.ctrlName="addPeak"
    XRD_Button(add)
    DoUpdate
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-29)<1e-8 && abs(V_max-32)<1e-8,"manual add preserves zoomed angle range")
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(abs(V_min+1)<1e-8 && abs(V_max-40)<1e-8,"manual add preserves zoomed intensity range")
    active=first
    XRD_TestDisableFollow()
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 40,45
    active=path
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-29)<1e-8 && abs(V_max-32)<1e-8,"measurement switch restores its own zoom")
    XRD_ResetView()
    DoUpdate
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-15)<1e-8 && abs(V_max-65)<1e-8,"explicit reset returns entire measurement range")

    Wave fids=$(first+":Peaks:peakID"),pids=$(path+":Peaks:peakID")
    Wave frefs=$(first+":Assignments:refIndex"),faids=$(first+":Assignments:peakID"),frows=$(first+":Assignments:refPeakIndex")
    Wave prefs=$(path+":Assignments:refIndex"),paids=$(path+":Assignments:peakID"),prows=$(path+":Assignments:refPeakIndex")
    Redimension/N=4 frefs,faids,frows
    frefs=1;faids=fids[p];frows=p
    Redimension/N=3 prefs,paids,prows
    prefs=1;paids=pids[p];prows=p
    list=XRD_LatticeChoices(first)
    Wave fm=$(first+":Lattice:phaseMap"),fc=$(first+":Lattice:phaseCounts")
    list=XRD_LatticeChoices(path)
    Wave pm=$(path+":Lattice:phaseMap"),pc=$(path+":Lattice:phaseCounts")
    XRD_TestCheck(fc[0]==4 && pc[0]==3 && numpnts(pm)==1,"lattice counts separate: first 4 peaks, second 3")
    XRD_TestCheck(strsearch(list,"1:",0)==0 && pm[0]==1,"phase list ordinal starts at one and maps reference")
    XRD_PrepareLattice(path,1)
    Wave input=$(path+":Lattice:inputs")
    XRD_TestCheck(DimSize(input,0)==3,"lattice input uses only selected measurement")

    // Independent synthetic cubic reflections, known a=4.195 A and slope=0.0004.
    Redimension/N=(8,6) input
    Make/FREE/D hh={1,2,2,3,2,4,3,4},kk={1,0,2,1,2,0,3,2},ll={1,0,0,1,2,0,1,0}
    Make/FREE/D angles={37.1329435377461,43.13447520307,62.6185413764812,75.0722278070662,79.0371080335616,94.5599559479282,106.363273354446,110.434062856159}
    input[][0]=1;input[][1]=angles[p];input[][2]=hh[p];input[][3]=kk[p];input[][4]=ll[p]
    previous=GetDataFolder(1)
    Variable result=XRD_FitCubic(path)
    NVAR aa=$(path+":Lattice:a"),sa=$(path+":Lattice:aSigma")
    Wave coef=$(path+":Lattice:W_coef")
    XRD_TestCheck(result==0 && abs(aa-4.195)<1e-6 && abs(coef[1]-0.0004)<1e-9,"cubic CurveFit recovers known a and nonzero slope")
    XRD_TestCheck(numtype(sa)==0 && sa>=0 && cmpstr(previous,GetDataFolder(1))==0,"cubic uncertainty saved and working folder restored")
    input[0][0]=0;input[1][0]=0;input[2][0]=0;input[3][0]=0;input[4][0]=0;input[5][0]=0
    XRD_TestCheck(XRD_FitCubic(path)==-1,"cubic fit rejects fewer than three peaks")
    input[][0]=1
    XRD_FitCubic(path)
    hint=samplesPath
    KillPath/Z XRDReferencePath
    XRD_TestCheck(XRD_RestoreReferencePath(project)==0,"saved reference folder restores symbolic path")
    PathInfo XRDReferencePath
    XRD_TestCheck(V_flag==1 && cmpstr(S_path,samplesPath)==0,"restored folder is the original selection")
    XRD_RebuildReferenceTable(project)
    Wave/T rt=$(project+":References:table")
    XRD_TestCheck(cmpstr(rt[0][0],"M-type")==0 && cmpstr(GetDimLabel(rt,1,3),"Name")==0,"type-first reference table retains English name on right")

    // Legacy per-card marker is copied during formula-group migration.
    String rp2=XRD_ReferencePath(2)
    SVAR card2=$(rp2+":cardNumber")
    String/G $(rp2+":phaseClass")=""
    String/G $(rp2+":phaseName")="Magnesium Aluminum Oxide"
    String/G $(rp2+":formula")="MgAl2O4"
    String/G $(rp2+":typeOverride")="通常相"
    String/G $(rp2+":styleGroup")=card2
    Wave/T keys=$(XRD80_Styles()+":keys")
    Wave values=$(XRD80_Styles()+":values")
    Variable n=numpnts(keys)
    Redimension/N=(n+1) keys
    Redimension/N=(n+1,4) values
    keys[n]=card2;values[n][0]=8;values[n][1]=12345;values[n][2]=23456;values[n][3]=34567
    Variable migrated=XRD_StyleIndex(2)
    XRD_TestCheck(values[migrated][0]==8 && values[migrated][1]==12345,"legacy marker and color retained during migration")
    String/G $(first+":conditionLabel")="1200°C in air"
    String/G $(path+":conditionLabel")="x = 1"
    String/G $(first+":status")="同定完了"
    String/G $(path+":status")="同定完了"
    NVAR hide=$(project+":Measurements:Data3:visibleInStack")
    hide=0
    XRD_CreateStackGraph()
    String win=WinName(0,1)
    DoUpdate
    GetAxis/W=$win/Q left
    XRD_TestCheck(V_max==260,"two sample graph has 30 gap and 30 top headroom")
    String annotation=AnnotationInfo(win,"Condition2",0)
    XRD_TestCheck(strlen(annotation)>0,"editable condition textbox exists for each measurement")
    SavePICT/O/E=-5/WIN=$win as outputPath+"stack.png"
    XRD_CreateEditableGraph()
    win=WinName(0,1)
    SavePICT/O/E=-5/WIN=$win as outputPath+"single.png"
    step=1
    XRD_TestDisableFollow()
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 29,32
    XRD_CaptureView()
    filter=1
    allowed="Fe;O;Cu;"
    // Store all state for a second isolated Igor process to reload.
    SaveExperiment as outputPath+"roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.0 runtime tests: failures="+num2istr(failures)
    return failures
End

Function XRD_RunV41Tests(samplesPath,outputPath,fixturesPath)
    String samplesPath,outputPath,fixturesPath
    XRD_RunV4Tests(samplesPath,outputPath)
    XRD_NewProject()
    String project=XRD_Project(),rp,path,types="Z;X;M;QS;W;T;Y;U",token
    Variable i,ok=1,row,r,g,b
    for(i=0;i<8;i+=1)
        token=StringFromList(i,types)
        ok*=cmpstr(XRD_TypeName(token+"_type test.txt"),token+"-type")==0
        ok*=cmpstr(XRD_TypeName(LowerStr(token)+"type"),token+"-type")==0
    endfor
    XRD_TestCheck(ok,"eight families accept underscore, case and joined type names")
    NewPath/O/Q XRDReferencePath,fixturesPath
    XRD_TestCheck(XRD_LoadReferences()==4,"metadata-free Greek-theta legacy references load")
    String expected="CuFeO₂;W-type;X-type;Y-type"
    for(i=1;i<=4;i+=1)
        XRD_TestCheck(cmpstr(XRD_PhaseLabel(i),StringFromList(i-1,expected))==0,"legacy phase label "+num2istr(i))
        row=XRD_StyleIndex(i)
        Wave vals=$(XRD80_Styles()+":values")
        XRD_TestCheck(WhichListItem(num2istr(vals[row][0]),"19;16;17;18;23")>=0,"automatic marker is filled "+num2istr(i))
        XRD_TestCheck(max(vals[row][1],max(vals[row][2],vals[row][3]))<=55000,"automatic color is dark "+num2istr(i))
    endfor
    rp=XRD_ReferencePath(1)
    String/G $(rp+":source")="QS-type-folder/ordinary.pdf"
    XRD_TestCheck(strlen(XRD_ReferenceType(1))==0,"parent folder does not misclassify ordinary card")
    XRD_TestCheck(cmpstr(XRD_FormulaFamily("Ba2 Cu2 Fe12 O22"),"Y-type")==0 && cmpstr(XRD_FormulaFamily("BaFe18O27"),"W-type")==0,"composition fallback recognizes verified Y and W")
    NVAR filter=$(project+":elementFilterMode"),refSelection=$(project+":selectedReference")
    SVAR allowed=$(project+":allowedElements")
    filter=1;allowed="Fe;O;"
    XRD_TestCheck(XRD_FormulaCompatible("CuFeO2",XRD_ReferenceType(1))==0 && XRD_FormulaCompatible("Ba2Cu2Fe12O22",XRD_ReferenceType(4))==1,"ordinary Cu excluded while named Y retained")
    XRD_TestCheck(XRD_ImportFile(fixturesPath+"measurement.xy")==0,"XY file imports")
    path=XRD_Data()
    Wave raw=$(path+":Raw:intensity"),yy=$(path+":Processed:intensity")
    XRD_TestCheck(raw[2]==250 && yy[2]==100,"XY raw preserved and display normalized")
    XRD_DetectLegacy(path)
    XRD_TestDisableFollow()
    XRD_Panel()
    SetAxis/W=XRDWorkbench#Pattern bottom 29.5,32.5
    NVAR selected=$(path+":selectedPeakRow")
    selected=0
    XRD_SelectedPeakGuide(path)
    DrawAction/W=XRDWorkbench#Pattern/L=UserBack getgroup=XRDSelectedPeak
    XRD_TestCheck(V_flag!=0,"selected peak black guide group exists")
    XRD_SelectedPeakGuide(path)
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(V_min==29.5 && V_max==32.5,"guide refresh preserves zoom")
    STRUCT WMListboxAction lba
    lba.eventCode=4;lba.row=1
    XRD_PeakListAction(lba)
    XRD_TestCheck(str2num(GetUserData("XRDWorkbench#Pattern","","XRDSelectedAngle"))==34,"list selection moves guide to new peak")
    lba.row=0
    XRD_PeakListAction(lba)
    XRD_ElementPanel()
    SetWindow XRDElements userdata(TestPersistent)="yes"
    STRUCT WMButtonAction ba
    ba.eventCode=2;ba.ctrlName="elCu"
    XRD_ElementButton(ba)
    XRD_TestCheck(cmpstr(GetUserData("XRDElements","","TestPersistent"),"yes")==0,"element click does not recreate window")
    XRD_TestCheck(WhichListItem("Cu",allowed)>=0,"element selected immediately")
    XRD_ElementButton(ba)
    XRD_TestCheck(WhichListItem("Cu",allowed)<0,"repeated click deselects element")
    ba.ctrlName="apply"
    XRD_ElementButton(ba)
    XRD_TestCheck(strsearch(StrVarOrDefault(path+":candidateFilterKey",""),"1:"+allowed+":",0)==0,"filter refresh stamps current measurement cache")
    filter=0
    XRD_ScoreCandidates(path,0)
    XRD_V70Adopt(path,0,1)
    XRD_V70Adopt(path,1,4)
    refSelection=0
    XRD_StylePanel()
    ControlInfo/W=XRDStyles target
    XRD_TestCheck(V_Value==1 && strsearch(S_Value,"CuFeO",0)>=0,"style reference dropdown populated")
    PopupMenu symbol,win=XRDStyles,mode=18
    PopupMenu color,win=XRDStyles,popColor=(12345,23456,34567)
    STRUCT WMPopupAction pa
    pa.eventCode=2;pa.popNum=2;pa.popStr="Y-type"
    XRD_StyleTargetAction(pa)
    row=XRD_StyleIndex(1)
    XRD_TestCheck(refSelection==3 && vals[row][0]==17 && vals[row][1]==12345,"dropdown switches reference and saves previous native style")
    pa.popStr="通常相"
    XRD_StyleTypeAction(pa)
    XRD_TestCheck(strlen(XRD_ReferenceType(4))==0,"explicit ordinary override disables inferred type")
    pa.popStr="Y-type"
    XRD_StyleTypeAction(pa)
    XRD_TestCheck(cmpstr(XRD_ReferenceType(4),"Y-type")==0,"explicit type restores family")
    vals[1][0]=20
    XRD_PhaseColor(2,r,g,b)
    vals[1][1]=r;vals[1][2]=g;vals[1][3]=b
    XRD_RepairAutoStyles(project)
    XRD_TestCheck(vals[1][0]==16 && vals[1][2]==0.75*g,"legacy automatic slash migrates to filled square")
    XRD_TestCheck(vals[0][0]==17 && vals[0][1]==12345,"migration preserves manually chosen style")
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDStyles as outputPath+"styles_v041.png"
    DoWindow/K XRDStyles
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as outputPath+"workbench_v041.png"
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.1 runtime tests: failures="+num2istr(failures)
    return failures
End

Function XRD_VerifyV4Restored()
    Variable/G root:XRDTestFailures=0
    String project=XRD_Project(),path=XRD_Data()
    NVAR aa=$(path+":Lattice:a"),filter=$(project+":elementFilterMode")
    SVAR crystal=$(path+":Lattice:crystalSystem"),allowed=$(project+":allowedElements"),hint=$(project+":referenceFolderHint"),condition=$(path+":conditionLabel")
    XRD_TestCheck(abs(aa-4.195)<1e-6 && cmpstr(crystal,"立方晶")==0,"cubic result and crystal system survive save/reload")
    XRD_TestCheck(filter==1 && WhichListItem("Cu",allowed)>=0,"periodic selection survives save/reload")
    XRD_TestCheck(cmpstr(condition,"x = 1")==0,"measurement condition text survives save/reload")
    XRD_TestCheck(XRD_RestoreReferencePath(project)==0,"reference folder reusable after reopening experiment")
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    XRD_TestCheck(abs(V_min-29)<1e-8 && abs(V_max-32)<1e-8,"measurement zoom survives save/reload")
    Wave values=$(XRD80_Styles()+":values")
    Variable row=XRD_StyleIndex(1)
    XRD_TestCheck(values[row][0]==5 && values[row][3]==65535,"project marker and color survive save/reload")
    Wave pc=$(path+":Lattice:phaseCounts")
    XRD_TestCheck(pc[0]==3,"measurement-specific phase count survives save/reload")
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.0 roundtrip tests: failures="+num2istr(failures)
    return failures
End

Function XRD_V4FigurePreview(outputPath)
    String outputPath
    String project=XRD_Project(),path=XRD_Data(),first=project+":Measurements:Data1",rp=XRD_ReferencePath(1),rp2=XRD_ReferencePath(2),name,win
    SVAR pname=$(rp+":phaseName"),pclass=$(rp+":phaseClass"),group=$(rp+":styleGroup")
    SVAR pname2=$(rp2+":phaseName"),pclass2=$(rp2+":phaseClass"),group2=$(rp2+":styleGroup")
    pname="M-type";pclass="M-type";group="M-type"
    pname2="Z-type";pclass2="Z-type";group2="Z-type"
    Variable r=XRD_StyleIndex(1),r2=XRD_StyleIndex(2),i,j
    Wave values=$(XRD80_Styles()+":values")
    values[r][0]=19;values[r][1]=0;values[r][2]=0;values[r][3]=50000
    values[r2][0]=23;values[r2][1]=55000;values[r2][2]=0;values[r2][3]=0
    Wave xx=$(first+":Raw:twoTheta"),yy=$(first+":Raw:intensity")
    for(i=0;i<3;i+=1)
        name=XRD_Store(xx,yy,"preview.csv")
        XRD_DetectLegacy(name)
        String/G $(name+":conditionLabel")=num2istr(1100+i*50)+"°C"
    endfor
    String list=XRD_MeasurementOrderList(project)
    for(i=0;i<ItemsInList(list);i+=1)
        name=project+":Measurements:"+StringFromList(i,list)
        if(cmpstr(StringFromList(i,list),"Data3")==0)
            continue
        endif
        Wave ids=$(name+":Peaks:peakID"),refs=$(name+":Assignments:refIndex"),aid=$(name+":Assignments:peakID"),rows=$(name+":Assignments:refPeakIndex")
        Redimension/N=(numpnts(ids)) refs,aid,rows
        refs=1+mod(p,2);aid=ids[p];rows=0
        String/G $(name+":status")="同定完了"
    endfor
    XRD_CreateStackGraph()
    win=WinName(0,1)
    DoUpdate
    GetAxis/W=$win/Q left
    XRD_TestCheck(V_max==650,"five sample graph reserves top headroom")
    XRD_TestCheck(strlen(AnnotationInfo(win,"Condition5",0))>0,"five sample graph includes fifth condition label")
    Print "Five sample graph settings: "+WinRecreation(win,0)
    SavePICT/O/E=-5/WIN=$win as outputPath+"stack_five.png"
    XRD_CreateEditableGraph()
    win=WinName(0,1)
    SavePICT/O/E=-5/WIN=$win as outputPath+"single_types.png"
    XRD_ElementPanel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=XRDElements as outputPath+"periodic.png"
    NVAR failures=root:XRDTestFailures
    Print "XRD figure tests: failures="+num2istr(failures)
End
#include ":xrd_v50_tests"
#include ":xrd_v51_tests"
#include ":xrd_v52_tests"

#include ":xrd_v53_tests"
#include ":xrd_v60_tests"

#include ":xrd_v70_tests"

Function XRD_TestDisableFollow()
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project)
    Variable i
    for(i=0;i<ItemsInList(list);i+=1)
        Variable/G $(project+":Measurements:"+StringFromList(i,list)+":followPeak")=0
    endfor
End
#include ":xrd_v71_tests"
#include ":xrd_v72_tests"
