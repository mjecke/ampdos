; ==========================================================================
; BOOTSEC.ASM - the boot sector of a bootable ampDOS disk.
;
; An original AMPRO boot ROM reads track 0, side 0, sector 1 of drive A to
; 9000h and jumps there, with the ROM on.
; v1.2 rom only does so if the first byte is 21h or 3Eh (LD HL,nn / LD A,n).
;
; The sector is also the FAT12 boot sector: the disk stays an ordinary 360K
; DOS disk.  A DOS disk starts EB 3C 90 (an x86 jump to offset 3Eh); this one
; starts 3E 3C 90 (LD A,3Ch / SUB B: harmless), and a JR in the 8-byte "OEM
; name" field jumps over the BPB to the same offset 3Eh.
;
; The loader finds AMPDOS.SYS in the root directory, follows its clusters
; through the FAT (so the file may lie anywhere),
; reads it to 0A000h, switches the ROM off, copies it to 0000h and
; starts it there.  It drives the WD1772 itself: the ROM versions differ
; inside, so it relies on nothing but the ROM having loaded this sector.
; It reads the layout from the BPB above it.  SYS (SYS.ASM) and FDISK /S
; put this code on a disk. The main build.py makes the whole image with it.
; ==========================================================================

OSLOAD:  equ 0A000h		; AMPDOS.SYS is read here first (24 KB at most)
FATB:	 equ 9400h		; the FAT (2 sectors)
DIRB:	 equ 9800h		; a root directory sector
VARS:	 equ 9200h		; (just past this sector)
curcyl:  equ VARS		; where the head is
settle:  equ VARS+1		; 04h: the next read waits for the head (after a seek)
data0:	 equ VARS+2		; word: the first data sector
dest:	 equ VARS+4		; word: where the next cluster goes
size:	 equ VARS+6		; word: AMPDOS.SYS's size
tries:	 equ VARS+8

BPB_RES: equ 900Eh		; (the BPB, as the ROM loaded it)
BPB_SPF: equ 9016h

	org 9000h

	ld a,3Ch		; 3E 3C : what the v1.2 ROM checks for
	sub b			; 90    : (as in DOS's EB 3C 90)
	jr start		; in the OEM name field, over the BPB
	defm "ampDOS"
	defs 903Eh-$,0		; 900B-903D: the BPB (filled in by whoever writes it)

start:	ld hl,m_load		; (the ROM has the interrupts off, SP = 9000h, and
	call puts		;  the head on cylinder 0 of drive A: it just read
	xor a			;  this sector from there)
	ld (curcyl),a
	ld a,04h
	ld (settle),a
	ld hl,(BPB_RES) 	; the FAT (its first 2 sectors are all of a 360K one)
	ld de,FATB
	call rdsec
	inc hl
	call rdsec
	ld hl,(BPB_RES) 	; the root: after the reserved sectors and the
	ld de,(BPB_SPF) 	; two FATs
	add hl,de
	add hl,de
	push hl
	ld de,7 		; root sectors: 112 entries / 16 (every 360K disk)
	ld b,e
	add hl,de
	ld (data0),hl
	pop hl

rs1:	push bc 		; each root sector: is AMPDOS.SYS in it?
	push hl
	ld de,DIRB
	call rdsec
	ld hl,DIRB
	ld b,16
rs2:	push bc
	push hl
	ld de,m_name
	ld b,11
rs3:	ld a,(de)
	cp (hl)
	jr nz,rs4
	inc hl
	inc de
	djnz rs3
	pop hl			; found: HL = its entry
	pop bc
	pop bc
	pop bc
	jr found
rs4:	pop hl
	ld de,32
	add hl,de
	pop bc
	djnz rs2
	pop hl
	inc hl
	pop bc
	djnz rs1
	ld hl,m_nosys
	jp fail

found:	ld de,26		; first cluster, size
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld (size),bc
	ld hl,OSLOAD
	ld (dest),hl
cl1:	ld a,d			; FF8h and up: the end of the chain
	cp 0Fh
	jr c,cl2
	ld a,e
	cp 0F8h
	jr nc,go
cl2:	push de
	ex de,hl		; sector = data0 + (cluster - 2) * 2
	dec hl			; (2 sectors a cluster: every 360K disk)
	dec hl
	add hl,hl
	ld de,(data0)
	add hl,de
	ld b,2
	ld de,(dest)
cl4:	call rdsec
	inc hl
	djnz cl4
	ld (dest),de
	pop de
	call fatnx		; the next cluster
	jr cl1

go:	ld bc,(size)
	ld a,40h		; ROM off: RAM at 0000-7FFF (no drive selected)
	out (00h),a
	ld hl,OSLOAD
	ld de,0
	ldir
	jp 0			; ampDOS's reset entry

fatnx:	ld h,d			; DE = a cluster -> DE = the next one (FAT12)
	ld l,e
	srl h
	rr l
	add hl,de		; cluster * 3 / 2
	ld bc,FATB
	add hl,bc
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	bit 0,e
	jr z,fn2
	ld b,4			; odd: the upper 12 bits
fn1:	srl h
	rr l
	djnz fn1
fn2:	ld a,h
	and 0Fh
	ld d,a
	ld e,l
	ret

rdsec:	push bc 		; read sector HL (LBA) to DE; DE += 512.  Keeps BC, HL
	push hl
	ld c,0			; cylinder = LBA / 18, then side, sector
rd1:	ld a,l
	sub 18
	ld l,a
	ld a,h
	sbc a,0
	jr c,rd2
	ld h,a
	inc c
	jr rd1
rd2:	ld a,l
	add a,18		; A = 0..17
	ld b,01h		; side 0: board control 01h, side 1: 11h
	cp 9
	jr c,rd3
	sub 9
	ld b,11h
rd3:	inc a
	out (0C2h),a		; the sector register
	ld a,b
	out (00h),a
	ld a,(curcyl)		; on the right cylinder?
	cp c
	jr z,rd4
	ld a,c
	ld (curcyl),a
	out (0C3h),a		; Seek (6 ms steps)
	ld a,10h
	call fcmd
fwait:	in a,(0C4h)		; (until it is no longer busy)
	rrca
	jr c,fwait
	ld a,04h
	ld (settle),a
rd4:	ld a,5
	ld (tries),a
rd5:	push de
	ex de,hl
	ld a,(settle)		; Read Sector (+ head settle after a seek)
	or 80h
	call fcmd
rd6:	in a,(0C4h)		; busy?  then a byte?
	rrca
	jr nc,rd7
	rrca
	jr nc,rd6
	in a,(0C7h)
	ld (hl),a
	inc hl
	jr rd6
rd7:	ex de,hl
	in a,(0C4h)		; lost data, CRC, record not found?
	and 1Ch
	jr z,rd8
	pop de			; again, into the same place
	ld a,04h
	ld (settle),a
	ld hl,tries
	dec (hl)
	jr nz,rd5
	ld hl,m_err
	jr fail
rd8:	pop af			; (DE has moved on by 512)
	xor a
	ld (settle),a
	ld a,d			; " ." each time the load address passes a 4 KB
	and 0Fh 		; boundary: 6 of them for a 24 KB AMPDOS.SYS
	or e
	ld hl,m_dot
	call z,puts
	pop hl
	pop bc
	ret

fail:	call puts		; say what, and stop (press reset to try again:
	halt			;  the interrupts are off, so this is for good)

fcmd:	out (0C0h),a		; a command, then wait until the FDC is busy
	ld b,20
fc1:	djnz fc1
fc2:	in a,(0C4h)
	rrca
	jr nc,fc2
	ret

puts:	ld a,(hl)
	or a
	ret z
	call putc
	inc hl
	jr puts

putc:	push af 		; the console, as the ROM set it up
pc1:	in a,(84h)
	and 04h
	jr z,pc1
	pop af
	out (80h),a
	ret

m_name: defm "AMPDOS  SYS"
m_load: defb 13,10
	defm "booting"
m_dot:	defm " ."
	defb 0
m_nosys: defb 13,10
	defm "no AMPDOS.SYS"
	defb 0
m_err:	defb 13,10
	defm "error"
	defb 0

	defs 91FEh-$,0
	defb 55h,0AAh		; the DOS boot sector mark
