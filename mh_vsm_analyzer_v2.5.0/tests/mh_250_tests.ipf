#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

Function MHF_Check(ok,label)
    Variable ok
    String label
    if(ok)
        Print "PASS: "+label
    else
        Print "FAIL: "+label
        Variable/G root:MHFErrors=NumVarOrDefault("root:MHFErrors",0)+1
    endif
End

Function MHF_Demo(output)
    String output
    Variable/G root:MHFErrors=0
    HMG_Init()
    HMH_FigurePanel()
    MHF_Check(WinType("HMH_FigureSettings")==7,"Experiment settings open before any graph exists")
    DoWindow/K HMH_FigureSettings
    String namesList="x = -0.1;x = 0;x = 0.2;x = 0.4"
    Wave/T paths=root:MHApp:paths,names=root:MHApp:names,list=root:MHApp:listText
    Wave state=root:MHApp:listState
    Variable i
    for(i=0;i<4;i+=1)
        HMH_Import(output+"fixture.VSM")
        names[i]=StringFromList(i,namesList)
        list[i][1]=names[i]
        state[i][0]=48
        Wave x=$(paths[i]+"H_kOe"),y=$(paths[i]+"M_emu_g")
        Redimension/N=302 x,y
        x=p<151 ? -15+p/5 : 15-(p-151)/5
        y=(9+i)*tanh((x+SelectNumber(p<151,0.7,-0.7))/(2.6+i*0.65))+(0.65+0.1*i)*x
    endfor
    MHF_Check(cmpstr(HMD_Minus("x=-0.1, MH-044, y=1e-3"),"x=−0.1, MH-044, y=1e−3")==0,"numeric minus is converted without changing the sample identifier")
    MHF_Check(HMH_DrawGraph(-1)==4,"four curves plotted")
    SVAR last=root:MHApp:lastGraph
    String first=last
    MHF_Check(cmpstr(AnnotationList(first),"HMHLegend;HMD_RT;")==0 || (ItemsInList(AnnotationList(first))==2 && WhichListItem("HMHLegend",AnnotationList(first))>=0),"one legend box and one R.T. annotation")
    String info=AnnotationInfo(first,"HMHLegend",1)
    MHF_Check(strsearch(info,"−0.1",0)>=0 && cmpstr(names[0],"x = -0.1")==0,"native legend uses mathematical minus without editing measurement name")
    MHF_Check(HMP_WritePNG(first,output+"legend_standard.png")==0,"standard PNG export")
    MHF_Check(HMH_DrawGraph(0)==1,"second graph is open")
    String second=last
    GetAxis/Q/W=$second left
    Variable axisLow=V_min,axisHigh=V_max
    TextBox/W=$second/C/N=UserNote/A=LT "User note"
    HMF_BeginDraft()
    Variable/G root:MHApp:FigureDraft:ratio=1.1
    Variable/G root:MHApp:FigureDraft:rtRight=12
    Variable/G root:MHApp:FigureDraft:rtBottom=16
    Variable/G root:MHApp:FigureDraft:legendStyle=3
    MHF_Check(HMF_CommitDraft()==0,"shared ratio, R.T. position and right-arrow legend apply")
    MHF_Check(cmpstr(GetUserData(first,"","HMDStyle"),"3")==0 && cmpstr(GetUserData(second,"","HMDStyle"),"3")==0,"both open figures adopt shared legend mode")
    GetWindow $first psize
    MHF_Check(abs((V_right-V_left)/(V_bottom-V_top)-1.1)<0.02,"first plot adopts shared ratio")
    GetWindow $second psize
    MHF_Check(abs((V_right-V_left)/(V_bottom-V_top)-1.1)<0.02,"second plot adopts shared ratio")
    GetAxis/Q/W=$second left
    MHF_Check(V_min==axisLow && V_max==axisHigh && WhichListItem("UserNote",AnnotationList(second))>=0,"shared layout preserves axis limits and user annotation")
    DrawAction/W=$first/L=UserFront getgroup=HMDLeaders,commands
    MHF_Check(V_flag>0 && strsearch(ReplaceString(" ",S_recreation,""),"linefgc=(65535,0,0)",0)>=0,"right arrows match the trace colors")
    MHF_Check(HMP_WritePNG(first,output+"legend_right.png")==0,"right arrows PNG export")
    Variable/G root:MHApp:FigureDraft:legendStyle=2
    MHF_Check(HMF_CommitDraft()==0,"top-arrow mode applies experiment-wide")
    DrawAction/W=$first/L=UserFront getgroup=HMDLeaders,commands
    MHF_Check(V_flag>0 && strsearch(S_recreation,"DrawLine",0)>=0,"top legend has native draw leaders")
    MHF_Check(HMP_WritePNG(first,output+"legend_top.png")==0,"top arrows PNG export")
    Variable/G root:MHApp:FigureDraft:widthCM=6
    Variable/G root:MHApp:FigureDraft:ratio=4
    MHF_Check(HMF_CommitDraft()<0 && NumVarOrDefault("root:MHApp:Figure:ratio",0)==1.1,"invalid dimensions leave committed settings intact")
    MHF_Check(HMH_DrawGraph(1)==1 && cmpstr(GetUserData(last,"","HMDStyle"),"2")==0,"new graph reads committed Experiment style")
    HMP_Close(last)
    HMP_Close(first)
    HMP_Close(second)
    HMH_FigurePanel()
    SavePICT/SNAP=1/WIN=HMH_FigureSettings/O/E=-5 as output+"common_settings.png"
    DoWindow/K HMH_FigureSettings
    SaveExperiment/C/F={1,"",0} as output+"shared_roundtrip.pxp"
    Variable error=GetRTError(1)
    Print "RUNTIME_ERROR",error,GetErrMessage(error)
    MHF_Check(error==0,"no runtime errors")
    Print "MHF_FAILURES",NumVarOrDefault("root:MHFErrors",-1)
End

Function MHF_Reopen()
    MHF_Check(NumVarOrDefault("root:MHApp:Figure:ratio",0)==1.1 && NumVarOrDefault("root:MHApp:Figure:rtBottom",0)==16,"shared geometry and R.T. offset survive reopen")
    MHF_Check(HMH_DrawGraph(0)==1,"saved Experiment makes another graph")
    SVAR last=root:MHApp:lastGraph
    MHF_Check(cmpstr(GetUserData(last,"","HMDStyle"),"2")==0 && WhichListItem("HMD_RT",AnnotationList(last))>=0,"reopened experiment uses stored arrow legend and R.T. setting")
    Print "REOPEN_FAILURES",NumVarOrDefault("root:MHFErrors",-1)
End
