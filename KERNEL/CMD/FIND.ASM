; ==========================================================================
; FIND.ASM - FIND [/I] [/N] [/C] "text" name: the lines of a text file that
; hold the text.
;
;   /I  ignore upper / lower case     /N  number the lines     /C  only count them
;   A> find /n "mov a" prog.asm
;   12: start:  mov a,b
;   31:         mov a,(hl)
; The text may be one word without quotes.  The status is 1 if no line was
; found, so a batch file can ask.  Lines are cut at 250 characters.
; ==========================================================================

FND_V:	 equ BATBUF+0C0h
fnd_flags: equ FND_V		  ; bit 0 /I, bit 1 /N, bit 2 /C
fnd_pat: equ FND_V+1		  ; word: the text looked for
fnd_line: equ FND_V+3		  ; word: the number of the line
fnd_cnt: equ FND_V+5		  ; word: lines found
fnd_lp:  equ FND_V+7		  ; word: where the next character of the line goes
fnd_lb:  equ FND_V+9		  ; word: the line buffer
fnd_len: equ FND_V+11		  ; characters in the line so far

cmd_find:
	xor a
	ld (fnd_flags),a
	ld hl,(sh_args)
fnd_opt: call sh_skipsp
	ld a,(hl)
	cp '/'
	jr nz,fnd_txt
	inc hl
	ld a,(hl)
	inc hl
	and 0DFh
	ld b,1			; I
	cp 'I'
	jr z,fnd_o1
	ld b,2			; N
	cp 'N'
	jr z,fnd_o1
	ld b,4			; C
	cp 'C'
	jp nz,fnd_usage
fnd_o1:  ld a,(fnd_flags)
	or b
	ld (fnd_flags),a
	jr fnd_opt
fnd_txt: ld a,(hl)
	or a
	jp z,fnd_usage
	ld b,' '		; the text ends at a space, or at the closing quote
	cp '"'
	jr nz,fnd_t1
	inc hl
	ld b,a
fnd_t1:  ld (fnd_pat),hl
fnd_t2:  ld a,(hl)
	or a
	jp z,fnd_usage		 ; (nothing after it: no file name)
	cp b
	jr z,fnd_t3
	inc hl
	jr fnd_t2
fnd_t3:  ld (hl),0		 ; the text ends here
	inc hl
	call sh_skipsp
	ld (sh_args),hl 	; ... and the file name follows
	ld a,(hl)
	or a
	jp z,fnd_usage
	ld a,(fnd_flags)	 ; /I: the text in capitals once
	rrca
	jr nc,fnd_op
	ld hl,(fnd_pat)
fnd_up:  ld a,(hl)
	or a
	jr z,fnd_op
	call fnd_cap
	ld (hl),a
	inc hl
	jr fnd_up
fnd_op:  ld hl,(sh_bufsz)	 ; room for 512 bytes read and a line
	ld de,768
	or a
	sbc hl,de
	jp c,fnd_nomem
	call ct_open
	ret c
	ld hl,(sh_buf)
	ld de,512
	add hl,de
	ld (fnd_lb),hl
	ld (fnd_lp),hl
	ld hl,0
	ld (fnd_line),hl
	ld (fnd_cnt),hl
	xor a
	ld (fnd_len),a
fnd_rd:  call ct_piece
	ret c
	ld a,b
	or c
	jr z,fnd_eof
	ld hl,(sh_buf)
fnd_ch:  ld a,(hl)
	inc hl
	cp 10
	jr z,fnd_nl
	cp 13
	jr z,fnd_nx
	cp 1Ah
	jr z,fnd_nx
	ld d,a			; the character
	ld a,(fnd_len)		 ; room in the line? (the rest of a long one is dropped)
	cp 250
	jr nc,fnd_nx
	inc a
	ld (fnd_len),a
	push hl
	ld hl,(fnd_lp)
	ld (hl),d
	inc hl
	ld (fnd_lp),hl
	pop hl
	jr fnd_nx
fnd_nl:  push hl
	push bc
	call fnd_eol
	pop bc
	pop hl
	ret c			; Esc
fnd_nx:  dec bc
	ld a,b
	or c
	jr nz,fnd_ch
	jr fnd_rd
fnd_eof: ld a,(fnd_len) 	  ; a last line with no end
	or a
	call nz,fnd_eol
	ret c
	ld a,(fnd_flags)
	and 4
	jr z,fnd_nc
	ld hl,(fnd_cnt)
	ld b,0
	call con_dec16w
	call con_crlf
fnd_nc:  ld hl,(fnd_cnt)
	ld a,h
	or l
	ret nz
	jp sh_fail

fnd_eol:			 ; a line is complete: count it, look, show.  CF = Esc
	ld hl,(fnd_lp)
	ld (hl),0
	ld hl,(fnd_line)
	inc hl
	ld (fnd_line),hl
	ld hl,(fnd_lb)
	ld (fnd_lp),hl
	xor a
	ld (fnd_len),a
	call fnd_has
	ret nc			; (no carry: not there)
	ld hl,(fnd_cnt)
	inc hl
	ld (fnd_cnt),hl
	ld a,(fnd_flags)
	and 4
	ret nz			; /C: only count
	ld a,(fnd_flags)
	and 2
	jr z,fe_1
	ld hl,(fnd_line)
	ld b,0
	call con_dec16w
	call sh_colsp
fe_1:	ld hl,(fnd_lb)
fe_2:	ld a,(hl)
	or a
	jr z,fe_3
	cp 9
	jr nz,fe_4
	ld a,' '
fe_4:	cp ' '
	jr nc,fe_5
	ld a,'.'
fe_5:	call con_putc
	inc hl
	jr fe_2
fe_3:	call con_crlf
	jp sh_brk

fnd_has:			 ; CF = the line at fnd_lb holds the text
	ld hl,(fnd_lb)
fh_1:	push hl
	ld de,(fnd_pat)
fh_2:	ld a,(de)
	or a
	jr z,fh_yes		; all of the text matched
	ld c,a
	ld a,(hl)
	or a
	jr z,fh_no		; the line ended first
	call fnd_cap
	cp c
	jr nz,fh_nx
	inc hl
	inc de
	jr fh_2
fh_nx:	pop hl
	inc hl			; try from the next place
	jr fh_1
fh_yes: pop hl
	scf
	ret
fh_no:	pop hl
	or a
	ret

fnd_cap:			 ; A = a character: in capitals if /I
	push bc
	ld b,a
	ld a,(fnd_flags)
	rrca
	ld a,b
	pop bc
	ret nc
	jp sh_upper

fnd_nomem:
	ld hl,m_dc_mem
	jp sh_usage
fnd_usage:
	ld hl,m_fd_use
	jp sh_usage

m_fd_use: defm "FIND [/I /N /C] ",34,"text",34," name"
	defb 13,10,0
