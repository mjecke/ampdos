; ==========================================================================
; SIOA.ASM - the console: DART channel A + CTC channel 0, 9615 baud, 8N1, polled.
; These are the same instructions the AMPRO monitor ROM uses for its
; RST 08h / 10h / 18h (stub_menu6.asm: TXA, RXA, CKIN), so the terminal sees
; exactly what it would from the ROM.  The OS uses them directly, so it
; does not need the ROM for the console.
;   sioa_init            set up CTC 0 and the DART (only needed without the ROM
;                        monitor: it has done this already)
;   sioa_putc   A        send A (waits for the transmitter).  Keeps all registers.
;   sioa_getc            wait for a key -> A
;   sioa_kbhit           NZ = a key is waiting (A, flags changed)
; ==========================================================================

mc_init:			; (the machine layer's name for it)
sioa_init:
	ld a,47h		; CTC 0: timer mode, prescale 16, time constant follows
	out (CTC0),a
	ld a,13 		; time constant -> 9615 baud
	out (CTC0),a
	ld hl,sioa_table
	ld b,9
	ld c,DARTAC
	otir
	ret
sioa_table:
	defb 18h		; WR0: channel reset
	defb 04h, 44h		; WR4: x16 clock, 1 stop bit, no parity
	defb 01h, 00h		; WR1: no interrupts
	defb 03h, 0C1h		; WR3: receiver on, 8 bits
	defb 05h, 0EAh		; WR5: transmitter on, 8 bits, DTR and RTS on

mc_out:			; (the machine layer's name for it)
sioa_putc:
	push af
sioa_p1:
	in a,(DARTAC)
	bit 2,a 		; transmit buffer empty?
	jr z,sioa_p1
	pop af
	out (DARTAD),a
	ret

mc_in:			; (the machine layer's name for it)
sioa_getc:
	in a,(DARTAC)
	bit 0,a 		; a character waiting?
	jr z,sioa_getc
	in a,(DARTAD)
	ret

mc_stat:			; (the machine layer's name for it)
sioa_kbhit:
	in a,(DARTAC)
	and 01h 		; NZ = a character is waiting
	ret
