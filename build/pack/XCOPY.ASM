; ==========================================================================
; XCOPY.ASM - XCOPY.BIN: copy a directory with all that is in it.
;
;   XCOPY [d:]from [d:]to        e.g.  XCOPY \DOCS B:\DOCS    XCOPY . B:\BACKUP
;
; Every file of "from" and of each directory under it goes into "to", which
; is made (with its subdirectories) where they are not there yet.  The
; copying is the shell's own COPY (and MD), run with OS_EXEC for each
; directory, so it says what it does as COPY does; hidden and system files
; are left out as COPY's wildcards leave them.  "to" may not be inside
; "from" on the same drive (it would copy itself forever): that is refused
; when both are written the same way.  16 levels at most.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h
P_NAME: equ 9010h
v_ix:	equ 9020h		; word: the entry number in this directory
v_dep:	equ 9022h
v_plen: equ 9024h		; v_path's length (WALK.INC)
v_dlen: equ 9025h		; v_dst's length
v_nf:	equ 9026h		; files in this directory (to copy)
v_path: equ 9040h		; 80 bytes: the source directory "DOCS\SUB\"
v_tmp:	equ 9090h		; 80 bytes
v_dst:	equ 90E0h		; 80 bytes: the target "B:\DOCS\SUB\"
v_cmd:	equ 9130h		; 160 bytes: a command line for OS_EXEC
v_stk:	equ 91D0h		; 16 x 4 bytes: (entry number, source length, target length)
v_top:	equ 9220h		; 80 bytes: the target as given (normalized)
XMEM:	equ 0A000h		; memory for the copying
MAXDEP: equ 16

start:	xor a
	ld (v_path),a
	ld (v_dst),a
	ld (v_dep),a
	ld de,v_path
	call pl_word
	jp z,use
	ld de,v_dst
	call pl_word
	jp z,use
	ld hl,v_path		; "." and ".\x" are the same as "" and "x"
	call nodot
	ld hl,v_dst
	call nodot
	call w_norm		; both end in \ (or are a drive)
	ld hl,v_path		; (the target the same way, by hand: w_norm does v_path)
	ld de,v_tmp
	call pl_cat
	ld hl,v_dst
	ld de,v_path
	call pl_cat
	call w_norm
	ld a,(v_plen)
	ld (v_dlen),a
	ld hl,v_path
	ld de,v_dst
	call pl_cat
	ld hl,v_tmp
	ld de,v_path
	call pl_cat
	call w_norm
	call inside		; "to" in "from"?
	jp z,self
	ld hl,v_dst
	ld de,v_top
	call pl_cat
	call w_res
	ret c
	call dirgo		; the top directory: made, files copied
	ret c
	ld hl,0
	ld (v_ix),hl

lp:	ld hl,(v_ix)		; its subdirectories, one by one, down into each
	call OS_DIRGET
	jr c,up
	ld a,(hl)
	or a
	jr z,up
	call pl_entry
	jr nz,next
	bit 4,a
	jr z,next
	ld a,(v_dep)
	cp MAXDEP-1
	jr nc,next
	call pl_ename
	push de
	call push_lv
	pop hl
	push hl
	call w_add		; the source + NAME\
	pop hl
	jr c,long
	call d_add		; the target + NAME\
	jr c,long
	call istop		; the target itself (XCOPY . BACKUP): not into itself
	jr z,skip
	call w_res
	jr c,back0
	call dirgo
	jr c,back0
	ld hl,v_dep
	inc (hl)
	ld hl,0
	ld (v_ix),hl
	jr lp
skip:	call pop_lv		; ("to" itself: not copied into itself)
	call w_res
	ret c
	jr next
long:	call pop_lv
	ld hl,m_long
	call OS_PUTS
	call OS_CRLF
	ld a,1
	call OS_STATUS
	call w_res
	ret c
	jr next
back0:	call pop_lv
	ld a,1
	call OS_STATUS
	call w_res
	ret c
next:	ld hl,(v_ix)
	inc hl
	ld (v_ix),hl
	jp lp
up:	ld a,(v_dep)
	or a
	ret z
	dec a
	ld (v_dep),a
	call pop_lv
	call w_res
	ret c
	jr next

use:	ld hl,m_use
	jp pl_fail
self:	ld hl,m_self
	jp pl_fail

dirgo:				; in the source directory: make the target, copy the files
	ld hl,0 		; any files to copy?
	ld (v_tmp),hl
	xor a
	ld (v_nf),a
dg_1:	ld hl,(v_tmp)
	call OS_DIRGET
	jr c,dg_2
	ld a,(hl)
	or a
	jr z,dg_2
	call pl_entry
	jr nz,dg_n
	and ATTR_DIR+ATTR_HID+ATTR_SYS
	jr nz,dg_n
	ld a,1
	ld (v_nf),a
	jr dg_2
dg_n:	ld hl,(v_tmp)
	inc hl
	ld (v_tmp),hl
	jr dg_1
dg_2:	ld a,(v_dlen)		; the target: there?  (a drive alone always is)
	ld e,a
	ld d,0
	ld hl,v_dst
	add hl,de
	dec hl
	ld a,(hl)
	cp ':'
	jr z,dg_cp
	ld hl,v_dst		; OS_RESOLVE of target + "*"
	ld de,v_cmd
	call pl_cat
	ld a,'*'
	ld (de),a
	inc de
	xor a
	ld (de),a
	ld hl,v_cmd
	call OS_RESOLVE
	jr nc,dg_cp
	ld de,v_cmd		; not there: "MD target" (without its last \)
	ld hl,m_md
	call pl_cat
	ld hl,v_dst
	call pl_cat
	dec de
	ld a,(de)
	cp 5Ch
	jr nz,dg_md
	xor a
	ld (de),a
dg_md:	call exec
	ld hl,v_dst		; is it there now?
	ld de,v_cmd
	call pl_cat
	ld a,'*'
	ld (de),a
	inc de
	xor a
	ld (de),a
	ld hl,v_cmd
	call OS_RESOLVE
	jr nc,dg_cp
	ld hl,m_nomd
	call OS_PUTS
	ld hl,v_dst
	call OS_PUTS
	call OS_CRLF
	scf
	ret
dg_cp:	ld a,(v_nf)		; "COPY source*.* target"
	or a
	jr z,dg_back
	ld de,v_cmd
	ld hl,m_copy
	call pl_cat
	ld hl,v_path
	call pl_cat
	ld hl,m_all
	call pl_cat
	ld hl,v_dst
	call pl_cat
	call exec
dg_back:			; back in the source directory
	jp w_res

exec:	ld hl,v_cmd		; show the command, and run it
	call OS_PUTS
	call OS_CRLF
	ld hl,v_cmd
	ld de,XMEM
	ld bc,0F000h-XMEM
	call OS_EXEC
	ret nc
	ld hl,m_long
	call OS_PUTS
	jp OS_CRLF

d_add:				; v_dst + HL + \ .  CF = too long
	ld a,(v_dlen)
	ld e,a
	ld d,0
	push hl
	ld hl,v_dst
	add hl,de
	ex de,hl
	pop hl
	ld b,a
da_1:	ld a,(hl)
	or a
	jr z,da_2
	ld (de),a
	inc hl
	inc de
	inc b
	ld a,b
	cp W_MAX
	jr c,da_1
	scf
	ret
da_2:	ld a,5Ch
	ld (de),a
	inc de
	xor a
	ld (de),a
	inc b
	ld a,b
	ld (v_dlen),a
	or a
	ret

inside: 			; Z = v_dst starts with v_path (and it is not empty)
	ld a,(v_plen)
	or a
	jr z,in_no
	ld b,a
	ld hl,v_path
	ld de,v_dst
in_1:	ld a,(de)
	call pl_upper
	ld c,a
	ld a,(hl)
	call pl_upper
	cp c
	ret nz
	inc hl
	inc de
	djnz in_1
	ret			; Z
in_no:	or 1
	ret

nodot:				; HL = a path: a leading "." or ".\" goes
	ld a,(hl)
	cp '.'
	ret nz
	inc hl
	ld a,(hl)
	or a
	jr z,nd_all
	cp 5Ch
	ret nz
	inc hl			; ".\x": move x down by 2
	ld d,h
	ld e,l
	dec de
	dec de
nd_1:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,nd_1
	ret
nd_all: dec hl			; ".": nothing
	ld (hl),0
	ret

istop:				; Z = v_path is the target as given (any case)
	ld hl,v_path
	ld de,v_top
it_1:	ld a,(de)
	call pl_upper
	ld c,a
	ld a,(hl)
	call pl_upper
	cp c
	ret nz
	or a
	ret z
	inc hl
	inc de
	jr it_1

push_lv:			; keep (v_ix, v_plen, v_dlen) of the level being left
	call lv_at
	ld de,(v_ix)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld a,(v_plen)
	ld (hl),a
	inc hl
	ld a,(v_dlen)
	ld (hl),a
	ret
pop_lv: call lv_at		; and back to it
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (v_ix),de
	ld a,(hl)
	inc hl
	ld (v_plen),a
	ld e,a
	ld a,(hl)
	ld (v_dlen),a
	push af
	ld d,0
	ld hl,v_path
	add hl,de
	ld (hl),0
	pop af
	ld e,a
	ld hl,v_dst
	add hl,de
	ld (hl),0
	ret
lv_at:	ld a,(v_dep)		; HL = this level's 4 bytes
	add a,a
	add a,a
	ld l,a
	ld h,0
	ld de,v_stk
	add hl,de
	ret

	include "PROGRAMS/WALK.INC"

m_use:	defm "XCOPY [d:]from [d:]to   (a directory, and all in it)"
	defb 0
m_self: defm "XCOPY: the target is inside the source"
	defb 0
m_long: defm "(path too long: left out)"
	defb 0
m_nomd: defm "cannot make "
	defb 0
m_md:	defm "MD "
	defb 0
m_copy: defm "COPY "
	defb 0
m_all:	defm "*.* "
	defb 0

	include "PROGRAMS/PLIB.INC"
