"""Apply the reviewed v1.3.0 changes only to the new release directory."""
from pathlib import Path
import re

root=Path(__file__).resolve().parents[1]/'xrd_workbench_v1.3.0'
def edit(name,old,new,count=1):
    p=root/name;s=p.read_text('utf-8-sig')
    assert s.count(old)==count,(name,old[:100],s.count(old),count)
    p.write_text(s.replace(old,new),'utf-8')

# Keep auxiliary windows independent of maximized MDI graphs, but hide them
# whenever another Windows application is activated (Igor 9 /FLTH=1).
for p in root.glob('*.ipf'):
    s=p.read_text('utf-8-sig')
    s=s.replace('/FLT=1','/FLT=1/FLTH=1')
    p.write_text(s,'utf-8')
edit('xrd_main.ipf','#pragma version=1.29','#pragma version=1.30')
edit('xrd_main.ipf','#include ":xrd_transfer120"','#include ":xrd_transfer120"\n#include ":xrd_v130"')
for name in ('xrd_main.ipf','xrd_ui.ipf','xrd_ui120.ipf'):
    p=root/name;s=p.read_text('utf-8');s=s.replace('v1.2.9','v1.3.0').replace('"1.2.3"','"1.3.0"');p.write_text(s,'utf-8')

# Registration: retain the import/copy engine for old experiments, remove its UI.
edit('xrd_entry110.ipf','    Button copy120,pos={210,194},size={458,28},title="他プロジェクトの同定済み試料から追加…",proc=XRD120_CopyButton\n','')
edit('xrd_entry110.ipf','        Button copy120,disable=2\n','')
edit('xrd_entry110.ipf','    TitleBox fileName,win=XRDRegister110,title=ParseFilePath(0,chosen,":",1,0)',
'''    String serial130=XRD130_FileSerial(chosen)
    if(strlen(serial130))
        String/G $(base+":number")=serial130
        ControlUpdate/W=XRDRegister110 number
    endif
    XRD110_EntryPreview()
    TitleBox fileName,win=XRDRegister110,title=ParseFilePath(0,chosen,":",1,0)''')
edit('xrd_ui110.ipf','    Button projects110,win=XRDWorkbench,pos={116,6},size={100,20},title="プロジェクト一覧",proc=XRD110_Button','    KillControl/W=XRDWorkbench projects110')
edit('xrd_ui110.ipf','    Button projects110,win=XRDWorkbench,pos={116*scale,6*scale},size={100*scale,20*scale}\n','')
edit('xrd_ui110.ipf','{230*scale,6*scale},size={w-242*scale,20*scale}','{116*scale,6*scale},size={w-128*scale,20*scale}')
edit('xrd_ui110.ipf','{230*scale,6*scale},size={V_right-242*scale,20*scale}','{116*scale,6*scale},size={V_right-128*scale,20*scale}')
edit('xrd_ui110.ipf','    if(step!=3 || (s.eventMod & 16)', '    if((step!=1 && step!=3) || (s.eventMod & 16)')
edit('xrd_ui110.ipf','        Button detectorSettings,win=XRDWorkbench,pos={16,340}', '''        XRD_EnsureNumeric(path+":zoomHalf130",5)
        SetVariable peakZoom130,win=XRDWorkbench,pos={16,380},size={175,22},title="選択時の拡大 ±(deg)",limits={0.01,30,0.5},value=$(path+":zoomHalf130")
        Button detectorSettings,win=XRDWorkbench,pos={16,340}''')
edit('xrd_view100.ipf','if(gesture && NumVarOrDefault(XRD_Project()+":activeStep",1)==3 &&', 'if(gesture && (NumVarOrDefault(XRD_Project()+":activeStep",1)==1 || NumVarOrDefault(XRD_Project()+":activeStep",1)==3) &&')
edit('xrd_view100.ipf','        XRD100_Zoom(path,xx[row],NumVarOrDefault(path+":zoomSpan100",10))', '''        Variable span130=NumVarOrDefault(path+":zoomSpan100",10)
        if(NumVarOrDefault(XRD_Project()+":activeStep",1)==1)
            span130=2*NumVarOrDefault(path+":zoomHalf130",5)
        endif
        XRD100_Zoom(path,xx[row],span130)''')

# Snap newly detected, unreviewed candidates to a measured local maximum.
old='''        index=BinarySearch(xx,gx[candidates[i]])
        index=max(0,min(n-2,index))
        if(abs(xx[index+1]-gx[candidates[i]])<abs(xx[index]-gx[candidates[i]]))
            index+=1
        endif'''
edit('xrd_detect.ipf',old,'        index=XRD130_RawMaximum(xx,yy,gx[candidates[i]],max(smoothDeg,2*step)/2)')
edit('xrd_detect.ipf','prominence-sg-v1','prominence-sg-raw-apex-v2',2)
edit('xrd_autofind.ipf','''        index=max(0,min(numpnts(xx)-2,BinarySearch(xx,angle)))
        index+=abs(xx[index+1]-angle)<abs(xx[index]-angle)''', '        index=XRD130_RawMaximum(xx,yy,angle,max(NumVarOrDefault(path+":detectSmoothDeg",0.05),2*gridStep)/2)')
edit('xrd_autofind.ipf','igor-peak-autofind-v1','igor-peak-autofind-raw-apex-v2',2)

# A display cache follows the plotted measurement even for precise external angles.
edit('xrd_v71.ipf','    AppendToGraph/W=XRDWorkbench#Pattern py/TN=XRDWB_Peaks vs px', '''    XRD130_PeakDisplay(path)
    Wave displayY130=$(path+":Preview:peakDisplay130")
    AppendToGraph/W=XRDWorkbench#Pattern displayY130/TN=XRDWB_Peaks vs px''')
edit('xrd_v81.ipf','''    if(WhichListItem("XRDWB_Select",TraceNameList(win,";",1))<0)
        AppendToGraph/W=$win py/TN=XRDWB_Select vs px''','''    if(step==1)
        XRD130_PeakDisplay(path)
        Wave py=$(path+":Preview:peakDisplay130")
    endif
    if(WhichListItem("XRDWB_Select",TraceNameList(win,";",1))<0)
        AppendToGraph/W=$win py/TN=XRDWB_Select vs px''')
edit('xrd_v81.ipf','''    if(step==1)
        XRD_DetectionTable(path)''','''    if(step==1)
        XRD_DetectionTable(path)
        XRD130_PeakDisplay(path)''')

# Lattice screen: assigned markers without preview sticks, plus the comparison pane.
edit('xrd_ui.ipf','''    AppendToGraph/W=XRDWorkbench#Pattern previewY/TN=XRDWB_Preview vs previewX
    XRD_AddEvidenceTraces(path)''','''    if(step!=4)
        AppendToGraph/W=XRDWorkbench#Pattern previewY/TN=XRDWB_Preview vs previewX
        XRD_AddEvidenceTraces(path)
    endif''')
edit('xrd_ui.ipf','    ModifyGraph/W=XRDWorkbench#Pattern mode(XRDWB_Preview)=1,rgb(XRDWB_Preview)=(60000,0,0,alpha),lsize(XRDWB_Preview)=lineWidth','''    if(step!=4)
        ModifyGraph/W=XRDWorkbench#Pattern mode(XRDWB_Preview)=1,rgb(XRDWB_Preview)=(60000,0,0,alpha),lsize(XRDWB_Preview)=lineWidth
    endif''')
edit('xrd_v72.ipf','''    if(NumVarOrDefault(project+":activeStep",1)!=3 || !strlen(path))''','''    if(NumVarOrDefault(project+":activeStep",1)==4 && strlen(path))
        return XRD130_LatticeSide(path)
    endif
    if(NumVarOrDefault(project+":activeStep",1)!=3 || !strlen(path))''')
edit('xrd_v72.ipf','NumVarOrDefault(XRD_Project()+":activeStep",1)==3 && strlen(XRD_Data())','(NumVarOrDefault(XRD_Project()+":activeStep",1)==3 || NumVarOrDefault(XRD_Project()+":activeStep",1)==4) && strlen(XRD_Data())')
edit('xrd_v72.ipf','''    if(NumVarOrDefault(XRD_Project()+":activeStep",1)!=3 || !WinType("XRDWorkbench#SideCompare"))''','''    if(NumVarOrDefault(XRD_Project()+":activeStep",1)==4 && WinType("XRDWorkbench#SideCompare"))
        return XRD130_LatticeLayout(w,h,scale)
    endif
    if(NumVarOrDefault(XRD_Project()+":activeStep",1)!=3 || !WinType("XRDWorkbench#SideCompare"))''')
edit('xrd_v44.ipf','if(step==3 && strlen(path))','if((step==3 || step==4) && strlen(path))')

# Reuse the style editor instead of killing/recreating its native window.
edit('xrd_v3.ipf','''    DoWindow/K XRDStyles
    NewPanel/FLT=1/FLTH=1/K=1/N=XRDStyles/W=(70,70,560,420) as "Experiment共通の相・色・記号"''','''    if(!WinType("XRDStyles"))
        NewPanel/FLT=1/FLTH=1/K=1/N=XRDStyles/W=(70,70,560,420) as "Experiment共通の相・色・記号"
    else
        SetActiveSubwindow XRDStyles
    endif''')

# Legend order is assignment-based, independent of the style editor's filter.
p=root/'xrd_plot81.ipf';s=p.read_text('utf-8');start=s.index('Function/S XRD81_AllUsedStyles()');end=s.index('\nFunction ',start+1)
s=s[:start]+'''Function/S XRD81_AllUsedStyles()
    String paths=XRD_AllMeasurementPaths(0),keys="",indices="",rp,key
    Variable i,j,index
    for(i=0;i<ItemsInList(paths);i+=1)
        Wave/Z refs=$(StringFromList(i,paths)+":Assignments:refIndex")
        if(!WaveExists(refs))
            continue
        endif
        for(j=0;j<numpnts(refs);j+=1)
            index=refs[j]
            if(index<1)
                continue
            endif
            rp=XRD_ReferencePath(index)
            key=StrVarOrDefault(rp+":styleGroup",XRD_PhaseLabel(index))
            if(WhichListItem(key,keys)<0)
                keys+=key+";";indices+=num2istr(index)+";"
            endif
        endfor
    endfor
    XRD_SortLegendItems(XRD_Project(),keys,indices)
    return indices
End
'''+s[end:];p.write_text(s,'utf-8')

# Preserve scrolling across source-tree expansion/check changes.
edit('xrd_tree110.ipf','''    String ui=XRD_PlotRoot()+":UI",tree=XRD110_TreeBase(1)
    XRD110_TreeBuild(1)''','''    String ui=XRD_PlotRoot()+":UI",tree=XRD110_TreeBase(1)
    ControlInfo/W=XRDPlotWorkspace sourceTree
    Variable first130=V_startRow
    XRD110_TreeBuild(1)''')
edit('xrd_tree110.ipf','''    ListBox samples,win=XRDPlotWorkspace,pos={475,105}''','''    ListBox sourceTree,win=XRDPlotWorkspace,row=max(0,first130)
    ListBox samples,win=XRDPlotWorkspace,pos={475,105}''')

# All measurements can be plotted; warn before the first snapshot of each set
# of incomplete source UIDs. Existing saved recipes keep their native macros.
edit('xrd_plotworkspace.ipf','list=XRD_AllMeasurementPaths(completedOnly)','list=XRD_AllMeasurementPaths(0)')
edit('xrd_plotworkspace.ipf','作図：全プロジェクトの解析完了試料','作図：全プロジェクトの測定データ')
edit('xrd_plotworkspace.ipf','title="完了試料の一覧を更新"','title="測定データの一覧を更新"')
edit('xrd_plotworkspace.ipf','解析完了の試料がありません。登録ピークをすべて同定またはUnknownにしてください。','作図する測定データを選択してください。')
edit('xrd_plotworkspace.ipf','Function/S XRD_PlotSaveDraft(recipe)\n    String recipe','Function/S XRD_PlotSaveDraft(recipe,[warnIncomplete])\n    String recipe\n    Variable warnIncomplete')
edit('xrd_plotworkspace.ipf','if(!XRD_IsAnalysisComplete(paths[i]) || NumVarOrDefault','if(!DataFolderExists(paths[i]) || NumVarOrDefault')
edit('xrd_plotworkspace.ipf','解析完了の試料を1つ以上選び、2θの下限を上限より小さくしてください。','測定データを1つ以上選び、2θの下限を上限より小さくしてください。')
edit('xrd_plotworkspace.ipf','''    if(!strlen(recipe))
        NVAR serial=$(base+":serial")''','''    String incomplete130=XRD130_IncompletePlot(paths,flags)
    if(strlen(incomplete130) && cmpstr(StrVarOrDefault(recipe+":acknowledgedIncomplete130",""),incomplete130)!=0 && (ParamIsDefault(warnIncomplete) || warnIncomplete))
        if(XRD124_Alert(1,"同定が完了していない測定データが図に含まれます。未同定のピークを含む途中結果です。このまま作図しますか？")!=1)
            return ""
        endif
    endif
    if(!strlen(recipe))
        NVAR serial=$(base+":serial")''')
edit('xrd_plotworkspace.ipf','''    String/G $(recipe+":displayName")=StrVarOrDefault(ui+":title","XRD 比較図")''','''    String/G $(recipe+":acknowledgedIncomplete130")=incomplete130
    String/G $(recipe+":displayName")=StrVarOrDefault(ui+":title","XRD 比較図")''')
edit('xrd_plot81.ipf','            if(XRD_IsAnalysisComplete(path))','            if(DataFolderExists(path))')
edit('xrd_plot81.ipf',' && XRD_IsAnalysisComplete(map[i])','')
edit('xrd_plot81.ipf','プロジェクト内の完了試料をチェックしてください。\\r未解析・解析中の試料は表示のみです。順番は作図ウィンドウでドラッグします。','プロジェクト内の測定データをチェックしてください。\\r同定途中でも作図できます。未完了データを含む場合は作図前に確認します。')

# Comparison snapshots must include the reference values used at calculation.
edit('xrd_lattice.ipf','    XRD80_RecordLatticeRun(path)','    XRD130_ReferenceComparison(path)\n    XRD80_RecordLatticeRun(path)',2)
edit('xrd_v50.ipf','''    ListBox qualityList,pos={15,235},size={925,240}''','''    XRD130_ReferenceComparison(path)
    ListBox referenceCell130,pos={15,135},size={925,70},listWave=$(path+":Lattice:comparison130"),mode=1,widths={90,170,170,170,170}
    TitleBox conditions,pos={15,210},frame=0,title="波長 "+num2str(NumVarOrDefault(path+":Lattice:wavelength",NaN))+" Å / "+StrVarOrDefault(path+":Lattice:referenceCellSource130","参照格子定数は未収録")
    ListBox qualityList,pos={15,255},size={925,220}''')

print('Applied v1.3.0 changes to',root)
