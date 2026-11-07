from pathlib import Path
import re
p=Path(__file__).resolve().parents[1]
modules=['MH_VSM_Analyzer','mh_figure','mh_axis','mh_store','mh_graph_store','mh_tree','mh_arrow']
parts=[]
for i,name in enumerate(modules):
    text=(p/'src'/f'{name}.ipf').read_text(encoding='utf-8')
    text=re.sub(r'^#include .*\n','',text,flags=re.M)
    if i:
        text=re.sub(r'^#pragma (?:rtGlobals|version)=.*\n','',text,flags=re.M)
    parts.append('// ---- '+name+' ----\n'+text)
out=p/'MH_VSM_Analyzer_v2_2_0.ipf'
out.write_text('#pragma TextEncoding = "UTF-8"\n'+ '\n'.join(parts),encoding='utf-8')
print(out.name)
