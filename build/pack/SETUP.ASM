; ==========================================================================
; SETUP.ASM - SETUP: find out what the terminal can do, and keep it.
;
;   1  a teletype: no screen codes
;   2  find the codes, one action at a time: for each of CLEAR, HOME, EOL,
;      EOS, UP, DOWN, RIGHT and LEFT it tries the codes terminals of the
;      time used (VT52, VT100/ANSI, ADM-3A, Heath H19, TeleVideo ...), with
;      a test you can see, until you say "yes"; if none works you can type
;      the bytes, or say it cannot.  So a terminal that mixes VT52 with
;      something else ends up with exactly the codes that work on it.  EOL
;      and EOS that do not erase from the cursor are tried again on whole
;      lines (some terminals' ESC K erases the line, ESC J from the line
;      down): kept so, with a flag (SCREEN WRAP 2 and 4).
;   3  type the codes in (not tried)
; Then for all three: the screen's rows (a ruler: read the number on the top
; line), its columns, and whether it wraps by itself after the last column;
; and what the Esc key sends.  A summary, and Y keeps it: SCREEN lines in
; A:\AUTOEXEC.BAT (which runs at every start; its other lines stay as they
; are, SCREEN lines from before are replaced).  Esc at any question, or N at
; the end, puts back the codes as they were (AUTOEXEC.BAT's SCREEN lines).
; (The SCREEN command, KERNEL/CMD/SCREEN.ASM, is what keeps them.)
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"

LBUF:	equ 0A000h		; the SCREEN lines, 0-terminated one after the other
FBUF:	equ 0A200h		; AUTOEXEC.BAT as it was (4 KB at most)
FMAX:	equ 1000h
OBUF:	equ 0B200h		; and as it will be
XMEM:	equ 0C800h		; memory for OS_EXEC (4 KB)
NACT:	equ 8			; the actions, as OS_SCREEN numbers them
CW:	equ 7			; CODES: per action, its length and up to 6 bytes

v_sp:	equ 9E00h		; word: SP at the start (Esc goes back from there)
v_flen: equ 9E02h		; word: AUTOEXEC.BAT's length before (0 = none)
v_lend: equ 9E04h		; word: the end of LBUF's lines
v_act:	equ 9E06h		; the action being found
v_cand: equ 9E08h		; word: the next code to try
v_rows: equ 9E0Ah
v_cols: equ 9E0Bh
v_wrap: equ 9E0Ch		; the flags (SCREEN WRAP): 1 wraps, 2 EOL is the whole line,
				; 4 EOS is from the start of the line
v_n:	equ 9E0Dh		; a counter
v_mode: equ 9E0Eh		; the choice: '1' to '3'
v_pass: equ 9E0Fh		; EOL, EOS: 0 tried from the cursor, 1 on whole lines
v_try:	equ 9E10h		; CW bytes: the code being tried
CODES:	equ 9E20h		; NACT x CW: the codes that work (length 0: none)
TBUF:	equ 9E60h		; 96 bytes: a command line for OS_EXEC
INBUF:	equ 9F00h		; a typed line
FCB:	equ 9FC0h		; 16 bytes

start:	ld (v_sp),sp
	call rdauto		; AUTOEXEC.BAT as it is (for Esc, and to keep its other lines)
	ret c
	xor a
	ld (v_wrap),a
	ld hl,CODES		; nothing found yet
	ld b,NACT*CW
st_0:	ld (hl),0
	inc hl
	djnz st_0
	ld hl,m_title
	call OS_PUTS
st_1:	call getkey
	cp '1'
	jr c,st_1
	cp '4'
	jr nc,st_1
	ld (v_mode),a
	call OS_PUTC
	call OS_CRLF
	ld hl,m_tty		; from no codes at all
	call exec
	ld a,(v_mode)
	cp '2'
	call z,find
	ld a,(v_mode)
	cp '3'
	call z,own
	call size		; rows, columns, wrap
	call esckey
	call summary
	ld hl,m_keep
	call OS_PUTS
	call yesno
	jp nz,abort1
	call mklines
	call use
	jp save

; ---------------------------------------------------------------- 2: find
find:	xor a
	ld (v_act),a
fd_act: xor a
	ld (v_pass),a
	ld a,(v_act)		; for each action: its codes to try
	cp NACT
	ret nc
fd_list:
	ld a,(v_act)
	call candlist
	ld (v_cand),hl
fd_next:
	ld hl,(v_cand)
	ld a,(hl)
	or a
	jr z,fd_own		; tried them all
	cp 0FFh 		; EOS needs HOME (to go back up): no HOME, no EOS
	jr z,fd_skip
	ld de,v_try
	ld c,a
	inc c
	ld b,0
	ldir
	ld (v_cand),hl
	call trial
	jr nz,fd_next
fd_keep:
	call keep		; this one works
	ld a,(v_pass)		; (on whole lines: noted in the flags)
	or a
	jr z,fd_done
	ld a,(v_act)		; EOL (2): flag 2, EOS (3): flag 4
	sub 1
	ld b,a
	ld a,1
fd_fl:	add a,a
	djnz fd_fl
	ld hl,v_wrap
	or (hl)
	ld (hl),a
fd_done:
	ld hl,v_act
	inc (hl)
	jr fd_act
fd_own: ld a,(v_pass)		; EOL and EOS: none erases from the cursor; do they
	or a			; erase whole lines?  (this terminal's may)
	jr nz,fd_own0
	ld a,(v_act)
	cp 2
	jr c,fd_own0
	cp 4
	jr nc,fd_own0
	ld a,1
	ld (v_pass),a
	ld hl,m_lines2
	call OS_PUTS
	call getkey
	jr fd_list
fd_own0:
	ld hl,m_none1		; none of them: type it, or it cannot
	call OS_PUTS
	call typed
	jr z,fd_cannot		; just Return
	jr c,fd_own
	call trial
	jr z,fd_keep
	jr fd_own
fd_cannot:
	xor a
	ld (v_try),a
	call setcode		; (no codes: SCREEN NAME alone)
	call keep
	jr fd_done
fd_skip:
	ld de,CODES+1*CW	; HOME found?
	ld a,(de)
	or a
	jr nz,fd_sk1
	ld hl,m_noeos
	call OS_PUTS
	jr fd_cannot
fd_sk1: inc hl			; yes: go on with the codes after the mark
	ld (v_cand),hl
	jp fd_next

trial:				; v_try in force for v_act, its test, and the question.
	call setcode		; Z = it works (Y)
	call prep
	ld a,(v_act)
	add a,a
	ld e,a
	ld d,0
	ld hl,tests
	ld a,(v_pass)
	or a
	jr z,tri_1
	ld hl,tests2
tri_1:	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call jphl
	jp yesno
jphl:	jp (hl)

keep:	ld a,(v_act)		; v_try -> CODES[v_act]
	call codesat
	ex de,hl
	ld hl,v_try
	ld bc,CW
	ldir
	ret

codesat:			; A = an action -> HL = its CODES entry
	ld l,a
	add a,a
	add a,a
	add a,a
	sub l			; x 7
	ld e,a
	ld d,0
	ld hl,CODES
	add hl,de
	ret

candlist:			; A = an action -> HL = its list of codes to try
	ld hl,cands
	or a
	ret z
	ld b,a
cl_1:	ld a,(hl)		; past one list: entries, then 0
	inc hl
	or a
	jr z,cl_2
	cp 0FFh
	jr z,cl_1
	ld e,a
	ld d,0
	add hl,de
	jr cl_1
cl_2:	djnz cl_1
	ret

prep:				; a clean screen for a test, and what is being tried
	ld a,(v_act)
	or a
	jr z,pr_1		; (CLEAR is the one being tried)
	ld a,(CODES)		; CLEAR known: it
	or a
	jr z,pr_1
	xor a
	call OS_SCREEN
	jr pr_2
pr_1:	call OS_CRLF
	call OS_CRLF
pr_2:	ld hl,m_try		; "SETUP: EOL, trying 1B 4B"
	call OS_PUTS
	ld a,(v_act)
	call actname
	call OS_PUTS
	ld hl,m_try2
	call OS_PUTS
	ld hl,v_try
	call showcode
	jp OS_CRLF

; the tests: each shows what the code does, and asks (Y/N is read after)
tests:	defw t_clear,t_home,t_eol,t_eos,t_up,t_down,t_right,t_left
tests2: defw t_clear,t_home,t_eoll,t_eosl	; EOL, EOS on whole lines

t_clear:
	ld hl,m_fill
	call OS_PUTS
	call getkey
	xor a
	call OS_SCREEN
	ld hl,m_qclear
	jp OS_PUTS
t_home: ld hl,m_lines
	call OS_PUTS
	ld a,1
	call OS_SCREEN
	ld hl,m_qhome
	jp OS_PUTS
t_eol:	ld hl,m_eol1
	call OS_PUTS
	ld a,2
	call OS_SCREEN
	call OS_CRLF
	ld hl,m_q12345
	jp OS_PUTS
t_eos:	ld hl,m_eos1
	call OS_PUTS
	ld a,1
	call OS_SCREEN
	ld hl,m_12345
	call OS_PUTS
	ld a,3
	call OS_SCREEN
	call OS_CRLF
	ld hl,m_qeos
	jp OS_PUTS
t_eoll: ld hl,m_eol2		; EOL at the start of a line: is the line gone?
	call OS_PUTS
	ld a,2
	call OS_SCREEN
	ld hl,m_12345
	call OS_PUTS
	call OS_CRLF
	ld hl,m_q12345
	jp OS_PUTS
t_eosl: ld hl,m_eos1		; EOS at the top: is everything gone?
	call OS_PUTS
	ld a,1
	call OS_SCREEN
	ld a,3
	call OS_SCREEN
	ld hl,m_12345
	call OS_PUTS
	call OS_CRLF
	ld hl,m_qeos
	jp OS_PUTS
t_up:	ld hl,m_up1
	call OS_PUTS
	ld a,4
	call OS_SCREEN
	ld hl,m_up2
	call OS_PUTS
	ld hl,m_qup
	jp OS_PUTS
t_down: ld hl,m_dn1
	call OS_PUTS
	ld a,5
	call OS_SCREEN
	ld hl,m_dn2
	call OS_PUTS
	ld hl,m_qdown
	jp OS_PUTS
t_right:
	ld hl,m_rt1
	call OS_PUTS
	ld b,3
tr_1:	ld a,6
	call OS_SCREEN
	djnz tr_1
	ld hl,m_rt2
	call OS_PUTS
	ld hl,m_qright
	jp OS_PUTS
t_left: ld hl,m_lf1
	call OS_PUTS
	ld b,2
tl_1:	ld a,7
	call OS_SCREEN
	djnz tl_1
	ld hl,m_lf2
	call OS_PUTS
	ld hl,m_qleft
	jp OS_PUTS

; ---------------------------------------------------------------- 3: own
own:	ld hl,m_own
	call OS_PUTS
	xor a
	ld (v_act),a
ow_1:	ld a,(v_act)
	cp NACT
	ret nc
	call actname
	call OS_PUTS
	ld hl,m_codes
	call OS_PUTS
	call typed
	jr c,ow_1		; (said why)
	jr nz,ow_2
	xor a			; Return: it cannot
	ld (v_try),a
ow_2:	call setcode
	call keep
	ld hl,v_act
	inc (hl)
	jr ow_1

typed:				; a typed line of hex bytes -> v_try.  Z = an empty
	ld hl,INBUF		; line; CF = not hex bytes (said so)
	ld b,30
	call OS_GETLINE
	ld hl,INBUF
	call skipsp
	or a
	ret z
	ld de,v_try+1
	ld c,0			; C = how many
ty_1:	call skipsp
	or a
	jr z,ty_end
	ld a,c
	cp 6
	jr nc,ty_bad
	call hexd		; one or two digits
	jr c,ty_bad
	ld b,a
	inc hl
	ld a,(hl)
	or a
	jr z,ty_one
	cp ' '
	jr z,ty_one
	call hexd
	jr c,ty_bad
	inc hl
	push af
	ld a,b
	add a,a
	add a,a
	add a,a
	add a,a
	ld b,a
	pop af
	or b
	ld b,a
	ld a,(hl)		; then a space or the end
	or a
	jr z,ty_one
	cp ' '
	jr nz,ty_bad
ty_one: ld a,b
	ld (de),a
	inc de
	inc c
	jr ty_1
ty_end: ld a,c
	ld (v_try),a
	or 1			; NZ, NC
	ret
ty_bad: ld hl,m_hexbad
	call OS_PUTS
	scf
	ret

hexd:	ld a,(hl)		; (HL) a hex digit -> A = 0..15.  CF = not one
	sub '0'
	ret c
	cp 10
	ccf
	ret nc
	ld a,(hl)
	and 0DFh
	sub 'A'
	ret c
	cp 6
	ccf
	ret c
	add a,10
	ret

skipsp: ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr skipsp

; ---------------------------------------------------------------- size
size:	ld a,(CODES)		; rows: a ruler 1-40 (cleared first, if it can)
	or a
	jr z,sz_0
	xor a
	call OS_SCREEN
sz_0:	ld hl,1
sz_1:	push hl
	call OS_DEC16
	call OS_CRLF
	pop hl
	inc hl
	ld a,l
	cp 41
	jr nz,sz_1
sz_q1:	ld hl,m_qrows		; the number on the top line: rows = 42 - it
	call OS_PUTS
	call number
	ld a,24
	jr z,sz_r
	ld a,e
	or a
	jr z,sz_q1
	cp 41
	jr nc,sz_q1
	ld b,a
	ld a,42
	sub b
sz_r:	ld (v_rows),a
	ld hl,m_rows1
	call OS_PUTS
	ld a,(v_rows)
	call dec8
	ld hl,m_rows2
	call OS_PUTS
sz_q2:	ld hl,m_qcols		; columns: asked
	call OS_PUTS
	call number
	ld a,80
	jr z,sz_c
	ld a,e
	cp 20
	jr c,sz_q2
sz_c:	ld (v_cols),a
	call prep0		; wraps by itself after the last column?
	ld a,(v_cols)
	ld b,a
sz_3:	ld a,'-'
	call OS_PUTC
	djnz sz_3
	call OS_CRLF
	ld hl,m_qwrap
	call OS_PUTS
	call yesno
	ld hl,v_wrap		; flag 1, the others kept
	res 0,(hl)
	jr nz,sz_w
	set 0,(hl)
sz_w:
	ld hl,m_rows		; in force now
	ld a,(v_rows)
	call setnum
	ld hl,m_cols
	ld a,(v_cols)
	call setnum
	ld hl,m_wrap
	ld a,(v_wrap)
	jp setnum

prep0:	ld a,(CODES)		; a clear screen if it can be had
	or a
	jp z,OS_CRLF
	xor a
	jp OS_SCREEN

number: 			; a typed number -> DE.  Z = just Return
	ld hl,INBUF
	ld b,10
	call OS_GETLINE
	ld hl,INBUF
	call skipsp
	or a
	ret z
	ld de,0
nb_1:	ld a,(hl)
	sub '0'
	jr c,nb_2
	cp 10
	jr nc,nb_2
	push hl
	ld h,d
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	add hl,hl
	ld e,a
	ld d,0
	add hl,de
	ex de,hl
	pop hl
	inc hl
	ld a,d			; (too big: 0, asked again)
	or a
	jr z,nb_1
	ld de,0
nb_2:	or 1			; NZ
	ret

; ---------------------------------------------------------------- Esc key
esckey: ld hl,m_esc
	call OS_PUTS
	call OS_GETC		; (Esc here is not "stop")
	cp 1Bh
	jr nz,ek_skip
	ld hl,m_esc1
	call OS_PUTS
	ld a,1Bh
ek_1:	call OS_HEX8		; the key's bytes: the first, and any that follow
	ld a,' '		; it within about 50 ms
	call OS_PUTC
	ld de,0
ek_2:	call OS_KBHIT
	jr nz,ek_3
	dec de
	ld a,d
	or e
	jr z,ek_4
	ld a,d			; (the loop takes long enough: 65536 x ~50 T)
	cp 0F0h
	jr nc,ek_2
	jr ek_4
ek_3:	call OS_GETC
	jr ek_1
ek_4:	ld hl,m_esc2		; (and time to read it)
	call OS_PUTS
	jp OS_GETC
ek_skip:
	jp OS_CRLF

; ---------------------------------------------------------------- summary
summary:
	call prep0
	ld hl,m_sum
	call OS_PUTS
	xor a
	ld (v_n),a
su_1:	ld a,(v_n)
	cp NACT
	jr nc,su_3
	ld hl,m_sp2
	call OS_PUTS
	ld a,(v_n)
	call actname
	call OS_PUTS
	ld b,7			; to column 9
	call strlen
	ld a,7
	sub c
	ld b,a
su_2:	ld a,' '
	call OS_PUTC
	djnz su_2
	ld a,(v_n)
	call codesat
	ld a,(hl)
	or a
	jr nz,su_c
	push hl
	ld hl,m_cannot
	call OS_PUTS
	pop hl
	jr su_e
su_c:	call showcode
	ld a,(v_n)		; EOL, EOS on whole lines: said so
	cp 2
	ld b,2
	ld hl,m_wline
	jr z,su_f
	cp 3
	ld b,4
	ld hl,m_wfrom
	jr nz,su_e
su_f:	ld a,(v_wrap)
	and b
	call nz,OS_PUTS
su_e:	call OS_CRLF
	ld hl,v_n
	inc (hl)
	jr su_1
su_3:	ld hl,m_sz1		; "  screen   26 rows, 80 columns, wraps"
	call OS_PUTS
	ld a,(v_rows)
	call dec8
	ld hl,m_sz2
	call OS_PUTS
	ld a,(v_cols)
	call dec8
	ld hl,m_sz3
	call OS_PUTS
	ld a,(v_wrap)
	and 1
	ld hl,m_wr1
	jr nz,su_4
	ld hl,m_wr0
su_4:	jp OS_PUTS

strlen: ld c,0			; HL = text -> C = its length (HL kept)
	push hl
sl_1:	ld a,(hl)
	or a
	jr z,sl_2
	inc c
	inc hl
	jr sl_1
sl_2:	pop hl
	ret

showcode:			; HL = a code (length, bytes): " 1B 48 1B 4A"
	ld b,(hl)
	inc b
	dec b
	ret z
sc_1:	inc hl
	ld a,(hl)
	call OS_HEX8
	ld a,' '
	call OS_PUTC
	djnz sc_1
	ret

dec8:	ld l,a			; A in decimal
	ld h,0
	jp OS_DEC16

; ---------------------------------------------------------------- the codes in force
setcode:			; "SCREEN NAME hh hh ..." for v_act, from v_try: run it
	ld de,TBUF
	ld hl,m_scr
	call cpy
	ld a,' '
	ld (de),a
	inc de
	ld a,(v_act)
	call actname
	call cpy
	ld hl,v_try
	ld b,(hl)
	inc b
	dec b
	jr z,se_2
se_1:	inc hl
	ld a,' '
	ld (de),a
	inc de
	ld a,(hl)
	call hex2
	djnz se_1
se_2:	xor a
	ld (de),a
	ld hl,TBUF
	jp exec

setnum: 			; HL = "SCREEN ROWS", A = n: "SCREEN ROWS n", run it
	push af
	ld de,TBUF
	call cpy
	ld a,' '
	ld (de),a
	inc de
	pop af
	call decs
	xor a
	ld (de),a
	ld hl,TBUF
	jp exec

cpy:	ld a,(hl)		; HL -> DE, without its 0 (DE: after it)
	or a
	ret z
	ld (de),a
	inc hl
	inc de
	jr cpy

hex2:	push af 		; A -> "hh" at DE
	rrca
	rrca
	rrca
	rrca
	call hx_1
	pop af
hx_1:	and 0Fh
	add a,'0'
	cp '9'+1
	jr c,hx_2
	add a,7
hx_2:	ld (de),a
	inc de
	ret

decs:	ld c,0			; A (0-255) -> decimal digits at DE
	ld b,100
	call ds_1
	ld b,10
	call ds_1
	add a,'0'
	ld (de),a
	inc de
	ret
ds_1:	ld h,0			; one digit: A / B; leading zeros left out (C = 1:
ds_2:	cp b			; a digit was written)
	jr c,ds_3
	sub b
	inc h
	jr ds_2
ds_3:	push af
	ld a,h
	or c
	jr z,ds_4
	ld a,h
	add a,'0'
	ld (de),a
	inc de
	ld c,1
ds_4:	pop af
	ret

actname:			; A = an action -> HL = its name
	ld hl,acts
	or a
	ret z
	ld b,a
an_1:	ld a,(hl)
	inc hl
	or a
	jr nz,an_1
	djnz an_1
	ret

exec:	ld de,XMEM		; HL = a command line: run it
	ld bc,1000h
	jp OS_EXEC

getkey: call OS_GETC		; a key; Esc: put everything back and stop
	cp 1Bh
	ret nz
abort:	ld hl,m_esc0
	call OS_PUTS
abort1: ld sp,(v_sp)		; (back at the start's stack)
	ld hl,m_tty		; the codes from before: AUTOEXEC.BAT's SCREEN lines
	call exec		; (on the size as at the start: 24 x 80, no wrap)
	ld hl,m_rows
	ld a,24
	call setnum
	ld hl,m_cols
	ld a,80
	call setnum
	ld hl,m_wrap
	xor a
	call setnum
	ld hl,FBUF
ab_1:	ld a,(hl)
	or a
	jr z,ab_9
	call isscr
	jr nz,ab_3
	ld de,TBUF		; this one: without spaces, @ and its CR LF
ab_2:	ld a,(hl)
	cp ' '
	jr z,ab_2a
	cp '@'
	jr nz,ab_2b
ab_2a:	inc hl
	jr ab_2
ab_2b:	ld a,(hl)
	or a
	jr z,ab_2c
	cp 13
	jr z,ab_2c
	cp 10
	jr z,ab_2c
	ld (de),a
	inc hl
	inc de
	jr ab_2b
ab_2c:	xor a
	ld (de),a
	push hl
	ld hl,TBUF
	call exec
	pop hl
ab_3:	ld a,(hl)		; to the next line
	or a
	jr z,ab_9
	inc hl
	cp 10
	jr nz,ab_3
	jr ab_1
ab_9:	ld hl,m_nochg
	call OS_PUTS
	jp OS_HOME

yesno:	call getkey		; Z = Y
	and 0DFh
	cp 'Y'
	jr z,yn_1
	cp 'N'
	jr nz,yesno
yn_1:	push af
	call OS_PUTC
	call OS_CRLF
	pop af
	cp 'Y'
	ret

; ---------------------------------------------------------------- AUTOEXEC.BAT
rdauto: 			; AUTOEXEC.BAT -> FBUF, 0 at its end.  CF = too big (said)
	ld hl,0
	ld (v_flen),hl
	call autoname
	jr c,ra_none
	ld ix,FCB
	call OS_OPEN
	jr c,ra_none		; not there yet
	ld de,FBUF
	ld bc,FMAX
	ld ix,FCB
	call OS_READ
	jr c,ra_err
	ld a,b
	cp FMAX>>8
	jr nc,ra_big
	ld (v_flen),bc
ra_none:
	ld hl,FBUF
	ld bc,(v_flen)
	add hl,bc
	ld (hl),0
	or a
	ret
ra_big: ld hl,m_big
	call OS_PUTS
	scf
	ret
ra_err: call OS_ERRMSG
	call OS_PUTS
	call OS_CRLF
	scf
	ret

mklines:			; LBUF: a SCREEN line for each action, ROWS, COLS, WRAP
	ld hl,LBUF
	ld (hl),0
	ld (v_lend),hl
	xor a
	ld (v_n),a
ml_1:	ld a,(v_n)
	cp NACT
	jr nc,ml_3
	call codesat
	ld a,(hl)
	or a
	jr z,ml_2		; none: no line (SCREEN TTY leaves it so)
	push hl
	ld a,(v_n)
	call actname
	call ln_begin
	pop hl
	ld b,(hl)
ml_c:	inc hl
	ld a,(hl)
	call ln_hex
	djnz ml_c
	call ln_end
ml_2:	ld hl,v_n
	inc (hl)
	jr ml_1
ml_3:	ld hl,m_nrows
	ld a,(v_rows)
	call ml_num
	ld hl,m_ncols
	ld a,(v_cols)
	call ml_num
	ld hl,m_nwrap
	ld a,(v_wrap)
ml_num: push af 		; "@SCREEN NAME n"
	call ln_begin
	ld a,' '
	call ln_ch
	pop af
	ld de,INBUF
	push de
	call decs
	xor a
	ld (de),a
	pop hl
ml_n1:	ld a,(hl)
	or a
	jp z,ln_end
	call ln_ch
	inc hl
	jr ml_n1

save:	ld hl,FBUF		; AUTOEXEC.BAT without its old SCREEN lines, then ours
	ld de,OBUF
s_line: ld a,(hl)
	or a
	jr z,s_ours
	call isscr		; Z = a SCREEN line: dropped
	push af
s_ch:	ld a,(hl)		; to its end (with its CR LF)
	or a
	jr z,s_eol
	inc hl
	cp 10
	jr z,s_eol1
	pop af
	push af
	jr z,s_ch
	dec hl
	ld a,(hl)
	inc hl
	ld (de),a
	inc de
	jr s_ch
s_eol1: pop af
	jr z,s_line
	ld a,10
	ld (de),a
	inc de
	jr s_line
s_eol:	pop af			; the file ended inside a line: end it
	jr z,s_ours
	ld a,13
	ld (de),a
	inc de
	ld a,10
	ld (de),a
	inc de
s_ours: ld hl,LBUF		; then our lines, each with CR LF
s_o1:	ld a,(hl)
	or a
	jr z,s_write
s_o2:	ld a,(hl)
	inc hl
	or a
	jr z,s_o3
	ld (de),a
	inc de
	jr s_o2
s_o3:	ld a,13
	ld (de),a
	inc de
	ld a,10
	ld (de),a
	inc de
	jr s_o1
s_write:
	ex de,hl		; BC = the new length (there is always a line: ROWS)
	ld de,OBUF
	or a
	sbc hl,de
	ld b,h
	ld c,l
	push bc
	call autoname
	ld ix,FCB
	call OS_CREATE
	pop bc
	jr c,s_err
	ld de,OBUF
	ld ix,FCB
	call OS_WRITE
	jr c,s_err
	ld ix,FCB
	call OS_CLOSE
	jr c,s_err
	ld hl,m_saved
	call OS_PUTS
	jp OS_HOME
s_err:	call OS_ERRMSG
	call OS_PUTS
	call OS_CRLF
	ld a,1
	call OS_STATUS
	jp OS_HOME

autoname:			; A:\AUTOEXEC.BAT (which runs at start) -> HL (name part)
	ld hl,m_auto
	jp OS_RESOLVE

use:	ld hl,m_tty		; SCREEN TTY, then each line of LBUF
	call exec
	ld hl,LBUF
us_1:	ld a,(hl)
	or a
	ret z
	push hl
	inc hl			; (without its @)
	call exec
	pop hl
us_2:	ld a,(hl)
	inc hl
	or a
	jr nz,us_2
	jr us_1

isscr:	push de 		; HL = a line: Z = it is a SCREEN line
	push hl 		; ([spaces][@]SCREEN ..., any case)
	dec hl
is_0:	inc hl
	ld a,(hl)
	cp ' '
	jr z,is_0
	cp '@'
	jr z,is_0
	ld de,m_scr
is_1:	ld a,(de)
	or a
	jr z,is_2
	ld c,a
	ld a,(hl)
	and 0DFh
	cp c
	inc hl
	inc de
	jr z,is_1
	pop hl
	pop de
	ret			; NZ
is_2:	ld a,(hl)
	cp ' '
	pop hl
	pop de
	ret

; the lines in LBUF: ln_begin HL = an action's name ("@SCREEN NAME"), ln_hex
; A = a byte (" hh"), ln_ch A = a character, ln_end.  HL, B kept.
ln_begin:
	push hl
	ld de,m_atscr
	ld hl,(v_lend)
lb_1:	ld a,(de)
	or a
	jr z,lb_2
	ld (hl),a
	inc hl
	inc de
	jr lb_1
lb_2:	ld (hl),' '
	inc hl
	ex de,hl
	pop hl
	push hl
lb_3:	ld a,(hl)
	or a
	jr z,lb_4
	ld (de),a
	inc hl
	inc de
	jr lb_3
lb_4:	ld (v_lend),de
	pop hl
	ret
ln_hex: push af
	ld a,' '
	call ln_ch
	pop af
	push af
	rrca
	rrca
	rrca
	rrca
	call ln_dig
	pop af
ln_dig: and 0Fh
	add a,'0'
	cp '9'+1
	jr c,ln_ch
	add a,7
ln_ch:	push hl
	ld hl,(v_lend)
	ld (hl),a
	inc hl
	ld (v_lend),hl
	pop hl
	ret
ln_end: push hl
	ld hl,(v_lend)
	ld (hl),0
	inc hl
	ld (hl),0		; (the end of all of them, until the next)
	ld (v_lend),hl
	pop hl
	ret

; ---------------------------------------------------------------- the codes to try
; For each action, in OS_SCREEN's order: entries (length, bytes), then 0.
; FFh in EOS's list: "only if HOME was found" (its test goes back up).
; The ones that do something else on other terminals come last: 0Ch (form
; feed) clears many screens, so as RIGHT (ADM-3A) it is tried after the others.
cands:	defb 4,1Bh,48h,1Bh,4Ah		; CLEAR: VT52 ESC H ESC J
	defb 2,1Bh,45h			;   Heath H19 / Zenith, Atari VT52: ESC E
	defb 1,1Ah			;   ADM-3A, Kaypro: Ctrl-Z
	defb 2,1Bh,2Ah			;   TeleVideo, ADM-31: ESC *
	defb 6,1Bh,5Bh,48h,1Bh,5Bh,4Ah	;   VT100 / ANSI: ESC [H ESC [J
	defb 1,0Ch			;   form feed
	defb 0
	defb 2,1Bh,48h			; HOME: VT52 ESC H
	defb 3,1Bh,5Bh,48h		;   VT100: ESC [H
	defb 1,1Eh			;   ADM-3A, TeleVideo: Ctrl-^
	defb 0
	defb 2,1Bh,4Bh			; EOL: VT52 ESC K
	defb 3,1Bh,5Bh,4Bh		;   VT100: ESC [K
	defb 2,1Bh,54h			;   TeleVideo: ESC T
	defb 0
	defb 0FFh			; EOS (needs HOME):
	defb 2,1Bh,4Ah			;   VT52 ESC J
	defb 3,1Bh,5Bh,4Ah		;   VT100: ESC [J
	defb 0
	defb 2,1Bh,41h			; UP: VT52 ESC A
	defb 3,1Bh,5Bh,41h		;   VT100: ESC [A
	defb 1,0Bh			;   ADM-3A, TeleVideo: Ctrl-K
	defb 0
	defb 2,1Bh,42h			; DOWN: VT52 ESC B
	defb 3,1Bh,5Bh,42h		;   VT100: ESC [B
	defb 1,0Ah			;   a line feed that keeps the column
	defb 0
	defb 2,1Bh,43h			; RIGHT: VT52 ESC C
	defb 3,1Bh,5Bh,43h		;   VT100: ESC [C
	defb 1,0Ch			;   ADM-3A, TeleVideo: Ctrl-L
	defb 0
	defb 2,1Bh,44h			; LEFT: VT52 ESC D
	defb 3,1Bh,5Bh,44h		;   VT100: ESC [D
	defb 1,08h			;   backspace
	defb 0

acts:	defm "CLEAR"
	defb 0
	defm "HOME"
	defb 0
	defm "EOL"
	defb 0
	defm "EOS"
	defb 0
	defm "UP"
	defb 0
	defm "DOWN"
	defb 0
	defm "RIGHT"
	defb 0
	defm "LEFT"
	defb 0

m_atscr: defm "@"		; (@: the line is not shown when it runs)
m_scr:	defm "SCREEN"
	defb 0
m_tty:	defm "SCREEN TTY"
	defb 0
m_rows: defm "SCREEN "
m_nrows: defm "ROWS"
	defb 0
m_cols: defm "SCREEN "
m_ncols: defm "COLS"
	defb 0
m_wrap: defm "SCREEN "
m_nwrap: defm "WRAP"
	defb 0
m_auto: defm "A:\\AUTOEXEC.BAT"
	defb 0
m_title:
	defm "ampDOS terminal setup.  Esc at any question: everything stays as it was."
	defb 13,10,13,10
	defm "  1  a teletype, or not known: no screen codes"
	defb 13,10
	defm "  2  find this terminal's codes, one at a time (VT52, VT100, ADM-3A,"
	defb 13,10
	defm "     H19, TeleVideo ... are tried, and you say which work)"
	defb 13,10
	defm "  3  type the codes in"
	defb 13,10
	defm "1-3: "
	defb 0
m_try:	defm "SETUP: "
	defb 0
m_try2: defm ", trying "
	defb 0
m_fill: defm "This screen should be cleared, with only one line left at the top."
	defb 13,10
	defm "...................................................................."
	defb 13,10
	defm "...................................................................."
	defb 13,10
	defm "Press a key"
	defb 0
m_qclear:
	defm "Is the screen clear, with this line at the top? (Y/N) "
	defb 0
m_lines: defm "line 1"
	defb 13,10
	defm "line 2"
	defb 13,10
	defm "line 3"
	defb 13,10,0
m_qhome:
	defm "* Is this line the top one on the screen (over SETUP: ...)? (Y/N) "
	defb 0
m_eol1: defm "12345XXXXXXXXXXXXXXX"
	defb 13
m_12345: defm "12345"
	defb 0
m_q12345:
	defm "Does the line above say only 12345? (Y/N) "
	defb 0
m_eos1: defm "XXXXXXXXXXXXXXXXXXXX"
	defb 13,10
	defm "XXXXXXXXXXXXXXXXXXXX"
	defb 13,10
	defm "XXXXXXXXXXXXXXXXXXXX"
	defb 0
m_qeos: defm "Is 12345 all there is above this line (no X left)? (Y/N) "
	defb 0
m_eol2: defm "XXXXXXXXXXXXXXXXXXXX"
	defb 13,0
m_lines2:
	defm "None erases from the cursor.  Some terminals erase whole lines instead:"
	defb 13,10
	defm "the same codes again, tried that way.  Press a key "
	defb 0
m_wline:
	defm " (the whole line: use it at the line's start)"
	defb 0
m_wfrom:
	defm " (from the start of the line)"
	defb 0
m_up1:	defm "abcde"
	defb 13,10,0
m_up2:	defm "ABC"
	defb 13,10,13,10,0
m_qup:	defm "Does it say ABCde two lines up, with an empty line under it? (Y/N) "
	defb 0
m_dn1:	defm "1234"
	defb 0
m_dn2:	defm "5"
	defb 13,10,0
m_qdown:
	defm "Is the 5 one line under the 4, just to its right? (Y/N) "
	defb 0
m_rt1:	defm "123"
	defb 13,0
m_rt2:	defm "456"
	defb 13,10,0
m_qright:
	defm "Does the line above say 123456? (Y/N) "
	defb 0
m_lf1:	defm "1234567XX"
	defb 0
m_lf2:	defm "89"
	defb 13,10,0
m_qleft:
	defm "Does the line above say 123456789? (Y/N) "
	defb 0
m_none1:
	defm "None of those.  Type its bytes in hex (ESC is 1B), or just Return if"
	defb 13,10
	defm "this terminal cannot do it: "
	defb 0
m_noeos:
	defm "(EOS is tried with HOME, which this terminal does not have: none.)"
	defb 13,10,0
m_own:	defm "Type each one's bytes in hex (ESC is 1B), e.g. 1B 45, or just Return if"
	defb 13,10
	defm "the terminal cannot."
	defb 13,10,0
m_codes:
	defm ": "
	defb 0
m_hexbad:
	defm "(hex bytes, at most 6, e.g. 1B 45)"
	defb 13,10,0
m_qrows:
	defm "The number on the TOP line of the screen (Return: 24 rows): "
	defb 0
m_rows1:
	defm "So the screen has "
	defb 0
m_rows2:
	defm " rows."
	defb 13,10,0
m_qcols:
	defm "How many columns (characters on a line)? (Return: 80) "
	defb 0
m_qwrap:
	defm "Is there an empty line between the dashes and this line? (Y/N) "
	defb 0
m_esc:	defm "Press Esc, to see what your Esc key sends (another key: skip it) "
	defb 0
m_esc1: defm "It sends: "
	defb 0
m_esc2: defm " (ampDOS programs look for 1B)"
	defb 13,10
	defm "Press a key to go on "
	defb 0
m_sum:	defm "What SETUP found:"
	defb 13,10,0
m_sp2:	defm "  "
	defb 0
m_cannot:
	defm "(cannot)"
	defb 0
m_sz1:	defm "  screen   "
	defb 0
m_sz2:	defm " rows, "
	defb 0
m_sz3:	defm " columns, "
	defb 0
m_wr1:	defm "wraps by itself after the last column"
	defb 13,10,0
m_wr0:	defm "does not wrap by itself"
	defb 13,10,0
m_keep: defm "Keep this, in A:\\AUTOEXEC.BAT? (Y/N) "
	defb 0
m_saved:
	defm "Saved in A:\\AUTOEXEC.BAT: it sets them again at every start."
	defb 13,10,0
m_esc0: defm "Esc"
	defb 13,10,0
m_nochg:
	defm "Nothing changed."
	defb 13,10,0
m_big:	defm "\\AUTOEXEC.BAT is too big for SETUP (4 KB): nothing changed."
	defb 13,10,0
