; ==========================================================================
; DISKCOMP.ASM - DISKCOMP.BIN: compare two whole 360K disks, track by track.
;
;   DISKCOMP A: B:      the disks in the two drives
;   DISKCOMP A: A:      one drive: it asks for each disk in turn (16 times)
;
; Every sector is compared, the boot sector and the FATs too, so two disks
; with the same files written in another order differ; DISKCOPY's copies
; compare the same.  A track that differs (or cannot be read) is listed:
;   "Compare error on side 1, track 12"; then "Compare OK" or how many differ.
; Status 0 = the same, 1 = they differ (or a disk could not be read).
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

CHUNK:	equ 5			; tracks of the first disk kept at a time
TRK:	equ 4608		; bytes in a track (9 x 512)
BUF1:	equ 9000h		; CHUNK tracks of the first disk (22.5 KB)
BUF2:	equ 0EA00h		; one track of the second
P_PAT:	equ 8F00h
P_NAME: equ 8F10h
v_d1:	equ 8F20h		; the drives: 0 = A, 1 = B
v_d2:	equ 8F21h
v_one:	equ 8F22h		; 1 = one drive (ask for the disks)
v_t0:	equ 8F23h		; the first track of this chunk
v_t:	equ 8F24h		; the track being compared
v_n:	equ 8F25h		; tracks in this chunk
v_bad:	equ 8F26h		; word: tracks that differ
v_rd:	equ 8F28h		; 1 = this track could not be read
v_dn:	equ 8F2Ah		; "A:*", 0
v_w:	equ 8F30h		; 16 bytes: a word

start:	call drv		; the two drives
	jp c,use
	ld (v_d1),a
	call drv
	jp c,use
	ld (v_d2),a
	ld b,a
	ld a,(v_d1)
	cp b
	ld a,0
	jr nz,st_1
	inc a
st_1:	ld (v_one),a
	ld hl,0
	ld (v_bad),hl
	xor a
	ld (v_t0),a
	ld a,(v_one)		; two drives: both disks in now
	or a
	jr nz,chunk
	ld hl,m_both
	call OS_PUTS
	call key
	ret c

chunk:	ld a,(v_t0)		; ---- CHUNK tracks of the first disk
	ld b,a
	ld a,80
	sub b
	cp CHUNK
	jr c,ch_1
	ld a,CHUNK
ch_1:	ld (v_n),a
	ld a,(v_one)
	or a
	jr z,ch_2
	ld hl,m_first
	call OS_PUTS
	call key
	ret c
ch_2:	ld a,(v_d1)
	call usedrv
	ld a,(v_t0)		; read them
	ld (v_t),a
	ld de,BUF1
rd_1:	push de
	ld a,(v_t)
	call rdtrk		; (a track that cannot be read is compared as it is: wrong)
	pop de
	ld hl,TRK
	add hl,de
	ex de,hl
	ld hl,v_t
	inc (hl)
	ld a,(v_t0)
	ld b,a
	ld a,(v_n)
	add a,b
	cp (hl)
	jr nz,rd_1
	ld a,(v_one)		; ---- then the same tracks of the second
	or a
	jr z,ch_3
	ld hl,m_second
	call OS_PUTS
	call key
	ret c
ch_3:	ld a,(v_d2)
	call usedrv
	ld a,(v_t0)
	ld (v_t),a
	ld hl,BUF1
cm_1:	push hl
	xor a
	ld (v_rd),a
	ld a,(v_t)
	ld de,BUF2
	call rdtrk
	pop hl
	push hl
	ld de,BUF2		; the same?
	ld bc,TRK
cm_2:	ld a,(de)
	cp (hl)
	jr nz,cm_bad
	inc hl
	inc de
	dec bc
	ld a,b
	or c
	jr nz,cm_2
	ld a,(v_rd)
	or a
	jr z,cm_3
cm_bad: call bad
cm_3:	pop hl
	ld de,TRK
	add hl,de
	ld a,(v_t)
	inc a
	ld (v_t),a
	ld b,a
	ld a,(v_t0)
	ld c,a
	ld a,(v_n)
	add a,c
	cp b
	jr nz,cm_1
	ld a,b			; the next chunk
	ld (v_t0),a
	cp 80
	jp nz,chunk
	ld hl,(v_bad)		; the result
	ld a,h
	or l
	jr nz,res_1
	ld hl,m_ok
	jp OS_PUTS
res_1:	call OS_DEC16
	ld hl,m_nbad
	call OS_PUTS
	ld a,1
	jp OS_STATUS

bad:				; "Compare error on side s, track t"
	ld hl,(v_bad)
	inc hl
	ld (v_bad),hl
	ld hl,m_err
	call OS_PUTS
	ld a,(v_t)
	and 1
	add a,'0'
	call OS_PUTC
	ld hl,m_trk
	call OS_PUTS
	ld a,(v_t)
	srl a
	ld l,a
	ld h,0
	call OS_DEC16
	ld a,(v_rd)
	or a
	ld hl,m_unread
	call nz,OS_PUTS
	jp OS_CRLF

rdtrk:				; A = a track (0-79), DE = where: its 9 sectors
	ld l,a			; (v_rd = 1 if one cannot be read)
	ld h,0
	ld b,h
	ld c,l
	add hl,hl		; x9
	add hl,hl
	add hl,hl
	add hl,bc
	ld b,9
rt_1:	push bc
	push hl
	push de
	call OS_RDLBA
	pop de
	pop hl
	pop bc
	jr nc,rt_2
	ld a,1
	ld (v_rd),a
rt_2:	inc hl
	inc d			; + 512
	inc d
	djnz rt_1
	ret

usedrv: 			; A = a drive: raw reads go to it (a fresh read: the track
	add a,'A'		; cache is dropped by the mount).  A disk that cannot be
	ld (v_dn),a		; mounted is fine: the drive is chosen all the same
	ld a,':'
	ld (v_dn+1),a
	ld a,'*'
	ld (v_dn+2),a
	xor a
	ld (v_dn+3),a
	ld hl,v_dn
	jp OS_RESOLVE

drv:				; the next word: A:, B:, A or B -> A = 0 / 1.  CF = not that
	ld de,v_w
	call pl_word
	scf
	ret z
	ld a,(v_w)
	call pl_upper
	sub 'A'
	cp 2
	ccf
	ret c
	ld b,a
	ld a,(v_w+1)
	or a
	jr z,dv_1
	cp ':'
	scf
	ret nz
dv_1:	ld a,b
	or a
	ret

key:	call OS_GETC		; any key; Esc: CF
	call OS_CRLF
	cp 1Bh
	scf
	ret z
	or a
	ret

use:	ld hl,m_use
	jp pl_fail

m_use:	defm "DISKCOMP A: B:   (or A: A: with one drive)"
	defb 0
m_both: defm "The disks to compare in A: and B:, then a key (Esc stops) "
	defb 0
m_first: defm "The FIRST disk in the drive, then a key (Esc stops) "
	defb 0
m_second: defm "The SECOND disk in the drive, then a key (Esc stops) "
	defb 0
m_err:	defm "Compare error on side "
	defb 0
m_trk:	defm ", track "
	defb 0
m_unread: defm " (could not be read)"
	defb 0
m_ok:	defm "Compare OK"
	defb 13,10,0
m_nbad: defm " tracks differ"
	defb 13,10,0

	include "PROGRAMS/PLIB.INC"
