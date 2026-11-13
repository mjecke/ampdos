# Porting ampDOS to another Z80 machine

I eventually want to port ampDOS to other Z80 computers other than the AMPRO 
Little Boards.  Hardware like to RC2014 Z80 homebrew kits are very similar and
may be the next target.

I've tried to keep everything in ampDOS that touches the hardware is in one
folder, `KERNEL/MACHINE/AMPRO/`. The rest of the OS reaches the hardware only
through the routines and constants listed here. A port is a new folder,
`KERNEL/MACHINE/<NAME>/`, that provides the same files, and a build with
`python3 build.py --machine NAME`. The default is `AMPRO`, the only machine
so far.

## How the build finds the machine

`build.py` writes four one-line files into `build/GEN/`. Each one points into
the machine's folder:

| Generated file | Includes | Where the OS includes it |
|---|---|---|
| `GEN/MACHINE.INC` | `MACHINE.INC`: the constants, and the ports (`HW.INC`) | `KERNEL/OS/AMPDOS.ASM`, first |
| `GEN/MACHRAM.INC` | `MRAM.INC`: the machine layer's variables | `KERNEL/INC/RAM.INC` |
| `GEN/MACHCON.ASM` | `CONDRV.ASM`: the console driver | `KERNEL/LIB/CONSOLE.ASM`, at its end |
| `GEN/MACHDRV.ASM` | `DRIVERS.ASM`: every other driver, and `MACH.ASM` | `KERNEL/OS/BODY.ASM`, before the file system |

The source disks carry these generated files as they carry `GEN/VERSION.INC`,
so `BUILD` on the machine itself builds the same OS.

## What a machine provides

**Constants** (`MACHINE.INC`)

| Name | AMPRO | What it is |
|---|---|---|
| `M_CLOCK` | 4000 | the CPU clock in kHz (timing loops) |
| `M_DRIVES` | 2 | drives (A:, B:) |
| `M_SERIAL2` | 1 | a second serial port: Serial B (SERSEND, SERRECV, TERM, MIRROR). These commands are not optional yet: a machine without one needs them taken out first |
| `M_ROWS`, `M_COLS` | 24, 80 | the screen at the start (`SETUP` keeps the real size) |

**Variables** (`MRAM.INC`): the machine layer may use `VARS+01h` up to
`VARS+2Fh`. It must define `md_drive`, the selected drive (0 = A, 1 = B).

**Console** (`CONDRV.ASM`). Every routine keeps all registers except the ones
it returns. The RST 08h, 10h and 18h vectors jump to the three routines that
print, read and test the keyboard.

| Routine | Does |
|---|---|
| `mc_init` | sets the console up at the cold start |
| `mc_out` | A = a character to the screen |
| `mc_in` | waits for a key: A = it |
| `mc_stat` | NZ = a key is waiting |

**Disks** (`DRIVERS.ASM`). CF = failed, as the FAT code expects.

| Routine | Does |
|---|---|
| `md_init` | sets the drives up (the cold start, `RESTART W`) |
| `md_select` | A = drive: makes it the one the others act on |
| `md_present` | CF = no disk in it, so ampDOS says so at once instead of retrying |
| `md_geom` | for the selected drive: HL = its sectors, D = sectors a track, E = heads (D = 0: no tracks, as on a card), A = 1 if it can be formatted |
| `md_read`, `md_write` | HL = sector number (0 = the first), DE = 512 bytes of memory |
| `md_flush` | writes anything the driver is holding back (a write cache) |
| `md_drop` | forgets what it holds (after a disk change) |
| `md_off` | lets go of the drive (motors off) |
| `md_fmt`, `md_mkimg`, `md_rdtrk`, `md_wrtrk`, `md_vfytrk`, `md_restore` | track-level floppy access for FDISK and DISKCOPY only; not needed on a drive with no tracks |

The file system mounts any FAT12 disk whose size is no bigger than `md_geom`
says. On a drive with tracks, the disk's sectors a track and heads must also be
the drive's. FDISK and DISKCOPY are 360K floppy tools: on any other drive they
answer "not a disk this drive takes".

**The rest** (`MACH.ASM`)

| Routine | Does |
|---|---|
| `mach_wait` | DE = milliseconds: wait (SLEEP). CF = Esc pressed (it reads the keyboard through `con_kbhit`, `con_getc`) |
| `mach_id` | A = the board's ID jumpers (ID); return 0 if the machine has none |
| `mach_reboot` | back to the machine's boot ROM (EXIT) |
| `siob_init`, `siob_putc`, `siob_getc`, `siob_setup`, `siob_poll` | Serial B, while `M_SERIAL2` is 1 |

**Booting.** `BOOTSEC.ASM` is the machine's business: something must load
`AMPDOS.SYS` at 0000h and jump there. On the AMPRO, its ROM loads sector 0
to 9000h, and the boot sector loads the file and switches the ROM off.

## What does not move (yet)

- **The memory map.** The OS runs at 0000h, so a machine needs RAM there.
  Programs load at 8000h and the OS call table is at FF00h. Keep these two the
  same on every port: then a program that only uses OS calls runs everywhere,
  unchanged.
- **The FAT in memory.** The whole FAT is held in a 1 KB buffer (`FATBUF`).
  That is enough for a 360K floppy, but not for a large card. A card needs the
  FAT read a sector at a time, or FAT16.
- **The track cache.** `TRKBUF` (4608 bytes) is in `BUFS.INC`, where only
  the floppy driver uses it. A machine without one can use the space for
  something else.
- **AMPRO-only programs.** IMGWRITE (it carries its own copy of the floppy
  and Serial B drivers) and BASIC's Serial B extension.


The following is my roadmap for how to behind porting to a different machine:

1. Copy `KERNEL/MACHINE/AMPRO/` to `KERNEL/MACHINE/<NAME>/`. Names are 8.3,
   in capitals, so the source disks can carry them.
2. Change `HW.INC` and `MACHINE.INC` for the new machine's ports and clock,
   and `README.TXT` (the boot disk's README) for its name and how it boots.
3. Write `CONDRV.ASM` (the console) and the disk routines.
4. Make `md_geom` tell the truth about the drives.
5. Write `MACH.ASM`'s timing, ID and reboot.
6. Write a boot sector, or whatever the machine needs, that loads `AMPDOS.SYS`
   at 0000h.
7. Run `python3 build.py --machine <NAME>`. The OS must still end below 5F00h.
8. Run TESTALL on the machine.
