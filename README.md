# ampDOS

A small yet incredily functional OS for the **AMPRO Little Board/Z80** (1984)

Designed to be a DOS-like experience, it has a command shell, a
FAT12 file system that reads and writes ordinary 360K PC floppies, batch files,
serial file transfers to a modern computer, a version of Microsoft BASIC with 
disk and special ampDOS commands added, and many extra utilities.
Written from scratch in Z80 assembly, it mostly keeps one small commented file 
per part, and it carries its own assembler: 
ampDOS has most all the tools to do development in z80 assembly and build itself
and new programs on the real hardware. 

See COMMANDS.MD for comprehensive documentation of what all ampDOS can do.

Booting on a real AMPRO LittleBoard Plus attached to a serial terminal console:

https://github.com/user-attachments/assets/6d844679-50e4-4abb-a38d-82d86ff10cc9


## Try it

You need:
- Little Board or Little Board Plus with its original AMPRO boot ROM
(I have tested with v2.0, and with the SCSI boot ROM v1.2), 
- a 5.25" double-sided double-density drive as drive A and 360k floppy
- and a serial terminal at 9600 baud, 8N1, on the Serial A port of the AMPRO.

1. Download `ampdos_boot.img` from the releases 
   (or build it: `python build.py` puts a fresh built disk img it `release/`).
2. Write it to a 5.25" DSDD disk: a PC with a 360K drive, or a Greaseweazle or 
   something similar. 
3. Put it in drive A and switch on. The ROM boots it: `booting . . . . .`, a
   banner, a RAM test, asks to set the date, and then the `A>` prompt. 
   `HELP` lists the commands.
4. (optional) To give some info to ampDOS about your terminal:
   Type `SETUP` once. It tries the screen codes terminals of the time used
   (VT52, VT100, ADM-3A, H19, TeleVideo ...), one action at a time, and you say
   which work. Then it asks the screen's size. `CLEAR` and programs then use the
   codes that passed, and they are kept in `AUTOEXEC.BAT`, which runs at every
   start.

The OS is the file `AMPDOS.SYS` on that disk: the stock boot ROM loads it into
RAM, and programs get 31 KB (8000h-FBFFh). 

The boot disk's root holds the OS , `AUTOEXEC.BAT`, `SETUP`, `HELLO`, `IMGWRITE`
(it writes new disks) and `BASIC`. Every other program is in `\BIN`, 
which the shell searches as well (it is in the PATH).  

The OS kernel itself contains many useful utilities and can fully operate
without the disk in the drive after boot, allowing for this system to be used 
to work on mutliple disks at a time even with only a single drive. 

*Note: for the Little Board Plus there is currently no support of SCSI devices.*

## Scope

ampDOS is a small, hobby OS, yet is very useable right now with plenty of 
functionality already built-in.   
It is **not CP/M compatible and does not try to be**: its programs load at 8000h 
and call the OS through a table at FF00h, not through BDOS. 
If you want to run CP/M programs on a Little Board, boot CP/M instead.


## Documentation

- [docs/COMMANDS.md](docs/COMMANDS.md): every command, names and paths, EDIT, IMGWRITE
- [docs/COMMANDS.md#mon](docs/COMMANDS.md#mon): MON, the machine code monitor
- [docs/COMMANDS.md#disasm](docs/COMMANDS.md#disasm): DISASM, the file disassembler
- [docs/COMMANDS.md#asm](docs/COMMANDS.md#asm): ASM, the assembler (ampDOS can build itself)
- [docs/BATCH.md](docs/BATCH.md): batch files (`%1`, `IF`, `GOTO`, ...)
- [docs/BUILDING.md](docs/BUILDING.md): building, the PC tools, testing
- [docs/PROGRAMMING.md](docs/PROGRAMMING.md): writing programs for ampDOS (the OS calls)
- [docs/INTERNALS.md](docs/INTERNALS.md): how it works: boot, memory, file system, source map
- [docs/PORTING.md](docs/PORTING.md): the machine layer, and what a port to another Z80 machine needs
- [docs/HARDWARE.md](docs/HARDWARE.md): the Little Board's hardware, and the floppy lessons

The BASIC interpreter included in specialized for this hardware, for more info:
- [PROGRAMS/BASIC/README.md](PROGRAMS/BASIC/README.md): 

ampDOS is written entirely in z80 assembly.... but you can write programs for 
it in C! some small experiments with this have been done, see
[c/README.md](c/README.md) for more. 

## License

ampDOS is under the [MIT License](LICENSE), copyright (c) 2026 M.J. Eckert

**Except BASIC.** `PROGRAMS/BASIC/BAS32K.ASM` is Microsoft's NASCOM BASIC 4.7 in
Grant Searle's Z80 version, which is for **non-commercial use only**. 
BASIC.BIN as built, and any disk image that contains it, is non-commercial. 
It is kept a separate program on the disk, not part of the OS. See
[PROGRAMS/BASIC/README.md](PROGRAMS/BASIC/README.md).

## Contributing & Usage
If you use this OS please let me know and any bug reports are appreciated!
Pull reqeusts are also welcome.

The current kernel version is in VERSION and is <1.0, as I would like to have 
feedback from others / other machines before developing further.

Large portions of the z80 assembly for this project were constructed with the 
the help of Claude Opus 4.5, however every line was reviewed and heavily
tested on actual hardware by an actual human.   

## Special thanks 
Thanks to Grant Searle for his Z80 port of NASCOM BASIC, and to Bas Wijnen for
z80asm. 
Also thanks to Herb Johnson and his page on the Ampro Little Board 
(https://www.retrotechnology.com/restore/ampro_lb.html) which 
provided me the initial info about the board which led to my further interest.
