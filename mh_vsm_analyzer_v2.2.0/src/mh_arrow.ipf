#pragma rtGlobals=3

// Optional: only this editor's named arrows are changed. Native user drawings
// remain in the full graph snapshot and can always be edited with Igor tools.
Function HMG_ArrowPanel()
    if(HMG_Init()!=0)
        return -1
    endif
    NVAR option=root:MHApp:Manager:arrowOption
    if(!option)
        return 0
    endif
    String win=WinName(0,1),uid,base,choices="新しい矢印を追加;",aid
    SVAR kind=root:MHApp:Manager:selectedKind,selected=root:MHApp:Manager:selectedUID
    if(cmpstr(kind,"graph")==0)
        win=HMG_GraphWindow(selected)
        if(strlen(win)==0)
            if(HMG_OpenGraph(selected)!=0)
                return -1
            endif
            win=HMG_GraphWindow(selected)
        endif
    endif
    if(WinType(win)!=1 || WhichListItem(win,HMH_FigureList())<0)
        DoAlert 0,"先にMHグラフを選んでください。"
        return -1
    endif
    uid=HMG_AdoptGraph(win);base=HMG_GraphPath(uid)
    Wave/T/Z arrows=$(base+"arrowIDs")
    if(!WaveExists(arrows))
        Make/O/T/N=0 $(base+"arrowIDs")
        Wave/T arrows=$(base+"arrowIDs")
    endif
    Variable i,choice=1,x1,x2,y1,y2
    for(i=0;i<numpnts(arrows);i+=1)
        choices+="矢印 "+num2istr(i+1)+";"
    endfor
    Prompt choice,"調整する矢印",popup choices
    DoPrompt "補助機能：矢印の位置",choice
    if(V_flag)
        return 0
    endif
    Make/FREE/D/N=4 coords
    if(choice==1)
        GetAxis/Q/W=$win bottom
        x1=V_min+0.65*(V_max-V_min);x2=V_min+0.55*(V_max-V_min)
        GetAxis/Q/W=$win left
        y1=V_min+0.8*(V_max-V_min);y2=V_min+0.65*(V_max-V_min)
    else
        aid=arrows[choice-2]
        if(HMG_ReadArrow(win,aid,coords)!=0)
            DoAlert 0,"この矢印を数値で読み取れません。Igor標準の描画ツールで編集してください。"
            return -1
        endif
        x1=coords[0];y1=coords[1];x2=coords[2];y2=coords[3]
    endif
    Prompt x1,"始点：磁場 (kOe)"
    Prompt y1,"始点：磁化 (emu/g)"
    Prompt x2,"終点：磁場 (kOe)"
    Prompt y2,"終点：磁化 (emu/g)"
    DoPrompt "矢印の始点・終点（取消で変更なし）",x1,y1,x2,y2
    if(V_flag)
        return 0
    endif
    if(choice==1)
        aid=HMG_NewUID("a")
    endif
    if(HMG_SetArrow(win,aid,x1,y1,x2,y2)!=0)
        return -1
    endif
    if(choice==1)
        i=numpnts(arrows)
        Redimension/N=(i+1) arrows
        arrows[i]=aid
    endif
    return HMG_Capture(win)
End

Function HMG_ReadArrow(win,aid,coords)
    String win,aid
    Wave coords
    DrawAction/W=$win/L=UserFront getgroup=$aid,commands
    if(!V_flag)
        return -1
    endif
    String commands=S_recreation,compact=ReplaceString(" ",S_recreation,"")
    Variable start=strsearch(commands,"DrawLine ",0),i
    if(start<0 || strsearch(compact,"xcoord=bottom",0)<0 || strsearch(compact,"ycoord=left",0)<0)
        return -1
    endif
    String line=StringFromList(0,commands[start+9,inf],"\r")
    for(i=0;i<4;i+=1)
        coords[i]=str2num(StringFromList(i,line,","))
    endfor
    return SelectNumber(numtype(sum(coords))==0,-1,0)
End

Function HMG_SetArrow(win,aid,x1,y1,x2,y2)
    String win,aid
    Variable x1,y1,x2,y2
    if(WinType(win)!=1 || numtype(x1+y1+x2+y2)!=0)
        return -1
    endif
    DrawAction/W=$win/L=UserFront getgroup=$aid,commands
    String original=S_recreation,line,commands
    Variable existsGroup=V_flag,start,stop,error
    sprintf line,"DrawLine %.17g,%.17g,%.17g,%.17g",x1,y1,x2,y2
    if(existsGroup)
        Make/FREE/D/N=4 coords
        if(HMG_ReadArrow(win,aid,coords)!=0)
            return -1
        endif
        start=strsearch(original,"DrawLine ",0)
        stop=strsearch(original,"\r",start)
        if(stop<0)
            return -1
        endif
        commands=original[0,start-1]+line+original[stop,inf]
        DrawAction/W=$win/L=UserFront getgroup=$aid,delete,beginInsert
    else
        commands="SetDrawEnv gstart,gname="+aid+"\rSetDrawEnv xcoord=bottom,ycoord=left,arrow=1,linethick=1.5\r"+line+"\rSetDrawEnv gstop\r"
    endif
    DoWindow/F $win
    SetDrawLayer/W=$win UserFront
    V_flag=0
    Execute/Z "Macro HMGArrowEdit()\r"+commands+"End\r"
    error=V_flag
    if(existsGroup)
        DrawAction/W=$win/L=UserFront endInsert
    endif
    if(error && existsGroup)
        Execute/Z "Macro HMGArrowRestore()\r"+original+"End\r"
    endif
    return error
End
