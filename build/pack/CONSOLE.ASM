; ==========================================================================
; CONSOLE.ASM - the console (the machine's: mc_out, mc_in, mc_stat), optionally mirrored to Serial B
; (so a log can be captured on the PC: MIRROR ON; off by default).  All routines preserve every register.
;   con_init              initialise Serial B (mirroring stays as it is: off at start)
;   con_putc   A          print one character
;   con_puts   HL         print a zero-terminated string; a byte 81h..FFh in it
;                         prints as 1..127 spaces (SPC+n, KERNEL/INC/OS.INC)
;   con_crlf              new line
;   con_hex8   A          print A as two hex digits
;   con_hex16  HL         print HL as four hex digits
;   con_dec16  HL         print HL as an unsigned decimal number
;   con_getc              wait for a key (returns A)
;   con_kbhit             NZ = a key is waiting (does not take it)
; ==========================================================================
con_init:			; (the mirror setting is left as it is: off from
	push af 		;  the start, MIRROR ON turns it on)
	push bc
	push hl
	call siob_init
	pop hl
	pop bc
	pop af
	ret

con_putc:			; (keeps the flags: callers count on it)
	push hl 		; redirected (> file): into memory instead
	push af
	ld hl,(rd_ptr)
	ld a,h
	or a
	jr z,con_putc0
	cp TPA_TOP >> 8 	; full? (the memory ends at TPA_TOP, a 256-byte boundary)
	jr z,con_putcf
	pop af
	ld (hl),a
	inc hl
	ld (rd_ptr),hl
	pop hl
	ret
con_putcf:
	ld (rd_cut),a		; (the rest is lost)
	pop af
	pop hl
	ret
con_putc0:
	pop af
	pop hl
	push af
	call mc_out		; on the console (DART A)
	ld a,(con_mirror)
	or a
	jr z,con_putc1
	pop af
	push af
	call siob_putc
con_putc1:
	pop af
	ret

con_puts:
	push af
	push hl
con_puts1:
	ld a,(hl)
	or a
	jr z,con_puts2
	jp p,con_puts3		; a byte 81h..FFh is 1..127 spaces (SPC+n in a defm)
	push bc
	and 7Fh
	ld b,a
	ld a,' '
con_puts4:
	call con_putc
	djnz con_puts4
	pop bc
	jr con_puts5
con_puts3:
	call con_putc
con_puts5:
	inc hl
	jr con_puts1
con_puts2:
	pop hl
	pop af
	ret

con_crlf:
	push af
	ld a,13
	call con_putc
	ld a,10
	call con_putc
	pop af
	ret

con_hex8:
	push af
	rrca
	rrca
	rrca
	rrca
	call con_nib
	pop af
con_nib:
	push af
	and 0Fh
	add a,'0'
	cp ':'
	jr c,con_nib1
	add a,7 		; A..F
con_nib1:
	call con_putc
	pop af
	ret

con_hex16:
	push af
	ld a,h
	call con_hex8
	ld a,l
	call con_hex8
	pop af
	ret

con_dec16:			; (NUMBER.ASM does the work)
	push bc
	ld b,0
	call con_dec16w
	pop bc
	ret

con_getc:
	jp mc_in

con_kbhit:
	jp mc_stat

	include "GEN/MACHCON.ASM"	; the machine's console driver
