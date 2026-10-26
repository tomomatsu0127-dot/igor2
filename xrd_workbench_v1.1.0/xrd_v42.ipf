#pragma rtGlobals=3
// XRD Workbench v1.1.0: native legend text and reversible measurement deletion.
Function/S XRD_LegendText(label)
    String label
    String subs="₀;₁;₂;₃;₄;₅;₆;₇;₈;₉",supers="⁰;¹;²;³;⁴;⁵;⁶;⁷;⁸;⁹;⁺;⁻",plain="0;1;2;3;4;5;6;7;8;9;+;-"
    Variable i
    // User-entered ASCII formulas such as Cu2 also use native subscripts.
    if(GrepString(label,"^([A-Z][a-z]?([0-9]+([.][0-9]+)?)?)+$"))
        label=XRD_FormulaLabel(label)
    endif
    for(i=0;i<10;i+=1)
        label=ReplaceString(StringFromList(i,subs),label,"\\B"+num2istr(i)+"\\M")
    endfor
    label=ReplaceString("\\M\\B",label,"")
    label=ReplaceString("\\M.\\B",label,".")
    for(i=0;i<12;i+=1)
        label=ReplaceString(StringFromList(i,supers),label,"\\S"+StringFromList(i,plain)+"\\M")
    endfor
    return ReplaceString("\\M\\S",label,"")
End

Function XRD_DeleteMeasurement(path)
    String path
    String project=XRD_Project(),list=XRD_MeasurementOrderList(project),name=ParseFilePath(0,path,":",1,0)
    if(cmpstr(path,XRD110_MeasurementPath(project,name))!=0 || WhichListItem(name,list)<0)
        return -1
    endif
    XRD_CaptureView()
    XRD_RecordUndo(path,"測定データの削除")
    Variable row=WhichListItem(name,list)
    Variable/G $(path+":deleted")=1
    String/G $(path+":deletedAt")=Secs2Date(DateTime,-2)+" "+Secs2Time(DateTime,3)
    list=RemoveFromList(name,list)
    SVAR active=$(project+":activeData")
    if(cmpstr(active,path)==0)
        active=""
        if(ItemsInList(list)>0)
            active=project+":Measurements:"+StringFromList(min(row,ItemsInList(list)-1),list)
        endif
    endif
    XRD_CloseEditors()
    XRD_Panel()
    return 0
End

Function XRD_DeleteMeasurementUI()
    String path=XRD_Data()
    if(strlen(path)==0)
        return 0
    endif
    SVAR name=$(path+":displayName")
    DoAlert 1,"「"+name+"」を測定一覧から削除しますか？\r削除した測定は新しい比較図に含まれません。\r元ファイルと作成済みグラフは残り、「削除を取り消す」で戻せます。"
    if(V_flag==1)
        return XRD_DeleteMeasurement(path)
    endif
    return 0
End

Function XRD_RestoreMeasurement(path)
    String path
    String project=XRD_Project(),name=ParseFilePath(0,path,":",1,0)
    if(cmpstr(path,XRD110_MeasurementPath(project,name))!=0 || !DataFolderExists(path))
        return -1
    endif
    if(!NumVarOrDefault(path+":deleted",0))
        return -1
    endif
    XRD_RecordUndo(path,"測定データの復元")
    Variable/G $(path+":deleted")=0
    SVAR active=$(project+":activeData")
    active=path
    XRD_Panel()
    return 0
End

Function XRD_RestoreMeasurementUI()
    String project=XRD_Project(),name,path,labels="",paths=""
    DFREF folder=$(project+":Measurements")
    Variable i=0,choice=1
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(strlen(name)==0)
            break
        endif
        path=XRD110_MeasurementPath(project,name)
        if(NumVarOrDefault(path+":deleted",0))
            labels+=name+" — "+ReplaceString(";",StrVarOrDefault(path+":displayName",name),",")+";"
            paths+=path+";"
        endif
        i+=1
    while(1)
    if(strlen(paths)==0)
        DoAlert 0,"削除した測定データはありません。"
        return 0
    endif
    Prompt choice,"戻す測定データ",popup,labels
    DoPrompt "削除を取り消す",choice
    if(V_flag)
        return 0
    endif
    return XRD_RestoreMeasurement(StringFromList(choice-1,paths))
End

Function/S XRD_LatticeResultText(path)
    String path
    NVAR aa=$(path+":Lattice:a"),sa=$(path+":Lattice:aSigma")
    SVAR crystal=$(path+":Lattice:crystalSystem")
    String result="a = "+num2str(aa)+" Å",uncertainty="a: "+num2str(sa)+" Å"
    if(cmpstr(crystal,"立方晶")!=0)
        NVAR cc=$(path+":Lattice:c"),sc=$(path+":Lattice:cSigma")
        result+="\rc = "+num2str(cc)+" Å"
        uncertainty+=" / c: "+num2str(sc)+" Å"
    endif
    return result+"\r\rフィット由来の標準誤差（1σ）\r"+uncertainty+"\r以前の±はこの値です。装置の系統誤差を含む総合精度ではありません。\r係数・標準誤差・残差は保存しています。"
End
