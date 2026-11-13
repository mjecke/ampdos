# Writing programs for ampDOS

A program is a plain binary, `NAME.BIN`, assembled for **8000h**. The shell 
loads it there and calls it with **HL** pointing at the rest of the command line
(zero-ended, leading spaces skipped). `RET` (or `JP OS_WARM`) goes back to the 
shell. The stack is the shell's, with room for about 300 bytes.

It may use the RAM from 8000h up to what `OS_MEMTOP` returns: `TPA_TOP`, FC00h
(8 KB less while its output goes to a file, `PROG > X`). Interrupts are off and stay off.

The smallest example is [PROGRAMS/HELLO.ASM](../PROGRAMS/HELLO.ASM); the biggest is
EDIT ([PROGRAMS/EDIT.ASM](../PROGRAMS/EDIT.ASM)). To have `build.py` build it and put it
on the disks, add a line for it to the `PROGRAMS` table at the top of `build.py`
(and, for the boot disk, to `KERNEL/MACHINE/AMPRO/README.TXT`).

Or write it on the Little Board itself: `EDIT PROG.ASM`, then `ASM PROG.ASM` makes
`PROG.BIN` (see [ASM](COMMANDS.md#asm)). For `include "KERNEL/INC/OS.INC"` to work
there, the disk needs `KERNEL\INC\OS.INC`: the programs' source disks
(`ampdos_src2.img`, `ampdos_src3.img`) have it, or copy `OS.INC` next to your source and include it by
that name.

```
        org 8000h
        include "KERNEL/INC/OS.INC"
        push hl                 ; the arguments
        ld hl,hello
        call OS_PUTS
        pop hl
        call OS_PUTS
        jp OS_CRLF              ; (and back to the shell)
hello:  defm "You gave me: "
        defb 0
```

## The OS calls

Programs reach the OS only through the call table at **FF00h**
([KERNEL/INC/OS.INC](../KERNEL/INC/OS.INC) has the names). Its entries never move, so
programs keep working when the OS changes. Inputs and outputs are as for the routine
named; unless it says otherwise, AF, BC, DE, HL and IX may change, and carry set
means an error with A = the error code (`OS_ERRMSG` turns it into text).

| Call | | |
|---|---|---|
| `OS_WARM` | FF00 | back to the shell |
| `OS_PUTC` | FF03 | print A |
| `OS_GETC` | FF06 | wait for a key -> A |
| `OS_KBHIT` | FF09 | NZ = a key is waiting |
| `OS_PUTS` | FF0C | print the zero-ended text at HL (a byte `SPC+n`, 81h..FFh, prints n spaces) |
| `OS_CRLF` | FF0F | new line |
| `OS_HEX8`, `OS_HEX16` | FF12, FF15 | print A / HL in hex |
| `OS_DEC16` | FF18 | print HL in decimal |
| `OS_DEC32` | FF54 | print the 4-byte number at HL in decimal, B = width |
| `OS_GETLINE` | FF1B | read a typed line: HL = buffer, B = room -> B = length |
| `OS_MOUNT` | FF1E | read the disk's layout (after a disk change) |
| `OS_OPEN` | FF21 | open a file: IX = 16-byte FCB, HL = name |
| `OS_READ` | FF24 | IX, DE = to, BC = count -> BC = bytes read (0 = the end) |
| `OS_CREATE` | FF27 | a new, empty file (an old one of that name is replaced): IX, HL = name |
| `OS_WRITE` | FF2A | add to the end: IX, DE = from, BC = count |
| `OS_CLOSE` | FF2D | close a written file (until then it is not on the disk) |
| `OS_DELETE`, `OS_RENAME` | FF30, FF33 | HL = name; HL = old, DE = new |
| `OS_FLUSH` | FF36 | write everything changed to the disk |
| `OS_ERRMSG` | FF39 | A = error code -> HL = its text |
| `OS_DIRFIRST`, `OS_DIRNEXT` | FF3C, FF3F | walk the current directory: HL = a 32-byte entry |
| `OS_RDLBA`, `OS_WRLBA` | FF42, FF45 | read / write sector HL (0-719): DE = 512 bytes |
| `OS_VERSION` | FF48 | H = major, L = minor, A = patch |
| `OS_DATE` | FF4B | HL = today, DOS format |
| `OS_DRIVE` | FF4E | A = the current drive (0 = A, 1 = B) |
| `OS_RESOLVE` | FF51 | HL = `[d:][path\]name`: its drive and directory become the ones files are found in; HL = the name part |
| `OS_EXEC` | FF57 | run a built-in shell command: HL = the line, DE/BC = 512+ bytes it may use (how BASIC's DOS works) |
| `OS_MEMTOP` | FF5A | HL = the first address past the memory programs may use (8 KB less while the output goes to a file: `PROG > X`) |
| `OS_HOME` | FF5D | back to the current drive and directory (after OS_RESOLVE) |
| `OS_STATUS` | FF60 | A = the program's exit status (0 = success, 1-255 = failure): a batch file's `IF ERRORLEVEL n` sees it after the program ends |
| `OS_SCREEN` | FF63 | A = a screen action: 0 clear the screen (cursor home), 1 cursor home, 2 erase to the end of the line, 3 to the end of the screen, 4 up, 5 down, 6 right, 7 left. CF = this terminal cannot (0 always can: empty lines on a teletype). A = 8: the screen's size, no codes sent: L = rows, H = columns, A = the flags of `SCREEN WRAP`: 1 it wraps by itself after the last column, 2 EOL erases the whole line, 4 EOS erases from the start of the line (`SCREEN ROWS`/`COLS`/`WRAP`) |
| `OS_DIRGET` | FF66 | HL = an entry number (0 ...) in the current directory: HL = that 32-byte entry, whatever it holds (in use, deleted: first byte E5h, never used: 00h, nothing after it). CF past the end. Valid until the next directory call |
| `OS_DIRPUT` | FF69 | write back the sector of the entry last got (after changing it); then `OS_FLUSH` |
| `OS_FATGET` | FF6C | HL = a cluster: HL = its FAT entry (0 free, FF7h bad, FF8h+ the end) |
| `OS_FATSET` | FF6F | HL = a cluster, DE = its new entry; in memory until `OS_FLUSH` |
| `OS_DISK` | FF72 | A = sectors per cluster, HL = the number of data clusters (2 .. HL+1) |

The utilities (ATTRIB, TREE, XCOPY, UNDELETE ...) share a few helpers:
`PROGRAMS/PLIB.INC` (words, wildcard names, directory entries), `PROGRAMS/RFILE.INC`
(read a file a byte at a time), `PROGRAMS/WALK.INC` (walk a directory tree). The
file system's names (entry fields `DE_...`, attributes `ATTR_...`, error codes; a
read-only file gives `FS_ERO`, 16) are in `KERNEL/FS/FS.INC`.

**The screen.** Programs never send a terminal's codes themselves: they ask
`OS_SCREEN` for an action, and the codes the user gave (`SCREEN`, `SETUP`) are sent.
On a teletype only 0 (clear) works; a program that needs the cursor moves checks CF
and says it cannot, or does without.

**Exit status.** A program that just returns counts as a success. To tell a batch
file it failed, `LD A,1` (or any 1-255) and `CALL OS_STATUS` before returning;
`IF ERRORLEVEL n` is then true for every n up to that number.

File names are found in the current directory of the current drive; use
`OS_RESOLVE` first for a name with a drive or a path. The FCB layout and the error
codes are in [KERNEL/FS/FS.INC](../KERNEL/FS/FS.INC). Data a program wrote without
closing its files is thrown away when it ends.

`OS_MIRROR` (FC00h, a byte) is 1 while console output is copied to Serial B. A
program that uses Serial B itself (like IMGWRITE) sets it to 0 and puts it back.
The restart vectors work as the old AMPRO monitor's did: `RST 08h` prints A,
`RST 10h` waits for a key, `RST 18h` tests for one.
