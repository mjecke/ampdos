; ==========================================================================
; TYPE.ASM - TYPE (show a text file) and MORE (a page at a time).  DUMP is a
; program now (\BIN\DUMP.BIN).
; The file is read in pieces of up to 512 bytes into sh_buf (the TPA, or the
; memory a program lends: OS_EXEC).
; ==========================================================================

cmd_type:
	xor a			; no pages
ct_go:	ld (sh_pgmax),a
	ld (sh_pg),a
	call ct_open
	ret c
	xor a
	ld (sh_mode),a
ct_loop:
	call ct_piece		; BC = bytes now at TPA, 0 = end
	ret c
	ld a,b
	or c
	jp z,con_crlf
	ld a,(sh_mode)
	or a
	jr nz,ct_loop		; after ^Z: read on to the end, show nothing
	ld hl,(sh_buf)
ct_ch:	ld a,(hl)
	cp 1Ah			; ^Z: the old end-of-text mark
	jr z,ct_eof
	cp 10
	jr z,ct_lf
	cp 13
	jr z,ct_next		; CR: the LF makes the new line
	cp 9
	jr z,ct_tab
	cp ' '
	jr c,ct_dot
	cp 7Fh
	jr c,ct_put
ct_dot: ld a,'.'
	jr ct_put
ct_tab: ld a,' '
ct_put: call con_putc
	jr ct_next
ct_lf:	call con_crlf
	call sh_brk
	ret c
	ld a,(sh_pgmax)
	or a
	jr z,ct_next
	ld a,(sh_pg)
	dec a
	ld (sh_pg),a
	jr nz,ct_next
	push hl 		; a page is full: "-- More --"
	push bc
	ld hl,m_ct_more
	call con_puts
	call con_getc
	ld e,a
	call con_crlf
	pop bc
	pop hl
	ld a,e
	cp 1Bh
	jr z,ct_quit
	and 0DFh
	cp 'Q'
	jr z,ct_quit
	ld a,(sh_pgmax) 	; any key: a page; Return: one more line
	ld d,a
	ld a,e
	cp 13
	ld a,d
	jr nz,ct_pg
	ld a,1
ct_pg:	ld (sh_pg),a
ct_next:
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,ct_ch
	jr ct_loop
ct_eof: ld a,1
	ld (sh_mode),a
	jp ct_loop

ct_quit:
	scf
	ret

cmd_more:			; MORE name [lines]: TYPE a page at a time (default: the rows less 1)
	ld hl,(sh_args)
	call sh_skipword
	call sh_skipsp
	call cu_num		; DE = the page size, if one is given
	ld a,(scr_rows)		; (default: the screen's rows less one)
	dec a
	jp c,ct_go
	ld a,d
	or a
	ld a,255
	jp nz,ct_go
	ld a,e
	or a
	jp nz,ct_go
	ld a,(scr_rows)
	dec a
	jp ct_go

m_ct_more: defm "-- More --"
	defb 0

ct_open:			; open the file named by the argument. CF = no
	call sh_open1	      ; [d:][path\]name 1
	ret c
	ld ix,sh_fcb1
	call f_open
	ret nc
	jp sh_err1

ct_piece:			; read up to 512 bytes to sh_buf.  BC = count, CF = error
	ld ix,sh_fcb1
	ld de,(sh_buf)
	ld bc,512
	call f_read
	ret nc
	jp sh_err1
