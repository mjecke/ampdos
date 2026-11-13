; ==========================================================================
; PEEK.ASM - looking at memory and ports, as a monitor would.  All numbers
; are in hex (1 to 4 digits; no "h" needed).
;   PEEK addr [count]     the bytes there, 16 to a line (count: 1 if not given)
;   POKE addr byte ...    put bytes there (all of them are checked first)
;   IN port               read an I/O port:  IN 29  shows the ID jumpers
;   OUT port value        write one
; Careful: POKE into the OS's memory and OUT to the board's ports (00h, the
; floppy controller ...) can stop the machine.  That is what they are for.
; ==========================================================================

cmd_peek:
	ld hl,(sh_args)
	call cu_hexw		; DE = the address
	jr c,cpk_bad
	push de
	call sh_skipsp
	ld de,1 		; the count: 1, or as given
	ld a,(hl)
	or a
	call nz,cu_hexw
	pop hl			; HL = the address
	jr c,cpk_bad
	ld a,d
	or e
	jr z,cpk_bad
cpk_ln: call con_hex16		; a line: "8000: 3E 3C 90 ..."
	ld a,':'
	call con_putc
	ld b,16
cpk_b:	ld a,' '
	call con_putc
	ld a,(hl)
	call con_hex8
	inc hl
	dec de
	ld a,d
	or e
	jr z,cpk_end
	djnz cpk_b
	call con_crlf
	call sh_brk
	ret c
	jr cpk_ln
cpk_end:
	jp con_crlf
cpk_bad:
	ld hl,m_mo_peek
	jr cmo_bad

cmd_poke:
	ld c,0			; the first time through only check,
cpo_0:	ld hl,(sh_args) 	; the second time write
	call cu_hexw
	jr c,cpo_bad
	push de
	call sh_skipsp
	ld a,(hl)
	pop de
	or a
	jr z,cpo_bad		; no bytes
cpo_1:	call sh_skipsp
	ld a,(hl)
	or a
	jr z,cpo_2
	push de
	call cu_hexw		; E = the next byte
	ld a,d
	ld b,e
	pop de
	jr c,cpo_bad
	or a
	jr nz,cpo_bad		; (more than FF)
	inc c
	dec c
	jr z,cpo_1a
	ld a,b
	ld (de),a
cpo_1a: inc de
	jr cpo_1
cpo_2:	inc c
	dec c
	ret nz			; written: done
	inc c
	jr cpo_0
cpo_bad:
	ld hl,m_mo_poke
	jr cmo_bad

cmd_in:
	ld hl,(sh_args)
	call cu_hexw
	jr c,cin_bad
	ld a,d
	or a
	jr nz,cin_bad
	ld c,e
	ld b,0
	in a,(c)
	call con_hex8
	jp con_crlf
cin_bad:
	ld hl,m_mo_in
	jr cmo_bad

cmd_out:
	ld hl,(sh_args)
	call cu_hexw		; the port
	jr c,cou_bad
	ld a,d
	or a
	jr nz,cou_bad
	push de
	call sh_skipsp
	ld a,(hl)
	or a
	scf
	call nz,cu_hexw 	; the value
	pop bc
	jr c,cou_bad
	ld a,d
	or a
	jr nz,cou_bad
	ld a,e
	ld b,0
	out (c),a
	ret
cou_bad:
	ld hl,m_mo_out
cmo_bad:
	call sh_fail
	jp con_puts

cu_hexw:			; HL = 1 to 4 hex digits (spaces before them are
	call sh_skipsp		; skipped), then a space or the end -> DE, HL past
	ld de,0 		; them.  CF = not that
	ld b,0
chw_1:	ld a,(hl)
	call cu_hexd
	jr c,chw_2
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	or l
	ld l,a
	ex de,hl
	inc hl
	inc b
	ld a,b
	cp 5
	jr c,chw_1
	scf			; a fifth digit: too many
	ret
chw_2:	ld a,b
	or a
	scf
	ret z			; no digit
	ld a,(hl)
	or a
	ret z
	cp ' '
	ret z
	scf
	ret

cu_hexd:			; A = a character -> its value 0..15.  CF = not hex
	cp '0'
	ret c
	cp '9'+1
	jr nc,chd_1
	sub '0'
	ret
chd_1:	and 0DFh		; (a-f as A-F)
	cp 'A'
	ret c
	cp 'F'+1
	ccf
	ret c
	sub 'A'-10
	ret

m_mo_peek: defm "PEEK addr [count]   (hex, e.g. PEEK 8000 40)"
	defb 13,10,0
m_mo_poke: defm "POKE addr byte ...   (hex, e.g. POKE 9000 C9)"
	defb 13,10,0
m_mo_in:   defm "IN port   (hex, e.g. IN 29)"
	defb 13,10,0
m_mo_out:  defm "OUT port value   (hex, e.g. OUT 00 01)"
	defb 13,10,0
