"""Create synthetic schema-1 data with the old release; compare every old field after real restarts."""
import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import numpy as np
from studio.document import load_document,save_document


def fingerprint(value):
    if isinstance(value,np.ndarray):return {'dtype':str(value.dtype),'shape':list(value.shape),'bytes':base64.b64encode(value.tobytes()).decode()}
    if isinstance(value,dict):return {k:fingerprint(v) for k,v in value.items()}
    if isinstance(value,(list,tuple)):return [fingerprint(v) for v in value]
    if isinstance(value,np.generic):return value.item()
    return value


def compare_old(expected,actual,path='state'):
    if isinstance(expected,dict):
        if not isinstance(actual,dict):raise AssertionError(path)
        for key,value in expected.items():
            if key not in actual:raise AssertionError(path+'/'+key+' missing')
            compare_old(value,actual[key],path+'/'+key)
    elif isinstance(expected,list):
        if len(expected)!=len(actual):raise AssertionError(path+' length')
        for i,(a,b) in enumerate(zip(expected,actual)):compare_old(a,b,path+'/'+str(i))
    elif expected!=actual:raise AssertionError(path+' differs')


def run(legacy_root,output):
    legacy_root=Path(legacy_root).resolve();output=Path(output).resolve()
    code='''
from pathlib import Path
import json,sys,base64
import numpy as np
from studio.document import Document,save_document
from studio import demo,analysis
def fp(value):
    if isinstance(value,np.ndarray):return {'dtype':str(value.dtype),'shape':list(value.shape),'bytes':base64.b64encode(value.tobytes()).decode()}
    if isinstance(value,dict):return {k:fp(v) for k,v in value.items()}
    if isinstance(value,(list,tuple)):return [fp(v) for v in value]
    if isinstance(value,np.generic):return value.item()
    return value
d=Document();demo.populate(d.state);sid=next(iter(d.state['samples']))
d.change('detect',lambda st:analysis.detect_peaks(st['samples'][sid],st['samples'][sid]['parameters']))
s=d.state['samples'][sid]
for p in s['peaks']:
    cs=analysis.score_candidates(s,d.state['references'],p['id'],s['parameters']);analysis.assign(s,p['id'],cs[0])
p=s['peaks'][0];analysis.fit_profile(s,p['id'],p['angle']-.4,p['angle']+.4);analysis.adopt_profile(s,p['id'])
analysis.fit_lattice(s,next(iter(d.state['references'].values())))
second=list(d.state['samples'].values())[1]
analysis.detect_peaks(second,second['parameters']);analysis.assign(second,second['peaks'][0]['id'])
import copy,uuid
unknown=copy.deepcopy(next(iter(d.state['references'].values())))
unknown['id']=uuid.uuid4().hex;unknown['revision']=uuid.uuid4().hex;unknown['h'][:]=np.nan
d.state['references'][unknown['id']]=unknown
s['serial']='015';save_document(d,Path(sys.argv[1])/'legacy.labx')
(Path(sys.argv[1])/'expected.json').write_text(json.dumps({'state':fp(d.state),'undo':fp(d.undo_stack),'redo':fp(d.redo_stack)}),encoding='utf-8')
'''
    with tempfile.TemporaryDirectory() as directory:
        env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1');env.pop('PYTHONPATH',None)
        subprocess.run([sys.executable,'-c',code,directory],cwd=legacy_root,env=env,check=True,capture_output=True)
        root=Path(directory);before=(root/'legacy.labx').read_bytes();expected=json.loads((root/'expected.json').read_text())
        document=load_document(root/'legacy.labx')
        compare_old(expected['state'],fingerprint(document.state));compare_old(expected['undo'],fingerprint(document.undo_stack));compare_old(expected['redo'],fingerprint(document.redo_stack))
        save_document(document,root/'new.labx')
        # New process, no original source files present or required by the document.
        child="from studio.document import load_document; from tests.compatibility_check import fingerprint; import json,sys; d=load_document(sys.argv[1]); print(json.dumps({'state':fingerprint(d.state),'undo':fingerprint(d.undo_stack),'redo':fingerprint(d.redo_stack)}))"
        # The test folder need not be an importable package.
        child=child.replace('from tests.compatibility_check import fingerprint','import runpy; fingerprint=runpy.run_path(\"tests/compatibility_check.py\")[\"fingerprint\"]')
        result=subprocess.run([sys.executable,'-c',child,str(root/'new.labx')],cwd=Path(__file__).resolve().parents[1],check=True,text=True,capture_output=True)
        actual=json.loads(result.stdout)
        for key in ['state','undo','redo']:compare_old(expected[key],actual[key],key)
        if before!=(root/'legacy.labx').read_bytes():raise AssertionError('Old document was modified')
    report={'status':'PASS','schema1_to_schema2':True,'separate_processes':3,'all_original_fields_equal':True,
        'raw_arrays_units_ids_references_assignments_profiles_lattice_undo_redo_preserved':True,'original_file_unchanged':True,
        'data':'Artificial cubic data only; not user PXP compatibility'}
    output.write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('legacy_root');p.add_argument('output');args=p.parse_args();run(args.legacy_root,args.output)
