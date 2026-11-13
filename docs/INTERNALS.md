# How ampDOS Works

## Booting

The Little Board's original AMPRO boot ROM copies itself to RAM
at 8000h, sets up both serial ports (9600 baud), reads track 0, side 0, sector 1 of
drive A to 9000h and jumps there, with the ROM still switched on. That sector is
`KERNEL/MACHINE/AMPRO/BOOTSEC.ASM`:

- It is also the disk's FAT12 boot sector, so the disk stays a normal DOS disk. 
  A DOS disk starts `EB 3C 90` (an x86 jump over the BIOS parameter block to 
  3Eh); ours starts `3E 3C 90` (`LD A,3Ch` / `SUB B`: harmless on a Z80), (at
  least on the SCSI boot ROM v1.2) boots only a sector whose first byte is 
  3Eh or 21h. A `JR` in the 8-byte "OEM name" field then jumps over the 
  parameter block to 3Eh as well.
- From 3Eh, the loader reads the FAT and the root directory (using the disk's own
  parameter block), finds `AMPDOS.SYS`, follows its clusters through the FAT to
  A000h, switches the ROM off (board control bit 6: RAM at 0000h-7FFFh), copies 
  the file to 0000h and jumps to it. It drives the WD1772 itself and uses
  nothing of the ROM. Everything fits in 512 bytes.

At 0000h (`KERNEL/OS/AMPDOS.ASM`) the OS sets up the console; then every variable is
cleared, the call table copied to FF00h, the drives reset, and the banner, the RAM
test, the date question and the prompt follow.

## Memory

| | |
|---|---|
| 0000-5EFF | the OS code (in the RAM under the ROM, which is switched off) |
| 5F00-7FFF | its buffers (`BUFS.INC`) |
| 8000-FBFF | programs |
| FC00-FCFF | the variables |
| FD00-FD7F | the command line |
| FD80-FEFF | the stack |
| FF00-FF7F | the OS call table |

The buffers: the track cache (4.5 KB), the whole FAT (1 KB), a sector and a
directory sector, the read-back sector for verified writes, the current directory
paths of both drives, a second page of shell variables, the batch file's state, and
the shell's own 512 bytes: the command history (256), SET's variables (64), the
terminal's screen codes (48) and PATH (64). Every address is named in
`KERNEL/INC/RAM.INC` and `BUFS.INC`.

No code ever writes to its own area, so the image in memory stays exactly as
loaded: `SYS` saves it as `AMPDOS.SYS` straight from 0000h.

## Floppy drives

`KERNEL/MACHINE/AMPRO/FD.ASM`: DOS 360K (40 cylinders, 2 sides, 9 sectors of 512 bytes),
drives A and B, a one-track write-back cache (a whole track is read at once, written
at once with every other sector per turn, and read back to verify), formatting with
Write Track. The timing lessons that shaped it (the transfer loop must answer the
controller within 32 microseconds; only 6 ms steps work; the controller's status bit
7 means "motor on") are in [HARDWARE.md](HARDWARE.md).

## The file system

`KERNEL/FS/`: FAT12, the whole FAT kept in memory. Files are read and written
through a 16-byte file control block. Writes go into the track cache and the FAT in
memory; they reach the disk on close, on a flush, or when another track is needed.
Subdirectories are cluster chains with `.` and `..` entries, as DOS makes them, so
disks are interchangeable with PCs. Long file names, the volume label and deleted
entries are skipped. A read-only file cannot be deleted or written over.

One disk is mounted at a time: its FAT is the one in memory. Anything that works on
two drives (COPY, ASM writing to the other drive) mounts each again before it reads
or writes there. The disk's size comes from the driver (`md_geom`): MOUNT takes any
FAT12 disk the drive can read.

## The shell

`KERNEL/SHELL/SHELL.ASM` reads a line, looks the first word up in its command table,
and runs the command, or else a program (`NAME.BIN`, then `NAME.BAT`; here, then in
the `PATH` directories). A command may give up at any point by jumping back to the prompt loop.
Commands run for programs through `OS_EXEC` (BASIC's `DOS`), then borrow the
program's free memory instead of the TPA. Batch files are read a byte at a time
from an open file; their arguments, the line being read and GOTO's state live in a
256-byte buffer.

**Output redirection** (`command > file`, `>> file`, `SHELL/REDIRECT.ASM`): the
console keeps the output in the TPA's top 8 KB, and the shell writes it to the file
when the command has ended, so writing never mixes with the command's own use of the
file system.

**The screen.** `SCREEN action hh ...` keeps up to 6 bytes for each of 8 actions
(clear, home, erase to the end of the line or the screen, the four cursor moves),
and `SCREEN ROWS`, `COLS`, `WRAP` the terminal's size and ways. `OS_SCREEN` sends
the codes, and `CLEAR` uses them, or empty lines on a teletype. `SETUP` finds the
codes and writes them as `@SCREEN` lines in `A:\AUTOEXEC.BAT`, which runs at every
start: the batch file is the settings.

**The RAM test** (at the start, and `MEM`) checks all 64 KB: each byte with 55h and
AAh and put back, the OS's own code through a copy of the test in the verify buffer,
every 1 KB block numbered, and 8000h-FBFFh filled with an address pattern and read
back.

## Programs

Programs load at 8000h, get HL = the rest of the command line, and call the OS
through the table at FF00h (docs/PROGRAMMING.md). Most are in `\BIN`.

- **MON** is a small stub, `MON.ASM`, that copies the monitor (`MONBODY.ASM` and the
  disassembler `MONDIS.ASM`, assembled for BC00h) to just under the OS, so the whole
  TPA from 8000h is free to look at and to load programs into. **DISASM** uses the
  same decoder, `DISCORE.ASM`, which reads the code through an address offset: the
  file can sit anywhere in memory while its addresses are its own.
- **ASM** assembles the language of these sources, the OS too, to the same bytes as
  z80asm: ampDOS builds itself. It makes two passes, reading the sources from the
  disk each time (a 128-byte buffer per open include), and keeps only the symbols in
  memory, 4 bytes and the name each, in 256 hash chains.
- **The utilities** share `PLIB.INC` (words, names, wildcards), `RFILE.INC` (reading
  a file a byte at a time) and `WALK.INC` (going through a directory tree).

## Source

```
KERNEL/OS/AMPDOS.ASM     the OS's top file: restart vectors, start (start reading here)
KERNEL/OS/BODY.ASM       everything else, in reading order
KERNEL/OS/CALLS.ASM      the OS call table, copied to FF00h at start
KERNEL/INC/              RAM.INC + BUFS.INC (memory), OS.INC (for programs)
KERNEL/SHELL/SHELL.ASM   the prompt, parsing, the command table, helpers
KERNEL/SHELL/PATH.ASM    drives and paths behind every name
KERNEL/SHELL/WILD.ASM    wildcard names (* and ?) for DIR, DEL and COPY
KERNEL/SHELL/HISTORY.ASM the command history (Up/Down are in LIB/GETLINE.ASM), HISTORY
KERNEL/SHELL/REDIRECT.ASM  > and >> (output to a file)
KERNEL/CMD/               the commands, a file each (or a few that go together):
                         DIR, TYPE (TYPE MORE), COPY (COPY DEL MV), RUN (and PATH),
                         CD (CD MD RD), DATE, FDISK, MISC (CLEAR TOUCH PWD), MEM,
                         XFER (SERRECV SERSEND), BATCH, UTIL (SLEEP TRUE FALSE WC ID GO
                         MIRROR), DELTREE, PEEK (PEEK POKE IN OUT), LABEL (LABEL VOL),
                         CHKDSK, DISKCOPY, CRC, CMP (CMP FC), FIND, SORT, TERM, SYS,
                         SCREEN (and OS_SCREEN: the terminal's codes), BANNER
KERNEL/CMD/BANNER.TXT    the start-up banner (packed by tools/build/mkbanner.py)
KERNEL/MACHINE/AMPRO/    the machine layer (docs/PORTING.md): MACHINE.INC (constants, HW.INC:
                         the ports), MRAM.INC (its variables), CONDRV.ASM + SIOA.ASM (console),
                         DRIVERS.ASM: SIOB.ASM (Serial B), FD.ASM (floppy), MACH.ASM (md_geom,
                         timing, ID, reboot); BOOTSEC.ASM (the boot sector and loader)
KERNEL/LIB/              CONSOLE.ASM, GETLINE.ASM, NUMBER.ASM (32-bit decimal)
KERNEL/FS/               FS.INC, MOUNT.ASM, FAT.ASM, DIRENT.ASM, FILE.ASM, SUBDIR.ASM
PROGRAMS/                hello, edit, imgwrite, mon, disasm, asm, setup, disked, the utilities
                         (attrib, tree, xcopy, undelete, head, tail, tr, diff, diskcomp, dump,
                         hexed, defrag, scandisk, memmap, ascii: PLIB.INC, RFILE.INC,
                         WALK.INC), BASIC/
                         (mon: MONBODY.ASM, MONDIS.ASM; DISASM.ASM; both use DISCORE.ASM;
                         asm: ASM.ASM, ASMEXPR.ASM, ASMZ80.ASM)
tools/pc/, build/        the PC side, the build's helpers
c/                       C programs with uc80 (outside the build)
```
