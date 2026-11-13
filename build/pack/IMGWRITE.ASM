; ==========================================================================
; IMGWRITE.ASM - IMGWRITE A: | B:  write a whole 360K disk image, sent from the
; PC over Serial B, onto the disk in drive A (or B).  The PC side is
; tools/pc/imgsend.py.  Every track is formatted, written and read back.
; EVERYTHING ON THE TARGET DISK IS LOST.
;
; Its buffers are 9400h-D0FFh (and the OS's own, which it uses through its copy
; of the floppy driver).  The disk IMGWRITE was loaded from may be taken out
; before starting.
;
; It uses the OS's own variables (RAM.INC) and its floppy driver, so it runs
; only on the OS it was built with: it checks OS_VERSION first: an IMGWRITE from
; another version could switch the ROM back on under the OS and reboot the board.
;
; The protocol (the Ampro asks, so the PC never sends faster than it writes):
;   Ampro: SYN 'J' SYN 'I' (every ~2 s)  PC: 'G'
;          (J: fill tracks are understood; I: full tracks only)
;   Ampro: 'T' t   (t = 0..79 = cyl*2 + side)
;   PC:    'D' 4608 bytes (track t of the image) sum(2: 16-bit sum, low first)
;      or  'F' b b  : a track of 4608 times the byte b (sent twice, as a check).
;          At 9600 baud a track takes 4.8 s to send; an empty one, 3 ms.  It
;          is written like any other: formatting alone cannot give F6h (the
;          WD1772 writes F6h in a format as C2h, a sync mark).
;   (a bad sum or a timeout: the Ampro asks for the same track again)
;   Ampro: 'Z' at the end, or 'E' code on a failure (1 write, 2 serial, 3 Esc)
; ==========================================================================
	org 8000h

	include "KERNEL/MACHINE/AMPRO/HW.INC"
	include "KERNEL/INC/BUFS.INC"
	include "KERNEL/INC/RAM.INC"
	include "GEN/VERSION.INC"	; OS_VER, OS_PATCH: the OS this is built for

OSC_PUTC:  equ OSCALLS+3
OSC_GETC:  equ OSCALLS+6
OSC_KBHIT: equ OSCALLS+9
OSC_PUTS:  equ OSCALLS+12
OSC_CRLF:  equ OSCALLS+15
OSC_DEC16: equ OSCALLS+24
OSC_MTOP:  equ OSCALLS+90	  ; OS_MEMTOP
OSC_VER:   equ OSCALLS+72	  ; OS_VERSION

IMG:	 equ 9400h		; 6400 bytes: the Write Track image
DATA:	 equ 0AD00h		; 4608 bytes: the track from the PC
RBK:	 equ 0BF00h		; 4608 bytes: the track read back
TRKLEN:  equ 4608
NTRK:	 equ 80
SYN:	 equ 16h

start:	ld (savesp),sp
	push hl
	call OSC_VER		; the OS it was built with?
	ld de,OS_VER
	or a
	sbc hl,de
	jr nz,st_ver
	cp OS_PATCH
	jr z,st_v1
st_ver: pop hl
	ld hl,m_ver
	jp OSC_PUTS
st_v1:	call OSC_MTOP		  ; the buffers must be free RAM (not with > file)
	ld de,0D100h
	or a
	sbc hl,de
	pop hl
	jr nc,st0
	ld hl,m_layout
	jp OSC_PUTS
st0:	ld a,(hl)		; the drive must be given: A, A:, B or B:
	and 0DFh		; (everything on its disk is replaced)
	sub 'A'
	cp 2
	jp nc,st_use
	ld b,a
	inc hl
	ld a,(hl)
	cp ':'
	jr nz,st0b
	inc hl
	ld a,(hl)
st0b:	or a
	jr z,st0c
	cp ' '
	jp nz,st_use
st0c:	ld a,b
st1:	ld (drv),a
	add a,'A'
	ld (m_drv),a
	ld hl,m_hello
	call OSC_PUTS
	call OSC_GETC
	and 0DFh
	cp 'Y'
	jp nz,stop
	call OSC_CRLF
	ld a,(con_mirror)	; Serial B is ours now: no console copy on it
	ld (mir),a
	xor a
	ld (con_mirror),a
	call siob_init
	call fd_init		; the drives
	ld a,(drv)
	call fd_select
	jp c,e_disk
	call fd_restore
	jp c,e_disk
	call fd_present
	jp c,e_nodisk
	ld hl,IMG
	call fd_mk_image
	ld hl,m_wait
	call OSC_PUTS

sy0:	ld a,SYN		; ---- wait for the PC
	call siob_putc
	ld a,'J'
	call siob_putc
	ld a,SYN
	call siob_putc
	ld a,'I'
	call siob_putc
	call rx_t
	jr c,sy0
	cp 'G'
	jr nz,sy0
	xor a
	ld (trk),a

tr0:	ld a,6			; ---- each track: ask, receive, check, write
	ld (tries),a
tr1:	ld a,'T'
	call siob_putc
	ld a,(trk)
	call siob_putc
	call rx_t
	jp c,tr_again
	cp 'F'
	jr z,tr_fill
	cp 'D'
	jp nz,tr_again
	ld hl,DATA
	ld bc,TRKLEN
	ld de,0 		; DE = the sum
tr2:	call rx_t
	jr c,tr_again
	ld (hl),a
	inc hl
	add a,e
	ld e,a
	jr nc,tr3
	inc d
tr3:	dec bc
	ld a,b
	or c
	jr nz,tr2
	call rx_t		; the PC's sum
	jr c,tr_again
	ld (sumlo),a
	call rx_t
	jr c,tr_again
	cp d
	jr nz,tr_again
	ld a,(sumlo)
	cp e
	jr nz,tr_again
tr_wr:	call wr_track		; onto the disk
	jp c,e_write
	ld hl,m_trk		; "track nn of 80 written" on one line
	call OSC_PUTS
	ld a,(trk)
	inc a
	ld (trk),a
	ld l,a
	ld h,0
	call OSC_DEC16
	ld hl,m_trk2
	call OSC_PUTS
	ld a,(trk)
	cp NTRK
	jr nz,tr0
	ld a,'Z'		; all done
	call siob_putc
	ld hl,m_done
	call OSC_PUTS
	jp quit

tr_fill:			; 'F' b b: the whole track is b
	call rx_t
	jr c,tr_again
	ld e,a
	call rx_t
	jr c,tr_again
	cp e
	jr nz,tr_again
	ld hl,DATA		; (DATA: what the read-back must find)
	ld (hl),a
	ld de,DATA+1
	ld bc,TRKLEN-1
	ldir
	jr tr_wr

tr_again:			; a bad block: let the line go quiet, ask again
	call drain
	ld hl,tries
	dec (hl)
	jp nz,tr1
	jp e_serial

wr_track:			; format, write and read back track (trk).  CF = failed
	ld a,3
	ld (wtry),a
wt1:	call wt_cs
	ld hl,IMG
	call fd_fmt_track
	jr c,wt_bad
	call wt_cs
	ld hl,DATA
	call fd_wr_track
	jr c,wt_bad
	call wt_cs
	ld hl,RBK
	call fd_rd_track
	jr c,wt_bad
	ld hl,DATA		; the same, byte for byte?
	ld de,RBK
	ld bc,TRKLEN
wt2:	ld a,(de)
	cp (hl)
	jr nz,wt_bad
	inc hl
	inc de
	dec bc
	ld a,b
	or c
	jr nz,wt2
	ret			; (NC)
wt_bad: ld hl,wtry
	dec (hl)
	jr nz,wt1
	scf
	ret
wt_cs:	ld a,(trk)		; A = cylinder, C = side
	and 1
	ld c,a
	ld a,(trk)
	srl a
	ret

rx_t:	push bc 		; A = a byte from Serial B, CF = none in ~2 s.
	push de 		; Keeps BC, DE, HL.  Esc on the console stops all.
	ld b,3
	ld de,0
rxt1:	call siob_getc
	jr nc,rxt3
	dec de
	ld a,e
	or a
	jr nz,rxt2
	push hl 		; (every 256 turns: a look at the console)
	call OSC_KBHIT
	jr z,rxt4
	call OSC_GETC
	cp 1Bh
	jp z,e_esc
rxt4:	pop hl
rxt2:	ld a,d
	or e
	jr nz,rxt1
	djnz rxt1
	scf
rxt3:	pop de
	pop bc
	ret

drain:	call rx_t		; read until the line has been quiet for ~2 s
	jr nc,drain
	ret

e_write:
	ld a,1
	call fail
	ld hl,m_ewrite
	call OSC_PUTS
	ld a,(trk)
	ld l,a
	ld h,0
	call OSC_DEC16
	ld hl,m_ewrite2
	jr quitm
e_serial:
	ld a,2
	call fail
	ld hl,m_eser
	jr quitm
e_esc:	ld sp,(savesp)
	ld a,3
	call fail
	ld hl,m_esc
	jr quitm
e_disk: ld hl,m_edisk
	jr quitm
e_nodisk:
	ld hl,m_enodisk
quitm:	call OSC_PUTS
quit:	ld a,(mir)		; the console copy as it was
	ld (con_mirror),a
stop:	ld sp,(savesp)
	jp OSC_CRLF

fail:	push af 		; tell the PC: 'E', code
	ld a,'E'
	call siob_putc
	pop af
	jp siob_putc

st_use: ld hl,m_use
	jp OSC_PUTS
m_use:	  defm "IMGWRITE A: | B:   (the drive whose disk the image replaces)"
	defb 13,10,0
m_ver:	  defm "This IMGWRITE.BIN is not for this OS: use the one that came with it"
	defb 13,10,0
m_layout: defm "IMGWRITE needs the memory up to D0FFh (not with > file)"
	defb 13,10,0
m_hello:  defm "IMGWRITE: a 360K disk image from the PC (Serial B) onto the disk in drive "
m_drv:	  defm "A:"
	defb 13,10
	defm "Every track is formatted, written and read back.  EVERYTHING ON THAT DISK"
	defb 13,10
	defm "IS LOST.  Put the disk in now, then press Y to start (any other key stops): "
	defb 0
m_wait:   defm "Waiting for the PC: python3 imgsend.py FILE.IMG   (Esc stops)"
	defb 13,10,0
m_trk:	  defb 13
	defm "  track "
	defb 0
m_trk2:   defm " of 80 written and checked  "
	defb 0
m_done:   defb 13,10
	defm "Done: the whole disk is written and checked."
	defb 13,10,0
m_ewrite: defb 13,10
	defm "FAILED: track "
	defb 0
m_ewrite2: defm " could not be written and read back (a bad disk?)"
	defb 13,10,0
m_eser:   defb 13,10
	defm "FAILED: the PC stopped answering"
	defb 13,10,0
m_esc:	  defb 13,10
	defm "Stopped (Esc).  The disk is only partly written."
	defb 13,10,0
m_edisk:  defm "FAILED: the drive does not answer"
	defb 13,10,0
m_enodisk: defm "FAILED: no disk turning in the drive"
	defb 13,10,0

savesp: defw 0
drv:	defb 0
mir:	defb 0
trk:	defb 0
tries:	defb 0
wtry:	defb 0
sumlo:	defb 0

	include "KERNEL/MACHINE/AMPRO/SIOB.ASM"
	include "KERNEL/MACHINE/AMPRO/FD.ASM"
prog_end:
