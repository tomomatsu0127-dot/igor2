#pragma rtGlobals=3
// XRD Workbench v1.2.0: one Experiment palette, with explicit legacy conflict choices.
Function/S XRD80_Styles()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:XRDWorkbench
    String base="root:Packages:XRDWorkbench:ExperimentStyles"
    NewDataFolder/O $base
    Wave/T/Z keys=$(base+":keys")
    if(!WaveExists(keys))
        Make/T/N=0 $(base+":keys"),$(base+":owners")
        Make/D/N=(0,4) $(base+":values")
        Make/T/N=(0,4) $(base+":conflicts")
        Make/D/N=(0,4) $(base+":incomingValues")
        Make/D/N=0 $(base+":conflictRows"),$(base+":resolved")
        String/G $(base+":legendOrder")=""
        Variable/G $(base+":selectedConflict")=0
    endif
    return base
End

Function XRD80_MigrateStyles(project)
    String project
    String base=XRD80_Styles()
    if(NumVarOrDefault(project+":stylesMigrated80",0))
        return 0
    endif
    Wave/T/Z oldKeys=$(project+":Styles:keys")
    Wave/Z oldValues=$(project+":Styles:values")
    if(!WaveExists(oldKeys) || !WaveExists(oldValues))
        return 0
    endif
    Wave/T keys=$(base+":keys"),owners=$(base+":owners"),conflicts=$(base+":conflicts")
    Wave values=$(base+":values"),incoming=$(base+":incomingValues"),rows=$(base+":conflictRows"),resolved=$(base+":resolved")
    Variable i,j,k,n,c,different
    for(i=0;i<numpnts(oldKeys);i+=1)
        j=-1
        for(k=0;k<numpnts(keys);k+=1)
            if(cmpstr(keys[k],oldKeys[i])==0)
                j=k
                break
            endif
        endfor
        if(j<0)
            n=numpnts(keys)
            Redimension/N=(n+1) keys,owners
            Redimension/N=(n+1,4) values
            keys[n]=oldKeys[i];owners[n]=project
            values[n][]=oldValues[i][q]
        else
            different=0
            for(k=0;k<4;k+=1)
                different+=(values[j][k]!=oldValues[i][k])
            endfor
            if(different)
                c=DimSize(conflicts,0)
                Redimension/N=(c+1,4) conflicts,incoming
                Redimension/N=(c+1) rows,resolved
                conflicts[c][0]=keys[j]
                conflicts[c][1]=StrVarOrDefault(owners[j]+":displayName",ParseFilePath(0,owners[j],":",1,0))
                conflicts[c][2]=StrVarOrDefault(project+":displayName",ParseFilePath(0,project,":",1,0))
                conflicts[c][3]="未選択"
                incoming[c][]=oldValues[i][q]
                rows[c]=j;resolved[c]=0
            endif
        endif
    endfor
    SVAR order=$(base+":legendOrder")
    if(!strlen(order))
        order=StrVarOrDefault(project+":Styles:legendOrder","")
    endif
    Variable/G $(project+":stylesMigrated80")=1
    return 0
End

Function XRD80_StyleConflictCount()
    String base=XRD80_Styles()
    Wave resolved=$(base+":resolved")
    Variable i,n=0
    for(i=0;i<numpnts(resolved);i+=1)
        n+=resolved[i]==0
    endfor
    return n
End

Function XRD80_StyleConflicts()
    String base=XRD80_Styles()
    if(!XRD80_StyleConflictCount())
        DoAlert 0,"色・記号の引継ぎで未選択の項目はありません。"
        return 0
    endif
    Wave/T table=$(base+":conflicts")
    SetDimLabel 1,0,'相・グループ',table
    SetDimLabel 1,1,'現在の設定の由来',table
    SetDimLabel 1,2,'別の設定の由来',table
    SetDimLabel 1,3,'選択状況',table
    DoWindow/K XRDStyleConflicts
    NewPanel/K=1/N=XRDStyleConflicts/W=(35,35,945,450) as "色・記号の引継ぎ：使う設定を選ぶ"
    DefaultGUIFont/W=XRDStyleConflicts all={"Segoe UI",12,0}
    TitleBox help,pos={15,12},frame=0,title="同じ相に異なる設定がありました。行を選び、引き継ぐ方を選んでください。\r元のプロジェクトの設定は保存してあります。"
    ListBox conflicts,pos={15,68},size={870,225},listWave=table,mode=1,widths={160,250,250,180},proc=XRD80_ConflictSelect
    TitleBox current,pos={15,305},frame=0,title=""
    TitleBox incoming,pos={15,333},frame=0,title=""
    PopupMenu currentSymbol,pos={440,300},title="記号",value="*MARKERPOP*",disable=2
    PopupMenu currentColor,pos={655,300},title="色",value="*COLORPOP*",disable=2
    PopupMenu incomingSymbol,pos={440,333},title="記号",value="*MARKERPOP*",disable=2
    PopupMenu incomingColor,pos={655,333},title="色",value="*COLORPOP*",disable=2
    Button keepCurrent,pos={15,375},size={260,30},title="現在の設定を使う",proc=XRD80_ConflictButton
    Button useIncoming,pos={295,375},size={260,30},title="選んだ別の設定を使う",proc=XRD80_ConflictButton
    Button done,pos={575,375},size={300,30},title="閉じる（後で選択できます）",proc=XRD80_ConflictButton
    XRD80_ShowConflict(0)
    return 0
End

Function XRD80_ShowConflict(row)
    Variable row
    String base=XRD80_Styles()
    Wave rows=$(base+":conflictRows"),values=$(base+":values"),incoming=$(base+":incomingValues")
    if(row<0 || row>=numpnts(rows))
        return -1
    endif
    Variable/G $(base+":selectedConflict")=row
    Variable k=rows[row]
    TitleBox current,win=XRDStyleConflicts,title="現在の設定（表の左側）"
    TitleBox incoming,win=XRDStyleConflicts,title="別の設定（表の右側）"
    PopupMenu currentSymbol,win=XRDStyleConflicts,mode=values[k][0]+1
    PopupMenu currentColor,win=XRDStyleConflicts,popColor=(values[k][1],values[k][2],values[k][3])
    PopupMenu incomingSymbol,win=XRDStyleConflicts,mode=incoming[row][0]+1
    PopupMenu incomingColor,win=XRDStyleConflicts,popColor=(incoming[row][1],incoming[row][2],incoming[row][3])
    return 0
End

Function XRD80_OfferStyleConflicts()
    String base=XRD80_Styles()
    if(XRD80_StyleConflictCount()>0 && !NumVarOrDefault(base+":conflictNoticeShown",0))
        Variable/G $(base+":conflictNoticeShown")=1
        XRD80_StyleConflicts()
    endif
    return 0
End

Function XRD80_ConflictSelect(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if(lba.eventCode==4)
        XRD80_ShowConflict(lba.row)
    endif
    return 0
End

Function XRD80_ResolveStyle(row,useIncoming)
    Variable row,useIncoming
    String base=XRD80_Styles()
    Wave rows=$(base+":conflictRows"),values=$(base+":values"),incoming=$(base+":incomingValues"),resolved=$(base+":resolved")
    Wave/T table=$(base+":conflicts")
    if(row<0 || row>=numpnts(rows))
        return -1
    endif
    if(useIncoming)
        values[rows[row]][]=incoming[row][q]
    endif
    resolved[row]=1
    table[row][3]=SelectString(useIncoming,"現在の設定を採用","別の設定を採用")
    XRD_RefreshStyles()
    XRD_RequestLive()
    return 0
End

Function XRD80_ConflictButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(cmpstr(ba.ctrlName,"done")==0)
        DoWindow/K XRDStyleConflicts
        return 0
    endif
    String base=XRD80_Styles()
    XRD80_ResolveStyle(NumVarOrDefault(base+":selectedConflict",0),cmpstr(ba.ctrlName,"useIncoming")==0)
    XRD80_ShowConflict(NumVarOrDefault(base+":selectedConflict",0))
    return 0
End
