; ==========================================================================
; TREE.ASM - TREE.BIN: the directories under one, as a tree.
;
;   TREE [[d:]dir] [/F]       /F: the files too
;
;   B:\
;     DOCS\
;       OLD\
;     GAMES\
; Directories end in \.  Hidden and system files are shown too (with /F).
; 16 levels at most.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h
P_NAME: equ 9010h		; 13 bytes
v_ix:	equ 9020h		; word: the entry number in this directory
v_dep:	equ 9022h		; the level (0 = the directory given)
v_f:	equ 9023h		; 1 = /F
v_plen: equ 9024h		; the length of v_path
v_ndir: equ 9026h		; word: directories found
v_path: equ 9040h		; 80 bytes: the directory being listed, "B:\DOCS\" or ""
v_tmp:	equ 9090h		; 80 bytes: it, with a * after it
v_stk:	equ 9100h		; 16 x 3 bytes: (entry number, path length) of each level up
MAXDEP: equ 16

start:	xor a
	ld (v_f),a
	ld (v_path),a
	ld (v_dep),a
	ld d,a
	ld e,a
	ld (v_ndir),de
st_1:	call pl_skip
	or a
	jr z,st_go
	cp '/'
	jr z,st_opt
	ld de,v_path
	call pl_word
	jr st_1
st_opt: inc hl
	ld a,(hl)
	inc hl
	call pl_upper
	cp 'F'
	jr nz,st_use
	ld a,1
	ld (v_f),a
	jr st_1
st_use: ld hl,m_use
	jp pl_fail

st_go:	call w_norm		; "B:\DOCS" -> "B:\DOCS\"
	ld hl,v_path		; the first line: the directory itself
	ld a,(hl)
	or a
	jr nz,st_g1
	ld hl,m_here
st_g1:	call OS_PUTS
	call OS_CRLF
	call w_res
	ret c
	ld hl,0
	ld (v_ix),hl

lp:	ld hl,(v_ix)
	call OS_DIRGET
	jr c,up
	ld a,(hl)
	or a
	jr z,up
	call pl_entry
	jr nz,next
	bit 4,a
	jr nz,isdir
	ld a,(v_f)		; a file: shown with /F
	or a
	jr z,next
	call indent
	call pl_ename
	ex de,hl
	call OS_PUTS
	call OS_CRLF
	jr next
isdir:	push hl
	call indent
	pop hl
	call pl_ename		; "NAME\"
	push de
	ex de,hl
	call OS_PUTS
	ld a,5Ch
	call OS_PUTC
	call OS_CRLF
	ld hl,(v_ndir)
	inc hl
	ld (v_ndir),hl
	ld a,(v_dep)		; down into it (unless that is too deep)
	cp MAXDEP-1
	pop de
	jr nc,next
	call push_lv
	ex de,hl		; the path + NAME\
	call w_add
	jr c,toolong
	call w_res
	jr c,cantgo
	ld hl,v_dep
	inc (hl)
	ld hl,0
	ld (v_ix),hl
	jr lp
cantgo: call pop_lv		; (it said why): on in this one
	call w_res
	ret c
	jr next
toolong:
	call pop_lv
	ld hl,m_long
	call OS_PUTS
	call OS_CRLF
next:	ld hl,(v_ix)
	inc hl
	ld (v_ix),hl
	jp lp
up:	ld a,(v_dep)		; this directory is done: back up
	or a
	jr z,fin
	dec a
	ld (v_dep),a
back:	call pop_lv
	call w_res
	ret c
	jr next
fin:	ld hl,(v_ndir)
	ld a,h
	or l
	ret nz
	ld hl,m_none
	call OS_PUTS
	jp OS_CRLF

indent: ld a,(v_dep)		; 2 spaces a level, and 2 more
	inc a
	add a,a
	ld b,a
in_1:	ld a,' '
	call OS_PUTC
	djnz in_1
	ret

push_lv:			; keep (v_ix, v_plen) for the level being left
	push de
	ld a,(v_dep)
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,de		; x3
	ld de,v_stk
	add hl,de
	ld de,(v_ix)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld a,(v_plen)
	ld (hl),a
	pop de
	ret
pop_lv: 			; and back to it: v_ix, v_path as it was
	ld a,(v_dep)
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	ld de,v_stk
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (v_ix),de
	ld a,(hl)
	ld (v_plen),a
	ld e,a
	ld d,0
	ld hl,v_path
	add hl,de
	ld (hl),0
	ret

	include "PROGRAMS/WALK.INC"

m_use:	defm "TREE [[d:]dir] [/F]"
	defb 0
m_here: defm "."
	defb 0
m_none: defm "  (no directories)"
	defb 0
m_long: defm "  (path too long)"
	defb 0

	include "PROGRAMS/PLIB.INC"
