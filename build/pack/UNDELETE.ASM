; ==========================================================================
; UNDELETE.ASM - UNDELETE.BIN: bring a deleted file back.
;
;   UNDELETE [[d:]dir\]            list the deleted files there
;   UNDELETE [[d:]dir\]NAME.EXT    bring that one back
;
; DEL marks a file's directory entry deleted (its first letter becomes E5h)
; and frees its clusters in the FAT; the data stays on the disk until a new
; file takes the clusters.  So a file can come back if the clusters it had
; are still free.  UNDELETE takes them to be one after the other from its
; first cluster (as a file written on a floppy with room usually is): when
; they are all free it chains them again and gives the entry back its first
; letter, the one you type.  Write nothing to a disk before undeleting on it.
; A file whose clusters were not one after the other comes back with wrong
; data after its first cluster: check it.  Directories are not brought back.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h		; 11 bytes
P_NAME: equ 9010h		; 13 bytes
v_ix:	equ 9020h		; word: the entry number
v_n:	equ 9022h		; word: deleted files found
v_f:	equ 9024h		; word: the first cluster
v_k:	equ 9026h		; word: clusters it had
v_max:	equ 9028h		; word: the highest cluster number
v_bpc:	equ 902Ah		; word: bytes per cluster
v_first: equ 902Ch		; the first letter to give it (0: just list)
v_size: equ 9030h		; 4 bytes: its size
v_arg:	equ 9040h		; 64 bytes: the argument
v_fcb:	equ 9080h		; 16 bytes

start:	xor a
	ld (v_arg),a
	ld (v_first),a
	ld d,a
	ld e,a
	ld (v_n),de
	ld de,v_arg
	call pl_word
	ld hl,v_arg		; its drive and directory (a \ at the end: just those)
	ld a,(hl)
	or a
	jr z,st_1
	call OS_RESOLVE
	jp c,pl_err
st_1:	ld a,(hl)		; a name: bring it back
	or a
	jr z,st_2
	call pl_upper
	cp 'A'			; (its first letter must be one)
	jp c,need1
	cp '?'
	jp z,need1
	cp '*'
	jp z,need1
	ld (v_first),a
	push hl
	ld ix,v_fcb		; a file of that name must not be there
	call OS_OPEN
	pop hl
	jp nc,exists
	push hl
	call pl_pat
	pop hl
st_2:	call OS_DISK		; the cluster size and the last cluster
	inc hl
	ld (v_max),hl
	ld h,a
	ld l,0
	add hl,hl		; spc x 512
	ld (v_bpc),hl
	ld hl,0
	ld (v_ix),hl

lp:	ld hl,(v_ix)
	call OS_DIRGET
	jp c,done
	ld a,(hl)
	or a
	jp z,done
	cp 0E5h
	jp nz,next
	push hl 		; (a long-name piece, the label: not files)
	ld de,DE_ATTR
	add hl,de
	ld a,(hl)
	pop hl
	cp ATTR_LFN
	jp z,next
	bit 3,a
	jp nz,next
	ld c,a			; C = the attributes
	ld a,(v_first)		; bringing one back: is this it?
	or a
	jr z,lp_1
	inc hl			; (its name but the first letter)
	push hl
	ld de,P_PAT+1
	ld b,10
lp_m:	ld a,(de)
	cp '?'
	jr z,lp_m1
	cp (hl)
	jr nz,lp_m2
lp_m1:	inc hl
	inc de
	djnz lp_m
lp_m2:	pop hl
	dec hl
	jp nz,next
lp_1:	push hl 		; its first cluster, size
	push bc
	ld de,DE_CLUS
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (v_f),de
	ld de,v_size
	ld bc,4
	ldir
	pop bc
	pop hl
	ld de,(v_n)
	inc de
	ld (v_n),de
	push hl
	call count		; v_k = clusters it had
	pop hl
	ld a,(v_first)
	or a
	jr nz,bring
	call show		; listing: "?ELLO.TXT    115  ..."
	jp next

bring:	bit 4,c 		; a directory: not this way
	jp nz,isdir
	call free		; are they all still free?
	jp nz,inuse
	ld de,(v_f)		; chain them: f -> f+1 -> ... -> end
	ld hl,(v_k)
	ld a,h
	or l
	jr z,br_2
	ld b,h
	ld c,l
br_1:	push bc
	ld h,d
	ld l,e
	inc de			; DE = the next one
	dec bc
	ld a,b
	or c
	jr nz,br_1a
	ld de,0FFFh		; the last: end of chain
br_1a:	push de
	call OS_FATSET
	pop de
	pop bc
	dec bc
	ld a,b
	or c
	jr nz,br_1
br_2:	ld hl,(v_ix)		; the entry again (OS_OPEN moved DIRBUF)
	call OS_DIRGET
	jp c,pl_err
	ld a,(v_first)
	ld (hl),a
	call OS_DIRPUT
	jp c,pl_err
	call OS_FLUSH
	jp c,pl_err
	ld hl,(v_ix)
	call OS_DIRGET
	call pl_ename
	ex de,hl
	call OS_PUTS
	ld hl,m_back
	call OS_PUTS
	ld hl,(v_k)
	ld de,2
	or a
	sbc hl,de
	ret c			; one cluster (or none): it is certainly right
	ld hl,m_check
	jp OS_PUTS

next:	ld hl,(v_ix)
	inc hl
	ld (v_ix),hl
	jp lp
done:	ld a,(v_first)		; looked for one: it is not among them
	or a
	ld hl,m_nof
	jp nz,pl_fail
	ld hl,(v_n)
	ld a,h
	or l
	ret nz
	ld hl,m_none
	jp pl_fail
isdir:	ld hl,m_dir
	jp pl_fail
inuse:	ld hl,m_inuse
	jp pl_fail
exists: ld hl,m_exist
	jp pl_fail
need1:	ld hl,m_use
	jp pl_fail

count:				; v_k = ceil(size / bytes per cluster) (size < 64 KB here)
	ld hl,(v_size)
	ld a,(v_size+2)
	or a
	jr z,ct_1
	ld hl,0FFFFh		; (a 360K disk has no file that big)
ct_1:	ld de,(v_bpc)
	ld bc,0
ct_2:	ld a,h
	or l
	jr z,ct_3
	inc bc
	or a
	sbc hl,de
	jr nc,ct_2
ct_3:	ld (v_k),bc
	ret

free:				; Z = clusters f .. f+k-1 are all free (and on the disk)
	ld hl,(v_k)
	ld a,h
	or l
	ret z
	ld b,h
	ld c,l
	ld hl,(v_f)
	ld a,h
	or l
	jr z,fr_no
fr_1:	push hl 		; in range: 2 .. max
	ld de,(v_max)
	inc de
	or a
	sbc hl,de
	pop hl
	jr nc,fr_no
	push hl
	push bc
	call OS_FATGET
	ld a,h
	or l
	pop bc
	pop hl
	ret nz
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,fr_1
	ret			; Z
fr_no:	or 1
	ret

show:				; one deleted file: name, size, can it come back
	push bc
	call pl_ename
	ld a,'?'		; (its first letter is gone)
	ld (de),a
	ex de,hl
	call OS_PUTS
	ld a,14 		; to column 14
	ld b,0
	ld hl,P_NAME
sh_1:	ld a,(hl)
	or a
	jr z,sh_2
	inc hl
	inc b
	jr sh_1
sh_2:	ld a,14
	sub b
	jr nc,sh_2a
	xor a
sh_2a:	inc a
	ld b,a
sh_3:	ld a,' '
	call OS_PUTC
	djnz sh_3
	ld hl,v_size
	ld b,7
	call OS_DEC32
	pop bc
	bit 4,c
	ld hl,m_ldir
	jr nz,sh_4
	call free
	ld hl,m_lok
	jr z,sh_4
	ld hl,m_lgone
sh_4:	call OS_PUTS
	jp OS_CRLF

m_use:	defm "UNDELETE [[d:]dir\\]   lists them;  UNDELETE [[d:]dir\\]NAME.EXT  brings one back"
	defb 13,10
	defm "(type its first letter too: it was lost)"
	defb 0
m_none: defm "no deleted files here"
	defb 0
m_nof:	defm "no deleted file of that name here"
	defb 0
m_dir:	defm "a directory: UNDELETE brings back files only"
	defb 0
m_inuse: defm "lost: another file has some of its clusters now"
	defb 0
m_exist: defm "a file of that name is there already"
	defb 0
m_back: defm " is back"
	defb 13,10,0
m_check: defm "(it had more than one cluster: check that it is all right)"
	defb 13,10,0
m_ldir: defm "  (a directory)"
	defb 0
m_lok:	defm "  can be brought back"
	defb 0
m_lgone: defm "  lost (its clusters are in use)"
	defb 0

	include "PROGRAMS/PLIB.INC"
