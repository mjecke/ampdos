; ==========================================================================
; FILE.ASM - find a file by name, open it and read it.
;
;   fs_name83   HL = name ("readme.md")   fs_fname = "README  MD ", CF = bad name
;   dir_find    fs_fname                  HL = its directory entry, CF = not found
;   f_open      IX = FCB, HL = name       CF = failed, A = FS_E... code
;   f_read      IX = FCB, DE = destination, BC = bytes wanted
;               BC = bytes delivered (fewer only at the end of the file;
;               0 = end of file).  CF = failed, A = code
;   f_create    IX = FCB, HL = name       make an empty file (an old one of that
;                                         name is emptied), open for writing
;   f_write     IX = FCB, DE = source, BC = bytes    add them at the end of the file
;   f_close     IX = FCB                  after writing: update the directory entry,
;                                         write FAT and data to the disk
;   f_delete    HL = name
;   f_delent    HL = its entry (from dir_first / dir_next): delete that file
;   f_rename    HL = old name, DE = new name
; All return CF = failed with A = code.  Writing changes the FAT in memory and
; sectors in the driver's track cache; nothing is safe on the disk until
; f_close (or fs_flush) has returned without an error.
;
; A file is read one sector at a time through md_read (the machine layer), which keeps the
; whole track in its cache, so reading a file in order costs one disk read
; per 9 sectors.  The sector holding byte "pos" of a file is
;     datalba + (cluster - 2) * spc + (pos / 512) mod spc
; where "cluster" is the pos / bytes-per-cluster'th cluster of the chain.
; FCB_CLUS keeps that cluster, and moves one step along the chain each time
; pos reaches a cluster boundary.
; ==========================================================================

; ---------------------------------------------------------------- names
fs_name83:
	push bc
	push de
	push hl
	ld hl,fs_fname		; start from all spaces
	ld b,11
fn_1:	ld (hl),' '
	inc hl
	djnz fn_1
	pop hl
	push hl
	ld de,fs_fname
	ld b,8			; the name part: 1 to 8 characters
	call fn_part
	jr c,fn_bad
	ld a,b
	cp 8
	jr z,fn_bad		; nothing before the dot
	ld a,(hl)
	cp '.'
	jr nz,fn_end
	inc hl
	ld de,fs_fname+8
	ld b,3			; the extension: 0 to 3 characters
	call fn_part
	jr c,fn_bad
	ld a,(hl)
	cp '.'
	jr z,fn_bad		; a second dot
fn_end: call fn_term
	jr nz,fn_bad		; something left over
	pop hl
	pop de
	pop bc
	or a
	ret
fn_bad: pop hl
	pop de
	pop bc
	ld a,FS_ENAME
	scf
	ret

fn_part:			; copy up to B characters to DE.  Stops at '.' or the end.
	ld a,(hl)		; B = room left on return; CF = too long or bad character
	cp '.'
	ret z
	call fn_term
	ret z
	call fn_char
	ret c
	inc b			; no room left? (test B = 0 without losing it)
	dec b
	scf
	ret z
	ld (de),a
	inc de
	inc hl
	dec b
	jr fn_part

fn_term:			; Z = (HL) ends the name: 0, space or CR
	ld a,(hl)
	or a
	ret z
	cp ' '
	ret z
	cp 13
	ret

fn_char:			; A = a name character -> upper case, CF = not allowed
	cp 'a'
	jr c,fc_1
	cp 'z'+1
	jr nc,fc_1
	sub 20h 		; lower to upper case
	or a
	ret
fc_1:	cp 'A'
	jr c,fc_2
	cp 'Z'+1
	ccf
	ret nc
fc_2:	cp '0'
	jr c,fc_3
	cp '9'+1
	ccf
	ret nc
fc_3:	push hl 		; the punctuation DOS allows in names
	push bc
	ld hl,fc_ok
	ld bc,fc_okn
	cpir			; Z = found (CPIR leaves the carry flag alone)
	pop bc
	pop hl
	jr nz,fc_no
	or a			; allowed: clear the carry
	ret
fc_no:	scf
	ret
fc_ok:	defm "!#$%&'()-@^_`{}~"
fc_okn: equ $-fc_ok

; ---------------------------------------------------------------- find
dir_find:
	call dir_first
df_1:	jr c,df_end
	push hl
	ld de,fs_fname
	ld b,11
df_2:	ld a,(de)
	cp (hl)
	jr nz,df_3
	inc hl
	inc de
	djnz df_2
	pop hl			; all 11 the same
	or a
	ret
df_3:	pop hl
	call dir_next
	jr df_1
df_end: cp FS_EEND
	scf
	ret nz			; a read error stays a read error
	ld a,FS_ENOTF
	ret

; ---------------------------------------------------------------- open
f_open:
	call fs_name83
	ret c
	call dir_find
	ret c
	call de_attr
	and ATTR_DIR
	jr z,fo_1
	ld a,FS_EISDIR
	scf
	ret
fo_1:	ld de,DE_CLUS
	add hl,de
	ld a,(hl)
	ld (ix+FCB_FIRST),a
	ld (ix+FCB_CLUS),a
	inc hl
	ld a,(hl)
	ld (ix+FCB_FIRST+1),a
	ld (ix+FCB_CLUS+1),a
	inc hl			; HL = DE_SIZE
	ld b,4
	push ix
fo_2:	ld a,(hl)
	ld (ix+FCB_SIZE),a
	ld (ix+FCB_POS),0
	inc hl
	inc ix
	djnz fo_2
	pop ix
	ld hl,(fs_dirix)
	ld (ix+FCB_DIRIX),l
	ld (ix+FCB_DIRIX+1),h
	ld (ix+FCB_MODE),0
	or a
	ret

; ---------------------------------------------------------------- read
f_read:
	ld (f_dest),de
	ld (f_cnt),bc
	ld hl,0
	ld (f_done),hl
fr_loop:
	ld hl,(f_cnt)		; all delivered?
	ld a,h
	or l
	jp z,fr_done
	call f_left		; HL = bytes left in the file (at most FFFFh)
	ld a,h
	or l
	jp z,fr_done		; end of file
	ld de,(f_cnt)		; n = min(left, wanted, rest of this sector)
	call f_min
	push hl
	ld a,(ix+FCB_POS+1)	; rest of sector = 512 - (pos mod 512)
	and 1
	ld d,a
	ld e,(ix+FCB_POS)
	ld hl,512
	or a
	sbc hl,de
	ex de,hl
	pop hl
	call f_min
	push hl 		; n on the stack

	call f_seclba		; read the sector that holds pos
	ld de,SECBUF
	call md_read
	jp c,fr_rerr

	ld a,(ix+FCB_POS+1)	; copy n bytes from SECBUF + pos mod 512
	and 1
	ld h,a
	ld l,(ix+FCB_POS)
	ld de,SECBUF
	add hl,de
	ld de,(f_dest)
	pop bc
	push bc
	ldir
	ld (f_dest),de

	pop bc			; count it everywhere
	ld hl,(f_cnt)
	or a
	sbc hl,bc
	ld (f_cnt),hl
	ld hl,(f_done)
	add hl,bc
	ld (f_done),hl
	ld a,(ix+FCB_POS)	; pos = pos + n (32 bits)
	add a,c
	ld (ix+FCB_POS),a
	ld a,(ix+FCB_POS+1)
	adc a,b
	ld (ix+FCB_POS+1),a
	ld a,(ix+FCB_POS+2)
	adc a,0
	ld (ix+FCB_POS+2),a
	ld a,(ix+FCB_POS+3)
	adc a,0
	ld (ix+FCB_POS+3),a

	ld hl,(fs_bpc)		; on a cluster boundary, with more to come?
	dec hl
	ld a,(ix+FCB_POS)
	and l
	jp nz,fr_loop
	ld a,(ix+FCB_POS+1)
	and h
	jp nz,fr_loop
	call f_left
	ld a,h
	or l
	jp z,fr_loop		; that was the end of the file
	ld l,(ix+FCB_CLUS)	; step along the chain
	ld h,(ix+FCB_CLUS+1)
	call fat_next
	jp c,fr_berr
	ld (ix+FCB_CLUS),l
	ld (ix+FCB_CLUS+1),h
	jp fr_loop

fr_done:
	ld bc,(f_done)
	or a
	ret
fr_rerr:
	pop bc
	ld a,FS_EREAD
	scf
	ret
fr_berr:
	ld a,FS_EBAD		; the chain ended before the file did
	scf
	ret

f_left: 			; HL = size - pos, or FFFFh if that is bigger
	ld a,(ix+FCB_SIZE)
	sub (ix+FCB_POS)
	ld l,a
	ld a,(ix+FCB_SIZE+1)
	sbc a,(ix+FCB_POS+1)
	ld h,a
	ld a,(ix+FCB_SIZE+2)
	sbc a,(ix+FCB_POS+2)
	ld e,a
	ld a,(ix+FCB_SIZE+3)
	sbc a,(ix+FCB_POS+3)
	or e
	ret z
	ld hl,0FFFFh
	ret

f_min:				; HL = the smaller of HL and DE
	or a
	sbc hl,de
	add hl,de
	ret c
	ex de,hl
	ret

f_seclba:			; HL = sector holding pos
	ld l,(ix+FCB_CLUS)
	ld h,(ix+FCB_CLUS+1)
	dec hl			; (cluster - 2) * spc
	dec hl
	ld a,(fs_cshift)
	sub 9
	jr z,fs_sl2
fs_sl1: add hl,hl
	dec a
	jr nz,fs_sl1
fs_sl2: ld de,(fs_datalba)
	add hl,de
	ld a,(ix+FCB_POS+1)	; + (pos / 512) mod spc
	srl a
	ld e,a
	ld a,(fs_spc)
	dec a
	and e
	ld e,a
	ld d,0
	add hl,de
	ret

; ---------------------------------------------------------------- create
f_create:
	call fs_name83
	ret c
	call dir_find
	jr nc,fcr_old
	cp FS_ENOTF
	scf
	ret nz			; a real error
	call dir_free		; a new file: take a free entry
	ret c
	jr fcr_fill
fcr_old:
	call fs_canchg		; the name exists: a file, not read-only ...
	ret c
				; ... and it is emptied: free its clusters
	push hl
	call de_clus
	call fat_freechain
	pop hl
fcr_fill:			; HL = the entry: name, attributes, date, no data
	ex de,hl
	ld hl,fs_fname
	ld bc,11
	ldir
	ex de,hl		; HL = entry + 11
	ld (hl),ATTR_ARC
	inc hl
	ld b,10 		; 12..21: reserved, zero
fcr_f1: ld (hl),0
	inc hl
	djnz fcr_f1
	ld de,(fs_ftime)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld de,(fs_fdate)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld b,6			; first cluster 0, size 0
fcr_f2: ld (hl),0
	inc hl
	djnz fcr_f2
	call dir_put
	ret c
	push ix 		; the FCB: all zero ...
	pop hl
	ld b,FCB_LEN
fcr_f3: ld (hl),0
	inc hl
	djnz fcr_f3
	ld hl,(fs_dirix)	; ... except where the entry is, and the mode
	ld (ix+FCB_DIRIX),l
	ld (ix+FCB_DIRIX+1),h
	ld (ix+FCB_MODE),1
	or a
	ret

; ---------------------------------------------------------------- write
f_write:
	ld (f_dest),de		; (here: where the data comes from)
	ld (f_cnt),bc
fw_loop:
	ld hl,(f_cnt)
	ld a,h
	or l
	jp z,fw_done
	ld hl,(fs_bpc)		; at a cluster boundary the file needs a new cluster
	dec hl
	ld a,(ix+FCB_POS)
	and l
	jr nz,fw_have
	ld a,(ix+FCB_POS+1)
	and h
	jr nz,fw_have
	call fat_alloc		; HL = new cluster, already marked "last"
	ret c
	ld a,(ix+FCB_FIRST)	; the file's first cluster, or a link from the last one
	or (ix+FCB_FIRST+1)
	jr nz,fw_link
	ld (ix+FCB_FIRST),l
	ld (ix+FCB_FIRST+1),h
	jr fw_set
fw_link:
	push hl
	ex de,hl		; DE = new cluster
	ld l,(ix+FCB_CLUS)
	ld h,(ix+FCB_CLUS+1)
	call fat_set		; old last cluster -> new cluster
	pop hl
fw_set: ld (ix+FCB_CLUS),l
	ld (ix+FCB_CLUS+1),h
fw_have:
	ld a,(ix+FCB_POS+1)	; n = min(wanted, rest of this sector)
	and 1
	ld d,a
	ld e,(ix+FCB_POS)
	ld hl,512
	or a
	sbc hl,de
	ex de,hl
	ld hl,(f_cnt)
	call f_min
	push hl 		; n on the stack

	call f_seclba
	ld (f_lba),hl
	ld a,(ix+FCB_POS+1)	; a fresh sector starts all zero; a sector that
	and 1			; already holds the start of this file is read first
	or (ix+FCB_POS)
	jr nz,fw_old
	ld hl,SECBUF
	ld de,SECBUF+1
	ld bc,511
	ld (hl),0
	ldir
	jr fw_copy
fw_old: ld hl,(f_lba)
	ld de,SECBUF
	call md_read
	jr c,fw_rerr
fw_copy:
	ld a,(ix+FCB_POS+1)	; copy n bytes to SECBUF + pos mod 512
	and 1
	ld d,a
	ld e,(ix+FCB_POS)
	ld hl,SECBUF
	add hl,de
	ex de,hl
	ld hl,(f_dest)
	pop bc
	push bc
	ldir
	ld (f_dest),hl
	ld hl,(f_lba)		; into the track cache
	ld de,SECBUF
	call md_write
	jr c,fw_werr

	pop bc			; count it
	ld hl,(f_cnt)
	or a
	sbc hl,bc
	ld (f_cnt),hl
	ld a,(ix+FCB_POS)	; pos = pos + n, and the size grows with it
	add a,c
	ld (ix+FCB_POS),a
	ld (ix+FCB_SIZE),a
	ld a,(ix+FCB_POS+1)
	adc a,b
	ld (ix+FCB_POS+1),a
	ld (ix+FCB_SIZE+1),a
	ld a,(ix+FCB_POS+2)
	adc a,0
	ld (ix+FCB_POS+2),a
	ld (ix+FCB_SIZE+2),a
	ld a,(ix+FCB_POS+3)
	adc a,0
	ld (ix+FCB_POS+3),a
	ld (ix+FCB_SIZE+3),a
	jp fw_loop
fw_done:
	or a
	ret
fw_rerr:
	pop bc
	ld a,FS_EREAD
	scf
	ret
fw_werr:
	pop bc
	ld a,FS_EWRITE
	scf
	ret

; ---------------------------------------------------------------- close
f_close:
	ld a,(ix+FCB_MODE)
	or a
	ret z			; opened for reading: nothing to do
	ld l,(ix+FCB_DIRIX)	; the entry gets the first cluster and the size
	ld h,(ix+FCB_DIRIX+1)
	ld (fs_dirix),hl
	call dir_get
	ret c
	ld de,DE_CLUS
	add hl,de
	ld a,(ix+FCB_FIRST)
	ld (hl),a
	inc hl
	ld a,(ix+FCB_FIRST+1)
	ld (hl),a
	inc hl
	ld b,4
	push ix
fcl_1:	ld a,(ix+FCB_SIZE)
	ld (hl),a
	inc hl
	inc ix
	djnz fcl_1
	pop ix
	call dir_put
	ret c
	ld (ix+FCB_MODE),0
	jp fs_flush

; ---------------------------------------------------------------- delete
f_delete:
	call fs_name83
	ret c
	call dir_find
	ret c
	call fs_canchg
	ret c
	call f_delent
	ret c
	jp fs_flush

fs_canchg:			; HL = an entry: CF with A = FS_EISDIR or FS_ERO if it may
	call de_attr		; not be emptied or deleted (HL kept, DE not)
	ld e,FS_EISDIR
	bit 4,a
	jr nz,fcc_no
	ld e,FS_ERO
	rra			; (read-only: bit 0)
	ret nc
fcc_no: ld a,e
	scf
	ret

f_delent:			; HL = a file's directory entry (in DIRBUF): free its
	push hl 		; clusters, mark the entry deleted, write the sector
	call de_clus	; back.  The FAT is not flushed.  CF = failed
	call fat_freechain
	pop hl
	ld (hl),0E5h		; the DOS mark for a deleted entry
	jp dir_put

; ---------------------------------------------------------------- rename
f_rename:
	push hl 		; the new name first: valid, and not in use
	ex de,hl
	call fs_name83
	jr c,frn_pop
	ld hl,fs_fname
	ld de,fs_fname2
	ld bc,11
	ldir
	call dir_find
	jr nc,frn_exists
	cp FS_ENOTF
	jr nz,frn_err
	pop hl			; then the old name
	call fs_name83
	ret c
	call dir_find
	ret c
	ex de,hl
	ld hl,fs_fname2
	ld bc,11
	ldir
	call dir_put
	ret c
	jp fs_flush
frn_exists:
	ld a,FS_EEXIST
frn_err:
	scf
frn_pop:
	pop hl
	ret
