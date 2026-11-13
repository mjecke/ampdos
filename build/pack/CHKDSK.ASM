; ==========================================================================
; CHKDSK.ASM - CHKDSK [d:] [/F]: check a disk's file system.
;
; Every directory is walked, and every file's and directory's cluster chain
; followed through the FAT (in memory: no disk reads for that).  A bitmap,
; one bit per cluster, marks the clusters that belong to something.  It finds
;   - a chain that runs into a free, reserved or bad cluster, or off the disk
;     ("broken chain"),
;   - a cluster that two chains share, or a chain that loops ("cross-linked"),
;   - a file whose size does not match the clusters it has,
;   - clusters marked in use in the FAT that nothing owns ("lost").
; /F frees the lost clusters (nothing else is changed).  The status is a
; failure if anything was found (except lost clusters that /F freed); lost
; clusters not freed count as one problem.
;
; Memory (the TPA, sh_buf): the bitmap (512 bytes: enough for any FAT12
; disk), the path of the directory being looked at (64), then a stack of the
; directories still to visit: 66 bytes each, the first cluster and the path.
; Subdirectories found are pushed, and the walk goes on with the last one
; pushed, until the stack is empty.  No recursion, so no deep machine stack.
; ==========================================================================

CK_SP:	 equ BATBUF+0C0h	; word: the directory stack's top
CK_LIM:  equ BATBUF+0C2h	; word: no entry may start above this
CK_NF:	 equ BATBUF+0C4h	; word: files
CK_ND:	 equ BATBUF+0C6h	; word: directories
CK_CF:	 equ BATBUF+0C8h	; word: clusters in files
CK_CD:	 equ BATBUF+0CAh	; word: clusters in directories
CK_LOST: equ BATBUF+0CCh	; word: lost clusters
CK_BAD:  equ BATBUF+0CEh	; word: bad clusters (FF7h)
CK_FREE: equ BATBUF+0D0h	; word: free clusters
CK_PROB: equ BATBUF+0D2h	; word: problems found
CK_CNT:  equ BATBUF+0D4h	; word: clusters in the chain just followed
CK_CL:	 equ BATBUF+0D6h	; word: the cluster being looked at
CK_ENT:  equ BATBUF+0D8h	; word: the directory entry being looked at
CK_FIX:  equ BATBUF+0DAh	; 1 = /F
CK_DRV:  equ BATBUF+0DBh	; the drive
CK_DIRF: equ BATBUF+0DCh	; nonzero = the entry is a directory
CK_ESZ:  equ 66 		; a stack entry: cluster (2), path (64)

cmd_chkdsk:
	call sh_noexec
	ret c
	xor a
	ld (CK_FIX),a
	ld a,(sh_drive)
	ld (CK_DRV),a
	ld hl,(sh_args)
ck_a1:	call sh_skipsp		; the words: d:  /F
	ld a,(hl)
	or a
	jr z,ck_a3
	cp '/'
	jr nz,ck_a2
	inc hl
	ld a,(hl)
	and 0DFh
	cp 'F'
	jp nz,ck_use
	ld a,1
	ld (CK_FIX),a
	inc hl
	jr ck_a1
ck_a2:	and 0DFh
	sub 'A'
	cp 2
	jp nc,ck_use
	ld (CK_DRV),a
	inc hl
	ld a,(hl)
	cp ':'
	jp nz,ck_use
	inc hl
	jr ck_a1
ck_a3:	ld a,(CK_DRV)		; that drive's root
	ld hl,0
	call sh_ctx
	jp c,sh_err
	ld hl,m_ck_head 	; "Checking A:"
	call con_puts
	ld a,(CK_DRV)
	add a,'A'
	call con_putc
	ld a,':'
	call con_putc
	call con_crlf

	ld hl,(sh_buf)		; the bitmap: nothing owned yet
	xor a
	ld b,a
ck_z1:	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	djnz ck_z1
	ld (hl),a		; the path of the root: ""
	ld de,64
	add hl,de
	ld (CK_SP),hl		; the stack: just the root
	push hl
	ld hl,0 		; the counters
	ld (CK_NF),hl
	ld (CK_ND),hl
	ld (CK_CF),hl
	ld (CK_CD),hl
	ld (CK_LOST),hl
	ld (CK_BAD),hl
	ld (CK_FREE),hl
	ld (CK_PROB),hl
	ld hl,(sh_buf)		; the limit: the end of the memory, less one entry
	ld de,(sh_bufsz)
	add hl,de
	ld de,CK_ESZ
	or a
	sbc hl,de
	ld (CK_LIM),hl
	pop hl
	xor a			; push the root: cluster 0, path ""
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	ld hl,(CK_SP)
	ld de,CK_ESZ
	add hl,de
	ld (CK_SP),hl

ck_pop: ld hl,(sh_buf)		; ---- the next directory: the stack's top entry
	ld de,512+64
	add hl,de		; (HL = the stack's bottom)
	ld de,(CK_SP)
	or a
	sbc hl,de
	jp z,ck_lost		; empty: all done
	ex de,hl
	ld de,CK_ESZ
	or a
	sbc hl,de
	ld (CK_SP),hl
	ld e,(hl)		; its cluster
	inc hl
	ld d,(hl)
	inc hl
	ld (fs_cwd),de
	call ck_path		; DE = the current path
	ld bc,64
	ldir
	call dir_first
ck_ent: jp c,ck_dend
	ld (CK_ENT),hl
	ld a,(hl)
	cp '.'
	jp z,ck_next		; "." and ".."
	push hl
	ld de,DE_ATTR
	add hl,de
	ld a,(hl)
	and ATTR_DIR
	ld (CK_DIRF),a
	pop hl
	ld de,DE_CLUS		; follow its chain
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call ck_chain
	or a
	jr z,ck_ok
	ld hl,m_ck_broken
	dec a
	jr z,ck_bad1
	ld hl,m_ck_cross
ck_bad1:
	call ck_prob
	jp ck_count
ck_ok:	ld a,(CK_DIRF)
	or a
	jr z,ck_file
	ld hl,(CK_CNT)		; a directory: it must have a cluster
	ld a,h
	or l
	ld hl,m_ck_broken
	call z,ck_prob
	jp z,ck_count
	ld hl,(CK_SP)		; push it, to visit later
	ld de,(CK_LIM)
	or a
	sbc hl,de
	add hl,de
	jr c,ck_push
	ld hl,m_ck_room 	; (no room: it is counted, not looked into)
	call ck_prob
	jp ck_count
ck_push:
	ld hl,(CK_ENT)
	ld de,DE_CLUS
	add hl,de
	ld de,(CK_SP)
	ldi
	ldi
	push de 		; its path: the current one, "\", its name
	call ck_path
	ex de,hl
	pop de
ck_p1:	ld a,(hl)
	or a
	jr z,ck_p2
	ldi
	jr ck_p1
ck_p2:	ld hl,(CK_SP)		; (only if it fits: 63 characters)
	ld bc,2+63-13
	add hl,bc
	or a
	sbc hl,de
	jr c,ck_p3
	ld a,5Ch
	ld (de),a
	inc de
	call ck_name		; HL = its name, "NAME.EXT"
	ld bc,13
	ldir
	jr ck_p4
ck_p3:	xor a
	ld (de),a
ck_p4:	ld hl,(CK_SP)
	ld de,CK_ESZ
	add hl,de
	ld (CK_SP),hl
	jr ck_count
ck_file:
	ld hl,(CK_ENT)		; a file: does its size fit its clusters?
	ld de,DE_SIZE		; (size + bytes per cluster - 1) / bytes per cluster
	add hl,de
	ld de,sh_total
	ld bc,4
	ldir
	ld hl,(sh_total)
	ld de,(fs_bpc)
	dec de
	add hl,de
	ld (sh_total),hl
	jr nc,ck_f1
	ld hl,(sh_total+2)
	inc hl
	ld (sh_total+2),hl
ck_f1:	ld a,(fs_cshift)
	ld b,a
ck_f2:	ld hl,sh_total+3
	srl (hl)
	dec hl
	rr (hl)
	dec hl
	rr (hl)
	dec hl
	rr (hl)
	djnz ck_f2
	ld hl,(sh_total+2)
	ld a,h
	or l
	jr nz,ck_f3
	ld hl,(sh_total)
	ld de,(CK_CNT)
	or a
	sbc hl,de
	jr z,ck_count
ck_f3:	ld hl,m_ck_size
	call ck_prob
ck_count:
	ld a,(CK_DIRF)		; the totals
	or a
	ld hl,CK_NF
	ld de,CK_CF
	jr z,ck_c1
	ld hl,CK_ND
	ld de,CK_CD
ck_c1:	call ck_inc
	ex de,hl
	ld e,(hl)		; (DE) += CK_CNT
	inc hl
	ld d,(hl)
	push hl
	ld hl,(CK_CNT)
	add hl,de
	ex de,hl
	pop hl
	ld (hl),d
	dec hl
	ld (hl),e
ck_next:
	call sh_brk
	ret c
	call dir_next
	jp ck_ent
ck_dend:
	cp FS_EEND
	jp nz,sh_err
	jp ck_pop

ck_lost:			; ---- every cluster: free, bad, owned, or lost?
	ld bc,2
ck_l1:	ld hl,(fs_clend)
	or a
	sbc hl,bc
	jr z,ck_l4
	ld h,b
	ld l,c
	call fat_get
	ld a,h
	or l
	jr nz,ck_l2
	ld hl,CK_FREE
	jr ck_l3
ck_l2:	ld de,0FF7h
	or a
	sbc hl,de
	ld hl,CK_BAD
	jr z,ck_l3
	push bc
	ld h,b
	ld l,c
	call ck_bit
	and (hl)
	pop bc
	jr nz,ck_l3a		; owned
	ld hl,CK_LOST
	ld a,(CK_FIX)
	or a
	jr z,ck_l3
	push hl
	ld h,b
	ld l,c
	ld de,0 		; /F: free it
	call fat_set
	pop hl
ck_l3:	call ck_inc
ck_l3a: inc bc
	jr ck_l1
ck_l4:	ld a,(CK_FIX)
	or a
	jr z,ck_rep
	call fs_flush
	jp c,sh_err

ck_rep: ld hl,(fs_nclus)	; ---- the report
	call ck_bytes
	ld hl,m_ck_total
	call con_puts
	ld hl,(CK_CD)
	call ck_bytes
	ld hl,m_ck_in
	call con_puts
	ld hl,(CK_ND)
	call ck_dec
	ld hl,m_ck_dirs
	call con_puts
	ld hl,(CK_CF)
	call ck_bytes
	ld hl,m_ck_in
	call con_puts
	ld hl,(CK_NF)
	call ck_dec
	ld hl,m_ck_files
	call con_puts
	ld hl,(CK_LOST)
	ld a,h
	or l
	jr z,ck_r1
	call ck_bytes
	ld hl,m_ck_in
	call con_puts
	ld hl,(CK_LOST)
	call ck_dec
	ld hl,m_ck_lost
	call con_puts
	ld hl,(CK_FREE) 	; freed: they count as free now
	ld de,(CK_LOST)
	add hl,de
	ld a,(CK_FIX)
	or a
	jr z,ck_rf
	ld (CK_FREE),hl
	ld hl,m_ck_fixd
	jr ck_r0
ck_rf:
	ld hl,(CK_PROB) 	; not freed: a problem (so the last line says so)
	inc hl
	ld (CK_PROB),hl
	ld hl,m_ck_usef
ck_r0:	call con_puts
ck_r1:	ld hl,(CK_BAD)
	ld a,h
	or l
	jr z,ck_r2
	call ck_bytes
	ld hl,m_ck_bad
	call con_puts
ck_r2:	ld hl,(CK_FREE)
	call ck_bytes
	ld hl,m_cd_free 	; (DIR's)
	call con_puts
	ld hl,(CK_PROB)
	ld a,h
	or l
	ld hl,m_ck_ok
	jp z,con_puts
	call sh_fail
	ld hl,(CK_PROB)
	call ck_dec
	ld hl,m_ck_probs
	jp con_puts
ck_use: call sh_fail
	ld hl,m_ck_use
	jp con_puts

; ---------------------------------------------------------------- helpers
ck_chain:			; HL = first cluster: follow it, mark its clusters.
	ld de,0 		; CK_CNT = how many.  A = 0 fine, 1 broken,
	ld (CK_CNT),de		; 2 cross-linked (a cluster already marked)
	ld a,h
	or l
	ret z			; no clusters (an empty file)
ckc_1:	ld (CK_CL),hl
	ld de,2 		; a cluster number: 2 .. clend-1?
	or a
	sbc hl,de
	jr c,ckc_bad
	add hl,de
	ld de,(fs_clend)
	or a
	sbc hl,de
	jr nc,ckc_bad
	add hl,de
	call ck_bit
	ld c,a
	and (hl)
	jr nz,ckc_cross
	ld a,c
	or (hl)
	ld (hl),a
	ld hl,(CK_CNT)
	inc hl
	ld (CK_CNT),hl
	ld hl,(CK_CL)		; the next
	call fat_get
	ld de,FAT_EOC
	or a
	sbc hl,de
	add hl,de
	jr c,ckc_1
	xor a			; the end of the chain
	ret
ckc_bad:
	ld a,1
	ret
ckc_cross:
	ld a,2
	ret

ck_bit: 			; HL = cluster -> HL = its byte in the bitmap, A = its
	ld a,l			; bit.  (Uses B, DE)
	and 7
	ld b,a
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld de,(sh_buf)
	add hl,de
	ld a,1
	inc b
ckb_1:	dec b
	ret z
	add a,a
	jr ckb_1

ck_path:			; DE = the current directory's path (in sh_buf)
	push hl
	ld hl,(sh_buf)
	ld de,512
	add hl,de
	ex de,hl
	pop hl
	ret

ck_name:			; HL = the entry's name as "NAME.EXT",0 (in sh_sname)
	push de
	ld hl,(CK_ENT)
	ld de,fs_fname
	ld bc,11
	ldir
	ld de,sh_sname
	call sh_fname2txt
	pop de
	ld hl,sh_sname
	ret

ck_prob:			; HL = what is wrong: "\SUB\X.TXT: <it>", one more problem
	push hl
	call ck_path
	ex de,hl
	call con_puts
	ld a,5Ch
	call con_putc
	call ck_name
	call con_puts
	call sh_colsp
	pop hl
	call con_puts
	ld hl,CK_PROB
	call ck_inc
	xor a			; (Z: callers go on to count it)
	ret

ck_inc: inc (hl)		; the word at HL, plus 1
	ret nz
	inc hl
	inc (hl)
	dec hl
	ret

ck_bytes:			; HL = clusters: print them as bytes, 10 wide
	ld (sh_total),hl
	ld hl,0
	ld (sh_total+2),hl
	ld hl,sh_total
	ld a,(fs_cshift)
	call num_shl32
	ld b,10
	jp con_dec32

ck_dec: ld b,0			; HL in decimal
	jp con_dec16w

m_ck_head:  defm "Checking "
	defb 0
m_ck_broken: defm "broken cluster chain"
	defb 13,10,0
m_ck_cross: defm "cross-linked (shares clusters with something else)"
	defb 13,10,0
m_ck_size:  defm "its size does not match its clusters"
	defb 13,10,0
m_ck_room:  defm "not looked into (no memory for more directories)"
	defb 13,10,0
m_ck_total: defm " bytes total disk space"
	defb 13,10,0
m_ck_in:    defm " bytes in "
	defb 0
m_ck_dirs:  defm " directories"
	defb 13,10,0
m_ck_files: defm " files"
	defb 13,10,0
m_ck_lost:  defm " lost clusters"
	defb 0
m_ck_usef:  defm "  (CHKDSK /F frees them)"
	defb 13,10,0
m_ck_fixd:  defm ", freed"
	defb 13,10,0
m_ck_bad:   defm " bytes in bad sectors"
	defb 13,10,0
m_ck_ok:    defm "No problems found."
	defb 13,10,0
m_ck_probs: defm " problem(s) found."
	defb 13,10,0
m_ck_use:   defm "CHKDSK [d:] [/F]"
	defb 13,10,0
