; ==========================================================================
; DIRENT.ASM - walk the current directory: the root, or a subdirectory.
;
; The root directory has a fixed place and size (fs_rootlba, fs_rootents).
; A subdirectory is stored like a file: a chain of clusters, starting at
; fs_cwd, each holding 16 entries per sector.  Its first two entries are "."
; (itself) and ".." (its parent, cluster 0 = the root).  It has no fixed
; size: dir_free makes it a cluster longer when it is full.
; The entries are numbered from 0 (fs_dirix) either way.
;
;   dir_first            HL = first entry in use, NC
;   dir_next             HL = next entry in use,  NC
;                        both: CF with A = FS_EEND at the end, FS_EREAD on a read error
;   dir_get              HL = entry number fs_dirix, whatever it holds (CF past the end)
;   dir_free             HL = a free entry (never used, or deleted), fs_dirix = its number;
;                        a full subdirectory grows by a cluster; a full root
;                        directory gives CF with A = FS_EDIRFULL
;   fs_zclus   HL = cluster    write zeros to all its sectors
;   dir_put              write DIRBUF (the sector holding the entry) back.  CF = failed
;   de_attr   HL = entry  A = its attributes (HL kept)
;   de_clus   HL = entry  HL = its first cluster
;
; The returned HL points into DIRBUF, which holds one directory sector
; (16 entries).  It stays valid until the next dir_... call.
; "In use" skips deleted entries (first byte E5h), long-name pieces (attribute
; 0Fh) and the volume label; it stops at an entry whose first byte is 00h,
; which marks the end of the used part of the directory.
; ==========================================================================

dir_first:
	ld hl,0
	ld (fs_dirix),hl
	jr dir_scan

dir_next:
	ld hl,(fs_dirix)
	inc hl
	ld (fs_dirix),hl
	; fall into dir_scan

dir_scan:
	call dir_get
	ret c
	ld a,(hl)
	or a
	jr z,dir_s_end		; 00: nothing after this
	cp 0E5h
	jr z,dir_s_skip 	; deleted
	call de_attr
	cp ATTR_LFN
	jr z,dir_s_skip 	; a long-name piece
	and ATTR_VOL
	jr nz,dir_s_skip	; the volume label
	or a			; NC: HL = an entry in use
	ret
dir_s_skip:
	ld hl,(fs_dirix)
	inc hl
	ld (fs_dirix),hl
	jr dir_scan
dir_s_end:
	ld a,FS_EEND
	scf
	ret

dir_get:
	ld hl,(fs_cwd)
	ld a,h
	or l
	jr nz,dir_g_sub
	ld hl,(fs_dirix)	; the root: past the last entry?
	ld de,(fs_rootents)
	or a
	sbc hl,de
	jr nc,dir_s_end
	add hl,de		; HL = index again
	ld b,4			; sector = rootlba + index / 16
dir_g1: srl h
	rr l
	djnz dir_g1
	ld de,(fs_rootlba)
	add hl,de
	jr dir_g_lba
dir_g_sub:			; a subdirectory: s = index / 16 is its s'th sector,
	ld hl,(fs_dirix)	; in cluster number s / spc of its chain
	ld b,4
dir_g3: srl h
	rr l
	djnz dir_g3
	ld a,(fs_spc)		; C = s mod spc (sector inside the cluster)
	dec a
	and l
	ld c,a
	ld a,(fs_cshift)	; HL = s / spc (how many links to follow)
	sub 9
	jr z,dir_g5
dir_g4: srl h
	rr l
	dec a
	jr nz,dir_g4
dir_g5: ex de,hl		; DE = links
	ld hl,(fs_cwd)
dir_g6: ld a,d
	or e
	jr z,dir_g7
	push de
	push bc
	call fat_next
	pop bc
	pop de
	jp c,dir_s_end		; the chain is shorter: past the end
	dec de
	jr dir_g6
dir_g7: dec hl			; lba = datalba + (cluster - 2) * spc + C
	dec hl
	ld a,(fs_cshift)
	sub 9
	jr z,dir_g9
dir_g8: add hl,hl
	dec a
	jr nz,dir_g8
dir_g9: ld de,(fs_datalba)
	add hl,de
	ld b,0
	add hl,bc
dir_g_lba:
	ld de,(fs_dirsec)	; already in DIRBUF?
	or a
	sbc hl,de
	add hl,de
	jr z,dir_g2
	ld (fs_dirsec),hl
	ld de,DIRBUF
	call md_read
	jr nc,dir_g2
	ld hl,0FFFFh		; read error: forget the buffer
	ld (fs_dirsec),hl
	ld a,FS_EREAD
	scf
	ret
dir_g2: ld a,(fs_dirix) 	; HL = DIRBUF + (index mod 16) * 32
	and 0Fh
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,DIRBUF
	add hl,de
	or a
	ret

dir_free:
	ld hl,0
	ld (fs_dirix),hl
dir_f1: call dir_get
	jr c,dir_f_full
	ld a,(hl)
	or a
	ret z			; 00: never used (carry is clear)
	cp 0E5h
	ret z			; deleted
	ld hl,(fs_dirix)
	inc hl
	ld (fs_dirix),hl
	jr dir_f1
dir_f_full:
	cp FS_EREAD
	scf
	ret z
	ld hl,(fs_cwd)		; the root cannot grow
	ld a,h
	or l
	ld a,FS_EDIRFULL
	scf
	ret z
	call dir_grow		; a subdirectory gets one more cluster
	ret c
	jr dir_f1		; and the same entry number is free now

dir_grow:			; add a zeroed cluster to the current subdirectory
	ld hl,(fs_cwd)		; find its last cluster
dir_gr1:
	push hl
	call fat_next
	jr c,dir_gr2
	pop de
	jr dir_gr1
dir_gr2:
	pop hl			; HL = last cluster
	cp FS_EEND
	ld a,FS_EBAD
	scf
	ret nz
	push hl
	call fat_alloc		; HL = new cluster, marked "last"
	pop de
	ret c
	push hl
	ex de,hl		; old last -> new
	call fat_set
	pop hl
	jp fs_zclus

fs_zclus:			; write zeros to every sector of cluster HL. CF = failed
	dec hl
	dec hl
	ld a,(fs_cshift)
	sub 9
	jr z,fs_zc2
fs_zc1: add hl,hl
	dec a
	jr nz,fs_zc1
fs_zc2: ld de,(fs_datalba)
	add hl,de		; HL = its first sector
	push hl
	ld hl,SECBUF		; a sector of zeros
	ld de,SECBUF+1
	ld bc,511
	ld (hl),0
	ldir
	pop hl
	ld a,(fs_spc)
	ld b,a
fs_zc3: push bc
	push hl
	ld de,SECBUF
	call md_write
	pop hl
	pop bc
	ld a,FS_EWRITE
	ret c
	inc hl
	djnz fs_zc3
	or a
	ret

dir_put:
	ld hl,(fs_dirsec)
	ld de,DIRBUF
	call md_write
	ret nc
	ld a,FS_EWRITE
	ret

de_attr:			; HL = a directory entry -> A = its attributes
	push hl 		; (HL kept; DE = DE_ATTR)
	ld de,DE_ATTR
	add hl,de
	ld a,(hl)
	pop hl
	ret

de_clus:			; HL = a directory entry -> HL = its first cluster
	ld de,DE_CLUS		; (DE = DE_CLUS, A = its low byte)
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret
