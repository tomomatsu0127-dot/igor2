#pragma rtGlobals=3
// Run in a disposable Experiment. Never run this suite in a user's working Experiment.
Function XRD_RunV80LibraryTests(fixtures)
    String fixtures
    XRD_Init()
    String project=XRD_Project(),lib=XRD80_Library(),rp,oldUID,oldRevision,stem,draft
    NewPath/O/Q XRDReferencePath,fixtures
    Variable count=NumVarOrDefault(lib+":referenceCount",0)
    XRD_TestCheck(XRD_LoadReferenceFile("QS-A.txt",count+1)==0,"shared library imports named-column reference")
    Variable first=NumVarOrDefault(lib+":referenceCount",0)
    rp=XRD_ReferencePath(first)
    XRD_TestCheck(strsearch(rp,":SharedLibrary:References:",0)>0,"reference storage belongs to Experiment library")
    XRD_LoadReferenceFile("QS-A.txt",first+1)
    XRD_TestCheck(NumVarOrDefault(lib+":referenceCount",0)==first,"identical content import is idempotent")
    oldUID=StrVarOrDefault(rp+":refUID","")
    oldRevision=StrVarOrDefault(rp+":revisionUID","")
    stem=StrVarOrDefault(rp+":waveStem","")
    Wave/T reflectionUID=$(rp+":reflectionUID")
    Wave tt=$(rp+":twoTheta"),prefixed=$(rp+":tt_"+stem)
    Variable oldCRC=WaveCRC(0,tt)
    XRD_TestCheck(strlen(oldUID)>0 && strlen(oldRevision)>0 && numpnts(reflectionUID)==numpnts(tt),"reference revision and reflection identities are persisted")
    XRD_TestCheck(WaveExists(prefixed) && XRD80_SameReferenceWave(tt,prefixed),"prefixed tt alias matches canonical angle wave")
    Variable savedAngle=tt[0]
    tt[0]=savedAngle+0.002
    DoUpdate
    XRD_TestCheck(prefixed[0]==tt[0],"prefixed aliases follow canonical wave changes without a second numeric master")
    tt[0]=savedAngle
    DoUpdate
    Variable/G $(rp+":enabled")=0
    XRD80_LibraryChanged()
    XRD_NewProject()
    String second=XRD_Project()
    XRD_TestCheck(!XRD80_LibraryReferenceEnabled(first) && cmpstr(XRD_ReferencePath(first),rp)==0,"enabled choice is Experiment-wide after changing project")
    XRD_TestCheck(NumVarOrDefault(second+":referenceCount",0)==NumVarOrDefault(lib+":referenceCount",0),"project count mirror reflects common library")
    Variable/G $(rp+":enabled")=1
    XRD80_LibraryPanel()
    XRD80_SelectLibraryReference(first)
    draft=lib+":UI:Draft"
    Wave draftTT=$(draft+":twoTheta")
    draftTT[0]+=0.001
    String/G $(draft+":displayOverride")="QS-type edited"
    Variable revised=XRD80_SaveReferenceDraft()
    String newer=XRD_ReferencePath(revised)
    XRD_TestCheck(revised>first && cmpstr(StrVarOrDefault(newer+":refUID",""),oldUID)==0 && cmpstr(StrVarOrDefault(newer+":revisionUID",""),oldRevision)!=0,"scientific edit appends a revision of the same reference identity")
    XRD_TestCheck(WaveCRC(0,tt)==oldCRC && cmpstr(StrVarOrDefault(rp+":revisionUID",""),oldRevision)==0,"historical scientific wave and revision identity remain unchanged")
    XRD_TestCheck(!XRD80_LibraryReferenceEnabled(first) && XRD80_LibraryReferenceEnabled(revised),"new candidates use current enabled revision while old revision remains stored")
    XRD_TestCheck(cmpstr(StrVarOrDefault(newer+":waveStem",""),stem)==0,"display-name change does not rename the wave stem")
    DuplicateDataFolder $newer,$(second+":References:Ref1")
    Variable migrated=XRD80_ImportLegacyReferences(second)
    Wave map=$(second+":ReferenceMigration:legacyToGlobal")
    Variable afterMigration=NumVarOrDefault(lib+":referenceCount",0)
    XRD_TestCheck(migrated==1 && map[0]==revised,"legacy owner and local index map to exact shared revision")
    XRD_TestCheck(XRD80_ImportLegacyReferences(second)==0 && NumVarOrDefault(lib+":referenceCount",0)==afterMigration,"legacy migration can be repeated without duplicates")
    XRD_TestCheck(DataFolderExists(second+":References:Ref1"),"migration preserves legacy folders for old native graph bindings")
    String/G $(lib+":referenceFolderHint")=fixtures
    String addedFiles=XRD80_NewReferenceFiles()
    XRD_TestCheck(WhichListItem("QS-B.txt",addedFiles)>=0 && WhichListItem("QS-A.txt",addedFiles)<0,"new-file scan finds additions without offering cached filenames again")
    String/G $(lib+":referenceFolderHint")="C:__XRD_missing_folder__ :"
    XRD_TestCheck(strlen(XRD80_NewReferenceFiles())==0 && WaveExists(tt),"missing original folder does not prevent use of cached references")
    DoWindow/K XRDLibrary
    DoWindow/K XRDLibraryNumbers
    DoWindow/K XRDLibraryPattern
    return 0
End
