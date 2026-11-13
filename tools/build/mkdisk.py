#!/usr/bin/env python3
"""Make a DOS 360K FAT12 disk image (the same format the AMPRO drive uses here).

usage: mkdisk.py out.img [file ...]
(build.py calls make() with boot_code= for ampDOS's boot sector;
system= puts bytes in extra reserved sectors after it, moving everything below up.)

Layout (all sizes in 512-byte sectors, LBA = (cyl*2+side)*9 + sector-1):
  0        boot sector with the BIOS parameter block
  1-2      FAT 1          3-4  FAT 2
  5-11     root directory (112 entries of 32 bytes)
  12-719   data: cluster n (n >= 2) is sectors 12+(n-2)*2 and the next one
Files are stored in 8.3 upper-case names, one after another.  Unused data
sectors are filled with F6h, as DOS FORMAT does."""
import sys, os

SEC, SPC, NFAT, ROOTENT, TOTAL, MEDIA, SPF = 512, 2, 2, 112, 720, 0xFD, 2
ROOTSEC = ROOTENT * 32 // SEC

def name83(path):
    base = os.path.basename(path).upper()
    stem, _, ext = base.partition('.')
    return (stem[:8].ljust(8) + ext[:3].ljust(3)).encode('ascii')

def make(out, files, boot_code=None, system=b'', label='NO NAME'):
    """boot_code: 512 bytes for sector 0 (its BPB, 0Bh-3Dh, is filled in here);
    system: bytes for the reserved sectors after it (they become part of the
    reserved area, so the FATs, root and data move up)."""
    rsvd = 1 + (len(system) + SEC - 1) // SEC
    DATA0 = rsvd + NFAT * SPF + ROOTSEC
    NCLUS = (TOTAL - DATA0) // SPC
    img = bytearray(b'\xF6' * SEC * TOTAL)
    if boot_code is not None:
        assert len(boot_code) == SEC
        boot = bytearray(boot_code)
    else:
        boot = bytearray(SEC)
        boot[0:3] = b'\xEB\x3C\x90'
        boot[3:11] = b'AMPDOS  '
    bpb = [(11, 2, SEC), (13, 1, SPC), (14, 2, rsvd), (16, 1, NFAT), (17, 2, ROOTENT),
           (19, 2, TOTAL), (21, 1, MEDIA), (22, 2, SPF), (24, 2, 9), (26, 2, 2), (28, 4, 0)]
    for off, n, v in bpb:
        boot[off:off + n] = v.to_bytes(n, 'little')
    boot[36] = 0                                  # extended BPB: drive number,
    boot[38] = 0x29                               # signature, serial, label, type
    boot[39:43] = (0x414D5044).to_bytes(4, 'little')
    boot[43:54] = label.upper().encode('ascii')[:11].ljust(11)
    boot[54:62] = b'FAT12   '
    boot[510:512] = b'\x55\xAA'
    img[0:SEC] = boot
    img[SEC:SEC + len(system)] = system

    fat = [0] * (NCLUS + 2)
    fat[0], fat[1] = 0xF00 | MEDIA, 0xFFF
    nextc = [2]

    def alloc(data):                              # clusters for data -> the first
        nc = (len(data) + SEC * SPC - 1) // (SEC * SPC)
        first = nextc[0] if nc else 0
        for k in range(nc):
            c = nextc[0] + k
            fat[c] = c + 1 if k < nc - 1 else 0xFFF
            o = (DATA0 + (c - 2) * SPC) * SEC
            chunk = data[k * SEC * SPC:(k + 1) * SEC * SPC]
            img[o:o + SEC * SPC] = chunk.ljust(SEC * SPC, b'\0')
        nextc[0] += nc
        return first

    def entry(name, attr, first, size, stamp):
        e = bytearray(32)
        e[0:11] = name
        e[11] = attr
        y, mo, d = __import__('time').localtime(stamp)[:3]
        e[24:26] = (((y - 1980) << 9) | (mo << 5) | d).to_bytes(2, 'little')
        e[26:28] = first.to_bytes(2, 'little')
        e[28:32] = size.to_bytes(4, 'little')
        return bytes(e)

    # files: a path, or (path, "DIR") to put it in that directory of the root
    dirs = {}                                     # name -> [entries]
    top = []
    for f in files:
        path, sub = (f, None) if isinstance(f, str) else f
        data = open(path, 'rb').read()
        e = entry(name83(path), 0x20, alloc(data), len(data), os.path.getmtime(path))
        if sub is None:
            top.append(e)
        else:
            dirs.setdefault(sub, []).append(e)
    for sub, ents in dirs.items():                # each directory: . .. and its files
        stamp = __import__('time').time()
        ents = [None, None] + ents
        data = b'\0' * (32 * len(ents))
        first = alloc(data.ljust(((len(data) + SEC * SPC - 1) // (SEC * SPC)) * SEC * SPC, b'\0'))
        ents[0] = entry(b'.          ', 0x10, first, 0, stamp)
        ents[1] = entry(b'..         ', 0x10, 0, 0, stamp)
        blob = b''.join(ents)
        o = (DATA0 + (first - 2) * SPC) * SEC
        img[o:o + len(blob)] = blob
        top.append(entry(sub.upper().ljust(11).encode('ascii'), 0x10, first, 0, stamp))
    root = bytearray(ROOTSEC * SEC)
    for i, e in enumerate(top):
        root[i * 32:(i + 1) * 32] = e
    fb = bytearray(SPF * SEC)                     # pack 12-bit entries
    for n in range(0, len(fat) - 1, 2):
        a, b = fat[n], fat[n + 1]
        o = n * 3 // 2
        fb[o:o + 3] = bytes([a & 0xFF, (a >> 8) | ((b & 0xF) << 4), b >> 4])
    for k in range(NFAT):
        o = (rsvd + k * SPF) * SEC
        img[o:o + SPF * SEC] = fb
    img[(rsvd + NFAT * SPF) * SEC:DATA0 * SEC] = root
    open(out, 'wb').write(img)
    print(f'{out}: {len(files)} file(s), {nextc[0] - 2} cluster(s) used of {NCLUS}'
          + (f', {rsvd - 1} system sector(s) after the boot sector' if system else ''))

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    make(sys.argv[1], sys.argv[2:])
