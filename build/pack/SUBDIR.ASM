; ==========================================================================
; SUBDIR.ASM - subdirectories: make, remove, change into.
;
;   fs_chdir   HL = one name, "." or ".."   fs_cwd = that directory
;   fs_mkdir   HL = name                    make it in the current directory
;   fs_rmdir   HL = name                    remove it (it must be empty)
;   fs_cl2lba  HL = cluster                 HL = its first sector
; All return CF = failed with A = an FS_E... code.
;
; A new directory gets one cluster of zeros, with two entries in front:
;   "."   -> its own first cluster
;   ".."  -> the parent's first cluster (0 when the parent is the root)
; This is what DOS does, so PCs read our directories and we read theirs.
; ==========================================================================

fs_chdir:
	ld a,(hl)
	cp '.'
	jr nz,fcd_name
	inc hl
	ld a,(hl)
	or a
	ret z			; "." : stay (carry is clear)
	cp '.'
	jr nz,fcd_bad
	inc hl
	ld a,(hl)
	or a
	jr nz,fcd_bad
	ld hl,(fs_cwd)		; ".." : in the root it changes nothing
	ld a,h
	or l
	ret z
	ld hl,1 		; entry 1 of a subdirectory is ".."
	ld (fs_dirix),hl
	call dir_get
	ret c
	ld a,(hl)
	cp '.'
	jr nz,fcd_broken
	inc hl
	ld a,(hl)
	cp '.'
	jr nz,fcd_broken
	dec hl
	jr fcd_go
fcd_name:
	call fs_name83
	ret c
	call dir_find
	ret c
	call de_attr
	and ATTR_DIR
	ld a,FS_ENOTDIR
	scf
	ret z
fcd_go: ld de,DE_CLUS		; the directory's first cluster becomes fs_cwd
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld (fs_cwd),hl
	or a
	ret
fcd_bad:
	ld a,FS_EPATH
	scf
	ret
fcd_broken:
	ld a,FS_EBAD
	scf
	ret

; ---------------------------------------------------------------- make
fs_mkdir:
	call fs_name83
	ret c
	call dir_find		; the name must be new
	jr c,fmd_1
	ld a,FS_EEXIST
	scf
	ret
fmd_1:	cp FS_ENOTF
	scf
	ret nz
	call dir_free		; an entry for it (a subdirectory may grow here)
	ret c
	ld hl,(fs_dirix)
	ld (fs_t2),hl
	call fat_alloc		; and a cluster
	ret c
	ld (fs_t1),hl
	call fs_zclus		; zeros everywhere; SECBUF is all zeros after this
	ret c
	ld hl,SECBUF		; first sector: "." and ".."
	ld de,(fs_t1)
	ld a,ATTR_DIR
	call fs_fillent
	ld hl,SECBUF
	ld (hl),'.'
	ld hl,SECBUF+32
	ld de,(fs_cwd)
	ld a,ATTR_DIR
	call fs_fillent
	ld hl,SECBUF+32
	ld (hl),'.'
	inc hl
	ld (hl),'.'
	ld hl,(fs_t1)
	call fs_cl2lba
	ld de,SECBUF
	call md_write
	ld a,FS_EWRITE
	ret c
	ld hl,(fs_t2)		; now the entry in the parent
	ld (fs_dirix),hl
	call dir_get
	ret c
	push hl
	ld de,(fs_t1)		; a directory, at the new cluster ...
	ld a,ATTR_DIR
	call fs_fillent
	pop de
	ld hl,fs_fname		; ... with the new name (still in fs_fname)
	ld bc,11
	ldir
	call dir_put
	ret c
	jp fs_flush

fs_fillent:			; HL = entry: blank name, attribute A, cluster DE,
	push hl 		; size 0, today's date
	push af
	ld b,11
ffe_1:	ld (hl),' '
	inc hl
	djnz ffe_1
	pop af
	ld (hl),a		; 11: attributes
	inc hl
	ld b,10 		; 12-21: zero
ffe_2:	ld (hl),0
	inc hl
	djnz ffe_2
	ld a,(fs_ftime) 	; 22: time, 24: date
	ld (hl),a
	inc hl
	ld a,(fs_ftime+1)
	ld (hl),a
	inc hl
	ld a,(fs_fdate)
	ld (hl),a
	inc hl
	ld a,(fs_fdate+1)
	ld (hl),a
	inc hl
	ld (hl),e		; 26: first cluster
	inc hl
	ld (hl),d
	inc hl
	ld b,4			; 28: size 0
ffe_3:	ld (hl),0
	inc hl
	djnz ffe_3
	pop hl
	ret

fs_cl2lba:			; HL = cluster -> HL = its first sector
	dec hl
	dec hl
	ld a,(fs_cshift)
	sub 9
	jr z,fsc_2
fsc_1:	add hl,hl
	dec a
	jr nz,fsc_1
fsc_2:	ld de,(fs_datalba)
	add hl,de
	ret

; ---------------------------------------------------------------- remove
fs_rmdir:
	call fs_name83
	ret c
	call dir_find
	ret c
	call de_attr
	and ATTR_DIR
	ld a,FS_ENOTDIR
	scf
	ret z
	call de_clus
	ld (fs_t1),hl		; its cluster
	ld hl,(fs_dirix)
	ld (fs_t2),hl		; its entry in the parent
	ld hl,(fs_cwd)
	ld (fs_t3),hl		; the parent
	ld hl,(fs_t1)		; look inside: anything but "." and ".."?
	ld (fs_cwd),hl
	call dir_first
frd_1:	jr c,frd_end
	ld a,(hl)
	cp '.'
	jr nz,frd_full
	call dir_next
	jr frd_1
frd_end:
	ld hl,(fs_t3)		; (back in the parent before anything else)
	ld (fs_cwd),hl
	cp FS_EEND
	scf
	ret nz			; a read error
	ld hl,(fs_t1)		; empty: free its clusters ...
	call fat_freechain
	ld hl,(fs_t2)		; ... and mark its entry deleted
	ld (fs_dirix),hl
	call dir_get
	ret c
	ld (hl),0E5h
	call dir_put
	ret c
	jp fs_flush
frd_full:
	ld hl,(fs_t3)
	ld (fs_cwd),hl
	ld a,FS_ENOTEMPTY
	scf
	ret
