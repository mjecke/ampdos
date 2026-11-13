; ==========================================================================
; LABEL.ASM - the volume label: a disk's name.
;   LABEL [d:]           show it (and the serial number)      VOL [d:]  the same
;   LABEL [d:] name      set it: up to 11 characters, spaces allowed
;   LABEL [d:] /D        remove it
; DOS keeps the label in two places, and so does this: an entry in the root
; directory with the volume attribute (08h), which is what DOS and Windows
; show, and the 11 bytes at 2Bh in the boot sector, if its extended BPB is
; there (the byte 29h at 26h; "NO NAME" when there is no label).
; ==========================================================================

LB_DRV:  equ BATBUF+0C0h	; the drive
LB_MODE: equ BATBUF+0C1h	; 0 = show, 1 = set, 2 = remove
LB_NEW:  equ BATBUF+0C2h	; 11 bytes (C2-CC): the new label, padded with spaces
LB_VOL:  equ BATBUF+0CDh	; 1 = VOL (show only)

cmd_vol:
	ld a,1			; (only the drive is looked at)
	jr clb_0
cmd_label:
	xor a
clb_0:	ld (LB_VOL),a
	ld hl,(sh_args)
	ld a,(sh_drive)
	ld (LB_DRV),a
	inc hl			; a drive letter?
	ld a,(hl)
	dec hl
	cp ':'
	jr nz,clb_1
	ld a,(hl)
	and 0DFh
	sub 'A'
	cp 2
	jr nc,clb_bad
	ld (LB_DRV),a
	inc hl
	inc hl
clb_1:	call sh_skipsp
	ld de,LB_NEW		; "NO NAME    " until there is a name
	push hl
	ld hl,m_fd_noname
	ld bc,11
	ldir
	pop hl
	xor a
	ld (LB_MODE),a
	ld a,(hl)
	or a
	jr z,clb_go		; nothing: show it
	ld a,(LB_VOL)
	or a
	jr nz,clb_go		; VOL: show it
	ld a,(hl)
	cp '/'
	jr nz,clb_2
	inc hl
	ld a,(hl)
	and 0DFh
	cp 'D'
	jr nz,clb_bad
	ld a,2
	ld (LB_MODE),a
	jr clb_go
clb_2:	ld a,1			; a new label
	ld (LB_MODE),a
	ld de,LB_NEW
	push hl
	ld hl,LB_NEW
	ld b,11
clb_3:	ld (hl),' '
	inc hl
	djnz clb_3
	pop hl
	ld b,11
clb_4:	ld a,(hl)
	or a
	jr z,clb_go
	inc b			; room left?
	dec b
	jr z,clb_long
	cp ' '
	jr z,clb_5
	call fn_char		; (upper case; not . , ; : * ? and the like)
	jr c,clb_bad
clb_5:	ld (de),a
	inc de
	inc hl
	dec b
	jr clb_4
clb_long:
	ld hl,m_lb_long
	jr clb_msg
clb_bad:
	ld hl,m_lb_use
clb_msg:
	call sh_fail
	jp con_puts

clb_go: ld a,(LB_DRV)		; the root directory of that drive
	ld hl,0
	call sh_ctx
	jp c,sh_err
	call lb_find
	jr nc,clb_have
	cp FS_EEND
	jp nz,sh_err
	ld a,(LB_MODE)		; no label yet
	or a
	jr z,clb_none
	dec a
	jr nz,clb_none		; /D: there is nothing to remove
	call dir_free		; set: a new entry
	jp c,sh_err
	ld a,ATTR_VOL
	ld de,0
	call fs_fillent
clb_have:
	ld a,(LB_MODE)
	or a
	jr z,clb_show
	dec a
	jr nz,clb_del
	ex de,hl		; set: the name into the entry
	ld hl,LB_NEW
	ld bc,11
	ldir
	jr clb_put
clb_del:
	ld (hl),0E5h		; remove: the entry is deleted
clb_put:
	call dir_put
	jp c,sh_err
	ld hl,0 		; and the boot sector's copy (if it has one)
	ld de,SECBUF
	call md_read
	ld a,FS_EREAD
	jp c,sh_err
	ld a,(SECBUF+26h)
	cp 29h
	jr nz,clb_flush
	ld hl,LB_NEW
	ld de,SECBUF+2Bh
	ld bc,11
	ldir
	ld hl,0
	ld de,SECBUF
	call md_write
	ld a,FS_EWRITE
	jp c,sh_err
clb_flush:
	call fs_flush
	jp c,sh_err
	ret

clb_none:
	call clb_drv
	ld hl,m_lb_none
	jp con_puts
clb_show:
	push hl
	call clb_drv
	ld hl,m_lb_is
	call con_puts
	pop hl
	ld b,11 		; the name, without the spaces after it
	ld c,0			; C = how many spaces are owed
clb_s1: ld a,(hl)
	inc hl
	cp ' '
	jr nz,clb_s2
	inc c
	jr clb_s4
clb_s2: inc c			; first the spaces before it
clb_s3: dec c
	jr z,clb_s3a
	push af
	ld a,' '
	call con_putc
	pop af
	jr clb_s3
clb_s3a:
	call con_putc
clb_s4: djnz clb_s1
	call con_crlf
	ld hl,0 		; the serial number, from the boot sector
	ld de,SECBUF
	call md_read
	ret c
	ld a,(SECBUF+26h)
	cp 29h
	ret nz
	ld hl,m_lb_ser
	call con_puts
	ld hl,(SECBUF+29h)
	call con_hex16
	ld a,'-'
	call con_putc
	ld hl,(SECBUF+27h)
	call con_hex16
	jp con_crlf

clb_drv:			; "Volume in drive A "
	ld hl,m_lb_vol
	call con_puts
	ld a,(LB_DRV)
	add a,'A'
	jp con_putc

lb_find:			; the root's volume label entry -> HL, NC.  CF: none
	ld hl,0 		; (A = FS_EEND) or a read error
	ld (fs_dirix),hl
lbf_1:	call dir_get
	ret c
	ld a,(hl)
	or a
	jr z,lbf_none		; the end of the used entries
	cp 0E5h
	jr z,lbf_2
	call de_attr
	cp ATTR_LFN
	jr z,lbf_2
	and ATTR_VOL
	ret nz			; (AND clears the carry)
lbf_2:	ld hl,(fs_dirix)
	inc hl
	ld (fs_dirix),hl
	jr lbf_1
lbf_none:
	ld a,FS_EEND
	scf
	ret

m_lb_vol:  defm "Volume in drive "
	defb 0
m_lb_is:   defm " is "
	defb 0
m_lb_none: defm " has no label"
	defb 13,10,0
m_lb_ser:  defm "Volume Serial Number is "
	defb 0
m_lb_long: defm "a label is 11 characters at most"
	defb 13,10,0
m_lb_use:  defm "LABEL [d:] [name | /D]"
	defb 13,10,0
