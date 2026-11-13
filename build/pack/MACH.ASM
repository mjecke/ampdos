; ==========================================================================
; MACH.ASM - the AMPRO's mach_ routines (docs/PORTING.md): timing, the ID
; jumpers, going back to the boot ROM.
;
;   md_geom      the selected drive: HL = its sectors, D = sectors a track,
;                E = heads (D = 0: no tracks, a card), A = 1 if it can format
;   mach_wait    DE = milliseconds: wait (CTC channel 2).  CF = Esc pressed
;   mach_id      A = the board's ID jumpers (port 29h)
;   mach_reboot  the boot ROM on, and its start (it boots the disk again)
;   siob_setup   TERM: Serial B at its baud rate and format (tm_ variables)
;   siob_poll    CF = a byte came in on Serial B, A = it
; ==========================================================================

SL_TC:	equ M_CLOCK/16		; CTC counts per millisecond (prescaler 16)

md_geom:			; both drives: 360K, 40 cylinders, 2 sides, 9 sectors
	ld hl,720
	ld de,0902h
	ld a,1
	ret

mach_wait:			; wait DE milliseconds.  CF = Esc pressed (SLEEP)
	ld a,d
	or e
	ret z
	ld a,07h		; timer mode, /16, starts at once, time constant next
	out (CTC2),a
	ld a,SL_TC
	out (CTC2),a
	ld b,10 		; (let it start counting)
cum_0:	djnz cum_0
	in a,(CTC2)
	ld b,a
cum_1:	in a,(CTC2)
	cp b			; the count falls during the millisecond ...
	ld b,a
	jr c,cum_1
	jr z,cum_1
	call con_kbhit		; ... and jumps up when it is over
	jr z,cum_2
	call con_getc
	cp 1Bh
	scf
	ret z
cum_2:	dec de
	ld a,d
	or e
	jr nz,cum_1
	ld a,03h		; the channel stopped again (control word, reset)
	out (CTC2),a
	ret

mach_id:
	in a,(IDPORT)
	ret

mach_reboot:			; the ROM is switched on from a stub in the TPA:
	ld hl,TPA		; when the OS runs in RAM at 0000h, the ROM appears
	ld (hl),0D3h		; under the code the moment it is on.
	inc hl			;   out (BCR),a / jp 0
	ld (hl),BCR
	inc hl
	ld (hl),0C3h
	inc hl
	ld (hl),0
	inc hl
	ld (hl),0
	xor a			; ROM on, no drive
	jp TPA

siob_setup:			; TERM: the baud rate and the format (tm_ctc, tm_tc:
	ld a,(tm_ctc)		; CTC channel 1; tm_wr4, tm_wr3, tm_wr5: the DART's)
	out (CTC1),a
	ld a,(tm_tc)
	out (CTC1),a
	ld a,18h		; channel reset
	out (DARTBC),a
	ld a,4
	out (DARTBC),a
	ld a,(tm_wr4)
	out (DARTBC),a
	ld a,1
	out (DARTBC),a
	xor a
	out (DARTBC),a
	ld a,3
	out (DARTBC),a
	ld a,(tm_wr3)
	out (DARTBC),a
	ld a,5
	out (DARTBC),a
	ld a,(tm_wr5)
	out (DARTBC),a
	ret

siob_poll:			; CF = a byte arrived, A = it
	in a,(DARTBC)
	rrca
	ret nc
	in a,(DARTBD)
	scf
	ret
