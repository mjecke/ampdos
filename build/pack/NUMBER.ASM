; ==========================================================================
; NUMBER.ASM - printing numbers bigger than 16 bits, and small helpers.
;
;   con_dec32   HL = address of a 4-byte number (low byte first), B = width
;               print it in decimal, right-aligned in B columns (B = 0: no padding)
;   con_dec16w  HL = number, B = width     the same for a 16-bit number
;   con_dec2    A = 0..99                  print exactly two digits ("07")
;   num_add32   HL = address, DE = address (HL) = (HL) + (DE), 4 bytes each
;   num_shl32   HL = address, A = count    (HL) = (HL) shifted left A times
; All of them preserve BC, DE and HL.
; ==========================================================================

con_dec32:
	push af
	push bc
	push de
	push hl
	ld de,num_tmp		; work on a copy
	push bc
	ld bc,4
	ldir
	pop bc
	ld c,0			; C = digits made
cd32_1: call num_div10		; lowest digit first ...
	add a,'0'
	push af 		; ... so stack them and print in reverse
	inc c
	ld hl,num_tmp		; anything left?
	ld a,(hl)
	inc hl
	or (hl)
	inc hl
	or (hl)
	inc hl
	or (hl)
	jr nz,cd32_1
	ld a,b			; pad with spaces up to the width
	sub c
	jr c,cd32_3
	jr z,cd32_3
	ld b,a
	ld a,' '
cd32_2: call con_putc
	djnz cd32_2
cd32_3: pop af
	call con_putc
	dec c
	jr nz,cd32_3
	pop hl
	pop de
	pop bc
	pop af
	ret

num_div10:			; num_tmp = num_tmp / 10, A = remainder
	push bc 		; long division, one byte at a time from the top:
	push de 		; the remainder (D, always < 10) and the next
	push hl 		; byte are shifted through one bit at a time
	ld hl,num_tmp+3
	ld d,0
	ld c,4
nd_1:	ld e,(hl)
	ld b,8
nd_2:	sla e			; next bit of the dividend into carry ...
	rl d			; ... and into the remainder
	ld a,d
	cp 10
	jr c,nd_3
	sub 10			; it goes: subtract, and this quotient bit is 1
	ld d,a
	inc e			; (E's low bit is free after the shift)
nd_3:	djnz nd_2
	ld (hl),e		; E is now this byte of the quotient
	dec hl
	dec c
	jr nz,nd_1
	ld a,d
	pop hl
	pop de
	pop bc
	ret

con_dec16w:
	push hl
	push de
	ld (num_val),hl
	ld hl,0
	ld (num_val+2),hl
	ld hl,num_val
	call con_dec32
	pop de
	pop hl
	ret

con_dec2:
	push af
	push bc
	ld b,'0'
cd2_1:	cp 10
	jr c,cd2_2
	sub 10
	inc b
	jr cd2_1
cd2_2:	ld c,a
	ld a,b
	call con_putc
	ld a,c
	add a,'0'
	call con_putc
	pop bc
	pop af
	ret

num_add32:
	push af
	push bc
	push de
	push hl
	ld b,4
	or a
na_1:	ld a,(de)
	adc a,(hl)
	ld (hl),a
	inc hl
	inc de
	djnz na_1
	pop hl
	pop de
	pop bc
	pop af
	ret

num_shl32:
	push af
	push bc
	push hl
	or a
	jr z,ns_3
	ld c,a
ns_1:	push hl
	ld b,4
	or a
ns_2:	rl (hl)
	inc hl
	djnz ns_2
	pop hl
	dec c
	jr nz,ns_1
ns_3:	pop hl
	pop bc
	pop af
	ret
