; ==========================================================================
; CD.ASM - CD, MD and RD: directories.
;
;   CD               show where we are:  A:\SUB
;   CD SUB           into SUB            CD ..       up one
;   CD \             the root            CD \SUB\X   a whole path, from the root
;   CD SUB\X         a path from here
; Each drive has its own current directory: fs_cwd is the first cluster of
; the current one (0 = root), and SH_PATH0 / SH_PATH1 hold its name for the
; prompt ("\SUB\X", empty in the root).  A CD that fails half way puts both
; back as they were.
; ==========================================================================

SH_PATHMAX: equ 63

cmd_cd:
	ld hl,(sh_args)
	ld a,(hl)
	or a
	jr nz,ccd_go
	call sh_pwd		; no argument: where are we?
	jp con_crlf
ccd_go: inc hl			; CD d:path: that drive's directory changes
	ld a,(hl)
	dec hl
	cp ':'
	jr nz,ccd_here
	ld a,(sh_drive) 	; (as if we were on it for a moment)
	push af
	ld a,(hl)
	and 0DFh
	sub 'A'
	cp 2
	ld a,FS_EPATH
	jr nc,ccd_bdrv
	ld a,(hl)
	and 0DFh
	sub 'A'
	ld (sh_drive),a
	inc hl
	inc hl
	ld (sh_args),hl
	call ccd_here
ccd_back:
	pop af
	ld (sh_drive),a
	ret
ccd_bdrv:
	call sh_err
	jr ccd_back
ccd_here:
	call sh_mount
	ret c
	ld hl,(fs_cwd)		; keep the old place, to undo a failed CD
	ld (sh_savecwd),hl
	call sh_curpath
	ld de,sh_pathsave
	ld bc,SH_PATHMAX+1
	ldir
	ld hl,(sh_args)
	ld a,(hl)
	cp 5Ch			; a leading backslash (or /): start at the root
	jr z,ccd_root
	cp '/'
	jr nz,ccd_part
ccd_root:
	inc hl
	push hl
	ld hl,0
	ld (fs_cwd),hl
	call sh_curpath
	ld (hl),0
	pop hl
ccd_part:			; HL = the next part of the path
	ld a,(hl)
	or a
	jr z,ccd_done
	cp ' '
	jr z,ccd_done
	ld de,sh_comp		; copy it to sh_comp, up to the next separator
	ld b,13
ccd_c1: ld a,(hl)
	or a
	jr z,ccd_c2
	cp ' '
	jr z,ccd_c2
	cp 5Ch
	jr z,ccd_c2
	cp '/'
	jr z,ccd_c2
	dec b
	jr z,ccd_long
	ld (de),a
	inc de
	inc hl
	jr ccd_c1
ccd_c2: xor a
	ld (de),a
	push hl
	ld hl,sh_comp		; step into it
	call fs_chdir
	jr c,ccd_failpop
	call ccd_path		; and say so in the path
	jr c,ccd_failpop
	pop hl
	ld a,(hl)		; past the separator, if there is one
	cp 5Ch
	jr z,ccd_sep
	cp '/'
	jr nz,ccd_part
ccd_sep:
	inc hl
	jr ccd_part
ccd_done:			; arrived: this is the drive's directory now
	ld a,(sh_drive)
	call sh_cwdp
	ld de,(fs_cwd)
	ld (hl),e
	inc hl
	ld (hl),d
	ret
ccd_long:
	ld a,FS_EPATH
	jr ccd_fail
ccd_failpop:
	pop hl
ccd_fail:
	push af 		; undo: the old directory, the old path
	ld hl,(sh_savecwd)
	ld (fs_cwd),hl
	call sh_curpath
	ex de,hl
	ld hl,sh_pathsave
	ld bc,SH_PATHMAX+1
	ldir
	pop af
	jp sh_err

ccd_path:			; update the path text for the part in sh_comp. CF = too long
	ld a,(sh_comp)
	cp '.'
	jr nz,ccp_name
	ld a,(sh_comp+1)
	or a
	ret z			; "." : no change (carry is clear)
	call sh_curpath 	; ".." : cut the path at its last backslash
	ld d,h
	ld e,l
ccp_1:	ld a,(hl)
	or a
	jr z,ccp_2
	cp 5Ch
	jr nz,ccp_1a
	ld d,h			; DE = the last backslash so far
	ld e,l
ccp_1a: inc hl
	jr ccp_1
ccp_2:	xor a
	ld (de),a
	ret
ccp_name:			; a name: add "\NAME.EXT" (from fs_fname, tidy)
	call sh_curpath
	ld b,0			; B = length so far
ccp_3:	ld a,(hl)
	or a
	jr z,ccp_4
	inc hl
	inc b
	jr ccp_3
ccp_4:	ld a,b			; room for 13 more?
	cp SH_PATHMAX-13+1
	ld a,FS_EPATH
	ccf
	ret c
	ld (hl),5Ch
	inc hl
	ex de,hl
	call sh_fname2txt
	or a
	ret

cmd_md:
	call sh_open1
	ret c
	call fs_mkdir
	jp c,sh_err
	ret

cmd_rd:
	call sh_open1
	ret c
	call fs_rmdir
	jp c,sh_err
	ret
