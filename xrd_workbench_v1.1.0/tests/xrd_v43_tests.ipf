#pragma rtGlobals=3
// v0.4.3: use an isolated test experiment. These are synthetic cards.
Function XRD_RunV43Tests(fixturesPath,outputPath)
    String fixturesPath,outputPath
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_NewProject()
    NewPath/O/Q XRDReferencePath,fixturesPath
    String project=XRD_Project(),errorText="",aliases="tt;2theta;two_theta;twotheta;2θ",ints="I;int;intensity;rel_intensity"
    Make/FREE/D/N=6 map,values
    Variable a,b,count,result
    for(a=0;a<ItemsInList(aliases);a+=1)
        for(b=0;b<ItemsInList(ints);b+=1)
            count=XRD_MapReferenceHeader("h k l "+StringFromList(b,ints)+" "+StringFromList(a,aliases),map,errorText)
            result=XRD_ParseMappedReferenceRow("1 2 -3 8e1 35.4",count,map,values,errorText)
            XRD_TestCheck(count==5 && result==1 && values[0]==-3 && values[1]==2 && values[2]==1 && values[3]==80 && values[4]==35.4 && numtype(values[5])==2,"aliases "+StringFromList(a,aliases)+" / "+StringFromList(b,ints))
        endfor
    endfor
    count=XRD_MapReferenceHeader("  D\tREL_INTENSITY  h\tTWOTHETA l K ",map,errorText)
    result=XRD_ParseMappedReferenceRow("2.532\t80  1\t35.4 3 2",count,map,values,errorText)
    XRD_TestCheck(count==6 && result==1 && values[0]==3 && values[2]==1 && values[5]==2.532,"reordered case-insensitive header and tab separators")
    count=XRD_MapReferenceHeader("l k h I 2theta d",map,errorText)
    result=XRD_ParseMappedReferenceRow("1 0 0 25.4254 11.4780 7.70300",count,map,values,errorText)
    XRD_TestCheck(result==1 && values[0]==1 && values[2]==0 && values[3]==25.4254 && values[4]==11.478 && values[5]==7.703,"user-provided BaCaFe4O8 example parsed exactly")
    count=XRD_MapReferenceHeader("tt int h k l",map,errorText)
    result=XRD_ParseMappedReferenceRow("15.479 2.3 0 0 3",count,map,values,errorText)
    XRD_TestCheck(result==1 && values[0]==3 && values[1]==0 && values[2]==0 && values[3]==2.3 && values[4]==15.479,"user-provided CuFeO2 example parsed exactly")
    XRD_TestCheck(XRD_MapReferenceHeader("tt int h k",map,errorText)==-1 && strsearch(errorText,"l",0)>=0,"missing hkl column diagnosed")
    XRD_TestCheck(XRD_MapReferenceHeader("h k l I d",map,errorText)==-1 && strsearch(errorText,"2theta",0)>=0,"missing angle column diagnosed")
    XRD_TestCheck(XRD_MapReferenceHeader("h k l tt",map,errorText)==-1 && strsearch(errorText,"intensity",0)>=0,"missing intensity column diagnosed")
    XRD_TestCheck(XRD_MapReferenceHeader("h k l tt 2theta int",map,errorText)==-1 && strsearch(errorText,"重複",0)>=0,"duplicate aliases rejected")
    XRD_TestCheck(XRD_MapReferenceHeader("h k l tt int unknown",map,errorText)==6,"v051 extra named column accepted without remapping required fields")
    count=XRD_MapReferenceHeader("tt int h k l",map,errorText)
    XRD_TestCheck(XRD_ParseMappedReferenceRow("35.4 80 1 2",count,map,values,errorText)==-1 && strsearch(errorText,"列数",0)>=0,"short row rejected")
    XRD_TestCheck(XRD_ParseMappedReferenceRow("35.4 80 1 2 3 4",count,map,values,errorText)==-1,"extra numeric column rejected")
    XRD_TestCheck(XRD_ParseMappedReferenceRow("35.4 bad 1 2 3",count,map,values,errorText)==-1 && strsearch(errorText,"2列目",0)>=0,"bad number reports column")
    XRD_TestCheck(XRD_ParseMappedReferenceRow("35.4 1e999 1 2 3",count,map,values,errorText)==-1,"nonfinite overflow rejected")
    XRD_TestCheck(XRD_ParseMappedReferenceRow("35.4 80 1.5 2 3",count,map,values,errorText)==-1,"fractional Miller index rejected")
    XRD_TestCheck(XRD_ParseMappedReferenceRow("35.4 -1 1 2 3",count,map,values,errorText)==-1,"negative intensity rejected")
    XRD_TestCheck(XRD_ParseMappedReferenceRow("180 80 1 2 3",count,map,values,errorText)==-1,"angle upper boundary rejected")
    XRD_TestCheck(XRD_ParseMappedReferenceRow("0 80 1 2 3",count,map,values,errorText)==-1,"angle lower boundary rejected")
    count=XRD_MapReferenceHeader("l k h I 2theta d",map,errorText)
    XRD_TestCheck(XRD_ParseMappedReferenceRow("3 2 1 80 35.4 0",count,map,values,errorText)==-1,"explicit zero d rejected")
    XRD_TestCheck(XRD_ParseMappedReferenceRow("3 2 1 80 35.4 NaN",count,map,values,errorText)==-1,"explicit nonnumeric d rejected")
    XRD_TestCheck(XRD_LoadReferenceFile("legacy_six.txt",1)==0,"legacy six-column card imports")
    XRD_TestCheck(XRD_LoadReferenceFile("five_columns.txt",2)==0,"tt/int five-column card imports")
    XRD_TestCheck(XRD_LoadReferenceFile("reordered_six.txt",3)==0,"metadata-free reordered card imports")
    Wave lx=$(XRD_ReferencePath(1)+":twoTheta"),li=$(XRD_ReferencePath(1)+":intensity"),lh=$(XRD_ReferencePath(1)+":h"),lk=$(XRD_ReferencePath(1)+":k"),ll=$(XRD_ReferencePath(1)+":l"),ld=$(XRD_ReferencePath(1)+":d")
    Wave fx=$(XRD_ReferencePath(2)+":twoTheta"),fi=$(XRD_ReferencePath(2)+":intensity"),fh=$(XRD_ReferencePath(2)+":h"),fk=$(XRD_ReferencePath(2)+":k"),fl=$(XRD_ReferencePath(2)+":l"),fd=$(XRD_ReferencePath(2)+":d")
    Wave rx=$(XRD_ReferencePath(3)+":twoTheta"),rd=$(XRD_ReferencePath(3)+":d")
    XRD_TestCheck(lx[0]==15.479 && fx[0]==lx[0] && fx[1]==lx[1] && rx[0]==lx[0],"angle sorting agrees across formats")
    XRD_TestCheck(lh[0]==2 && lk[0]==0 && ll[0]==-1 && fh[0]==2 && fk[0]==0 && fl[0]==-1 && fh[1]==1 && fk[1]==2 && fl[1]==3,"hkl meaning and row alignment preserved")
    XRD_TestCheck(fi[0]==li[0] && fi[1]==li[1] && rd[0]==ld[0] && rd[1]==ld[1],"intensity and provided d preserved after sorting")
    XRD_TestCheck(numtype(fd[0])==2 && numtype(fd[1])==2,"missing d stored as NaN without fabrication")
    SVAR card=$(XRD_ReferencePath(3)+":cardNumber"),name=$(XRD_ReferencePath(3)+":phaseName"),formula=$(XRD_ReferencePath(3)+":formula"),source=$(XRD_ReferencePath(3)+":source"),cl=$(XRD_ReferencePath(3)+":phaseClass")
    XRD_TestCheck(cmpstr(card,"FILE:reordered_six.txt")==0 && cmpstr(name,"reordered_six.txt")==0 && strlen(formula)==0 && strlen(source)==0 && strlen(cl)==0,"all metadata optional with original filename fallback")
    SVAR fiveSource=$(XRD_ReferencePath(2)+":source")
    XRD_TestCheck(strsearch(fiveSource,"6670",0)>=0,"optional source metadata retained")
    String invalids="invalid_missing.txt;invalid_duplicate.txt;invalid_numeric.txt;invalid_d.txt"
    NVAR refs=$(project+":referenceCount")
    for(a=0;a<ItemsInList(invalids);a+=1)
        result=XRD_LoadReferenceFile(StringFromList(a,invalids),refs+1)
        XRD_TestCheck(result==-2 && refs==3,"invalid card rejected atomically: "+StringFromList(a,invalids))
    endfor
    name="User edited name"
    Variable style=XRD_StyleIndex(3)
    Wave styles=$(XRD80_Styles()+":values")
    styles[style][0]=8;styles[style][1]=12345
    XRD_LoadReferenceFile("reordered_six.txt",4)
    XRD_TestCheck(refs==3 && cmpstr(name,"User edited name")==0 && styles[style][0]==8 && styles[style][1]==12345,"reload retains existing card and user style/name")
    result=XRD_LoadReferences()
    NVAR errors=$(project+":referenceErrorCount")
    XRD_TestCheck(result==3 && refs==3 && errors==4,"mixed folder reports successes and errors without duplicates")
    // Follow imported five-column hkl through matching into the lattice input.
    Make/FREE/D xx={14,15.479,35.4,36},yy={0,20,80,0}
    String path=XRD_Store(xx,yy,"synthetic.xy")
    XRD_AddPoint(path,1,"Manual")
    XRD_AddPoint(path,2,"Manual")
    XRD_ScoreCandidates(path,0)
    Wave cr=$(path+":Candidates:refIndex")
    Variable row=-1
    for(a=0;a<numpnts(cr);a+=1)
        if(cr[a]==2)
            row=a
            break
        endif
    endfor
    XRD_TestCheck(row>=0,"five-column card participates in candidate matching")
    if(row>=0)
        XRD_AssignCandidate(path,0,row,0)
        XRD_PrepareLattice(path,2)
        Wave input=$(path+":Lattice:inputs")
        XRD_TestCheck(DimSize(input,0)==1 && input[0][2]==2 && input[0][3]==0 && input[0][4]==-1,"lattice input uses correctly mapped h/k/l without stored d")
    endif
    SVAR hint=$(project+":referenceFolderHint")
    hint=fixturesPath
    SaveExperiment as outputPath+"reference_roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "XRD v0.4.3 reference tests: failures="+num2istr(failures)
    return failures
End

Function XRD_VerifyV43Restored()
    NVAR failures=root:XRDTestFailures
    failures=0
    Wave d=$(XRD_ReferencePath(2)+":d"),h=$(XRD_ReferencePath(2)+":h")
    XRD_TestCheck(numtype(d[0])==2 && h[0]==2,"five-column imported data and missing d survive experiment reload")
    SVAR name=$(XRD_ReferencePath(3)+":phaseName"),hint=$(XRD_Project()+":referenceFolderHint")
    XRD_TestCheck(cmpstr(name,"User edited name")==0 && strlen(hint)>0,"reference name and folder hint survive reload")
    Print "XRD v0.4.3 reference persistence tests: failures="+num2istr(failures)
    return failures
End
