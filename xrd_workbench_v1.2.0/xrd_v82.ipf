#pragma rtGlobals=3
// v1.2.0: explicit missing Miller indices, never inferred or zero-filled.
Function XRD82_HKLKnown(h,k,l)
    Variable h,k,l
    return numtype(h)==0 && numtype(k)==0 && numtype(l)==0
End

Function XRD82_ValidIndex(value)
    Variable value
    return numtype(value)==2 || (numtype(value)==0 && value==round(value))
End

Function XRD82_ExcludeMissingLatticeHKL(input)
    Wave input
    Variable i,excluded=0
    for(i=0;i<DimSize(input,0);i+=1)
        if(!XRD82_HKLKnown(input[i][2],input[i][3],input[i][4]))
            excluded+=(input[i][0]==1)
            input[i][0]=0
        endif
    endfor
    return excluded
End

Function XRD82_OpenNumericDraft(draft)
    String draft
    // Keep the same text waves when reopening an uncommitted numeric editor.
    if(!NumVarOrDefault(draft+":numericTextActive82",0))
        Wave hh=$(draft+":h"),kk=$(draft+":k"),ll=$(draft+":l"),dd=$(draft+":d")
        Make/O/T/N=(numpnts(hh)) $(draft+":hText82"),$(draft+":kText82"),$(draft+":lText82"),$(draft+":dText82")
        Wave/T ht=$(draft+":hText82"),kt=$(draft+":kText82"),lt=$(draft+":lText82"),dt=$(draft+":dText82")
        ht=SelectString(numtype(hh[p])==2,num2istr(hh[p]),"hkl不明")
        kt=SelectString(numtype(kk[p])==2,num2istr(kk[p]),"hkl不明")
        lt=SelectString(numtype(ll[p])==2,num2istr(ll[p]),"hkl不明")
        dt=SelectString(numtype(dd[p])==2,XRD_ExactNumber(dd[p]),"欠損")
        SetDimLabel 0,-1,h,ht
        SetDimLabel 0,-1,k,kt
        SetDimLabel 0,-1,l,lt
        SetDimLabel 0,-1,d,dt
        Variable/G $(draft+":numericTextActive82")=1
    endif
    DoWindow/K XRDLibraryNumbers
    Edit/N=XRDLibraryNumbers/W=(60,90,1060,560) $(draft+":twoTheta"),$(draft+":intensity"),$(draft+":dText82"),$(draft+":hText82"),$(draft+":kText82"),$(draft+":lText82") as "参照の下書き — 指数不明は hkl不明 / d不明は 欠損"
    ModifyTable/W=XRDLibraryNumbers width=130
    return 0
End

Function XRD82_CommitNumericText(draft)
    String draft
    if(!NumVarOrDefault(draft+":numericTextActive82",0))
        return 0
    endif
    Wave hh=$(draft+":h"),kk=$(draft+":k"),ll=$(draft+":l"),dd=$(draft+":d")
    Wave/T ht=$(draft+":hText82"),kt=$(draft+":kText82"),lt=$(draft+":lText82"),dt=$(draft+":dText82")
    Variable n=numpnts(hh),i,j,value
    if(numpnts(ht)!=n || numpnts(kt)!=n || numpnts(lt)!=n || numpnts(dt)!=n)
        return -1
    endif
    Make/FREE/D/N=(n,4) parsed=NaN
    String token,number="^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$"
    for(i=0;i<n;i+=1)
        for(j=0;j<4;j+=1)
            switch(j)
                case 0:
                    token=ht[i]
                    break
                case 1:
                    token=kt[i]
                    break
                case 2:
                    token=lt[i]
                    break
                case 3:
                    token=dt[i]
                    break
            endswitch
            token=TrimString(token)
            if((j<3 && (cmpstr(token,"hkl不明")==0 || cmpstr(token,"-")==0 || cmpstr(LowerStr(token),"none")==0)) || (j==3 && cmpstr(token,"欠損")==0))
                continue
            endif
            value=str2num(token)
            if(!GrepString(token,number) || numtype(value)!=0 || (j<3 && value!=round(value)) || (j==3 && value<=0))
                return -1
            endif
            parsed[i][j]=value
        endfor
    endfor
    // Nothing is written back until all text cells have passed validation.
    hh=parsed[p][0];kk=parsed[p][1];ll=parsed[p][2];dd=parsed[p][3]
    return 0
End
