#pragma rtGlobals=3
// XRD Workbench v1.1.0. Assigned markers and native Igor output graphs.

Function XRD_UpdateAssignedPlot(path)
    String path
    XRD_EnsureMeasurement(path)
    Wave peakX=$(path+":Peaks:angle"),peakY=$(path+":Peaks:height"),peakIDs=$(path+":Peaks:peakID")
    Wave assignID=$(path+":Assignments:peakID"),assignRef=$(path+":Assignments:refIndex")
    Make/O/D/N=(numpnts(peakX)) $(path+":Assignments:plotAngle"),$(path+":Assignments:plotHeight"),$(path+":Assignments:plotRefIndex")
    Wave outX=$(path+":Assignments:plotAngle"),outY=$(path+":Assignments:plotHeight"),outRef=$(path+":Assignments:plotRefIndex")
    Variable i,j,n=0
    for(i=0;i<numpnts(peakX);i+=1)
        for(j=0;j<numpnts(assignID);j+=1)
            if(assignID[j]==peakIDs[i] && assignRef[j]>0)
                outX[n]=peakX[i]
                outY[n]=peakY[i]
                outRef[n]=assignRef[j]
                n+=1
                break
            endif
        endfor
    endfor
    Redimension/N=(n) outX,outY,outRef
    return n
End

Function XRD_CreateEditableGraph()
    String path=XRD_Data()
    if(!strlen(path))
        return -1
    endif
    return XRD_PlotQuickCreate(path+";","XRD 単独図")
End

Function XRD_CreateStackGraph()
    String project=XRD_Project(),names=XRD_MeasurementOrderList(project),paths="",path
    Variable i
    for(i=0;i<ItemsInList(names);i+=1)
        path=project+":Measurements:"+StringFromList(i,names)
        if(NumVarOrDefault(path+":visibleInStack",0) && XRD_IsAnalysisComplete(path))
            paths+=path+";"
        endif
    endfor
    return XRD_PlotQuickCreate(paths,"XRD 比較図")
End

Function XRD_BuildStackPhaseWaves(path,offset,normalization)
    String path
    Variable offset,normalization
    String project=XRD_PlotOwner(path),stackRoot=path+":Stack"
    Variable refCount=NumVarOrDefault(XRD80_Library()+":referenceCount",0)
    Wave peakX=$(path+":Peaks:angle"),peakY=$(path+":Peaks:height"),peakIDs=$(path+":Peaks:peakID")
    Wave assignID=$(path+":Assignments:peakID"),assignRef=$(path+":Assignments:refIndex")
    Variable refIndex,i,j,n,yValue
    for(refIndex=1;refIndex<=refCount;refIndex+=1)
        Make/O/D/N=(numpnts(peakX)) $(stackRoot+":Ref"+num2istr(refIndex)+"_X"),$(stackRoot+":Ref"+num2istr(refIndex)+"_Y")
        Wave outX=$(stackRoot+":Ref"+num2istr(refIndex)+"_X"),outY=$(stackRoot+":Ref"+num2istr(refIndex)+"_Y")
        n=0
        for(i=0;i<numpnts(peakX);i+=1)
            for(j=0;j<numpnts(assignID);j+=1)
                if(assignID[j]==peakIDs[i] && assignRef[j]==refIndex)
                    outX[n]=peakX[i]
                    yValue=peakY[i]+offset
                    outY[n]=yValue
                    n+=1
                    break
                endif
            endfor
        endfor
        Redimension/N=(n) outX,outY
    endfor
    return 0
End

Function XRD_PhaseColor(refIndex,r,g,b)
    Variable refIndex
    Variable &r,&g,&b
    switch(mod(refIndex-1,8))
        case 0:
            r=52428; g=0; b=0
            break
        case 1:
            r=0; g=26214; b=52428
            break
        case 2:
            r=0; g=39321; b=19660
            break
        case 3:
            r=52428; g=26214; b=0
            break
        case 4:
            r=32768; g=0; b=49151
            break
        case 5:
            r=0; g=43690; b=43690
            break
        case 6:
            r=49151; g=0; b=32768
            break
        default:
            r=21845; g=21845; b=21845
    endswitch
End
