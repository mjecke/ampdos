# Batch files

`NAME.BAT` is a text file of commands, run line by line as if they were typed.
Start it like a program: `NAME` (after `NAME.BIN` is looked for), `RUN NAME.BAT`,
or keep it in a `PATH` directory (`A:\BIN`). `BOOT` runs `AUTOEXEC.BAT` from the root of the current
drive (`BOOT B:`: of drive B). At every start, after the date question, `A:\AUTOEXEC.BAT`
runs by itself, if it is there (Esc stops it, like any batch file). `SETUP` keeps the
terminal's screen codes in it.

| | |
|---|---|
| `@command` | the line is not shown before it runs |
| `ECHO OFF`, `ECHO ON` | stop / start showing each line before it runs |
| `ECHO text` | show the text |
| `PAUSE` | wait for a key; Esc stops the batch file |
| `REM text` | a remark |
| `%0` .. `%9` | the batch file's name and its arguments (`%%` is a %) |
| `SHIFT` | `%1` becomes `%0`, `%2` becomes `%1` ... |
| `SET NAME=value` | keep a value (`SET` alone lists them; `SET NAME=` forgets one). Names are kept in capitals; all of them take 64 bytes at most. Also at the prompt |
| `%NAME%` | in a batch file's line: that value (nothing if there is none): `COPY %SRC% B:`, `IF "%MODE%"=="fast" GOTO quick`. A `%` followed by a space stays a `%` |
| `:label` | a place to jump to (the line itself does nothing) |
| `GOTO label` | go on after `:label` (any case; backwards too) |
| `IF [NOT] EXIST name command` | run the command if the file or directory is (not) there |
| `IF [NOT] a==b command` | ... if the two words are (not) the same, ignoring case: `IF "%1"=="" GOTO usage` |
| `IF [NOT] ERRORLEVEL n command` | ... if the last command's status is n or more |
| `TRUE`, `FALSE` | do nothing, leaving the status success (0) / failure (1) |

**The status.** Every command succeeds (0) unless it reports an error, is unknown,
lacks its argument, or is `FALSE` (1). `IF`, `ECHO`, `REM`, `GOTO`, `SHIFT` and
`PAUSE` leave it alone, so `IF ERRORLEVEL` still sees the command before them. A
program counts as a success unless it sets its exit status (`OS_STATUS`, see
[PROGRAMMING.md](PROGRAMMING.md)): any number 0-255, so `IF ERRORLEVEL 3` is true
for a status of 3 or more. `CHKDSK` fails when it finds a problem, so
`CHKDSK` then `IF ERRORLEVEL 1 ECHO check the disk` works.

**Running.** Esc stops a batch file after the current line. Programs and BASIC may
run from a batch file: `BASIC GAME`, with `DOS` at the end of the BASIC program,
comes back to the next line. A batch file started from another one takes its place,
as in MS-DOS. The lines may change drives and directories (not the disk the batch
file is on).

## An example

```
@ECHO OFF
IF "%1"=="" GOTO usage
IF NOT EXIST %1 GOTO missing
TYPE %1
GOTO end
:missing
ECHO no file %1
GOTO end
:usage
ECHO usage: SHOW file
:end
```

`tests/hw/TESTALL.BAT` uses all of it.
It is the whole-system test for the board.
