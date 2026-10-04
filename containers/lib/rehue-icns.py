#!/usr/bin/env python3
"""Set the hue of every coloured pixel in an .icns, keeping saturation, value and alpha.

Pure stdlib (zlib + struct): no Pillow, no install step, works offline. Greys keep no
hue and are left alone, so white glyphs stay white. The hue is ABSOLUTE, not a rotation:
passing 185 makes every coloured pixel hue 185 whatever it was before.

Usage: rehue-icns.py <in.icns> <out.icns> <hue-degrees>
"""
import colorsys, os, shutil, struct, subprocess, sys, tempfile, zlib

PNG_SIG = b"\x89PNG\r\n\x1a\n"


def _chunks(data):
    off = len(PNG_SIG)
    while off < len(data):
        (ln,) = struct.unpack(">I", data[off:off + 4])
        typ = data[off + 4:off + 8]
        body = data[off + 8:off + 8 + ln]
        yield typ, body
        off += 12 + ln


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def _unfilter(raw, width, height, bpp):
    stride = width * bpp
    out = bytearray(stride * height)
    pos = 0
    for y in range(height):
        ft = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos + stride]); pos += stride
        base = y * stride
        prior = out[base - stride:base] if y else bytes(stride)
        if ft == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prior[i]) & 0xFF
        elif ft == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prior[i]) >> 1)) & 0xFF
        elif ft == 4:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                ul = prior[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + _paeth(left, prior[i], ul)) & 0xFF
        elif ft != 0:
            raise ValueError(f"bad PNG filter {ft}")
        out[base:base + stride] = line
    return out


def _png_write(path, width, height, bpp, pixels):
    ct = 6 if bpp == 4 else 2
    stride = width * bpp
    raw = bytearray()
    for y in range(height):
        raw.append(0)                                   # filter: None
        raw += pixels[y * stride:(y + 1) * stride]
    def chunk(typ, body):
        return (struct.pack(">I", len(body)) + typ + body
                + struct.pack(">I", zlib.crc32(typ + body) & 0xFFFFFFFF))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, ct, 0, 0, 0)
    with open(path, "wb") as fh:
        fh.write(PNG_SIG + chunk(b"IHDR", ihdr)
                 + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                 + chunk(b"IEND", b""))


def rehue_png(path, hue):
    data = open(path, "rb").read()
    if not data.startswith(PNG_SIG):
        return False
    idat = b""
    width = height = bpp = None
    for typ, body in _chunks(data):
        if typ == b"IHDR":
            width, height, depth, ct, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or ct not in (2, 6) or interlace:
                raise ValueError(f"{path}: unsupported PNG (depth={depth} ct={ct} "
                                 f"interlace={interlace}); expected 8-bit RGB/RGBA")
            bpp = 4 if ct == 6 else 3
        elif typ == b"IDAT":
            idat += body
        elif typ == b"IEND":
            break
    px = _unfilter(zlib.decompress(idat), width, height, bpp)
    h = (hue % 360) / 360.0
    for i in range(0, len(px), bpp):
        r, g, b = px[i] / 255.0, px[i + 1] / 255.0, px[i + 2] / 255.0
        _, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s == 0:                       # greys carry no hue; leave them alone
            continue
        r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
        px[i], px[i + 1], px[i + 2] = round(r2 * 255), round(g2 * 255), round(b2 * 255)
    _png_write(path, width, height, bpp, px)
    return True


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__.strip().splitlines()[-1])
    src, dst, hue = sys.argv[1], sys.argv[2], float(sys.argv[3])
    work = tempfile.mkdtemp(prefix="rehue.")
    try:
        iconset = os.path.join(work, "AppIcon.iconset")
        subprocess.run(["iconutil", "-c", "iconset", src, "-o", iconset], check=True)
        n = sum(rehue_png(os.path.join(iconset, f), hue)
                for f in sorted(os.listdir(iconset)) if f.endswith(".png"))
        if not n:
            sys.exit("no PNGs found in iconset")
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", dst], check=True)
        print(f"rehued {n} images -> {dst} (hue {hue}deg)")
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
