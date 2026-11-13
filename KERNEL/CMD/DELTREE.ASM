; ==========================================================================
; DELTREE.ASM - DELTREE [/Y] dir: delete a directory with everything in
; it, files and subdirectories at any depth (like rm -rf).  It asks first,
; unless /Y is given (for batch files).
;
; No list of names is kept: it walks down into the first subdirectory it
; meets, deletes the files there, and when a directory holds nothing but
; "." and "..", it goes up through ".." and deletes that directory's entry
; in its parent (found by its first cluster).  Then it looks at the parent
; again, until the directory it started with is empty: then that one goes.
; ==========================================================================

DT_TOP:  equ BATBUF+0EEh	; word: the directory to delete (its first cluster)
DT_PAR:  equ BATBUF+0F0h	; word: the directory it is in
DT_IX:	 equ BATBUF+0F2h	; word: its entry there
DT_CH:	 equ BATBUF+0F4h	; word: the directory just emptied (going up)
DT_NF:	 equ BATBUF+0F6h	; word: files deleted
DT_ND:	 equ BATBUF+0F8h	; word: directories deleted
DT_Y:	 equ BATBUF+0FAh	; 1 = /Y: do not ask

cmd_deltree:
	xor a
	ld (DT_Y),a
	ld h,a
	ld l,a
	ld (sh_wcn),hl		; (the name: none yet)
	ld hl,(sh_args)
cdt_1:	call sh_skipsp		; the words: /Y, and the directory's name
	ld a,(hl)
	or a
	jr z,cdt_3
	cp '/'
	jr nz,cdt_2
	inc hl
	ld a,(hl)
	and 0DFh
	cp 'Y'
	jp nz,cdt_use
	ld a,1
	ld (DT_Y),a
	inc hl
	jr cdt_1
cdt_2:	ld (sh_wcn),hl
	call sh_skipword
	ld a,(hl)
	or a
	jr z,cdt_3
	ld (hl),0
	inc hl
	jr cdt_1
cdt_3:	ld hl,(sh_wcn)
	ld a,h
	or l
	jp z,cdt_use
	ld a,(DT_Y)		; ask
	or a
	jr nz,cdt_4
	push hl
	ld hl,m_dt_ask1
	call con_puts
	pop hl
	call con_puts
	ld hl,m_dt_ask2
	call sh_yes
	ret nz
cdt_4:	call sh_mount
	ret c
	ld hl,(sh_wcn)
	call sh_resolve 	; into the directory that holds it
	jp c,sh_err
	call sh_noname		; (no name: the root, or "X\")
	jp z,cdt_use
	cp '.'			; not "." or ".."
	jp z,cdt_use
	call fs_name83
	jp c,sh_err
	call dir_find
	jp c,sh_err
	call de_attr
	and ATTR_DIR
	ld a,FS_ENOTDIR
	jp z,sh_err
	call dt_clus
	ld (DT_TOP),hl
	ld hl,(fs_dirix)
	ld (DT_IX),hl
	ld hl,(fs_cwd)
	ld (DT_PAR),hl
	ld hl,0
	ld (DT_NF),hl
	ld (DT_ND),hl
	ld hl,(DT_TOP)
	ld (fs_cwd),hl

dt_scan:			; look through the directory we are in
	call dir_first
dt_1:	jr c,dt_end
	ld a,(hl)
	cp '.'
	jr z,dt_next		; "." and ".."
	call de_attr
	and ATTR_DIR
	jr nz,dt_down
	call dt_kill		; a file: gone
	jp c,dt_err
	ld hl,(DT_NF)
	inc hl
	ld (DT_NF),hl
dt_next:
	call dir_next
	jr dt_1
dt_down:			; a subdirectory: in there first
	call dt_clus
	ld (fs_cwd),hl
	jr dt_scan

dt_end: cp FS_EEND		; this directory is empty now
	jp nz,dt_err
	ld hl,(fs_cwd)
	ld de,(DT_TOP)
	or a
	sbc hl,de
	jr z,dt_top
	ld hl,(fs_cwd)		; up through "..", which is entry 1
	ld (DT_CH),hl
	ld hl,1
	ld (fs_dirix),hl
	call dir_get
	jr c,dt_err
	call dt_clus
	ld (fs_cwd),hl		; (0 = the root)
	call dir_first		; there: the entry of the one just emptied
dt_u1:	jr c,dt_err
	ld a,(hl)
	cp '.'
	jr z,dt_u2
	push hl
	call dt_clus
	ld de,(DT_CH)
	or a
	sbc hl,de
	pop hl
	jr z,dt_u3
dt_u2:	call dir_next
	jr dt_u1
dt_u3:	call dt_kill
	jr c,dt_err
	call dt_dir
	jr dt_scan		; and the rest of this one

dt_top: ld hl,(DT_PAR)		; all of it is empty: the directory itself
	ld (fs_cwd),hl
	ld hl,(DT_IX)
	ld (fs_dirix),hl
	call dir_get
	jr c,dt_err
	call dt_kill
	jr c,dt_err
	call dt_dir
	call fs_flush
	jr c,dt_err
	ld hl,(DT_NF)		; "5 file(s) and 2 dir(s) deleted"
	call con_dec16
	ld hl,m_dt_done1
	call con_puts
	ld hl,(DT_ND)
	call con_dec16
	ld hl,m_dt_done2
	jp con_puts

dt_err: push af 		; what is done so far is written, then the error
	call fs_flush
	pop af
	jp sh_err

cdt_use:
	call sh_fail
	ld hl,m_dt_use
	jp con_puts

dt_dir: ld hl,(DT_ND)
	inc hl
	ld (DT_ND),hl
	ret

dt_kill:			; HL = an entry: free its clusters, mark it deleted
	push hl
	call dt_clus
	call fat_freechain
	pop hl
	ld (hl),0E5h
	jp dir_put

dt_clus:			; HL = an entry -> HL = its first cluster
	push de
	call de_clus
	pop de
	ret

m_dt_ask1:  defm "Delete "
	defb 0
m_dt_ask2:  defm " and everything in it (Y/N)? "
	defb 0
m_dt_done1: defm " file(s) and "
	defb 0
m_dt_done2: defm " dir(s) deleted"
	defb 13,10,0
m_dt_use:   defm "DELTREE [/Y] dir: the directory and everything in it"
	defb 13,10,0
