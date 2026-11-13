; ==========================================================================
; MEM.ASM - MEM (also MEMTEST): test all 64 KB of RAM, and say how it is used:
;   64KB RAM OK. Programs: 8000-FBFF (31KB), OS: 0000-5EFF, Buffers: 5F00-7FFF
; It also runs at every start, before the DATE question.  Three tests:
;
;   fill       (at the start only) 8000-FBFF, where programs go and nothing is
;              yet: every byte written with a pattern made from its address
;              (high XOR low byte), then all read back; then again inverted.
;              Reading back only after all is written also finds RAM that
;              forgets (refresh), and bytes that answer for others.
;   addresses  all 64 blocks of 1 KB get their own number in their first byte,
;              then all are read back: a block showing another's number means
;              the RAM repeats itself (a missing chip, a broken address line).
;   data       every byte of 0000-FFFF, the OS and its buffers too: kept,
;              written with 55h and AAh (each bit 0 and 1, its neighbours the
;              other way), read back, and put back.  Nothing is lost.  The
;              1 KB blocks holding this test's own code (mt_beg..mt_fin) are
;              tested afterwards by a copy of mt_data run from VFYBUF.
; Interrupts are off (as always in ampDOS), so nothing else touches memory
; meanwhile.  The first bad byte is reported: its address and what it read.
; ==========================================================================

MT_SAVE: equ VFYBUF+100h	; 64 bytes: the blocks' first bytes (no 1 KB boundary in it)

cmd_mem:
	xor a
	jr mt_go
mt_boot:			; (at the start: the fill test too)
	ld a,1
mt_go:	push af
	ld hl,m_mt_test 	; "Testing RAM . . ." while it runs (the result is
	call con_puts		; written over it: CR, no LF)
	call fs_flush		; (VFYBUF is free after this)
	ld hl,0FFFFh		; no bad byte yet
	ld (mt_first),hl
	pop af
	or a
	call nz,mt_fill
	call mt_addr
	xor a			; the data test: all but this code's blocks ...
	ld (mt_stop),a
	ld a,(mt_beg>>8) & 0FCh
	ld (mt_s1),a
	ld a,(mt_fin>>8) | 3
	ld (mt_s2),a
	ld hl,0
	call mt_data
	ld hl,mt_data		; ... then those, by a copy of it
	ld de,VFYBUF
	ld bc,mtd_end-mt_data
	ldir
	ld a,(mt_s2)
	inc a
	ld (mt_stop),a
	ld a,(mt_s1)
	ld h,a
	ld l,0
	ld a,0FFh		; (none left out)
	ld (mt_s1),a
	xor a
	ld (mt_s2),a
	call VFYBUF
	ld a,13 		; back to the start of the line
	call con_putc
	ld hl,(mt_first)	; the result
	inc hl
	ld a,h
	or l
	ld hl,m_mt_ok
	jr z,mt_say
	ld hl,m_mt_bad		; "RAM BAD at 8123 (read 54h)"
	call con_puts
	ld hl,(mt_first)
	call con_hex16
	ld hl,m_mt_read
	call con_puts
	ld a,(mt_got)
	call con_hex8
	ld hl,m_mt_rd2
mt_say: call con_puts
	ld hl,m_mt_map
	jp con_puts

mt_fill:			; 8000-FBFF: all written, then all read back (destructive)
	ld e,0			; E = 0, then FFh: the pattern inverted
mtf_p:	ld hl,TPA
mtf_w:	ld a,h
	xor l
	xor e
	ld (hl),a
	inc hl
	ld a,h
	cp TPA_TOP>>8
	jr nz,mtf_w
	ld hl,TPA
mtf_r:	ld a,h
	xor l
	xor e
	cp (hl)
	jr z,mtf_n
	ld a,(hl)
	call mt_note
mtf_n:	inc hl
	ld a,h
	cp TPA_TOP>>8
	jr nz,mtf_r
	ld a,e
	cpl
	ld e,a
	or a
	jr nz,mtf_p
	ret

; ---------------------------------------------------------------- the tests
mt_beg: 			; (from here to mt_fin: the code that runs during the tests)

mt_data:			; HL = a page: each byte from there up to page (mt_stop)
mtd_pg: ld a,(mt_s1)		; (0: to FFFF), but pages (mt_s1)..(mt_s2).  Only
	ld b,a			; relative jumps: it also runs as a copy
	ld a,h
	cp b
	jr c,mtd_1
	ld a,(mt_s2)
	cp h
	jr nc,mtd_skip
mtd_1:	ld c,(hl)		; keep what is there
	ld (hl),55h
	ld a,(hl)
	cp 55h
	jr nz,mtd_bad
	ld (hl),0AAh
	ld a,(hl)
	cp 0AAh
	jr nz,mtd_bad
	ld (hl),c		; put it back
	inc l
	jr nz,mtd_1
mtd_skip:
	inc h
mtd_chk:
	ld a,(mt_stop)
	cp h
	jr nz,mtd_pg
	ret
mtd_bad:
	ld (hl),c		; put back what was there first
	call mt_note
	ld a,h			; on with the next 1 KB block
	and 0FCh
	add a,4
	ld h,a
	ld l,0
	jr mtd_chk
mtd_end:

mt_addr:			; the address test: DE = a block's first byte
	ld de,0
	ld hl,MT_SAVE		; keep every block's first byte
mta_1:	ld a,(de)
	ld (hl),a
	inc hl
	ld a,d
	add a,4
	ld d,a
	jr nc,mta_1
mta_2:	call mta_code		; write each block's number (D / 4) into it
	jr c,mta_3
	ld a,d
	rrca
	rrca
	ld (de),a
mta_3:	ld a,d
	add a,4
	ld d,a
	jr nc,mta_2
mta_4:	call mta_code		; read them all back
	jr c,mta_5
	ld a,d
	rrca
	rrca
	ex de,hl
	cp (hl)
	ld a,(hl)
	call nz,mt_note
	ex de,hl
mta_5:	ld a,d
	add a,4
	ld d,a
	jr nc,mta_4
	ld hl,MT_SAVE		; and put the first bytes back
mta_6:	ld a,(hl)
	ld (de),a
	inc hl
	ld a,d
	add a,4
	ld d,a
	jr nc,mta_6
	ret

mta_code:			; CF = block D holds this code (left out)
	ld a,d
	cp (mt_beg>>8) & 0FCh
	ccf
	ret nc
	cp ((mt_fin>>8) | 3) + 1
	ret

mt_note:			; HL = a bad address, A = what was read there:
	push af 		; remember the first one.  Keeps BC, DE, HL.
	push hl
	ld hl,(mt_first)
	inc hl			; FFFFh (none yet) -> 0
	ld a,h
	or l
	pop hl
	jr nz,mtn_1
	ld (mt_first),hl
	pop af
	ld (mt_got),a
	ret
mtn_1:	pop af
	ret

mt_fin:

m_mt_test: defm "Testing RAM . . ."
	defb 0
m_mt_ok:   defm "64KB RAM OK. "
	defb 0
m_mt_bad:  defm "RAM BAD at "
	defb 0
m_mt_read: defm " (read "
	defb 0
m_mt_rd2:  defm "h)"
	defb 13,10,0
m_mt_map:  defm "Programs: 8000-FBFF (31KB), OS: 0000-5EFF, Buffers: 5F00-7FFF"
	defb 13,10,0
