; ==========================================================================
; BATCH.ASM - batch files: NAME.BAT is a text file of shell commands, run
; one line after the other as if typed.  Started like a program (NAME, or
; RUN NAME.BAT); BOOT [d:] runs AUTOEXEC.BAT from the root of a drive.
;
;   @command     the line is not shown first
;   ECHO OFF/ON  stop / start showing each line before it runs
;   ECHO text    show the text
;   PAUSE        wait for a key (Esc stops the batch file)
;   REM text     nothing (a remark)
; Esc pressed while a batch file runs stops it after the current line.  A
; program or BASIC may run from a batch file: the next line follows when it
; ends.  A batch file started from a batch file takes its place.
;
; The file stays open (sh_bfcb) and is read a byte at a time.  Its drive is
; read again only when the commands have gone to the other drive, so they may
; change drives and directories, but not the disk the batch file is on.
; ==========================================================================

bat_start:			; sh_fcb1 is an open batch file, named at sh_word0,
	ld hl,sh_fcb1		; with arguments at sh_args: run it
	ld de,sh_bfcb
	ld bc,FCB_LEN
	ldir
	ld hl,sh_fcb1		; (and once more, to start again from: GOTO)
	ld de,BATFCB0
	ld bc,FCB_LEN
	ldir
	ld hl,(sh_word0)	; %0 = the name, then the arguments
	ld de,BATARGS
	ld b,78
bs_1:	ld a,(hl)
	or a
	jr z,bs_2
	cp ' '
	jr z,bs_2
	ld (de),a
	inc hl
	inc de
	djnz bs_1
bs_2:	ld a,' '
	ld (de),a
	inc de
	ld hl,(sh_args)
bs_3:	ld a,(hl)
	ld (de),a
	or a
	jr z,bs_4
	inc hl
	inc de
	djnz bs_3
	xor a
	ld (de),a
bs_4:	ld (BATLBL),a		; (A = 0: no GOTO under way)
	ld a,(md_drive)
	ld (sh_bdrv),a
	ld a,1
	ld (sh_bat),a
	ld (sh_becho),a
	ret

bat_line:			; the next line into LINEBUF, shown unless @ or
	call con_kbhit		; ECHO OFF.  CF = the batch file is over
	jr z,bl_0
	call con_getc
	cp 1Bh
	jp z,bl_stop
bl_0:	xor a			; its disk.  Only read again when another drive is
	ld (sh_bhome),a 	; the one in use: each mount reads track 0 and the FAT
	ld a,(fs_mounted)	; (half a second), and a GOTO may skip many lines
	or a
	jr z,bl_m
	ld a,(md_drive)
	ld hl,sh_bdrv
	cp (hl)
	jr z,bl_r
bl_m:	ld a,(sh_bdrv)		; (the root will do: the file is open)
	ld hl,0
	call sh_ctx
	jp c,bl_err
	ld a,1			; (and back home before the command)
	ld (sh_bhome),a
bl_r:	ld hl,BATRAW
	ld b,78
bl_1:	push hl
	push bc
	ld ix,sh_bfcb
	ld de,sh_bch
	ld bc,1
	call f_read
	ld a,c			; (0 = the end)
	pop bc
	pop hl
	jp c,bl_err
	or a
	jr z,bl_eof
	ld a,(sh_bch)
	cp 1Ah			; ^Z: the end
	jr z,bl_eof
	cp 10
	jr z,bl_end
	cp 13
	jr z,bl_1
	cp 9			; a tab is a space
	jr nz,bl_2
	ld a,' '
bl_2:	dec b
	inc b
	jr z,bl_1		; (a line too long: the rest is left out)
	ld (hl),a
	inc hl
	dec b
	jr bl_1
bl_eof: ld a,(BATLBL)		; the end: during a GOTO, the label was not there
	or a
	jr nz,bl_nolbl
	ld a,b			; an unfinished last line still runs
	cp 78
	jr z,bl_stop
	xor a
	ld (sh_bat),a
bl_end: ld (hl),0
	ld hl,BATRAW		; a label?
	call sh_skipsp
	ld a,(hl)
	cp ':'
	jr nz,bl_cmd
	ld a,(BATLBL)		; yes: nothing to do, unless GOTO looks for it
	or a
	jr z,bl_more
	inc hl
	ld de,BATLBL
	call bt_word
	jr nz,bl_more
	xor a			; found: on from the next line
	ld (BATLBL),a
bl_more:
	ld a,(sh_bat)		; (the end of the file was reached: no more)
	or a
	jr nz,bl_r
	scf
	ret
bl_cmd: ld a,(BATLBL)		; a GOTO looks for its label: skip the line
	or a
	jr nz,bl_more
	call bl_expand		; %n replaced: into LINEBUF
	ld a,(sh_bhome) 	; home again for the command, if we left it
	or a
	call nz,sh_mount
	ld hl,LINEBUF
	call sh_skipsp
	ld a,(hl)
	cp '@'
	jr z,bl_at
	ld a,(sh_becho)
	or a
	ret z
	call sh_prompt		; "A> command", as if it had been typed
	ld hl,LINEBUF
	call con_puts
	call con_crlf
	or a
	ret
bl_at:	ld (hl),' '		; @: not shown
	or a
	ret
bl_nolbl:
	ld hl,m_bt_nolbl
	call con_puts
	ld hl,BATLBL
	call con_puts
	call con_crlf
	jr bl_stop
bl_err: call sh_err
bl_stop:
	xor a
	ld (sh_bat),a
	scf
	ret

cmd_echo:			; ECHO OFF, ECHO ON, ECHO text
	call bt_keep
	ld hl,(sh_args)
	push hl
	ld de,m_bt_off
	call bt_word
	ld a,0
	jr z,ce_set
	pop hl
	push hl
	ld de,m_bt_on
	call bt_word
	ld a,1
	jr z,ce_set
	pop hl
	call con_puts
	jp con_crlf
ce_set: pop hl
	ld (sh_becho),a
	ret

bl_expand:			; BATRAW -> LINEBUF, with %0..%9, %NAME% and %% replaced
	ld hl,BATRAW
	ld de,LINEBUF
	ld b,78 		; (room left)
bx_1:	ld a,(hl)
	inc hl
	or a
	jp z,bx_end
	cp '%'
	jr nz,bx_put
	ld a,(hl)
	cp '%'
	jr z,bx_pct
	sub '0'
	cp 10
	jr nc,bx_name
	ld a,(hl)
	inc hl
	push hl
	sub '0'
	call bt_arg		; HL = that argument
bx_2:	ld a,(hl)
	or a
	jr z,bx_3
	cp ' '
	jr z,bx_3
	inc hl
	call bx_out
	jr bx_2
bx_3:	pop hl
	jr bx_1
bx_pct: inc hl
bx_put: call bx_out
	jr bx_1
bx_name:			; %NAME%: SET's value (none: nothing); no closing %: a %
	push hl
	ld c,0
bx_n1:	ld a,(hl)
	or a
	jr z,bx_nn
	cp '%'
	jr z,bx_n2
	cp 21h			; (a space: not a name, the % stays)
	jr c,bx_nn
	inc hl
	inc c
	ld a,c
	cp 13
	jr c,bx_n1
bx_nn:	pop hl
	ld a,'%'
	jr bx_put
bx_n2:	pop hl			; HL = the name, C = its length
	push hl
	push de
	push bc
	ex de,hl
	call env_find
	pop bc
	pop de
	jr nz,bx_n4
bx_n3:	ld a,(hl)		; the value: after the =
	inc hl
	cp '='
	jr nz,bx_n3
bx_nv:	ld a,(hl)
	or a
	jr z,bx_n4
	call bx_out
	inc hl
	jr bx_nv
bx_n4:	pop hl			; on after the closing %
	ld a,c
	inc a
	add a,l
	ld l,a
	jr nc,bx_1
	inc h
	jr bx_1

env_find:			; DE = a name (C characters, any case) -> HL = its
	ld hl,ENVBUF		; "NAME=value", Z.  NZ = there is none
ef_1:	ld a,(hl)
	or a
	jr z,ef_no
	push hl
	push de
	ld b,c
ef_2:	ld a,(de)
	call sh_upper
	cp (hl)
	jr nz,ef_3
	inc hl
	inc de
	djnz ef_2
	ld a,(hl)
	cp '='
ef_3:	pop de
	pop hl
	ret z
ef_4:	ld a,(hl)
	inc hl
	or a
	jr nz,ef_4
	jr ef_1
ef_no:	or 1
	ret

cmd_set:			; SET: list them.  SET NAME=value, SET NAME= (gone)
	ld hl,(sh_args)
	ld a,(hl)
	or a
	jr nz,cst_1
	ld hl,ENVBUF
cst_l:	ld a,(hl)
	or a
	ret z
	call con_puts
	call con_crlf
cst_l2: ld a,(hl)
	inc hl
	or a
	jr nz,cst_l2
	jr cst_l
cst_1:	ld d,h			; DE = the name; up to the =, in capitals
	ld e,l
	ld c,0
cst_2:	ld a,(hl)
	or a
	jr z,cst_use
	cp '='
	jr z,cst_3
	call sh_upper
	ld (hl),a
	inc hl
	inc c
	jr cst_2
cst_3:	ld a,c
	or a
	jr z,cst_use
	push hl
	push de
	call env_find		; an old one goes
	jr nz,cst_4
	ld d,h			; DE = it; HL = after it
	ld e,l
cst_s:	ld a,(hl)
	inc hl
	or a
	jr nz,cst_s
	push de
	ld de,ENVBUF+ENVLEN
	ex de,hl
	or a
	sbc hl,de		; BC = the rest
	ld b,h
	ld c,l
	ex de,hl
	pop de
	ldir
cst_4:	pop de
	pop hl
	inc hl			; the value: none = just gone
	ld a,(hl)
	or a
	ret z
	ld hl,ENVBUF		; the end of the ones there
cst_e:	ld a,(hl)
	or a
	jr z,cst_f
cst_e2: ld a,(hl)
	inc hl
	or a
	jr nz,cst_e2
	jr cst_e
cst_f:	push hl 		; room for "NAME=value", 0 and the end's 0?
	ld h,d
	ld l,e
	ld bc,2
cst_f1: ld a,(hl)
	inc hl
	inc bc
	or a
	jr nz,cst_f1
	pop hl
	push hl
	add hl,bc
	dec hl
	ld bc,ENVBUF+ENVLEN+1
	or a
	sbc hl,bc
	pop hl
	jr nc,cst_full
	ex de,hl		; copy it, then the end
cst_c:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,cst_c
	ld (de),a
	ret
cst_full:
	ld hl,m_bt_full
	jp sh_usage
cst_use:
	ld hl,m_bt_setu
	jp sh_usage
m_bt_full:
	defm "no room: SET's variables take 64 bytes at most"
	defb 13,10,0
m_bt_setu:
	defm "SET [NAME=value]"
	defb 13,10,0
bx_end: ld (de),a
	ret
bx_out: dec b			; A to (DE), if there is room
	inc b
	ret z
	ld (de),a
	inc de
	dec b
	ret

bt_arg: 			; HL = argument A (0 = the name) in BATARGS
	ld c,a
	ld hl,BATARGS
	call sh_skipsp
	inc c
bta_1:	dec c
	ret z
	call sh_skipword
	call sh_skipsp
	jr bta_1

cmd_shift:			; SHIFT: %0 goes, %1 becomes %0 ...
	call bt_keep
	xor a
	inc a
	call bt_arg
	ld de,BATARGS
csh_1:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,csh_1
	ret

cmd_goto:			; GOTO label: read the file again from the start,
	call bt_keep		; up to the line ":label"
	ld a,(sh_bat)
	or a
	ret z
	call sh_need1
	ret c
	ld a,(hl)		; (GOTO :label works too)
	cp ':'
	jr nz,cg_1
	inc hl
cg_1:	ld de,BATLBL
	ld b,15
cg_2:	ld a,(hl)
	or a
	jr z,cg_3
	cp ' '
	jr z,cg_3
	call sh_upper
	ld (de),a
	inc hl
	inc de
	djnz cg_2
cg_3:	xor a
	ld (de),a
	ld hl,BATFCB0
	ld de,sh_bfcb
	ld bc,FCB_LEN
	ldir
	ret

cmd_if: 			; IF [NOT] EXIST name command / IF [NOT] a==b command
	call bt_keep		; (IF itself leaves the status as it was)
	ld hl,(sh_args)
	xor a
	ld (sh_ifnot),a
	push hl
	ld de,m_bt_not
	call bt_word
	pop hl
	jr nz,ci_1
	ld a,1
	ld (sh_ifnot),a
	call sh_skipword
	call sh_skipsp
ci_1:	push hl 		; ERRORLEVEL n: the last status n or more?
	ld de,m_bt_errl
	call bt_word
	pop hl
	jr nz,ci_ex
	call sh_skipword
	call sh_skipsp
	call cu_num		; DE = n
	jp c,ci_bad
	call ci_cut
	ld a,(sh_lstat)
	cp e
	jr nc,ci_yes
	jr ci_no
ci_ex:	push hl
	ld de,m_bt_exist
	call bt_word
	pop hl
	jr nz,ci_str
	call sh_skipword	; ---- EXIST name
	call sh_skipsp
	ld a,(hl)
	or a
	jr z,ci_bad
	push hl
	call ci_cut		; the name ends with a 0, the command is noted
	call sh_mount
	pop hl
	jr c,ci_no
	call sh_resolve
	jr c,ci_no
	ld ix,sh_fcb1
	call f_open
	jr nc,ci_yes
	cp FS_EISDIR		; a directory counts too
	jr nz,ci_no
ci_yes: ld a,1
	jr ci_res
ci_str: ld a,(hl)		; ---- a==b
	or a
	jr z,ci_bad
	push hl
	call ci_cut
	pop hl
	ld d,h			; DE: look for "=="
	ld e,l
ci_s1:	ld a,(de)
	or a
	jr z,ci_bad
	inc de
	cp '='
	jr nz,ci_s1
	ld a,(de)
	cp '='
	jr nz,ci_s1
	dec de			; the first '=' ends a, b follows the second
	xor a
	ld (de),a
	inc de
	inc de
ci_s2:	ld a,(de)		; the same, letter for letter (any case)?
	call sh_upper
	ld c,a
	ld a,(hl)
	call sh_upper
	cp c
	jr nz,ci_no
	or a
	jr z,ci_yes
	inc hl
	inc de
	jr ci_s2
ci_no:	xor a
ci_res: ld hl,sh_ifnot		; NOT turns it round
	xor (hl)
	ret z
	ld hl,(sh_ifr)		; true: the command, as if typed
	ld de,LINEBUF
ci_r1:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,ci_r1
	jp sh_do
ci_bad: ld hl,m_bt_if
	jp con_puts

ci_cut: call sh_skipword	; HL = a word: end it with a 0, sh_ifr = what follows
	ld a,(hl)
	or a
	jr z,cic_1
	ld (hl),0
	inc hl
	call sh_skipsp
cic_1:	ld (sh_ifr),hl
	ret

bt_word:			; Z = HL holds just the word at DE (any case)
	ld a,(de)
	or a
	jr z,btw_end
	ld a,(hl)
	call sh_upper
	ex de,hl
	cp (hl)
	ex de,hl
	ret nz
	inc hl
	inc de
	jr bt_word
btw_end:
	ld a,(hl)		; then the end, or a space
	or a
	ret z
	cp ' '
	ret

cmd_pause:
	call bt_keep
	ld hl,m_bt_pause
	call con_puts
	call con_getc
	push af
	call con_crlf
	pop af
	cp 1Bh
	ret nz
	xor a			; Esc: no more of the batch file
	ld (sh_bat),a
	ret

cr_isbat:			; Z = sh_name ends in ".BAT" (any case)
	ld de,m_cr_bat+1
cr_isext:			; Z = sh_name's extension is the one at DE ("BIN", 0)
	ld hl,sh_name
cib_1:	ld a,(hl)
	inc hl
	or a
	jr z,cib_no
	cp '.'
	jr nz,cib_1
	call bt_word
	ret
cib_no: inc a			; NZ
	ret

m_bt_not:   defm "NOT"
	defb 0
m_bt_errl:  defm "ERRORLEVEL"
	defb 0
m_bt_exist: defm "EXIST"
	defb 0
m_bt_if:    defm "IF [NOT] EXIST name | a==b | ERRORLEVEL n  command"
	defb 13,10,0
m_bt_nolbl: defm "batch file: no label :"
	defb 0
m_bt_off:   defm "OFF"
	defb 0
m_bt_on:    defm "ON"
	defb 0
m_bt_pause: defm "Press a key (Esc stops) "
	defb 0
m_cr_bat:   defm ".BAT"
	defb 0
m_ext_bin:  defm "BIN"
	defb 0
m_cr_notp:  defm "only .BIN and .BAT files run"
	defb 13,10,0
cmd_rem:			; REM: nothing (and the status stays)
bt_keep:			; ECHO, REM, GOTO, SHIFT, PAUSE (and IF) leave the
	ld a,(sh_lstat) 	; status as the command before them left it, so
	ld (sh_status),a	; IF ERRORLEVEL still sees that one afterwards
	ret

sh_autoexec:			; at start: A:\AUTOEXEC.BAT, if it is there (quietly
	xor a			; nothing if not)
	ld h,a
	ld l,a
	call sh_ctx
	ret c
	ld hl,m_bt_auto
	ld ix,sh_fcb1
	call f_open
	ret c
	jr cbt_go

cmd_boot:			; BOOT [d:]: run AUTOEXEC.BAT from the root of this
	ld a,(sh_drive) 	; drive, or of the one named
	ld hl,(sh_args)
	ld c,(hl)
	inc c
	dec c
	jr z,cbt_1
	ld a,c
	and 0DFh		; (lower case too)
	sub 'A'
	cp 2
	jr c,cbt_1
	ld hl,m_sh_nodrv
	jp con_puts
cbt_1:	ld hl,0 		; that drive, its root
	call sh_ctx
	jp c,sh_err
	ld hl,m_bt_auto
	ld ix,sh_fcb1
	call f_open
	jp c,sh_err
cbt_go: ld hl,m_bt_auto 	; %0 = AUTOEXEC.BAT, no arguments
	ld (sh_word0),hl
	ld hl,m_bt_auto+12
	ld (sh_args),hl
	jp bat_start

m_bt_auto:  defm "AUTOEXEC.BAT"
	defb 0
