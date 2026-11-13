; ==========================================================================
; FAT.ASM - the File Allocation Table, kept whole in FATBUF.
;
;   fat_get    HL = cluster    HL = its FAT entry (12 bits)
;   fat_next   HL = cluster    HL = next cluster of the chain, NC
;                              or CF with A = FS_EEND (chain ended normally)
;                                      or A = FS_EBAD (free, reserved or bad entry)
;   fat_set    HL = cluster, DE = value    change an entry (in memory)
;   fat_alloc                  HL = a free cluster, now marked "end of chain";
;                              CF with A = FS_EFULL if there is none
;   fat_freechain HL = first cluster       mark the whole chain free
;   fat_flush                  write FATBUF to every FAT copy if it changed. CF = failed
; Changes stay in FATBUF until fat_flush (fs_flush) writes them out.
;
; FAT12 packs two 12-bit entries into three bytes:
;
;     byte 0     byte 1     byte 2
;   [ a7..a0 ] [ b3..b0 a11..a8 ] [ b11..b4 ]
;
; so entry n starts at byte n + n/2.  Read the 16 bits there; for an even n
; keep the low 12 bits, for an odd n the high 12 bits.
; Entry values: 000 = free, 002..FEF = next cluster, FF7 = bad cluster,
; FF8..FFF = last cluster of the file.
; ==========================================================================

fat_get:
	push bc
	push de
	ld b,l			; remember whether n is odd
	ld d,h
	ld e,l
	srl d
	rr e			; DE = n / 2
	add hl,de		; HL = n + n/2 = byte offset in the FAT
	ld de,FATBUF
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl		; HL = the 16 bits holding the entry
	bit 0,b
	jr z,fat_g1
	srl h			; odd: the high 12 bits
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	jr fat_g2
fat_g1: ld a,h			; even: the low 12 bits
	and 0Fh
	ld h,a
fat_g2: pop de
	pop bc
	ret

fat_next:
	call fat_get
	push de
	ld de,FAT_EOC		; FF8 and up: the chain ends here
	or a
	sbc hl,de
	add hl,de
	jr nc,fat_n_end
	ld de,2 		; below 2: free or reserved, not a link
	or a
	sbc hl,de
	add hl,de
	jr c,fat_n_bad
	ld de,(fs_clend)	; past the last cluster (this includes FF7 = bad)
	or a
	sbc hl,de
	add hl,de
	jr nc,fat_n_bad
	pop de
	or a			; NC: HL is the next cluster
	ret
fat_n_end:
	pop de
	ld a,FS_EEND
	scf
	ret
fat_n_bad:
	pop de
	ld a,FS_EBAD
	scf
	ret

fat_set:
	push bc
	push de
	push hl
	ld b,l			; odd or even
	push de
	ld d,h
	ld e,l
	srl d
	rr e
	add hl,de		; byte offset n + n/2
	ld de,FATBUF
	add hl,de
	pop de			; DE = value
	bit 0,b
	jr nz,fat_s_odd
	ld (hl),e		; even: low 8 bits in the first byte,
	inc hl
	ld a,(hl)		; high 4 bits in the low half of the second
	and 0F0h
	ld c,a
	ld a,d
	and 0Fh
	or c
	ld (hl),a
	jr fat_s_done
fat_s_odd:
	ld a,e			; odd: low 4 bits in the high half of the first byte,
	rlca
	rlca
	rlca
	rlca
	and 0F0h
	ld c,a
	ld a,(hl)
	and 0Fh
	or c
	ld (hl),a
	inc hl
	ld a,e			; high 8 bits (value >> 4) in the second byte
	srl d
	rra
	srl d
	rra
	srl d
	rra
	srl d
	rra
	ld (hl),a
fat_s_done:
	ld a,1
	ld (fs_fatdirty),a
	pop hl
	pop de
	pop bc
	ret

fat_alloc:
	push bc
	push de
	ld hl,(fs_hint) 	; start at the hint, wrap around once
	ld de,(fs_clend)
	or a
	sbc hl,de
	add hl,de
	jr c,fat_a0
	ld hl,2
fat_a0: ld bc,(fs_nclus)	; BC = clusters still to look at
fat_a1: push hl
	call fat_get
	ld a,h
	or l
	pop hl
	jr z,fat_a_got
	inc hl			; next, wrapping from the end to 2
	ex de,hl
	ld hl,(fs_clend)
	or a
	sbc hl,de
	ex de,hl
	jr nz,fat_a2
	ld hl,2
fat_a2: dec bc
	ld a,b
	or c
	jr nz,fat_a1
	pop de
	pop bc
	ld a,FS_EFULL
	scf
	ret
fat_a_got:
	ld de,0FFFh		; mark it "last cluster"
	call fat_set
	push hl
	inc hl
	ld (fs_hint),hl 	; next time start after it
	pop hl
	pop de
	pop bc
	or a
	ret

fat_freechain:
	ld a,h
	or l
	ret z			; cluster 0: no chain
fat_fc1:
	push hl
	call fat_get		; DE = next, read before it is cleared
	ex de,hl
	pop hl
	push de
	ld de,0
	call fat_set
	pop hl			; follow the old link
	ld de,2 		; stop at anything that is not a cluster number
	or a
	sbc hl,de
	add hl,de
	ret c
	ld de,(fs_clend)
	or a
	sbc hl,de
	add hl,de
	ret nc
	jr fat_fc1

fat_flush:
	ld a,(fs_fatdirty)
	or a
	ret z
	ld a,(fs_nfats) 	; every copy: lba = fatlba + copy * fatsecs + i
	ld c,a
	ld hl,(fs_fatlba)
fat_f1: ld a,(fs_fatsecs)
	ld b,a
	ld de,FATBUF
fat_f2: push bc
	push de
	push hl
	call md_write
	pop hl
	pop de
	pop bc
	jr c,fat_f_bad
	inc hl
	inc d			; DE += 512
	inc d
	djnz fat_f2
	dec c
	jr nz,fat_f1
	xor a
	ld (fs_fatdirty),a
	ret
fat_f_bad:
	ld a,FS_EWRITE
	scf
	ret
