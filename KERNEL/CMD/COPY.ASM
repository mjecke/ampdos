; ==========================================================================
; COPY.ASM - DEL, MV and COPY.
;
;   DEL [d:][path\]name           MV from to   (rename, or move: COPY + DEL)
;   COPY from [to]                both may have a drive and a path; "to" may
;                                 also be just a directory (B:  SUB  ..\X\),
;                                 then the copy keeps the source's name; no
;                                 "to" at all means the current directory
; DEL and COPY take wildcards in the name (WILD.ASM):  DEL *.TMP  COPY *.* B:
; DEL *.* asks first.  Wildcards leave out directories, and hidden, system
; (and for DEL read-only) files.  COPY with wildcards copies into a directory.
; COPY reads as much as fits in the TPA, then writes it, and so on.
; Between two drives it takes turns: before leaving the destination disk its
; FAT goes to the disk (fs_flush), and each disk is mounted again on the way
; back in, so the FAT in memory always belongs to the disk being used.  In
; one drive no turns are needed (reading does not depend on the directory).
; The copy gets the source's date, as DOS does.
; ==========================================================================

cmd_del:
	call sh_open1
	ret c
	call wc_make
	jp c,sh_err
	ld a,(wc_on)
	or a
	jr nz,cdl_wild
	call f_delete
	jp c,sh_err
	ret
cdl_wild:
	ld hl,wc_pat		; *.*: ask first
	ld b,11
cdl_1:	ld a,(hl)
	cp '?'
	jr nz,cdl_go
	inc hl
	djnz cdl_1
	ld hl,m_cdl_all
	call sh_yes
	ret nz
cdl_go: ld hl,0
	ld (sh_nlist),hl
	call dir_first
cdl_2:	jr c,cdl_end
	call wc_match
	jr nz,cdl_3
	call de_attr
	and ATTR_DIR+ATTR_HID+ATTR_SYS+ATTR_RO
	jr nz,cdl_3
	call f_delent
	jp c,sh_err
	ld hl,(sh_nlist)
	inc hl
	ld (sh_nlist),hl
cdl_3:	call dir_next
	jr cdl_2
cdl_end:
	cp FS_EEND
	jp nz,sh_err
	call fs_flush
	jp c,sh_err
	ld hl,(sh_nlist)
	ld a,h
	or l
	ld a,FS_ENOTF
	jp z,sh_err
	ld b,0
	call con_dec16w
	ld hl,m_cdl_n
	jp con_puts

; MV from to: a new plain name renames the file, in its own directory.  When
; "to" is a drive, a path, . or .., or a directory that exists, MV moves: COPY,
; then DEL of the source if every copy worked (so it moves between drives too,
; and many files at once).
cmd_mv: call sh_need2
	ret c
	ld (sh_arg2),de
	ex de,hl
	ld a,(hl)		; . or ..: a directory
	cp '.'
	jr z,mv_go
mv_1:	ld a,(hl)		; a drive or a path: a move
	or a
	jr z,mv_2
	cp ' '
	jr z,mv_2
	cp ':'
	jr z,mv_go
	cp 5Ch
	jr z,mv_go
	cp '/'
	jr z,mv_go
	inc hl
	jr mv_1
mv_2:	call sh_mount
	ret c
	ld hl,(sh_arg2) 	; a directory that exists here: a move
	call fs_name83
	jr c,mv_ren
	call dir_find
	jr c,mv_ren
	call de_attr
	and ATTR_DIR
	jr nz,mv_go
mv_ren: ld hl,(sh_args) 	; else a new name
	call sh_resolve
	jp c,sh_err
	ld de,(sh_arg2)
	call f_rename
	jp c,sh_err
	ret
mv_go:	call cmd_copy		; the move: COPY, then DEL if it all worked
	ld a,(sh_status)
	or a
	ret nz
	jp cmd_del

; ---------------------------------------------------------------- COPY
cmd_copy:
	call sh_need1		; COPY from [to]: without "to", into the current
	ret c			; directory (an empty name part = the source's name)
	call sh_skipword
	call sh_skipsp
	ld (sh_arg2),hl
	call sh_mount
	ret c
	ld hl,(sh_args) 	; ---- the source: where, and which name(s)
	call sh_resolve
	jp c,sh_err
	call sh_noname
	jr nz,cc_s1
	call sh_fail
	ld hl,m_sh_need1
	jp con_puts
cc_s1:	call wc_make
	jp c,sh_err
	ld hl,wc_pat		; its name, tidy ("readme.md" -> "README.MD")
	ld de,fs_fname
	ld bc,11
	ldir
	ld de,sh_sname
	call sh_fname2txt
	ld a,(sh_rdrv)
	ld (sh_sdrv),a
	ld hl,(fs_cwd)
	ld (sh_scwd),hl
	ld hl,(sh_buf)		; the data goes to the memory commands may use
	ld (sh_cbuf),hl 	; (after the list of names, if there is one)
	ld hl,(sh_bufsz)
	ld (sh_cbsz),hl
	ld a,(wc_on)
	or a
	call nz,cc_list
	jp c,sh_err

	ld hl,(sh_arg2) 	; ---- the destination
	call sh_resolve
	jp c,sh_err
	xor a
	ld (sh_ddir),a
	call sh_noname
	jr z,cc_d2		; just a directory: the source's name
	push hl 		; a directory that exists: into it, same name
	call fs_name83
	jr c,cc_d1
	call dir_find
	jr c,cc_d1
	ld de,DE_ATTR
	add hl,de
	ld a,(hl)
	and ATTR_DIR
	jr z,cc_d1
	pop hl
	ld hl,sh_comp
	call fs_chdir
	jp c,sh_err
	jr cc_d2
cc_d1:	pop hl			; a file name: copy to it
	ld a,(wc_on)
	or a
	jr nz,cc_dbad		; (many files go into a directory)
	ld de,sh_dname
	ld b,13
cc_d1a: ld a,(hl)
	or a
	jr z,cc_d1b
	cp ' '
	jr z,cc_d1b
	ld (de),a
	inc hl
	inc de
	djnz cc_d1a
cc_d1b: xor a
	ld (de),a
	jr cc_d3
cc_d2:	ld a,1
	ld (sh_ddir),a
cc_d3:	ld a,(sh_rdrv)
	ld (sh_ddrv),a
	ld hl,(fs_cwd)
	ld (sh_dcwd),hl
	ld a,(wc_on)
	or a
	jp z,cc_one		; one file

	ld hl,0 		; ---- many: each name in the list
	ld (sh_dirs),hl
cc_m1:	ld hl,(sh_nlist)
	ld a,h
	or l
	jr z,cc_m2
	dec hl
	ld (sh_nlist),hl
	ld hl,(sh_ent)
	push hl
	ld de,sh_sname
	ld bc,14
	ldir
	pop hl
	ld de,16
	add hl,de
	ld (sh_ent),hl
	ld hl,sh_sname
	call con_puts
	ld a,' '
	call con_putc
	call con_putc
	call cc_one
	ret c
	ld hl,(sh_dirs)
	inc hl
	ld (sh_dirs),hl
	call sh_brk
	jr nc,cc_m1
cc_m2:	ld hl,(sh_dirs)
	ld b,0
	call con_dec16w
	ld hl,m_cc_nfiles
	jp con_puts
cc_dbad:
	call sh_fail
	ld hl,m_cc_todir
	jp con_puts

cc_list:			; the names that fit wc_pat here -> 16-byte slots from
	ld hl,0 		; (sh_buf), "NAME.EXT",0; sh_cbuf and sh_cbsz move past
	ld (sh_nlist),hl	; them.  sh_ent = the first.  CF = none, or a read error
	ld hl,(sh_buf)
	ld (sh_ent),hl
	call dir_first
cl_1:  jr c,cl_end
	call wc_match
	jr nz,cl_3
	call de_attr
	and ATTR_DIR+ATTR_HID+ATTR_SYS
	jr nz,cl_3
	ld de,fs_fname		; its name
	ld bc,11
	ldir
	ld hl,(sh_cbsz) 	; room for one more?  (512 bytes stay for the data)
	ld de,512+16
	or a
	sbc hl,de
	jr c,cl_full
	ld de,512
	add hl,de
	ld (sh_cbsz),hl
	ld hl,(sh_cbuf)
	ld de,16
	add hl,de
	ld (sh_cbuf),hl
	ld hl,(sh_nlist)	; DE = its slot
	inc hl
	ld (sh_nlist),hl
	dec hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,(sh_buf)
	add hl,de
	ex de,hl
	call sh_fname2txt
cl_3:  call dir_next
	jr cl_1
cl_full:
	ld hl,m_cc_full
	call con_puts
	jr cl_2
cl_end:
	cp FS_EEND
	scf
	ret nz
cl_2:  ld hl,(sh_nlist)
	ld a,h
	or l
	ld a,FS_ENOTF
	scf
	ret z
	or a
	ret

cc_one: 			; copy sh_sname (in sh_sdrv:sh_scwd) to sh_dname (in
	call cc_src		; sh_ddrv:sh_dcwd; sh_ddir = 1: the same name).
	jp c,cc_err		; CF = failed (and said so)
	ld hl,sh_sname
	ld ix,sh_fcb1
	call f_open
	jp c,cc_err
	call dir_get		; its date and time go to the copy
	jp c,cc_err
	ld de,DE_TIME
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (sh_ctime),de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (sh_cdate),de
	ld a,(sh_ddir)
	or a
	jr z,co_1
	ld hl,sh_sname
	ld de,sh_dname
	ld bc,14
	ldir
co_1:	call cc_dst
	jp c,cc_err

	ld a,(sh_sdrv)		; ---- not onto itself: same drive, directory, name
	ld b,a
	ld a,(sh_ddrv)
	cp b
	jr nz,cc_go
	ld hl,(sh_scwd)
	ld de,(sh_dcwd)
	or a
	sbc hl,de
	jr nz,cc_go
	ld hl,sh_sname
	call fs_name83
	ld hl,fs_fname
	ld de,fs_fname2
	ld bc,11
	ldir
	ld hl,sh_dname
	call fs_name83
	jp c,cc_err
	ld hl,fs_fname
	ld de,fs_fname2
	ld b,11
cc_same:
	ld a,(de)
	cp (hl)
	jr nz,cc_go
	inc hl
	inc de
	djnz cc_same
	call sh_fail
	ld hl,m_cc_self
	call con_puts
	scf
	ret

cc_go:	ld hl,(sh_cdate)	; ---- create the copy (we are in its directory)
	ld (fs_fdate),hl
	ld hl,(sh_ctime)
	ld (fs_ftime),hl
	ld hl,sh_dname
	ld ix,sh_fcb2
	call f_create
	jp c,cc_err
	ld hl,0
	ld (sh_total),hl
	ld (sh_total+2),hl
cc_loop:
	call cc_src		; the source disk
	jr c,cc_fail
	ld ix,sh_fcb1
	ld de,(sh_cbuf)
	ld bc,(sh_cbsz)
	call f_read
	jr c,cc_fail
	ld a,b
	or c
	jr z,cc_end
	push bc
	call cc_dst		; the destination disk
	pop bc
	jr c,cc_fail
	push bc
	ld (sh_cnt),bc
	xor a
	ld (sh_cnt+2),a
	ld (sh_cnt+3),a
	ld hl,sh_total
	ld de,sh_cnt
	call num_add32
	pop bc
	ld ix,sh_fcb2
	ld de,(sh_cbuf)
	call f_write
	jr c,cc_fail
	jr cc_loop
cc_end: call cc_dst
	jr c,cc_fail
	ld ix,sh_fcb2
	call f_close
	jr c,cc_fail
	ld hl,sh_total
	ld b,0
	call con_dec32
	ld hl,m_cc_done
	call con_puts
	or a
	ret
cc_fail:			; tell, and do not leave half a copy behind:
	call sh_err		; its clusters are only in its FCB so far (the
	call cc_dst		; entry gets them at close), so free them from
	ret c			; there, then delete the entry
	ld hl,(sh_fcb2+FCB_FIRST)
	call fat_freechain
	ld hl,sh_dname
	call f_delete
	scf
	ret
cc_err: call sh_err
	scf
	ret

cc_src: 			; to the source's disk and directory
	call cc_two
	jr z,ccs_1
	call fs_flush		; (another drive: the destination's FAT goes to
	ret c			;  its disk first)
	ld a,(sh_sdrv)
	ld hl,(sh_scwd)
	jp sh_ctx
ccs_1:	ld hl,(sh_scwd) 	; (one drive: just the directory)
	ld (fs_cwd),hl
	ret
cc_dst: 			; to the destination's disk and directory
	call cc_two
	jr z,ccd_1
	ld a,(sh_ddrv)
	ld hl,(sh_dcwd)
	jp sh_ctx
ccd_1:	ld hl,(sh_dcwd)
	ld (fs_cwd),hl
	ret
cc_two: 			; Z = source and destination are on one drive
	ld a,(sh_sdrv)		; (carry is clear either way)
	ld b,a
	ld a,(sh_ddrv)
	cp b
	ret z
	ld a,1			; NZ, NC (not OR A: drive A is 0, that would give Z)
	or a
	ret

m_cc_self: defm "a file cannot be copied onto itself"
	defb 13,10,0
m_cc_done: defm " bytes copied"
	defb 13,10,0
m_cc_nfiles: defm " file(s) copied"
	defb 13,10,0
m_cc_todir: defm "with wildcards, copy into a directory: COPY *.TXT B:"
	defb 13,10,0
m_cc_full: defm "(too many names: only the first ones)"
	defb 13,10,0
m_cdl_all: defm "Delete every file in that directory (Y/N)? "
	defb 0
m_cdl_n:   defm " file(s) deleted"
	defb 13,10,0
