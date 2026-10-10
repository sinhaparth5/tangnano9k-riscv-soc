#!/usr/bin/env python3
"""Convert an 8x16 PSF1/PSF2 console font to a $readmemh file: 128 glyphs x 16 rows, one byte per line (MSB = left pixel)."""
import gzip, sys
raw = open(sys.argv[1], 'rb').read()
if sys.argv[1].endswith('.gz'): raw = gzip.decompress(raw)
if raw[:2] == b'\x36\x04':                      # PSF1
    off, h = 4, raw[3]
elif raw[:4] == b'\x72\xb5\x4a\x86':            # PSF2
    off, h = int.from_bytes(raw[8:12], 'little'), int.from_bytes(raw[24:28], 'little')
    assert int.from_bytes(raw[28:32], 'little') == 8, "need 8-pixel-wide font"
else: sys.exit("not a PSF font")
assert h == 16, "need 16-row font"
print("\n".join("%02x" % b for b in raw[off:off + 128 * 16]))
