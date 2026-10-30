"""Package the validated v1.2.5 source without including private Experiments."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import sys
import zipfile

repo, destination = Path(sys.argv[1]), Path(sys.argv[2])
source = repo / 'xrd_workbench_v1.2.5'
manifest_name = 'MANIFEST_v1.2.5.json'
files = sorted(p for p in source.rglob('*') if p.is_file() and p.name != manifest_name)
assert not any(p.suffix.lower() in {'.pxp', '.uxp', '.ibw', '.h5xp'} for p in files)
edges = 0
for path in source.rglob('*.ipf'):
    for include in re.findall(r'^#include\s+"(:[^"\r\n]+)"', path.read_text(encoding='utf-8-sig'), re.M):
        target = path.parent / (include[1:].replace(':', '/') + '.ipf')
        assert target.is_file(), (path, include)
        edges += 1
sha = lambda data: hashlib.sha256(data).hexdigest()
manifest = dict(version='1.2.5', date_jst='2026-10-30', branch='codex/xrd-v1.2.5',
                base_commit='2694482a48f43f8e88bf8869a50f58a9b2059d90',
                production_ipf_count=len(list(source.glob('*.ipf'))), relative_include_edges=edges,
                native_assertions_passed=147, actual_experiment_records_compared=589850,
                files={p.relative_to(source).as_posix(): sha(p.read_bytes()) for p in files})
(source / manifest_name).write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
output = destination / source.name
shutil.copytree(source, output, dirs_exist_ok=True)
archive = destination / (source.name + '.zip')
assert not archive.exists(), 'Never replace a released ZIP'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as package:
    for path in sorted(output.rglob('*')):
        if path.is_file():
            package.write(path, path.relative_to(output).as_posix())
with zipfile.ZipFile(archive) as package:
    assert not package.testzip()
    for info in package.infolist():
        assert package.read(info.filename) == (output / info.filename).read_bytes()
archive_sha = sha(archive.read_bytes())
(destination / (archive.name + '.sha256')).write_text(archive_sha + '  ' + archive.name + '\n', encoding='ascii')
print(json.dumps(dict(files=len(files)+1, production_ipfs=manifest['production_ipf_count'],
                     relative_includes=edges, zip_bytes=archive.stat().st_size, sha256=archive_sha)))
