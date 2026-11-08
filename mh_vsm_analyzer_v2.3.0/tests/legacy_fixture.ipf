#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

Function MHC_CreateLegacy(output)
    String output
    HMH_Import(output+"MH-044-x=0-1200inAir_26-11-07-18_33_52.VSM")
    Wave/T paths=root:MHApp:paths,names=root:MHApp:names,list=root:MHApp:listText
    String base=paths[0]
    names[0]="旧測定 サンプル";list[0][1]=names[0]
    Wave h=$(base+"H_Oe"),m=$(base+"M_emu"),x=$(base+"H_kOe"),y=$(base+"M_emu_g")
    SetScale/P x,2,0.25,"index",h
    SetScale d,0,0,"Oe",h
    SetDimLabel 0,0,first,h
    SetDimLabel 0,10,last,h
    Note/K h,"raw field; retain all metadata"
    m[3]=NaN
    SetScale d,0,0,"emu",m
    Note/K m,"NaN is a missing measurement"
    Make/O/D/N=11 $(base+"dependent")
    Wave dependent=$(base+"dependent")
    SetFormula dependent,base+"H_Oe*2"
    Make/O/T/N=3 $(base+"labels")
    Wave/T labels=$(base+"labels")
    labels[0]="条件A";labels[1]="space and ; punctuation";labels[2]=""
    Note/K labels,"text wave metadata"
    Make/O/D/N=(2,3,2) $(base+"cube")
    Wave cube=$(base+"cube")
    cube=p+10*q+100*r
    cube[1][2][1]=NaN
    SetScale/P y,1,2,"secondary",cube
    SetDimLabel 1,1,center,cube
    Note/K cube,"3D fixture"
    String/G $(base+"customString")="原値保持テスト"
    Variable/G $(base+"customNumber")=12.3456789012345
    NewDataFolder/O root:UnrelatedResearch
    Make/O/D/N=5 root:UnrelatedResearch:wave0={1,2,NaN,4,5}
    String/G root:UnrelatedResearch:note="outside MH"
    HMH_DrawGraph(0)
    SVAR win=root:MHApp:lastGraph
    ModifyGraph/W=$win gfSize=26
    SetAxis/W=$win bottom -4,4
    Legend/W=$win/C/N=HMHLegend1 "旧版の手編集凡例"
    TextBox/W=$win/C/N=CustomLabel "legacy annotation"
    SetDrawLayer/W=$win UserFront
    SetDrawEnv/W=$win xcoord=bottom,ycoord=left,arrow=1,linefgc=(0,0,50000)
    DrawLine/W=$win 2,8,1,3
    String folder=HMG_AddFolder("home","旧フォルダ")
    Wave/T ids=root:MHApp:Manager:datasetUID
    HMG_Move("data",ids[0],folder)
    HMG_Move("graph",GetUserData(win,"","HMHGraphUID"),folder)
    SavePICT/WIN=$win/O/E=-5/B=72 as output+"legacy_graph.png"
    SaveExperiment/C/F={1,"",0} as output+"legacy.pxp"
    Print "LEGACY_CREATED",GetRTError(1)
End
