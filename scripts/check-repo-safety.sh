#!/usr/bin/env bash
# Fast, ROM-free repository gate for local checks and GitHub Actions.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
    echo "Repository safety check failed: $*" >&2
    exit 1
}

current_files="$(git ls-files --cached --others --exclude-standard | sort -u)"

tracked_ref_files="$(printf '%s\n' "$current_files" |
    grep '^ref/' | grep -v '^ref/README\.md$' || true)"
if [ -n "$tracked_ref_files" ]; then
    echo "$tracked_ref_files" >&2
    fail "ref/ contains tracked files other than ref/README.md"
fi

forbidden_extensions='\.(z64|n64|v64|rom|o2r|otr|mpq|ipa|xcarchive|mobileprovision|provisionprofile|p12|p8|pem|key)(/|$)'
forbidden_tracked="$(printf '%s\n' "$current_files" |
    grep -Ei "$forbidden_extensions|(^|/)[^/]+\.app/" || true)"
if [ -n "$forbidden_tracked" ]; then
    echo "$forbidden_tracked" >&2
    fail "proprietary, generated, packaged, or signing material is tracked"
fi

history_paths="$(git rev-list --objects --all | awk 'NF > 1 { sub(/^[^ ]+ /, ""); print }')"
forbidden_history="$(printf '%s\n' "$history_paths" |
    grep -Ei "$forbidden_extensions|(^|/)[^/]+\.app/" || true)"
history_ref="$(printf '%s\n' "$history_paths" |
    grep '^ref/' | grep -v '^ref/README\.md$' || true)"
if [ -n "$forbidden_history" ] || [ -n "$history_ref" ]; then
    printf '%s\n%s\n' "$forbidden_history" "$history_ref" >&2
    fail "proprietary, generated, packaged, or signing material exists in Git history"
fi

while IFS= read -r file; do
    [ -f "$file" ] || continue
    size="$(wc -c < "$file")"
    if [ "$size" -gt 5242880 ]; then
        echo "$file ($size bytes)" >&2
        fail "tracked file exceeds the 5 MiB review limit"
    fi
done < <(printf '%s\n' "$current_files")

credential_pattern='(-----BEGIN [A-Z ]*PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})'
credential_hits=""
while IFS= read -r file; do
    [ -f "$file" ] || continue
    matches="$(grep -nEI "$credential_pattern" "$file" 2>/dev/null || true)"
    if [ -n "$matches" ]; then
        credential_hits="${credential_hits}${file}:${matches}"$'\n'
    fi
done < <(printf '%s\n' "$current_files")
if [ -n "$credential_hits" ]; then
    printf '%s' "$credential_hits" >&2
    fail "a likely credential or private key exists in the current tree"
fi

bash -n scripts/*.sh
for script in scripts/*.sh; do
    [ -x "$script" ] || fail "$script is not executable"
done

for patch in patches/*.patch; do
    git apply --numstat "$patch" >/dev/null ||
        fail "$patch is not a syntactically valid patch"
done

python3 - "$ROOT" <<'PY'
import json
import pathlib
import re
import subprocess
import sys
import urllib.parse

root = pathlib.Path(sys.argv[1])
markdown = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.md"],
    cwd=root,
    text=True,
).splitlines()
missing = []
patterns = [
    re.compile(r"!?\[[^\]]*\]\(([^)\s]+)"),
    re.compile(r'<(?:img|a)\b[^>]+(?:src|href)="([^"]+)"', re.IGNORECASE),
]

for relative in markdown:
    document = root / relative
    text = document.read_text(encoding="utf-8")
    for pattern in patterns:
        for raw_target in pattern.findall(text):
            target = raw_target.strip("<>")
            if target.startswith(("#", "/", "http://", "https://", "mailto:")):
                continue
            target = urllib.parse.unquote(target.split("#", 1)[0].split("?", 1)[0])
            if target and not (document.parent / target).exists():
                missing.append(f"{relative}: {raw_target}")

with (root / "assets/AppIcon.appiconset/Contents.json").open(encoding="utf-8") as handle:
    json.load(handle)

if missing:
    print("Missing local Markdown targets:", file=sys.stderr)
    print("\n".join(missing), file=sys.stderr)
    raise SystemExit(1)
PY

git fsck --full --strict --no-dangling

echo "Repository safety checks passed."
