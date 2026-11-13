; ==========================================================================
; SIOB.ASM - Serial B (the PC link): DART channel B + CTC channel 1
; 9615 baud, 8N1, polled (no interrupts).
;   siob_init            set up the baud rate generator and the DART
;   siob_putc  A         send a byte (waits for the transmitter)
;   siob_getc            A = byte (carry clear), or carry set if nothing is waiting
; ==========================================================================
siob_init:
	ld a,47h		; CTC1: timer mode, prescale 16, time constant follows
	out (CTC1),a
	ld a,13 		; time constant -> 9615 baud
	out (CTC1),a
	ld hl,siob_table
	ld b,9
	ld c,DARTBC
	otir
	ret
siob_table:
	defb 18h		; WR0: channel reset
	defb 04h, 44h		; WR4: x16 clock, 1 stop bit, no parity
	defb 01h, 00h		; WR1: no interrupts
	defb 03h, 0C1h		; WR3: receiver on, 8 bits
	defb 05h, 0EAh		; WR5: transmitter on, 8 bits, DTR and RTS on

siob_putc:
	push af
siob_putc1:
	in a,(DARTBC)
	bit 2,a 		; transmit buffer empty?
	jr z,siob_putc1
	pop af
	out (DARTBD),a
	ret

siob_getc:
	in a,(DARTBC)
	rrca			; bit 0 = a character is waiting
	jr c,siob_getc1
	scf			; nothing there: carry set
	ret
siob_getc1:
	in a,(DARTBD)
	or a			; carry clear, byte in A
	ret
