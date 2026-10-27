#pragma rtGlobals=3
// XRD Workbench v1.2.0. Measurement import remains strict and preserves raw values.
Function XRD_ParseLine(line, ax, ay)
    String line
    Variable &ax, &ay
    line=TrimString(line)
    if (strlen(line)==0 || StringMatch(line,"#*") || StringMatch(line,"//*"))
        return 0
    endif
    String number="[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?"
    String pattern="^[ \\t]*("+number+")[ \\t]*[,; \\t][ \\t]*("+number+")[ \\t\\r\\n]*$"
    if (!GrepString(line,pattern))
        return -1
    endif
    line=ReplaceString(",",line," ")
    line=ReplaceString(";",line," ")
    sscanf line, "%g %g", ax, ay
    if(V_flag!=2 || numtype(ax)!=0 || numtype(ay)!=0)
        return -1
    endif
    return 1
End

Function XRD_ImportFile(fileName)
    String fileName
    Variable ref, ax, ay, parsed, n=0, lineNo=0, headerCount=0
    String line, errorText=""
    Open/R/Z=2/F="XRD data (*.txt,*.csv,*.xy,*.dat):.txt,.csv,.xy,.dat;All files:.*;" ref as fileName
    if (V_flag!=0)
        if(V_flag!=-1)
            Print "XRD file open failed: "+num2istr(V_flag)
            return -3
        endif
        return -1
    endif
    String source=S_fileName
    Make/FREE/D/N=1024 xx, yy
    do
        FReadLine ref, line
        if (strlen(line)==0)
            break
        endif
        lineNo+=1
        if (lineNo==1)
            line=ReplaceString(num2char(239)+num2char(187)+num2char(191),line,"")
        endif
        parsed=XRD_ParseLine(line,ax,ay)
        if (parsed==0)
            continue
        endif
        if (parsed<0)
            // Only nonnumeric leading headers are skipped, never malformed data.
            if (n==0 && (!GrepString(TrimString(line),"^[+-.0-9]") || StringMatch(LowerStr(TrimString(line)),"2theta*")))
                headerCount+=1
                continue
            endif
            errorText="Invalid two-column data at line "+num2istr(lineNo)
            break
        endif
        if (n>0)
            if (ax<=xx[n-1])
                errorText="2theta must increase strictly; line "+num2istr(lineNo)
                break
            endif
        endif
        if (n==numpnts(xx))
            Redimension/N=(n+1024) xx, yy
        endif
        xx[n]=ax
        yy[n]=ay
        n+=1
    while(1)
    Close ref
    if (strlen(errorText)==0 && n<3)
        errorText="At least three valid data points are required."
    endif
    if (strlen(errorText))
        Print "XRD import rejected: "+errorText
        return -2
    endif
    Redimension/N=(n) xx, yy
    SetScale d,0,0,"deg",xx
    SetScale d,0,0,"a.u.",yy
    String path=XRD_Store(xx,yy,source)
    Variable/G $(path+":skippedHeaderLines")=headerCount
    Print "XRD imported "+num2istr(n)+" points; header lines skipped: "+num2istr(headerCount)
    return 0
End

Function XRD_ImportDialog()
    XRD_Init()
    if(!strlen(XRD_Project()))
        DoAlert 0,"先にプロジェクトを追加してください。"
        return -1
    endif
    return XRD110_RegisterPanel("")
End
