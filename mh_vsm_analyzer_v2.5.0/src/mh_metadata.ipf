#pragma rtGlobals=3

Function/S HMM_NormalizeLabel(label)
    String label
    String result="",ch
    Variable i=0
    do
        if(i>=strlen(label))
            break
        endif
        ch=label[i]
        if(cmpstr(ch,"=")==0 || cmpstr(ch,",")==0)
            if(cmpstr(ch,"=")==0)
                result=RemoveEnding(RemoveEnding(result," "),"\t")
                do
                    if(strlen(result)==0 || (cmpstr(result[strlen(result)-1]," ")!=0 && cmpstr(result[strlen(result)-1],"\t")!=0))
                        break
                    endif
                    result=RemoveEnding(result,result[strlen(result)-1])
                while(1)
                result+=" = "
            else
                result+=", "
            endif
            i+=1
            do
                if(i>=strlen(label) || (cmpstr(label[i]," ")!=0 && cmpstr(label[i],"\t")!=0))
                    break
                endif
                i+=1
            while(1)
        else
            result+=ch;i+=1
        endif
    while(1)
    return TrimString(result)
End

Function/S HMM_FileName(path)
    String path
    String normalized=ReplaceString("\\",path,":")
    return StringFromList(ItemsInList(normalized,":")-1,normalized,":")
End

Function HMM_ParseName(path,sample,composition)
    String path
    String &sample,&composition
    String file=HMM_FileName(path),body,condition
    sample="";composition=""
    SplitString/E="(?i)^MH-([0-9]+)-(.+)-([0-9]+(?:[.][0-9]+)?in[^_]*)_[0-9].*[.]VSM$" file,sample,body,condition
    if(V_flag!=3)
        sample="";composition=""
        return 0
    endif
    composition=HMM_NormalizeLabel(body)
    return 1
End

Function HMM_Init()
    NVAR count=root:MHApp:count
    Wave/T paths=root:MHApp:paths
    Wave/T/Z numbers=root:MHApp:Manager:sampleNumber
    Variable old=0,i
    if(!WaveExists(numbers))
        Make/O/T/N=0 root:MHApp:Manager:sampleNumber,root:MHApp:Manager:composition,root:MHApp:Manager:sourceName
    endif
    Wave/T numbers=root:MHApp:Manager:sampleNumber,compositions=root:MHApp:Manager:composition,sources=root:MHApp:Manager:sourceName
    old=numpnts(numbers)
    if(old>count || numpnts(compositions)!=old || numpnts(sources)!=old)
        return -1
    endif
    String sample,composition,file
    if(old<count)
        Redimension/N=(count) numbers,compositions,sources
        for(i=old;i<count;i+=1)
            SVAR/Z source=$(paths[i]+"sourceFile")
            file=""
            if(SVAR_Exists(source))
                file=source
            endif
            HMM_ParseName(file,sample,composition)
            numbers[i]=sample;compositions[i]=composition;sources[i]=HMM_FileName(file)
        endfor
    endif
    return 0
End

Function/S HMM_SampleNumber(uid)
    String uid
    Variable i=HMG_Find("data",uid)
    Wave/T/Z numbers=root:MHApp:Manager:sampleNumber
    if(i<0 || !WaveExists(numbers) || i>=numpnts(numbers))
        return ""
    endif
    return numbers[i]
End

Function HMM_ImportBatch(fileList,parent)
    String fileList,parent
    if(HMG_Init()!=0 || HMG_Find("folder",parent)<0)
        return -1
    endif
    if(WinType("HMM_ImportReview"))
        if(HMM_ApplyReview()!=0)
            DoAlert 0,"追加分の名前を確認してから次のファイルを追加してください。"
            return -1
        endif
        DoWindow/K HMM_ImportReview
    endif
    NewDataFolder/O root:MHApp:Manager:ImportReview
    Variable total=ItemsInList(fileList,"\r")
    Make/O/T/N=(total) root:MHApp:Manager:ImportReview:ids
    Wave/T batch=root:MHApp:Manager:ImportReview:ids
    NVAR count=root:MHApp:count
    Variable i,before,added=0,failed=0
    String file
    // Suppress tree construction per file; redraw once at the end of the batch.
    HMH_SaveNames()
    Variable/G root:MHApp:Manager:batchImporting=1
    try
    for(i=0;i<total;i+=1)
        file=StringFromList(i,fileList,"\r")
        if(strlen(file)==0)
            continue
        endif
        before=count
        if(HMH_Import(file,folderUID=parent)==0 && count==before+1)
            Wave/T ids=root:MHApp:Manager:datasetUID
            batch[added]=ids[before]
            added+=1
        else
            failed+=1
        endif
    endfor
    catch
        Variable err=GetRTError(1)
        failed+=total-i
        Print "MH: 読込を中断しました: ",err
    endtry
    Variable/G root:MHApp:Manager:batchImporting=0
    Redimension/N=(added) batch
    Variable/G root:MHApp:Manager:ImportReview:failures=failed
    HMM_PrepareReview()
    HMG_Refresh()
    return added
End

Function HMM_PrepareReview()
    Wave/T batch=root:MHApp:Manager:ImportReview:ids
    Wave/T names=root:MHApp:names,numbers=root:MHApp:Manager:sampleNumber,sources=root:MHApp:Manager:sourceName
    Variable n=numpnts(batch),i,index
    Make/O/T/N=(n,3) root:MHApp:Manager:ImportReview:text
    Make/O/N=(n,3) root:MHApp:Manager:ImportReview:state
    Make/O/T/N=3 root:MHApp:Manager:ImportReview:titles={"試料番号","表示名（凡例）","今回追加したファイル"}
    Wave/T text=root:MHApp:Manager:ImportReview:text
    Wave state=root:MHApp:Manager:ImportReview:state
    for(i=0;i<n;i+=1)
        index=HMG_Find("data",batch[i])
        if(index<0)
            return -1
        endif
        text[i][0]=numbers[index];text[i][1]=names[index];text[i][2]=sources[index]
        state[i][0]=6;state[i][1]=6;state[i][2]=0
    endfor
    return 0
End

Function HMM_ReviewPanel()
    Wave/T/Z batch=root:MHApp:Manager:ImportReview:ids
    if(!WaveExists(batch))
        return 0
    endif
    Variable n=numpnts(batch)
    if(n==0)
        return 0
    endif
    if(WinType("HMM_ImportReview"))
        DoWindow/F HMM_ImportReview
        return 0
    endif
    HMM_PrepareReview()
    NewPanel/N=HMM_ImportReview/W=(70,70,1080,540) as "MH：今回追加した測定の名前を確認"
    DefaultGUIFont/W=HMM_ImportReview all={"Segoe UI",12,0}
    Variable failed=NumVarOrDefault("root:MHApp:Manager:ImportReview:failures",0)
    String heading="今回追加した "+num2istr(n)+" 件。試料番号と表示名は別々に編集できます。"
    if(failed)
        heading+="　未読込 "+num2istr(failed)+" 件（履歴を確認）"
    endif
    TitleBox title,pos={18,15},frame=0,title=heading
    ListBox imported,pos={18,50},size={972,304},widths={95,315,540},mode=1,listWave=root:MHApp:Manager:ImportReview:text,selWave=root:MHApp:Manager:ImportReview:state,titleWave=root:MHApp:Manager:ImportReview:titles
    TitleBox hint,pos={18,367},frame=0,title="セルをダブルクリックして編集。例：044 ／ x = 0。元のファイル名は変更しません。"
    Button apply,pos={18,407},size={280,32},title="名前・試料番号を反映",proc=HMM_ReviewButton
    Button moveBatch,pos={310,407},size={300,32},title="今回追加分だけを別フォルダへ移動",proc=HMM_ReviewButton
    Button done,pos={622,407},size={368,32},title="反映して閉じる",proc=HMM_ReviewButton
    return 0
End

Function HMM_ApplyReview()
    Wave/T/Z batch=root:MHApp:Manager:ImportReview:ids,text=root:MHApp:Manager:ImportReview:text
    if(!WaveExists(batch) || !WaveExists(text))
        return 0
    endif
    Variable i,index,n=numpnts(batch)
    for(i=0;i<n;i+=1)
        if(HMG_Find("data",batch[i])<0 || strlen(TrimString(text[i][1]))==0 || strsearch(text[i][0]+text[i][1],"\r",0)>=0 || strsearch(text[i][0]+text[i][1],"\n",0)>=0)
            return -1
        endif
    endfor
    Wave/T names=root:MHApp:names,list=root:MHApp:listText,numbers=root:MHApp:Manager:sampleNumber
    for(i=0;i<n;i+=1)
        index=HMG_Find("data",batch[i])
        numbers[index]=TrimString(text[i][0])
        names[index]=HMM_NormalizeLabel(text[i][1])
        list[index][1]=names[index];text[i][0]=numbers[index];text[i][1]=names[index]
    endfor
    return 0
End

Function HMM_MoveBatch(parent)
    String parent
    if(HMG_Find("folder",parent)<0 || HMM_ApplyReview()!=0)
        return -1
    endif
    Wave/T batch=root:MHApp:Manager:ImportReview:ids,parents=root:MHApp:Manager:datasetFolder
    Variable i
    for(i=0;i<numpnts(batch);i+=1)
        if(HMG_Find("data",batch[i])<0)
            return -1
        endif
    endfor
    for(i=0;i<numpnts(batch);i+=1)
        parents[HMG_Find("data",batch[i])]=parent
    endfor
    HMG_Refresh()
    return 0
End

Function HMM_ReviewButton(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    if(HMM_ApplyReview()!=0)
        DoAlert 0,"表示名が空の行や改行を確認してください。反映していません。"
        return 0
    endif
    if(cmpstr(ba.ctrlName,"moveBatch")==0)
        String parent=HMG_ChooseFolder("今回追加した測定だけを移動")
        if(strlen(parent))
            HMM_MoveBatch(parent)
        endif
    elseif(cmpstr(ba.ctrlName,"done")==0)
        DoWindow/K HMM_ImportReview
    endif
    HMG_Refresh()
    return 0
End
