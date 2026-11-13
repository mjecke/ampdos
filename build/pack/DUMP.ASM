; ==========================================================================
; DUMP.ASM - DUMP.BIN: any file in hex, with its text on the right.
;
;   DUMP [d:][dir\]name [/H] [/O:offset] [/P]
;
;   000000: 3E 0A CD 03 FF 76 48 65 6C 6C 6F 0D 0A 00 00 00  >....vHello.....
;
; /H  hex only (as DUMP was in the kernel); /O:hhhhhh start at that offset
; (hex); /P a screen at a time (SCREEN ROWS): Space the next one, Return one
; more line, Q or Esc stop.  Without /P, Esc stops and another key pauses.
; Bytes that are not printable (below 20h, 7Fh and up) show as "." on the
; right.  The output can be redirected: DUMP X.BIN > X.HEX.  (It was a
; built-in command until 0.8.7.)
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h
P_NAME: equ 9010h
RF_FCB: equ 9020h		; RFILE.INC's
rf_ptr: equ 9030h
rf_end: equ 9032h
v_off:	equ 9034h		; 3 bytes: the offset of the line
v_skip: equ 9038h		; 3 bytes: /O
v_hex:	equ 903Bh		; 1 = /H
v_page: equ 903Ch		; 1 = /P
v_left: equ 903Dh		; lines left on this screen (/P)
v_rows: equ 903Eh
v_n:	equ 903Fh		; bytes in v_line
v_line: equ 9040h		; 16 bytes
v_name: equ 9060h		; 64 bytes: the argument
v_w:	equ 90A0h		; 16 bytes: a switch
RF_BUF: equ 9100h
RF_LEN: equ 512

start:	xor a
	ld (v_hex),a
	ld (v_page),a
	ld (v_name),a
	ld (v_skip),a
	ld (v_skip+1),a
	ld (v_skip+2),a
	push hl
	ld a,8			; the screen's rows
	call OS_SCREEN
	ld a,l
	jr nc,st_r
	ld a,24
st_r:	dec a
	ld (v_rows),a
	ld (v_left),a
	pop hl
st_arg: ld de,v_w		; the name and the switches, in any order
	call pl_word
	jr z,st_go
	ld a,(v_w)
	cp '/'
	jr z,st_sw
	ld a,(v_name)		; (one name)
	or a
	jp nz,use
	push hl
	ld hl,v_w
	ld de,v_name
	call pl_cat
	pop hl
	jr st_arg
st_sw:	ld a,(v_w+1)
	call pl_upper
	cp 'H'
	jr nz,st_s1
	ld a,1
	ld (v_hex),a
	jr st_arg
st_s1:	cp 'P'
	jr nz,st_s2
	ld a,1
	ld (v_page),a
	jr st_arg
st_s2:	cp 'O'
	jp nz,use
	ld a,(v_w+2)
	cp ':'
	jp nz,use
	push hl
	ld hl,v_w+3
	call hexnum
	pop hl
	jp c,use
	jr st_arg
st_go:	ld a,(v_name)
	or a
	jp z,use
	ld hl,v_name
	call rf_open
	jp c,pl_err
	ld hl,(v_skip)		; past the first /O bytes
	ld (v_off),hl
	ld a,(v_skip+2)
	ld (v_off+2),a
sk_1:	ld hl,(v_skip)
	ld a,(v_skip+2)
	or h
	or l
	jr z,lines
	call rf_getc
	jr c,sk_end
	ld hl,(v_skip)		; one less
	ld a,h
	or l
	dec hl
	ld (v_skip),hl
	jr nz,sk_1
	ld hl,v_skip+2
	dec (hl)
	jr sk_1
sk_end: or a			; the file is shorter: nothing to show
	jp nz,pl_err
	ret

lines:	xor a			; ---- 16 bytes a line
	ld (v_n),a
ln_1:	call rf_getc
	jr c,ln_eof
	ld hl,v_n
	ld e,(hl)
	inc (hl)
	ld d,0
	ld hl,v_line
	add hl,de
	ld (hl),a
	ld a,(v_n)
	cp 16
	jr nz,ln_1
	call show
	ret c			; (stopped)
	jr lines
ln_eof: push af
	ld a,(v_n)
	or a
	call nz,show
	pop af
	or a
	ret z
	jp pl_err

show:				; the line in v_line (v_n bytes).  CF = stop
	ld a,(v_off+2)		; "000000:"
	call OS_HEX8
	ld hl,(v_off)
	call OS_HEX16
	ld a,':'
	call OS_PUTC
	ld hl,v_line
	ld b,16
sh_1:	ld a,' '
	call OS_PUTC
	ld a,16 		; (past the end: spaces, so the text lines up)
	sub b
	ld c,a
	ld a,(v_n)
	cp c
	jr z,sh_sp
	jr c,sh_sp
	ld a,(hl)
	call OS_HEX8
	jr sh_2
sh_sp:	ld a,' '
	call OS_PUTC
	call OS_PUTC
sh_2:	inc hl
	djnz sh_1
	ld a,(v_hex)
	or a
	jr nz,sh_4
	ld a,' '		; the text: printable characters, else "."
	call OS_PUTC
	call OS_PUTC
	ld hl,v_line
	ld a,(v_n)
	ld b,a
sh_3:	ld a,(hl)
	cp 20h
	jr c,sh_dot
	cp 7Fh
	jr c,sh_ch
sh_dot: ld a,'.'
sh_ch:	call OS_PUTC
	inc hl
	djnz sh_3
sh_4:	call OS_CRLF
	ld hl,(v_off)		; the next line's offset
	ld de,16
	add hl,de
	ld (v_off),hl
	jr nc,sh_5
	ld hl,v_off+2
	inc (hl)
sh_5:	ld a,(v_page)
	or a
	jr nz,pg
	call OS_KBHIT		; no /P: Esc stops, another key pauses
	ret z
	call OS_GETC
	cp 1Bh
	scf
	ret z
	call OS_GETC
	cp 1Bh
	scf
	ret z
	or a
	ret
pg:	ld hl,v_left		; /P: a screen at a time
	dec (hl)
	ret nz
	ld hl,m_more
	call OS_PUTS
pg_k:	call OS_GETC
	call pl_upper
	cp 1Bh
	jr z,pg_q
	cp 'Q'
	jr z,pg_q
	ld b,1
	cp 13
	jr z,pg_n
	ld a,(v_rows)
	ld b,a
pg_n:	ld a,b
	ld (v_left),a
	ld a,13 		; the prompt goes: CR, spaces, CR
	call OS_PUTC
	ld b,10
pg_sp:	ld a,' '
	call OS_PUTC
	djnz pg_sp
	ld a,13
	call OS_PUTC
	or a
	ret
pg_q:	call OS_CRLF
	scf
	ret

hexnum: 			; HL = hex digits (6 at most) -> v_skip.  CF = not that
	ld de,0
	ld c,0			; C:DE = the number
	ld b,0			; B = digits
hn_1:	ld a,(hl)
	or a
	jr z,hn_end
	call pl_upper
	sub '0'
	jr c,hn_bad
	cp 10
	jr c,hn_d
	sub 7
	cp 10
	jr c,hn_bad
	cp 16
	jr nc,hn_bad
hn_d:	push af 		; C:DE = C:DE x 16 + digit
	push bc
	ld b,4
hn_sh:	sla e
	rl d
	rl c
	djnz hn_sh
	ld a,c
	pop bc
	ld c,a
	pop af
	or e
	ld e,a
	inc hl
	inc b
	ld a,b
	cp 7
	jr nc,hn_bad
	jr hn_1
hn_end: ld a,b
	or a
	jr z,hn_bad
	ld (v_skip),de
	ld a,c
	ld (v_skip+2),a
	or a
	ret
hn_bad: scf
	ret

use:	ld hl,m_use
	jp pl_fail

m_use:	defm "DUMP [d:][dir\\]name [/H] [/O:offset] [/P]   (/H hex only, /O hex offset,"
	defb 13,10
	defm "/P a screen at a time)"
	defb 0
m_more: defm "-- More --"
	defb 0

	include "PROGRAMS/RFILE.INC"
	include "PROGRAMS/PLIB.INC"
