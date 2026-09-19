#!/usr/bin/env python3
"""Verify complete source against immutable Git objects; legacy fixtures retain patch comparison."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def git(tree, *args, **kwargs):
    return subprocess.check_output(['git', '-C', str(tree), *args], **kwargs)


def verify(root=ROOT, pristine=False):
    lock = json.loads((root / 'sources.lock.json').read_text())
    identities = []
    if lock.get('schema', 1) >= 2:
        # Check every declared gitlink, including the wrapper's root submodule.
        for component in lock['components']:
            parents = [c for c in lock['components'] if component['path'].startswith(c['path'] + '/')]
            parent = max(parents, key=lambda c: len(c['path'])) if parents else None
            parent_tree = root / parent['path'] if parent else root
            relative = component['path'][len(parent['path']) + 1:] if parent else component['path']
            entry = git(parent_tree, 'ls-tree', 'HEAD', '--', relative).decode().strip()
            if not entry or entry.split()[0:3] != ['160000', 'commit', component['commit']]:
                raise ValueError(f"{component['name']}: parent gitlink disagrees with lock")
    for component in lock['components']:
        tree = root / component['path']
        head = git(tree, 'rev-parse', 'HEAD').decode().strip()
        if head != component['commit']:
            raise ValueError(f"{component['name']}: revision mismatch (expected {component['commit']}, got {head})")
        with tempfile.TemporaryDirectory(prefix='harkinianpad-source-check-') as directory:
            expected = Path(directory)
            git(expected, 'init', '-q')
            objects = git(tree, 'rev-parse', '--path-format=absolute', '--git-path', 'objects').decode().strip()
            (expected / '.git/objects/info/alternates').write_text(objects + '\n')
            git(expected, 'read-tree', head)
            if not pristine:
                for patch in component['patches']:
                    args = ['apply', '--cached']
                    if patch.get('ignore_space_change'):
                        args.append('--ignore-space-change')
                    git(expected, *args, str(root / patch['path']))
                for overlay in component.get('overlays', []):
                    blob = git(expected, 'hash-object', '-w', '--no-filters', str(root / overlay['source'])).decode().strip()
                    git(expected, 'update-index', '--add', '--cacheinfo', '100644', blob, overlay['destination'])
            entries = git(expected, 'ls-files', '--stage', '-z').split(b'\0')
            expected_files = set()
            for entry in entries:
                if not entry:
                    continue
                metadata, name = entry.split(b'\t', 1)
                mode, blob, stage = metadata.decode().split()
                if mode == '160000':
                    continue  # Each nested repository is checked independently below.
                name = os.fsdecode(name)
                expected_files.add(name)
                path = tree / name
                if not path.exists() and not path.is_symlink():
                    raise ValueError(f"{component['name']}: missing source {name}")
                if path.is_symlink():
                    data = os.fsencode(os.readlink(path))
                    actual_mode = '120000'
                else:
                    data = path.read_bytes()
                    actual_mode = '100755' if path.stat().st_mode & 0o111 else '100644'
                actual_blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
                if actual_blob != blob or actual_mode != mode:
                    raise ValueError(f"{component['name']}: unexpected source content/mode: {name}; preserve edits before rebuilding")
            names = git(tree, 'ls-files', '--cached', '--others', '--exclude-standard', '-z').split(b'\0')
            actual_files = {os.fsdecode(n) for n in names if n and not (tree / os.fsdecode(n)).is_dir()}
            extra = actual_files - expected_files
            if extra:
                raise ValueError(f"{component['name']}: unexpected source files: {', '.join(sorted(extra))}")
            identities.append({'name': component['name'], 'upstream': component['url'],
                               'base_commit': component.get('upstream_commit', head), 'commit': head, 'prepared_tree': git(expected, 'write-tree').decode().strip(),
                               'files': len(expected_files)})
    return {'schema': 1, 'profile': 'pristine' if pristine else ('maintained' if lock.get('schema', 1) >= 2 else 'preview5-prepared'), 'components': identities}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pristine', action='store_true', help='check untouched pinned sources before preparation')
    args = parser.parse_args()
    try:
        print(json.dumps(verify(pristine=args.pristine), indent=2))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Source verification failed: {error}\n')
