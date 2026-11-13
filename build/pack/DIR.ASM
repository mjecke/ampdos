; ==========================================================================
; DIR.ASM - DIR [d:][path] [name]: list a directory, then the totals.
; The name may have wildcards (DIR *.BAS), or be one file (DIR README.MD).
;   README   MD       3305  2026-11-02
;   SUBDIR          <DIR>   2026-11-02
;        2 file(s), 3305 bytes, 323584 bytes free
; ==========================================================================

cmd_dir:
	xor a			; (everything, unless a name is given)
	ld (wc_on),a
	call sh_mount
	ret c
	ld hl,m_cd_of		; "Directory of A:\SUB" (or of what was asked for)
	call con_puts
	ld hl,(sh_args)
	ld a,(hl)
	or a
	jr nz,cd_arg
	call sh_pwd
	jr cd_go
cd_arg: call cd_word		; print the argument as typed
	call con_crlf
	ld hl,(sh_args) 	; DIR B:  DIR SUB  DIR \X\Y  DIR ..
	call sh_resolve
	jp c,sh_err
	call sh_noname
	jr z,cd_go1
	cp '.'			; "." and "..": directories
	jr z,cd_cd
	call wc_make		; DIR *.BAS: only what fits
	jp c,sh_err
	ld a,(wc_on)
	or a
	jr nz,cd_go1
cd_cd:	ld hl,sh_comp		; the last part is a directory too ...
	call fs_chdir
	jr nc,cd_go1
	cp FS_ENOTDIR		; ... or a file: just that one
	jp nz,sh_err
	ld a,1
	ld (wc_on),a
	jr cd_go1
cd_go:	call con_crlf
cd_go1: ld hl,0
	ld (sh_dirs),hl
	ld (sh_files),hl
	ld (sh_total),hl
	ld (sh_total+2),hl
	call dir_first
cd_loop:
	jr c,cd_end
	ld (sh_ent),hl
	ld a,(wc_on)
	or a
	call nz,wc_match
	jr nz,cd_cnt1
	ld de,DE_ATTR		; hidden and system files are not listed
	add hl,de
	ld a,(hl)
	and ATTR_HID+ATTR_SYS
	jr nz,cd_cnt1
	ld hl,(sh_ent)
	call cd_line
	ld hl,(sh_ent)		; count files and directories apart
	ld de,DE_ATTR
	add hl,de
	ld a,(hl)
	and ATTR_DIR
	ld hl,sh_files
	jr z,cd_cnt
	ld hl,sh_dirs
cd_cnt: inc (hl)
	jr nz,cd_cnt1
	inc hl
	inc (hl)
cd_cnt1:
	call sh_brk
	ret c
	call dir_next
	jr cd_loop
cd_end: cp FS_EEND
	jp nz,sh_err
	ld hl,(sh_files)	; totals
	ld b,6
	call con_dec16w
	ld hl,m_cd_files
	call con_puts
	ld hl,sh_total
	ld b,0
	call con_dec32
	ld hl,m_cd_bytes
	call con_puts
	ld hl,(sh_dirs)
	ld b,6
	call con_dec16w
	ld hl,m_cd_dirs
	call con_puts
	call cd_free
	ld hl,sh_free
	ld b,0
	call con_dec32
	ld hl,m_cd_free
	jp con_puts

cd_word:			; print the text at HL up to a space or the end
	ld a,(hl)
	or a
	ret z
	cp ' '
	ret z
	call con_putc
	inc hl
	jr cd_word

cd_line:			; one entry, at (sh_ent)
	ld hl,(sh_ent)
	ld b,8			; the name, a space, the extension
cd_l1:	ld a,(hl)
	call con_putc
	inc hl
	djnz cd_l1
	ld a,' '
	call con_putc
	ld b,3
cd_l2:	ld a,(hl)
	call con_putc
	inc hl
	djnz cd_l2
	ld hl,(sh_ent)		; <DIR> or the size
	ld de,DE_ATTR
	add hl,de
	ld a,(hl)
	and ATTR_DIR
	jr z,cd_l3
	ld hl,m_cd_dir
	call con_puts
	jr cd_l4
cd_l3:	ld hl,(sh_ent)
	ld de,DE_SIZE
	add hl,de
	ld b,10
	call con_dec32
	ex de,hl
	ld hl,sh_total
	call num_add32
cd_l4:	ld a,' '
	call con_putc
	call con_putc
	ld hl,(sh_ent)
	ld de,DE_DATE
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	call sh_pdate
	jp con_crlf

sh_pdate:			; print the DOS date in DE as yyyy-mm-dd
	ld a,d			; yyyyyyym mmmddddd
	srl a
	ld l,a
	ld h,0
	push de
	ld de,1980
	add hl,de
	pop de
	ld b,0
	call con_dec16w
	ld a,'-'
	call con_putc
	ld a,e			; month: 3 bits from the low byte, 1 from the high
	rlca
	rlca
	rlca
	and 07h
	ld c,a
	ld a,d
	and 01h
	add a,a
	add a,a
	add a,a
	or c
	call con_dec2
	ld a,'-'
	call con_putc
	ld a,e
	and 1Fh
	jp con_dec2

cd_free:			; sh_free = bytes in free clusters
	ld hl,0
	ld (sh_free),hl
	ld (sh_free+2),hl
	ld bc,2
cd_f1:	ld hl,(fs_clend)
	or a
	sbc hl,bc
	jr z,cd_f3
	ld h,b
	ld l,c
	call fat_get
	ld a,h
	or l
	jr nz,cd_f2
	ld hl,(sh_free)
	inc hl
	ld (sh_free),hl
cd_f2:	inc bc
	jr cd_f1
cd_f3:	ld hl,sh_free
	ld a,(fs_cshift)
	jp num_shl32

m_cd_of:    defm "Directory of "
	defb 0
m_cd_dir:   defm "     <DIR>"
	defb 0
m_cd_files: defm " file(s), "
	defb 0
m_cd_bytes: defm " bytes"
	defb 13,10,0
m_cd_dirs:  defm " dir(s), "
	defb 0
m_cd_free:  defm " bytes free"
	defb 13,10,0
