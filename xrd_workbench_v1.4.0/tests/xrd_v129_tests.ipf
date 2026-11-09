#pragma rtGlobals=3
#include ":xrd_v120_tests"
Function XRD_RunV129Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    NewPath/O/Q XRDReferencePath,fixtures
    Variable i
    String labels="M-type;Y-type;U-type;Z-type;spinel;SnO₂;BaSn₁.₇₀Fe₂.₇₅O₈.₅₂",path,uid,recipe,win,ui=XRD_PlotRoot()+":UI"
    for(i=1;i<=7;i+=1)
        XRD_LoadReferenceFile("phase"+num2istr(i)+".txt",i)
        String/G $(XRD_ReferencePath(i)+":styleGroup")=StringFromList(i-1,labels)
    endfor
    Make/FREE/D/N=1001 xx=20+0.05*p,yy=2
    for(i=0;i<7;i+=1)
        yy+=100*exp(-((xx[p]-(25+2*i))/0.1)^2)
    endfor
    path=XRD_Store(xx,yy,"first.xy");uid=XRD80_MeasurementUID(path)
    for(i=0;i<7;i+=1)
        XRD_Manual(path,25+2*i)
        XRD80_TestAdopt(path,i,i+1,0)
    endfor
    XRD100_SetSample(path,"003","x=0","x=0");path=XRD80_ResolveMeasurement(uid)
    XRD_PlotDefaults()
    XRD_TestCheck(abs(NumVarOrDefault(ui+":width",0)-16*72/2.54)<0.001 && abs(NumVarOrDefault(ui+":height",0)-12*72/2.54)<0.001,"v129 fresh defaults are 16x12 cm")
    Variable/G $(ui+":width")=500
    XRD_PlotDefaults()
    XRD_TestCheck(NumVarOrDefault(ui+":width",0)==500,"v129 user draft dimensions survive repeated default initialization")
    Variable/G $(ui+":width")=16*72/2.54
    XRD_PlotQuickCreate(path+";","XRD legend v1.2.9")
    recipe=StrVarOrDefault(ui+":recipe","");win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    XRD129_CheckFigure(win)
    String traces=TraceNameList(win,";",1),key="",legendTraces=""
    XRD_TestCheck(WhichListItem("int_M_type_003",traces)>=0 && WhichListItem("int_spinel_003",traces)>=0,"v129 aliases follow manual identification example")
    XRD_TestCheck(XRD110_LegendItems(win,key,legendTraces)==7,"v129 seven phases remain in one legend")
    String info=AnnotationInfo(win,"Phases",1),text=info[strsearch(info,"TEXT:",0)+5,inf]
    XRD_TestCheck(ItemsInList(text,"\r")==4 && ItemsInList(StringFromList(0,text,"\r"),"\t")==2,"v129 two columns have four rows")
    XRD_TestCheck(ItemsInList(text,"\\F'")==2 && ItemsInList(text,"\\Z")==2 && strsearch(text,"\\B",0)<0 && strsearch(text,"\\M",0)<0,"v129 only one common font prefix and editable Unicode labels")
    XRD_TestCheck(strsearch(text,"\\s(int_M_type_003) M-type",0)>=0 && strsearch(text,"SnO₂",0)>=0,"v129 simple trace symbols and chemical labels retained")
    XRD_TestCheck(XRD110_LegendWidth("BaSn₁.₇₀Fe₂.₇₅O₈.₅₂",24)<strlen("BaSn₁.₇₀Fe₂.₇₅O₈.₅₂")*24*0.72,"v129 Unicode width no longer uses byte-count floor")
    XRD_EnableFigureResize(win,flexible=1)
    XRD_TestCheck(cmpstr(GetUserData(win,"","XRDFlexible"),"1")==0,"v129 explicit drag action still enables flexible mode")
    XRD_PlotLegend(win)
    XRD_TestCheck(strsearch(WinRecreation(win,0),"width=",0)<0,"v129 flexible mode remains Auto after legend layout")
    XRD_EnableFigureResize(win)
    ModifyGraph/W=$win width=16*72/2.54,height=12*72/2.54
    SavePICT/O/E=-5/SNAP=1/WIN=$win as output+"legend_compact.png"
    String/G root:V129Recipe=recipe
    String/G root:V129Path=path
    XRD_PlotWorkspace();XRD_PlotLoadRecipe(recipe)
    XRD_TestCheck(XRD81_ApplyPlotLive(recipe)==0,"v129 existing plot update succeeds with readable aliases")
    XRD_TestCheck(ItemsInList(TraceNameList(win,";",1))==8,"v129 update removes old phase aliases without duplicate traces")
    XRD129_CheckFigure(win)
    TextBox/W=$win/C/N=Phases "\\s(int_M_type_003) my edited M-type"
    String manual=XRD_FigureLegendSignature(win)
    XRD_PlotCaptureNative(recipe)
    XRD_RefreshStyles()
    XRD_TestCheck(cmpstr(manual,XRD_FigureLegendSignature(win))==0,"v129 palette refresh preserves manual legend edits")
    XRD_PlotDrawRecipe(recipe,1)
    XRD_TestCheck(cmpstr(manual,XRD_FigureLegendSignature(win))==0,"v129 native redisplay preserves manual legend edits")
    String/G root:V129Manual=manual
    SaveExperiment/C/F={1,"",0} as output+"saved129.pxp"
    Print "V129 FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End

Function XRD129_CheckFigure(win)
    String win
    GetWindow $win psize
    XRD_TestCheck(abs(V_right-V_left-16*72/2.54)<0.75 && abs(V_bottom-V_top-12*72/2.54)<0.75,"v129 plot rectangle remains 16x12 cm")
    String macro=WinRecreation(win,0)
    XRD_TestCheck(strsearch(macro,"width=453.54",0)>=0 && strsearch(macro,"height=340.1",0)>=0,"v129 width and height stay Absolute")
End

Function XRD_V129Reopen()
    Variable/G root:XRDTestFailures=0
    String recipe=StrVarOrDefault("root:V129Recipe",""),win="XRDP_"+StrVarOrDefault(recipe+":plotUID","")
    XRD129_CheckFigure(win)
    XRD_TestCheck(cmpstr(StrVarOrDefault("root:V129Manual",""),XRD_FigureLegendSignature(win))==0,"v129 actual restart retains edited legend")
    XRD_TestCheck(WhichListItem("int_M_type_003",TraceNameList(win,";",1))>=0,"v129 actual restart resolves simple trace alias")
    String path=StrVarOrDefault("root:V129Path","")
    Wave refs=$(path+":Assignments:refIndex"),raw=$(path+":Raw:intensity")
    XRD_TestCheck(numpnts(refs)==7 && numpnts(raw)==1001,"v129 actual restart retains assignments and raw data")
    Print "V129 REOPEN FAILURES",NumVarOrDefault("root:XRDTestFailures",-1)
End
