#pragma rtGlobals=3

Function HMH_TestReferenceDefaults(output)
    String output
    HMH_TestSetup(4)
    Wave/T names=root:MHApp:names,list=root:MHApp:listText
    Variable i
    String labels="x = -0.1;x = 0;x = -0.1 遊星ミル;x = 0 遊星ミル"
    for(i=0;i<4;i+=1)
        names[i]=StringFromList(i,labels);list[i][1]=names[i]
        Wave y=$("root:MHApp:Demo"+num2istr(i)+":M_emu_g")
        y*=0.65
    endfor
    Wave raw=root:MHApp:Demo0:M_emu_g
    Variable checksum=sum(raw)
    HMH_TestCheck(HMH_DrawGraph(-1)==4,"comparison uses new default format without opening settings")
    SVAR win=root:MHApp:lastGraph
    GetAxis/Q/W=$win bottom
    HMH_TestCheck(V_min==-15 && V_max==15,"default X limits exactly -15 to 15")
    GetAxis/Q/W=$win left
    HMH_TestCheck(V_min==-40 && V_max==40,"default Y limits exactly -40 to 40")
    HMH_TestCheck(cmpstr(HMH_AxisSetting(win,"bottom","manTick"),"{0,5,0,0}")==0,"default X ticks every 5 with integer labels")
    HMH_TestCheck(cmpstr(HMH_AxisSetting(win,"left","manTick"),"{0,20,0,0}")==0,"default Y ticks every 20 with integer labels")
    HMH_TestCheck(cmpstr(HMH_AxisSetting(win,"bottom","manMinor"),"{0,0}")==0,"default has no minor ticks")
    HMH_TestCheck(NumVarOrDefault("root:MHApp:Figure:lineWidth",0)==2.5,"new figure defaults use 2.5 pt curves")
    String japanese=HMH_JapaneseLegendFont()
    String formatted=HMH_LegendLabel("x = -0.1 遊星ミル")
    HMH_TestCheck(strsearch(formatted,"\\F'"+japanese+"'遊星ミル",0)>=0,"Japanese legend uses an installed Mincho font")
    HMH_TestCheck(cmpstr(HMH_LegendLabel("Fe\\B2\\MO\\B3\\M 1200°C"),"Fe\\B2\\MO\\B3\\M 1200°C")==0,"Latin, degree symbol and subscript escapes preserved")
    HMH_TestCheck(cmpstr(HMH_LegendLabel("\\F'Arial'手動指定"),"\\F'Arial'手動指定")==0,"explicit user font commands respected")
    HMH_TestLegendBounds(win,2)
    HMH_TestCheck(sum(raw)==checksum,"new default style does not alter data")
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as output+"mh_reference_default_demo.png"
    NVAR lw=root:MHApp:Figure:lineWidth
    lw=3.75
    String firstGraph=win
    HMH_DrawGraph(0)
    HMH_TestCheck(lw==3.75,"existing user line width preference preserved")
    DoWindow/F $firstGraph
    HMH_TestCheck(HMH_ReferenceLast()==0,"one action restores reference appearance on an existing graph")
    HMH_TestCheck(cmpstr(win,firstGraph)==0,"reference action targets the selected MH graph")
    HMH_TestCheck(lw==2.5,"explicit reference action becomes next graph defaults")
    HMH_NewGraphAxes(win,-25.1,25.2,-91,92)
    GetAxis/Q/W=$win bottom
    HMH_TestCheck(V_min<=-25.1 && V_max>=25.2,"large magnetic field ranges remain visible")
    GetAxis/Q/W=$win left
    HMH_TestCheck(V_min<=-91 && V_max>=92,"large magnetization ranges remain visible")
    HMH_TestCheck(HMH_NewGraphAxes(win,-15,15,0,0)==0,"zero signal still receives a usable range")
    HMH_TestCheck(GetRTError(1)==0,"new default style leaves no runtime error")
End

Function HMH_TestMatchedReal(listPath,output)
    String listPath,output
    Variable refNum,i=0
    String line
    Open/R refNum as listPath
    do
        FReadLine refNum,line
        if(!strlen(line))
            break
        endif
        line=ReplaceString("\r",ReplaceString("\n",line,""),"")
        HMH_TestCheck(HMH_Import(line)==0,"matching real VSM "+num2istr(i+1)+" imports")
        i+=1
    while(1)
    Close refNum
    HMH_TestCheck(i==4,"all four 1100C N2 measurements loaded")
    Wave/T names=root:MHApp:names,list=root:MHApp:listText,paths=root:MHApp:paths
    Wave state=root:MHApp:listState
    String labels="x = -0.1;x = 0;x = -0.1 遊星ミル;x = 0 遊星ミル"
    for(i=0;i<4;i+=1)
        names[i]=StringFromList(i,labels);list[i][1]=names[i];state[i][0]=48
    endfor
    Wave x=$(paths[1]+"H_kOe"),y=$(paths[3]+"M_emu_g")
    Variable xMax=WaveMax(x),yMax=WaveMax(y),points=numpnts(x)
    HMH_TestCheck(HMH_DrawGraph(-1)==4,"matching four real curves draw in the reference style automatically")
    SVAR win=root:MHApp:lastGraph
    GetAxis/Q/W=$win bottom
    HMH_TestCheck(V_min==-15 && V_max==15,"nominal real X limits are -15 to 15")
    GetAxis/Q/W=$win left
    HMH_TestCheck(V_min==-40 && V_max==40,"real Y limits are -40 to 40")
    HMH_TestCheck(cmpstr(HMH_AxisSetting(win,"bottom","manTick"),"{0,5,0,0}")==0,"real X labels include every 5 kOe")
    HMH_TestCheck(cmpstr(HMH_AxisSetting(win,"left","manTick"),"{0,20,0,0}")==0,"real Y labels include every 20 emu/g")
    HMH_TestCheck(numpnts(x)==points && WaveMax(x)==xMax && xMax>15,"instrument overshoot retained in source waves")
    HMH_TestCheck(WaveMax(y)==yMax && abs(yMax-36.393981481481475)<1e-9,"real magnetization is unchanged")
    HMH_TestLegendBounds(win,2)
    GetWindow $win psize
    HMH_TestCheck(abs((V_right-V_left)-4/3*(V_bottom-V_top))<1,"real plot retains 4:3 aspect")
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as output+"mh_1100_n2_reference_default.png"
    HMH_TestCheck(GetRTError(1)==0,"matching real data draw without runtime error")
End

Function HMH_TestCheck(ok,label)
    Variable ok
    String label
    if(ok)
        Print "PASS: "+label
    else
        Print "FAIL: "+label
    endif
End

Function HMH_TestAxes(output)
    String output
    HMH_TestSetup(4)
    // Synthetic preview loops fit the requested +/-30 demonstration range.
    Variable k
    for(k=0;k<4;k+=1)
        Wave demo=$("root:MHApp:Demo"+num2istr(k)+":M_emu_g")
        demo*=0.4
    endfor
    HMH_DrawGraph(-1)
    SVAR win=root:MHApp:lastGraph
    SetAxis/W=$win bottom -15,15
    SetAxis/W=$win left -30,30
    ModifyGraph/W=$win manTick(bottom)={0,5,0,2},manTick(left)={0,20,0,2},manMinor={0,0}
    HMH_AxisDialog()
    NVAR xd=root:MHApp:Axes:xDigits,yd=root:MHApp:Axes:yDigits
    NVAR xs=root:MHApp:Axes:xStep,ys=root:MHApp:Axes:yStep
    HMH_TestCheck(xd==2 && yd==2 && xs==5 && ys==20,"axis editor reads legacy decimal digits and intervals")
    Wave y=root:MHApp:Demo0:M_emu_g
    Variable checksum=sum(y)
    String originalLegend=StringByKey("TEXT",AnnotationInfo(win,"HMHLegend1",1))
    Legend/W=$win/C/N=HMHLegend1 "Custom legend text"
    String legendBefore=StringByKey("TEXT",AnnotationInfo(win,"HMHLegend1",1))
    STRUCT WMButtonAction action
    action.eventCode=2;action.ctrlName="integers"
    HMH_AxisButton(action)
    HMH_TestCheck(xd==0 && yd==0,"integer shortcut sets both decimal controls")
    ys=10
    action.ctrlName="applyAxes"
    HMH_AxisButton(action)
    HMH_TestCheck(cmpstr(HMH_AxisSetting(win,"bottom","manTick"),"{0,5,0,0}")==0,"UI apply renders integer X labels")
    HMH_TestCheck(cmpstr(HMH_AxisSetting(win,"left","manTick"),"{0,10,0,0}")==0,"UI apply renders integer Y labels with chosen interval")
    HMH_TestCheck(WinType("HMH_AxisSettings")==7,"axis editor remains open after applying")
    HMH_TestCheck(cmpstr(legendBefore,StringByKey("TEXT",AnnotationInfo(win,"HMHLegend1",1)))==0,"axis edits preserve manually edited legend")
    HMH_TestCheck(sum(y)==checksum,"axis edits preserve measurement data")
    Legend/W=$win/C/N=HMHLegend1 originalLegend
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as output+"mh_axis_integers.png"
    SavePICT/O/E=-5/SNAP=1/WIN=HMH_AxisSettings as output+"mh_axes_settings.png"
    HMH_TestCheck(HMH_ApplyAxes(win,-1.5,1.5,0.5,4,-1,-0.3,0.3,0.1,3,-1)==0,"automatic digits support fractional intervals")
    HMH_TestCheck(cmpstr(HMH_AxisSetting(win,"bottom","manTick"),"{0,0.5,0,1}")==0,"0.5 interval uses one decimal automatically")
    HMH_TestCheck(cmpstr(HMH_AxisSetting(win,"left","manTick"),"{0,0.1,0,1}")==0,"0.1 interval uses one decimal automatically")
    HMH_ReadAxes(win)
    NVAR xm=root:MHApp:Axes:xMinor,ym=root:MHApp:Axes:yMinor
    HMH_TestCheck(xm==4 && ym==3 && xd==-1 && yd==-1,"reopening retains minor tick counts and automatic decimal selection")
    String before=WinRecreation(win,0)
    HMH_TestCheck(HMH_ApplyAxes(win,-15,15,0,0,0,-30,30,10,0,0)<0,"reject zero tick interval")
    HMH_TestCheck(HMH_ApplyAxes(win,-15,15,0.25,0,0,-30,30,10,0,0)<0,"reject insufficient decimals causing repeated tick labels")
    HMH_TestCheck(cmpstr(before,WinRecreation(win,0))==0,"invalid axis settings leave graph unchanged")
    HMH_ApplyAxes(win,-15,15,5,0,2,-30,30,10,0,2)
    HMH_ReadAxes(win)
    HMH_AxisSuggest()
    HMH_TestCheck(xs>=10,"spacing suggestion accounts for two-decimal label width")
    HMH_TestCheck(HMH_ApplyAxes(win,-15,15,xs,0,2,-30,30,ys,0,2)==0,"two-decimal display supported with wider interval")
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as output+"mh_axis_two_decimals.png"
    GetWindow $win psize
    HMH_TestCheck(abs((V_right-V_left)-4/3*(V_bottom-V_top))<1.5,"axis margin adjustment preserves plot aspect")
    HMH_Layout(win,2,16.5,1.1,24,24,2,2)
    HMH_TestCheck(HMH_ApplyAxes(win,-15,15,10,0,2,-30,30,10,0,2)==0,"decimal labels supported in whole canvas mode")
    GetWindow $win gsize
    HMH_TestCheck(abs((V_right-V_left)-1.1*(V_bottom-V_top))<1.5,"axis margin adjustment preserves whole canvas aspect")
    HMH_TestCheck(HMH_AxisDigits(0.25)==2 && HMH_AxisDigits(0.001)==3,"automatic precision covers common fractional intervals")
    HMH_TestCheck(GetRTError(1)==0,"axis UI and formatting leave no runtime error")
End

Function HMH_TestSetup(n)
    Variable n
    String testWins=HMH_FigureList(),testWin
    Variable testI
    for(testI=0;testI<ItemsInList(testWins);testI+=1)
        testWin=StringFromList(testI,testWins)
        DoWindow/K $testWin
    endfor
    KillDataFolder/Z root:MHApp:Manager
    HMH_Init()
    NVAR count=root:MHApp:count
    count=n
    Wave/T paths=root:MHApp:paths,names=root:MHApp:names,listText=root:MHApp:listText
    Wave listState=root:MHApp:listState
    Redimension/N=(n) paths,names
    Redimension/N=(n,2) listText,listState
    String labels="900°C pre;milled;1100°C;1200°C;1250°C;1300°C"
    Variable i
    for(i=0;i<n;i+=1)
        String rp="root:MHApp:Demo"+num2istr(i)
        NewDataFolder/O $rp
        Make/O/D/N=602 $(rp+":H_kOe"),$(rp+":M_emu_g")
        Wave x=$(rp+":H_kOe"),y=$(rp+":M_emu_g")
        x=p<301 ? -15+0.1*p : 15-0.1*(p-301)
        y=(44+i*2)*tanh((x+(p<301 ? -1 : 1)*(1.1-0.12*i))/(2-0.1*i))+0.2*x
        paths[i]=rp+":"
        names[i]="Sample "+num2istr(i+1)
        if(i<6)
            names[i]=StringFromList(i,labels)
        endif
        listText[i][0]="比較"
        listText[i][1]=names[i]
        listState[i][0]=48
        listState[i][1]=6
    endfor
End

Function HMH_TestRun(output)
    String output
    HMH_TestSetup(6)
    HMH_TestCheck(HMH_DrawGraph(-1)==6,"six checked samples displayed")
    SVAR win=root:MHApp:lastGraph
    GetWindow $win psize
    HMH_TestCheck(abs((V_right-V_left)-4/3*(V_bottom-V_top))<=1,"plot ratio 4:3 within one screen point of rounding")
    HMH_TestLegendBounds(win,2)
    String recreation=WinRecreation(win,0)
    HMH_TestCheck(strsearch(recreation,"Times New Roman",0)>=0 && strsearch(recreation,"gfSize=24",0)>=0,"24 pt Times New Roman in native graph")
    HMH_TestCheck(strsearch(recreation,"width=340.157,height=255.118",0)>=0,"physical plot dimensions 12 x 9 cm")
    HMH_TestCheck(strsearch(recreation,"zero=1",0)>=0 && strsearch(recreation,"mirror=1",0)>=0,"native zero lines and mirrored axes")
    String info=AnnotationInfo(win,"HMHLegend1",1)
    HMH_TestCheck(strsearch(info,"900°C pre",0)>=0 && strsearch(info,"1100°C",0)>=0,"legend row order matches sample list")
    SetAxis/W=$win bottom -15,15
    SetAxis/W=$win left -80,80
    ModifyGraph/W=$win manTick(bottom)={0,5,0,0},manTick(left)={0,40,0,0},manminor={0,0}
    // Preview uses synthetic loops; experimental data are never fabricated.
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as output+"mh_plot_ratio.png"
    HMH_TestCheck(HMH_Layout(win,2,16.5,1.1,24,24,2,2)==0,"whole canvas mode applies")
    GetWindow $win gsize
    HMH_TestCheck(abs((V_right-V_left)-1.1*(V_bottom-V_top))<72/ScreenResolution*2.1,"whole canvas ratio within screen pixel rounding")
    HMH_TestCheck(abs(str2num(GetUserData(win,"","HMHCanvasWidth"))-1.1*str2num(GetUserData(win,"","HMHCanvasHeight")))<0.02,"physical canvas dimensions retain ratio 1.1")
    HMH_TestLegendBounds(win,2)
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as output+"mh_canvas_ratio.png"
    HMH_FigurePanel()
    DoUpdate
    SavePICT/O/E=-5/SNAP=1/WIN=HMH_FigureSettings as output+"mh_settings.png"
    STRUCT WMPopupAction action
    action.eventCode=2; action.ctrlName="targetMode"; action.popNum=1
    GetWindow $win psize
    Variable expectedWidth=(V_right-V_left)*2.54/72
    HMH_LayoutChoice(action)
    HMH_TestCheck(abs(NumVarOrDefault("root:MHApp:Figure:widthCM",0)-expectedWidth)<1e-9,"switching to plot mode reads actual plot width")
    action.popNum=2
    HMH_LayoutChoice(action)
    HMH_TestCheck(abs(NumVarOrDefault("root:MHApp:Figure:widthCM",0)-16.5)<0.02,"switching to canvas mode reads actual canvas width")
    SetAxis/W=$win bottom -5,5
    SetAxis/W=$win left -20,20
    Wave y=root:MHApp:Demo0:M_emu_g
    Variable checksum=sum(y),first=y[0],points=numpnts(y)
    HMH_TestCheck(HMH_Layout(win,1,16,1.5,28,24,3,2.5)==0,"independent plot ratio, fonts and three columns")
    GetAxis/Q/W=$win bottom
    HMH_TestCheck(V_min==-5 && V_max==5,"layout preserves horizontal zoom")
    GetAxis/Q/W=$win left
    HMH_TestCheck(V_min==-20 && V_max==20,"layout preserves vertical zoom")
    HMH_TestLegendBounds(win,3)
    HMH_TestCheck(sum(y)==checksum && y[0]==first && numpnts(y)==points,"formatting preserves measurement waves")
    String before=WinRecreation(win,0)
    HMH_TestCheck(HMH_Layout(win,2,6,4,24,24,3,2)<0,"reject impossible whole-canvas geometry")
    HMH_TestCheck(cmpstr(before,WinRecreation(win,0))==0,"rejected layout does not change target graph")
    HMH_TestCheck(HMH_Layout(win,1,NaN,1,24,24,2,2)<0,"reject nonfinite size")
    HMH_TestCheck(HMH_Layout(win,1,12,1,24,24,1.5,2)<0,"reject fractional legend columns")
    HMH_ReadLayout(win)
    HMH_TestCheck(NumVarOrDefault("root:MHApp:Figure:ratio",0)==1.5,"read per-figure saved settings")
    NVAR ratio=root:MHApp:Figure:ratio
    ratio=4/3
    HMH_ApplyDefaults(win)
    HMH_ReadLayout(win)
    HMH_TestCheck(abs(ratio-4/3)<1e-10,"ratio metadata retains numeric precision")
    ModifyGraph/W=$win expand=0.6
    DoUpdate/W=$win
    GetWindow $win psize
    Variable physicalWidth=V_right-V_left,physicalHeight=V_bottom-V_top
    HMH_FitFigure(win)
    GetWindow $win psize
    HMH_TestCheck(abs(V_right-V_left-physicalWidth)<1 && abs(V_bottom-V_top-physicalHeight)<1,"screen fitting preserves physical plot size")
    HMH_TestCheck(strsearch(WinRecreation(win,0),"gfSize=28",0)>=0,"screen fitting preserves physical font size")
    TextBox/W=$win/N=UserComment "This is a user annotation"
    HMH_Layout(win,1,12,4/3,24,24,2,2)
    HMH_TestCheck(strlen(AnnotationInfo(win,"UserComment",0))>0,"user annotations preserved")
    String trace=StringFromList(0,TraceNameList(win,";",1))
    SetWindow $win userdata($("HMHLabel_"+trace))="Fe\\B2\\MO\\B3\\M 1200°C annealed sample with a long condition label"
    HMH_TestCheck(HMH_Layout(win,1,12,4/3,24,24,2,2)==0,"long rich-text labels add canvas space")
    HMH_TestLegendBounds(win,2)
    GetWindow $win psize
    HMH_TestCheck(abs((V_right-V_left)-4/3*(V_bottom-V_top))<1,"long legend retains requested plot aspect")
    HMH_TestCheck(ItemsInList(WinList("HMH_Measure*",";","WIN:1"))==0,"measurement staging graphs cleaned up")
    HMH_TestSetup(1)
    HMH_TestCheck(HMH_DrawGraph(0)==1,"single sample graph supported")
    HMH_TestLegendBounds(win,1)
    HMH_TestCheck(WhichListItem("HMHLegend2",AnnotationList(win))<0,"single sample creates only one legend column")
    // Legacy graphs recover sample names from the wave's DataFolder.
    trace=StringFromList(0,TraceNameList(win,";",1))
    SetWindow $win userdata($("HMHLabel_"+trace))=""
    HMH_TestCheck(cmpstr(HMH_TraceLabel(win,trace),"900°C pre")==0,"v2.01 graph names recovered from dataset folder")
    HMH_TestSetup(10)
    HMH_TestCheck(HMH_DrawGraph(-1)==10,"ten sample comparison supported")
    HMH_TestLegendBounds(win,3)
    HMH_TestImport(output)
    SetWindow HMH_Panel userdata(HMHPanelVersion)=""
    HMH_OpenPanel()
    HMH_TestCheck(cmpstr(GetUserData("HMH_Panel","","HMHPanelVersion"),"2.2.0")==0,"old panel upgrades when reopened")
    HMH_TestCheck(WhichListItem("figure",ControlNameList("HMH_Panel",";"))>=0,"upgraded panel exposes figure settings button")
    NVAR mode=root:MHApp:Figure:targetMode,widthCM=root:MHApp:Figure:widthCM,axisFont=root:MHApp:Figure:axisFont
    NVAR legendFont=root:MHApp:Figure:legendFont,columns=root:MHApp:Figure:columns,lineWidth=root:MHApp:Figure:lineWidth
    mode=2; widthCM=18; ratio=1.2; axisFont=26; legendFont=24; columns=2; lineWidth=2.25
    HMH_TestCheck(HMH_ApplyDefaults(win)==0,"saved defaults apply to ten-sample graph")
    HMH_TestCheck(GetRTError(1)==0,"no runtime errors after all figure operations")
    SaveExperiment/C/F={1,"",0} as output+"mh_test_roundtrip.pxp"
    Print "SAVED",output+"mh_test_roundtrip.pxp"
    return 0
End

Function HMH_TestPersistence(saved)
    String saved
    LoadData/O/Q/R saved
    HMH_FigureInit()
    String base="root:MHApp:Figure:"
    HMH_TestCheck(NumVarOrDefault(base+"targetMode",0)==2,"canvas mode survives experiment save and reload")
    HMH_TestCheck(NumVarOrDefault(base+"widthCM",0)==18 && NumVarOrDefault(base+"ratio",0)==1.2,"physical width and ratio survive save reload")
    HMH_TestCheck(NumVarOrDefault(base+"axisFont",0)==26 && NumVarOrDefault(base+"legendFont",0)==24,"font sizes survive save reload")
    HMH_TestCheck(NumVarOrDefault(base+"columns",0)==2 && NumVarOrDefault(base+"lineWidth",0)==2.25,"legend columns and line width survive save reload")
    HMH_TestCheck(HMH_DrawGraph(-1)==10,"reloaded measurements support new comparison graph")
    SVAR win=root:MHApp:lastGraph
    GetWindow $win gsize
    HMH_TestCheck(abs(V_right-V_left-1.2*(V_bottom-V_top))<2*72/ScreenResolution*2.2,"reloaded canvas agrees within screen component rounding")
    HMH_TestCheck(abs(str2num(GetUserData(win,"","HMHCanvasWidth"))-1.2*str2num(GetUserData(win,"","HMHCanvasHeight")))<0.02,"reloaded physical canvas retains ratio 1.2")
    HMH_TestLegendBounds(win,2)
    HMH_TestCheck(GetRTError(1)==0,"no runtime errors after save reload")
End

Function HMH_TestLegendBounds(win,cols)
    String win
    Variable cols
    DoUpdate/W=$win
    GetWindow $win expand
    Variable expand=abs(V_value)
    GetWindow $win gsize
    Variable cw=V_right-V_left,ch=V_bottom-V_top
    GetWindow $win psize
    Variable plotTop=V_top,previousRight=-inf,c
    String rect,name
    Variable x1,y1,x2,y2
    for(c=1;c<=cols;c+=1)
        name="HMHLegend"+num2istr(c)
        rect=StringByKey("RECT",AnnotationInfo(win,name,1))
        x1=str2num(StringFromList(0,rect,",")); y1=str2num(StringFromList(1,rect,","))
        x2=str2num(StringFromList(2,rect,",")); y2=str2num(StringFromList(3,rect,","))
        HMH_TestCheck(x1>=-1 && y1>=-1 && x2<=cw+1,"legend "+num2istr(c)+" within canvas width")
        HMH_TestCheck(y2<=plotTop-4,"legend "+num2istr(c)+" above plot with gap")
        HMH_TestCheck(x1>=previousRight,"legend columns do not overlap")
        previousRight=x2
    endfor
End

Function HMH_TestImport(output)
    String output
    NVAR count=root:MHApp:count
    Variable before=count
    String fixture=ParseFilePath(1,output,":",1,0)+"tests:fixture.VSM"
    HMH_TestCheck(HMH_Import(fixture)==0,"original VSM import succeeds")
    HMH_TestCheck(count==before+1,"import adds one measurement")
    Wave/T paths=root:MHApp:paths
    String rp=paths[count-1]
    Wave h=$(rp+"H_Oe"),m=$(rp+"M_emu"),x=$(rp+"H_kOe"),y=$(rp+"M_emu_g")
    HMH_TestCheck(numpnts(h)==11 && h[0]==-5000 && h[10]==5000,"raw magnetic field retained")
    HMH_TestCheck(abs(m[0]+0.2)<1e-12 && abs(m[10]-0.2)<1e-12,"raw magnetic moment retained")
    HMH_TestCheck(x[0]==-5 && x[10]==5,"Oe to kOe conversion unchanged")
    HMH_TestCheck(abs(y[0]+10)<1e-12 && abs(y[10]-10)<1e-12,"mass normalization emu per gram unchanged")
    HMH_TestCheck(NumVarOrDefault(rp+"sampleMassG",0)==0.02,"sample mass metadata retained")
    HMH_TestCheck(strsearch(note(y),"emu / sample mass(g)",0)>=0,"normalization provenance retained")
End

Function HMH_TestReal(listPath,output)
    String listPath,output
    Variable refNum,i=0
    String line
    Open/R refNum as listPath
    do
        FReadLine refNum,line
        if(!strlen(line))
            break
        endif
        line=ReplaceString("\r",ReplaceString("\n",line,""),"")
        HMH_TestCheck(HMH_Import(line)==0,"real VSM "+num2istr(i+1)+" imports")
        i+=1
    while(1)
    Close refNum
    HMH_TestCheck(i==6,"six real VSM files loaded")
    Wave/T names=root:MHApp:names,listText=root:MHApp:listText,paths=root:MHApp:paths
    Wave states=root:MHApp:listState
    String labels="before mill;after mill;1100°C;1200°C;1250°C;1300°C"
    for(i=0;i<6;i+=1)
        names[i]=StringFromList(i,labels)
        listText[i][1]=names[i]
        states[i][0]=48
    endfor
    Wave rawH=$(paths[0]+"H_Oe"),rawM=$(paths[0]+"M_emu"),x=$(paths[0]+"H_kOe"),y=$(paths[0]+"M_emu_g")
    // The file header says 2387 but the body contains 2388 numeric rows.
    // Count the body independently; do not discard a valid endpoint to match metadata.
    HMH_TestCheck(numpnts(x)==2388,"real VSM imports all independently counted numeric rows")
    HMH_TestCheck(abs(rawH[2387]-14999.04)<1e-6 && abs(rawM[2387]-0.95957)<1e-9,"real last numeric row retained")
    HMH_TestCheck(abs(rawH[0]-14998.31)<1e-6 && abs(rawM[0]-0.95921)<1e-9,"real first row matches original file")
    HMH_TestCheck(abs(x[0]-14.99831)<1e-9 && abs(y[0]-0.95921/0.0219)<1e-9,"real Oe and mass conversions match independently read header")
    HMH_TestCheck(HMH_DrawGraph(-1)==6,"real six-sample comparison renders")
    SVAR win=root:MHApp:lastGraph
    SetAxis/W=$win bottom -15,15
    SetAxis/W=$win left -80,80
    ModifyGraph/W=$win manTick(bottom)={0,5,0,0},manTick(left)={0,40,0,0},manminor={0,0}
    HMH_TestLegendBounds(win,2)
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as output+"mh_real_plot_ratio.png"
    HMH_Layout(win,2,16.5,1.1,24,24,2,2)
    HMH_TestLegendBounds(win,2)
    DoUpdate
    SavePICT/O/E=-5/WIN=$win as output+"mh_real_canvas_ratio.png"
    HMH_TestCheck(GetRTError(1)==0,"real VSM import and rendering without runtime error")
End
