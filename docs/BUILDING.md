# Building and testing

## What you need

- **z80asm**, Bas Wijnen's, version 1.8.
- **Python**, with `pyserial` for the PC tools (`pip install pyserial`)
- Optional: `mtools` (for the source disks and the tests) and `dosfstools`
  (`fsck.fat`) for the checks. These are programs, not Python packages (the pip
  package called `mtools` is something else): `brew install mtools dosfstools` on
  a Mac, `apt install mtools dosfstools` on Debian or Ubuntu.

## Building

    python3 build.py                      everything
    python3 build.py ampdos               only that (and what it needs)
    python3 build.py --machine AMPRO ...  for one machine layer (AMPRO is the default and,
                                          so far, the only one)

`build.py` starts by saying what it builds: the version, the machine (from
the `; Machine:` line of `KERNEL/MACHINE/<name>/MACHINE.INC`) and the date
the OS will start with. Then one line per program: its size, its load
address and how much room it has left below its limit.

Everything about the programs is in one table at the top of `build.py`, the
`PROGRAMS` list: each program's source, load address, limit, where it goes on
the boot disk (the root, `\BIN`, or not at all), which source disk carries
its sources, and a few words for the boot disk's README. The boot disk, its
README, the source disks and their `BUILD.BAT` files are all made from that
table, so a new program is one line there.

Always build through `build.py`: it writes the files the sources include into
`build/GEN/` (the version from `VERSION`, today's date, the packed banner from
`KERNEL/CMD/BANNER.TXT`, and four one-line files that include the machine
layer's files, see [PORTING.md](PORTING.md)), keeps the binaries other sources
`incbin` in `build/BIN/`, and builds things in the right order. The sources
name those files as the source disks have them (`include "GEN/VERSION.INC"`,
`incbin "BIN/BOOTSEC.BIN"`), and z80asm is run with `-I build` to find them.

**The sources are kept as they go on the Ampro.** Everything in `KERNEL/` and
`PROGRAMS/` that ASM reads has an 8.3 name in capitals, tabs at 8-column stops
(not runs of spaces), no trailing spaces and LF line ends, and `build.py` copies it
onto the source disks unchanged; a source that is not packed stops the build
(`python3 tools/build/srcdisk.py --pack FILE` packs it). Set your editor to tabs,
8 wide. The exceptions: `KERNEL/CMD/BANNER.TXT` (ASCII art, read as it is), and
`PROGRAMS/BASIC/BAS32K.ASM` (Grant Searle's, unchanged) and `SEREXT.ASM`, which
`mkbasic.py` reads to make the `BASIC.ASM` that goes on the disk.

`build.py` makes two folders, and neither is kept in the repository:

| Folder | What is in it |
|---|---|
| `release/` | the disks, published as the release files. `ampdos_boot.img`: the boot disk, a 360K floppy. In the root: AMPDOS.SYS, BASIC, HELLO, IMGWRITE, SETUP, README.TXT. In `\BIN` (the shell's default `PATH`): EDIT, MON, DISASM, ASM, DISKED, ATTRIB, TREE, XCOPY, UNDELETE, HEAD, TAIL, TR, DIFF, DISKCOMP, DUMP, HEXED, DEFRAG, SCANDISK, MEMMAP, ASCII. `ampdos_src1.img` to `ampdos_src3.img`: the source disks (the OS's sources, the programs' and BASIC's, the utilities'), each with a `BUILD.BAT` (run in B:, with the boot disk in A:). Nothing assembled is on them (made with mtools: `tools/build/srcdisk.py`) |
| `build/` | working files. `build/BIN/` has every binary as it goes on the disk: `AMPDOS.BIN` (the OS, at 0000h: `AMPDOS.SYS`), `BOOTSEC.BIN`, `MONBODY.BIN` (the monitor itself, which `MON.BIN` carries) and `NAME.BIN` for each program. `build/GEN/` has the generated includes |

The boot disk's `README.TXT` is a plain text file kept with the machine layer,
`KERNEL/MACHINE/<name>/README.TXT`, because it talks about that machine. It goes
onto the disk as it is (with CR LF line ends). Change it there; if you add a
program to the boot disk, add a line for it there too.

The version is in one place: `VERSION`. The OS starts at the date it was built.

## Running and updating

Write `ampdos_boot.img` to a disk (see the README) and boot it. To try a new build:
`SERRECV AMPDOS.SYS` on the Ampro, `python3 tools/pc/serxfer.py send build/BIN/AMPDOS.BIN
AMPDOS.SYS` on the PC, then `EXIT`. Keep a second boot disk in case a new build
does not start.

## The PC tools

| | |
|---|---|
| `tools/pc/serxfer.py` | the PC side of `SERRECV` / `SERSEND`: `send FILE [NAME]`, `get [FILE]` |
| `tools/pc/imgsend.py` | the PC side of `IMGWRITE`: a whole 360K disk image |
| `tools/pc/serlog.py` | log what comes out of Serial B (`-t` adds time stamps); pairs with `MIRROR ON` |
| `tools/build/mkdisk.py` | make a FAT12 360K disk image with files on it |
| `tools/build/mkbanner.py` | pack `BANNER.TXT` (build.py runs it) |
| `tools/build/srcdisk.py` | make the source disks (build.py runs it) |


The serial tools look for a USB serial adapter themselves, or take the port name
first (`/dev/ttyUSB0`, `COM3` ...).

## Testing

- **On the board:** copy `tests/hw/TESTALL.BAT`, `TESTEND.BAT` and `TESTBAS.BAS`
  onto a boot disk (BASIC, HELLO and the programs in `\BIN` are already on it) and
  run `TESTALL - one two`. Each check prints `ok:` or
  `FAIL:` with its number; each failure also leaves `A:\FAILS\Fnn.TXT`, and the end
  lists that directory: empty means everything passed. Time `SLEEP 10` with a watch
  when it asks.
- **BASIC on the board:** `tests/hw/BASTEST.BAS` tries every BASIC keyword, the
  maths above all (each function against known values, then identities such as
  SIN²+COS²=1 over a few hundred values, with the largest error shown), and prints
  `ok` or `FAIL` for each of its 91 checks. Copy it to a disk and type
  `BASIC BASTEST`: about 2 minutes, then a STOP (type `CONT`) and an INPUT (type
  `42`). It needs about 8 KB, so 15 KB stay free. LOAD, SAVE, SSAVE, SLOAD, LIST,
  NEW and RUN are left to try by hand.

## Source conventions

- Each program is one top-level `.ASM` with an `org`, which `include`s what it needs
  (paths from the project root).
- Every label starts with its module's prefix (`fd_`, `siob_`, `con_`, `sh_`), so
  modules can be included in any order. What belongs to one machine is in
  `KERNEL/MACHINE/<name>/`, behind the `mc_` and `md_` calls ([PORTING.md](PORTING.md)). Local labels are numbered (`fd_rx1`).
- Each routine says what it takes and gives. Unless it says otherwise, AF, BC, DE and
  HL are changed. Carry set means an error.
- Every variable and buffer address is in `KERNEL/INC/RAM.INC` and `BUFS.INC` (the
  machine's own in its `MRAM.INC`), so the memory map is in one place.
- No interrupts: everything is polled.
