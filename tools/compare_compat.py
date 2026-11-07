"""Compare semantic data fields in private native Igor compatibility fixtures."""
from pathlib import Path
import json
import sys
import numpy as np
from igor2 import packed
from PIL import Image, ImageChops

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
    for name in ['after_init_graph.png','reopened_legacy_graph.png']:
        current=Image.open(root/name).convert('RGB')
        equal=reference.size==current.size and ImageChops.difference(reference,current).getbbox() is None
        result[name]={'pixel_identical':equal,'size':reference.size}
        if not equal:
            raise AssertionError(name+' differs from the legacy graph')
    (root/'scratch/compat_comparison.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    main(sys.argv[1])
