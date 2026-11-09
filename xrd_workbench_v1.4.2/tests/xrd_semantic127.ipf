#pragma rtGlobals=3
// Run only in an isolated validation Experiment. TSV records all persisted fields.
Function/S XRD127_Escape(value)
    String value
    String result="",token
    Variable i,byte
    for(i=0;i<strlen(value);i+=1)
        byte=char2num(value[i])
        if(byte<0)
            byte+=256
        endif
        if(byte<32 || byte>=127 || byte==37)
            sprintf token,"%%%02X",byte
            result+=token
        else
            result+=num2char(byte)
        endif
    endfor
    return result
End

Function XRD127_DumpRecord(file,key,value)
    Variable file
    String key,value
    fprintf file,"%s\t%s\n",XRD127_Escape(key),XRD127_Escape(value)
End

Function XRD127_DumpFolder(base,file)
    String base
    Variable file
    if(!DataFolderExists(base))
        return 0
    endif
    DFREF folder=$base
    String name,path,label,value,encodedPath127
    Variable i=0,j,d,k,n,a,b,c,e,nx,ny,nz,nt
    XRD127_DumpRecord(file,"F|"+base,"")
    do
        name=GetIndexedObjNameDFR(folder,2,i)
        if(!strlen(name))
            break
        endif
        NVAR number=$(base+":"+PossiblyQuoteName(name))
        sprintf value,"%.17g",number
        XRD127_DumpRecord(file,"N|"+base+":"+PossiblyQuoteName(name),value)
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,3,i)
        if(!strlen(name))
            break
        endif
        SVAR text=$(base+":"+PossiblyQuoteName(name))
        XRD127_DumpRecord(file,"S|"+base+":"+PossiblyQuoteName(name),text)
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,1,i)
        if(!strlen(name))
            break
        endif
        path=base+":"+PossiblyQuoteName(name)
        Wave w=$path
        value=num2istr(WaveType(w))+","+num2istr(DimSize(w,0))+","+num2istr(DimSize(w,1))+","+num2istr(DimSize(w,2))+","+num2istr(DimSize(w,3))
        XRD127_DumpRecord(file,"W|"+path,value)
        XRD127_DumpRecord(file,"NOTE|"+path,note(w))
        XRD127_DumpRecord(file,"FORMULA|"+path,GetFormula(w))
        XRD127_DumpRecord(file,"UNITS|"+path,WaveUnits(w,-1))
        for(d=0;d<4;d+=1)
            sprintf value,"%.17g,%.17g",DimOffset(w,d),DimDelta(w,d)
            XRD127_DumpRecord(file,"SCALE"+num2istr(d)+"|"+path,value+","+WaveUnits(w,d))
            XRD127_DumpRecord(file,"DLABEL"+num2istr(d)+"|"+path,GetDimLabel(w,d,-1))
            for(j=0;j<DimSize(w,d);j+=1)
                label=GetDimLabel(w,d,j)
                if(strlen(label))
                    XRD127_DumpRecord(file,"LABEL"+num2istr(d)+","+num2istr(j)+"|"+path,label)
                endif
            endfor
        endfor
        nx=max(1,DimSize(w,0));ny=max(1,DimSize(w,1));nz=max(1,DimSize(w,2));nt=max(1,DimSize(w,3))
        encodedPath127=XRD127_Escape(path)
        for(k=0;k<numpnts(w);k+=1)
            a=mod(k,nx);b=mod(floor(k/nx),ny);c=mod(floor(k/nx/ny),nz);e=floor(k/nx/ny/nz)
            if(WaveType(w)==0)
                Wave/T tw=$path
                value=tw[a][b][c][e]
            else
                sprintf value,"%.17g",w[a][b][c][e]
            endif
            if(WaveType(w)==0)
                value=XRD127_Escape(value)
            endif
            fprintf file,"V%d|%s\t%s\n",k,encodedPath127,value
        endfor
        i+=1
    while(1)
    i=0
    do
        name=GetIndexedObjNameDFR(folder,4,i)
        if(!strlen(name))
            break
        endif
        XRD127_DumpFolder(base+":"+PossiblyQuoteName(name),file)
        i+=1
    while(1)
End

Function XRD127_DumpAll(destination)
    String destination
    Variable file
    Open file as destination
    XRD127_DumpFolder("root:Packages:Workbench",file)
    XRD127_DumpFolder("root:Packages:XRDWorkbench",file)
    Close file
    Print "SEMANTIC_DUMP_OK",destination,GetRTError(1)
End
