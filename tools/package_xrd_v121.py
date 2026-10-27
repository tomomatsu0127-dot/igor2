"""Package v1.2.1 without modifying old releases or synced sources."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import hashlib, json, re, shutil, sys, zipfile
repo=Path(__file__).resolve().parents[1]
src=repo/'xrd_workbench_v1.2.1'
destination=Path(sys.argv[1]).resolve()
dst=destination/src.name
archive=destination/(src.name+'.zip')
assert not dst.exists() and not archive.exists(), 'Use unused output paths'
baseline=json.loads((repo/'docs/LOCAL_BASELINE_FOR_v1.2.1.json').read_text(encoding='utf-8-sig'))
old=destination/'xrd_workbench_v1.2.0'
for name,digest in baseline['files'].items():
    assert hashlib.sha256((old/name).read_bytes()).hexdigest()==digest, name
names=set(baseline['files'])-{'MANIFEST_v1.2.0.json'}
names.update(p.name for p in src.glob('*v1.2.1.*'))
names.add('tests/xrd_v121_tests.ipf')
for directory in ('tests/results_v121','preview/v1.2.1'):
    names.update(p.relative_to(src).as_posix() for p in (src/directory).rglob('*') if p.is_file())
changed=[name for name in baseline['files'] if name.endswith('.ipf') and not name.startswith('tests/') and (src/name).read_bytes()!=(old/name).read_bytes()]
assert sorted(changed)==['xrd_main.ipf','xrd_ui.ipf','xrd_ui120.ipf','xrd_v51.ipf'],changed
for name in baseline['files']:
    if name not in changed+['README_ja.md','MANIFEST_v1.2.0.json']:
        assert (src/name).read_bytes()==(old/name).read_bytes(),name
includes=0
for name in sorted(names):
    f=src/name
    assert f.is_file(),name
    assert f.suffix.lower() not in ('.pxp','.uxp','.ibw'),name
    if f.suffix=='.ipf':
        for inc in re.findall(r'^\s*#include\s+"([^"]+)"',f.read_text(encoding='utf-8-sig'),re.M):
            if inc.startswith(':'):
                dep=f.parent/(inc[1:].replace(':','/')+'.ipf')
                assert dep.relative_to(src).as_posix() in names,(name,inc)
                includes+=1
    target=dst/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,target)
class Links(HTMLParser):
    def __init__(self):super().__init__();self.links=[];self.ids=set()
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'id' in a:self.ids.add(a['id'])
        for attr in ('src','href'):
            if attr in a:self.links.append(a[attr])
pages={}
for p in dst.glob('*.html'):
    obj=Links();obj.feed(p.read_text(encoding='utf-8-sig'));pages[p]=obj
for p,obj in pages.items():
    for link in obj.links:
        url=urlsplit(link)
        if url.scheme:continue
        target=p.parent/unquote(url.path) if url.path else p
        assert target.exists(),(p,link)
        if url.fragment and target in pages:assert unquote(url.fragment) in pages[target].ids,(p,link)
manifest={'version':'1.2.1','date_jst':'2026-10-27','branch':'codex/xrd-v1.2.1','base_commit':'93e92d001cf0df22d834bfb6cbb7fc3d80394966','baseline_version':'1.2.0','baseline_source':'user-specified local workspace folder','production_ipf_count':44,'changed_production_files':changed,'relative_includes':includes,'files':{n:hashlib.sha256((dst/n).read_bytes()).hexdigest() for n in sorted(names)}}
(src/'MANIFEST_v1.2.1.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copyfile(src/'MANIFEST_v1.2.1.json',dst/'MANIFEST_v1.2.1.json')
with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(dst.rglob('*')):
        if p.is_file():z.write(p,p.relative_to(destination).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for p in dst.rglob('*'):
        if p.is_file():assert hashlib.sha256(z.read(p.relative_to(destination).as_posix())).digest()==hashlib.sha256(p.read_bytes()).digest()
ziphash=hashlib.sha256(archive.read_bytes()).hexdigest()
(archive.parent/(archive.name+'.sha256')).write_text(ziphash+'  '+archive.name+'\n',encoding='ascii')
print(json.dumps({'files':len(names)+1,'relative_includes':includes,'zip_bytes':archive.stat().st_size,'sha256':ziphash,'destination':str(dst)},indent=2))
