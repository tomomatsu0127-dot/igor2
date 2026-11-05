"""Package v1.2.9 after native and private-data compatibility verification."""
from pathlib import Path
import hashlib,json,re,shutil,sys,zipfile
repo,destination=map(Path,sys.argv[1:3]);source=repo/'xrd_workbench_v1.2.9'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
baseline=json.loads((repo/'docs/BASELINE_FOR_v1.2.9.json').read_text())
assert all(sha(repo/'xrd_workbench_v1.2.8'/p)==value for p,value in baseline.items())
edges=0
for p in source.rglob('*.ipf'):
 for include in re.findall(r'^#include\s+"(:[^"\r\n]+)"',p.read_text('utf-8-sig'),re.M):
  target=p.parent/(include[1:].replace(':','/')+'.ipf');assert target.exists(),(p,include);edges+=1
files=sorted(p for p in source.rglob('*') if p.is_file() and p.name!='MANIFEST_v1.2.9.json')
assert not any(p.suffix.lower() in {'.pxp','.uxp','.ibw'} for p in files)
assert all(p.relative_to(source).as_posix()=='tests/fixtures_v051/comment_header.tsv' for p in files if p.suffix.lower()=='.tsv')
checks=json.loads((source/'tests/results_v129/verification_summary.json').read_text())
assert checks['scientific_differences']==checks['reopened_differences']==0
assert checks['native_assertions_passed']==168
manifest={'version':'1.2.9','date_jst':'2026-11-05','branch':'codex/xrd-v1.2.9',
 'base_commit':'1d52584afe93f8781935fc4210de101a3444e5d3','native_assertions_passed':168,
 'actual_experiment_records_compared':2481477,'relative_include_edges':edges,
 'production_ipf_count':len(list(source.glob('*.ipf'))),
 'files':{p.relative_to(source).as_posix():sha(p) for p in files}}
(source/'MANIFEST_v1.2.9.json').write_text(json.dumps(manifest,indent=2)+'\n')
output=destination/source.name;archive=destination/(source.name+'.zip')
assert not output.exists() and not archive.exists(),'Never overwrite a distributed release'
shutil.copytree(source,output)
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(output.rglob('*')):
  if p.is_file():z.write(p,p.relative_to(output).as_posix())
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 assert all(z.read(i.filename)==(output/i.filename).read_bytes() for i in z.infolist())
(destination/(archive.name+'.sha256')).write_text(sha(archive)+'  '+archive.name+'\n')
print(json.dumps({'files':len(files)+1,'production_ipfs':manifest['production_ipf_count'],
 'relative_includes':edges,'zip_bytes':archive.stat().st_size,'sha256':sha(archive)},indent=2))
