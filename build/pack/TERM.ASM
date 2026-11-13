; ==========================================================================
; TERM.ASM - TERM [baud] [bits parity stop] [/E]: a terminal on Serial B.
;
;   A> term                  9615 baud, 8 bits, no parity, 1 stop bit (8N1)
;   A> term 1200 7E1 /E      1200 baud, 7 bits, even parity, 1 stop bit, local echo
; What arrives on Serial B is shown on the console; what is typed goes out on
; Serial B.  Ctrl-] ends it (Serial B is set back to 9615 baud 8N1).  Speeds:
; 9600 4800 2400 1200 600 300 150 110 (the board cannot go faster).  The bits
; are 5 to 8, the parity N, E or O, the stop bits 1 or 2.  /E shows what you
; type too (for a far end that does not echo).  The console copy to Serial B
; (MIRROR) is off meanwhile.  It is a polled loop with a 3-byte receive FIFO,
; so a far end that sends at full speed without pauses may lose characters
; when the console is as slow as Serial B: send with pauses between lines.
; ==========================================================================

TM_V:	equ BATBUF+0C0h
tm_tc:	equ TM_V		; CTC time constant
tm_ctc: equ TM_V+1		; CTC mode byte
tm_wr4: equ TM_V+2		; DART: WR4, WR3, WR5
tm_wr3: equ TM_V+3
tm_wr5: equ TM_V+4
tm_echo: equ TM_V+5		; 1 = local echo
tm_mask: equ TM_V+6		; received characters are ANDed with this (7F: 7 bits)
tm_mir: equ TM_V+7		; MIRROR, to put back

cmd_term:
	ld hl,tm_dflt		; 9615 baud, 8N1, no echo
	ld de,TM_V
	ld bc,7
	ldir
	ld hl,(sh_args)
tm_w:	call sh_skipsp
	ld a,(hl)
	or a
	jp z,tm_go
	cp '/'
	jr nz,tm_nm
	inc hl
	ld a,(hl)
	and 0DFh
	cp 'E'
	jp nz,tm_bad
	inc hl
	ld a,1
	ld (tm_echo),a
	jr tm_w
tm_nm:	inc hl
	ld a,(hl)
	dec hl
	cp '0'
	jr c,tm_fmt		; "8N1": the second character is a letter
	cp '9'+1
	jr c,tm_baud
tm_fmt: ld a,(hl)		; bits
	sub '5'
	cp 4
	jp nc,tm_bad
	ld e,a
	ld d,0
	push hl
	ld hl,tm_bits
	add hl,de
	ld a,(hl)		; 0, 2, 1, 3 for 5, 6, 7, 8 bits
	pop hl
	ld c,a
	rrca
	rrca			; the bits in D7 D6 of WR3 (receiver on) ...
	or 1
	ld (tm_wr3),a
	ld a,c
	cp 3
	ld a,0FFh
	jr z,tm_m8
	ld a,7Fh
tm_m8:	ld (tm_mask),a
	ld a,c			; ... and in D6 D5 of WR5 (transmitter on, DTR, RTS)
	rrca
	rrca
	rrca
	and 60h
	or 8Ah
	ld (tm_wr5),a
	inc hl
	ld a,(hl)		; parity
	inc hl
	and 0DFh
	ld b,0
	cp 'N'
	jr z,tm_p
	ld b,1
	cp 'O'
	jr z,tm_p
	ld b,3
	cp 'E'
	jp nz,tm_bad
tm_p:	ld a,(hl)		; stop bits
	inc hl
	ld c,44h
	cp '1'
	jr z,tm_s
	ld c,4Ch
	cp '2'
	jp nz,tm_bad
tm_s:	ld a,c
	or b
	ld (tm_wr4),a
	ld a,(hl)
	or a
	jp z,tm_w
	cp ' '
	jp nz,tm_bad
	jp tm_w
tm_baud:
	call cu_num		; DE = the speed
	ld a,(hl)
	or a
	jr z,tm_b1
	cp ' '
	jp nz,tm_bad
tm_b1:	push hl
	ld hl,tm_rates
tm_b2:	ld a,(hl)
	inc hl
	or (hl)
	jp z,tm_bad2		; not in the table
	ld a,(hl)
	dec hl
	cp d
	jr nz,tm_b3
	ld a,(hl)
	cp e
	jr nz,tm_b3
	inc hl
	inc hl
	ld a,(hl)
	ld (tm_tc),a
	inc hl
	ld a,(hl)
	ld (tm_ctc),a
	pop hl
	jp tm_w
tm_b3:	inc hl
	inc hl
	inc hl
	inc hl
	jr tm_b2
tm_bad2:
	pop hl
tm_bad: ld hl,m_tm_use
	jp sh_usage

tm_go:	ld a,(con_mirror)	; ---- set Serial B up, and go
	ld (tm_mir),a
	xor a
	ld (con_mirror),a
	call siob_setup 	; (the baud rate and the format, as worked out above)
	ld hl,m_tm_go
	call con_puts
tm_loop:
	call siob_poll		; something arrived?
	jr nc,tm_key
	ld hl,tm_mask
	and (hl)
	call con_putc
tm_key: call con_kbhit
	jr z,tm_loop
	call con_getc
	cp 1Dh			; Ctrl-]
	jr z,tm_end
	push af
	call siob_putc
	pop af
	ld hl,tm_echo
	bit 0,(hl)
	jr z,tm_loop
	call con_putc
	jr tm_loop
tm_end: call siob_init		; Serial B as the OS uses it
	ld a,(tm_mir)
	ld (con_mirror),a
	jp con_crlf

tm_bits: defb 0,2,1,3
tm_dflt: defb 13,47h,44h,0C1h,0EAh,0,0FFh   ; tc, ctc, wr4, wr3, wr5, echo, mask
; the speeds: rate, CTC time constant, CTC mode.  47h = counter mode on the board's
; 2 MHz clock (real rates 9615, 4808, ...); 07h = timer mode on the 4 MHz CPU clock
; with prescale 16 (300.5, 150.2, 110.0 baud), for the slow rates.
tm_rates:
	defw 9600
	defb 13,47h
	defw 4800
	defb 26,47h
	defw 2400
	defb 52,47h
	defw 1200
	defb 104,47h
	defw 600
	defb 208,47h
	defw 300
	defb 52,07h
	defw 150
	defb 104,07h
	defw 110
	defb 142,07h
	defw 0

m_tm_go: defm "(Ctrl-] ends)"
	defb 13,10,0
m_tm_use: defm "TERM [baud] [8N1] [/E]  (baud 110-9600)"
	defb 13,10,0
