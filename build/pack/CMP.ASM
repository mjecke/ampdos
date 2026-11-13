; ==========================================================================
; CMP.ASM - CMP (or FC) a b: compare two files byte by byte.
;
;   A> cmp old.bin new.bin
;   000012: 41 42            (offset in hex, the byte in each file; the first 8)
;   000019: 00 FF
;   2 bytes differ
; or "Files are identical", or "The files differ in size: 100 and 120" (the
; common part is still compared).  The two files may be on different drives.
; Both are read in halves of the free memory; the status is 1 if they differ.
; ==========================================================================

CM_V:	equ BATBUF+0C0h 	; (the batch file does not use this part)
cm_d1:	equ CM_V		; drive of file 1, of file 2
cm_d2:	equ CM_V+1
cm_c1:	equ CM_V+2		; word: directory of file 1, of file 2
cm_c2:	equ CM_V+4
cm_half: equ CM_V+6		; word: bytes read from each file at once
cm_n1:	equ CM_V+8		; word: bytes read from file 1, from file 2
cm_n2:	equ CM_V+10
cm_base: equ CM_V+12		; 3 bytes: the offset of this chunk in the files
cm_cnt: equ CM_V+16		; 4 bytes: how many bytes differ
cm_a2:	equ CM_V+20		; word: the second name

cmd_cmp:
	call sh_need2		; HL = name 1, DE = name 2
	ret c
	ld (cm_a2),de
	call sh_mount
	ret c
	ld hl,(sh_args)
	ld ix,sh_fcb1
	call cm_open
	ret c
	ld (cm_d1),a
	ld (cm_c1),hl
	ld hl,(cm_a2)
	ld ix,sh_fcb2
	call cm_open
	ret c
	ld (cm_d2),a
	ld (cm_c2),hl
	ld hl,(sh_bufsz)	; half of the memory, in whole sectors
	srl h
	ld a,h
	and 0FEh
	ld h,a
	ld l,0
	or a
	jp z,cm_nomem
	ld (cm_half),hl
	ld hl,0
	ld (cm_base),hl
	ld (cm_base+2),hl
	ld (cm_cnt),hl
	ld (cm_cnt+2),hl
cm_loop:
	ld ix,sh_fcb1		; a chunk of each file
	ld de,(sh_buf)
	ld a,(cm_d1)
	ld hl,(cm_c1)
	call cm_rd
	ret c
	ld (cm_n1),bc
	ld ix,sh_fcb2
	ld hl,(sh_buf)
	ld de,(cm_half)
	add hl,de
	ex de,hl
	ld a,(cm_d2)
	ld hl,(cm_c2)
	call cm_rd
	ret c
	ld (cm_n2),bc
	ld hl,(cm_n1)		; BC = the shorter of the two
	or a
	sbc hl,bc
	jr nc,cm_m
	ld bc,(cm_n1)
cm_m:	ld a,b
	or c
	jr z,cm_end1
	ld hl,(sh_buf)
	ld de,(cm_half)
	add hl,de
	ex de,hl		; DE = file 2's chunk
	ld hl,(sh_buf)		; HL = file 1's
cm_cmp: ld a,(de)
	cpi
	call nz,cm_diff
	inc de
	ld a,b
	or c
	jr nz,cm_cmp
cm_end1:
	ld hl,(cm_n1)
	ld de,(cm_n2)
	or a
	sbc hl,de
	jr nz,cm_size		; one file ended first
	ld hl,(cm_n1)
	ld a,h
	or l
	jr z,cm_done		; both ended
	ld de,(cm_base) 	; the next chunk
	add hl,de
	ld (cm_base),hl
	jr nc,cm_nc
	ld hl,cm_base+2
	inc (hl)
cm_nc:	call sh_brk
	ret c
	jp cm_loop
cm_size:
	call sh_fail
	ld hl,m_cm_size
	call con_puts
	ld hl,sh_fcb1+FCB_SIZE
	ld b,0
	call con_dec32
	ld hl,m_cm_and
	call con_puts
	ld hl,sh_fcb2+FCB_SIZE
	ld b,0
	call con_dec32
	call con_crlf
cm_done:
	ld hl,cm_cnt
	ld a,(hl)
	inc hl
	or (hl)
	inc hl
	or (hl)
	inc hl
	or (hl)
	jr nz,cm_some
	ld hl,m_cm_same 	; no byte differs: identical, unless the sizes did
	ld a,(sh_status)
	or a
	ret nz
	jp con_puts
cm_some:
	call sh_fail
	ld hl,cm_cnt
	ld b,0
	call con_dec32
	ld hl,m_cm_differ
	jp con_puts

cm_diff:			; (HL-1) and (DE) differ: count it, show the first 8
	push hl
	push de
	push bc
	push hl
	pop ix			; IX = just past file 1's byte
	ld hl,cm_cnt
	ld b,4
cd_1:	inc (hl)
	jr nz,cd_2
	inc hl
	djnz cd_1
cd_2:	ld a,(cm_cnt+1)
	ld hl,cm_cnt+2
	or (hl)
	inc hl
	or (hl)
	jr nz,cd_x
	ld a,(cm_cnt)
	cp 9
	jr nc,cd_x
	push ix 		; the offset = chunk offset + place in the chunk
	pop hl
	dec hl
	ld de,(sh_buf)
	or a
	sbc hl,de
	ld de,(cm_base)
	add hl,de
	ld a,(cm_base+2)
	adc a,0
	push hl
	call con_hex8
	pop hl
	call con_hex16
	call sh_colsp
	ld a,(ix-1)
	call con_hex8
	ld a,' '
	call con_putc
	pop bc
	pop de
	push de
	push bc
	ld a,(de)
	call con_hex8
	call con_crlf
cd_x:	pop bc
	pop de
	pop hl
	ret

cm_rd:				; A, HL = the drive and directory of the file, IX = its FCB,
	push ix 		; DE = where to read: a chunk -> BC = bytes.  CF = failed
	push de
	ld c,a
	ld a,(cm_d1)
	ld b,a
	ld a,(cm_d2)
	cp b
	jr z,cr_1		; one drive: nothing to switch
	ld a,c
	call sh_ctx
	jr nc,cr_1
	pop de
	pop ix
	jp sh_err1
cr_1:	pop de
	pop ix
	ld bc,(cm_half)
	call f_read
	ret nc
	jp sh_err1

cm_open:			; HL = name, IX = FCB: open it -> A = its drive, HL = its
	push ix 		; directory.  CF = failed (said)
	call sh_resolve
	pop ix
	jp c,sh_err1
	call f_open
	jp c,sh_err1
	ld a,(sh_rdrv)
	ld hl,(fs_cwd)
	or a
	ret

cm_nomem:
	ld hl,m_dc_mem
	jp sh_usage

m_cm_size: defm "The files differ in size: "
	defb 0
m_cm_and:  defm " and "
	defb 0
m_cm_same: defm "Files are identical"
	defb 13,10,0
m_cm_differ: defm " byte(s) differ"
	defb 13,10,0
