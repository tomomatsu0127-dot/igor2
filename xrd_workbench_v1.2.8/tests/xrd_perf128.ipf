#pragma rtGlobals=3
// Shared, unchanged workload for old/new code; no private data in this file.
Function XRD128_Measure(operation,repeat)
    String operation
    Variable repeat
    String path=XRD_Data(),project=XRD_Project(),list
    Wave peaks=$(path+":Peaks:angle")
    Variable i,timer,ms,result=0
    for(i=0;i<repeat;i+=1)
        timer=StartMSTimer
        strswitch(operation)
            case "select":
                result=XRD100_Select(path,mod(i,numpnts(peaks)),1,preserveScroll=1)
                XRD_LiveDeferred()
                DoUpdate
                break
            case "score":
                result=XRD_ScoreCandidates(path,mod(i,numpnts(peaks)))
                break
            case "preview":
                result=XRD_PreviewCandidate(path,0)
                break
            case "comparePaths":
                list=XRD_ComparePaths();result=ItemsInList(list)
                break
            case "chooser":
                XRD110_DataChooser()
                break
            case "order":
                list=XRD_MeasurementOrderList(project);result=ItemsInList(list)
                break
            case "status":
                XRD_StatusBar(project,path)
                break
            case "live":
                XRD_RequestLive();result=XRD_LiveDeferred();DoUpdate
                break
            case "refresh":
                result=XRD_Panel();XRD_LiveDeferred();DoUpdate
                break
            case "upgrade":
                result=XRD_UpgradeProject(project)
                break
        endswitch
        ms=StopMSTimer(timer)/1000
        Print "PERF128",operation,i,ms,result
    endfor
End

Function XRD128_Make600()
    XRD_NewProject()
    String project=XRD_Project(),path,settings
    String/G $(project+":displayName")="Performance 600"
    Make/FREE/D/N=4001 xx=20+60*p/4000,yy=10+abs(sin(p*0.04))*100
    Variable i,j,timer=StartMSTimer
    for(i=0;i<600;i+=1)
        path=XRD_Store(xx,yy,"synthetic-600.csv")
        String/G $(path+":sampleNumber")=num2istr(i+1)
        String/G $(path+":composition")="x="+num2str(i/600)
        String/G $(path+":displayName")=StrVarOrDefault(path+":composition","")
        Wave px=$(path+":Peaks:angle"),py=$(path+":Peaks:height"),point=$(path+":Peaks:pointIndex"),ids=$(path+":Peaks:peakID")
        Wave/T origin=$(path+":Peaks:origin"),summary=$(path+":Peaks:assignmentSummary")
        Redimension/N=30 px,py,point,ids,origin,summary
        point=50+p*130;px=xx[point[p]];ids=p+1;origin="Manual"
        Variable/G $(path+":nextPeakID")=31
        Wave aid=$(path+":Assignments:peakID"),refs=$(path+":Assignments:refIndex"),rows=$(path+":Assignments:refPeakIndex"),shifts=$(path+":Assignments:shift")
        Wave/T mode=$(path+":Assignments:mode"),created=$(path+":Assignments:created")
        Redimension/N=30 aid,refs,rows,shifts,mode,created
        aid=ids[p];refs=0;rows=-1;shifts=0;mode="Unknown";created="synthetic"
        XRD_EnsureMeasurement(path)
    endfor
    String/G $(project+":activeData")=project+":Measurements:Data1"
    Variable/G $(project+":activeStep")=3
    settings=XRD120_CompareSettings()
    Make/O/T/N=5 $(settings+":uids")
    Wave/T selected=$(settings+":uids")
    for(i=0;i<5;i+=1)
        selected[i]=StrVarOrDefault(project+":Measurements:Data"+num2istr(i+1)+":measurementUID","")
    endfor
    Print "BUILD600_MS",StopMSTimer(timer)/1000
    XRD128_Workload()
End

Function XRD128_Workload()
    String projects=XRD_ProjectList(),project,names,path
    Variable i,j,measurements=0,points=0,peaks=0
    for(i=0;i<ItemsInList(projects);i+=1)
        project=XRD100_ProjectAt(projects,i)
        DFREF folder=$(project+":Measurements")
        for(j=0;j<CountObjectsDFR(folder,4);j+=1)
            path=project+":Measurements:"+PossiblyQuoteName(GetIndexedObjNameDFR(folder,4,j))
            Wave/Z raw=$(path+":Raw:twoTheta"),px=$(path+":Peaks:angle")
            if(WaveExists(raw))
                measurements+=1;points+=numpnts(raw)
            endif
            if(WaveExists(px))
                peaks+=numpnts(px)
            endif
        endfor
    endfor
    Print "WORKLOAD128",ItemsInList(projects),measurements,points,peaks,NumVarOrDefault(XRD80_Library()+":referenceCount",0)
    Print "MEMORY128",IgorInfo(0)
End
