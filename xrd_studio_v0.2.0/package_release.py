"""Package only this app, source, artificial data and verified results."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import zipfile
import numpy as np
from studio import demo
from studio.document import Document,save_document

ROOT=Path(__file__).resolve().parent


def package(destination):
    destination=Path(destination).resolve();destination.mkdir(parents=True,exist_ok=True)
    binary=ROOT/'dist/XRD_Studio_v0.2.0.exe'
    report=json.loads((ROOT/'tests/compiled_validation_v0.2.0.json').read_text())
    if report.get('status')!='PASS' or not report.get('frozen') or not report.get('qt_window'):
        raise RuntimeError('The final compiled executable must pass its own integration check.')
    if (ROOT/'tests/compiled_validation_v0.2.0.json').stat().st_mtime<binary.stat().st_mtime:
        raise RuntimeError('Compiled validation is older than the executable.')
    sources=[*ROOT.glob('*.py'),*ROOT.glob('studio/*.py')]
    if any(p.stat().st_mtime>binary.stat().st_mtime for p in sources):raise RuntimeError('Source changed after executable build.')
    log=(ROOT/'tests/test_run_v0.2.0.log').read_text(encoding='utf-8-sig')
    match=re.search(r'Ran (\d+) tests',log)
    if not match or '\nOK' not in log or 'FAILED (' in log:raise RuntimeError('Unit test report is not a pass.')
    target=destination/'XRD_Studio_v0.2.0'
    target.mkdir(exist_ok=False)
    shutil.copy2(binary,target/binary.name)
    for name in ['README_ja.md','IGOR_FOUNDATION_v0.2.0.md','FEATURE_PROGRESS_v0.2.0.md','TEST_RESULTS_v0.2.0.md','THIRD_PARTY_NOTICES.txt','DEPENDENCIES_v0.2.0.json']:
        shutil.copy2(ROOT/name,target/name)
    shutil.copytree(ROOT/'licenses',target/'licenses')
    source=target/'source';source.mkdir()
    for p in sources:
        relative=p.relative_to(ROOT);(source/relative).parent.mkdir(exist_ok=True,parents=True);shutil.copy2(p,source/relative)
    shutil.copy2(ROOT/'requirements.txt',source/'requirements.txt')
    checks=target/'verification';checks.mkdir()
    for p in (ROOT/'tests').glob('*'):
        if p.is_file() and (p.suffix in ('.json','.log') or p.name.startswith('test_') and p.suffix=='.py' or p.name in ['compatibility_check.py','gui_smoke.py']):shutil.copy2(p,checks/p.name)
    # Runnable test sources retain their expected location under source/tests.
    shutil.copytree(ROOT/'tests',source/'tests',ignore=shutil.ignore_patterns('__pycache__','*.png'))
    samples=target/'samples';samples.mkdir()
    document=Document();demo.populate(document.state);save_document(document,samples/'artificial_project.labx')
    sample=next(iter(document.state['samples'].values()));reference=next(iter(document.state['references'].values()))
    np.savetxt(samples/'artificial_measurement.csv',np.column_stack([sample['raw_x'],sample['raw_y']]),delimiter=',',header='2theta,intensity',comments='',fmt='%.12g')
    columns=np.column_stack([reference[k] for k in ['x','intensity','h','k','l','d']])
    np.savetxt(samples/'artificial_reference.txt',columns,header='name: 人工立方晶（操作練習用）\ncard_number: SYNTHETIC-CUBIC-001\n2theta I h k l d',fmt='%.12g',encoding='utf-8')
    preview=ROOT/'tests/compiled_validation_v0.2.0.png'
    shutil.copy2(preview,target/'preview.png');shutil.copy2(preview,destination/'XRD_Studio_v0.2.0_preview.png')
    files=[{'path':p.relative_to(target).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(target.rglob('*')) if p.is_file()]
    manifest={'version':'0.2.0','stage':'executable development preview','unit_tests':int(match[1]),'schema':2,'source_schema1_supported':True,'data':'artificial only','files':files}
    (target/'MANIFEST_v0.2.0.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    archive=destination/'XRD_Studio_v0.2.0.zip'
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(target.rglob('*')):
            if p.is_file():z.write(p,p.relative_to(destination).as_posix())
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            original=destination/info.filename
            if hashlib.sha256(z.read(info)).hexdigest()!=hashlib.sha256(original.read_bytes()).hexdigest():raise AssertionError('ZIP differs: '+info.filename)
    digest=hashlib.sha256(archive.read_bytes()).hexdigest()
    (destination/'XRD_Studio_v0.2.0.zip.sha256').write_text(digest+'  '+archive.name+'\n',encoding='ascii')
    result={'archive':archive.name,'bytes':archive.stat().st_size,'sha256':digest,'files':len(files)+1,
        'exe_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'every_zip_entry_verified':True,'unit_tests':int(match[1])}
    (ROOT/'DISTRIBUTION_v0.2.0.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('destination');args=p.parse_args();package(args.destination)
