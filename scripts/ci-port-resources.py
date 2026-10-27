#!/usr/bin/env python3
"""Fetch pinned resource inputs and verify portable generation on a native host."""
import argparse
import json
from pathlib import Path
import platform
import runpy
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--expected-host', required=True)
    args = parser.parse_args()
    machine = platform.machine().lower()
    arch = {'amd64': 'x86_64', 'aarch64': 'arm64'}.get(machine, machine)
    host = {'darwin': 'macos'}.get(platform.system().lower(), platform.system().lower()) + '-' + arch
    if host != args.expected_host:
        parser.error(f'Expected {args.expected_host}; Python reports {host}')
    args.work.mkdir(parents=True, exist_ok=False)
    lock = json.loads((ROOT / 'sources.lock.json').read_text())
    directories = {}
    for name, selection in [('Shipwright', 'soh/assets/custom'), ('libultraship', 'src/fast/shaders')]:
        component = next(c for c in lock['components'] if c['name'] == name)
        checkout = args.work / name
        checkout.mkdir()
        def git(*arguments):
            return subprocess.check_output(['git', '-c', 'core.autocrlf=false', '-c', 'core.eol=lf',
                                            '-C', str(checkout), *arguments], text=True)
        git('init', '--quiet')
        git('remote', 'add', 'origin', component['url'])
        git('sparse-checkout', 'init', '--cone')
        git('sparse-checkout', 'set', selection)
        git('fetch', '--depth=1', '--filter=blob:none', '--no-tags', 'origin', component['commit'])
        git('checkout', '--detach', 'FETCH_HEAD')
        if git('rev-parse', 'HEAD').strip() != component['commit']:
            raise ValueError('Fetched revision differs from lock')
        directories[name] = checkout / selection
    builder = runpy.run_path(str(ROOT / 'scripts/build-port-archive.py'))
    output = args.work / 'soh.o2r'
    for _ in range(2):
        builder['build_archive'](directories['Shipwright'], directories['libultraship'], output)
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None or len(archive.namelist()) != builder['EXPECTED_ENTRIES']:
            raise ValueError('Unexpected archive integrity or entry count')
    print(json.dumps({'host': host, 'entries': builder['EXPECTED_ENTRIES'], 'content_sha256': builder['EXPECTED_CONTENT'],
                      'rerun_verified': True, 'gameplay_verified': False}))


if __name__ == '__main__':
    main()
