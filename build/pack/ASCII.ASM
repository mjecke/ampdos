; ==========================================================================
; ASCII.ASM - ASCII.BIN: the character table, or what one character is.
;
;   ASCII          0-127: 16 lines of 8 columns, "41 A", control codes by name
;   ASCII /D       the same in decimal
;   ASCII /H       128-255, sent to the terminal as they are (what it shows
;                  for them is its own: graphics, accents, or nothing)
;   ASCII c        one character: ASCII A  ->  A = 65 = 41h = 01000001b
;   ASCII 65       a number (decimal, or hex with h: 41h) -> its character
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h
P_NAME: equ 9010h
v_dec:	equ 9020h		; 1 = /D
v_base: equ 9021h		; 0 or 128
v_row:	equ 9022h
v_w:	equ 9030h		; 32 bytes: the argument

start:	xor a
	ld (v_dec),a
	ld (v_base),a
	ld de,v_w
	call pl_word
	jr z,table
	ld a,(v_w)
	cp '/'
	jp nz,one
	ld a,(v_w+2)
	or a
	jp nz,one		; ("/x" with more after it: a word, not a switch)
	ld a,(v_w+1)
	call pl_upper
	cp 'D'
	jr nz,st_1
	ld a,1
	ld (v_dec),a
	jr table
st_1:	cp 'H'
	jp nz,one
	ld a,128
	ld (v_base),a

table:	ld hl,m_head		; the column heads
	ld a,(v_dec)
	or a
	jr z,tb_0
	ld hl,m_headd
tb_0:	ld a,(v_base)
	or a
	jr z,tb_0a
	ld hl,m_headh
tb_0a:	call OS_PUTS
	xor a
	ld (v_row),a
tb_1:	ld a,(v_dec)		; a line: "x0  " then 8 cells
	or a
	jr nz,tb_1a
	ld a,(v_row)
	call hexdig
	ld a,' '
	call OS_PUTC
	call OS_PUTC
	call OS_PUTC
tb_1a:	ld b,0
tb_2:	push bc
	ld a,b			; the code: base + column x 16 + row
	add a,a
	add a,a
	add a,a
	add a,a
	ld c,a
	ld a,(v_row)
	add a,c
	ld c,a
	ld a,(v_base)
	add a,c
	call cell
	pop bc
	inc b
	ld a,b
	cp 8
	jr nz,tb_2
	call OS_CRLF
	ld a,(v_row)
	inc a
	ld (v_row),a
	cp 16
	jr nz,tb_1
	ret

cell:				; A = a code: "41 A     " (9 wide)
	push af
	ld a,(v_dec)
	or a
	jr nz,ce_d
	pop af
	push af
	call OS_HEX8
	jr ce_1
ce_d:	pop af			; decimal: "065 A    "
	push af
	call dec3
ce_1:	ld a,' '
	call OS_PUTC
	pop af
	call name		; HL = its name, or 0: the character itself
	ld b,6			; (6 wide; in decimal 5, for the wider number)
	ld a,(v_dec)
	or a
	jr z,ce_w
	dec b
ce_w:
	ld a,h
	or l
	jr z,ce_ch
ce_n:	ld a,(hl)
	or a
	jr z,ce_sp
	call OS_PUTC
	inc hl
	dec b
	jr ce_n
ce_ch:	ld a,c
	call OS_PUTC
	dec b
ce_sp:	ld a,' '
	call OS_PUTC
	djnz ce_sp
	ret

name:				; A = a code -> HL = its name (control codes, space,
	ld c,a			; DEL), else 0 (C = the code)
	cp 20h
	jr c,nm_ctl
	jr z,nm_sp
	cp 7Fh
	jr z,nm_del
	cp 80h			; 80-9F: C1 control codes on some terminals: not sent
	jr c,nm_no
	cp 0A0h
	jr c,nm_c1
nm_no:	ld hl,0
	ret
nm_c1:	ld hl,m_c1
	ret
nm_ctl: ld l,a			; 4 bytes a name
	ld h,0
	add hl,hl
	add hl,hl
	ld de,ctl
	add hl,de
	ret
nm_sp:	ld hl,m_sp
	ret
nm_del: ld hl,m_del
	ret

one:				; one character, or a number -> all its forms
	ld a,(v_w+1)
	or a
	jr nz,on_num
	ld a,(v_w)		; a character
	jr on_show
on_num: ld hl,v_w		; decimal, or hex ending in h
	ld de,0
	ld b,0
on_h1:	ld a,(hl)		; (an h at the end?)
	or a
	jr z,on_h2
	inc hl
	ld b,a
	jr on_h1
on_h2:	ld a,b
	call pl_upper
	cp 'H'
	ld hl,v_w
	jr z,on_hex
on_d1:	ld a,(hl)
	or a
	jr z,on_dn
	sub '0'
	jr c,on_bad
	cp 10
	jr nc,on_bad
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
	jr on_d1
on_dn:	ld a,d
	or a
	jr nz,on_bad
	ld a,e
	jr on_show
on_hex: ld a,(hl)
	call pl_upper
	cp 'H'
	jr z,on_dn
	sub '0'
	jr c,on_bad
	cp 10
	jr c,on_hx
	sub 7
	cp 10
	jr c,on_bad
	cp 16
	jr nc,on_bad
on_hx:	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	or l
	ld l,a
	ex de,hl
	inc hl
	jr on_hex
on_bad: ld hl,m_use
	jp pl_fail

on_show:			; A = a code: "A = 65 = 41h = 01000001b"
	push af
	call name
	ld a,h
	or l
	jr z,os_1
	call OS_PUTS		; (a control code: its name)
	jr os_2
os_1:	ld a,c
	call OS_PUTC
os_2:	ld hl,m_eq
	call OS_PUTS
	pop af
	push af
	ld l,a
	ld h,0
	call OS_DEC16
	ld hl,m_eq
	call OS_PUTS
	pop af
	push af
	call OS_HEX8
	ld hl,m_heq
	call OS_PUTS
	pop af
	push af
	ld b,8
os_3:	rlca
	push af
	ld a,'0'
	adc a,0
	call OS_PUTC
	pop af
	djnz os_3
	ld a,'b'
	call OS_PUTC
	pop af
	cp 20h			; a control code: and the key that makes it
	jr nc,os_4
	push af
	ld hl,m_ctrl
	call OS_PUTS
	pop af
	add a,40h
	call OS_PUTC
	ld a,')'
	call OS_PUTC
os_4:	jp OS_CRLF

hexdig: and 0Fh 		; A's low hex digit (the row)
	add a,'0'
	cp '9'+1
	jr c,hd_1
	add a,7
hd_1:	jp OS_PUTC

dec3:	ld l,a			; A in 3 digits, zeros before
	ld h,0
	ld b,'0'-1
d3_1:	inc b
	ld de,100
	or a
	sbc hl,de
	jr nc,d3_1
	add hl,de
	ld a,b
	call OS_PUTC
	ld b,'0'-1
d3_2:	inc b
	ld de,10
	or a
	sbc hl,de
	jr nc,d3_2
	add hl,de
	ld a,b
	call OS_PUTC
	ld a,l
	add a,'0'
	jp OS_PUTC

m_use:	defm "ASCII [/D | /H | character | number]   (the table, or one: ASCII A, ASCII 41h)"
	defb 0
m_head: defm "    0x       1x       2x       3x       4x       5x       6x       7x"
	defb 13,10,0
m_headd:
	defm "decimal: the code, then the character"
	defb 13,10,0
m_headh:
	defm "    8x       9x       Ax       Bx       Cx       Dx       Ex       Fx"
	defb 13,10,0
m_eq:	defm " = "
	defb 0
m_heq:	defm "h = "
	defb 0
m_ctrl: defm "  (Ctrl-"
	defb 0
m_sp:	defm "SP"
	defb 0
m_del:	defm "DEL"
	defb 0
m_c1:	defm "(C1)"
	defb 0
ctl:	defm "NUL",0,"SOH",0,"STX",0,"ETX",0,"EOT",0,"ENQ",0,"ACK",0,"BEL",0
	defm "BS",0,0,"HT",0,0,"LF",0,0,"VT",0,0,"FF",0,0,"CR",0,0,"SO",0,0,"SI",0,0
	defm "DLE",0,"DC1",0,"DC2",0,"DC3",0,"DC4",0,"NAK",0,"SYN",0,"ETB",0
	defm "CAN",0,"EM",0,0,"SUB",0,"ESC",0,"FS",0,0,"GS",0,0,"RS",0,0,"US",0,0

	include "PROGRAMS/PLIB.INC"
