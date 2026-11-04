#pragma rtGlobals=3
#include ":xrd_v126_tests"
#include ":xrd_semantic120"
#include ":xrd_semantic127"
Function XRD_RunV127Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    String/G $(XRD100_Admin()+":backupFolder")=output
    String prefs=XRD127_Settings(),p1=XRD_Project(),a,b,c,ua,ub,uc
    XRD_TestCheck(XRD127_DefaultProminence()==5,"v127 fresh default prominence is five percent")
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=2+100*exp(-((xx[p]-25)/0.1)^2)+70*exp(-((xx[p]-27)/0.1)^2)+50*exp(-((xx[p]-29)/0.1)^2)
    a=XRD_Store(xx,yy,"ten.xy");ua=XRD80_MeasurementUID(a)
    XRD100_SetSample(a,"010","x=0.1","ten");a=XRD80_ResolveMeasurement(ua)
    b=XRD_Store(xx,yy,"two.xy");ub=XRD80_MeasurementUID(b)
    XRD100_SetSample(b,"002","x=0.2","two");b=XRD80_ResolveMeasurement(ub)
    c=XRD_Store(xx,yy,"one.xy");uc=XRD80_MeasurementUID(c)
    XRD100_SetSample(c,"001","x=0.3","one");c=XRD80_ResolveMeasurement(uc)
    String list=XRD127_MeasurementList(p1)
    XRD_TestCheck(cmpstr(StringFromList(0,list),"'001'")==0 && cmpstr(StringFromList(1,list),"'002'")==0 && cmpstr(StringFromList(2,list),"'010'")==0,"v127 chooser sorts entered serials numerically regardless of import order")
    XRD_TestCheck(cmpstr(XRD127_SerialKey("2",0),XRD127_SerialKey("10",0))<0 && cmpstr(XRD127_SerialKey("0002",0),XRD127_SerialKey("10",0))<0,"v127 unequal widths and leading zeros use numeric order")
    XRD_TestCheck(cmpstr(XRD127_SerialKey(PadString("9",200,0x39),0),XRD127_SerialKey(PadString("1",201,0x31),0))<0,"v127 huge serials sort without floating point conversion")
    String oldStack=XRD_MeasurementOrderList(p1)
    XRD127_MeasurementList(p1)
    XRD_TestCheck(cmpstr(oldStack,XRD_MeasurementOrderList(p1))==0,"v127 chooser sort preserves existing stack order")
    Variable/G $(a+":detectProminence")=0.5
    XRD_TestCheck(XRD127_SaveDefault(7.5)==0,"v127 configurable initial prominence accepts valid percent")
    XRD_EnsureMeasurement(a)
    XRD_TestCheck(NumVarOrDefault(a+":detectProminence",0)==0.5,"v127 changing defaults never rewrites an existing measurement")
    String later=XRD_Store(xx,yy,"later.xy")
    XRD_TestCheck(NumVarOrDefault(later+":detectProminence",0)==7.5,"v127 new measurement receives saved default")
    XRD_TestCheck(XRD127_SaveDefault(-1)<0 && XRD127_SaveDefault(101)<0 && XRD127_SaveDefault(NaN)<0 && XRD127_DefaultProminence()==7.5,"v127 invalid defaults leave saved value unchanged")
    XRD127_SaveDefault(5)
    XRD127_DefaultsPanel()
    String defaults="root:Packages:XRDWorkbench:UI:Defaults127"
    Variable/G $(defaults+":prominence")=12
    STRUCT WMButtonAction ba
    ba.eventCode=2;ba.ctrlName="cancel";XRD127_DefaultsButton(ba)
    XRD_TestCheck(XRD127_DefaultProminence()==5 && !WinType("XRDDefaults127"),"v127 cancelling default edits retains five percent")
    String/G $(p1+":activeData")=a
    Variable/G $(p1+":activeStep")=1
    XRD_Panel();XRD_DetectionPanel()
    ControlInfo/W=XRDDetectionSettings defaults127
    XRD_TestCheck(V_flag==1 && V_disable==0,"v127 detection settings expose future-measurement defaults")
    STRUCT WMPopupAction preset
    preset.eventCode=2;preset.popNum=2;XRD_DetectionPreset(preset)
    XRD_TestCheck(NumVarOrDefault(a+":detectProminence",0)==5,"v127 standard preset uses configured initial prominence")
    KillWindow/Z XRDDetectionSettings
    XRD110_RegisterPanel(a)
    String entry=XRD110_Entry()
    ControlInfo/W=XRDRegister110 number
    Variable numberY=V_top
    ControlInfo/W=XRDRegister110 composition
    Variable compositionY=V_top
    ControlInfo/W=XRDRegister110 label
    XRD_TestCheck(numberY<compositionY && compositionY<V_top,"v127 registration fields are serial composition display name")
    String/G $(entry+":composition")="x=0.6"
    STRUCT WMSetVariableAction sva
    sva.ctrlName="composition";sva.eventCode=-2;XRD110_EntryChanged(sva)
    XRD_TestCheck(cmpstr(StrVarOrDefault(entry+":label",""),"x=0.6")==0,"v127 composition blur fills display name")
    String/G $(entry+":label")="custom display"
    sva.ctrlName="label";sva.eventCode=1;XRD110_EntryChanged(sva)
    XRD_TestCheck(cmpstr(StrVarOrDefault(entry+":composition",""),"x=0.6")==0,"v127 manual display name does not alter composition")
    sva.ctrlName="composition";sva.eventCode=8;XRD110_EntryChanged(sva)
    XRD_TestCheck(cmpstr(StrVarOrDefault(entry+":label",""),"custom display")==0,"v127 merely focusing unchanged composition keeps custom display name")
    XRD_TestCheck(XRD110_CommitEntry()==0 && !WinType("XRDRegister110"),"v127 successful metadata registration closes floating entry panel")
    XRD_TestCheck(cmpstr(XRD80_ResolveMeasurement(ua),a)==0 && cmpstr(StrVarOrDefault(a+":displayName",""),"custom display")==0,"v127 registration retains stable measurement identity and custom label")
    Variable file
    Open file as output+"import127.xy"
    Variable i
    for(i=0;i<numpnts(xx);i+=1)
        fprintf file,"%.7g\t%.7g\r\n",xx[i],yy[i]
    endfor
    Close file
    Variable/G $(p1+":activeStep")=3
    XRD_Panel()
    XRD110_RegisterPanel("")
    String/G $(entry+":number")="000"
    String/G $(entry+":composition")="x=0"
    sva.ctrlName="composition";sva.eventCode=1;XRD110_EntryChanged(sva)
    String/G $(entry+":file")=output+"import127.xy"
    XRD_TestCheck(XRD110_CommitEntry()==0 && !WinType("XRDRegister110"),"v127 successful file addition closes registration panel")
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    Variable importMin127=V_min,importMax127=V_max
    GetAxis/W=XRDWorkbench#SideCompare/Q bottom
    XRD_TestCheck(abs(V_min-importMin127)<1e-8 && abs(V_max-importMax127)<1e-8 && V_max>V_min,"v127 successful import keeps comparison and measured X ranges aligned")
    String imported=XRD_Data(),importUID=XRD80_MeasurementUID(imported)
    XRD_TestCheck(cmpstr(StrVarOrDefault(imported+":sampleNumber",""),"000")==0 && cmpstr(StrVarOrDefault(imported+":displayName",""),"x=0")==0 && NumVarOrDefault(imported+":detectProminence",0)==5,"v127 zero-padded serial composition name and five percent survive import")
    XRD_TestCheck(cmpstr(StringFromList(0,XRD127_MeasurementList(p1)),"'000'")==0,"v127 newly imported smaller serial appears first")
    String/G $(p1+":activeData")=a
    XRD_NewProject();String p2=XRD_Project(),u2=XRD80_ProjectUID(p2)
    XRD_NewProject();String p3=XRD_Project(),u3=XRD80_ProjectUID(p3)
    String u1=XRD80_ProjectUID(p1)
    XRD_TestCheck(XRD127_MoveProject(p3,-1)==1 && XRD127_MoveProject(p3,-1)==0,"v127 projects move upward independently of folder creation order")
    XRD_TestCheck(cmpstr(StringFromList(0,XRD_ProjectList()),p3)==0 && cmpstr(StringFromList(1,XRD_ProjectList()),p1)==0,"v127 project list uses saved stable UID order")
    XRD_TestCheck(XRD127_MoveProject(p3,-1)<0 && cmpstr(StringFromList(0,XRD_ProjectList()),p3)==0,"v127 first project cannot move above list boundary")
    String/G root:Packages:XRDWorkbench:activeProject=p1
    XRD110_Manager()
    String manager="root:Packages:XRDWorkbench:UI:Manager"
    String/G $(manager+":reorderUID127")=u3
    Variable/G $(manager+":direction127")=1
    XRD127_ProjectOrderDeferred()
    XRD_TestCheck(cmpstr(StringFromList(1,XRD_ProjectList()),p3)==0 && cmpstr(XRD100_ManagerProject(),p3)==0,"v127 manager reorder retains selected project")
    XRD_TestCheck(XRD100_RenameProject(p3,"order renamed")==0,"v127 project can be renamed after reordering")
    p3=XRD100_ProjectByUID(u3)
    XRD_TestCheck(cmpstr(StringFromList(1,XRD_ProjectList()),p3)==0,"v127 project order survives physical rename by stable UID")
    Variable/G $(p3+":projectDeleted100")=1
    XRD_TestCheck(WhichListItem(p3,XRD_ProjectList())<0,"v127 deleted projects remain hidden in ordered list")
    Variable/G $(p3+":projectDeleted100")=0
    XRD_TestCheck(cmpstr(StringFromList(1,XRD_ProjectList()),p3)==0,"v127 restored visibility retains saved order")
    Variable before=ItemsInList(XRD_ProjectList())
    XRD_TestCheck(XRD127_CreateProject(XRD_ProjectDisplayName(p1))<0 && XRD127_CreateProject("\"quoted\"")<0 && ItemsInList(XRD_ProjectList())==before,"v127 duplicate or quoted new project names never overwrite data")
    XRD127_NewProjectPanel()
    ControlInfo/W=XRDNewProject127 name
    XRD_TestCheck(V_flag==5 && cmpstr(StrVarOrDefault("root:Packages:XRDWorkbench:UI:NewProject127:name","invalid"),"")==0,"v127 project addition uses blank plain text control")
    ba.ctrlName="cancel";XRD127_NewProjectButton(ba)
    XRD_TestCheck(!WinType("XRDNewProject127") && ItemsInList(XRD_ProjectList())==before,"v127 cancelling plain project form creates nothing")
    XRD127_NewProjectPanel()
    String/G root:Packages:XRDWorkbench:UI:NewProject127:name="native plain name"
    XRD127_CreateProjectDeferred()
    XRD_TestCheck(!WinType("XRDNewProject127") && cmpstr(XRD_ProjectDisplayName(XRD_Project()),"native plain name")==0 && ItemsInList(XRD_ProjectList())==before+1,"v127 plain text project creation succeeds and closes its form")
    ControlInfo/W=XRDWorkbench measurementLabel
    XRD_TestCheck(strsearch(S_recreation,"測定データ未登録",0)>=0,"v127 empty project header explains the next import step")
    ControlInfo/W=XRDWorkbench detectorSettings
    Variable emptyDisabled127=V_disable==2
    ControlInfo/W=XRDWorkbench pointAdd
    XRD_TestCheck(emptyDisabled127 && V_disable==2,"v127 empty project disables unavailable peak actions with explicit labels")
    String/G root:Packages:XRDWorkbench:activeProject=p1
    String/G $(p1+":activeData")=a
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_LoadReferenceFile("phase1.txt",1)
    XRD_Manual(a,25);XRD_Manual(a,27);XRD_Manual(a,29)
    XRD80_TestAdopt(a,0,1,0);XRD_SetUnknown(a,2)
    Variable/G $(a+":selectedPeakRow")=0
    Variable/G $(p1+":activeStep")=3
    XRD_Panel()
    Wave ids=$(a+":Peaks:peakID"),raw=$(a+":Raw:intensity"),aid=$(a+":Assignments:peakID"),refs=$(a+":Assignments:refIndex")
    Variable crc=WaveCRC(0,raw),idCRC=WaveCRC(0,ids)
    XRD_TestCheck(XRD127_FindUnknown(a,1)==1,"v127 next unexplained peak skips assigned peaks")
    XRD_TestCheck(XRD127_GotoUnknown(1)==1 && NumVarOrDefault(a+":selectedPeakID100",-1)==ids[1],"v127 unexplained navigation selects stable measured peak ID")
    XRD_TestCheck(XRD127_FindUnknown(a,-1)==2,"v127 previous unexplained peak wraps across assigned peak")
    XRD_TestCheck(XRD_RunMatchAction(14)==2 && XRD_RunMatchAction(15)==1,"v127 other actions menu navigates both directions")
    Duplicate/FREE aid,beforeAid
    Duplicate/FREE refs,beforeRefs
    Redimension/N=4 aid,refs
    aid[0]=ids[0];refs[0]=1;aid[1]=ids[1];refs[1]=0;aid[2]=ids[1];refs[2]=1;aid[3]=ids[2];refs[3]=1
    XRD_TestCheck(XRD127_FindUnknown(a,1)==-1,"v127 an assigned overlap with an Unknown row is still identified")
    Duplicate/O beforeAid,$(a+":Assignments:peakID")
    Duplicate/O beforeRefs,$(a+":Assignments:refIndex")
    XRD_TestCheck(WaveCRC(0,raw)==crc && WaveCRC(0,ids)==idCRC,"v127 navigation never changes measured data or peak IDs")
    NewDataFolder/O root:DumpProbe127
    Make/O/D/N=(3,2) root:DumpProbe127:values=p+q*0.1
    Make/O/T/N=3 root:DumpProbe127:text={"a%", "line\tbreak", "試料µ"}
    Wave values=root:DumpProbe127:values
    Note values,"metadata %\t試料"
    SetScale/P x,12,0.25,"deg",values
    SetDimLabel 1,0,'日本語',values
    Open file as output+"semantic_old.tsv"
    XRD120_DumpFolder("root:DumpProbe127",file);Close file
    Open file as output+"semantic_new.tsv"
    XRD127_DumpFolder("root:DumpProbe127",file);Close file
    String expectedProjects=""
    list=XRD_ProjectList()
    for(i=0;i<ItemsInList(list);i+=1)
        expectedProjects+=XRD80_ProjectUID(StringFromList(i,list))+";"
    endfor
    String/G root:XRD127ExpectedProjects=expectedProjects
    String/G root:XRD127ExpectedMeasurement=ua
    String/G root:XRD127ExpectedImport=importUID
    XRD_TestCheck(GetRTError(1)==0,"v127 runtime clean")
    Print "V127_FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End

Function XRD127_ReopenCheck()
    Variable/G root:XRDTestFailures=0
    SVAR expected=root:XRD127ExpectedProjects,uid=root:XRD127ExpectedMeasurement,importUID=root:XRD127ExpectedImport
    String list=XRD_ProjectList(),actual="",path=XRD80_ResolveMeasurement(uid),imported=XRD80_ResolveMeasurement(importUID)
    Variable i
    for(i=0;i<ItemsInList(list);i+=1)
        actual+=XRD80_ProjectUID(StringFromList(i,list))+";"
    endfor
    XRD_TestCheck(cmpstr(actual,expected)==0,"v127 fresh process retains reordered renamed projects")
    XRD_TestCheck(XRD127_DefaultProminence()==5,"v127 five percent initial value persists")
    XRD_TestCheck(strlen(path)>0 && strlen(imported)>0 && cmpstr(StrVarOrDefault(imported+":sampleNumber",""),"000")==0,"v127 saved registration and measurement UIDs resolve")
    XRD_TestCheck(cmpstr(StrVarOrDefault(path+":displayName",""),"custom display")==0 && cmpstr(StrVarOrDefault(path+":composition",""),"x=0.6")==0,"v127 composition and custom display name persist separately")
    String sorted=XRD127_MeasurementList(XRD80_ProjectForMeasurement(imported))
    XRD_TestCheck(cmpstr(StringFromList(0,sorted),"'000'")==0,"v127 serial order persists after native save and restart")
    XRD_TestCheck(GetRTError(1)==0,"v127 reopened runtime clean")
    Print "V127_REOPEN_FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End
