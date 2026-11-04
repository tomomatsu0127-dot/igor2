#pragma rtGlobals=3
// v1.2.0 explicit legend columns; canvas grows while the plot rectangle is retained.
Function XRD110_LegendItems(win,keys,traces)
    String win
    String &keys,&traces
    String all=TraceNameList(win,";",1),trace,key,order=StrVarOrDefault(XRD80_Styles()+":legendOrder",""),ordered="",orderedTraces=""
    Variable i,index,j
    keys="";traces=""
    for(i=0;i<ItemsInList(all);i+=1)
        trace=StringFromList(i,all);index=str2num(GetUserData(win,"","Ref_"+trace))
        if(numtype(index)!=0 || index<=0)
            continue
        endif
        key=GetUserData(win,"","PhaseKey_"+trace)
        if(!strlen(key))
            key=StrVarOrDefault(XRD_ReferencePath(index)+":styleGroup",XRD_PhaseLabel(index))
        endif
        if(WhichListItem(key,keys)<0)
            keys+=key+";";traces+=trace+";"
        endif
    endfor
    for(i=0;i<ItemsInList(order);i+=1)
        key=StringFromList(i,order);j=WhichListItem(key,keys)
        if(j>=0)
            ordered+=key+";";orderedTraces+=StringFromList(j,traces)+";"
        endif
    endfor
    for(i=0;i<ItemsInList(keys);i+=1)
        key=StringFromList(i,keys)
        if(WhichListItem(key,ordered)<0)
            ordered+=key+";";orderedTraces+=StringFromList(i,traces)+";"
        endif
    endfor
    keys=ordered;traces=orderedTraces
    return ItemsInList(keys)
End

Function XRD110_ClearLegend(win)
    String win
    Variable i
    String name
    for(i=0;i<4;i+=1)
        name=SelectString(i==0,"PhasesCol110_"+num2istr(i+1),"Phases")
        if(WhichListItem(name,AnnotationList(win))>=0)
            TextBox/W=$win/K/N=$name
        endif
    endfor
End

Function XRD110_LegendColumns(win,keys,traces,font,cols,canvasWidth)
    String win,keys,traces
    Variable font,cols,canvasWidth
    return XRD120_OneLegend(win,"Phases",keys,traces,font,cols,1)
End

Function XRD120_OneLegend(win,name,keys,traces,font,cols,exterior)
    String win,name,keys,traces
    Variable font,cols,exterior
    Variable n=ItemsInList(keys),rows=ceil(n/cols),c,j,index
    Make/FREE/D/N=4 widths=0,stops=0
    String text="",label
    for(c=0;c<cols;c+=1)
        for(j=0;j<rows;j+=1)
            index=c*rows+j
            if(index<n)
                widths[c]=max(widths[c],XRD110_LegendWidth(StringFromList(index,keys),font))
            endif
        endfor
        stops[c]=widths[c]+font
        if(c>0)
            stops[c]+=stops[c-1]
        endif
    endfor
    for(j=0;j<rows;j+=1)
        if(j>0)
            text+="\r"
        endif
        for(c=0;c<cols;c+=1)
            index=c*rows+j
            if(index>=n)
                continue
            endif
            if(c>0)
                text+="\t"
            endif
            label=ReplaceString("\\M",XRD_LegendText(StringFromList(index,keys)),"\\M\\Z"+num2istr(font))
            text+="\\F'Times New Roman'\\Z"+num2istr(font)+"\\s("+StringFromList(index,traces)+") "+label
        endfor
    endfor
    if(n)
        Legend/W=$win/C/N=$name/F=0/M=0/A=LT/E=(exterior)/X=0/Y=0/T={stops[0],stops[1],stops[2]} text
    endif
    return rows
End

Function XRD110_RenderLegend(win)
    String win
    if(cmpstr(GetUserData(win,"","XRDLegendBusy110"),"1")==0)
        return 0
    endif
    SetWindow $win userdata(XRDLegendBusy110)="1"
    String recipe=GetUserData(win,"","XRDPlotRecipe"),keys="",traces="",ui=XRD_PlotRoot()+":UI"
    Variable n=XRD110_LegendItems(win,keys,traces),cols=max(1,min(4,NumVarOrDefault(recipe+":legendColumns",2))),font=NumVarOrDefault(recipe+":legendFont",24),separate=NumVarOrDefault(recipe+":legendSeparate",0)
    if(n)
        cols=min(n,cols)
    endif
    GetWindow $win psize
    Variable pw=V_right-V_left,ph=V_bottom-V_top,left=V_left,right
    GetWindow $win gsize
    right=V_right-(left+pw)
    Variable baseLeft=str2num(GetUserData(win,"","XRDLegendLeft110")),baseRight=str2num(GetUserData(win,"","XRDLegendRight110"))
    if(numtype(baseLeft)!=0)
        baseLeft=left;baseRight=right
    endif
    // First conversion restores the recipe's intended plot size, including old cramped figures.
    if(cmpstr(GetUserData(win,"","XRDLegend110"),"1")!=0 && strlen(recipe))
        pw=NumVarOrDefault(recipe+":width",pw);ph=NumVarOrDefault(recipe+":height",ph)
    endif
    XRD110_ClearLegend(win)
    Variable rows=ceil(n/cols),c,j,at,totalWidth=0,columnWidth,extra,top=24
    for(c=0;c<cols;c+=1)
        columnWidth=0
        for(j=0;j<rows;j+=1)
            at=c*rows+j
            if(at<n)
                columnWidth=max(columnWidth,XRD110_LegendWidth(StringFromList(at,keys),font))
            endif
        endfor
        totalWidth+=columnWidth+font
    endfor
    totalWidth=max(1,totalWidth-font)
    if(n && !separate)
        top=rows*font*1.5+18
    endif
    extra=SelectNumber(separate, max(0,totalWidth-pw-baseLeft-baseRight),0)
    ModifyGraph/W=$win width=pw,height=ph,margin(top)=top,margin(left)=(baseLeft+extra/2),margin(right)=(baseRight+extra/2)
    DoUpdate/W=$win
    GetWindow $win gsize
    Variable canvas=V_right-V_left
    if(!separate && WinType(win+"_Legend"))
        DoWindow/K $(win+"_Legend")
    endif
    if(n && !separate)
        XRD110_LegendColumns(win,keys,traces,font,cols,canvas)
    elseif(n)
        XRD110_SeparateLegend(win,keys,traces,font,cols,totalWidth,rows)
    endif
    ModifyGraph/W=$win width=0,height=0
    SetWindow $win userdata(XRDLegendRows)=num2istr(SelectNumber(separate,rows,0))
    SetWindow $win userdata(XRDLegend110)="1"
    SetWindow $win userdata(XRDLegendLeft110)=num2str(baseLeft)
    SetWindow $win userdata(XRDLegendRight110)=num2str(baseRight)
    SetWindow $win userdata(XRDManagedLegend)=XRD_FigureLegendSignature(win)
    SetWindow $win userdata(XRDLegendBusy110)="0"
    return 0
End

Function XRD110_SeparateLegend(source,keys,traces,font,cols,width,rows)
    String source,keys,traces
    Variable font,cols,width,rows
    String recipe=GetUserData(source,"","XRDPlotRecipe"),folder=recipe+":Legend110",win=source+"_Legend",trace,key
    if(!strlen(recipe))
        return -1
    endif
    NewDataFolder/O $folder
    Variable i,index
    DoWindow/K $win
    for(i=0;i<ItemsInList(keys);i+=1)
        trace=StringFromList(i,traces)
        Make/O/D/N=1 $(folder+":X"+num2istr(i))=NaN,$(folder+":Y"+num2istr(i))=NaN
        Wave xx=$(folder+":X"+num2istr(i)),yy=$(folder+":Y"+num2istr(i))
        if(i==0)
            Display/N=$win/K=1 yy/TN=$trace vs xx as "凡例 — "+StrVarOrDefault(recipe+":displayName","")
        else
            AppendToGraph/W=$win yy/TN=$trace vs xx
        endif
        index=str2num(GetUserData(source,"","Ref_"+trace))
        XRD_ApplyPhaseStyle(win,trace,index)
    endfor
    ModifyGraph/W=$win gFont="Times New Roman",gfSize=font
    ModifyGraph/W=$win width=max(150,width+12),height=max(45,rows*font*1.6+16),margin=4,noLabel=2,axThick=0,nticks=0
    SetAxis/W=$win bottom 0,1
    SetAxis/W=$win left 0,1
    XRD110_LegendColumns(win,keys,traces,font,cols,max(150,width+12))
    SetWindow $win userdata(XRDLegendSource110)=source
    return 0
End

Function XRD110_LegendButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode==2)
        Execute/P/Q "XRD110_ExportLegend()"
    endif
    return 0
End

Function XRD110_ExportLegend()
    String recipe=StrVarOrDefault(XRD_PlotRoot()+":UI:recipe",""),win="XRDP_"+StrVarOrDefault(recipe+":plotUID",""),keys="",traces=""
    if(!WinType(win))
        DoAlert 0,"先に図を作成・表示してください。"
        return -1
    endif
    Variable n=XRD110_LegendItems(win,keys,traces),cols=max(1,min(4,NumVarOrDefault(recipe+":legendColumns",2))),font=NumVarOrDefault(recipe+":legendFont",24),i,width=0
    if(!n)
        DoAlert 0,"出力する同定相の凡例がありません。"
        return -1
    endif
    for(i=0;i<n;i+=1)
        width=max(width,XRD110_LegendWidth(StringFromList(i,keys),font))
    endfor
    XRD110_SeparateLegend(win,keys,traces,font,cols,cols*(width+font),ceil(n/cols))
    SavePICT/O/E=-5/WIN=$(win+"_Legend")
    return 0
End

Function XRD110_LegendWidth(text,font)
    String text
    Variable font
    // Allow room for native subscript/superscript font resets and marker spacing.
    return max(XRD_LegendEntryWidth(text,font),strlen(text)*font*0.72+font*2.5)
End
