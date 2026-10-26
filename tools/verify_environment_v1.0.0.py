"""Read-only checks for the imported baseline and development records (stdlib only)."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
checks = 0


def check(condition, message):
    global checks
    checks += 1
    if not condition:
        errors.append(message)


def main():
    manifest = json.loads((ROOT / 'docs/BASELINE_MANIFEST_v1.0.0.json').read_text(encoding='utf-8-sig'))
    expected = set()
    for entry in manifest['files']:
        relative = entry['path']
        expected.add(relative)
        path = ROOT / relative
        check(path.is_file(), f'Missing baseline: {relative}')
        if path.is_file():
            data = path.read_bytes()
            check(hashlib.sha256(data).hexdigest() == entry['sha256'], f'Baseline changed: {relative}')
            check(len(data) == entry['bytes'], f'Baseline size changed: {relative}')
    actual = {p.relative_to(ROOT).as_posix() for p in (ROOT / 'xrd_workbench_v1.1.0').rglob('*') if p.is_file()}
    check(actual == expected, f'Baseline file list changed: {sorted(actual ^ expected)}')

    include_count = 0
    external = []
    for path in (ROOT / 'xrd_workbench_v1.1.0').rglob('*.ipf'):
        content = path.read_text(encoding='utf-8-sig')
        for token in re.findall(r'^\s*#include\s+([<"][^>"\r\n]+[>"])', content, re.M):
            if token.startswith('"') and token[1:-1].startswith(':'):
                target = token[1:-1][1:].replace(':', '/')
                target += '' if target.lower().endswith('.ipf') else '.ipf'
                check((path.parent / target).is_file(), f'Unresolved include: {path.name} -> {token}')
                include_count += 1
            else:
                external.append((path.name, token))
    check(external == [('xrd_main.ipf', '<Peak AutoFind>')], f'External include inventory changed: {external}')

    for name in ['AGENTS.md', 'WORK_STATUS.md', 'WORK_LOG.md', 'README.md',
                 'docs/DEPENDENCY_AUDIT_v1.0.0.md', 'docs/IGOR905_VALIDATION_v1.0.0.md',
                 'docs/RESUME_GUIDE_v1.0.0.md']:
        path = ROOT / name
        check(path.is_file() and path.stat().st_size > 0, f'Missing management file: {name}')

    skills = sorted((ROOT / '.agents/skills').glob('*/SKILL.md'))
    check(len(skills) == 3, 'Expected three Igor skills')
    for path in skills:
        text = path.read_text(encoding='utf-8')
        header = re.match(r'^---\n(.*?)\n---\n', text, re.S)
        check(header is not None, f'Missing frontmatter: {path}')
        if header:
            fields = dict(re.findall(r'^(name|description): (.+)$', header[1], re.M))
            check(fields.get('name') == path.parent.name, f'Skill name/folder mismatch: {path}')
            check(bool(fields.get('description')), f'Missing skill description: {path}')
        check((path.parent / 'agents/openai.yaml').is_file(), f'Missing skill UI metadata: {path}')

    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode('utf-8').split('\0')
    forbidden = ('.pxp', '.uxp', '.pxt', '.uxt', '.ibw', '.h5xp', '.autosave')
    check(not any(p.lower().endswith(forbidden) for p in tracked), 'Research/experiment files tracked')

    # Validate local links only in newly authored management/skill docs; imported docs are immutable.
    docs = [ROOT / n for n in ['README.md', 'AGENTS.md', 'WORK_STATUS.md', 'WORK_LOG.md']]
    docs += list((ROOT / 'docs').glob('*.md')) + skills
    for path in docs:
        for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', path.read_text(encoding='utf-8')):
            if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target) or target.startswith('#'):
                continue
            target = target.split('#')[0]
            check((path.parent / target).exists(), f'Broken local link: {path.name} -> {target}')

    print(json.dumps({'version': '1.0.0', 'checks': checks, 'baseline_files': len(expected),
                      'relative_includes': include_count, 'external_includes': external,
                      'skills': [p.parent.name for p in skills], 'errors': errors,
                      'igor_runtime': '未確認'}, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
