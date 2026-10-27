# Portable port-resource generation

The command below reproduces the pinned `soh.o2r` resources without
building the native asset tools. It uses only Python 3.9 or later. The normal build calls it
through `generate-port-archive.sh`, preserving the existing archive locations. Portable
resource generation does not establish a Windows, Linux or Android app-build route.

```sh
python3 scripts/build-port-archive.py \
  sources/Shipwright/soh/assets/custom \
  sources/Shipwright/libultraship/src/fast/shaders \
  /path/to/private/soh.o2r
```

The input digest covers the complete custom-resource set and runtime shaders.
Shaders are read directly from the pinned runtime, so the command does not copy
or remove files in the engine checkout. It reproduces the PNG texture
conversions and the pinned 9.3.1 version record. Input drift or an unexpected
output digest fails before writing. An existing archive is retained and accepted
only when every entry matches; output must be outside the input directories.

On 27 October 2026, local comparison against Shipwright 9.3.1's native
`soh-o2r-packer` matched all **1,056** entry names and bytes. The content digest is
`45762d7a99ddd059e1a81a4273f38a42ed804e1da0e7438f0bda6cf23e438a1d`.
The comparison stages inputs in a private scratch directory, leaving the source
tree unchanged. The input and output digests in `build-port-archive.py` reject
stale resources from the previous engine version.

Historical 9.2.3 qualification matched 1,042 entries.
Python 3.9 and 3.11 passed conversion/filter, malformed-input, preservation and
interrupted-write tests. Native Windows/Linux x64 and ARM64 plus Mac ARM64
generation for that earlier pin passed in
[run 36987010786](https://github.com/chrissotraidis/harkinianpad/actions/runs/36987010786).
That earlier normal-build integration also passed a local unsigned iPhoneOS build
and all 30 Python regression tests. The old CI results do not qualify the new
pins on those hosts. These checks do not establish gameplay or publication clearance.
