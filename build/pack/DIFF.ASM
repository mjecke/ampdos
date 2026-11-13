; ==========================================================================
; DIFF.ASM - DIFF.BIN: how two text files differ, line by line.
;
;   DIFF old new
;
; The output is UNIX diff's:  3c3  (line 3 changed),  5,7d4  (lines 5-7 of
; the first gone, after line 4 of the second),  8a9,10  (lines 9-10 of the
; second added after line 8 of the first); then the lines, "< " for the
; first file's, "> " for the second's, "---" between.  Nothing is printed
; when they are the same.  Status 0 = the same, 1 = they differ, 2 = trouble.
;
; Both files are read whole: 11 KB and 700 lines each at most.  After a
; difference DIFF looks for the nearest place where two lines in a row match
; again (or the files end), so its hunks are short; it is not as thorough as
; UNIX diff on files changed all through.  A key pauses it, Esc stops it.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

ATEXT:	equ 09000h		; the first file  (11 KB)
BTEXT:	equ 0BB00h		; the second
MAXT:	equ 02B00h
AIDX:	equ 0E600h		; 700 words: where each line starts
BIDX:	equ 0EC00h
AHASH:	equ 0F200h		; 700 bytes: a hash of each line
BHASH:	equ 0F500h
MAXL:	equ 700
VARS:	equ 0F800h
P_PAT:	equ VARS
P_NAME: equ VARS+10h
vna:	equ VARS+20h		; words: lines in each file
vnb:	equ VARS+22h
vi:	equ VARS+24h		; where each file is (line numbers from 0)
vj:	equ VARS+26h
vii:	equ VARS+28h		; where they match again
vjj:	equ VARS+2Ah
vk:	equ VARS+2Ch		; the search: lines skipped in all, and in the first
vd:	equ VARS+2Eh
vdiff:	equ VARS+30h		; 1 = they differ
x_beg:	equ VARS+32h		; index: the text, its end, its tables
x_end:	equ VARS+34h
x_idx:	equ VARS+36h
x_hash: equ VARS+38h
x_n:	equ VARS+3Ah
vname1: equ VARS+40h		; 64 bytes each
vname2: equ VARS+80h
vfcb:	equ VARS+0C0h

start:	ld de,vname1
	call pl_word
	jp z,use
	ld de,vname2
	call pl_word
	jp z,use
	xor a
	ld (vdiff),a
	ld hl,vname1		; read and index both
	ld de,ATEXT
	call load
	jp c,trouble
	ld (x_end),hl
	ld hl,ATEXT
	ld (x_beg),hl
	ld hl,AIDX
	ld (x_idx),hl
	ld hl,AHASH
	ld (x_hash),hl
	call index
	jp c,trouble
	ld (vna),bc
	ld hl,vname2
	ld de,BTEXT
	call load
	jp c,trouble
	ld (x_end),hl
	ld hl,BTEXT
	ld (x_beg),hl
	ld hl,BIDX
	ld (x_idx),hl
	ld hl,BHASH
	ld (x_hash),hl
	call index
	jp c,trouble
	ld (vnb),bc
	ld hl,0
	ld (vi),hl
	ld (vj),hl

ml:	call ilt		; both ended?
	jr c,ml_1
	call jlt
	jp nc,fin
	jr sync
ml_1:	call jlt
	jr nc,sync
	ld bc,(vi)		; the same line: on
	ld de,(vj)
	call eq
	jr nz,sync
	ld hl,(vi)
	inc hl
	ld (vi),hl
	ld hl,(vj)
	inc hl
	ld (vj),hl
	jr ml

sync:	ld hl,1 		; the nearest match: k lines skipped, d of them in the first
	ld (vk),hl
sk:	ld hl,0
	ld (vd),hl
sd:	ld hl,(vi)		; ii = i + d
	ld de,(vd)
	add hl,de
	ld (vii),hl
	ld de,(vna)		; past the end of the first: the next k
	ex de,hl
	or a
	sbc hl,de
	jp c,nk
	ld hl,(vj)		; jj = j + k - d
	ld de,(vk)
	add hl,de
	ld de,(vd)
	or a
	sbc hl,de
	ld (vjj),hl
	ld de,(vnb)
	ex de,hl
	or a
	sbc hl,de
	jr c,nd 		; past the end of the second: the next d
	call iiend		; both at their ends: that is it
	jr nz,sd_1
	call jjend
	jr z,found
sd_1:	call iiend		; one at its end, the other not: no
	jr z,nd
	call jjend
	jr z,nd
	ld bc,(vii)
	ld de,(vjj)
	call eq
	jr nz,nd
	ld bc,(vii)		; a line with 3 characters or more is enough;
	call strong		; a shorter one (blank, "}", "END") needs the next too
	jr nc,found
	ld hl,(vii)		; and the line after (or an end)
	inc hl
	ld de,(vna)
	or a
	sbc hl,de
	jr z,found
	ld hl,(vjj)
	inc hl
	ld de,(vnb)
	or a
	sbc hl,de
	jr z,found
	ld bc,(vii)
	inc bc
	ld de,(vjj)
	inc de
	call eq
	jr z,found
nd:	ld hl,(vd)		; d + 1, up to k
	inc hl
	ld (vd),hl
	ld de,(vk)
	ex de,hl
	or a
	sbc hl,de
	jp nc,sd
nk:	ld hl,(vk)
	inc hl
	ld (vk),hl
	jp sk

found:	ld a,1
	ld (vdiff),a
	call hunk
	ret c			; (Esc)
	ld hl,(vii)
	ld (vi),hl
	ld hl,(vjj)
	ld (vj),hl
	jp ml

fin:	ld a,(vdiff)
	jp OS_STATUS

use:	ld hl,m_use
	call OS_PUTS
	call OS_CRLF
	ld a,2
	jp OS_STATUS
trouble:
	or a			; (A = the error; 0: too big, said already)
	jr z,tr_1
	call OS_ERRMSG
	call OS_PUTS
	call OS_CRLF
tr_1:	ld a,2
	jp OS_STATUS

ilt:	ld hl,(vi)		; CF = i < na
	ld de,(vna)
	or a
	sbc hl,de
	ret
jlt:	ld hl,(vj)
	ld de,(vnb)
	or a
	sbc hl,de
	ret
iiend:	ld hl,(vii)		; Z = ii is the end of the first
	ld de,(vna)
	or a
	sbc hl,de
	ret
jjend:	ld hl,(vjj)
	ld de,(vnb)
	or a
	sbc hl,de
	ret

; ---------------------------------------------------------------- output
hunk:				; lines i..ii-1 of the first, j..jj-1 of the second
	ld hl,(vii)
	ld de,(vi)
	or a
	sbc hl,de
	ld a,h
	or l
	jr z,hk_add		; none of the first: added
	ld hl,(vjj)
	ld de,(vj)
	or a
	sbc hl,de
	ld a,h
	or l
	jr z,hk_del		; none of the second: deleted
	ld hl,(vi)		; changed: "i+1,ii c j+1,jj"
	ld de,(vii)
	call range
	ld a,'c'
	call OS_PUTC
	ld hl,(vj)
	ld de,(vjj)
	call range
	call OS_CRLF
	call a_lines
	ret c
	ld hl,m_sep
	call OS_PUTS
	jp b_lines
hk_del: ld hl,(vi)
	ld de,(vii)
	call range
	ld a,'d'
	call OS_PUTC
	ld hl,(vj)
	call OS_DEC16
	call OS_CRLF
	jp a_lines
hk_add: ld hl,(vi)
	call OS_DEC16
	ld a,'a'
	call OS_PUTC
	ld hl,(vj)
	ld de,(vjj)
	call range
	call OS_CRLF
	jp b_lines

range:				; lines HL+1 .. DE as "5" or "5,7"
	push de
	inc hl
	push hl
	call OS_DEC16
	pop hl
	pop de
	or a
	sbc hl,de
	ret z
	ld a,','
	call OS_PUTC
	ex de,hl
	jp OS_DEC16

a_lines:			; "< line" for i .. ii-1.  CF = Esc
	ld bc,(vi)
al_1:	ld hl,(vii)
	or a
	sbc hl,bc
	ret z
	push bc
	ld hl,AIDX
	add hl,bc
	add hl,bc
	ld a,'<'
	call pline
	pop bc
	ret c
	inc bc
	jr al_1
b_lines:
	ld bc,(vj)
bl_1:	ld hl,(vjj)
	or a
	sbc hl,bc
	ret z
	push bc
	ld hl,BIDX
	add hl,bc
	add hl,bc
	ld a,'>'
	call pline
	pop bc
	ret c
	inc bc
	jr bl_1

pline:				; HL = an index entry, A = < or >: print the line.  CF = Esc
	ld e,(hl)
	inc hl
	ld d,(hl)
	call OS_PUTC
	ld a,' '
	call OS_PUTC
	ex de,hl
pl_1:	ld a,(hl)
	inc hl
	cp 10
	jr z,pl_2
	cp 13
	jr z,pl_1
	call OS_PUTC
	jr pl_1
pl_2:	call OS_CRLF
	call OS_KBHIT		; a key: pause; Esc: stop
	ret z
	call OS_GETC
	cp 1Bh
	scf
	ret z
	call OS_GETC
	cp 1Bh
	scf
	ret z
	or a
	ret

; ---------------------------------------------------------------- the files
load:				; HL = a name, DE = where: read it whole, with an LF at
	push de 		; its end -> HL = the end.  CF = error (A; 0: too big, said)
	call OS_RESOLVE 	; ([d:][dir\]name)
	pop de
	ret c
	push de
	ld ix,vfcb
	call OS_OPEN
	pop de
	ret c
	ld a,(vfcb+FCB_SIZE+2)	; small enough?
	ld hl,vfcb+FCB_SIZE+3
	or (hl)
	jr nz,ld_big
	ld hl,(vfcb+FCB_SIZE)
	push de
	ld de,MAXT-1
	or a
	sbc hl,de
	pop de
	jr nc,ld_big
	push de
	ld ix,vfcb
	ld bc,MAXT-1
	call OS_READ
	pop hl
	ret c
	add hl,bc		; HL = the end
	ld a,b
	or c
	ret z			; (empty: no lines)
	dec hl			; an LF at the end?
	ld a,(hl)
	inc hl
	cp 10
	ret z
	ld (hl),10
	inc hl
	or a
	ret
ld_big: ld hl,m_big
	call OS_PUTS
	call OS_CRLF
	xor a
	scf
	ret

index:				; x_beg .. x_end -> x_idx, x_hash; BC = lines.	CF = too many
	ld hl,(x_beg)
	ld bc,0
ix_1:	push hl
	ld de,(x_end)
	or a
	sbc hl,de
	pop hl
	ret nc			; (NC: done)
	push hl
	ld hl,MAXL-1
	or a
	sbc hl,bc
	pop hl
	jr c,ix_many
	push hl 		; where it starts
	ex de,hl
	ld hl,(x_idx)
	add hl,bc
	add hl,bc
	ld (hl),e
	inc hl
	ld (hl),d
	pop hl
	ld e,0			; its hash: rotate, add, over its bytes (no CR)
ix_2:	ld a,(hl)
	inc hl
	cp 10
	jr z,ix_3
	cp 13
	jr z,ix_2
	rlc e
	add a,e
	ld e,a
	jr ix_2
ix_3:	push hl
	ld hl,(x_hash)
	add hl,bc
	ld (hl),e
	pop hl
	inc bc
	jr ix_1
ix_many:
	ld hl,m_many
	call OS_PUTS
	call OS_CRLF
	xor a
	scf
	ret

strong: 			; BC = a line of the first: NC = 3 or more characters
	ld hl,AIDX		; that are not spaces (or tabs)
	add hl,bc
	add hl,bc
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld b,0
st_1:	ld a,(hl)
	inc hl
	cp 10
	jr z,st_2
	cp ' '+1
	jr c,st_1
	inc b
	jr st_1
st_2:	ld a,b
	cp 3
	ret

eq:				; BC = a line of the first, DE = of the second: Z = the same
	ld hl,AHASH
	add hl,bc
	ld a,(hl)
	ld hl,BHASH
	add hl,de
	cp (hl)
	ret nz
	push bc
	push de
	ld hl,BIDX
	add hl,de
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)		; DE = the second's line
	ld hl,AIDX
	add hl,bc
	add hl,bc
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a			; HL = the first's
eq_1:	ld a,(hl)
	cp 13
	jr nz,eq_2
	inc hl
	jr eq_1
eq_2:	ld c,a
eq_3:	ld a,(de)
	cp 13
	jr nz,eq_4
	inc de
	jr eq_3
eq_4:	cp c
	jr nz,eq_x
	cp 10
	jr z,eq_x		; both at their LF: the same (Z)
	inc hl
	inc de
	jr eq_1
eq_x:	pop de
	pop bc
	ret

m_use:	defm "DIFF old new   (two text files, line by line)"
	defb 0
m_sep:	defm "---"
	defb 13,10,0
m_big:	defm "too big for DIFF (11 KB at most)"
	defb 0
m_many: defm "too many lines for DIFF (700 at most)"
	defb 0

	include "PROGRAMS/PLIB.INC"
