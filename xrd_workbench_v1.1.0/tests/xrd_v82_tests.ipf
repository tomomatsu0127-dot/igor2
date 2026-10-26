#pragma rtGlobals=3
#include ":xrd_v81_tests"
#include ":xrd_v82_expected"

Function XRD_RunV82Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    String/G root:XRDLiveTestFile=output+"live.txt"
    XRD_Init()
    CtrlNamedBackground XRDAutoSave,stop
    NewPath/O/Q XRDReferencePath,fixtures
    String files="00-001-0562.txt;00-003-0380.txt;00-017-0106.txt;00-019-0098.txt;00-039-0183.txt",rp,err=""
    Variable i,j,count,before,result,missing,unknownRow=-1,candidate=-1
    Make/FREE/D missingCounts={2,1,16,3,1},rowCounts={14,14,16,45,33}
    for(i=0;i<5;i+=1)
        XRD_TestCheck(XRD_LoadReferenceFile(StringFromList(i,files),i+1)==0,"v082 actual source imports "+StringFromList(i,files))
        rp=XRD_ReferencePath(i+1)
        Wave hh=$(rp+":h"),kk=$(rp+":k"),ll=$(rp+":l"),tt=$(rp+":twoTheta"),ii=$(rp+":intensity")
        missing=0
        for(j=0;j<numpnts(tt);j+=1)
            missing+=!XRD82_HKLKnown(hh[j],kk[j],ll[j])
        endfor
        XRD_TestCheck(numpnts(tt)==rowCounts[i] && missing==missingCounts[i],"v082 all rows and missing counts retained "+StringFromList(i,files))
        XRD82_Expected(i+1)
        XRD_TestCheck(XRD_LoadReferenceFile(StringFromList(i,files),6)==0 && NumVarOrDefault(XRD80_Library()+":referenceCount",0)==i+1,"v082 missing-value reload remains idempotent "+StringFromList(i,files))
    endfor
    // Strict parsing of explicitly missing indices; do not accept arbitrary NaN coercions.
    Make/FREE/D/N=6 map,values
    count=XRD_MapReferenceHeader("tt int h k l",map,err)
    result=XRD_ParseMappedReferenceRow("35.4 80 None -2 -",count,map,values,err)
    XRD_TestCheck(result==1 && numtype(values[2])==2 && values[1]==-2 && numtype(values[0])==2,"v082 partial hkl keeps known negative component and missing components")
    XRD_TestCheck(XRD_ParseMappedReferenceRow("35.4 80 nOnE 1 0",count,map,values,err)==1,"v082 None token is case insensitive")
    String badRows="35.4 80 bogus 1 0;35.4 80 NaN 1 0;35.4 80 inf 1 0;35.4 80 -- 1 0;35.4 80 1.5 - 0;None 80 - - -;35.4 None - - -;35.4 - - - -;0 80 - - -;180 80 - - -;35.4 -1 - - -;35.4 1e999 - - -;35.4 80 - -"
    for(i=0;i<ItemsInList(badRows);i+=1)
        XRD_TestCheck(XRD_ParseMappedReferenceRow(StringFromList(i,badRows),count,map,values,err)==-1,"v082 strict invalid row rejected "+num2istr(i))
    endfor
    count=XRD_MapReferenceHeader("l k h I 2theta d",map,err)
    XRD_TestCheck(XRD_ParseMappedReferenceRow("- - - 80 35.4 None",count,map,values,err)==-1,"v082 missing d token does not bypass supplied d validation")
    Variable h,k,l,intensity,angle,d
    XRD_TestCheck(XRD_ParseReferenceRow("- None 1 80 35.4 2.5",l,k,h,intensity,angle,d)==1 && numtype(l)==2 && numtype(k)==2 && h==1,"v082 legacy helper accepts the same explicit missing tokens")
    before=NumVarOrDefault(XRD80_Library()+":referenceCount",0)
    XRD_TestCheck(XRD_LoadReferenceFile("invalid_after_valid.txt",before+1)==-2 && NumVarOrDefault(XRD80_Library()+":referenceCount",0)==before && !DataFolderExists(XRD_ReferencePath(before+1)),"v082 invalid text still rejects entire file atomically after a valid missing row")
    XRD_TestCheck(XRD_LoadReferenceFile("partial.txt",6)==0,"v082 five-column partial-index fixture imports")
    Wave ph=$(XRD_ReferencePath(6)+":h"),pk=$(XRD_ReferencePath(6)+":k"),pl=$(XRD_ReferencePath(6)+":l"),pd=$(XRD_ReferencePath(6)+":d")
    XRD_TestCheck(ph[0]==-1 && pk[0]==0 && pl[0]==2 && ((numtype(ph[1])==2 && pk[1]==-2 && pl[1]==1) || (numtype(ph[2])==2 && pk[2]==-2 && pl[2]==1)) && numtype(pd[0])==2,"v082 sorted partial indices and absent d preserved")
    XRD_TestCheck(cmpstr(XRD_HKL(NaN,1,0),"hkl不明")==0 && cmpstr(XRD_HKL(1,0,-2),"(10-2)")==0,"v082 friendly missing hkl label and existing known label")
    XRD_TestCheck(cmpstr(XRD_CandidateIdentity(6,1),XRD_CandidateIdentity(6,2))!=0,"v082 same-angle unindexed reflections retain distinct queued identities")
    Make/FREE/D/N=17501 xx=1+p*0.01,yy=5+100*exp(-((xx[p]-55.296)/0.08)^2)+40*exp(-((xx[p]-25.281)/0.08)^2)
    String path=XRD_Store(xx,yy,"missing_hkl.xy")
    XRD_Manual(path,55.296)
    XRD_TestCheck(XRD_ScoreCandidates(path,0)>0,"v082 unknown hkl participates in candidate scoring")
    Wave refs=$(path+":Candidates:refIndex"),rows=$(path+":Candidates:refPeakIndex"),scores=$(path+":Candidates:totalScore")
    Wave/T candidateTable=$(path+":Candidates:table")
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==1 && rows[i]==4)
            candidate=i
        endif
    endfor
    XRD_TestCheck(candidate>=0,"v082 unindexed source reflection is a selectable candidate")
    if(candidate<0)
        return -1
    endif
    XRD_TestCheck(strsearch(candidateTable[candidate][1],"hkl不明",0)>=0 && strsearch(candidateTable[candidate][1],"NaN",0)<0 && numtype(scores[candidate])==0,"v082 candidate label is friendly and score remains finite")
    XRD_PreviewCandidate(path,candidate)
    Wave preview=$(path+":Preview:angle")
    XRD_TestCheck(numpnts(preview)==14,"v082 preview includes indexed and unindexed source sticks")
    XRD_TestCheck(XRD_AssignCandidate(path,0,candidate,0)==0 && XRD_IsAnalysisComplete(path),"v082 unknown hkl reflection can be adopted and completes its measurement")
    XRD_TestCheck(strsearch(XRD_AssignmentSummary(path,1),"hkl不明",0)>=0,"v082 assignment label shows unknown hkl")
    XRD_Manual(path,25.281)
    XRD80_TestAdopt(path,0,1,0)
    XRD_TestCheck(XRD_PrepareLattice(path,1)==1 && NumVarOrDefault(path+":Lattice:missingHKLExcluded",0)==1,"v082 lattice preparation excludes only unindexed adopted reflection")
    Wave inputs=$(path+":Lattice:inputs")
    XRD_TestCheck(inputs[0][2]==1 && inputs[0][3]==0 && inputs[0][4]==1,"v082 known adopted hkl survives lattice preparation")
    String/G root:XRD82SavedMeasurement=path
    // The native library editor presents missing cells as text, but keeps numeric storage.
    XRD80_LibraryPanel()
    XRD80_SelectLibraryReference(1)
    String draft=XRD80_Library()+":UI:Draft"
    XRD82_OpenNumericDraft(draft)
    Wave/T ht=$(draft+":hText82"),dt=$(draft+":dText82")
    XRD_TestCheck(cmpstr(ht[4],"hkl不明")==0 && strsearch(WinRecreation("XRDLibraryNumbers",0),"hText82",0)>=0,"v082 native editor displays friendly hkl text waves")
    String saved=ht[4]
    ht[4]="typo"
    Wave dh=$(draft+":h")
    XRD_TestCheck(XRD82_CommitNumericText(draft)==-1 && numtype(dh[4])==2,"v082 invalid editor text does not change numeric missing cells")
    ht[4]=saved
    XRD_TestCheck(XRD82_CommitNumericText(draft)==0 && XRD80_ValidateReferenceDraft(draft)==0,"v082 missing hkl draft passes numeric editor and scientific validation")
    Variable revised=XRD80_SaveReferenceDraft()
    Wave revisedH=$(XRD_ReferencePath(revised)+":h")
    XRD_TestCheck(revised==7 && numtype(dh[4])==2 && numtype(revisedH[4])==2,"v082 scientific revision keeps missing hkl")
    Wave oldH=$(XRD_ReferencePath(1)+":h")
    XRD_TestCheck(numtype(oldH[4])==2 && XRD_IsAnalysisComplete(path),"v082 old adopted revision and completion survive library edit")
    // Exercise real CurveFit with an injected unknown row marked Use=1.
    XRD82_TestFitGuard(path)
    DoWindow/K XRDLibraryNumbers
    DoWindow/K XRDLibrary
    String/G $(XRD80_Library()+":referenceFolderHint")="C:__XRD_v082_no_source_folder__:"
    KillPath/Z XRDReferencePath
    SaveExperiment/C/F={1,"",0} as output+"roundtrip.pxp"
    NVAR failures=root:XRDTestFailures
    Print "v082 failures="+num2istr(failures)
    return failures
End

Function XRD82_TestFitGuard(path)
    String path
    Wave input=$(path+":Lattice:inputs")
    Redimension/N=(5,6) input
    Variable a=4.195,lambda=1.5406,i
    Variable/G $(path+":measurementWavelength")=lambda
    for(i=0;i<4;i+=1)
        input[i][0]=1;input[i][1]=2*asin(lambda*sqrt(i+1)/(2*a))*180/pi
        input[i][2]=1+(i==3);input[i][3]=(i==1 || i==2);input[i][4]=(i==2);input[i][5]=i+1
    endfor
    input[4][0]=1;input[4][1]=55.296;input[4][2]=NaN;input[4][3]=0;input[4][4]=1;input[4][5]=99
    XRD_TestCheck(XRD_FitCubic(path)==0 && abs(NumVarOrDefault(path+":Lattice:a",0)-a)<1e-6 && input[4][0]==0 && NumVarOrDefault(path+":Lattice:usedCount",0)==4,"v082 cubic guard excludes injected unknown Use=1 before real CurveFit")
    Redimension/N=(9,6) input
    Make/FREE/D hh={1,0,1,1,2,2,0,2},kk={0,0,1,0,0,1,0,0},ll={0,2,0,2,1,0,4,3}
    a=5.89
    Variable c=23.2
    for(i=0;i<8;i+=1)
        input[i][0]=1
        input[i][1]=360/pi*asin(lambda/2*sqrt(4*(hh[i]^2+hh[i]*kk[i]+kk[i]^2)/(3*a^2)+ll[i]^2/c^2))
        input[i][2]=hh[i];input[i][3]=kk[i];input[i][4]=ll[i];input[i][5]=i+1
    endfor
    input[8][0]=1;input[8][1]=55.296;input[8][2]=0;input[8][3]=NaN;input[8][4]=0;input[8][5]=99
    XRD_TestCheck(XRD_FitHexagonal(path)==0 && abs(NumVarOrDefault(path+":Lattice:a",0)-a)<1e-6 && abs(NumVarOrDefault(path+":Lattice:c",0)-c)<1e-6 && input[8][0]==0 && NumVarOrDefault(path+":Lattice:usedCount",0)==8,"v082 hexagonal guard excludes injected unknown Use=1 before real CurveFit")
End

Function XRD_VerifyV82Restored()
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    SVAR path=root:XRD82SavedMeasurement
    Variable i
    for(i=1;i<=5;i+=1)
        XRD82_Expected(i)
    endfor
    XRD_TestCheck(XRD_IsAnalysisComplete(path),"v082 assignment and completion survive actual PXP reopen")
    XRD_TestCheck(strsearch(XRD_AssignmentSummary(path,1),"hkl不明",0)>=0,"v082 friendly assignment label survives actual PXP reopen")
    XRD_TestCheck(XRD_PrepareLattice(path,1)==1 && NumVarOrDefault(path+":Lattice:missingHKLExcluded",0)==1,"v082 missing-hkl lattice exclusion survives actual PXP reopen")
    XRD_ScoreCandidates(path,1)
    Wave refs=$(path+":Candidates:refIndex")
    XRD_TestCheck(numpnts(refs)>0 && cmpstr(StrVarOrDefault(XRD80_Library()+":referenceFolderHint",""),"C:__XRD_v082_no_source_folder__:")==0,"v082 reference library remains usable with an unavailable source folder")
    Wave oldh=$(XRD_ReferencePath(1)+":h"),newh=$(XRD_ReferencePath(7)+":h")
    XRD_TestCheck(numtype(oldh[4])==2 && numtype(newh[4])==2,"v082 old and new scientific revisions preserve missing values after reopen")
    NVAR failures=root:XRDTestFailures
    Print "v082 reopened failures="+num2istr(failures)
    return failures
End
