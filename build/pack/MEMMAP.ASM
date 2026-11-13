; ==========================================================================
; MEMMAP.ASM - MEMMAP.BIN: the 64 KB of memory as a picture, and what is where.
;
;   MEMMAP
;
; 16 lines of 64 characters, a character for each 64 bytes, a letter for what
; uses them; then the list: the letter, from-to (hex), the size, and what.
; The OS's own size is AMPDOS.SYS's (A:\AMPDOS.SYS, which the ROM loaded);
; the buffers are where KERNEL/INC/BUFS.INC puts them.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"
	include "KERNEL/INC/BUFS.INC"

P_PAT:	equ 9000h
P_NAME: equ 9010h
v_fcb:	equ 9020h		; 16 bytes
v_a:	equ 9030h		; word: the address being drawn
v_n:	equ 9032h		; regions shown on this line of the list
v_osend: equ 9034h		; word
RSZ:	equ 7			; a region: letter, from, to, what

start:	ld hl,m_os		; the OS's size: AMPDOS.SYS's
	call OS_RESOLVE
	jr c,st_1
	ld ix,v_fcb
	call OS_OPEN
	jr c,st_1
	ld hl,(v_fcb+FCB_SIZE)
	jr st_2
st_1:	ld hl,SHBUF		; (not found: as if it filled its room)
st_2:	ld (v_osend),hl
	ld (rgn+3),hl		; the OS's end, and the free room after it
	ld (rgn+RSZ+1),hl
	ld hl,m_title		; "ampDOS 0.8.7: 64 KB"
	call OS_PUTS
	call OS_VERSION
	push af
	ld a,h
	call dec8
	ld a,'.'
	call OS_PUTC
	ld a,l
	call dec8
	ld a,'.'
	call OS_PUTC
	pop af
	call dec8
	ld hl,m_title2
	call OS_PUTS
	ld hl,0 		; ---- the picture
	ld (v_a),hl
pc_1:	ld a,(v_a+1)		; a line: its address, 64 characters
	call OS_HEX8
	ld a,(v_a)
	call OS_HEX8
	ld a,' '
	call OS_PUTC
	ld b,64
pc_2:	push bc
	ld hl,(v_a)
	call which		; -> A = its letter
	call OS_PUTC
	ld hl,(v_a)
	ld de,64
	add hl,de
	ld (v_a),hl
	pop bc
	djnz pc_2
	call OS_CRLF
	ld hl,(v_a)
	ld a,h
	or l
	jr nz,pc_1
	call OS_CRLF
	ld hl,rgn		; ---- the list, two to a line
	xor a
	ld (v_n),a
ls_1:	ld a,(hl)
	or a
	jr z,ls_end
	push hl 		; (an empty one, from = to: left out)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	or a
	sbc hl,de
	pop hl
	jr nz,ls_2
	ld de,RSZ
	add hl,de
	jr ls_1
ls_2:	push hl
	call entry
	pop hl
	ld de,RSZ
	add hl,de
	ld a,(v_n)
	xor 1
	ld (v_n),a
	jr nz,ls_1
	call OS_CRLF
	jr ls_1
ls_end: ld a,(v_n)
	or a
	ret z
	jp OS_CRLF

which:				; HL = an address -> A = the letter of its region
	ld ix,rgn
wh_1:	ld a,(ix+0)
	or a
	ld a,'?'
	ret z
	ld e,(ix+1)		; HL >= from?
	ld d,(ix+2)
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,wh_n
	ld e,(ix+3)		; and HL < to (0: the end of memory)?
	ld d,(ix+4)
	ld a,d
	or e
	jr z,wh_y
	push hl
	or a
	sbc hl,de
	pop hl
	jr nc,wh_n
wh_y:	ld a,(ix+0)
	ret
wh_n:	ld de,RSZ
	add ix,de
	jr wh_1

entry:				; HL = a region: "c ffff-tttt nnnnn  what" (39 wide)
	push hl
	pop ix
	ld a,(ix+0)
	call OS_PUTC
	ld a,' '
	call OS_PUTC
	ld l,(ix+1)
	ld h,(ix+2)
	call OS_HEX16
	ld a,'-'
	call OS_PUTC
	ld e,(ix+3)		; (to - 1)
	ld d,(ix+4)
	dec de
	ex de,hl
	call OS_HEX16
	ld a,' '
	call OS_PUTC
	ld e,(ix+3)		; the size: to - from
	ld d,(ix+4)
	ld l,(ix+1)
	ld h,(ix+2)
	ex de,hl
	or a
	sbc hl,de
	call dec5
	ld a,' '
	call OS_PUTC
	ld l,(ix+5)		; what
	ld h,(ix+6)
	call OS_PUTS
	ld a,(v_n)		; the left one: spaces to column 40
	or a
	ret nz
	ld b,0
en_1:	ld a,(hl)
	or a
	jr z,en_2
	inc hl
	inc b
	jr en_1
en_2:	ld a,21
	sub b
	ret c
	inc a
	ld b,a
en_3:	ld a,' '
	call OS_PUTC
	djnz en_3
	ret

dec5:	ld de,10000		; HL in 5 places
	call d5_sp
	ld de,1000
	call d5_sp
	ld de,100
	call d5_sp
	ld de,10
	call d5_sp
	jp OS_DEC16
d5_sp:	push hl
	or a
	sbc hl,de
	pop hl
	ret nc
	ld a,' '
	jp OS_PUTC
dec8:	push hl
	ld l,a
	ld h,0
	call OS_DEC16
	pop hl
	ret

; the regions: letter, from, to (0 = the end of memory), what
rgn:	defb 'O'
	defw 0,SHBUF,m_r0	; (to: AMPDOS.SYS's size, set at the start)
	defb '-'
	defw SHBUF,SHBUF,m_r1	; (from: the same)
	defb 'h'
	defw SHBUF,BATBUF,m_r2
	defb 'b'
	defw BATBUF,VFYBUF,m_r3
	defb 'v'
	defw VFYBUF,TRKBUF,m_r4
	defb 'c'
	defw TRKBUF,FATBUF,m_r5
	defb 'f'
	defw FATBUF,SECBUF,m_r6
	defb 's'
	defw SECBUF,DIRBUF,m_r7
	defb 'd'
	defw DIRBUF,SH_PATH0,m_r8
	defb 'p'
	defw SH_PATH0,TPA,m_r9
	defb 'P'
	defw TPA,pend,m_r10
	defb '.'
	defw pend,TPA_TOP,m_r11
	defb 'V'
	defw TPA_TOP,OSCALLS,m_r12
	defb 'T'
	defw OSCALLS,0,m_r13
	defb 0

m_r0:	defm "the OS (AMPDOS.SYS)"
	defb 0
m_r1:	defm "room left for the OS"
	defb 0
m_r2:	defm "history, SET, screen"
	defb 0
m_r3:	defm "batch files"
	defb 0
m_r4:	defm "write verify"
	defb 0
m_r5:	defm "the track cache"
	defb 0
m_r6:	defm "the FAT"
	defb 0
m_r7:	defm "a file's sector"
	defb 0
m_r8:	defm "a directory sector"
	defb 0
m_r9:	defm "paths, variables"
	defb 0
m_r10:	defm "MEMMAP itself"
	defb 0
m_r11:	defm "free for programs"
	defb 0
m_r12:	defm "OS variables, stack"
	defb 0
m_r13:	defm "the OS call table"
	defb 0
m_os:	defm "A:\\AMPDOS.SYS"
	defb 0
m_title:
	defm "ampDOS "
	defb 0
m_title2:
	defm ": 64 KB of memory, a character for each 64 bytes"
	defb 13,10,0

	include "PROGRAMS/PLIB.INC"
pend:
