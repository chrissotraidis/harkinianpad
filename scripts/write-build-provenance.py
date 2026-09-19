#!/usr/bin/env python3
"""Write allowlisted build identity; no machine names, paths, credentials or game data."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('source_verifier', ROOT / 'scripts/verify-sources.py')
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def sha(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--check', action='store_true', help='verify an existing build report')
    args = parser.parse_args()
    app = args.app.resolve()
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    report = verifier.verify()
    report['wrapper'] = {'commit': command('git', 'rev-parse', 'HEAD'),
                         'dirty': bool(command('git', 'status', '--porcelain', '--untracked-files=normal'))}
    report['tools'] = {'xcode': command('xcodebuild', '-version'),
                       'cmake': command('cmake', '--version').splitlines()[0],
                       'sdk': command('xcrun', '--sdk', 'iphonesimulator' if 'iphonesimulator' in info.get('DTPlatformName', '') else 'iphoneos', '--show-sdk-version')}
    report['app'] = {key: info.get(key) for key in ('CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion', 'MinimumOSVersion', 'DTPlatformName')}
    report['executable_sha256'] = sha(app / info['CFBundleExecutable'])
    report['port_archive_sha256'] = sha(app / 'soh.o2r')
    report['source_lock_sha256'] = sha(ROOT / 'sources.lock.json')
    report['resolved_git_dependencies'] = []
    for dependency in sorted((app.parents[2] / '_deps').glob('*-src')):
        if not (dependency / '.git').exists():
            continue
        diff = subprocess.check_output(['git', '-C', str(dependency), 'diff', 'HEAD', '--binary'])
        report['resolved_git_dependencies'].append({
            'name': dependency.name,
            'commit': command('git', '-C', str(dependency), 'rev-parse', 'HEAD'),
            'tracked_diff_sha256': hashlib.sha256(diff).hexdigest(),
            'dirty': bool(command('git', '-C', str(dependency), 'status', '--porcelain')),
        })
    report['qualification'] = 'Build identity only; complete offline source delivery and redistribution qualification pending.'
    if args.check:
        try:
            recorded = json.loads(app.with_suffix('.build.json').read_text())
        except (OSError, ValueError):
            parser.exit(1, 'Missing or invalid build provenance: rebuild before packaging.\n')
        if recorded != report:
            parser.exit(1, 'Build provenance mismatch: rebuild before packaging.\n')
    else:
        (app.with_suffix('.build.json')).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
