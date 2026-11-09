#pragma rtGlobals=3

Function XRD142_Bench()
    XRD_Init()
    Make/FREE/D/N=3001 xx=10+0.025*p,yy=20+70*exp(-((xx[p]-29)/0.8)^2)
    String path=XRD_Store(xx,yy,"synthetic.xy"),project=XRD_Project()
    XRD_Panel()
    XRD_AddPoint(path,760,"Manual")
    CtrlNamedBackground XRDAutoSave,stop
    Variable i,k,timer
    for(k=0;k<4;k+=1)
        timer=StartMSTimer
        for(i=0;i<10;i+=1)
            Variable/G $(project+":activeStep")=1+2*mod(i,2)
            XRD_Panel()
            DoUpdate
        endfor
        Print "SWITCH_10_MS",StopMSTimer(timer)/1000
    endfor
End
