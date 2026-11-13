; ==========================================================================
; TR.ASM - TR.BIN: change or delete characters in a file.
;
;   TR from to name [out]      each character of "from" becomes the one in
;                              the same place in "to" (the last one of "to"
;                              when it is shorter)
;   TR -d chars name [out]     those characters are left out
;
; Sets may have ranges, a-z, and \n (LF), \r (CR), \t (tab), \\ (a \), \-
; (a -); quotes keep spaces in one ("a b").  With no "out" the result is
; shown (CR is left out and LF starts a line, as TYPE does); with one, it is
; written there byte for byte.
;   TR a-z A-Z NOTES.TXT          TR -d \r UNIX.TXT LF.TXT     TR " " _ X Y
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h
P_NAME: equ 9010h
v_del:	equ 9020h		; 1 = -d
v_n1:	equ 9022h		; word: characters in set 1
v_n2:	equ 9024h		; word: in set 2
v_out:	equ 9028h		; 1 = to a file
v_sbeg: equ 902Ah		; word: spell: where the set starts
rf_ptr: equ 9070h
rf_end: equ 9072h
RF_FCB: equ 9080h
O_FCB:	equ 9090h
w1:	equ 9100h		; the words: 4 x 64 bytes
w2:	equ 9140h
w3:	equ 9180h
w4:	equ 91C0h
SET1:	equ 9200h		; 256: set 1 spelled out
SET2:	equ 9300h		; 256: set 2
MAP:	equ 9400h		; 256: what each byte becomes
DEL:	equ 9500h		; 256: 1 = left out
RF_BUF: equ 9800h		; (the screen: read 1 KB at a time)
RF_LEN: equ 1024
IBUF:	equ 9800h		; (a file: all of it here)
IMAX:	equ 0F800h-IBUF 	; 24 KB

start:	xor a
	ld (v_del),a
	ld (v_out),a
	ld (w1),a
	ld (w2),a
	ld (w3),a
	ld (w4),a
	call pl_skip		; -d?
	cp '-'
	jr nz,st_1
	inc hl
	ld a,(hl)
	call pl_upper
	cp 'D'
	jp nz,use
	inc hl
	ld a,1
	ld (v_del),a
st_1:	ld de,w1
	call pl_word
	ld de,w2
	call pl_word
	ld de,w3
	call pl_word
	ld de,w4
	call pl_word
	ld a,(v_del)		; -d chars name [out]: the words move along
	or a
	jr z,st_2
	ld hl,w3
	ld de,w4
	ld bc,64
	ldir
	ld hl,w2
	ld de,w3
	ld bc,64
	ldir
	xor a
	ld (w2),a
st_2:	ld a,(w3)		; a name there must be
	or a
	jp z,use
	ld hl,w1
	ld de,SET1
	call spell
	ld (v_n1),bc
	ld a,b
	or c
	jp z,use
	ld hl,w2
	ld de,SET2
	call spell
	ld (v_n2),bc
	ld a,(v_del)
	or a
	jr nz,st_3
	ld a,b			; changing: a "to" set is needed
	or c
	jp z,use
st_3:	ld hl,MAP		; the map: each byte as it is ...
	xor a
mp_1:	ld (hl),a
	inc l
	inc a
	jr nz,mp_1
	ld hl,DEL
	xor a
mp_2:	ld (hl),0
	inc l
	jr nz,mp_2
	ld hl,SET1		; ... but those of set 1
	ld bc,(v_n1)
	ld de,SET2
mp_3:	push bc
	ld a,(hl)
	push hl
	ld l,a
	ld a,(v_del)
	or a
	jr z,mp_4
	ld h,DEL>>8
	ld (hl),1
	jr mp_5
mp_4:	ld h,MAP>>8
	ld a,(de)
	ld (hl),a
	push de 		; the next of set 2, unless this is its last
	ld hl,(v_n2)
	ld bc,SET2-1
	add hl,bc
	pop de
	or a
	sbc hl,de
	jr z,mp_5
	jr c,mp_5
	inc de
mp_5:	pop hl
	inc hl
	pop bc
	dec bc
	ld a,b
	or c
	jr nz,mp_3
	ld a,(w4)		; the output: a file?
	or a
	jr nz,tofile
	ld hl,w3		; no: the screen, as it is read
	call rf_open
	jp c,pl_err
lp:	call rf_getc
	jr c,end
	ld l,a
	ld h,DEL>>8
	ld a,(hl)
	or a
	jr nz,lp
	ld h,MAP>>8
	ld a,(hl)
	call rf_out
	jr lp
end:	or a
	jp nz,pl_err
	ret

tofile: 			; a file: all of it read, changed, then written (so the
	ld hl,w3		; two may be on different drives)
	call OS_RESOLVE
	jp c,pl_err
	ld ix,RF_FCB
	call OS_OPEN
	jp c,pl_err
	ld a,(RF_FCB+FCB_SIZE+2)
	ld hl,RF_FCB+FCB_SIZE+3
	or (hl)
	jr nz,tf_big
	ld hl,(RF_FCB+FCB_SIZE)
	ld de,IMAX+1
	or a
	sbc hl,de
	jr nc,tf_big
	ld ix,RF_FCB
	ld de,IBUF
	ld bc,IMAX
	call OS_READ
	jp c,pl_err
	ld hl,IBUF		; changed where it is
	ld d,h
	ld e,l
tf_1:	ld a,b
	or c
	jr z,tf_2
	dec bc
	push bc
	ld a,(hl)
	inc hl
	push hl
	ld l,a
	ld h,DEL>>8
	ld a,(hl)
	or a
	jr nz,tf_n
	ld h,MAP>>8
	ld a,(hl)
	ld (de),a
	inc de
tf_n:	pop hl
	pop bc
	jr tf_1
tf_2:	ld hl,IBUF		; BC = what is left of it
	ex de,hl
	or a
	sbc hl,de
	push hl
	ld hl,w4
	call OS_RESOLVE
	pop bc
	jp c,pl_err
	push bc
	ld ix,O_FCB
	call OS_CREATE
	pop bc
	jp c,pl_err
	ld ix,O_FCB
	ld de,IBUF
	call OS_WRITE
	jp c,pl_err
	ld ix,O_FCB
	call OS_CLOSE
	jp c,pl_err
	ret
tf_big: ld hl,m_big
	jp pl_fail

spell:				; HL = a set as typed -> DE: each byte; BC = how many
	ld (v_sbeg),de
sp_1:	ld a,(hl)
	or a
	jr z,sp_end
	inc hl
	cp 5Ch			; \x
	jr nz,sp_ch
	ld a,(hl)
	or a
	jr z,sp_bsl
	inc hl
	cp 'n'
	jr nz,se_1
	ld a,10
	jr sp_put
se_1:	cp 'r'
	jr nz,se_2
	ld a,13
	jr sp_put
se_2:	cp 't'
	jr nz,sp_put		; \\ \- or another: that character
	ld a,9
	jr sp_put
sp_bsl: ld a,5Ch
	jr sp_put
sp_ch:	ld c,a			; c-x: a range?
	ld a,(hl)
	cp '-'
	jr nz,sp_one
	inc hl
	ld a,(hl)
	or a
	jr z,sp_cd		; "c-" at the end: c and -
	inc hl
	ld b,a			; B = the range's end
	ld a,c
sp_rg:	ld (de),a
	inc de
	cp b
	jr nc,sp_1
	inc a
	jr sp_rg
sp_cd:	ld a,c
	ld (de),a
	inc de
	ld a,'-'
	jr sp_put
sp_one: ld a,c
sp_put: ld (de),a
	inc de
	jr sp_1
sp_end: ex de,hl
	ld de,(v_sbeg)
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ret

use:	ld hl,m_use
	jp pl_fail

m_big:	defm "too big for TR into a file (24 KB at most; without one, any size)"
	defb 0
m_use:	defm "TR from to name [out]   or   TR -d chars name [out]"
	defb 13,10
	defm "(sets: a-z ranges, \\n \\r \\t \\\\ \\-; e.g. TR a-z A-Z X.TXT)"
	defb 0

	include "PROGRAMS/RFILE.INC"
	include "PROGRAMS/PLIB.INC"
