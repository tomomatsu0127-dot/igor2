"""Read-only audit of disposable local releases against the pushed Git tree."""
from pathlib import Path
import hashlib,json,subprocess,zipfile

repo=Path(__file__).resolve().parents[1]
workspace=repo.parents[1]
ref='origin/codex/xrd-v1.3.0'
sha=subprocess.check_output(['git','rev-parse',ref],cwd=repo,text=True).strip()
raw=subprocess.check_output(['git','ls-tree','-r','-z',ref],cwd=repo)
tree={}
for record in raw.split(b'\0'):
    if not record:continue
    meta,name=record.split(b'\t',1)
    tree[name.decode('utf-8')]=meta.split()[2].decode('ascii')
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def equal(name,data):
    if '/__pycache__/' in name and name.endswith('.pyc'):return True
    expected=tree.get(name)
    return expected is not None and (blob(data)==expected or blob(data.replace(b'\r\n',b'\n'))==expected)
report={'remote_commit':sha,'workspace':str(workspace),'safe':[],'held':[]}
versions=sorted({n.split('/')[0] for n in tree if n.startswith('xrd_workbench_') and not n.startswith('xrd_workbench_v1.3.0/')})
for version in versions:
    folder=workspace/version
    if folder.is_dir():
        files=[p for p in folder.rglob('*') if p.is_file()]
        mismatches=[str(p.relative_to(folder)) for p in files if not equal(version+'/'+p.relative_to(folder).as_posix(),p.read_bytes())]
        expected={n for n in tree if n.startswith(version+'/')}
        present={version+'/'+p.relative_to(folder).as_posix() for p in files}
        missing=sorted(expected-present)
        if not mismatches:
            report['safe'].append({'path':str(folder),'kind':'directory','version':version,'files':len(files)})
        else:report['held'].append({'path':str(folder),'mismatch_count':len(mismatches),'missing_count':len(missing),'examples':mismatches[:4]+missing[:4]})
    archive=workspace/(version+'.zip')
    if archive.is_file():
        with zipfile.ZipFile(archive) as z:
            entries=[i for i in z.infolist() if not i.is_dir()]
            def entry_name(name):
                if name.startswith(version+'/'):name=name[len(version)+1:]
                return version+'/'+name
            mismatches=[i.filename for i in entries if not equal(entry_name(i.filename),z.read(i))]
        if not mismatches:
            report['safe'].append({'path':str(archive),'kind':'zip','version':version,'files':len(entries),'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()})
            checksum=workspace/(archive.name+'.sha256')
            if checksum.exists():report['safe'].append({'path':str(checksum),'kind':'checksum','version':version})
        else:report['held'].append({'path':str(archive),'mismatch_count':len(mismatches),'examples':mismatches[:4]})
out=repo/'scratch/v130/cleanup_audit.json';out.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n','utf-8')
print(json.dumps({'remote_commit':sha,'safe_items':len(report['safe']),'held_items':len(report['held']),'safe_versions':sorted({x['version'] for x in report['safe']})},indent=2))
