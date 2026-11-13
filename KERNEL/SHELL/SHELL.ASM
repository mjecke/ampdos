; ==========================================================================
; SHELL.ASM - the command line: prompt, read a line, find the command, run it.
;
; A line is a command word and its arguments:  COPY A.TXT B.TXT
; The word is looked up in sh_table.  A word that is not a command is taken
; as a program name: FOO runs FOO.BIN (see RUN.ASM).
; Every command routine is called with sh_args pointing at its arguments
; (spaces skipped, may be empty) and just returns; on an error it prints a
; message itself.  The stack is reset before every command, so a command
; may also stop anywhere by jumping to sh_loop.
; ==========================================================================

sh_cold:
	di
	ld sp,OSSTACK
	ld hl,SHBUF		; every variable 0 (after power-on RAM holds anything),
	ld de,SHBUF+1		; and the shell's own area (no screen codes: a teletype)
	ld bc,VARS+0FFh-SHBUF
	ld (hl),0
	ldir
	call os_install
	call con_init
	xor a
	ld (sh_nonl),a
	call con_crlf		; (on a line of its own, after a boot loader's dots)
	call sh_banner		; the ampDOS banner, then the version
	call sh_hello
	xor a			; drive A, both drives in their root directory
	ld (sh_drive),a
	ld (SH_PATH0),a
	ld (SH_PATH1),a
	ld hl,0
	ld (sh_cwd0),hl
	ld (sh_cwd1),hl
	ld (fs_cwd),hl
	call sh_bufdef
	ld hl,HIST		; no history yet; PATH = A:\BIN
	ld (hs_end),hl
	ld hl,m_cr_defpath
	ld de,PATHBUF
	ld bc,7
	ldir
	ld hl,80*256+24 	; a screen of 24 x 80 until SCREEN says otherwise
	ld (scr_rows),hl
	xor a
	ld (scr_wrap),a
	ld hl,SH_DEFDATE	; no clock: start from this date, then ask
	ld (sh_date),hl
	call md_init
	jr nc,sh_c1
	ld hl,m_sh_nodisk
	call con_puts
	call md_off		; (and the drive's motor stops)
sh_c1:	call mt_boot		 ; test the RAM, then ask for the date
	call sh_askdate
	call sh_autoexec	; A:\AUTOEXEC.BAT, if there is one (Esc stops it)
	jr sh_loop

sh_warm:			; OS_WARM: a program wants to stop
	di
	ld sp,OSSTACK
	call sh_cleanup

sh_loop:			; (a command may give up by jumping here)
	ld sp,OSSTACK
	call rd_end		; the last command's > file, if it had one
	ld a,(sh_exec)		; ... while running for a program: back to it
	or a
	jp nz,oe_back
	ld a,(sh_bat)		; a batch file running: its next line
	or a
	jr z,sh_l0
	call bat_line
	jr nc,sh_lrun
sh_l0:	call sh_prompt
	ld a,1			; (Up and Down bring back earlier lines)
	ld (gl_hist),a
	ld hl,LINEBUF
	ld b,78
	call con_getline
	xor a
	ld (gl_hist),a
	call hs_add		; kept for Up
sh_lrun:
	call sh_do
	jr sh_loop

sh_do:				; run the command line in LINEBUF
	call rd_start		; (... > file)
	call sh_parse
	ld a,(sh_cmd)
	or a
	ret z			; empty line
	ld a,(sh_status)	; a new command: success until it says otherwise
	ld (sh_lstat),a
	xor a
	ld (sh_status),a
	ld a,(sh_cmd+1) 	; "A:" or "B:" alone: change drives
	cp ':'
	jr nz,sh_l1
	ld a,(sh_cmd+2)
	or a
	jp z,sh_drvcmd
sh_l1:	call sh_lookup
	jp c,cmd_runword	; not a command: a program?
sh_jphl:
	jp (hl) 		; run the command

; OS_EXEC: HL = a command line, DE = memory the commands may use, BC = its size
; (at least 512 bytes).  Runs one built-in command for a program (BASIC's DOS
; statement): programs and FDISK are refused, they would need the TPA.
; CF = refused.  The command uses the caller's stack (about 200 bytes).
os_exec:
	ld a,b			; at least 512 bytes to work in
	cp 2
	ret c
	ld (sh_buf),de
	ld (sh_bufsz),bc
	ld de,LINEBUF		; the line into LINEBUF (78 characters at most)
	ld b,78
oe_1:	ld a,(hl)
	ld (de),a
	or a
	jr z,oe_2
	inc hl
	inc de
	djnz oe_1
	xor a
	ld (de),a
oe_2:	ld a,1
	ld (sh_exec),a
	ld (sh_exsp),sp
	call sh_do
oe_back:			; (from sh_loop, if the command gave up)
	ld sp,(sh_exsp)
	xor a
	ld (sh_exec),a
sh_bufdef:			; commands work in the TPA again
	ld hl,TPA
	ld (sh_buf),hl
	ld hl,TPA_TOP-TPA
	ld (sh_bufsz),hl
	or a
	ret

sh_noexec:			; CF = a program is running (OS_EXEC): not now
	ld a,(sh_exec)
	or a
	ret z
	ld hl,m_sh_noexec
	call con_puts
	scf
	ret

; --------------------------------------------------------------------------
; sh_parse: LINEBUF -> sh_cmd (the first word, upper case, at most 12
; characters), sh_word (where it starts), sh_args (what follows it)
; --------------------------------------------------------------------------
sh_parse:
	ld hl,LINEBUF
	call sh_skipsp
	ld (sh_word),hl
	call sh_wordup
	ld (sh_args),hl
	ret

sh_wordup:			; HL = text: its first word, in capitals -> sh_cmd;
	ld de,sh_cmd		; HL = after it and the spaces that follow
	ld b,12
sp_1:	ld a,(hl)
	or a
	jr z,sp_3
	cp ' '
	jr z,sp_3
	cp '='			; (PATH=A:\BIN: the word is PATH)
	jr z,sp_3
	call sh_upper
	inc hl
	dec b
	inc b
	jr z,sp_1		; longer than 12: keep skipping, stop storing
	ld (de),a
	inc de
	dec b
	jr sp_1
sp_3:	xor a
	ld (de),a
	jr sh_skipsp

sh_skipsp:			; HL past any spaces
	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr sh_skipsp

sh_skipword:			; HL past a word (to a space or the end)
	ld a,(hl)
	or a
	ret z
	cp ' '
	ret z
	inc hl
	jr sh_skipword

; --------------------------------------------------------------------------
; sh_lookup: sh_cmd -> HL = its routine, or CF if there is no such command.
; sh_table: zero-terminated names, each followed by the routine's address;
; a 0 byte where a name would start ends the table.
; --------------------------------------------------------------------------
sh_lookup:
	ld hl,sh_table
sh_lookt:			; HL = a table like sh_table: sh_cmd in it?
sl_1:	ld a,(hl)
	or a
	jr z,sl_none
	ld de,sh_cmd
sl_2:	ld a,(de)
	cp (hl)
	jr nz,sl_skip
	or a
	jr z,sl_found		; both ended together
	inc hl
	inc de
	jr sl_2
sl_found:
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	or a
	ret
sl_skip:
	ld a,(hl)		; to the end of this name ...
	inc hl
	or a
	jr nz,sl_skip
	inc hl			; ... and past its address
	inc hl
	jr sl_1
sl_none:
	scf
	ret

sh_table:
	defm "DIR"
	defb 0
	defw cmd_dir
	defm "TYPE"
	defb 0
	defw cmd_type
	defm "MORE"
	defb 0
	defw cmd_more
	defm "CMP"
	defb 0
	defw cmd_cmp
	defm "FC"
	defb 0
	defw cmd_cmp
	defm "CRC"
	defb 0
	defw cmd_crc
	defm "FIND"
	defb 0
	defw cmd_find
	defm "SORT"
	defb 0
	defw cmd_sort
	defm "TERM"
	defb 0
	defw cmd_term
	defm "DEL"
	defb 0
	defw cmd_del
	defm "COPY"
	defb 0
	defw cmd_copy
	defm "RUN"
	defb 0
	defw cmd_run
	defm "CD"
	defb 0
	defw cmd_cd
	defm "CHDIR"
	defb 0
	defw cmd_cd
	defm "MD"
	defb 0
	defw cmd_md
	defm "MKDIR"
	defb 0
	defw cmd_md
	defm "RD"
	defb 0
	defw cmd_rd
	defm "RMDIR"
	defb 0
	defw cmd_rd
	defm "FDISK"
	defb 0
	defw cmd_fdisk
	defm "FORMAT"
	defb 0
	defw cmd_fdisk
	defm "DATE"
	defb 0
	defw cmd_date
	defm "SERRECV"
	defb 0
	defw cmd_serrecv
	defm "SERSEND"
	defb 0
	defw cmd_sersend
	defm "MEMTEST"
	defb 0
	defw cmd_mem
	defm "MEM"
	defb 0
	defw cmd_mem
	defm "CLEAR"
	defb 0
	defw cmd_clear
	defm "CLS"
	defb 0
	defw cmd_clear
	defm "SCREEN"
	defb 0
	defw cmd_screen
	defm "TOUCH"
	defb 0
	defw cmd_touch
	defm "PWD"
	defb 0
	defw cmd_pwd
	defm "LS"		; Unix names for the same commands
	defb 0
	defw cmd_dir
	defm "CAT"
	defb 0
	defw cmd_type
	defm "RM"
	defb 0
	defw cmd_del
	defm "CP"
	defb 0
	defw cmd_copy
	defm "MV"
	defb 0
	defw cmd_mv
	defm "HELP"
	defb 0
	defw cmd_help
	defm "?"
	defb 0
	defw cmd_help
	defm "VER"
	defb 0
	defw cmd_ver
	defm "EXIT"
	defb 0
	defw cmd_exit
	defm "RESTART"
	defb 0
	defw cmd_restart
	defm "ECHO"
	defb 0
	defw cmd_echo
	defm "PAUSE"
	defb 0
	defw cmd_pause
	defm "REM"
	defb 0
	defw cmd_rem
	defm "BOOT"
	defb 0
	defw cmd_boot
	defm "IF"
	defb 0
	defw cmd_if
	defm "GOTO"
	defb 0
	defw cmd_goto
	defm "SET"
	defb 0
	defw cmd_set
	defm "SHIFT"
	defb 0
	defw cmd_shift
	defm "SLEEP"
	defb 0
	defw cmd_sleep
	defm "TRUE"
	defb 0
	defw cmd_true
	defm "FALSE"
	defb 0
	defw cmd_false
	defm "WC"
	defb 0
	defw cmd_wc
	defm "ID"
	defb 0
	defw cmd_id
	defm "GO"
	defb 0
	defw cmd_go
	defm "DELTREE"
	defb 0
	defw cmd_deltree
	defm "MIRROR"
	defb 0
	defw cmd_mirror
	defm "HISTORY"
	defb 0
	defw cmd_history
	defm "PATH"
	defb 0
	defw cmd_path
	defm "PEEK"
	defb 0
	defw cmd_peek
	defm "POKE"
	defb 0
	defw cmd_poke
	defm "IN"
	defb 0
	defw cmd_in
	defm "OUT"
	defb 0
	defw cmd_out
	defm "LABEL"
	defb 0
	defw cmd_label
	defm "VOL"
	defb 0
	defw cmd_vol
	defm "CHKDSK"
	defb 0
	defw cmd_chkdsk
	defm "DISKCOPY"
	defb 0
	defw cmd_diskcopy
	defm "SYS"
	defb 0
	defw cmd_sys
	defb 0

; --------------------------------------------------------------------------
; helpers for the commands
; --------------------------------------------------------------------------
sh_mount:			; go home: the current drive and directory, the disk
	ld a,(sh_drive) 	; read again (it may have been changed).  CF = failed
	call sh_cwdp
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld a,(sh_drive)
	call sh_ctx
	jp c,sh_err1
	ld a,(sh_drive) 	; is the directory still there?
	call sh_cwdp
	ld e,(hl)
	inc hl
	ld d,(hl)
	push hl
	ld hl,(fs_cwd)
	or a
	sbc hl,de
	pop hl
	ret z
	xor a			; no (another disk): back to the root
	ld (hl),a
	dec hl
	ld (hl),a
	call sh_curpath
	ld (hl),a
	ld hl,m_sh_root
	call con_puts
	or a
	ret

os_mount:			; OS_MOUNT: fs_mount, and today's date for new files
	call fs_mount
	ret c
	ld hl,(sh_date)
	ld (fs_fdate),hl
	ret

sh_curpath:			; HL = the current drive's path ("\SUB\X" or "")
	ld hl,SH_PATH0
	ld a,(sh_drive)
	or a
	ret z
	ld hl,SH_PATH1
	ret

sh_prompt:			; "A>" in the root, "A:\SUB>" elsewhere
	ld hl,sh_nonl		; (no empty line first, just after CLEAR)
	ld a,(hl)
	ld (hl),0
	or a
	call z,con_crlf
	ld a,(sh_drive)
	add a,'A'
	call con_putc
	call sh_curpath
	ld a,(hl)
	or a
	jr z,sh_pr1
	ld a,':'
	call con_putc
	call con_puts
sh_pr1: ld hl,m_sh_gt
	jp con_puts

sh_pwd: 			; print "A:\SUB" (or "A:\")
	ld a,(sh_drive)
	add a,'A'
	call con_putc
	ld a,':'
	call con_putc
	call sh_curpath
	ld a,(hl)
	or a
	jp nz,con_puts
	ld a,5Ch		; a backslash
	jp con_putc

sh_drvcmd:			; "A:" / "B:"
	ld a,(sh_cmd)
	sub 'A'
	cp 2
	jr c,sh_setdrv
	ld hl,m_sh_nodrv
	jp con_puts

sh_setdrv:			; A = drive.  The next command selects and reads it
	ld (sh_drive),a
	ret

sh_need1:			; HL = first argument, CF (and a message) if none
	ld hl,(sh_args)
	ld a,(hl)
	or a
	ret nz
	ld hl,m_sh_need1
	jp sh_usage

sh_open1:			; the first argument, found: drive and directory
	call sh_need1		; selected, HL = its name part.  CF = failed (said so)
	ret c
	call sh_mount
	ret c
	ld hl,(sh_args)
	call sh_resolve
	ret nc
	jp sh_err1

sh_need2:			; HL = first argument, DE = second, CF if missing
	call sh_need1
	ret c
	push hl
	call sh_skipword
	call sh_skipsp
	ex de,hl
	pop hl
	ld a,(de)
	or a
	ret nz
	ld hl,m_sh_need2	; (a failure too: IF ERRORLEVEL sees it)
	jp sh_usage

sh_err1:			; print error A, return CF
	call sh_err
	scf
	ret

sh_err: 			; print the message for error code A
	call sh_fail
	push af
	push hl
	call fs_errmsg
	call con_puts
	call con_crlf
	pop hl
	pop af
	ret

sh_brk: 			; any key pauses, Esc stops (CF)
	call con_kbhit
	ret z
	call con_getc
	cp 1Bh
	jr z,sh_brk1
	call con_getc
	cp 1Bh
	jr z,sh_brk1
	or a
	ret
sh_brk1:
	scf
	ret

sh_cleanup:			; after a program: make the OS whole again
	xor a
	ld (sh_exec),a
	call sh_bufdef
	call os_install 	; (a program may have overwritten the table)
	call con_init
	call md_drop		; what a program did not flush is thrown away
	xor a
	ld (fs_fatdirty),a
	ret

; --------------------------------------------------------------------------
cmd_help:			; two parts, so it fits a screen: a key between them
	ld hl,m_sh_help 	; (Esc stops)
	call con_puts
	ld hl,m_ct_more
	call con_puts
	call con_getc
	call con_crlf
	cp 1Bh
	ret z
	ld hl,m_sh_help2
	jp con_puts

cmd_ver:
sh_hello:			; "ampDOS 0.8.8 for the AMPRO Little Board. ..."
	ld hl,m_sh_hello
	jp con_puts

m_sh_nodisk:
	defm "(no disk in the drive yet)"
	defb 13,10,0

cmd_restart:			; RESTART: the OS from its start, as after power-on.
	call fs_flush		; RESTART W: warm, back to the prompt keeping the
				; date, the drives' directories, the status
	ld hl,(sh_args)
	ld a,(hl)
	and 0DFh
	cp 'W'
	jr z,crs_w
	jp os_start
crs_w:	call md_init		; the drives set up again
	xor a			; no batch file goes on
	ld (sh_bat),a
	jp sh_warm		; (the call table, console, disk state, stack)

cmd_exit:			; back to the machine's boot ROM (which boots the
	call fs_flush		; disk again: mach_reboot)
	jp mach_reboot

m_sh_noexec: defm "not from inside a program"
	defb 13,10,0
m_sh_hello:
	defb 13,10
	defm "ampDOS "
	include "GEN/VERTEXT.INC"    ; defm "0.8.8" (from VERSION)
	defm " for the AMPRO Little Board.  HELP lists commands."
	defb 13,10,0
m_sh_gt:
	defm "> "
	defb 0
m_sh_root:
	defm "(another disk: back to the root directory)"
	defb 13,10,0
m_sh_nodrv:
	defm "there are only drives A: and B:"
	defb 13,10,0
m_sh_need1:
	defm "which file?"
	defb 13,10,0
m_sh_need2:
	defm "two names are needed"
	defb 13,10,0
m_sh_help:			; (SPC+n: n spaces, to keep it small)
	defm "Files",SPC+8,"DIR (LS) [name]",SPC+3,"TYPE (CAT) name",SPC+3,"DUMP name",SPC+3,"WC name ..."
	defb 13,10
	defm SPC+13,"COPY (CP) from [to]",SPC+3,"MV from to (rename, move)",SPC+3,"DEL (RM) name"
	defb 13,10
	defm SPC+13,"TOUCH name",SPC+3,"wildcards: DIR *.BAS",SPC+2,"DEL *.TMP",SPC+2,"COPY *.* B:"
	defb 13,10
	defm "Text",SPC+9,"MORE name [n]",SPC+3,"CMP (FC) a b",SPC+3,"CRC name",SPC+3,"SORT [/R /I] name [out]"
	defb 13,10
	defm SPC+13,"FIND [/I /N /C] ",34,"text",34," name"
	defb 13,10
	defm "Directories",SPC+2,"CD [d:][dir]",SPC+3,"MD name",SPC+3,"RD name",SPC+3,"DELTREE [/Y] dir",SPC+3,"PWD"
	defb 13,10
	defm "Disks",SPC+8,"A:",SPC+2,"B:",SPC+3,"FDISK [d:] [/Q]",SPC+3,"BOOT [d:]",SPC+3,"(runs AUTOEXEC.BAT)"
	defb 13,10
	defm SPC+13,"CHKDSK [d:] [/F]",SPC+3,"LABEL [d:] [name|/D]",SPC+3,"VOL [d:]"
	defb 13,10
	defm SPC+13,"DISKCOPY A: B:",SPC+3,"(A: A: for one drive)"
	defb 13,10
	defm SPC+13,"SYS [d:]",SPC+3,"(make it a boot disk)"
	defb 13,10
	defm "Programs",SPC+5,"name [args]",SPC+2,"or",SPC+2,"RUN name [args]",SPC+3,"(here, then the PATH)"
	defb 13,10
	defm SPC+13,"PATH [dir;dir...]",SPC+3,"BASIC [name]",SPC+3,"GO hhhh [args]"
	defb 13,10
	defm "Serial B",SPC+5,"SERRECV [name]",SPC+3,"SERSEND name",SPC+3,"(PC side: serxfer.py)"
	defb 13,10
	defm SPC+13,"MIRROR [ON|OFF]",SPC+3,"(console to Serial B too)"
	defb 13,10
	defm SPC+13,"TERM [baud] [8N1] [/E]",SPC+3,"(Ctrl-] ends)"
	defb 13,10,0
m_sh_help2:
	defm "System",SPC+7,"DATE [yyyy-mm-dd]",SPC+3,"MEM",SPC+3,"ID [B]",SPC+3,"VER",SPC+3,"CLEAR (CLS)"
	defb 13,10
	defm SPC+13,"SLEEP seconds[.mmm]",SPC+3,"RESTART [W]",SPC+3,"EXIT"
	defb 13,10
	defm SPC+13,"SCREEN TTY | action hh ...",SPC+3,"(the terminal's codes: SETUP)"
	defb 13,10
	defm SPC+13,"PEEK addr [n]",SPC+3,"POKE addr bytes",SPC+3,"IN port",SPC+3,"OUT port value",SPC+2,"(hex)"
	defb 13,10
	defm "Batch files",SPC+2,"NAME.BAT: one command a line",SPC+3,"@line",SPC+3,"REM text",SPC+3,":label"
	defb 13,10
	defm SPC+13,"ECHO ON|OFF|text",SPC+3,"PAUSE",SPC+3,"GOTO label",SPC+3,"SHIFT",SPC+3,"%0 .. %9"
	defb 13,10
	defm SPC+13,"SET [NAME=value]",SPC+3,"%NAME%"
	defb 13,10
	defm SPC+13,"IF [NOT] EXIST name | a==b | ERRORLEVEL n",SPC+2,"command"
	defb 13,10
	defm SPC+13,"TRUE",SPC+3,"FALSE",SPC+3,"(set the status)"
	defb 13,10
	defb 13,10
	defm "Names: [d:][\\dir\\]NAME.EXT, e.g. B:\\GAMES\\HUNT.BAS"
	defb 13,10
	defm "Output: command > file (made new), >> file (added to)"
	defb 13,10
	defm "Ctrl-P/N: earlier lines; Esc clears the line; HISTORY lists them."
	defb 13,10
	defm "A key pauses output, Esc stops it."
	defb 13,10,0
