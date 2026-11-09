#pragma rtGlobals=3

// Convert unary ASCII minus signs in numeric labels at rendering time.
Function/S HMD_Minus(label)
    String label
    String result="",before,next
    Variable i
    for(i=0;i<strlen(label);i+=1)
        next=label[i+1,i+1]
        before=""
        if(i>0)
            before=label[i-1,i-1]
        endif
        if(cmpstr(label[i],"-")==0 && strlen(next) && strsearch("0123456789.",next,0)>=0)
            if(i==0 || strsearch(" =,([:"+"\t",before,0)>=0 || ((cmpstr(before,"e")==0 || cmpstr(before,"E")==0) && i>=2 && strsearch("0123456789.",label[i-2,i-2],0)>=0))
                result+=num2char(0x2212)
                continue
            endif
        endif
        result+=label[i]
    endfor
    return result
End

// Both legend measurement and the visible figure use the same native textbox.
Function HMD_Box(win,text,font,tabs,x,y)
    String win,text
    Variable font,x,y
    Wave tabs
    TextBox/W=$win/C/N=HMHLegend/A=LT/E=2/F=0/B=1/H=(font*1.8)/LS=(font*0.08)/X=(x)/Y=(y)/T={tabs[0],tabs[1],tabs[2],tabs[3],tabs[4],tabs[5],tabs[6],tabs[7],tabs[8],tabs[9]} text
End

Function HMD_MeasureLegend(win,traces,style,columns,font,tabs,centers,text,boxW,boxH)
    String win,traces,&text
    Variable style,columns,font,&boxW,&boxH
    Wave tabs,centers
    Variable n=ItemsInList(traces),cols=min(columns,n)
    if(style==2)
        cols=n
    elseif(style==3)
        cols=1
    endif
    if(cols>11)
        return -1
    endif
    Make/FREE/T/N=(n) labels
    Make/FREE/D/N=(cols) widths=0
    String stage=UniqueName("HMH_Measure",6,0),trace,item
    String prefix="\\F'Times New Roman'\\Z"+num2istr(font)+"\\[0"
    Wave y=TraceNameToWaveRef(win,StringFromList(0,traces))
    Display/HIDE=1/K=1/N=$stage y
    ModifyGraph/W=$stage gFont="Times New Roman",gfSize=font,width=400,height=300,expand=1
    tabs=30*(p+1)
    Variable i,col,origin=0,gap=max(8,font*0.55)
    for(i=0;i<n;i+=1)
        trace=StringFromList(i,traces)
        item=HMH_LegendLabel(HMD_Minus(HMH_TraceLabel(win,trace)))
        labels[i]=SelectString(style==1,item,"\\s("+trace+") "+item)
        if(style==1)
            item="\\s("+NameOfWave(y)+") "+item
        endif
        HMD_Box(stage,prefix+item,font,tabs,0,0)
        DoUpdate/W=$stage
        col=mod(i,cols)
        widths[col]=max(widths[col],HMH_AnnotationSize(stage,"HMHLegend",0))
    endfor
    for(col=0;col<cols-1;col+=1)
        origin+=ceil(widths[col]+gap)
        tabs[col]=origin
    endfor
    for(col=cols-1;col<numpnts(tabs);col+=1)
        origin+=30
        tabs[col]=origin
    endfor
    text=prefix
    String staged=prefix,delimiter
    for(i=0;i<n;i+=1)
        col=mod(i,cols)
        delimiter=""
        if(i>0)
            delimiter=SelectString(col==0,"\t","\r")
        endif
        item=labels[i]
        text+=delimiter+item
        if(style==1)
            item=ReplaceString("\\s("+StringFromList(i,traces)+")",item,"\\s("+NameOfWave(y)+")")
        endif
        staged+=delimiter+item
        if(style==2)
            centers[i]=widths[col]/2
            if(col>0)
                centers[i]+=tabs[col-1]
            endif
        endif
    endfor
    HMD_Box(stage,staged,font,tabs,0,0)
    DoUpdate/W=$stage
    boxW=ceil(HMH_AnnotationSize(stage,"HMHLegend",0))
    boxH=ceil(HMH_AnnotationSize(stage,"HMHLegend",1))
    KillWindow/Z $stage
    if(numtype(boxW+boxH)!=0 || boxW<=0 || boxH<=0)
        return -1
    endif
    return 0
End

Function HMD_RoomTemperature(win)
    String win
    String base="root:MHApp:Figure:"
    if(!NumVarOrDefault(base+"rtVisible",1))
        if(WhichListItem("HMD_RT",AnnotationList(win))>=0)
            TextBox/W=$win/K/N=HMD_RT
        endif
        return 0
    endif
    Variable x=NumVarOrDefault(base+"rtRight",8),y=NumVarOrDefault(base+"rtBottom",12)
    Variable font=NumVarOrDefault(base+"rtFont",24)
    TextBox/W=$win/C/N=HMD_RT/A=RB/E=0/F=2/S=0/B=(65535,65535,65535)/X=(x)/Y=(y) ("\\F'Times New Roman'\\Z"+num2istr(font)+"R.T.")
    return 0
End

Function HMD_ClearLeaders(win)
    String win
    DrawAction/W=$win/L=UserFront getgroup=HMDLeaders
    if(V_flag)
        DrawAction/W=$win/L=UserFront getgroup=HMDLeaders,delete
    endif
End

// Place the legend with point-sized clearances. The drawing group belongs only
// to the automatic legend; hand-drawn arrows use independent groups.
Function HMD_Reposition(win)
    String win
    Variable style=str2num(GetUserData(win,"","HMDStyle"))
    if(numtype(style)!=0 || WhichListItem("HMHLegend",AnnotationList(win))<0)
        return 0
    endif
    GetWindow $win expand
    Variable zoom=max(0.01,V_value)
    GetWindow $win gsize
    Variable canvasW=V_right-V_left,canvasH=V_bottom-V_top
    GetWindow $win psize
    Variable pl=V_left,pt=V_top,pw=V_right-V_left,ph=V_bottom-V_top
    if(min(canvasW,canvasH,pw,ph)<=0)
        return -1
    endif
    Variable w=HMH_AnnotationSize(win,"HMHLegend",0)*zoom,h=HMH_AnnotationSize(win,"HMHLegend",1)*zoom
    Variable left=max(6*zoom,min(pl+(pw-w)/2,canvasW-w-6*zoom)),top=7*zoom
    if(style==3)
        left=pl+pw+30*zoom
        top=max(6*zoom,min(pt+(ph-h)/2,canvasH-h-6*zoom))
    endif
    if(style==1)
        TextBox/W=$win/C/N=HMHLegend/X=(100*left/canvasW)/Y=(100*top/canvasH)
        return 0
    endif
    GetAxis/Q/W=$win bottom
    Variable xmin=V_min,xmax=V_max
    GetAxis/Q/W=$win left
    Variable ymin=V_min,ymax=V_max
    if(xmax==xmin || ymax==ymin)
        return -1
    endif
    String traces=GetUserData(win,"","HMDTraces"),trace,info
    String centers=GetUserData(win,"","HMDCenters")
    Variable n=ItemsInList(traces),i,sx,sy,ex,ey,desired,red,green,blue
    Variable sumY=0,visible=0
    Make/FREE/D/N=(n) curveX=NaN,curveY=NaN
    for(i=0;i<n;i+=1)
        trace=StringFromList(i,traces)
        desired=1
        if(style==2)
            sx=left+str2num(StringFromList(i,centers))*zoom
            desired=max(0.03,min(0.97,(sx-pl)/pw))
        endif
        if(HMD_TracePoint(win,trace,style,desired,xmin,xmax,ymin,ymax,ex,ey)==0)
            curveX[i]=ex;curveY[i]=ey
            sumY+=ey;visible+=1
        endif
    endfor
    if(style==3 && visible)
        top=max(6*zoom,min(pt+(1-sumY/visible)*ph-h/2,canvasH-h-6*zoom))
    endif
    TextBox/W=$win/C/N=HMHLegend/X=(100*left/canvasW)/Y=(100*top/canvasH)
    HMD_ClearLeaders(win)
    if(!visible)
        return 0
    endif
    String r,g,b
    SetDrawLayer/W=$win UserFront
    SetDrawEnv/W=$win gstart,gname=HMDLeaders,gedit=1
    for(i=0;i<n;i+=1)
        trace=StringFromList(i,traces)
        if(style==2)
            sx=left+str2num(StringFromList(i,centers))*zoom
            sy=top+h+3*zoom
        else
            sx=left-5*zoom
            sy=top+h*(i+0.5)/n
        endif
        if(numtype(curveX[i]+curveY[i])!=0)
            continue
        endif
        red=0;green=0;blue=0
        info=TraceInfo(win,trace,0)
        SplitString/E="(?s).*rgb(?:\\([^)]*\\))?=\\(\\s*([0-9]+),\\s*([0-9]+),\\s*([0-9]+)" info,r,g,b
        if(V_flag==3)
            red=str2num(r);green=str2num(g);blue=str2num(b)
        endif
        SetDrawEnv/W=$win xcoord=rel,ycoord=rel,linethick=1.35,linefgc=(red,green,blue),dash=0,arrow=1,arrowlen=5
        DrawLine/W=$win sx/canvasW,sy/canvasH,(pl+curveX[i]*pw)/canvasW,(pt+(1-curveY[i])*ph)/canvasH
    endfor
    SetDrawEnv/W=$win gstop
    return 0
End

Function/S HMD_RightTraceOrder(win,traces)
    String win,traces
    Variable n=ItemsInList(traces),i,ex,ey
    Make/FREE/T/N=(n) traceNames=StringFromList(p,traces)
    Make/FREE/D/N=(n) scores=2+p
    GetAxis/Q/W=$win bottom
    Variable xmin=V_min,xmax=V_max
    GetAxis/Q/W=$win left
    Variable ymin=V_min,ymax=V_max
    if(xmax==xmin || ymax==ymin)
        return traces
    endif
    for(i=0;i<n;i+=1)
        if(HMD_TracePoint(win,traceNames[i],3,1,xmin,xmax,ymin,ymax,ex,ey)==0)
            scores[i]=-ey+i*1e-9
        endif
    endfor
    Sort scores,traceNames
    String ordered=""
    for(i=0;i<n;i+=1)
        ordered+=traceNames[i]+";"
    endfor
    return ordered
End

// Pick a real visible point. For right labels favor the right edge. For top
// labels favor the upper part of each curve and the column beneath the label.
Function HMD_TracePoint(win,trace,style,desired,xmin,xmax,ymin,ymax,ex,ey)
    String win,trace
    Variable style,desired,xmin,xmax,ymin,ymax,&ex,&ey
    Wave/Z x=XWaveRefFromTrace(win,trace),y=TraceNameToWaveRef(win,trace)
    if(!WaveExists(x) || !WaveExists(y))
        return -1
    endif
    Variable i,xr,yr,score,best=inf
    for(i=0;i<min(numpnts(x),numpnts(y));i+=1)
        xr=(x[i]-xmin)/(xmax-xmin)
        yr=(y[i]-ymin)/(ymax-ymin)
        if(numtype(xr+yr)!=0 || min(xr,yr)<0 || max(xr,yr)>1)
            continue
        endif
        if(style==2)
            score=abs(xr-desired)*0.7+(1-yr)*0.7
        else
            score=1-xr
        endif
        if(score<best)
            best=score
            ex=xr;ey=yr
        endif
    endfor
    return SelectNumber(numtype(best)==0,-1,0)
End
