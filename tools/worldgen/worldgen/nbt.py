"""Minimal read-only NBT decoder (enough for level.dat and Anvil chunks).

Compound tags become dicts, lists become Python lists, long arrays become numpy int64 arrays, so a chunk's
packed block data stays cheap. Nothing here ever writes to disk.
"""
from __future__ import annotations

import gzip
import struct
import zlib

import numpy as np

_S_B = struct.Struct(">b")
_S_H = struct.Struct(">H")
_S_h = struct.Struct(">h")
_S_i = struct.Struct(">i")
_S_q = struct.Struct(">q")
_S_f = struct.Struct(">f")
_S_d = struct.Struct(">d")


def _read_payload(buf: bytes, pos: int, tag: int):
    if tag == 10:  # compound
        out = {}
        while True:
            t = buf[pos]
            pos += 1
            if t == 0:
                return out, pos
            n = _S_H.unpack_from(buf, pos)[0]
            pos += 2
            name = buf[pos : pos + n].decode("utf-8", "replace")
            pos += n
            out[name], pos = _read_payload(buf, pos, t)
    if tag == 8:  # string
        n = _S_H.unpack_from(buf, pos)[0]
        pos += 2
        return buf[pos : pos + n].decode("utf-8", "replace"), pos + n
    if tag == 9:  # list
        t = buf[pos]
        n = _S_i.unpack_from(buf, pos + 1)[0]
        pos += 5
        out = [None] * max(n, 0)
        for i in range(n):
            out[i], pos = _read_payload(buf, pos, t)
        return out, pos
    if tag == 12:  # long array
        n = _S_i.unpack_from(buf, pos)[0]
        pos += 4
        return np.frombuffer(buf, dtype=">i8", count=n, offset=pos), pos + 8 * n
    if tag == 11:  # int array
        n = _S_i.unpack_from(buf, pos)[0]
        pos += 4
        return np.frombuffer(buf, dtype=">i4", count=n, offset=pos), pos + 4 * n
    if tag == 7:  # byte array
        n = _S_i.unpack_from(buf, pos)[0]
        pos += 4
        return np.frombuffer(buf, dtype=">i1", count=n, offset=pos), pos + n
    if tag == 1:
        return _S_B.unpack_from(buf, pos)[0], pos + 1
    if tag == 2:
        return _S_h.unpack_from(buf, pos)[0], pos + 2
    if tag == 3:
        return _S_i.unpack_from(buf, pos)[0], pos + 4
    if tag == 4:
        return _S_q.unpack_from(buf, pos)[0], pos + 8
    if tag == 5:
        return _S_f.unpack_from(buf, pos)[0], pos + 4
    if tag == 6:
        return _S_d.unpack_from(buf, pos)[0], pos + 8
    raise ValueError(f"unknown NBT tag {tag} at {pos}")


def parse(buf: bytes) -> dict:
    """Parse an uncompressed NBT document whose root is a named compound."""
    if buf[0] != 10:
        raise ValueError("NBT root is not a compound")
    n = _S_H.unpack_from(buf, 1)[0]
    value, _ = _read_payload(buf, 3 + n, 10)
    return value


def read_gzip_file(path) -> dict:
    with open(path, "rb") as f:  # read-only by construction
        raw = f.read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    elif raw[:1] == b"\x78":
        raw = zlib.decompress(raw)
    return parse(raw)
