#!/usr/bin/env python3
"""Generate the pinned clean HarkinianPad port archive using only Python.

Used by the normal resource step; native app compilation remains separate.
"""
import argparse
import hashlib
from pathlib import Path
import struct
import tempfile
import zipfile
import zlib

FORMATS = {"rgba32": 1, "ia4": 7, "ia8": 8, "ia16": 9}
EXPECTED_INPUT = "af35d4394381ae7678cf9941c3d2454ccd19387ddc86dfdb211c6e37ad0fa97c"
EXPECTED_ENTRIES = 1056
EXPECTED_CONTENT = "45762d7a99ddd059e1a81a4273f38a42ed804e1da0e7438f0bda6cf23e438a1d"


def content_hash(files):
    digest = hashlib.sha256()
    for name, data in sorted(files.items()):
        digest.update(name.encode("utf-8") + b"\0" + hashlib.sha256(data).digest())
    return digest.hexdigest()


def png_rgba(data):
    if not data[:8] == b'\x89PNG\r\n\x1a\n':
        raise ValueError('Unsupported or malformed pinned PNG')
    pos = 8
    compressed = bytearray()
    dimensions = None
    while pos < len(data):
        length = struct.unpack_from('>I', data, pos)[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if not len(body) == length:
            raise ValueError('Unsupported or malformed pinned PNG')
        crc = struct.unpack_from('>I', data, pos + 8 + length)[0]
        if not zlib.crc32(kind + body) & 4294967295 == crc:
            raise ValueError('Unsupported or malformed pinned PNG')
        pos += length + 12
        if kind == b'IHDR':
            if not dimensions is None:
                raise ValueError('Unsupported or malformed pinned PNG')
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', body)
            if not (width > 0 and height > 0 and ((depth, color, compression, filtering, interlace) == (8, 6, 0, 0, 0))):
                raise ValueError('Unsupported or malformed pinned PNG')
            dimensions = (width, height)
        elif kind == b'IDAT':
            compressed.extend(body)
        elif kind == b'IEND':
            break
    if not (dimensions and pos == len(data)):
        raise ValueError('Unsupported or malformed pinned PNG')
    width, height = dimensions
    stride = width * 4
    raw = zlib.decompress(compressed)
    if not len(raw) == height * (stride + 1):
        raise ValueError('Unsupported or malformed pinned PNG')
    result = bytearray()
    previous = bytearray(stride)
    for y in range(height):
        offset = y * (stride + 1)
        mode = raw[offset]
        if not mode in range(5):
            raise ValueError('Unsupported or malformed pinned PNG')
        row = bytearray(raw[offset + 1:offset + 1 + stride])
        for x in range(stride):
            left = row[x - 4] if x >= 4 else 0
            above = previous[x]
            corner = previous[x - 4] if x >= 4 else 0
            if mode == 0:
                predictor = 0
            elif mode == 1:
                predictor = left
            elif mode == 2:
                predictor = above
            elif mode == 3:
                predictor = (left + above) // 2
            else:
                p = left + above - corner
                distances = (abs(p - left), abs(p - above), abs(p - corner))
                predictor = (left, above, corner)[distances.index(min(distances))]
            row[x] = row[x] + predictor & 255
        result.extend(row)
        previous = row
    return (width, height, bytes(result))

def texture(data, fmt):
    width, height, rgba = png_rgba(data)
    pixels = list(zip(rgba[::4], rgba[3::4]))
    if fmt == 'rgba32':
        raw = rgba
    elif fmt == 'ia16':
        raw = bytes((v for pair in pixels for v in pair))
    elif fmt == 'ia8':
        raw = bytes((r >> 4 << 4 | a >> 4 for r, a in pixels))
    else:
        if not width % 2 == 0:
            raise ValueError('Unsupported or malformed pinned PNG')
        values = [r >> 5 << 1 | bool(a) for r, a in pixels]
        raw = bytes((values[i] << 4 | values[i + 1] for i in range(0, len(values), 2)))
    header = struct.pack('<IIIQI', 0, 1330922840, 0, 16045690984833335023, 0).ljust(64, b'\x00')
    return header + struct.pack('<IIII', FORMATS[fmt], width, height, len(raw)) + raw


def collect_inputs(source, shaders):
    files = {}
    for directory, prefix in ((Path(source), ""), (Path(shaders), "shaders/")):
        if not directory.is_dir() or directory.is_symlink():
            raise ValueError("Missing resource directory or directory is a link")
        for path in sorted(directory.rglob("*")):
            if path.is_symlink():
                raise ValueError("Resource links are not supported")
            name = path.relative_to(directory).as_posix()
            # The native generator stages runtime shaders here. Read the pinned
            # runtime originals instead, without mutating this source directory.
            if not prefix and name.split("/")[0] == "shaders":
                continue
            if path.is_file():
                files[prefix + name] = path.read_bytes()
    if content_hash(files) != EXPECTED_INPUT:
        raise ValueError("Pinned resource inputs changed; output preserved")
    return files


def generate_entries(files):
    entries = {}
    for name, data in sorted(files.items()):
        parts = name.rsplit(".", 2)
        if len(parts) == 3 and parts[-1] == "png" and parts[-2] in FORMATS:
            name, data = parts[0], texture(data, parts[-2])
        elif "accessibility" in name and not name.endswith(".json"):
            continue
        if name in entries:
            raise ValueError("Duplicate generated resource name")
        entries[name] = data
    entries["portVersion"] = struct.pack(">BHHH", 1, 9, 3, 1)
    if content_hash(entries) != EXPECTED_CONTENT:
        raise ValueError("Generated content differs from the native reference")
    return entries


def write_archive(files, output):
    output = Path(output)
    if output.is_symlink():
        raise ValueError("Output is a link; preserved")
    if output.exists():
        with zipfile.ZipFile(output) as archive:
            names = archive.namelist()
            if (len(names) != len(set(names)) or archive.testzip() is not None
                    or {name: archive.read(name) for name in names} != files):
                raise ValueError("Existing archive differs; preserved")
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, suffix=".partial", delete=False) as temporary:
        staging = Path(temporary.name)
    try:
        with zipfile.ZipFile(staging, "w", zipfile.ZIP_DEFLATED) as archive:
            for name, data in sorted(files.items()):
                member = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
                member.create_system = 3
                member.external_attr = 0o100644 << 16
                member.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(member, data)
        staging.replace(output)
    finally:
        staging.unlink(missing_ok=True)


def build_archive(source, shaders, output):
    output = Path(output)
    for root in (Path(source), Path(shaders)):
        if output.resolve().is_relative_to(root.resolve()):
            raise ValueError("Output must be outside resource inputs")
    write_archive(generate_entries(collect_inputs(source, shaders)), output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Pinned Shipwright soh/assets/custom")
    parser.add_argument("shaders", type=Path, help="Pinned libultraship src/fast/shaders")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        build_archive(args.source, args.shaders, args.output)
    except (ValueError, OSError, zipfile.BadZipFile, struct.error, zlib.error) as error:
        parser.exit(1, f"Port archive: {error}\n")
    print(f"Clean port archive: {args.output} (content SHA256 {EXPECTED_CONTENT})")


if __name__ == "__main__":
    main()
