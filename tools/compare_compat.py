"""Compare semantic data fields in private native Igor compatibility fixtures."""
from pathlib import Path
import json
import sys
import numpy as np
from igor2 import packed
from PIL import Image

WAVE_FIELDS = ['wData','formula','note','data_units','dimension_units','labels','sIndices']
HEADER_FIELDS = ['npnts','type','bname','nDim','sfA','sfB','dataUnits','dimUnits','fsValid','topFullScale','botFullScale']

def same(a,b):
    if isinstance(a,dict):
        return isinstance(b,dict) and a.keys()==b.keys() and all(same(a[k],b[k]) for k in a)
    if isinstance(a,(list,tuple)):
        return isinstance(b,(list,tuple)) and len(a)==len(b) and all(same(x,y) for x,y in zip(a,b))
    if isinstance(a,np.ndarray):
        if not isinstance(b,np.ndarray) or a.shape!=b.shape or a.dtype!=b.dtype:
            return False
        if np.issubdtype(a.dtype,np.number):
            return np.array_equal(a,b,equal_nan=True)
        return np.array_equal(a,b)
    if isinstance(a,(float,np.floating)) and isinstance(b,(float,np.floating)) and np.isnan(a) and np.isnan(b):
        return True
    return bool(a==b)

def flatten(folder,prefix='root'):
    result={}
    for key,value in folder.items():
        key=key.decode('utf-8') if isinstance(key,bytes) else key
        path=f'{prefix}:{key}'
        if isinstance(value,dict):
            result[path]={'folder':True}
            result.update(flatten(value,path))
        elif type(value).__name__=='WaveRecord':
            wave=value.wave['wave']
            result[path]={k:wave[k] for k in WAVE_FIELDS}
            result[path]['header']={k:wave['wave_header'][k] for k in HEADER_FIELDS}
        else:
            result[path]={'value':value}
    return result

def selected(file):
    _,fs=packed.load(str(file))
    records=flatten(fs['root'])
    return {p:v for p,v in records.items() if (p=='root:MHApp' or p.startswith('root:MHApp:') or p=='root:UnrelatedResearch' or p.startswith('root:UnrelatedResearch:')) and not p.startswith('root:MHApp:Manager')}

def graph_commands(file):
    records,_=packed.load(str(file))
    record=next(r for r in records if type(r).__name__=='RecreationRecord')
    raw=getattr(record,'text',record.data)
    text=raw.decode('utf-8') if isinstance(raw,bytes) else raw
    start=text.index('Window MH_Single')
    text=text[start:text.index('EndMacro',start)+len('EndMacro')]
    # Only these two intentional identity/persistence additions are permitted.
    return [line for line in text.splitlines() if 'hook(HMGStore)=HMG_WindowHook' not in line and 'userdata(HMHGraphUID)=' not in line]

def main(directory):
    root=Path(directory)
    baseline=selected(root/'legacy.pxp')
    result={}
    for name in ['loaded_before_init.pxp','upgraded.pxp','upgraded_reopened.pxp']:
        candidate=selected(root/name)
        differences=[]
        checked=0
        for path,fields in baseline.items():
            if path not in candidate:
                differences.append(path+': missing')
                continue
            for field,value in fields.items():
                checked+=1
                if not same(value,candidate[path].get(field)):
                    differences.append(path+': '+field)
        extra=sorted(candidate.keys()-baseline.keys())
        result[name]={'records':len(baseline),'field_groups_compared':checked,'differences':differences,'additional_existing_scope_records':extra}
        if differences or extra:
            raise AssertionError(json.dumps(result,indent=2))
    reference=Image.open(root/'legacy_graph.png').convert('RGB')
    reference_commands=graph_commands(root/'legacy.pxp')
    for name in ['loaded_before_init.pxp','upgraded.pxp','upgraded_reopened.pxp']:
        equal=reference_commands==graph_commands(root/name)
        result[name]['graph_commands_unchanged_except_identity_hook']=equal
        if not equal:
            raise AssertionError(name+' changes graph commands')
    arrays=[]
    for name in ['after_init_graph.png','reopened_legacy_graph.png']:
        current=Image.open(root/name).convert('RGB')
        a=np.array(reference);b=np.array(current)
        equal=reference.size==current.size and np.array_equal(a,b)
        black_equal=np.array_equal(np.all(a==0,axis=2),np.all(b==0,axis=2))
        white_equal=np.array_equal(np.all(a==255,axis=2),np.all(b==255,axis=2))
        delta=int(np.abs(a.astype(int)-b.astype(int)).max())
        result[name]={'pixel_identical':equal,'solid_black_mask_identical':black_equal,'white_mask_identical':white_equal,'max_antialias_channel_difference':delta,'size':reference.size}
        if not black_equal or not white_equal:
            raise AssertionError(name+' changes rendered geometry')
        arrays.append(b)
    result['initialized_vs_restarted_image_pixel_identical']=np.array_equal(*arrays)
    if not result['initialized_vs_restarted_image_pixel_identical']:
        raise AssertionError('Restart changes the rendered graph')
    (root/'scratch/compat_comparison.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    main(sys.argv[1])
