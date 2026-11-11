#pragma rtGlobals=3

Function XRD143_BenchZoom()
    XRD_Init()
    Make/FREE/D/N=120001 xx=10+0.000625*p,yy=10+70*exp(-((xx[p]-29)/0.8)^2)
    String path=XRD_Store(xx,yy,"synthetic.xy")
    Variable/G $(XRD_Project()+":activeStep")=3
    XRD_Panel();DoUpdate
    CtrlNamedBackground XRDAutoSave,stop
    Variable i,j,timer
    for(j=0;j<5;j+=1)
        timer=StartMSTimer
        for(i=0;i<20;i+=1)
            XRD100_Zoom(path,25+mod(i,2),4)
        endfor
        Print "ZOOM_20_MS",StopMSTimer(timer)/1000
    endfor
    GetAxis/W=XRDWorkbench#Pattern/Q bottom
    Print "FINAL_X",V_min,V_max
    GetAxis/W=XRDWorkbench#Pattern/Q left
    Print "FINAL_Y",V_min,V_max
End
