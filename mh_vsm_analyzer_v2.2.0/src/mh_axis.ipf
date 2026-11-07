#pragma rtGlobals=3

// MH v2.1.2: non-modal axis editor. Tick digits are independent for X and Y.
Function HMH_AxisDigits(step)
    Variable step
    Variable d
    for(d=0;d<6;d+=1)
        if(abs(step*10^d-round(step*10^d))<1e-7)
            return d
        endif
    endfor
    return 6
End

Function HMH_NiceStep(span)
    Variable span
    Variable raw=span/6,unit=10^floor(log(raw)),m=raw/unit
    if(m<=1)
        return unit
    elseif(m<=2)
        return 2*unit
    elseif(m<=5)
        return 5*unit
    endif
    return 10*unit
End

Function/S HMH_AxisSetting(win,axis,key)
    String win,axis,key
    String info=AxisInfo(win,axis)
    Variable start=strsearch(info,"RECREATION:",0)
    if(start>=0)
        info=info[start+11,inf]
    endif
    String needle=key+"(x)="
    start=strsearch(LowerStr(info),LowerStr(needle),0)
    if(start<0)
        return ""
    endif
    info=info[start+strlen(needle),inf]
    if(cmpstr(info[0],"{")==0)
        return info[0,strsearch(info,"}",0)]
    endif
    return StringFromList(0,info)
End

Function HMH_ReadAxes(win)
    String win
    if(WinType(win)!=1)
        return -1
    endif
    HMH_Init()
    NewDataFolder/O root:MHApp:Axes
    String base="root:MHApp:Axes:",axes="bottom;left",prefix="x;y",axis,pre,tick,minor
    String saved=GetUserData(win,"","HMHAxes")
    String/G $(base+"target")=win
    Variable i,step,digits,exponent
    for(i=0;i<2;i+=1)
        axis=StringFromList(i,axes);pre=StringFromList(i,prefix)
        GetAxis/Q/W=$win $axis
        Variable/G $(base+pre+"Min")=V_min
        Variable/G $(base+pre+"Max")=V_max
        step=HMH_NiceStep(V_max-V_min); digits=-1
        tick=HMH_AxisSetting(win,axis,"manTick")
        if(strsearch(tick,"{",0)>=0)
            tick=ReplaceString("}",ReplaceString("{",tick,""),"")
            exponent=str2num(StringFromList(2,tick,","))
            step=str2num(StringFromList(1,tick,","))*10^exponent
            digits=str2num(StringFromList(3,tick,","))
            if(NumberByKey(pre+"Digits",saved)==-1 && abs(NumberByKey(pre+"Step",saved)-step)<1e-9 && digits==HMH_AxisDigits(step))
                digits=-1
            endif
        endif
        Variable/G $(base+pre+"Step")=step
        Variable/G $(base+pre+"Digits")=digits
        minor=HMH_AxisSetting(win,axis,"manMinor")
        minor=ReplaceString("}",ReplaceString("{",minor,""),"")
        Variable/G $(base+pre+"Minor")=max(0,str2num(StringFromList(0,minor,",")))
        NVAR small=$(base+pre+"Minor")
        if(numtype(small)!=0)
            small=0
        endif
    endfor
    return 0
End

Function HMH_AxisPanel()
    HMH_Init()
    SVAR last=root:MHApp:lastGraph
    String wins=HMH_FigureList(),win=last
    if(WinType(win)!=1)
        win=StringFromList(0,wins)
    endif
    if(HMH_ReadAxes(win)!=0)
        DoAlert 0,"先に単独表示または比較グラフを作ってください。"
        return -1
    endif
    DoWindow/K HMH_AxisSettings
    NewPanel/N=HMH_AxisSettings/W=(60,60,800,577) as "MH：軸・目盛り・小数桁数 v2.2.0"
    DefaultGUIFont/W=HMH_AxisSettings all={"Segoe UI",12,0}
    PopupMenu axisTarget,pos={18,15},title="対象の図",value=HMH_FigureList(),mode=(WhichListItem(win,wins)+1),proc=HMH_AxisTarget
    String base="root:MHApp:Axes:",pre,head
    Variable i,x
    for(i=0;i<2;i+=1)
        pre=StringFromList(i,"x;y");x=18+i*356
        head=SelectString(i,"横軸：Magnetic field (kOe)","縦軸：Magnetization (emu/g)")
        GroupBox $(pre+"Group"),pos={x,54},size={344,253},title=head
        SetVariable $(pre+"Min"),pos={x+14,87},size={310,22},title="最小値",limits={-inf,inf,1},value=$(base+pre+"Min")
        SetVariable $(pre+"Max"),pos={x+14,122},size={310,22},title="最大値",limits={-inf,inf,1},value=$(base+pre+"Max")
        SetVariable $(pre+"Step"),pos={x+14,157},size={310,22},title="主目盛りの間隔",limits={0,inf,1},value=$(base+pre+"Step")
        SetVariable $(pre+"Minor"),pos={x+14,192},size={310,22},title="間に入れる小目盛りの数",limits={0,20,1},value=$(base+pre+"Minor")
        NVAR digits=$(base+pre+"Digits")
        PopupMenu $(pre+"Digits"),pos={x+14,229},title="小数点以下",value="自動（間隔に合わせる）;0桁：15;1桁：15.0;2桁：15.00;3桁：15.000;4桁：15.0000;5桁;6桁",mode=(digits+2),proc=HMH_AxisDecimal
        Button $(pre+"Preset"),pos={x+14,270},size={310,25},title=SelectString(i,"横軸：−15～15、5刻みにする","縦軸：−30～30、10刻みにする"),proc=HMH_AxisButton
    endfor
    Button integers,pos={20,325},size={216,30},title="両軸を整数表示にする",proc=HMH_AxisButton
    Button suggest,pos={250,325},size={466,30},title="数字の重なりを避ける目盛り間隔を提案",proc=HMH_AxisButton
    TitleBox axisHint,pos={22,372},frame=0,title="小数桁数：自動なら5刻みは15、0.5刻みは15.0。小目盛りは0で非表示。\r『提案』と『整数表示』は入力欄を変更します。下の『反映』で図に適用します。"
    Button applyAxes,pos={20,435},size={340,34},title="図へ反映（この画面は開いたまま）",proc=HMH_AxisButton
    Button readAxes,pos={376,435},size={340,34},title="現在の図の設定を読み直す",proc=HMH_AxisButton
    TitleBox axisStatus,pos={22,483},frame=0,title="調整後は『反映』を押してください。測定データと凡例は変更しません。"
    return 0
End

Function HMH_AxisTarget(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        HMH_ReadAxes(pa.popStr)
        HMH_AxisRefresh()
    endif
    return 0
End

Function HMH_AxisRefresh()
    NVAR xd=root:MHApp:Axes:xDigits,yd=root:MHApp:Axes:yDigits
    PopupMenu xDigits,win=HMH_AxisSettings,mode=(xd+2)
    PopupMenu yDigits,win=HMH_AxisSettings,mode=(yd+2)
End

Function HMH_AxisDecimal(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        Variable/G $("root:MHApp:Axes:"+pa.ctrlName)=pa.popNum-2
    endif
    return 0
End

Function HMH_TickTextWidth(win,axis,lo,hi,step,digits)
    String win,axis
    Variable lo,hi,step,digits
    String info=AxisInfo(win,axis),font=StringByKey("FONT",info),text,fmt="%."+num2istr(digits)+"f"
    Variable size=NumberByKey("FONTSIZE",info),i,width=0,value
    // Include endpoints as a conservative bound; check all ticks up to 500.
    for(i=-2;i<min(500,ceil((hi-lo)/step)+1);i+=1)
        value=ceil(lo/step)*step+i*step
        if(i==-2)
            value=lo
        elseif(i==-1)
            value=hi
        endif
        sprintf text,fmt,value
        // Igor's long minus is wider than the ASCII hyphen used by sprintf.
        // Measure the displayed sign so negative labels do not touch the title.
        text=ReplaceString("-",text,"−")
        width=max(width,FontSizeStringWidth(font,size*ScreenResolution/72,0,text)*72/ScreenResolution)
    endfor
    return width
End

Function HMH_AxisSuggest()
    String base="root:MHApp:Axes:"
    SVAR win=$(base+"target")
    NVAR xmin=$(base+"xMin"),xmax=$(base+"xMax"),ymin=$(base+"yMin"),ymax=$(base+"yMax")
    NVAR xs=$(base+"xStep"),ys=$(base+"yStep"),xd=$(base+"xDigits"),yd=$(base+"yDigits")
    if(numtype(xmin+xmax+ymin+ymax)!=0 || xmax<=xmin || ymax<=ymin || WinType(win)!=1)
        return -1
    endif
    GetWindow $win psize
    Variable w=V_right-V_left,h=V_bottom-V_top,i,d,spacing,font=NumberByKey("FONTSIZE",AxisInfo(win,"left"))
    xs=HMH_NiceStep(xmax-xmin);ys=HMH_NiceStep(ymax-ymin)
    for(i=0;i<12;i+=1)
        d=SelectNumber(xd<0,xd,HMH_AxisDigits(xs))
        spacing=w*xs/(xmax-xmin)
        if(spacing>=HMH_TickTextWidth(win,"bottom",xmin,xmax,xs,d)+10)
            break
        endif
        xs=HMH_NiceStep(xs*6*1.01)
    endfor
    for(i=0;i<12;i+=1)
        if(h*ys/(ymax-ymin)>=font*1.5)
            break
        endif
        ys=HMH_NiceStep(ys*6*1.01)
    endfor
    return 0
End

Function HMH_ApplyAxes(win,xmin,xmax,xstep,xminor,xdigits,ymin,ymax,ystep,yminor,ydigits)
    String win
    Variable xmin,xmax,xstep,xminor,xdigits,ymin,ymax,ystep,yminor,ydigits
    if(WinType(win)!=1 || numtype(xmin+xmax+xstep+xminor+xdigits+ymin+ymax+ystep+yminor+ydigits)!=0)
        return -1
    endif
    if(xmax<=xmin || ymax<=ymin || xstep<=0 || ystep<=0 || xminor<0 || yminor<0 || xminor>20 || yminor>20 || xminor!=round(xminor) || yminor!=round(yminor))
        return -1
    endif
    if(xdigits< -1 || ydigits< -1 || xdigits>6 || ydigits>6 || xdigits!=round(xdigits) || ydigits!=round(ydigits))
        return -1
    endif
    Variable xd=SelectNumber(xdigits<0,xdigits,HMH_AxisDigits(xstep)),yd=SelectNumber(ydigits<0,ydigits,HMH_AxisDigits(ystep))
    if(xstep*10^xd<1-1e-8 || ystep*10^yd<1-1e-8 || (xmax-xmin)/xstep>500 || (ymax-ymin)/ystep>500)
        return -2
    endif
    // Reserve room for numeric labels without rebuilding user-edited legends.
    GetWindow $win psize
    Variable pw=V_right-V_left,ph=V_bottom-V_top,leftMargin=V_left
    Variable plotRight=V_right,topMargin=V_top,bottomOfPlot=V_bottom
    GetWindow $win gsize
    Variable cw=V_right-V_left,ch=V_bottom-V_top,rightMargin=cw-plotRight
    // Read fixed physical margins from the native recreation, not the pixel-rounded
    // window rectangle (which changes with monitor DPI).
    String rec=WinRecreation(win,0),marginKeys="left;right;top;bottom",key
    Make/FREE/D/N=4 margins
    margins[0]=leftMargin;margins[1]=rightMargin;margins[2]=topMargin;margins[3]=ch-bottomOfPlot
    Variable k,offset,value
    for(k=0;k<4;k+=1)
        key="margin("+StringFromList(k,marginKeys)+")="
        offset=strsearch(rec,key,0)
        if(offset>=0)
            value=str2num(rec[offset+strlen(key),inf])
            if(numtype(value)==0 && value>0)
                margins[k]=value
            endif
        endif
    endfor
    leftMargin=margins[0];rightMargin=margins[1];topMargin=margins[2]
    Variable font=NumberByKey("FONTSIZE",AxisInfo(win,"left"))
    Variable yw=HMH_TickTextWidth(win,"left",ymin,ymax,ystep,yd)
    Variable xw=HMH_TickTextWidth(win,"bottom",xmin,xmax,xstep,xd)
    Variable newLeft=ceil(max(leftMargin,yw+font*1.5+28)),newRight=ceil(max(rightMargin,xw/2+8))
    Variable whole=NumberByKey("mode",GetUserData(win,"","HMHLayout"))==2
    if(whole)
        String layout=GetUserData(win,"","HMHLayout")
        Variable canvasW=NumberByKey("widthCM",layout)*72/2.54,canvasH=canvasW/NumberByKey("ratio",layout)
        pw=canvasW-newLeft-newRight
        ph=canvasH-topMargin-margins[3]
        if(pw<font*5)
            return -3
        endif
    else
        // Preserve the native physical dimensions rather than rounded screen pixels.
        offset=strsearch(rec,"width=",0)
        if(offset>=0 && str2num(rec[offset+6,inf])>0)
            pw=str2num(rec[offset+6,inf])
        endif
        offset=strsearch(rec,"height=",0)
        if(offset>=0 && str2num(rec[offset+7,inf])>0)
            ph=str2num(rec[offset+7,inf])
        endif
    endif
    SetAxis/W=$win bottom xmin,xmax
    SetAxis/W=$win left ymin,ymax
    ModifyGraph/W=$win manTick(bottom)={0,xstep,0,xd},manMinor(bottom)={xminor,0}
    ModifyGraph/W=$win manTick(left)={0,ystep,0,yd},manMinor(left)={yminor,0}
    ModifyGraph/W=$win width=pw,height=ph,margin(left)=newLeft,margin(right)=newRight
    ModifyGraph/W=$win lblPosMode(left)=3,lblPos(left)=(yw+font+18)
    DoUpdate/W=$win
    // Keep physical canvas dimensions; a screen rectangle is pixel-rounded.
    SetWindow $win userdata(HMHCanvasWidth)=num2str(pw+newLeft+newRight)
    SetWindow $win userdata(HMHCanvasHeight)=num2str(ph+topMargin+margins[3])
    String settings
    sprintf settings,"xStep:%.12g;yStep:%.12g;xDigits:%d;yDigits:%d;",xstep,ystep,xdigits,ydigits
    SetWindow $win userdata(HMHAxes)=settings
    return 0
End

Function HMH_AxisButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    String base="root:MHApp:Axes:"
    SVAR win=$(base+"target")
    NVAR xmin=$(base+"xMin"),xmax=$(base+"xMax"),xs=$(base+"xStep"),xm=$(base+"xMinor"),xd=$(base+"xDigits")
    NVAR ymin=$(base+"yMin"),ymax=$(base+"yMax"),ys=$(base+"yStep"),ym=$(base+"yMinor"),yd=$(base+"yDigits")
    Variable result=0
    strswitch(ba.ctrlName)
        case "integers":
            xd=0;yd=0
            HMH_AxisRefresh()
            break
        case "suggest":
            result=HMH_AxisSuggest()
            break
        case "xPreset":
            xmin=-15;xmax=15;xs=5;xm=0;xd=0
            HMH_AxisRefresh()
            break
        case "yPreset":
            ymin=-30;ymax=30;ys=10;ym=0;yd=0
            HMH_AxisRefresh()
            break
        case "readAxes":
            result=HMH_ReadAxes(win)
            HMH_AxisRefresh()
            break
        case "applyAxes":
            result=HMH_ApplyAxes(win,xmin,xmax,xs,xm,xd,ymin,ymax,ys,ym,yd)
            break
    endswitch
    String status="入力欄を更新しました。『図へ反映』で適用します。"
    if(cmpstr(ba.ctrlName,"applyAxes")==0 && result==0)
        status="反映しました。この画面を開いたまま続けて調整できます。"
    elseif(result==-2)
        status="桁数が不足しているか目盛りが多すぎます。小数桁を増やすか間隔を広げてください。"
    elseif(result==-3)
        status="図全体の幅が足りません。図のサイズ設定で幅を広げてください。"
    elseif(result!=0)
        status="範囲・間隔・桁数を確認してください。最小値＜最大値、間隔＞0です。"
    endif
    TitleBox axisStatus,win=HMH_AxisSettings,title=status
    return 0
End
