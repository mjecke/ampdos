; ==========================================================================
; ATTRIB.ASM - ATTRIB.BIN: show or change files' attributes.
;
;   ATTRIB [+R|-R] [+H|-H] [+S|-S] [+A|-A] [[d:][dir\]name]
;
; R read-only (DEL and COPY over it refuse; DEL with wildcards leaves it),
; H hidden, S system (DIR does not list them; wildcards leave them out),
; A archive.  The name may have * and ? (none: every file here).  Each file
; it fits is listed as  "R-S-A  NAME.EXT" (D: a directory), after any change.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h		; 11 bytes
P_NAME: equ 9010h		; 13 bytes
v_set:	equ 9020h		; the bits to set
v_clr:	equ 9021h		; and to clear
v_ix:	equ 9022h		; word: the entry number
v_n:	equ 9024h		; word: files that fit
v_arg:	equ 9030h		; 64 bytes: the name

start:	xor a
	ld (v_set),a
	ld (v_clr),a
	ld (v_arg),a
	ld d,a
	ld e,a
	ld (v_n),de
st_1:	call pl_skip		; +X and -X, then the name
	or a
	jr z,st_go
	cp '+'
	jr z,st_flag
	cp '-'
	jr z,st_flag
	ld de,v_arg
	call pl_word
	jr st_1
st_flag:
	ld c,a			; C = + or -
	inc hl
	ld a,(hl)
	inc hl
	call pl_upper
	ld b,ATTR_RO
	cp 'R'
	jr z,st_f1
	ld b,ATTR_HID
	cp 'H'
	jr z,st_f1
	ld b,ATTR_SYS
	cp 'S'
	jr z,st_f1
	ld b,ATTR_ARC
	cp 'A'
	jr nz,st_use
st_f1:	push hl
	ld hl,v_set
	ld a,c
	cp '+'
	jr z,st_f2
	ld hl,v_clr
st_f2:	ld a,b
	or (hl)
	ld (hl),a
	pop hl
	jr st_1
st_use: ld hl,m_use
	jp pl_fail

st_go:	ld hl,v_arg		; that drive and directory; the name part -> P_PAT
	ld a,(hl)
	or a
	jr z,st_g1
	call OS_RESOLVE
	jp c,pl_err
st_g1:	call pl_pat
	ld hl,0
	ld (v_ix),hl
lp:	ld hl,(v_ix)
	call OS_DIRGET
	jr c,done
	ld a,(hl)
	or a
	jr z,done
	call pl_entry
	jr nz,next
	call pl_match
	jr nz,next
	push hl
	ld hl,(v_n)
	inc hl
	ld (v_n),hl
	pop hl
	ld de,DE_ATTR		; the attributes: changed?
	add hl,de
	ld a,(v_clr)
	cpl
	and (hl)
	ld b,a
	ld a,(v_set)
	or b
	cp (hl)
	jr z,show
	ld (hl),a
	push hl
	call OS_DIRPUT
	pop hl
	jp c,pl_err
show:	ld a,(hl)		; "R-S-A  NAME.EXT"
	ld de,-DE_ATTR
	add hl,de
	push hl
	ld b,a
	ld a,'R'
	bit 0,b
	call sh_bit
	ld a,'H'
	bit 1,b
	call sh_bit
	ld a,'S'
	bit 2,b
	call sh_bit
	ld a,'A'
	bit 5,b
	call sh_bit
	ld a,'D'
	bit 4,b
	call sh_bit
	ld a,' '
	call OS_PUTC
	call OS_PUTC
	pop hl
	call pl_ename
	ex de,hl
	call OS_PUTS
	call OS_CRLF
next:	ld hl,(v_ix)
	inc hl
	ld (v_ix),hl
	jr lp
done:	call OS_FLUSH
	jp c,pl_err
	ld hl,(v_n)
	ld a,h
	or l
	ret nz
	ld a,FS_ENOTF
	jp pl_err

sh_bit: jr nz,sb_1		; Z: a "-" instead of the letter
	ld a,'-'
sb_1:	jp OS_PUTC

m_use:	defm "ATTRIB [+R|-R] [+H|-H] [+S|-S] [+A|-A] [[d:][dir\\]name]"
	defb 0

	include "PROGRAMS/PLIB.INC"
