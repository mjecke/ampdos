; ==========================================================================
; SORT.ASM - SORT [/R] [/I] name [out]: the lines of a text file in order.
;
;   /R  backwards       /I  upper and lower case alike
; The sorted lines go to the screen, or to the file "out" (which may be the
; file itself).  The order is that of the character codes.  The whole file is
; read into memory (up to about 30 KB) with a table of pointers
; to its lines at the end of the memory; the pointers are sorted (Shell's
; method), not the text.  Lines end with CR LF or LF; they come out with CR LF.
; ==========================================================================

SR_V:	equ BATBUF+0C0h
sr_flags: equ SR_V		; bit 0 /R, bit 1 /I
sr_in:	equ SR_V+1		; word: the input name (0 = none) ...
sr_out: equ SR_V+3		; word: ... and the output name
sr_n:	equ SR_V+5		; word: number of lines
sr_tab: equ SR_V+7		; word: the table of pointers
sr_gap: equ SR_V+9		; word
sr_i:	equ SR_V+11		; word
sr_j:	equ SR_V+13		; word
sr_tmp: equ SR_V+15		; word
sr_len: equ SR_V+17		; word: length of the text
sr_wr:	equ SR_V+19		; 1 = writing a file

cmd_sort:
	xor a
	ld (sr_flags),a
	ld (sr_wr),a
	ld hl,0
	ld (sr_in),hl
	ld (sr_out),hl
	ld hl,(sh_args)
so_w:	call sh_skipsp
	ld a,(hl)
	or a
	jr z,so_go
	cp '/'
	jr nz,so_name
	inc hl
	ld a,(hl)
	inc hl
	and 0DFh
	ld b,1
	cp 'R'
	jr z,so_f
	ld b,2
	cp 'I'
	jp nz,so_usage
so_f:	ld a,(sr_flags)
	or b
	ld (sr_flags),a
	jr so_w
so_name:
	ld de,(sr_in)
	ld a,d
	or e
	jr nz,so_n2
	ld (sr_in),hl
	jr so_skip
so_n2:	ld de,(sr_out)
	ld a,d
	or e
	jp nz,so_usage
	ld (sr_out),hl
so_skip:
	call sh_skipword
	jr so_w
so_go:	ld hl,(sr_in)
	ld a,h
	or l
	jp z,so_usage
	ld (sh_args),hl
	call ct_open
	ret c
	ld hl,(sh_bufsz)	; the text may fill all but 1 KB (for the table)
	ld de,1024
	or a
	sbc hl,de
	jp c,so_mem
	push hl
	ld b,h
	ld c,l
	ld ix,sh_fcb1
	ld de,(sh_buf)
	call f_read
	jp c,so_rerr
	pop hl
	ld a,b
	or c
	ret z			; an empty file
	or a
	sbc hl,bc
	jp z,so_mem		; it filled the memory: too big
	ld hl,(sh_buf)		; the last line gets an end
	add hl,bc
	dec hl
	ld a,(hl)
	inc hl
	cp 10
	jr z,so_lf
	ld (hl),10
	inc bc
so_lf:	ld (sr_len),bc
	ld hl,(sh_buf)		; count the lines
	ld de,0
so_c1:	ld a,10
	cpir
	jr nz,so_c2
	inc de
	jp pe,so_c1
so_c2:	ld (sr_n),de
	ld hl,(sh_buf)		; the table: 2 bytes a line, at the end of the memory
	ld de,(sh_bufsz)
	add hl,de
	ld de,(sr_n)
	or a
	sbc hl,de
	or a
	sbc hl,de
	ld (sr_tab),hl
	ex de,hl		; DE = where the table starts
	ld hl,(sh_buf)
	ld bc,(sr_len)
	add hl,bc		; HL = where the text ends
	or a
	sbc hl,de
	jr c,so_fit
	jp nz,so_mem		; the table would reach into the text
so_fit: ld hl,(sh_buf)		; fill it: where each line starts
	ld bc,(sr_len)
	ld de,(sr_tab)
so_f1:	ld a,l
	ld (de),a
	inc de
	ld a,h
	ld (de),a
	inc de
	ld a,10
	cpir
	jp pe,so_f1

	ld hl,(sr_n)		; ---- sort the table
	srl h
	rr l
	ld (sr_gap),hl
so_g:	ld hl,(sr_gap)
	ld a,h
	or l
	jr z,so_sorted
	ld (sr_i),hl		; i = gap
so_i:	ld hl,(sr_i)
	ld de,(sr_n)
	or a
	sbc hl,de
	jr nc,so_gn		; i >= n: the next gap
	ld hl,(sr_i)
	call so_at
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (sr_tmp),de		; tmp = a[i]
	ld hl,(sr_i)
	ld (sr_j),hl
so_j:	ld hl,(sr_j)
	ld de,(sr_gap)
	or a
	sbc hl,de
	jr c,so_put		; j < gap
	push hl 		; j - gap
	call so_at
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl		; HL = the line a[j - gap]
	ld de,(sr_tmp)
	call so_cmp		; CF = it belongs after tmp
	pop hl
	jr nc,so_put
	push hl
	call so_at
	ld e,(hl)
	inc hl
	ld d,(hl)		; a[j] = a[j - gap]
	ld hl,(sr_j)
	call so_at
	ld (hl),e
	inc hl
	ld (hl),d
	pop hl
	ld (sr_j),hl
	jr so_j
so_put: ld hl,(sr_j)		; a[j] = tmp
	call so_at
	ld de,(sr_tmp)
	ld (hl),e
	inc hl
	ld (hl),d
	ld hl,(sr_i)
	inc hl
	ld (sr_i),hl
	jr so_i
so_gn:	ld hl,(sr_gap)
	srl h
	rr l
	ld (sr_gap),hl
	jr so_g

so_sorted:			; ---- the lines out
	ld hl,(sr_out)
	ld a,h
	or l
	jr z,so_out
	call sh_resolve
	jp c,sh_err
	ld ix,sh_fcb2
	call f_create
	jp c,sh_err
	ld a,1
	ld (sr_wr),a
so_out: ld hl,(sr_tab)
	ld bc,(sr_n)
so_o1:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	push bc
	ex de,hl		; HL = a line
	ld a,(sr_wr)
	or a
	jr nz,so_w1
so_s1:	ld a,(hl)
	cp 10
	jr z,so_s2
	cp 13
	jr z,so_s2
	call con_putc
	inc hl
	jr so_s1
so_s2:	call con_crlf
	call sh_brk
	jr so_o2
so_w1:	ld bc,0 		; its length: up to the CR or LF
	push hl
so_l1:	ld a,(hl)
	cp 10
	jr z,so_l2
	cp 13
	jr z,so_l2
	inc hl
	inc bc
	jr so_l1
so_l2:	pop de			; DE = the line
	ld a,b
	or c
	jr z,so_w2
	ld ix,sh_fcb2
	call f_write
	jr c,so_werr
so_w2:	ld de,so_crlf
	ld bc,2
	ld ix,sh_fcb2
	call f_write
	jr c,so_werr
	or a
so_o2:	pop bc
	pop hl
	ret c			; Esc
	dec bc
	ld a,b
	or c
	jr nz,so_o1
	ld a,(sr_wr)
	or a
	ret z
	ld ix,sh_fcb2
	call f_close
	ret nc
	jp sh_err1
so_werr:
	pop bc
	pop hl
	jp sh_err1

so_at:				; HL = an index -> HL = the address of that table entry
	push de
	add hl,hl
	ld de,(sr_tab)
	add hl,de
	pop de
	ret

so_cmp: 			; HL, DE = two lines -> CF = the first belongs after the second
	ld a,(de)
	call so_norm
	ld c,a
	ld a,(hl)
	call so_norm
	cp c
	jr nz,so_df
	or a
	ret z			; both ended: alike
	inc hl
	inc de
	jr so_cmp
so_df:	ld a,(sr_flags) 	; (CF now: the first is smaller)
	bit 0,a
	ret nz			; /R: smaller comes later
	ccf
	ret

so_norm:			; A = a character: 0 at the end of the line, capitals if /I
	cp 13
	jr z,sn_end
	cp 10
	jr nz,sn_1
sn_end: xor a
	ret
sn_1:	ld b,a
	ld a,(sr_flags)
	bit 1,a
	ld a,b
	ret z
	jp sh_upper

so_rerr:
	pop hl
	jp sh_err1
so_mem: ld hl,m_dc_mem
	jr so_say
so_usage:
	ld hl,m_so_use
so_say: jp sh_usage

so_crlf: defb 13,10
m_so_use: defm "SORT [/R /I] name [out]"
	defb 13,10,0
