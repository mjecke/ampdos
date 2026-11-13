; ==========================================================================
; RUN.ASM - run a program from the disk.
;
;   RUN NAME [args]     or just     NAME [args]      (B:NAME, \BIN\NAME ... work too)
; NAME without an extension means NAME.BIN (then NAME.BAT); not here, it is
; looked for in the PATH directories (A:\BIN at the start; PATH changes them).	The file is loaded at TPA
; (8000h, up to TPA_TOP) and CALLed with HL = the arguments.  When it
; returns (RET, or JP OS_WARM), sh_cleanup makes the OS whole again.
; Nothing a program wrote without closing its files survives that.
; ==========================================================================

cmd_run:
	call sh_need1		; the name is the first argument
	ret c
	ld (sh_word),hl
	call sh_skipword	; its arguments follow
	call sh_skipsp
	ld (sh_args),hl
	jr cr_go

cmd_runword:			; the command word itself names the program
cr_go:	call sh_noexec		; (not while one is running: OS_EXEC)
	ret c
	ld hl,(sh_word) 	; the name as typed
	ld (sh_word0),hl
	xor a			; NAME.BIN first, then NAME.BAT
	ld (sh_xbat),a
cr_try: call sh_mount
	ret c
	ld hl,(sh_word0)	; [d:][path\]name: go where it is
	call sh_resolve
	jp c,sh_err
	ld (sh_word),hl
	call cr_name		; sh_name = the name, with .BIN (.BAT) if it had no dot
	ld hl,sh_name
	ld ix,sh_fcb1
	call f_open
	jr nc,cr_open
	cp FS_ENAME		; (a name too long for 8.3: no such program either)
	jr z,cr_nf
	cp FS_ENOTF
	jp nz,sh_err
cr_nf:	call cr_bin		; not here: in A:\BIN?
	jr nc,cr_open
	ld a,(sh_dot)		; no NAME.BIN: NAME.BAT? (if no extension was typed)
	ld hl,sh_xbat
	or (hl)
	ld (hl),1
	jr z,cr_try
	call sh_fail
	ld hl,m_cr_what 	; "unknown command"
	call con_puts
	ld hl,(sh_word0)
	call sh_skipword	; (the typed word: up to the space)
	ld (hl),0
	ld hl,(sh_word0)
	call con_puts
	jp con_crlf
cr_open:
	call cr_isbat		; a batch file: its lines run next
	jp z,bat_start
	ld de,m_ext_bin 	; and nothing but NAME.BIN runs as a program
	call cr_isext		; (not AMPDOS.SYS, the OS itself, or a text file)
	jr z,cr_prog
	call sh_fail
	ld hl,m_cr_notp
	jp con_puts
cr_prog:
	ld a,(sh_fcb1+FCB_SIZE+2)	; at most TPA_TOP - TPA bytes
	ld hl,sh_fcb1+FCB_SIZE+3
	or (hl)
	jr nz,cr_big
	ld hl,(sh_fcb1+FCB_SIZE)
	ld de,TPA_TOP-TPA+1
	or a
	sbc hl,de
	jr nc,cr_big
	ld ix,sh_fcb1
	ld de,TPA
	ld bc,TPA_TOP-TPA
	call f_read
	jp c,sh_err
	call sh_mount		; back home: the program starts in the current
	ret c			; drive and directory
	ld hl,(sh_args) 	; go: HL = the arguments
	call TPA
	jp sh_cleanup		; it came back
cr_big: ld hl,m_cr_big
	jp con_puts

cr_bin: 			; look for the program in the PATH directories too,
	ld hl,(sh_word0)	; if its name was typed without a drive or path.
crb_1:	ld a,(hl)		; NC = found and opened
	or a
	jr z,crb_2
	cp ' '
	jr z,crb_2
	cp ':'
	scf
	ret z
	cp 5Ch
	scf
	ret z
	cp '/'
	scf
	ret z
	inc hl
	jr crb_1
crb_2:	ld hl,PATHBUF
	ld (sh_pnext),hl
crb_dir:			; the next directory: sh_pbuf = "B:\TOOLS" ...
	ld hl,(sh_pnext)
	ld a,(hl)
	or a
	scf
	ret z			; no more
	ld de,sh_pbuf
crb_3:	ld a,(hl)
	or a
	jr z,crb_4
	inc hl
	cp ';'
	jr z,crb_4
	ld (de),a
	inc de
	jr crb_3
crb_4:	ld (sh_pnext),hl
	ld hl,sh_pbuf		; (";;": an empty one, skip it)
	or a
	sbc hl,de
	jr z,crb_dir
	dec de			; ... + "\" unless it ends with one (or is "B:")
	ld a,(de)
	inc de
	cp 5Ch
	jr z,crb_5
	cp ':'
	jr z,crb_5
	ld a,5Ch
	ld (de),a
	inc de
crb_5:	ld hl,(sh_word0)	; ... + the name
	ld b,13
crb_6:	ld a,(hl)
	or a
	jr z,crb_7
	cp ' '
	jr z,crb_7
	ld (de),a
	inc hl
	inc de
	djnz crb_6
crb_7:	xor a
	ld (de),a
	ld hl,sh_pbuf
	call sh_resolve
	jr c,crb_dir		; no such directory (or disk): the next one
	ld (sh_word),hl
	call cr_name
	ld hl,sh_name
	ld ix,sh_fcb1
	call f_open
	ret nc
	jr crb_dir

; ---------------------------------------------------------------- PATH
; PATH                show it        PATH dir;dir...   set it (at most 63 characters)
; PATH ;  (or PATH=)  none	     PATH=dir;...      the same as PATH dir;...
cmd_path:
	ld hl,(sh_args)
	ld a,(hl)
	or a
	jr z,cpa_show
	cp '='
	jr nz,cpa_1
	inc hl
cpa_1:	push hl 		; how long?  (up to a space or the end)
	call sh_skipword
	pop de
	or a
	sbc hl,de
	ld a,h
	or a
	jr nz,cpa_long
	ld a,l
	cp PATHLEN
	jr nc,cpa_long
	ld c,l
	ld b,0
	ex de,hl
	ld de,PATHBUF
	ld a,c
	or a
	jr z,cpa_2
	ldir
cpa_2:	xor a
	ld (de),a
	ld hl,PATHBUF		; upper case; ";" alone: no PATH
cpa_3:	ld a,(hl)
	or a
	jr z,cpa_4
	call sh_upper
	ld (hl),a
	inc hl
	jr cpa_3
cpa_4:	ld hl,PATHBUF
	ld a,(hl)
	cp ';'
	ret nz
	inc hl
	ld a,(hl)
	or a
	ret nz
	ld (PATHBUF),a
	ret
cpa_long:
	call sh_fail
	ld hl,m_cr_plong
	jp con_puts
cpa_show:
	ld hl,m_cr_path
	call con_puts
	ld hl,PATHBUF
	call con_puts
	jp con_crlf

m_cr_path:  defm "PATH="
	defb 0
m_cr_plong: defm "PATH: 63 characters at most"
	defb 13,10,0
m_cr_defpath: defm "A:\\BIN"
	defb 0

cr_name:			; sh_name = word at (sh_word), ".BIN" added if no dot
	ld hl,(sh_word)
	ld de,sh_name
	ld b,12
	ld c,0			; C = 1 once a dot is seen
crn_1:	ld a,(hl)
	or a
	jr z,crn_2
	cp ' '
	jr z,crn_2
	cp '.'
	jr nz,crn_d
	ld c,1
crn_d:	ld (de),a
	inc hl
	inc de
	djnz crn_1
crn_2:	ld a,c
	ld (sh_dot),a
	or a
	jr nz,crn_3
	ld hl,m_cr_bin
	ld a,(sh_xbat)
	or a
	jr z,crn_e
	ld hl,m_cr_bat
crn_e:	ld bc,4
	ldir
crn_3:	xor a
	ld (de),a
	ret

m_cr_bin:  defm ".BIN"
m_cr_what: defm "unknown command or program: "
	defb 0
m_cr_big:  defm "too big for the TPA"
	defb 13,10,0
