; ==========================================================================
; MOUNT.ASM - read a FAT12 disk's boot sector and FAT, work out the layout.
;
;   fs_mount               CF = failed, A = FS_E... code
;   fs_flush               write the FAT (if changed) and the cached track.  CF = failed
; fs_mount keeps fs_cwd (the current directory) if it is still valid on the disk.
;   fs_errmsg   A = code   HL = message text for an error code
;
; A FAT12 disk is, in sectors (LBA):
;   0                     boot sector: its BIOS parameter block (BPB) says how
;                         big everything below is
;   fs_fatlba ...         FAT 1, then FAT 2 (a copy)
;   fs_rootlba ...        root directory: fs_rootents entries of 32 bytes
;   fs_datalba ...        data, in clusters numbered from 2
; The whole FAT is kept in FATBUF, so following a file's chain costs no disk
; reads.  (A 360K disk has a 2-sector FAT.)
; ==========================================================================

FS_MAXFAT:  equ 2	   ; FATBUF holds 2 sectors: a 360K disk's FAT

; BPB fields in the boot sector
BPB_BPS:    equ 11	   ; word: bytes per sector (must be 512)
BPB_SPC:    equ 13	   ; byte: sectors per cluster
BPB_RES:    equ 14	   ; word: reserved sectors (boot sector included)
BPB_NFAT:   equ 16	   ; byte: number of FATs
BPB_ROOT:   equ 17	   ; word: root directory entries
BPB_TOTAL:  equ 19	   ; word: total sectors
BPB_SPF:    equ 22	   ; word: sectors per FAT
BPB_SPT:    equ 24	   ; word: sectors per track
BPB_HEADS:  equ 26	   ; word: sides

fs_mount:
	call md_drop		; a new disk: nothing cached from the old one is valid
	xor a			; (so flush before changing disks!)
	ld (fs_mounted),a
	call md_present 	; an empty drive: say so at once, instead of trying
	ld a,FS_ENODISK 	; every read for seconds
	ret c
	xor a
	ld (fs_fatdirty),a
	ld hl,FS_DEFDATE	; date stamped on new files (a program may change it)
	ld (fs_fdate),hl
	ld hl,0
	ld (fs_ftime),hl
	ld hl,2
	ld (fs_hint),hl
	ld hl,0FFFFh
	ld (fs_dirsec),hl	; DIRBUF no longer holds anything we trust

	ld hl,0 		; boot sector -> SECBUF
	ld de,SECBUF
	call md_read
	jp c,fs_m_read

	ld hl,(SECBUF+BPB_BPS)	; 512 bytes per sector, nothing else
	ld de,512
	or a
	sbc hl,de
	jp nz,fs_m_fmt

	ld a,(SECBUF+BPB_SPC)	; sectors per cluster: 1, 2, 4 ... 64
	ld (fs_spc),a
	ld b,9			; log2(512)
fs_m1:	or a
	jp z,fs_m_fmt		; 0 is not allowed
	cp 1
	jr z,fs_m2
	bit 0,a 		; an odd number above 1 is not a power of two
	jp nz,fs_m_fmt
	srl a
	inc b
	jr fs_m1
fs_m2:	ld a,b
	ld (fs_cshift),a
	ld hl,512		; bytes per cluster = 512 << (cshift - 9)
	sub 9
	jr z,fs_m4
fs_m3:	add hl,hl
	dec a
	jr nz,fs_m3
fs_m4:	ld (fs_bpc),hl

	ld a,(SECBUF+BPB_NFAT)	; one or two FATs
	ld (fs_nfats),a
	or a
	jp z,fs_m_fmt
	cp 3
	jp nc,fs_m_fmt

	ld hl,(SECBUF+BPB_SPF)	; FAT size: must fit in FATBUF
	ld a,h
	or a
	jp nz,fs_m_fmt
	ld a,l
	or a
	jp z,fs_m_fmt
	cp FS_MAXFAT+1
	jp nc,fs_m_fmt
	ld (fs_fatsecs),a

	call md_geom		; what the drive can read (the machine layer says):
	ld a,d			; with tracks, the disk's must be the drive's
	or a
	jr z,fs_m_g1
	ld a,(SECBUF+BPB_SPT+1)
	ld b,a
	ld a,(SECBUF+BPB_HEADS+1)
	or b
	jp nz,fs_m_geom
	ld a,(SECBUF+BPB_SPT)
	cp d
	jp nz,fs_m_geom
	ld a,(SECBUF+BPB_HEADS)
	cp e
	jp nz,fs_m_geom
fs_m_g1:
	ex de,hl		; DE = the drive's sectors
	ld hl,(SECBUF+BPB_TOTAL)
	ld a,h
	or l
	jp z,fs_m_fmt		; 0 here means a disk over 32 MB
	ld (fs_total),hl
	scf			; no more sectors than the drive has
	sbc hl,de
	jp nc,fs_m_geom

	ld hl,(SECBUF+BPB_RES)	; FAT 1 starts after the reserved sectors
	ld (fs_fatlba),hl

	ld a,(fs_nfats) 	; root = fatlba + nfats * fatsecs
	ld b,a
	ld a,(fs_fatsecs)
	ld e,a
	ld d,0
fs_m5:	add hl,de
	djnz fs_m5
	ld (fs_rootlba),hl

	ld hl,(SECBUF+BPB_ROOT) ; root sectors = (entries + 15) / 16
	ld (fs_rootents),hl
	ld de,15
	add hl,de
	ld b,4
fs_m6:	srl h
	rr l
	djnz fs_m6
	ld a,l
	ld (fs_rootsecs),a
	ld de,(fs_rootlba)	; data = root + root sectors
	add hl,de
	ld (fs_datalba),hl

	ex de,hl		; clusters = (total - data) / spc
	ld hl,(fs_total)
	or a
	sbc hl,de
	jp c,fs_m_fmt
	ld a,(fs_spc)
fs_m7:	srl a
	jr z,fs_m8		; done when spc is shifted down to 0 (from 1)
	srl h
	rr l
	jr fs_m7
fs_m8:	ld (fs_nclus),hl
	ld de,4085		; 4085 clusters and up is FAT16, not FAT12
	or a
	sbc hl,de
	jp nc,fs_m_fmt
	ld hl,(fs_nclus)
	inc hl
	inc hl
	ld (fs_clend),hl

	ld a,(fs_fatsecs)	; read FAT 1 into FATBUF
	ld b,a
	ld hl,(fs_fatlba)
	ld de,FATBUF
fs_m9:	push bc
	push hl
	push de
	call md_read
	pop de
	pop hl
	pop bc
	jr c,fs_m_read
	inc hl			; next sector
	inc d			; DE += 512
	inc d
	djnz fs_m9

	ld a,1
	ld (fs_mounted),a
	call fs_chkcwd		; is the current directory still there?
	xor a			; carry clear
	ret

fs_chkcwd:			; fs_cwd must be a directory on THIS disk: in range,
	ld hl,(fs_cwd)		; and its first entry must be "." (the disk may have
	ld a,h			; been changed, or fs_cwd may be left over from
	or l			; something else).  Otherwise: back to the root.
	ret z
	ld de,2
	or a
	sbc hl,de
	jr c,fs_cc_root
	ld hl,(fs_cwd)
	ld de,(fs_clend)
	or a
	sbc hl,de
	jr nc,fs_cc_root
	ld hl,0
	ld (fs_dirix),hl
	call dir_get
	jr c,fs_cc_root
	ld a,(hl)
	cp '.'
	jr nz,fs_cc_root
	inc hl
	ld a,(hl)
	cp ' '
	jr nz,fs_cc_root
	ld de,DE_ATTR-1
	add hl,de
	ld a,(hl)
	and ATTR_DIR
	ret nz
fs_cc_root:
	ld hl,0
	ld (fs_cwd),hl
	ret

fs_m_read:
	ld a,FS_EREAD
	scf
	ret
fs_m_fmt:
	ld a,FS_EFMT
	scf
	ret
fs_m_geom:
	ld a,FS_EGEOM
	scf
	ret

fs_flush:			; everything changed in memory goes to the disk
	call fat_flush
	ret c
	call md_flush
	ret nc
	ld a,FS_EWRITE
	ret

fs_errmsg:			; A = error code -> HL = message
	ld hl,fs_msgs
	or a
	ret z
	ld b,a
fs_e1:	ld a,(hl)		; skip one zero-terminated string per count
	inc hl
	or a
	jr nz,fs_e1
	djnz fs_e1
	ret

fs_msgs:
	defm "end of directory"
	defb 0
	defm "disk read error"
	defb 0
	defm "not a FAT12 disk"
	defb 0
	defm "not a disk this drive takes"
	defb 0
	defm "broken cluster chain"
	defb 0
	defm "file not found"
	defb 0
	defm "bad file name"
	defb 0
	defm "that is a directory"
	defb 0
	defm "disk full"
	defb 0
	defm "directory full"
	defb 0
	defm "name exists"
	defb 0
	defm "disk write error"
	defb 0
	defm "not a directory"
	defb 0
	defm "directory not empty"
	defb 0
	defm "bad path"
	defb 0
	defm "no disk (or door open)"
	defb 0
	defm "the file is read-only"
	defb 0
