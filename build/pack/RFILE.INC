; ==========================================================================
; RFILE.INC - read a file a byte at a time (HEAD, TAIL, TR, DIFF).  The
; program defines RF_FCB (16 bytes), RF_BUF (RF_LEN bytes), rf_ptr, rf_end
; (words).
;
;   rf_open    HL = a name ([d:][dir\]name): open it.  CF = error (A = code)
;   rf_getc    A = the next byte.  CF = the end (A = 0) or an error (A = code)
;   rf_out     A = a byte for the console: CR is left out, LF is CR LF
; ==========================================================================

rf_open:
	call OS_RESOLVE 	; (its drive and directory)
	ret c
	ld ix,RF_FCB
	call OS_OPEN
	ret c
	ld hl,RF_BUF
	ld (rf_ptr),hl
	ld (rf_end),hl
	or a
	ret

rf_getc:
	push hl
	push de
	ld hl,(rf_ptr)
	ld de,(rf_end)
	or a
	sbc hl,de
	jr c,rg_1
	push bc 		; the buffer is used up: the next part
	ld ix,RF_FCB
	ld de,RF_BUF
	ld bc,RF_LEN
	call OS_READ
	jr c,rg_err
	ld a,b
	or c
	jr z,rg_eof
	ld hl,RF_BUF
	ld (rf_ptr),hl
	add hl,bc
	ld (rf_end),hl
	pop bc
rg_1:	ld hl,(rf_ptr)
	ld a,(hl)
	inc hl
	ld (rf_ptr),hl
	pop de
	pop hl
	or a
	ret
rg_eof: xor a
rg_err: pop bc
	pop de
	pop hl
	scf
	ret

rf_out: cp 13
	ret z
	cp 10
	jp z,OS_CRLF
	jp OS_PUTC
