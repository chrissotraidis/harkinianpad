#!/usr/bin/env python3
"""Rebuild HarkinianPad's Shipwright source from the original upstream projects.

Usage: scripts/fetch-upstream-sources.py DEST

Clones HarbourMasters/Shipwright at the pinned upstream commit (with its own
submodule pins), applies HarkinianPad's patches from patches/upstream/, and
verifies that every patched tree matches the recorded tree ID. The result is
the same source as the fork commits in sources.lock.json, apart from submodule
URLs, without fetching the forks. DEST must not exist.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def git(*args, cwd):
    subprocess.run(["git", *args], cwd=cwd, check=True)


def output(*args, cwd):
    return subprocess.check_output(["git", *args], cwd=cwd, text=True).strip()


def main(argv):
    if len(argv) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    dest = Path(argv[0]).resolve()
    if dest.exists():
        print(f"{dest} already exists; choose a new folder", file=sys.stderr)
        return 1
    spec = json.loads((ROOT / "patches/upstream/sources.json").read_text())
    components = spec["components"]
    for component in components:
        actual = hashlib.sha256((ROOT / component["patch"]).read_bytes()).hexdigest()
        if actual != component["patch_sha256"]:
            print(f"{component['patch']} does not match its recorded SHA-256", file=sys.stderr)
            return 1
    root = components[0]
    dest.mkdir(parents=True)
    git("init", "-q", cwd=dest)
    git("remote", "add", "origin", root["upstream_url"], cwd=dest)
    git("fetch", "-q", "--depth", "1", "origin", root["upstream_commit"], cwd=dest)
    git("checkout", "-q", "--detach", "FETCH_HEAD", cwd=dest)
    git("submodule", "update", "--init", "--recursive", cwd=dest)
    for component in components:
        path = dest / component["path"]
        if output("rev-parse", "HEAD", cwd=path) != component["upstream_commit"]:
            print(f"{component['name']} is not at its pinned upstream commit", file=sys.stderr)
            return 1
        git("apply", "--index", "--whitespace=nowarn", str(ROOT / component["patch"]), cwd=path)
        tree = output("write-tree", cwd=path)
        if tree != component["patched_tree"]:
            print(f"{component['name']} patched tree {tree} != recorded {component['patched_tree']}",
                  file=sys.stderr)
            return 1
        git("remote", "set-url", "--push", "origin", "DISABLED", cwd=path)
        print(f"{component['name']}: upstream {component['upstream_commit'][:12]} + patch = "
              f"tree {tree[:12]} (verified)")
    print(f"Upstream-based source ready at {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

