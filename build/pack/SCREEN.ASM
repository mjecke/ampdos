; ==========================================================================
; SCREEN.ASM - the terminal's screen codes: SCREEN, and OS_SCREEN.
;
;   SCREEN action [hh hh ...]   the bytes the terminal takes for that action
;                               (up to 6, hex); none: it has no such thing
;   SCREEN TTY                  no codes at all: a teletype (how ampDOS starts)
;   SCREEN ROWS n / COLS n      its size (24 x 80 at the start)
;   SCREEN WRAP n               the terminal's ways, added up: 1 it goes to the
;                               next line by itself after the last column (a
;                               full line then needs no CR LF), 2 its EOL
;                               erases the whole line, 4 its EOS erases from
;                               the start of the line down (SETUP finds them)
;
; The actions (OS_SCREEN's numbers): CLEAR 0 (clear the screen, cursor home),
; HOME 1, EOL 2 (erase to the end of the line), EOS 3 (to the end of the
; screen), UP 4, DOWN 5, RIGHT 6, LEFT 7.  For a VT52:
;   SCREEN CLEAR 1B 48 1B 4A    SCREEN HOME 1B 48    SCREEN UP 1B 41 ...
; SETUP.BIN asks about the terminal and puts such lines in AUTOEXEC.BAT, which
; runs at every start.  Programs ask for an action (OS_SCREEN), never send codes
; themselves, so they work on any terminal: CLEAR always works (on a teletype
; as empty lines); the others say "cannot" (CF), and a program that needs them
; can say so.
;
;   scr_do   A = action: send its codes.  CF = this terminal has none.
;            A = 8: L = rows, H = columns, A = the WRAP flags; no codes sent
; ==========================================================================

SCR_N:	equ 8			; actions
SCR_W:	equ 6			; bytes for each (SCRTAB, KERNEL/INC/RAM.INC)

scr_do: cp 8			; 8: the size, not codes
	jr nz,scd_0
	ld hl,(scr_rows)
	ld a,(scr_wrap)
	or a
	ret
scd_0:	push hl
	push de
	push bc
	ld c,a
	cp SCR_N
	jr nc,scd_no
	call scr_slot
	ld b,SCR_W
	ld a,(hl)
	or a
	jr z,scd_none
scd_1:	 ld a,(hl)		 ; its bytes, up to 6 (ended early by a 0)
	or a
	jr z,scd_ok
	call con_putc
	inc hl
	djnz scd_1
scd_ok:  or a
scd_end: pop bc
	pop de
	pop hl
	ret
scd_none:
	ld a,c			; no codes: CLEAR still clears, with empty lines
	or a
	jr nz,scd_no
	ld a,(scr_rows)
	ld b,a
scd_2:	 call con_crlf
	djnz scd_2
	jr scd_ok
scd_no:  scf
	jr scd_end

scr_slot:			; A = action -> HL = its 6 bytes in SCRTAB
	ld l,a
	add a,a
	add a,l
	add a,a
	ld e,a
	ld d,0
	ld hl,SCRTAB
	add hl,de
	ret

cmd_screen:
	ld hl,(sh_args)
	call sh_wordup		; the action's name -> sh_cmd
	push hl
	ld hl,scr_names
	call sh_lookt		; HL = its number
	ld a,l
	pop hl
	jr c,cs_use
	cp SCR_N+1		; ROWS, COLS, WRAP: a number
	jr nc,cs_num
	push hl
	cp SCR_N
	ld hl,SCRTAB		; TTY: every action ...
	ld b,SCR_N*SCR_W
	jr nc,cs_0
	call scr_slot		; ... or this one
	ld b,SCR_W
cs_0:	push hl 		; none to begin with
cs_1:	ld (hl),0
	inc hl
	djnz cs_1
	pop de			; DE = where its bytes go
	pop hl
	ld b,SCR_W+1
cs_2:	call sh_skipsp		; the bytes
	ld a,(hl)
	or a
	ret z
	dec b
	jr z,cs_use		; more than 6
	push de
	call cu_hexw
	ld a,d
	ld c,e
	pop de
	jr c,cs_use
	or a
	jr nz,cs_use		; (more than FF)
	ld a,c
	ld (de),a
	inc de
	jr cs_2
cs_num: sub SCR_N+1		; scr_rows + 0, 1, 2
	ld e,a
	ld d,0
	push de
	call sh_skipsp
	call cu_num		; DE = n
	pop bc
	jr c,cs_use
	ld a,d			; 0 .. 255 (rows, columns: 1 at least)
	or a
	jr nz,cs_use
	ld hl,scr_rows
	add hl,bc
	ld a,c
	cp 2
	ld a,e
	jr z,cs_n1
	or a
	jr z,cs_use
cs_n1:	ld (hl),a
	ret
cs_use: ld hl,m_scr_use
	jp sh_usage

scr_names:
	defm "CLEAR"
	defb 0
	defw 0
	defm "HOME"
	defb 0
	defw 1
	defm "EOL"
	defb 0
	defw 2
	defm "EOS"
	defb 0
	defw 3
	defm "UP"
	defb 0
	defw 4
	defm "DOWN"
	defb 0
	defw 5
	defm "RIGHT"
	defb 0
	defw 6
	defm "LEFT"
	defb 0
	defw 7
	defm "TTY"
	defb 0
	defw 8
	defm "ROWS"
	defb 0
	defw 9
	defm "COLS"
	defb 0
	defw 10
	defm "WRAP"
	defb 0
	defw 11
	defb 0

m_scr_use:
	defm "SCREEN TTY | ROWS n | COLS n | WRAP n | CLEAR HOME EOL EOS UP DOWN RIGHT LEFT hh .."
	defb 13,10,0
