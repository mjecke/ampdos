; ==========================================================================
; SCANDISK.ASM - SCANDISK.BIN: read every sector of a disk, and show where it
; is sound.
;
;   SCANDISK [d:] [/F]
;
;   cylinder  0000000000111111111122222222223333333333
;             0123456789012345678901234567890123456789
;             ..........0.............................
;   . both sides read   0 side 0 not   1 side 1 not   B neither
;
; Every track of the 360K disk (40 cylinders, 2 sides, 9 sectors) is read,
; even on a disk that is not formatted or not FAT.  ampDOS reads a track at a
; time, so one bad sector makes all 9 of its track unreadable: the bad tracks
; are listed, 10 to a line, and on a FAT disk with a letter for what is on each
; (the worst): the system area (boot sector, FATs, root directory: the disk is
; not safe), a file (copy what you can off the disk), a cluster marked bad
; already, or free clusters.  Then how many clusters of each kind, once.  /F
; marks the free clusters on bad tracks as bad in the FAT, so no file is given
; them.  Esc stops.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h
P_NAME: equ 9010h
v_drv:	equ 9020h
v_fix:	equ 9021h
v_fat:	equ 9022h		; 1 = a FAT disk (mounted)
v_cyl:	equ 9023h
v_side: equ 9024h
v_badt: equ 9025h		; this cylinder: bit 0 side 0 bad, bit 1 side 1
v_trk:	equ 9026h		; the track (cylinder * 2 + side)
v_nbad: equ 9027h		; bad tracks
v_spc:	equ 9028h
v_data: equ 902Ah		; word: the first data sector
v_marked: equ 902Ch		; word: clusters marked bad (/F)
v_inuse: equ 902Eh		; word: clusters in files
v_sys:	equ 9030h		; bad tracks in the system area
v_free: equ 9032h		; word: free clusters (no /F)
v_already: equ 9034h		; word: clusters marked bad already
v_lastc: equ 9036h		; word: the cluster counted last (one may cross two tracks)
v_col:	equ 9038h		; tracks on this line of the list
v_mark: equ 9039h		; this track's letter
v_sec:	equ 903Ah		; word: the sector being looked at
v_left: equ 903Ch		; sectors of the track still to look at
v_w:	equ 9040h		; 16 bytes
v_dn:	equ 9050h		; "d:*"
BADS:	equ 9100h		; bytes: the bad tracks
SBUF:	equ 9400h		; a sector

start:	xor a
	ld (v_fix),a
	call OS_DRIVE
	add a,'A'
	ld (v_drv),a
st_1:	ld de,v_w
	call pl_word
	jr z,st_go
	ld a,(v_w)
	cp '/'
	jr z,st_sw
	call pl_upper
	cp 'A'
	jp c,use
	cp 'C'
	jp nc,use
	ld (v_drv),a
	ld a,(v_w+1)
	or a
	jr z,st_1
	cp ':'
	jp nz,use
	jr st_1
st_sw:	ld a,(v_w+1)
	call pl_upper
	cp 'F'
	jp nz,use
	ld a,1
	ld (v_fix),a
	jr st_1
st_go:	ld hl,v_dn		; that drive (a fresh read: the cache goes)
	ld a,(v_drv)
	ld (hl),a
	inc hl
	ld (hl),':'
	inc hl
	ld (hl),'*'
	inc hl
	ld (hl),0
	ld hl,v_dn
	call OS_RESOLVE
	ld a,0
	jr c,st_2		; (not FAT: the sectors all the same)
	inc a
st_2:	ld (v_fat),a
	or a
	call nz,layout
	xor a
	ld (v_nbad),a
	ld (v_sys),a
	ld (v_trk),a
	ld hl,0
	ld (v_marked),hl
	ld (v_inuse),hl
	ld (v_free),hl
	ld (v_already),hl
	ld (v_lastc),hl
	ld hl,m_head
	call OS_PUTS
	xor a
	ld (v_cyl),a
cy_1:	xor a			; ---- a cylinder: both sides
	ld (v_badt),a
	ld (v_side),a
cy_2:	ld a,(v_trk)		; its first sector: the whole track is read
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,de		; x 9
	ld de,SBUF
	call OS_RDLBA
	call c,bad
	ld hl,v_trk
	inc (hl)
	call OS_KBHIT		; Esc stops
	jr z,cy_4
	call OS_GETC
	cp 1Bh
	jr z,stopped
cy_4:	ld a,(v_side)
	inc a
	ld (v_side),a
	cp 2
	jr c,cy_2
	ld a,(v_badt)		; its mark
	ld e,a
	ld d,0
	ld hl,m_marks
	add hl,de
	ld a,(hl)
	call OS_PUTC
	ld a,(v_cyl)
	inc a
	ld (v_cyl),a
	cp 40
	jr c,cy_1
	call OS_CRLF
	ld hl,m_legend
	call OS_PUTS
	jp report
stopped:
	call OS_CRLF
	ld hl,m_stop
	call OS_PUTS
	jp report

bad:				; track v_trk could not be read
	ld a,(v_side)
	inc a
	ld b,a
	ld a,(v_badt)
	or b
	ld (v_badt),a
	ld a,(v_nbad)
	ld e,a
	ld d,0
	ld hl,BADS
	add hl,de
	ld a,(v_trk)
	ld (hl),a
	ld hl,v_nbad
	inc (hl)
	ret

; ---- the report:
;
;   3 tracks could not be read (cylinder/side), so none of their sectors:
;    6/1 f   7/0 u  38/1 f
;   s system area   u a file   b marked bad already   f free   m marked bad now
;     4 free clusters: SCANDISK /F marks them bad, so no file is given them
;     ...
report: ld a,(v_nbad)
	or a
	jr nz,rp_1
	ld a,(v_trk)		; (all of them: 720 sectors; fewer if stopped)
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,de
	call OS_DEC16
	ld hl,m_allok
	jp OS_PUTS
rp_1:	ld l,a
	ld h,0
	call OS_DEC16
	ld hl,m_nbad
	call OS_PUTS
	xor a
	ld (v_col),a
	ld hl,BADS
	ld a,(v_nbad)
	ld b,a
rp_3:	push bc
	push hl
	ld a,(hl)
	call onet
	pop hl
	inc hl
	pop bc
	djnz rp_3
	ld a,(v_col)		; (the last line ended)
	or a
	call nz,OS_CRLF
	ld a,(v_fat)
	or a
	jr nz,rp_6
	ld hl,m_nofat
	ld a,(BADS)		; (track 0 bad: the boot sector and FAT are on it)
	or a
	jr nz,rp_5
	ld hl,m_trk0
rp_5:	call OS_PUTS
	jr rp_e2
rp_6:	ld hl,m_key
	call OS_PUTS
	ld a,(v_sys)		; how many of each, and what it means
	ld l,a
	ld h,0
	ld de,m_sys
	call count
	ld hl,(v_inuse)
	ld de,m_used
	call count
	ld hl,(v_already)
	ld de,m_already
	call count
	ld hl,(v_free)
	ld de,m_free
	call count
	ld hl,(v_marked)
	ld a,h
	or l
	jr z,rp_e2
	call OS_FLUSH		; (/F: the FAT written)
	jp c,pl_err
	ld hl,(v_marked)
	ld de,m_marked
	call count
rp_e2:	ld a,1			; (status 1: bad tracks)
	jp OS_STATUS

count:				; HL of them, DE = what they are (none: nothing)
	ld a,h
	or l
	ret z
	push de
	push hl
	ld a,' '
	call OS_PUTC
	call OS_PUTC
	pop hl
	call OS_DEC16
	pop hl
	jp OS_PUTS

onet:				; A = a bad track: " 6/1 f", 2 spaces between: 10 = 78 wide
	push af
	ld a,(v_col)
	or a
	ld a,' '
	call nz,OS_PUTC
	call nz,OS_PUTC
	pop af
	push af
	srl a			; the cylinder, 2 wide
	ld l,a
	ld h,0
	cp 10
	ld a,' '
	call c,OS_PUTC
	call OS_DEC16
	ld a,'/'
	call OS_PUTC
	pop af
	push af
	and 1
	add a,'0'		; the side
	call OS_PUTC
	ld a,' '
	call OS_PUTC
	pop af
	call what		; its letter
	call OS_PUTC
	ld hl,v_col		; 10 to a line
	inc (hl)
	ld a,(hl)
	cp 10
	ret c
	ld (hl),0
	jp OS_CRLF

what:				; A = a bad track -> A = its letter; its clusters counted
	ld l,a			; (and with /F the free ones marked)
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,de
	ld (v_sec),hl		; its first sector
	ld a,(v_fat)
	or a
	ld a,' '		; (not a FAT disk: no letter)
	ret z
	ld a,9
	ld (v_left),a
	ld a,'f'		; the best there is: free
	ld (v_mark),a
wh_1:	ld hl,(v_sec)
	call cluster		; HL = its cluster, CF = the system area
	jr nc,wh_2
	ld a,'s'		; the system area: the worst
	ld (v_mark),a
	jr wh_next
wh_2:	ld de,(v_lastc) 	; (a cluster counted already: on the track before,
	or a			; or a sector before)
	sbc hl,de
	add hl,de
	jr z,wh_next
	ld (v_lastc),hl
	push hl
	call OS_FATGET
	ld a,h
	or l
	jr z,wh_free
	ld a,h
	cp 0Fh
	jr nz,wh_used
	ld a,l
	cp 0F7h
	jr nz,wh_used
	pop hl
	ld hl,(v_already)
	inc hl
	ld (v_already),hl
	ld b,'b'
	jr wh_lt
wh_used:
	pop hl
	ld hl,(v_inuse)
	inc hl
	ld (v_inuse),hl
	ld b,'u'
	jr wh_lt
wh_free:
	pop hl
	ld a,(v_fix)
	or a
	jr z,wh_f1
	ld de,0FF7h		; /F: marked bad
	call OS_FATSET
	ld hl,(v_marked)
	inc hl
	ld (v_marked),hl
	ld b,'m'
	jr wh_lt
wh_f1:	ld hl,(v_free)
	inc hl
	ld (v_free),hl
	ld b,'f'
wh_lt:	ld a,(v_mark)		; the worse letter: s > u > b > m > f
	call rank
	ld c,a
	ld a,b
	call rank
	cp c
	jr c,wh_next
	ld a,b
	ld (v_mark),a
wh_next:
	ld hl,(v_sec)
	inc hl
	ld (v_sec),hl
	ld hl,v_left
	dec (hl)
	jp nz,wh_1
	ld a,(v_mark)
	cp 's'
	ret nz
	ld hl,v_sys		; (counted by tracks)
	inc (hl)
	ret

rank:				; A = a letter -> A = how bad (f 0, m 1, b 2, u 3, s 4)
	push hl
	push bc
	ld hl,m_rank
	ld bc,5
	cpir
	ld a,4
	sub c
	pop bc
	pop hl
	ret
m_rank: defm "fmbus"

cluster:			; HL = a sector -> HL = its cluster, CF = the system area
	ld de,(v_data)
	or a
	sbc hl,de
	ret c
	ld a,(v_spc)		; cluster = (sector - data) / spc + 2
cl_1:	srl a
	jr z,cl_2
	srl h
	rr l
	jr cl_1
cl_2:	inc hl
	inc hl
	or a
	ret

layout: 			; a FAT disk: sectors a cluster, where the data starts
	call OS_DISK
	ld (v_spc),a
	ld hl,0
	ld de,SBUF
	call OS_RDLBA
	jr nc,la_1
	xor a
	ld (v_fat),a
	ret
la_1:	ld ix,SBUF
	ld e,(ix+16h)
	ld d,(ix+17h)
	ld b,(ix+10h)
	ld hl,0
la_2:	add hl,de
	djnz la_2
	ld e,(ix+0Eh)
	ld d,(ix+0Fh)
	add hl,de
	push hl
	ld l,(ix+11h)
	ld h,(ix+12h)
	ld de,15
	add hl,de
	ld b,4
la_3:	srl h
	rr l
	djnz la_3
	pop de
	add hl,de
	ld (v_data),hl
	ret

use:	ld hl,m_use
	jp pl_fail

m_use:	defm "SCANDISK [d:] [/F]   (every track read; /F marks free bad clusters)"
	defb 0
m_head: defm "cylinder  0000000000111111111122222222223333333333"
	defb 13,10
	defm "          0123456789012345678901234567890123456789"
	defb 13,10
	defm "          "
	defb 0
m_marks:
	defm ".01B"
m_legend:
	defm ". both sides read   0 side 0 not   1 side 1 not   B neither"
	defb 13,10,0
m_stop: defm "(stopped)"
	defb 13,10,0
m_allok:
	defm " sectors read: all of them good"
	defb 13,10,0
m_nbad: defm " tracks could not be read (cylinder/side), so none of their sectors:"
	defb 13,10,0
m_nofat:
	defm "(not a FAT disk: no files to say about)"
	defb 13,10,0
m_trk0: defm "Track 0 (the boot sector, FAT, root) could not be read: do not trust this disk"
	defb 13,10,0
m_key:	defm "s system area   u a file   b marked bad already   f free   m marked bad now"
	defb 13,10,0
m_sys:	defm " tracks in the system area (boot, FAT, root): do not trust this disk"
	defb 13,10,0
m_used: defm " clusters in files: copy what you can off this disk"
	defb 13,10,0
m_already:
	defm " clusters marked bad already"
	defb 13,10,0
m_free: defm " free clusters: SCANDISK /F marks them bad, so no file is given them"
	defb 13,10,0
m_marked:
	defm " free clusters now marked bad: no file will be given them"
	defb 13,10,0

	include "PROGRAMS/PLIB.INC"
