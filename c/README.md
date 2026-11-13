# C programs for ampDOS (uc80)

[uc80](https://github.com/avwohl/uc80) is a small ANSI C compiler for the Z80,
written in Python, for CP/M. The two small assembly files here let its programs
run on ampDOS as ordinary `.BIN` programs. The OS needs no change and has no
CP/M layer: everything lives inside the program and is undone when it exits.

| File | What it is |
|---|---|
| `ampcrt0.mac` | the start-up code, used instead of uc80's CP/M `crt0` |
| `ampbdos.mac` | the few CP/M BDOS functions uc80's C library calls, done with ampDOS calls |
| `ampcc.sh` | compile, assemble and link: `./ampcc.sh [-f] prog.c` makes `PROG.BIN` |
| `hello.c`, `mandel.c` | examples (`mandel.c`: an ASCII Mandelbrot explorer) |
| `ftest.c` | the file I/O checks: `FTEST` prints `ok:` or `FAIL:` for 24 of them |
| `ampdos.h`, `lib/` | `system()` and the `os_` functions (below); `lib/` becomes a library, so only those used are linked |
| `systest.c` | tries `ampdos.h`: version, drive, `system()`, `os_kbhit`, `os_screen`, `os_status` |
| `ctest.c` | 35 checks of the language and library: `math.h`, `long long`, `qsort`, `sscanf`, `setjmp`, `malloc`, recursion, structs, bitfields, `scanf` from the keyboard |
| `conway.c` | Conway's Life, 78 x 24, a random start, as fast as the terminal draws: Space or a letter starts a new grid, Esc, Q or Ctrl-C ends it |

## Setup

```
pip install uc80 um80          # the compiler; um80 has the assembler um80 and the linker ul80
./ampcc.sh prog.c [more.c ...]
```

Copy `PROG.BIN` to the disk and run it like any program: `PROG args`.

### Only what the program needs

The file part of the stub is about 1.2 KB, plus 1 KB of memory, and most
programs never touch a file. So `ampcc.sh` links twice, without looking at
the C source:

1. It links with the whole stub and writes the linker's symbol file.
2. If none of `_fopen`, `_freopen`, `_tmpfile`, `_remove` or `_rename`
   is in the program, it cannot reach a file. Every other file function
   works only on a file one of those opened. So the script links again,
   with `ampcrt0.mac` and `ampbdos.mac` assembled with `um80 -D FILES=0`:
   the console alone, and the stub at FBFDh instead of F7FDh.

It says which it chose, for example `HELLO.BIN: 1983 bytes (console
only)`. `-f` keeps the file stub regardless, for a program that calls the
BDOS file functions itself with `asm()`.

## How it works

uc80 expects CP/M, and ampDOS differs from it in five ways:

- **The load address.** CP/M programs start at 0100h; ampDOS loads them at
  8000h. `ul80 --bin -p 8000` links there, and `ampcrt0.rel` goes first so
  that `__start` is at 8000h.
- **System calls.** The C library does all console and file work by
  `CALL 5` with C = a BDOS function. ampDOS has nothing at 0005h: bytes
  0004h-0007h of AMPDOS.SYS are unused padding. While the program runs,
  `ampcrt0` puts `JP F7FDh` at 0005h and `JP __bdos` at F7FDh, just under
  the shim's memory. So address 6 holds the top of memory, as CP/M
  programs expect, and SP starts there too.
- **Exit.** `exit()`, `abort()` and the end of `main` end with `JP 0` (the
  CP/M warm boot). On ampDOS that would be a cold restart, so while the
  program runs, 0000h holds `JP __amp_exit`. That code puts the OS's own
  bytes back at 0000h-0007h, restores the shell's stack and returns to the
  shell.
- **Arguments.** ampDOS calls a program with HL pointing at the rest of its
  command line. `ampcrt0` copies the line and splits it at spaces into
  `main(argc, argv)`. `argv[0]` is `""`, because ampDOS does not pass the
  program's name. There are at most 15 arguments.
- **The exit status.** The value `main` returns becomes the program's
  status (OS_STATUS), which batch files see as `ERRORLEVEL`. uc80's
  `exit(n)` drops its argument, so after `exit(n)` the status is 0. Use
  `return n` from `main`.

`ampbdos.mac` provides:

- **The console.** BDOS 1 (a key, echoed), 2 (a character), 9 (a
  `$`-ended string) and 11 (is a key waiting?), with OS_GETC, OS_PUTC and
  OS_KBHIT. uc80's library already turns `\n` into CR LF.
- **Files.** BDOS 15 open, 16 close, 19 delete, 22 make, 23 rename, 26 set
  DMA, 33/34 read/write a record, and 35 the size in records, with OS_OPEN,
  OS_READ, OS_CREATE, OS_WRITE, OS_CLOSE, OS_DELETE, OS_RENAME and
  OS_RESOLVE. Every other function answers FFh.

### Files

uc80's library works the CP/M way: a file is 128-byte records, read and
written by number, and the last record is padded with Ctrl-Z (1Ah). ampDOS
reads a file in order, and writes only a new file, at its end. The shim
covers the difference as follows:

- **Reading a record.** The next record is an OS_READ of 128 bytes, padded
  with 1Ah past the end. A later record is read up to. An earlier one starts
  the file over: the ampDOS FCB's position goes back to 0, without
  reopening the file. So `fseek` works both ways, and backward costs a
  reread.
- **Writing.** The record last written is kept in the shim. It goes to the
  disk when the next record is written, or at the close, because the
  library writes the same record again as it fills it. At the close, the
  1Ah padding of the last record is left out, so files get their real size.
- **Writing to an opened file (`"a"`, `"r+"`, `"a+"`).** ampDOS cannot
  change a file in place, so the first write starts a new file,
  `AMPCTMPn.TMP`. The old file's records before and after the ones written
  are copied into it. At the close, the old file is deleted and the new one
  takes its name. This needs room on the disk for the copy.
- **Memory.** The open files' state is F800h-FBFCh, four slots of 184
  bytes. `ampcrt0` zeroes it, and the stack starts below it, at F7FDh.

What works: `fopen` with `r`, `w`, `a` and `+`, and the `b` variants;
`fgetc`, `fgets`, `fread`, `fscanf`, `fputc`, `fputs`, `fprintf`,
`fwrite`; `fseek`, `ftell`, `rewind`, `feof`; `remove`, `rename`; and
`B:NAME.EXT`. 

The limits on files:

- **No paths.** A CP/M FCB has no room for a path, so files are in the
  current directory of their drive. `CD` there before you run the program.
- **One drive at a time.** All the files open at once must be on one
  drive, because ampDOS keeps one disk's FAT in memory. Opening a file on
  the other drive while files are open fails. After closing them all, the
  other drive is fine.
- **4 files open at most.** A fifth `fopen` returns NULL.
- **`r+` writes go forward.** In a file opened and then written, records
  can only be written in order (the library does that), and a record
  already written cannot be read back before `fclose`.
- **CP/M text rules, even in `"rb"`.** uc80's `fgetc` skips CR (0Dh) and
  stops at 1Ah. A binary file whose last bytes really are 1Ah loses them at
  the close. So binary data with those two bytes needs care; plain text is
  unaffected.

## ampdos.h: system() and the OS

`#include "ampdos.h"`, and `ampcc.sh` links what the program uses from
`lib/`. It builds `lib/*.mac` into a library with `ulib80`, so only the
functions called cost anything. They are ordinary C functions: uc80 passes
the arguments on the stack and takes the result in HL. Each one keeps BC,
DE, IX and IY.

| Function | What it does |
|---|---|
| `int system(const char *cmd)` | one built-in shell command, with OS_EXEC: `system("SLEEP 2")`, `system("CLEAR")`, `system("DIR B:")`, `system("COPY A.TXT B:")`. It returns 0, or -1 if the shell refuses the command. `system(NULL)` is 1 |
| `int os_screen(int action)` | OS_SCREEN with the codes SETUP saved: `SCR_CLEAR`, `SCR_HOME`, `SCR_EOL`, `SCR_EOS`, `SCR_UP`/`DOWN`/`RIGHT`/`LEFT`. It returns -1 if this terminal cannot |
| `int os_rows(void)`, `int os_cols(void)`, `int os_wrap(void)`, `int os_flags(void)` | the screen's size as SETUP found it (`SCREEN ROWS`/`COLS`); `os_wrap()` is 1 if it wraps by itself after the last column; `os_flags()` all of `SCREEN WRAP`'s flags (`SCR_F_WRAP`, `SCR_F_EOLLINE`: EOL erases the whole line, `SCR_F_EOSLINE`) |
| `int os_kbhit(void)` | 1 if a key is waiting; it stays there, and `getchar()` gets it |
| `int os_getc(void)` | waits for a key and returns it without showing it (`getchar()` echoes it, the CP/M way) |
| `void os_write(const char *buf, unsigned n)` | n bytes straight to the screen, as they are (`\n` is not turned into CR LF). Far faster than `printf`/`fputs`, so a screen built in memory goes out at the line's speed |
| `void os_status(int n)` | the exit status (`ERRORLEVEL`). `os_status(n); exit(0);` ends with a status from anywhere, because `exit(n)` drops n |
| `int os_drive(void)` | the current drive: 0 = A, 1 = B |
| `unsigned os_version(void)`, `int os_patch(void)` | 0.8.8 gives `0x0008` and `8` |

`system()` replaces uc80's own, which always fails: ours is in a library
linked before `libc.lib`, so the linker takes it first. It copies the line,
because the shell may change it, and gives OS_EXEC the 512 bytes it needs.
Both come from below the stack, only for the length of the call.

The limits of `system()`:

- **Built-in commands only.** A `.BIN` program would load over the C
  program itself, so OS_EXEC refuses it, and FDISK too.
- **It cannot tell whether the command worked.** The OS has no call that
  reads the exit status back.
- **Not on a disk with files open.** A command that writes to a disk the
  program has files open on would work from the same FAT in memory, so
  close the files first.

For anything else, uc80 copies inline assembly as it is, so an OS call is
a few `asm()` lines. Save the registers uc80 may keep variables in. The
call addresses are in `KERNEL/INC/OS.INC` and `docs/PROGRAMMING.md`.

## Limits

- **No float speed.** Soft float works, but it is slow at 4 MHz. Fixed-point
  integers are much faster; see `mandel.c`.
- **Size.** Hello world with `printf` is about 2 KB, `mandel.c` about
  4.8 KB, and `ftest.c` 8.6 KB (with the file stub). Code, data, heap and
  stack share 8000h-FBFCh, about 31 KB, or 8000h-F7FCh, about 30 KB, with
  the file stub (F800h-FBFCh is its memory).
- **No time functions.** the Ampro Little Board has no real time clock and 
  ampDOS currently has no support for such.

The examples have been run on the real machine.
