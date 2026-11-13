; ==========================================================================
; TAIL.ASM - TAIL.BIN: the last lines of a text file.
;
;   TAIL [-n] name        the last n lines (10 if no -n)
;
; It reads the file twice: once to count its lines, then to show the end.
; A key pauses it, Esc stops it.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h
P_NAME: equ 9010h
v_n:	equ 9020h		; word: lines wanted
v_all:	equ 9022h		; word: lines in the file
v_last: equ 9024h		; the last byte read
v_name: equ 9030h		; 64 bytes
rf_ptr: equ 9070h
rf_end: equ 9072h
RF_FCB: equ 9080h
RF_BUF: equ 9400h
RF_LEN: equ 1024

start:	ld de,10
	ld (v_n),de
	call nlines
	jp c,use
	ld de,v_name
	call pl_word
	jp z,use
	ld hl,v_name		; 1: count the lines
	call rf_open
	jp c,pl_err
	ld hl,0
	ld (v_all),hl
	ld a,10
	ld (v_last),a
cn_1:	call rf_getc
	jr c,cn_2
	ld (v_last),a
	cp 10
	jr nz,cn_1
	ld hl,(v_all)
	inc hl
	ld (v_all),hl
	jr cn_1
cn_2:	or a
	jp nz,pl_err
	ld a,(v_last)		; a last line with no LF counts too
	cp 10
	jr z,cn_3
	ld hl,(v_all)
	inc hl
	ld (v_all),hl
cn_3:	ld hl,(v_all)		; lines to skip: all - n (or none)
	ld de,(v_n)
	or a
	sbc hl,de
	jr nc,cn_4
	ld hl,0
cn_4:	ld (v_all),hl
	ld hl,v_name		; 2: skip them, show the rest
	call rf_open
	jp c,pl_err
s_1:	ld hl,(v_all)
	ld a,h
	or l
	jr z,pr_1
	call rf_getc
	jr c,end
	cp 10
	jr nz,s_1
	ld hl,(v_all)
	dec hl
	ld (v_all),hl
	jr s_1
pr_1:	call rf_getc
	jr c,end
	call rf_out
	cp 10
	jr nz,pr_1
	call chkkey
	ret c
	jr pr_1
end:	or a
	jp nz,pl_err
	ld a,(v_last)		; (end the last line)
	cp 10
	ret z
	jp OS_CRLF
use:	ld hl,m_use
	jp pl_fail

nlines: call pl_skip
	cp '-'
	ret nz
	inc hl
	call pl_dec
	ret c
	ld (v_n),de
	ret

chkkey: call OS_KBHIT
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

m_use:	defm "TAIL [-n] name   (the last n lines: 10 if no -n)"
	defb 0

	include "PROGRAMS/RFILE.INC"
	include "PROGRAMS/PLIB.INC"
