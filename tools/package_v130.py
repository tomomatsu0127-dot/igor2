"""Create the shareable ZIP and synchronize the verified runtime documents."""
from pathlib import Path
import hashlib,json,re,shutil,zipfile

repo=Path(__file__).resolve().parents[1]
source=repo/'xrd_workbench_v1.3.0'
destination=Path(r'C:\Users\su200\Desktop\Igor2_XRD')
runtime=destination/'runtime'/source.name
distribution=destination/'配布'
distribution.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
baseline=json.loads((repo/'docs/BASELINE_FOR_v1.3.0.json').read_text('utf-8'))
assert all(sha(repo/'xrd_workbench_v1.2.9_build2'/name)==value for name,value in baseline.items()),'Old release changed'
summary=json.loads((source/'tests/results_v130/verification_summary.json').read_text('utf-8'))
assert summary['native_assertions_passed']==127 and summary['native_failures']==0
assert summary['scientific_differences']==0 and summary['saved_helper_procedures']==0
assert all(sha(p)==sha(runtime/p.name) for p in source.glob('*.ipf')),'Runtime differs from verified production code'
edges=0
for p in source.rglob('*.ipf'):
    for include in re.findall(r'^#include\s+"(:[^"\r\n]+)"',p.read_text('utf-8-sig'),re.M):
        target=p.parent/(include[1:].replace(':','/')+'.ipf')
        assert target.is_file(),(p,include)
        edges+=1
for p in (source/'tests/results_v130').glob('*.txt'):
    content=p.read_text('utf-8')
    content=content.replace(str(repo).replace('\\',':').replace('C::','C:')+':','<WORKSPACE>:')
    p.write_text(content,'utf-8')
files=sorted(p for p in source.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name!='MANIFEST_v1.3.0.json')
assert not any(p.suffix.lower() in {'.pxp','.uxp','.ibw','.pxt','.uxt','.db'} for p in files)
assert all(p.relative_to(source).as_posix()=='tests/fixtures_v051/comment_header.tsv' for p in files if p.suffix.lower()=='.tsv')
manifest={'version':'1.3.0','date_jst':'2026-11-06','branch':'codex/xrd-v1.3.0','base_commit':'fe8236e295c3d5455486257f45838b03553f2222','native_assertions_passed':127,'relative_include_edges':edges,'production_ipf_count':len(list(source.glob('*.ipf'))),'files':{p.relative_to(source).as_posix():sha(p) for p in files}}
(source/'MANIFEST_v1.3.0.json').write_text(json.dumps(manifest,indent=2)+'\n','utf-8')
files.append(source/'MANIFEST_v1.3.0.json')
for p in files:
    relative=p.relative_to(source);target=runtime/relative
    if p.parent==source and p.suffix=='.ipf':continue
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(p,target)
assert all(sha(p)==sha(runtime/p.relative_to(source)) for p in files)
archive=distribution/(source.name+'.zip')
assert not archive.exists(),'Never overwrite a distributed release'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(files):z.write(p,source.name+'/'+p.relative_to(source).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert all(z.read(source.name+'/'+p.relative_to(source).as_posix())==p.read_bytes() for p in files)
(distribution/(archive.name+'.sha256')).write_text(sha(archive)+'  '+archive.name+'\n','utf-8')
print(json.dumps({'zip':str(archive),'bytes':archive.stat().st_size,'sha256':sha(archive),'files':len(files),'production_ipfs':manifest['production_ipf_count'],'relative_includes':edges},indent=2,ensure_ascii=False))
