#pragma rtGlobals=3

Function HMP_CloseMode()
    // Igor 9 supports a silent close. Igor 10 can also omit open previews from a PXP.
    return SelectNumber(IgorVersion()>=10,1,4)
End

Function HMP_NeedsOverlay()
    if(WinType("HMG_Manager"))
        GetWindow HMG_Manager maximize
        if(V_value)
            return 1
        endif
    endif
    if(WinType("HMH_Panel"))
        GetWindow HMH_Panel maximize
        return V_value
    endif
    return 0
End

Function/S HMP_NewHost(title)
    String title
    String host=UniqueName("MH_Preview",6,0)
    NewPanel/FLT/K=(HMP_CloseMode())/N=$host/W=(110,100,735,625) as title
    ModifyPanel/W=$host fixedSize=0
    SetWindow $host userdata(HMPHost)="1",activeChildFrame=0
    return host
End

Function/S HMP_PlotList()
    String wins=WinList("*",";","WIN:1"),hosts=WinList("MH_Preview*",";","FLT:1")
    String host,plot
    Variable i
    for(i=0;i<ItemsInList(hosts);i+=1)
        host=StringFromList(i,hosts)
        if(cmpstr(GetUserData(host,"","HMPHost"),"1")==0)
            plot=host+"#Plot"
            if(WinType(plot)==1)
                wins+=plot+";"
            endif
        endif
    endfor
    return wins
End

Function HMP_Front(win)
    String win
    if(WinType(win)!=1)
        return -1
    endif
    String host=StringFromList(0,win,"#")
    DoWindow/F $host
    return 0
End

Function HMP_Close(win)
    String win
    if(WinType(win)==1)
        String host=StringFromList(0,win,"#")
        KillWindow/Z $host
        if(WinType(win)==1)
            return -1
        endif
        SVAR/Z last=root:MHApp:lastGraph
        if(SVAR_Exists(last) && cmpstr(last,win)==0)
            last=""
        endif
    endif
    return 0
End

Function HMP_ResizeOverlay(win,width,height)
    String win
    Variable width,height
    if(strsearch(win,"#",0)<0)
        return 0
    endif
    String host=StringFromList(0,win,"#")
    if(cmpstr(GetUserData(host,"","HMPHost"),"1")!=0)
        return 0
    endif
    GetWindow $host wsize
    Variable left=V_left,top=V_top
    MoveWindow/W=$host left,top,left+width,top+height
    return 0
End

Function/S HMP_DefaultExportName(win)
    String win
    String traces=TraceNameList(win,";",1),name=""
    if(strlen(traces))
        Wave/Z y=TraceNameToWaveRef(win,StringFromList(0,traces))
        if(WaveExists(y))
            name=HMM_FileName(StrVarOrDefault(GetWavesDataFolder(y,1)+"sourceFile",""))
        endif
    endif
    if(StringMatch(LowerStr(name),"*.vsm"))
        return name[0,strlen(name)-5]+".png"
    endif
    String uid=GetUserData(win,"","HMHGraphUID")
    name=HMG_Name("graph",uid)
    if(strlen(name)==0)
        name=StringFromList(0,win,"#")
    endif
    String illegal=num2char(92)+num2char(34)+"/:*?<>|"
    Variable i
    for(i=0;i<strlen(illegal);i+=1)
        name=ReplaceString(illegal[i],name,"_")
    endfor
    return name+".png"
End

Function HMP_WritePNG(win,path)
    String win,path
    if(WinType(win)!=1 || !StringMatch(LowerStr(path),"*.png"))
        return -1
    endif
    HMD_Reposition(win)
    SavePICT/O/E=-5/B=288/WIN=$win as path
    return V_flag
End

Function HMP_ExportDialog(win)
    String win
    if(WinType(win)!=1)
        return -1
    endif
    Variable refNum
    String file=HMP_DefaultExportName(win)
    Open/D/F="PNG image (*.png):.png;"/M="MHグラフをPNGで保存" refNum as file
    if(strlen(S_fileName)==0)
        return 0
    endif
    if(HMP_WritePNG(win,S_fileName)!=0)
        DoAlert 0,"画像を保存できませんでした。保存先を確認してください。"
        return -1
    endif
    return 0
End

Menu "GraphPopup", dynamic
    HMP_GraphMenuItem("画像を保存…"), /Q, HMP_RunGraphMenu(0)
    HMP_GraphMenuItem("グラフを閉じる"), /Q, HMP_RunGraphMenu(1)
End

Menu "TracePopup", dynamic
    HMP_GraphMenuItem("画像を保存…"), /Q, HMP_RunGraphMenu(0)
    HMP_GraphMenuItem("グラフを閉じる"), /Q, HMP_RunGraphMenu(1)
End

Function/S HMP_GraphMenuItem(label)
    String label
    GetLastUserMenuInfo
    String win=S_graphName
    if(strlen(win)==0 || WinType(win)!=1)
        return ""
    endif
    return SelectString(strlen(GetUserData(win,"","HMHFigure")) || strlen(GetUserData(win,"","HMHGraphUID")),"",label)
End

Function HMP_RunGraphMenu(closePlot)
    Variable closePlot
    GetLastUserMenuInfo
    String win=S_graphName
    if(WinType(win)!=1)
        return -1
    endif
    if(closePlot)
        return HMP_Close(win)
    endif
    return HMP_ExportDialog(win)
End
