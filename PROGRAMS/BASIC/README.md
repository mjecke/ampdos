# BASIC

`BASIC.BIN` is a Microsoft BASIC 4.7 (NASCOM ROM BASIC) interpreter, derived 
from **Grant Searle's** Z80 version, with some modifications by me specifically 
for the Little Board and ampDOS. Start it with `BASIC` at the prompt, or 
`BASIC NAME` to load `NAME.BAS` and run it.

## Credit and license

- NASCOM ROM BASIC Ver 4.7, (C) 1978 **Microsoft**.
- The Z80 version, `BAS32K.ASM` (kept here unchanged), is by **Grant Searle**
  His terms: you may use it for **non-commercial use only**; if
  you use it elsewhere, include an acknowledgement to him.
- Searle's original z80 ASM source is modified for the ampDOS project as 
  discussed  below and if this version is distributed in any way it is also 
  considered to be for non-commercial use only and attribution to Searle and 
  this project need be included.
- So `BASIC.BIN`, and any ampDOS disk image that includes it, is for
  **non-commercial use only**, whatever the license of the rest of ampDOS (MIT).
  It is a separate program on the disk, not part of the OS.

If for some reason you use an ampDOS image in a commercial setting, leave 
`BASIC.BIN` off it.

## Memory routine

BASIC loads at 8000h like any program and asks the OS how much RAM it may use:
23,076 bytes free (Searle's code as it is would leave 22,579).  To get there,
`mkbasic.py`:

- Assembles Searle's start-up table (a ROM's: copied into RAM at the start) at
  the end of BASIC.BIN, as the first bytes of BASIC's work area itself, so
  there is nothing to copy and no second copy;
- Moves the code that runs only at the start (and its sign-on messages) into
  DOSEXT's file buffers, which nothing uses before the first LOAD, SAVE or DOS;
- Drops what ampDOS makes unnecessary (the RAM size test, "Memory top");
- Makes each JP a JR where the target is near enough, except where its length
  or its speed counts (after a skip byte, in the start-up table, in the busiest
  routines).

## Speed mods

Searle's BASIC is from 8080 code; ampDOS's has Z80 code in its busiest places
(`mkbasic.py` patches them in, `BAS32K.ASM` stays as it is). 

Whole programs run a little faster because of the modifications, maybe 1.25-2x
in some cases.

Also, `@` and `_` are ordinary characters, typed or LOADed. (Previously they
deleted the line and the last character, so a LOADed line with one in it was
lost.) Normal Backspace and Delete delete.

## ampDOS BASIC version new keywords

In order to facilitate some interesting interactions when running BASIC on 
ampDOS, I've added new keyword functionality to the interpreter.  Notable, the 
SSAVE, SLOAD, and DPRINT commands are very useful because they can be used to 
prinout data over the Ampro Little Board's Serial B port, allowing custom BASIC 
programs to communicate with external RS-232 hardware via text commands. 

| Keyword | What it does |
|---|---|
| `LOAD "name"` | NEW, then read a program from a text file (`.BAS` is added if the name has no dot). Any key stops it. Lines are not shown while loading. |
| `SAVE "name"` | write the program as a text file (as LIST would show it) |
| `DOS "command"` | run a built-in ampDOS command and come back: `DOS "DIR"`, `DOS "TYPE X.BAS"`, `DOS "COPY A.BAS B:"`, `DOS "CD GAMES"`, `DOS "CLS"` |
| `DOS` | back to the ampDOS prompt (the program in memory is lost: SAVE it first) |
| `SSAVE` | send the program as text out of Serial B, ending with Ctrl-Z |
| `SLOAD` | NEW, then read a program as text from Serial B, until Ctrl-Z |
| `STPRINT ...` | exactly like PRINT, but the output goes to Serial B instead of the screen |
| `DPRINT ...` | exactly like PRINT, to the screen and Serial B both |
| `SLEEP n` | wait n milliseconds (0-65535); Ctrl-C stops it |

Names and commands are string expressions (`DOS "DIR "+D$`, `LOAD F$`) and may
have a drive and a path (`LOAD "B:\GAMES\HUNT"`). Disk programs and FDISK cannot 
run from inside BASIC (BASIC is in the memory they need). Stopping a program
with Ctrl-C also pulses the strobe line of the parallel port (for hardware that 
wants to know).

These took the places of keywords the Little Board has no use for: CLOAD and 
CSAVE (cassette) became SLOAD and SSAVE; SCREEN, SET and RESET (graphics stubs) 
became STPRINT, DPRINT and SLEEP; NULL, MONITOR and CLS became LOAD, SAVE and 
DOS.

## Standard NASCOM BASIC 4.7 commands
I think this is the rest, I took these keywords from the original NASCOM user 
manual.

Statements:

| | |
|---|---|
| `PRINT` (or `?`) | print; `;` keeps on the line, `,` jumps to the next zone; `TAB(n)`, `SPC(n)` |
| `INPUT ["prompt";] v,...` | read values typed in |
| `LET v = expr` | assign (LET may be left out) |
| `IF expr THEN ...` | `THEN` a statement or a line number; `GOTO n` works too |
| `GOTO n`, `GOSUB n`, `RETURN` | jump, call, return |
| `ON expr GOTO/GOSUB n,...` | jump to the n'th line number |
| `FOR v = a TO b [STEP s]`, `NEXT [v]` | loop |
| `DATA ...`, `READ v,...`, `RESTORE` | constants in the program, read in order |
| `DIM a(n,...)` | arrays (up to 10 elements need no DIM) |
| `DEF FNx(v) = expr` | a function of one variable: `FNx(3)` |
| `REM ...` | a remark |
| `END`, `STOP`, `CONT` | end; stop with a message; carry on after STOP or Ctrl-C |
| `POKE addr,byte`, `DOKE addr,word` | write a byte / a 16-bit word to memory |
| `OUT port,byte` | write to an I/O port |
| `WAIT port,and[,xor]` | wait until (port XOR xor) AND and is not 0 |
| `WIDTH n` | the terminal's width |
| `LINES n` | lines LIST shows before it waits for a key |
| `RUN [n]`, `LIST [a-b]`, `NEW`, `CLEAR [n]` | run, list, forget the program, clear variables (n: string space) |

Functions:

| | |
|---|---|
| `ABS SGN INT SQR RND LOG EXP SIN COS TAN ATN` | arithmetic (`RND(1)` a new random number) |
| `PEEK(a)`, `DEEK(a)` | read a byte / a 16-bit word from memory |
| `INP(port)` | read an I/O port, e.g. `INP(41)` is the ID jumpers |
| `FRE(0)`, `FRE("")` | free memory, free string space |
| `POS(0)` | the cursor's column |
| `USR(x)` | call machine code: DOKE its address into the USR jump first (label `USR` in `build/PROGRAMS/BASIC/BASIC.ASM`, plus 1) |
| `LEN STR$ VAL ASC CHR$ LEFT$ RIGHT$ MID$` | strings |
| `HEX$(n)`, `BIN$(n)` | a number in hex / binary; `&H1F` and `&B101` are hex / binary constants |
| `POINT` | a graphics stub (no use here) |

Operators: `+ - * / ^`, `= < > <= >= <>`, `AND OR NOT`. 

Ctrl-C stops a program, Ctrl-S pauses the output.
