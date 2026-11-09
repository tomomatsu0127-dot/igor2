#pragma rtGlobals=3

Function/S XRD142_ArrowRecipe(win)
    String win
    if(WinType(win)!=1)
        return ""
    endif
    String recipe=GetUserData(win,"","XRDPlotRecipe")
    if(strsearch(recipe,XRD133_TrendFigures()+":",0)!=0 || !DataFolderExists(recipe))
        return ""
    endif
    return recipe
End

Function/S XRD142_ArrowGroup(rightSide)
    Variable rightSide
    return SelectString(rightSide,"XRD142ArrowA","XRD142ArrowC")
End

Function XRD142_ArrowLines(vertical,horizontal,x,y,direction)
    String vertical,horizontal
    Variable &x,&y,&direction
    Variable vx,vy,ex,ey,tip,tipY
    sscanf vertical,"DrawLine %f,%f,%f,%f",vx,vy,ex,ey
    if(V_flag!=4)
        return 0
    endif
    sscanf horizontal,"DrawLine %f,%f,%f,%f",x,y,tip,tipY
    if(V_flag!=4 || abs(vx-ex)>1e-6 || abs(ex-x)>1e-6 || abs(ey-y)>1e-6 || abs(tipY-y)>1e-6)
        return 0
    endif
    direction=SelectNumber(vy>y,1,-1)
    return 1
End

Function XRD142_ArrowPosition(win,rightSide,x,y,direction,legacy)
    String win
    Variable rightSide,&x,&y,&direction,&legacy
    String name=XRD142_ArrowGroup(rightSide),vertical,horizontal
    legacy=-1
    DrawAction/W=$win/L=UserFront getgroup=$name,commands
    if(V_flag)
        SplitString/E="(DrawLine[^\\r\\n]*)[\\s\\S]*(DrawLine[^\\r\\n]*)" S_recreation,vertical,horizontal
        return V_flag==2 && XRD142_ArrowLines(vertical,horizontal,x,y,direction)
    endif
    // v1.4.1 produced two ungrouped lines. Match its complete drawing sequence
    // so that adjacent native annotations and other user drawings survive.
    DrawAction/W=$win/L=UserFront commands
    String rgb=SelectString(rightSide,"55000,0,0","0,0,54000")
    String item="\\s*//\\s*;ITEMNO:[0-9]+;\\s*"
    String coords="SetDrawEnv\\s+xcoord=\\s*prel,ycoord=\\s*prel"
    String pen="SetDrawEnv\\s+linethick=\\s*3,linefgc=\\s*\\("+rgb+"\\)"
    String head="SetDrawEnv\\s+arrow=\\s*1,arrowlen=\\s*7,arrowfat=\\s*0\\.9,arrowsharp=\\s*0"
    String pattern="//\\s*;ITEMNO:([0-9]+);\\s*"+coords+item+pen+item+"(DrawLine[^\\r\\n]*)"
    pattern+=item+coords+item+pen+item+head+item+"(DrawLine[^\\r\\n]*)"
    String index
    SplitString/E=(pattern) S_recreation,index,vertical,horizontal
    if(V_flag==3 && XRD142_ArrowLines(vertical,horizontal,x,y,direction))
        legacy=str2num(index)
        return 1
    endif
    return 0
End

Function XRD142_DrawArrow(win,rightSide,x,y,direction)
    String win
    Variable rightSide,x,y,direction
    String name=XRD142_ArrowGroup(rightSide)
    Variable tip=x+SelectNumber(rightSide,-0.10,0.10)
    Variable red=SelectNumber(rightSide,55000,0),blue=SelectNumber(rightSide,0,54000)
    GetWindow $win drawLayer
    String previous=S_value
    SetDrawLayer/W=$win UserFront
    SetDrawEnv/W=$win gstart,gname=$name
    SetDrawEnv/W=$win xcoord=prel,ycoord=prel,linefgc=(red,0,blue),linethick=3,dash=0,arrow=0
    DrawLine/W=$win x,y-direction*0.07,x,y
    SetDrawEnv/W=$win xcoord=prel,ycoord=prel,linefgc=(red,0,blue),linethick=3,dash=0,arrow=1,arrowlen=7,arrowfat=0.9,arrowsharp=0
    DrawLine/W=$win x,y,tip,y
    SetDrawEnv/W=$win gstop
    SetDrawLayer/W=$win $previous
End

Function XRD142_AdjustArrows(win,automatic,ax,ay,cx,cy)
    String win
    Variable automatic,ax,ay,cx,cy
    String recipe=XRD142_ArrowRecipe(win)
    if(!strlen(recipe))
        return -1
    endif
    Wave xx=$(recipe+":horizontal"),aa=$(recipe+":latticeA"),cc=$(recipe+":latticeC")
    Variable hasC=WhichListItem("right",AxisList(win))>=0
    if(!automatic && (numtype(ax)!=0 || numtype(ay)!=0 || (hasC && (numtype(cx)!=0 || numtype(cy)!=0))))
        return -1
    endif
    PauseUpdate
    Variable side,oldX,oldY,dir,legacy,newX,newY
    String name
    // Delete the second arrow first so legacy indices before it stay valid.
    for(side=hasC;side>=0;side-=1)
        dir=1
        XRD142_ArrowPosition(win,side,oldX,oldY,dir,legacy)
        if(legacy>=0)
            DrawAction/W=$win/L=UserFront delete=legacy,(legacy+6)
        else
            name=XRD142_ArrowGroup(side)
            DrawAction/W=$win/L=UserFront getgroup=$name
            if(V_flag)
                DrawAction/W=$win/L=UserFront getgroup=$name,delete
            endif
        endif
        if(automatic)
            XRD142_AutoArrow(win,xx,aa,cc,side,hasC,newX,newY,dir)
        else
            newX=SelectNumber(side,max(11,min(95,ax)),max(5,min(89,cx)))/100
            newY=max(5,min(95,SelectNumber(side,ay,cy)))/100
            if(newY-dir*0.07<0.02 || newY-dir*0.07>0.98)
                dir=-dir
            endif
        endif
        XRD142_DrawArrow(win,side,newX,newY,dir)
    endfor
    return XRD_PlotCaptureNative(recipe)
End

Function XRD142_ArrowFields(win)
    String win
    String base="root:Packages:XRDWorkbench:UI:ArrowPosition142"
    Variable side,x,y,direction,legacy
    Variable hasC=WhichListItem("right",AxisList(win))>=0
    for(side=0;side<=hasC;side+=1)
        x=SelectNumber(side,0.15,0.85)
        y=0.5
        XRD142_ArrowPosition(win,side,x,y,direction,legacy)
        Variable/G $(base+SelectString(side,":ax",":cx"))=round(x*1000)/10
        Variable/G $(base+SelectString(side,":ay",":cy"))=round(y*1000)/10
    endfor
End

Function XRD142_ArrowPanel(win)
    String win
    if(!strlen(XRD142_ArrowRecipe(win)))
        DoAlert 0,"格子定数の系列図を前に出してから選んでください。"
        return -1
    endif
    String base="root:Packages:XRDWorkbench:UI:ArrowPosition142"
    XRD_UISettings()
    NewDataFolder/O $base
    XRD_EnsureNumeric(base+":cx",85)
    XRD_EnsureNumeric(base+":cy",50)
    XRD142_ArrowFields(win)
    String state=XRD123_PanelState("XRDTrendArrows")
    KillWindow/Z XRDTrendArrows
    XRD131_KeepPanelSize()
    NewPanel/K=1/N=XRDTrendArrows/W=(45,45,488,264) as "格子定数図の矢印位置"
    SetWindow XRDTrendArrows userdata(target)=win
    DefaultGUIFont/W=XRDTrendArrows all={"Segoe UI",12,0}
    TitleBox help,win=XRDTrendArrows,pos={16,15},frame=0,title="枠内の位置（%）  横は左から、縦は上から数えます。"
    TitleBox a,win=XRDTrendArrows,pos={16,56},frame=0,title="赤 a（左軸）"
    TitleBox c,win=XRDTrendArrows,pos={16,97},frame=0,title="青 c（右軸）"
    SetVariable ax,win=XRDTrendArrows,pos={144,55},size={112,23},title="横 %",limits={11,95,1},value=$(base+":ax")
    SetVariable ay,win=XRDTrendArrows,pos={270,55},size={112,23},title="縦 %",limits={5,95,1},value=$(base+":ay")
    Variable disabled=SelectNumber(WhichListItem("right",AxisList(win))>=0,2,0)
    SetVariable cx,win=XRDTrendArrows,pos={144,96},size={112,23},title="横 %",limits={5,89,1},value=$(base+":cx"),disable=disabled
    SetVariable cy,win=XRDTrendArrows,pos={270,96},size={112,23},title="縦 %",limits={5,95,1},value=$(base+":cy"),disable=disabled
    Button apply,win=XRDTrendArrows,pos={16,142},size={173,31},title="矢印の位置を反映",proc=XRD142_ArrowButton
    Button automatic,win=XRDTrendArrows,pos={202,142},size={216,31},title="現在の軸から自動配置",proc=XRD142_ArrowButton
    TitleBox status,win=XRDTrendArrows,pos={16,184},frame=0,title="位置は図と一緒に保存されます。"
    XRD123_FinishPanel("XRDTrendArrows",state)
    return 0
End

Function XRD142_ArrowContext()
    GetLastUserMenuInfo
    return XRD142_ArrowPanel(S_graphName)
End

Function XRD142_ArrowButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String win=GetUserData(ba.win,"","target"),base="root:Packages:XRDWorkbench:UI:ArrowPosition142"
    Variable auto=cmpstr(ba.ctrlName,"automatic")==0
    Variable result=XRD142_AdjustArrows(win,auto,NumVarOrDefault(base+":ax",NaN),NumVarOrDefault(base+":ay",NaN),NumVarOrDefault(base+":cx",NaN),NumVarOrDefault(base+":cy",NaN))
    if(result==0)
        XRD142_ArrowFields(win)
        ControlUpdate/W=XRDTrendArrows /A
    endif
    TitleBox status,win=XRDTrendArrows,title=SelectString(result==0,"対象の図を開き、数値を確認してください。","矢印の位置を図に反映しました。")
    return 0
End
