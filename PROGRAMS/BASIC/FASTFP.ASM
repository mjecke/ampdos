; ==========================================================================
; FASTFP.ASM - BASIC reads a number in the program text (and in VAL and INPUT)
; digit by digit: times ten and plus the digit, both in floating point, about
; 2 ms for "123".  A whole number 1 .. 65535 (no point, no E) is read here in
; 16 bits instead, and made a float by shifting it.  The result is the same
; float: a whole number below 2^24 is exact either way.  mkbasic.py appends this and
; calls FASTN at the start of CNVNUM.
; ==========================================================================

FASTN:	push hl 		; HL = before the number (GETCHR comes first)
	ld de,0
fn_1:	inc hl
	ld a,(hl)
	cp ' '			; (spaces are skipped, as GETCHR does)
	jr z,fn_1
	sub '0'
	cp 10
	jr nc,fn_end
	push hl 		; DE = DE * 10 + the digit, in 16 bits
	ld h,d
	ld l,e
	add hl,hl
	jr c,fn_big
	add hl,hl
	jr c,fn_big
	add hl,de
	jr c,fn_big
	add hl,hl
	jr c,fn_big
	ld e,a
	ld d,0
	add hl,de
	jr c,fn_big
	ex de,hl
	pop hl
	jr fn_1
fn_big: pop hl			; too big: the usual way
	pop hl
	ret
fn_end: ld a,(hl)		; HL = the character after the digits
	cp '.'
	jr z,fn_slow
	cp 'E'
	jr z,fn_slow
	ld a,d			; (no digits at all, or 0: the usual way)
	or e
	jr z,fn_slow
	pop af			; (the saved HL)
	pop af			; (the return into CNVNUM: it is not needed)
	push hl 		; the code string address, as CONEXP keeps it
	ex de,hl		; HL = the number: shifted up until its top bit
	ld b,80h+16		; is set, that is the mantissa (the float BNORM
	ld a,h			; would make of it).  Below 256: a byte at once
	or a
	jr nz,fn_n
	ld h,l
	ld l,a
	ld b,80h+8
fn_n:	bit 7,h
	jr nz,fn_f
	add hl,hl
	dec b
	jr fn_n
fn_f:	res 7,h 		; (bit 23: the sign, +)
	ld (FPREG+1),hl
	xor a
	ld (FPREG),a
	ld a,b
	ld (FPEXP),a
	jp ENDCN2		; the sign, and back
fn_slow:
	pop hl
	ret
