"""Compare all fields in private native Igor dumps without publishing research data."""
from pathlib import Path
import gc,json,sys

base=Path(sys.argv[1])
def load(path):
    records={}
    with path.open('rb') as f:
        for line in f:
            key,value=line.rstrip(b'\r\n').split(b'\t',1)
            if key in records:raise ValueError('Duplicate semantic record')
            records[key]=value
    return records
def display(key):
    return '|root:Packages:XRDWorkbench:UI:' in key or key=='S|root:Packages:XRDWorkbench:Recovery:message'
summary={}
for left,right,label in [('baseline','preinit','code_load'),('baseline','postinit','initialization'),('postinit','reopened','save_restart_reopen')]:
    old=load(base/(left+'.tsv'));before=len(old);changes=[];after=0
    with (base/(right+'.tsv')).open('rb') as f:
        for line in f:
            key,value=line.rstrip(b'\r\n').split(b'\t',1);previous=old.pop(key,None);after+=1
            if previous!=value:changes.append({'key':key.decode('ascii'),'before':None if previous is None else previous.decode('ascii'),'after':value.decode('ascii')})
    changes.extend({'key':k.decode('ascii'),'before':v.decode('ascii'),'after':None} for k,v in old.items())
    unexpected=[c for c in changes if not display(c['key'])]
    summary[label]={'before_records':before,'after_records':after,'display_differences':len(changes)-len(unexpected),'scientific_differences':len(unexpected)}
    (base/(label+'_differences.json')).write_text(json.dumps(changes,indent=2),'utf-8')
    print(label,json.dumps(summary[label]))
    if unexpected:
        print('Unexpected field keys:',[c['key'] for c in unexpected[:10]])
        raise AssertionError('Unexpected non-display data changes')
    del old;gc.collect()
(base/'verified_summary.json').write_text(json.dumps(summary,indent=2)+'\n','utf-8')
