#pragma rtGlobals=3
Function XRD_RunV53Tests(fixtures,output)
    String fixtures,output
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    XRD_NewProject()
    String project=XRD_Project()
    NewPath/O/Q XRDReferencePath,fixtures
    XRD_TestCheck(XRD_LoadReferences()==5,"three QS and two Y cards load independently")
    Make/FREE/D/N=4001 xx=20+0.01*p,yy=2+100*exp(-((xx[p]-30.11)/0.07)^2)+40*exp(-((xx[p]-44)/0.07)^2)
    String path=XRD_Store(xx,yy,"nearby_reflections.xy")
    XRD_Manual(path,30.11)
    XRD_Manual(path,44)
    XRD_ScoreCandidates(path,0)
    Wave refs=$(path+":Candidates:refIndex"),rows=$(path+":Candidates:refPeakIndex"),shifts=$(path+":Candidates:shift")
    Wave/T table=$(path+":Candidates:table")
    Variable i,a=-1,b=-1,alternative=-1,nearest=-1,countA=0
    for(i=1;i<=5;i+=1)
        if(cmpstr(StrVarOrDefault(XRD_ReferencePath(i)+":cardNumber",""),"QS-A")==0)
            a=i
        elseif(cmpstr(StrVarOrDefault(XRD_ReferencePath(i)+":cardNumber",""),"QS-B")==0)
            b=i
        endif
    endfor
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==a)
            countA+=1
            if(rows[i]==1)
                alternative=i
            elseif(rows[i]==0)
                nearest=i
            endif
        endif
    endfor
    XRD_TestCheck(a>0 && b>0 && a!=b,"same type retains separate card identities")
    XRD_TestCheck(countA==2 && nearest>=0 && alternative>=0,"one card emits both nearby reflections instead of nearest only")
    XRD_TestCheck(abs(shifts[nearest]-shifts[alternative])<1e-12,"alternatives from one card share one whole-pattern shift")
    XRD_TestCheck(strsearch(table[alternative][1],"(110)",0)>=0 && abs(str2num(table[alternative][2]))>0.2,"alternative exposes distinct hkl and signed angular difference")
    XRD_TestCheck(strsearch(table[alternative][3],"一致幅外",0)>=0,"outside match tolerance is labelled for manual inspection")
    XRD_TestCheck(XRD_AssignCandidate(path,0,alternative,0)==0,"user may explicitly adopt the non-nearest reflection")
    Wave ar=$(path+":Assignments:refIndex"),ap=$(path+":Assignments:refPeakIndex"),aid=$(path+":Assignments:peakID")
    XRD_TestCheck(ar[0]==a && ap[0]==1,"assignment stores chosen card and chosen reflection")
    XRD_Undo()
    XRD_TestCheck(numpnts(ar)==0,"non-nearest reflection adoption is undoable")
    XRD_Redo()
    XRD_TestCheck(numpnts(ar)==1 && ap[0]==1,"non-nearest reflection adoption is redoable")
    XRD_TypePanel()
    String draft="root:Packages:XRDWorkbench:UI:TypeDraft"
    Wave map=$(draft+":map"),selection=$(draft+":selection"),modes=$(draft+":modes"),single=$(draft+":singleRef"),enabled=$(draft+":enabled")
    Variable bRow=-1,aRow=-1
    for(i=0;i<numpnts(map);i+=1)
        if(map[i]==a)
            aRow=i
        elseif(map[i]==b)
            bRow=i
        endif
    endfor
    XRD_TestCheck(numpnts(map)==3 && aRow>=0 && bRow>=0,"QS chooser lists all three cards and excludes Y cards")
    STRUCT WMPopupAction pa
    pa.eventCode=2;pa.popNum=2
    XRD_TypeModePopup(pa)
    selection[bRow][0]=48
    STRUCT WMListboxAction lba
    lba.eventCode=13;lba.row=bRow;lba.col=0
    XRD_TypeCardAction(lba)
    XRD_TestCheck(single[3]==b && selection[aRow][0]==32,"single mode switches to clicked card and unchecks the others")
    XRD_TestCheck(XRD_TypeCardAllowed(a)==1,"draft changes do not affect live candidates before apply")
    XRD_TestCheck(XRD_ApplyTypeDraft()==0 && !XRD_TypeCardAllowed(a) && XRD_TypeCardAllowed(b),"single-card QS policy applies to candidate generation")
    XRD_TestCheck(numpnts(aid)==1 && ar[0]==a,"excluding a reference does not erase prior identification")
    Variable blocked=-1
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==a)
            blocked=i
            break
        endif
    endfor
    XRD_TestCheck(blocked>=0 && XRD_AssignCandidate(path,0,blocked,0)==-3,"stale candidate cannot adopt a card excluded by current family policy")
    XRD_ScoreCandidates(path,0)
    Variable onlyB=1
    for(i=0;i<numpnts(refs);i+=1)
        if(cmpstr(XRD_ReferenceType(refs[i]),"QS-type")==0 && refs[i]!=b)
            onlyB=0
        endif
    endfor
    XRD_TestCheck(onlyB,"candidate rows use only chosen QS card")
    pa.popNum=1
    XRD_TypeModePopup(pa)
    selection[aRow][0]=48;lba.row=aRow
    XRD_TypeCardAction(lba)
    XRD_ApplyTypeDraft()
    XRD_TestCheck(XRD_TypeCardAllowed(a) && XRD_TypeCardAllowed(b),"multiple mode permits two selected QS cards")
    Variable third=0
    for(i=0;i<numpnts(map);i+=1)
        if(map[i]!=a && map[i]!=b)
            third=map[i]
        endif
    endfor
    XRD_TestCheck(!XRD_TypeCardAllowed(third),"unchecked QS card stays out of multiple mode")
    NVAR family=$(draft+":family")
    family=6
    XRD_TypeDraftTable()
    XRD_TestCheck(numpnts(map)==2,"Y-type can be configured separately")
    XRD_TestCheck(XRD_TypeCardAllowed(map[0]) && XRD_TypeCardAllowed(map[1]),"QS policy does not change Y-type selection")
    family=3
    XRD_TypeDraftTable()
    STRUCT WMButtonAction ba
    ba.eventCode=2;ba.ctrlName="noCards"
    XRD_TypeButton(ba)
    XRD_ApplyTypeDraft()
    XRD_TestCheck(!XRD_TypeCardAllowed(a) && !XRD_TypeCardAllowed(b),"explicit all-off is preserved instead of silently enabling cards")
    ba.ctrlName="allCards"
    XRD_TypeButton(ba)
    XRD_ApplyTypeDraft()
    XRD_TestCheck(XRD_TypeCardAllowed(a) && XRD_TypeCardAllowed(third),"all-cards action restores multiple selection")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDTypeCards as output+"type_cards_v053.png"
    DoWindow/K XRDTypeCards
    NVAR step=$(project+":activeStep"),selected=$(path+":selectedPeakRow")
    selected=0;step=3
    XRD_TestDisableFollow()
    XRD_Panel()
    DoUpdate
    XRD_TestCheck(strsearch(WinRecreation("XRDWorkbench",0),"widths={140,110,65",0)>=0,"responsive layout preserves separate readable hkl and delta columns")
    SavePICT/O/E=-5/SNAP=1/WIN=XRDWorkbench as output+"candidates_v053.png"
    NVAR radius=$(project+":candidateRadius")
    radius=0.05
    XRD_ScoreCandidates(path,0)
    countA=0
    for(i=0;i<numpnts(refs);i+=1)
        if(refs[i]==a && rows[i]==1)
            countA+=1
        endif
    endfor
    XRD_TestCheck(countA==0,"narrower search radius removes the distant alternative")
    radius=NaN
    XRD_TestCheck(XRD_ScoreCandidates(path,0)==-2,"invalid search radius cannot emit every reference row")
    radius=0.6
    XRD_TypePanel()
    pa.popNum=2
    XRD_TypeModePopup(pa)
    selection[bRow][0]=48;lba.row=bRow
    XRD_TypeCardAction(lba)
    XRD_ApplyTypeDraft()
    DoWindow/K XRDTypeCards
    NewPath/O/Q XRDReferencePath,fixtures+"extra:"
    XRD_TestCheck(XRD_LoadReferenceFile("QS-D.txt",6)==0,"additional same-type card imports without replacing existing cards")
    Wave liveModes=$(project+":TypeSelection:modes")
    liveModes[3]=0
    XRD_TestCheck(!XRD_TypeCardAllowed(6) && XRD_TypeCardAllowed(b),"newly imported card does not bypass configured multiple selection")
    liveModes[3]=1
    SaveExperiment/C/F={1,"",0} as output+"type_selection.pxp"
    XRD_NewProject()
    Wave freshModes=$(XRD_Project()+":TypeSelection:modes")
    XRD_TestCheck(freshModes[3]==0,"new project has independent default type policy")
    XRD_TestCheck(GetRTError(1)==0,"reference selection and multiple reflections leave no runtime error")
    NVAR failures=root:XRDTestFailures
    Print "v0.5.3 tests failures="+num2str(failures)
End

Function XRD_V53Persistence(saved)
    String saved
    LoadData/O/Q/R saved
    Variable/G root:XRDTestFailures=0
    XRD_Init()
    Wave modes=$(XRD_Project()+":TypeSelection:modes"),single=$(XRD_Project()+":TypeSelection:singleRef")
    XRD_TestCheck(modes[3]==1 && single[3]>0,"single-card family mode persists through save reload")
    XRD_TestCheck(XRD_TypeCardAllowed(single[3]),"saved selected card remains eligible")
    XRD_TestCheck(NumVarOrDefault(XRD_Project()+":candidateRadius",0)==0.6,"candidate search radius persists")
End
