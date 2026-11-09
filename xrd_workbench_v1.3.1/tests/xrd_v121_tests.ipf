#pragma rtGlobals=3
#include ":xrd_v120_tests"
Function XRD_RunV121Tests(output)
    String output
    Variable/G root:XRDTestFailures=0
    XRD_Init();CtrlNamedBackground XRDAutoSave,stop
    Make/FREE/D/N=1001 xx=20+p*0.05,yy=2+100*exp(-((xx[p]-30)/0.1)^2)
    String path=XRD_Store(xx,yy,"transition.xy"),project=XRD_Project()
    XRD_Manual(path,30)
    Wave raw=$(path+":Raw:intensity"),processed=$(path+":Processed:intensity"),peaks=$(path+":Peaks:angle")
    Variable rawCRC=WaveCRC(0,raw),processedCRC=WaveCRC(0,processed),peaksCRC=WaveCRC(0,peaks)
    NVAR step=$(project+":activeStep")
    step=1;XRD_Panel()
    MoveWindow/W=XRDWorkbench 10,10,1410,850
    XRD_ResizePanel();DoUpdate
    String instance=GetUserData("XRDWorkbench","","XRDInstance")
    Wave baseline=$(path+":viewBaseline")
    Duplicate/FREE baseline,expected
    baseline=12345
    SetWindow XRDWorkbench userdata(XRDLayoutReady)="0"
    XRD_ViewSync(path)
    XRD_TestCheck(baseline[0]==12345 && baseline[3]==12345,"v121 unfinished layout does not resolve or overwrite view baseline")
    baseline=expected[p]
    SetWindow XRDWorkbench userdata(XRDLayoutReady)="1"
    Variable state,i,w,h,maximized
    STRUCT WMButtonAction ba
    ba.eventCode=2
    for(state=0;state<2;state+=1)
        if(state)
            MoveWindow/W=XRDWorkbench 2,2,2,2
            XRD_ResizePanel();DoUpdate
        endif
        GetWindow XRDWorkbench wsizeForControls
        w=V_right;h=V_bottom
        GetWindow XRDWorkbench maximize
        maximized=V_Value
        for(i=0;i<12;i+=1)
            ba.ctrlName="step"+num2istr(mod(i+2,4)+1)
            XRD_Button(ba);DoUpdate
            GetWindow XRDWorkbench wsizeForControls
            XRD_TestCheck(V_right==w && V_bottom==h,"v121 transition dimensions "+num2istr(state)+"/"+num2istr(i))
            GetWindow XRDWorkbench maximize
            XRD_TestCheck(V_Value==maximized && cmpstr(instance,GetUserData("XRDWorkbench","","XRDInstance"))==0,"v121 transition native frame and maximize "+num2istr(state)+"/"+num2istr(i))
            ControlInfo/W=XRDWorkbench step1
            XRD_TestCheck(V_width>300 && cmpstr(GetUserData("XRDWorkbench","","XRDLayoutReady"),"1")==0,"v121 final control geometry "+num2istr(state)+"/"+num2istr(i))
            Make/FREE/D/N=4 box
            XRD_ViewBox(path,box)
            XRD_TestCheck(baseline[0]==box[0] && baseline[1]==box[1] && baseline[2]==box[2] && baseline[3]==box[3],"v121 final baseline matches visible axes "+num2istr(state)+"/"+num2istr(i))
        endfor
    endfor
    step=3;XRD_Panel()
    GetAxis/W=XRDWorkbench#Pattern/Q left
    XRD_TestCheck(V_min==-30 && V_max==110,"v121 identification retains fixed Y")
    XRD_TestCheck(WaveCRC(0,raw)==rawCRC && WaveCRC(0,processed)==processedCRC && WaveCRC(0,peaks)==peaksCRC,"v121 transitions preserve all raw processed and peak points")
    Cursor/P/W=XRDWorkbench#Pattern A XRDWB_Measured 200
    Cursor/P/W=XRDWorkbench#Pattern B XRDWB_Measured 300
    ba.ctrlName="step1";XRD_Button(ba)
    ba.ctrlName="step3";XRD_Button(ba);DoUpdate
    XRD_TestCheck(pcsr(A,"XRDWorkbench#Pattern")==200 && pcsr(B,"XRDWorkbench#Pattern")==300,"v121 screen changes retain both native cursors")
    XRD_TestCheck(cmpstr(GetUserData("XRDWorkbench","","XRDUIVersion"),"1.2.1")==0,"v121 native panel version")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"transition121.png"
    CtrlNamedBackground XRDAutoSave,stop
    NVAR failures=root:XRDTestFailures
    Print "v121 failures=",failures,"RTE=",GetRTError(1)
End
