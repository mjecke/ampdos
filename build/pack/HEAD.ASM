; ==========================================================================
; HEAD.ASM - HEAD.BIN: the first lines of a text file.
;
;   HEAD [-n] name        the first n lines (10 if no -n)
;
; A key pauses it, Esc stops it.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h
P_NAME: equ 9010h
v_n:	equ 9020h		; word: lines left to show
v_name: equ 9030h		; 64 bytes
rf_ptr: equ 9070h
rf_end: equ 9072h
RF_FCB: equ 9080h
RF_BUF: equ 9400h
RF_LEN: equ 1024

start:	ld de,10
	ld (v_n),de
	call nlines		; [-n]
	jr c,use
	ld de,v_name
	call pl_word
	jr z,use
	ld hl,v_name
	call rf_open
	jp c,pl_err
lp:	ld hl,(v_n)
	ld a,h
	or l
	ret z
	call rf_getc
	jr c,end
	call rf_out
	cp 10
	jr nz,lp
	ld hl,(v_n)
	dec hl
	ld (v_n),hl
	call chkkey
	ret c
	jr lp
end:	or a
	jp nz,pl_err
	ret
use:	ld hl,m_use
	jp pl_fail

nlines: 			; "-n" -> v_n (HL past it).  CF = bad
	call pl_skip
	cp '-'
	ret nz
	inc hl
	call pl_dec
	ret c
	ld (v_n),de
	ret

chkkey: call OS_KBHIT		; Esc: CF.  Another key: wait for one more
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

m_use:	defm "HEAD [-n] name   (the first n lines: 10 if no -n)"
	defb 0

	include "PROGRAMS/RFILE.INC"
	include "PROGRAMS/PLIB.INC"
