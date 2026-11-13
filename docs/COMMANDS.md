# Commands & Built in ampDOS Functionality

`HELP` lists an abrdiged listing of build in commands on the screen (it does not 
pull from disk, so you can type HELP even when the boot disk is out of drive A, 
in case you need a command refresher while doing file transfers etc.)

Commands and names may be typed in any case.

I gave many commands aliases to to their DOS/UNIX cousins, e.g. 'LS' can be used
instead of 'DIR'.  The underlying program is the same.  In commands below these 
aliases are noted in parenthesis next to their other name.

### Names and paths

Every file or directory name may have a drive and a path: `B:\DOCS\A.TXT`,
`..\X.BIN`, `\SUB\`, `FOLDER\FILE.BAS`. Names are DOS 8.3 names. Each drive keeps its
own current directory. The disk is read again at every command, so disks can be
changed at the prompt (but not while a command or batch file is using them).

Typing: Backspace deletes, Return ends the line, Esc clears it. Up and Down (or
Ctrl-P and Ctrl-N) bring back the lines typed before, to run again or change;
`HISTORY` lists them (the last few hundred characters' worth). While output runs,
any key pauses it and Esc stops it.

**Wildcards.** `DIR`, `DEL` and `COPY` take `*` and `?` in the name (not in the
directories before it): `?` is any one character, `*` the rest of the name or of
the extension. `DIR *.BAS`, `DEL TEST?.TMP`, `COPY *.* B:`, `COPY \DOCS\*.TXT SUB`.
A name with no dot that ends in `*` takes any extension, so `*` is `*.*`.
Wildcards leave out directories, and hidden and system files (`DEL` also
read-only ones).

**Output to a file.** `command > file` sends what a command prints into a file
(made new), `command >> file` adds it to the end of one (made if it is not there):

    DIR > LIST.TXT
    ECHO Started the backup >> LOG.TXT
    MEM > B:\NOTES\MEM.TXT

The output is kept in memory while the command runs and written when it ends, up
to 8 KB (more is cut, and you are told). Meanwhile commands and programs have 8 KB
less memory (`OS_MEMTOP` says so). A `>` inside quotes is text (`FIND "a>b" X`).
Something that asks a question (`DEL *.*`) asks it into the file, so do not
redirect those, and use `TYPE`, not `MORE`, which would wait for a key unseen.

### Files

| Command | |
|---|---|
| `DIR [dir] [name]` (`LS`) | list a directory; with a name, only what fits it (`DIR *.BAS`, `DIR B:\FOLDER\H*`) |
| `TYPE name` (`CAT`) | show a text file |
| `DUMP name [/H] [/O:offset] [/P]` | any file in hex, with its text on the right (a program, `\BIN\DUMP.BIN`): `/H` hex only, `/O:` start at a hex offset, `/P` a screen at a time |
| `WC name ...` | lines, words and bytes of each file |
| `COPY from [to]` (`CP`) | copy a file; "to" may be a directory or a drive (`COPY X.TXT B:`). With wildcards, every file that fits, into a directory or drive (`COPY *.* B:`) |
| `MV from to` | rename (when `to` is a new plain name), or move: when `to` is a directory (`SUB`, `SUB\`, `..\`, `\`), a path (`SUB\NEW.TXT`) or a drive (`B:`), MV copies and then deletes the source, if every copy worked. Wildcards move many files (`MV *.BIN SUB`) |
| `DEL name` (`RM`) | delete a file; with wildcards, every file that fits (`DEL *.TMP`; `DEL *.*` asks first) |
| `TOUCH name` | a new empty file; an existing file only gets today's date |
| `MORE name [lines]` | `TYPE` a page at a time (the screen's rows less one, `SCREEN ROWS`; or as many as you give): Space = next page, Return = one more line, Q or Esc = stop |
| `CMP a b` (`FC`) | compare two files byte by byte: the first 8 differences (offset in hex and the two bytes), how many differ, and a note if the sizes differ. The files may be on different drives. Status 1 if they differ |
| `CRC name` | the CRC-32 of a file, in hex, with its size: `18AF4D4E  115  hello.bin`. It is the CRC-32 of zip and gzip, so the PC gives the same (`crc32 file`, or `python3 -c "import zlib,sys; print('%08X' % zlib.crc32(open(sys.argv[1],'rb').read()))" file`): compare the two after a transfer. About 6 KB a second |
| `FIND [/I] [/N] [/C] "text" name` | the lines of a text file that hold the text (quotes are only needed for spaces); `/I` ignores case, `/N` numbers the lines, `/C` only counts them. Status 1 if there is none |
| `SORT [/R] [/I] name [out]` | the lines of a text file in order (the order of the character codes; `/R` backwards, `/I` capitals and small letters alike), to the screen or to the file `out` (which may be `name` itself). The file must fit in memory (about 30 KB) |

### Directories

| Command | |
|---|---|
| `CD [d:][dir]` (`CHDIR`) | change directory (`CD B:SUB` changes B:'s); alone: show where you are. `.` and `..` work as directories in other commands too: `MV SUB\X.TXT .`, `COPY X ..`, `DIR ..` |
| `PWD` | where you are |
| `MD name` (`MKDIR`) | make a directory |
| `RD name` (`RMDIR`) | remove an empty directory |
| `DELTREE [/Y] dir` | delete a directory and everything in it, at any depth (asks first unless /Y) |

### Drives and disks

| Command | |
|---|---|
| `A:`, `B:` | change drives |
| `FDISK [d:] [/Q]` (`FORMAT`) | format a disk: all 40 tracks, verified, bad tracks counted. `/Q`: quick, only a new empty file system on an already formatted disk |
| `SYS [d:]` | make a disk boot ampDOS: the boot code into its boot sector, keeping its layout and files, and the running OS saved as `AMPDOS.SYS` |
| `BOOT [d:]` | run `AUTOEXEC.BAT` from the root of this drive (or of d:). `A:\AUTOEXEC.BAT` also runs by itself at every start (Esc stops it) |
| `CHKDSK [d:] [/F]` | check the file system: every directory and cluster chain. Reports broken chains, cross-linked files, sizes that do not match, lost clusters, bad sectors and the space used. `/F` frees lost clusters. Fails (for `IF ERRORLEVEL`) if anything is wrong |
| `LABEL [d:] [name]` | show or set the disk's volume label (11 characters, spaces allowed); `LABEL /D` removes it. `VOL [d:]` shows it |
| `DISKCOPY A: B:` | copy a whole disk, track by track: the target is formatted as it goes and every track read back. `DISKCOPY A: A:` copies in one drive, asking for the source and the target disk in turn (some 15 times: as many tracks as fit in memory each time) |

A new boot disk from a blank one, with no PC: `FDISK B:`, then `SYS B:`.

### Programs

| Command | |
|---|---|
| `NAME [args]` or `RUN NAME [args]` | run `NAME.BIN` (or `NAME.BAT`): from the current directory, else from the `PATH` directories. Only `.BIN` and `.BAT` files run |
| `PATH [dir;dir...]` | show or set the directories programs are looked for in, in order (`PATH A:\BIN;B:\TOOLS`; `PATH=...` works too; `PATH ;` none). `A:\BIN` at start |
| `BASIC [name]` | BASIC (see [PROGRAMS/BASIC/README.md](../PROGRAMS/BASIC/README.md)) |
| `EDIT name` | the line editor (below) |
| `ATTRIB`, `TREE`, `XCOPY`, `UNDELETE`, `HEAD`, `TAIL`, `TR`, `DIFF`, `DISKCOMP`, `DUMP`, `HEXED`, `DEFRAG`, `SCANDISK`, `MEMMAP`, `ASCII` | the utilities (below) |
| `GO hhhh [args]` | call the address hhhh (exactly 4 hex digits); a RET comes back to the prompt |

### Serial B (the link to an outside computer)

| Command | |
|---|---|
| `SERRECV [name]` | receive a file from the PC: `python tools/pc/serxfer.py send FILE [NAME]` there |
| `SERSEND name` | send a file to the PC: `python tools/pc/serxfer.py get` there |
| `MIRROR [ON\|OFF]` | copy all console output to Serial B too (log it with `tools/pc/serlog.py`); off at start |
| `TERM [baud] [bits parity stop] [/E]` | a terminal on Serial B: what arrives is shown, what you type is sent. `TERM 1200 7E1 /E`: 1200 baud, 7 data bits, even parity, 1 stop bit, local echo. Ctrl-] ends it and sets Serial B back to 9600 8N1 |

Serial B runs at 9600 baud, 8N1 (really 9615), except while `TERM` has changed it.
The PC side may be started before or after the Ampro side.

`TERM` speeds are 9600, 4800, 2400, 1200, 600, 300, 150 and 110 baud (the board
cannot go faster); bits are 5 to 8, parity N, E or O, stop bits 1 or 2; the default
is 9600 8N1. Typing does not echo unless the far end echoes or you give `/E`.
Return sends a CR. The console and Serial B both run at 9600, so the receiving
side has no time to spare: a far end that sends a long stream at full speed may lose
characters (send with pauses, or at a lower speed). `MIRROR` is off meanwhile.

### System

| Command | |
|---|---|
| `VER` | the version |
| `HELP` (`?`) | the command list |
| `DATE [yyyy-mm-dd]` | show or set the date new files get. There is no clock: it starts at the day the OS was built, and is asked for at every start |
| `MEM` (`MEMTEST`) | test all 64 KB of RAM (it does at every start too) and show how it is used, on one line: `64KB RAM OK. Programs: 8000-FBFF (31KB), OS: 0000-5EFF, Buffers: 5F00-7FFF`; or `RAM BAD at 8123 (read 54h)`, the first bad byte. Every byte gets 55h and AAh and is put back; every 1 KB block its own number (RAM that repeats itself); at the start 8000-FBFF is also filled all through with a pattern from the addresses and read back, twice |
| `ID [B]` | the board's ID jumpers (port 29h) in hex, or with B in binary |
| `SLEEP s[.mmm]` | wait that many seconds, to the millisecond (`SLEEP 1.892`); Esc stops it |
| `CLEAR` (`CLS`) | clear the screen: with the terminal's code if `SCREEN` has one (`SETUP`), else by scrolling it away (`SCREEN ROWS` empty lines) |
| `SCREEN TTY` | no screen codes: a teletype, how ampDOS starts |
| `SCREEN action [hh ...]` | the bytes (hex, up to 6) the terminal takes for an action, or none: it cannot. Actions: `CLEAR` (clear, cursor home), `HOME`, `EOL` and `EOS` (erase to the end of the line, of the screen), `UP`, `DOWN`, `RIGHT`, `LEFT`. A VT52: `SCREEN CLEAR 1B 48 1B 4A`, `SCREEN UP 1B 41`. `SETUP` writes these lines for you |
| `SCREEN ROWS n`, `SCREEN COLS n` | the screen's size: 24 x 80 at the start. `CLEAR` on a teletype and `MORE` use the rows; programs ask with `OS_SCREEN 8` |
| `SCREEN WRAP n` | the terminal's ways, added up: 1 it goes to the next line by itself after the last column, so a full-width line needs no CR LF (an extra one would leave an empty line); 2 its `EOL` erases the whole line, not from the cursor (use it at the start of a line); 4 its `EOS` erases from the start of the cursor's line down. `SETUP` finds them |
| `HISTORY` | the lines typed before (Up and Down bring them back) |
| `PEEK addr [n]` | show n bytes of memory from addr (1 if n is not given), 16 to a line. All numbers in hex: `PEEK 8000 40` |
| `POKE addr byte ...` | put bytes into memory: `POKE 9000 3E 41 C9` |
| `IN port` | read an I/O port and show the byte: `IN 29` |
| `OUT port value` | write a byte to an I/O port: `OUT 00 01`. Careful: POKE and OUT can stop the machine (that is what they are for) |
| `ECHO`, `PAUSE`, `REM`, `IF`, `GOTO`, `SHIFT`, `TRUE`, `FALSE` | for batch files: see [BATCH.md](BATCH.md); IF works at the prompt too |
| `SETUP` | finds out what the console's terminal can do, and keeps it as `@SCREEN` lines in `A:\AUTOEXEC.BAT` (its other lines stay). Choice 2 tries, for each of CLEAR, HOME, EOL, EOS, UP, DOWN, RIGHT and LEFT, the codes of the VT52, VT100, ADM-3A, H19 and TeleVideo in turn, each with a test you see, until you say yes; if none works you type the bytes or say it cannot. Then the rows (read off a ruler), the columns, whether it wraps after the last column, and what the Esc key sends. An EOL or EOS that does not erase from the cursor is tried again on whole lines (some terminals' `ESC K` erases the line, `ESC J` from the line down), and kept with its flag in `SCREEN WRAP`. A summary, then Y keeps it; Esc at any question, or N at the end, leaves everything as it was. Run it once on a new system |
| `RESTART [W]` | start ampDOS again as after power-on; `W`: warm, back to the prompt keeping the date and directories |
| `EXIT` | switch the ROM on and start it: the AMPRO ROM boots the disk again (so `SERRECV AMPDOS.SYS` then `EXIT` boots a new OS) |

### EDIT

`EDIT name` loads a text file (or starts a new one) and shows its first line. A
command is an optional line number or range, then a letter:

| | |
|---|---|
| `12` | go to line 12 and show it |
| Return | show the next 16 lines |
| `-` | show the 16 lines before |
| `L`, `5,30L` | list 16 lines from here / lines 5 to 30 |
| `I`, `12I` | insert before this line / line 12 (a line holding only `.` stops) |
| `A` | add lines at the end |
| `D`, `5,9D` | delete this line / lines 5 to 9 |
| `E`, `12E` | retype this line / line 12 |
| `F text` | find the next line holding "text" |
| `R/old/new/`, `5,30R/old/new/` | replace every "old" with "new" in this line / lines 5 to 30 (any character instead of `/`) |
| `5,9,20C` | copy lines 5 to 9 to before line 20 (`$+1` is not needed: `5,9,$C` puts them before the last line; to the end use the line count + 1) |
| `5,9,20M` | move them there |
| `T name`, `20T name` | read a text file in, before this line / line 20 |
| `W`, `Q`, `X` | write the file, quit, write and quit |
| `H` or `?` | help |

`.` means the current line, `$` the last one. Files stay PC text files (CR LF), up
to about 28 KB. EDIT does not run while its output goes to a file (`EDIT X > Y`).

### The Utilities

Programs in the boot disk's `\BIN` (their sources are on `ampdos_src3.img`).

| | |
|---|---|
| `ATTRIB [+R\|-R] [+H\|-H] [+S\|-S] [+A\|-A] [name]` | show or change attributes: R read-only (DEL, COPY over it and `>` refuse it: "the file is read-only"; MV may rename it), H hidden, S system (left out of DIR and of wildcards), A archive. Wildcards; no name: every file here. Each is listed as `R-S-A  NAME.EXT` (D: a directory) |
| `TREE [[d:]dir] [/F]` | the directories under one, indented; `/F` the files too |
| `XCOPY from to` | copy a directory with everything under it: `to` and its subdirectories are made as needed, and each directory's files are copied with COPY (so hidden and system files are left out). `XCOPY \DOCS B:\DOCS`, `XCOPY . B:\BACKUP`. A target inside the source is refused |
| `UNDELETE [dir\]`, `UNDELETE [dir\]NAME.EXT` | list the deleted files there (with whether they can come back), or bring one back: type its lost first letter too. It works while the file's clusters are still free, taking them to be one after the other (as on a floppy with room); check a file that had more than one. Write nothing to the disk first |
| `HEAD [-n] name`, `TAIL [-n] name` | the first / last n lines of a text file (10) |
| `TR from to name [out]`, `TR -d chars name [out]` | change characters (`TR a-z A-Z X.TXT`) or leave them out (`TR -d \r UNIX.TXT LF.TXT`). Sets take ranges and `\n \r \t \\ \-`. With `out` the result is written there, byte for byte (24 KB at most then); else it is shown |
| `DIFF old new` | how two text files differ, in UNIX diff's form (`3c3`, `5,7d4`, `8a9,10`, then `<` and `>` lines). 11 KB and 700 lines each at most. Status 0 the same (nothing is printed), 1 different, 2 trouble |
| `DISKCOMP A: B:`, `DISKCOMP A: A:` | compare two whole disks track by track (one drive: it asks for each disk in turn): `Compare error on side 1, track 12` for each track that differs, then `Compare OK` or how many. Status 1 if they differ |
| `HEXED name` | a full-screen hex editor: offsets, 16 bytes in hex, the same as text. It needs the cursor moves (`SETUP`: UP DOWN LEFT RIGHT; HOME helps) and puts the cursor anywhere with them, so no cursor addressing is needed. Keys, all letters: `A D W S` left right up down (`H J K L` too; a move key acts once, and more of it for ~0.15 s after are let go by, so a key held a little long or a bouncing one does not jump), `Space`/`B` a page, `T`/`E` top/end, `G` go to a hex offset, `/` find hex bytes or `"text"`, `N` the next, `Tab` the hex or the text side, `Return` edit (hex digits, or characters; Backspace back; Esc ends; typing past the end adds bytes), `I` insert a 00, `X` delete, `P` put it on the disk (to HEXED.TMP, then in the file's place), `Q` quit (asks if it is not on the disk yet). Files up to 26 KB; a name that is not there is a new file |
| `DEFRAG [d:] [/F]` | the disk's clusters as a map (`.` free, `#` a file in one piece, `%` in pieces, `D` a directory, `B` bad, `?` lost, `!` claimed twice), the free space and its runs, the files in the most pieces. `/F` moves each file in pieces into one free run, the map redrawn as it goes (with HOME): data copied, the run chained and written, the entry pointed at it and written, and only then the old clusters freed, so stopping half way loses nothing (CHKDSK /F frees the run). Directories stay; a file with no run as big stays. Refused on a disk with lost or crossed chains |
| `SCANDISK [d:] [/F]` | read every sector (also of a disk that is not FAT), a mark for each cylinder as it goes (`.` both sides read, `0`/`1` that side not, `B` neither), then the bad sectors: cylinder, side, sector, and its cluster: free, in a file, marked bad already, or the system area. `/F` marks the free ones bad in the FAT. Esc stops; status 1 if any are bad |
| `MEMMAP` | the 64 KB as a picture, a letter for each 64 bytes (the OS, its room, each buffer, the program, the free TPA, the OS's variables and call table), and the list: from-to, size, what |
| `ASCII [/D \| /H \| c \| n]` | the table of 0-127 (hex; `/D` decimal; control codes by name), `/H` 128-255 as the terminal shows them, or one: `ASCII A` gives `A = 65 = 41h = 01000001b`, `ASCII 1Bh` gives `ESC ... (Ctrl-[)` |

### DISKED

`DISKED [B:]` is a sector editor: it shows and changes what DIR never shows, the
boot sector and its BPB, the two FATs, the root directory's raw entries. It works on
360K disks, on the drive you give (or the current one), and also on a disk the file
system cannot mount (a broken BPB), so it can repair one.

The prompt tells where you are: `A:0>` is drive A, sector 0; a `*` after the number
means the buffer has changes not written yet. Sector and cluster numbers are decimal
(as DIR and CHKDSK say them), offsets and bytes are hex.

| | |
|---|---|
| `R [n]` | read sector n (0-719) into the buffer and show its first 256 bytes, and what it is: `FAT 1, sector 2 of 2`, `root directory, entries 16-31`, `cluster 7, sector 1 of 2`. Alone: read this one again, dropping changes |
| `+`, `-` | the next, the previous sector |
| `D [a [b]]` | dump the buffer (hex offsets 0-1FF): alone, the next 256 bytes. A key pauses it, Esc stops |
| `E a [bytes]` | change bytes from offset a: hex, or `"text"` in quotes (`E 3 "MYDISK  "`). With no bytes it asks line by line (Return keeps one, `.` ends) |
| `F a b byte` | fill offsets a to b |
| `W [n]` | write the buffer to sector n (alone: the sector it came from), after a Y |
| `B` | the buffer as a boot sector: every BPB field by name, with its offset (`E` changes it) |
| `M` | the sector map of the disk from its BPB: boot sector, FATs, root directory, data clusters |
| `C n [v]` | cluster n: its sectors, its FAT entry and the chain it starts. With v (hex, 0-FFF) it sets the FAT entry in every FAT, after a Y: `FF8`-`FFF` end of file, `0` free, `FF7` bad |
| `A:`, `B:` | use that drive |
| `Q` | quit |

Nothing reaches the disk until `W` or `C n v` and a Y. Changing the BPB or the FAT
of a disk that is in use can destroy it: try it on a copy (`DISKCOPY`). To make a
bootable disk see `SYS`; to check a disk, `CHKDSK`.

### IMGWRITE

`IMGWRITE A:` (or `B:`) writes a whole 360K disk image, sent from the PC over
Serial B, onto the disk in that drive (it must be given): every track formatted, written and read back. It
is how to make an ampDOS boot disk with no PC floppy drive. On the PC:

    python3 tools/pc/imgsend.py ampdos_boot.img

Run `IMGWRITE A:` (or `B:`), put the disk to be written in, press Y. ampDOS runs from memory, so
the disk IMGWRITE was loaded from may be taken out first. Esc stops it. imgsend.py
shows a progress bar, the track and the time left.

At 9600 baud a full track takes about 5 seconds to send, so a full disk takes about
8 minutes. A track that is all one byte (an empty one) is sent as 3 bytes instead of
4611, so a mostly empty disk like the ampDOS boot disk takes about 3 minutes. Every
track is still formatted, written and read back.

IMGWRITE uses the OS's own variables, so it runs only on the OS it came with (it
says so otherwise): after updating `AMPDOS.SYS`, update `IMGWRITE.BIN` too.

### MON

`MON` starts a machine code monitor (a program, `MON.BIN`, on the boot disk). It
prompts with `*`. Numbers are hex, 1 to 4 digits; a range is `start end`. Esc stops
a long listing, any other key pauses it.

| | |
|---|---|
| `D [start [end]]` | dump memory (hex and text); alone, carry on from the last dump |
| `E addr [bytes]` | enter bytes; with no bytes, prompts address by address (`.` ends) |
| `F start end byte` | fill |
| `M start end dest` | move (safe when the ranges overlap) |
| `C start end other` | compare: shows the addresses that differ |
| `S start end bytes` | search for bytes, or for `"text"` |
| `U [start [end]]` | disassemble (16 instructions by default); undefined opcodes show as `DB` |
| `G addr [args]` | call the code at addr (HL points to the args); it returns to MON with `RET` |
| `L name [addr]` | load a file into memory (default 8000, up to BBFF) |
| `W name start end` | write memory to a file |
| `I port`, `O port value` | read / write an I/O port |
| `H a b` | hex sum and difference |
| `?` | help |
| `Q` | back to the shell |

To look at a whole program file, see [DISASM](#disasm); to assemble one, [ASM](#asm). MON is simple: no breakpoints and no register display. The monitor itself sits in
BC00-D9FF, so the rest of the TPA, 8000-BBFF, is yours to examine and load into.

### DISASM

`DISASM file [out] [/O:addr] [/S:addr] [/E:addr] [/D:a-b] [/A]` disassembles a
program file (a program `.BIN`, a ROM image, any file of Z80 code) to the screen,
or to the file `out`. All numbers are hex.

| | |
|---|---|
| `/O:addr` | the address the file's first byte belongs to (default `8000`, where programs run; use `/O:0` for a ROM image) |
| `/S:addr`, `/E:addr` | show from this address / up to this one (default: the whole file) |
| `/D:a-b` | those addresses are data, not code: they come out as `DB` lines (up to six of them) |
| `/A` | assembler source instead of a listing |

The default is a listing, as MON's `U` shows it:

    8000  E5           PUSH HL
    8001  21 27 80     LD HL,8027h
    8004  CD 0C FF     CALL 0FF0Ch

With `/A` the text is source: an `ORG` line, a label `Lxxxx:` at every address in
the shown range that a jump, a call or a load points to (and the operands use
the labels), and data bytes as `DB` lines with their text as a comment. The source
assembles back (with `z80asm`, for one) to the same bytes. The part of a program
that is text is not told apart from code on its own, so give it as `/D:`: for
`HELLO.BIN`, `DISASM HELLO.BIN H.ASM /A /D:8027-8072`.

Examples: `DISASM EDIT.BIN` lists the editor; `DISASM AMPDOS.SYS os.lst /O:0`
lists the OS to a file (about 3 times the size of the code: mind the disk);
`DISASM X.BIN /S:8100 /E:81FF` shows one page.

The file is read into memory above the program, as much as fits (about 20 KB); for a bigger file it prints
`(the file goes on: /S:xxxx shows the rest)`, and the rest is the same command
with that `/S:`. Esc stops, any other key pauses. If the output file cannot be
written (a full disk) the part written is kept and DISASM says so.

### ASM

`ASM source [output]` assembles a Z80 source into a binary (a program file on the
boot disk, `ASM.BIN`). Without `output`, the binary is the source's name with
`.BIN`, in the current directory: `ASM HELLO.ASM` makes `HELLO.BIN`.

It takes the language the ampDOS sources are written in (Bas Wijnen's `z80asm`), and
it assembles every one of them to the same bytes as `z80asm` does, ampDOS itself
included: ampDOS can build itself (see [the source disks](#building-ampdos-on-the-ampro)).

    count:  equ 10                  ; a name, a colon, and an instruction or directive
            org 8000h
    start:  ld b,count              ; mnemonics and registers in any case
    loop:   ld a,(ix+2)
            djnz loop
            ret
    msg:    defm "Hello\r\n",0      ; (defb and defm take numbers and "strings")

| | |
|---|---|
| instructions | all the Z80's, with IX and IY, and the undocumented `SLL` and `IXH IXL IYH IYL` |
| `name: equ expr` | a name for a value; `name equ expr` also works at the start of a line |
| `org addr` | where the next byte goes (it does not pad the file: use `defs` for that) |
| `defb`, `defm` (`db`, `dm`) | bytes: numbers and `"strings"` |
| `defw` (`dw`) | words |
| `defs n[,fill]` (`ds`) | n bytes of fill (0) |
| `include "file"` | the source of another file (up to 5 deep) |
| `incbin "file"` | the bytes of another file |
| `if expr` / `else` / `endif` | assemble a part only if expr is not 0 (they nest) |
| numbers | `123`, `0FFh`, `$FF`, `0x1F`, `101b`, `17o`; `'c'` is a character; `$` is the address of the line |
| operators | `+ - * / % << >> & ^ \| ~` and `( )`, with C's precedence; 16 bits |
| strings | `\\ \" \' \n \r \t \0` inside them |

Labels are case-sensitive (`Loop` and `loop` are two names). A `;` starts a comment.
File names in `include` and `incbin` are from the current directory, as typed:
`include "KERNEL/INC/OS.INC"` (`/` or `\`). Each part of one is cut to 8.3, the
way DOS cuts names.

It works in two passes over the source: the first finds every label's address,
the second makes the bytes. So a label may be used above the line it is on. An
`equ` whose value uses a label further down gets its value in the second pass;
use that name only below its line. `org`, `defs` and `if` must be able to work
out their values in the first pass. (Where `z80asm` takes such an `equ` as 0,
ASM gives it its real value. And `and a,b` is `and b` to ASM; `z80asm` makes it
`and a`. The ampDOS sources use neither.)

An error shows the file, the line number and the line:

    PROGRAMS/HELLO.ASM:12: undefined: m_hi
      ld hl,m_hi

Both passes run even after an error, so one run shows them all (each once). After
an error there is no output file, and the status is 1 (for `IF ERRORLEVEL`).
Esc stops. ASM prints `Pass 1` and `Pass 2`, and at the end the size, the address
of the first byte and the number of names:
`HELLO.BIN: 115 bytes at 8000h, 41 symbols`.

The names are kept in memory: 20 KB of room (ampDOS itself takes 17 KB: 1600
names). A name takes 4 bytes and its length. There are no macros and no listing
file. A small program takes seconds; ampDOS itself (about 260 KB of source) takes 
a few minutes. 

### Building ampDOS on the Ampro

While using the python build script on a modern machine is fast and the best way
to build ampDOS, it can actually be assembled by its own assembler on the real
hardware is you want, as long as you have a the AMPDOS.SYS kernel booted and the 
assembler and includes located in drive A.

Three more disk images build built in release: everything ampDOS is assembled from,
and a `BUILD.BAT` on each. Nothing assembled is on them: ASM and the programs to
compare with are on the boot disk. So if you boot the ampDOS disk in A:, put a source disk in B:, and type `B:` and `BUILD`  (It needs two drives.) it will use 
the assembler to assemble anew from source, and then compare the output of the new
binaries to the currently running binaries on A: via CRC.

The files are the same as the project's `KERNEL/` and `PROGRAMS/`.

This is all setup so you can do development of the OS from true ASM source on 
the real hardware, as I did much of the development of the OS in the first place.

`ampdos_src1.img` is all the asm for the OS: `BUILD` assembles the boot sector into `BIN\BOOTSEC.BIN` (the OS includes it) and the OS into `NEW\AMPDOS.SYS`, then compares that with `A:\AMPDOS.SYS`: `Files are identical`. To swap a new kernel in `COPY NEW\AMPDOS.SYS A:\AMPDOS.SYS`, then `EXIT`.


`ampdos_src2.img` is the programs (HELLO, EDIT, IMGWRITE, DISASM, MON, ASM itself) and BASIC (`PROGRAMS\BASIC\BASIC.ASM`, made by `mkbasic.py`; only its copyright notices are left of its comments, to fit).

`ampdos_src3.img` are utilities and any other assembly code. 