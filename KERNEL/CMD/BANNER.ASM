; ==========================================================================
; BANNER.ASM - the start-up banner, unpacked as it is printed.
; tools/build/mkbanner.py turns BANNER.TXT into GEN/BANNER.INC: a bit stream in which
; each character is a unary code (n 1 bits then a 0 = the n'th entry of
; bn_tab, the most frequent first: a space is just one 0 bit).  10 in the
; table prints CR LF, 0 ends the banner.  34 bytes of code, 8 of table and
; 81 of data instead of the 393 bytes of text.
; ==========================================================================

sh_banner:
	ld hl,bn_data
	ld e,80h		; E: the bits left, with a 1 behind them (80h: none)
bn_sym: ld bc,bn_tab		; a new character: count the 1 bits
bn_bit: sla e			; the next bit into carry ...
	jr nz,bn_1
	ld e,(hl)		; ... (only the end mark was left: the next byte,
	inc hl			; and the end mark, carry = 1, shifted in behind)
	rl e
bn_1:	jr nc,bn_got		; 0: the character is found
	inc bc
	jr bn_bit
bn_got: ld a,(bc)
	or a
	ret z			; the end
	cp 10
	call nz,con_putc	; (con_putc keeps the flags)
	call z,con_crlf
	jr bn_sym

	include "GEN/BANNER.INC"  ; (made from BANNER.TXT by build.py)
