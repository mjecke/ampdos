#!/usr/bin/env python3
"""dosimg.py - make a copy of an ampDOS disk image that a PC or Mac mounts -
    For diagnostic purposes! makes new image with _dos appended that you can 
    then mount on normal PC.

    python3 dosimg.py ampdos_boot.img            

An ampDOS disk is an ordinary 360K FAT12 disk, except for its first byte: the
AMPRO boot ROM wants 3Eh there (LD A,n), and DOS disks have EBh (an x86 JMP).
macOS will not mount it without the EBh, so the copy gets one.  Nothing else
changes; the original is left as it is.  (The copy no longer boots on the
Little Board: use the original for that, or put the 3Eh back!!!!!!)

"""
import os, sys

if len(sys.argv) not in (2, 3):
    sys.exit(__doc__)
src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) == 3 else os.path.splitext(src)[0] + "_dos.img"
img = bytearray(open(src, "rb").read())
if len(img) < 512 or img[510:512] != b"\x55\xAA":
    sys.exit(f"{src}: no boot sector signature (55 AA): not a FAT disk image")
if img[0] == 0xEB:
    print(f"{src}: already starts EB (a DOS disk); copied as it is")
elif img[0] == 0x3E:
    img[0] = 0xEB
else:
    sys.exit(f"{src}: starts {img[0]:02X}h, not 3Eh: not an ampDOS disk?")
open(dst, "wb").write(img)
print(f"{dst}: written ({len(img) // 1024} KB)")
