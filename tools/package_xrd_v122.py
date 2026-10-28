"""Package v1.2.2 into a fresh directory and verify all bytes and dependencies."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit,unquote
import hashlib,json,re,shutil,sys,zipfile
repo=Path(__file__).resolve().parents[1]
src=repo/'xrd_workbench_v1.2.2'
destination=Path(sys.argv[1]).resolve()
dst=destination/src.name
archive=destination/(src.name+'.zip')
assert destination.is_dir() and not dst.exists() and not archive.exists(),'Use unused output paths'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
baseline=json.loads((repo/'docs/BASELINE_FOR_v1.2.2.json').read_text(encoding='utf-8-sig'))
for name,digest in baseline['files'].items():
    assert sha(repo/'xrd_workbench_v1.2.1'/name)==digest,('old repository bytes changed',name)
local_baseline=json.loads((repo/'docs/LOCAL_BASELINE_FOR_v1.2.2.json').read_text(encoding='utf-8-sig'))
for name,digest in local_baseline['files'].items():
    assert sha(destination/'xrd_workbench_v1.2.1'/name)==digest,('old delivered bytes changed',name)
files=sorted(p for p in src.rglob('*') if p.is_file() and p.name!='MANIFEST_v1.2.2.json')
assert not any(p.suffix.lower() in ('.pxp','.uxp','.ibw') for p in files),'No Experiment or measurement binary packaging'
names={p.relative_to(src).as_posix() for p in files}
includes=0
for p in files:
    if p.suffix.lower()=='.ipf':
        for inc in re.findall(r'^\s*#include\s+"([^"]+)"',p.read_text(encoding='utf-8-sig'),re.M):
            assert inc.startswith(':'),(p,inc)
            target=p.parent/(inc[1:].replace(':','/')+'.ipf')
            assert target.relative_to(src).as_posix() in names,(p,inc)
            includes+=1
class Links(HTMLParser):
    def __init__(self):super().__init__();self.links=[];self.ids=set()
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'id' in a:self.ids.add(a['id'])
        self.links += [a[k] for k in ('src','href') if k in a]
pages={}
for p in src.glob('*.html'):
    parser=Links();parser.feed(p.read_text(encoding='utf-8-sig'));pages[p]=parser
for p,parser in pages.items():
    for link in parser.links:
        u=urlsplit(link)
        if u.scheme:continue
        target=p.parent/unquote(u.path) if u.path else p
        assert target.exists(),(p,link)
        if u.fragment and target in pages:assert unquote(u.fragment) in pages[target].ids,(p,link)
changed=sorted(p.name for p in src.glob('*.ipf') if p.read_bytes()!=(repo/'xrd_workbench_v1.2.1'/p.name).read_bytes())
assert len(changed)==23 and len(list(src.glob('*.ipf')))==44
manifest={'version':'1.2.2','date_jst':'2026-10-29','branch':'codex/xrd-v1.2.2','base_commit':'3c74fca','baseline_version':'1.2.1','native_assertions_passed':504,'relative_include_edges':includes,'production_ipf_count':44,'changed_production_files':changed,'files':{p.relative_to(src).as_posix():sha(p) for p in files}}
(src/'MANIFEST_v1.2.2.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copytree(src,dst)
with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(dst.rglob('*')):
        if p.is_file():z.write(p,p.relative_to(destination).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for p in dst.rglob('*'):
        if p.is_file():assert hashlib.sha256(z.read(p.relative_to(destination).as_posix())).hexdigest()==sha(p)
ziphash=sha(archive)
(archive.parent/(archive.name+'.sha256')).write_text(ziphash+'  '+archive.name+'\n',encoding='ascii')
summary={'files':len(files)+1,'production_ipf':44,'relative_include_edges':includes,'changed_production_files':changed,'archive_bytes':archive.stat().st_size,'sha256':ziphash,'destination':str(dst)}
(repo/'docs/PACKAGE_v1.2.2.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
