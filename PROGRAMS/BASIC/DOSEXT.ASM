; ==========================================================================
; DOSEXT.ASM - BASIC's ampdos extension: LOAD, SAVE and DOS, through the OS
; calls (KERNEL/INC/OS.INC).  mkbasic.py appends this to the converted BASIC source
; and hooks it in (see there).  IOMODE bits used here (the others: SEREXT.ASM):
;   10h = SAVE: LIST goes into the file      20h = LOAD: input comes from the file
; BASIC runs from RAM, so this part keeps its variables right here.  Its file
; buffers are where BASIC's start-up code was loaded (see DXFCB, at the end).
; ==========================================================================

DXEXTLEN: equ 4 		; ".BAS"

; ---- input: from the LOAD file, else what DXARG typed, else as before
DXRX:	ld a,(IOMODE)
	bit 5,a
	jr nz,dx_frx
	push hl
	ld hl,(DXFEED)
	ld a,h
	or l
	jr z,dxr_old
	ld a,(hl)
	inc hl
	ld (DXFEED),hl
	or a
	jr z,dxr_end
	pop hl
	ret
dxr_end:
	ld hl,0
	ld (DXFEED),hl
dxr_old:
	pop hl
	jp EXTRX2

dx_frx: in a,(DARTAC)		; any key stops the LOAD
	bit 0,a
	jp nz,SBABRT
	push bc
	push de
	push hl
dxf_1:	call dx_getb
	jr c,dxf_eof
	ld b,a
	ld a,(DXPREV)
	ld c,a
	ld a,b
	ld (DXPREV),a
	cp 10
	jr nz,dxf_2
	ld a,c			; LF after CR: skip; a bare LF ends a line too
	cp 13
	jr z,dxf_1
	ld a,13
	jr dxf_ok
dxf_2:	cp 1Ah			; ^Z: the end, as in CP/M and DOS text files
	jr z,dxf_eof
dxf_ok: pop hl
	pop de
	pop bc
	ret
dxf_eof:
	pop hl
	pop de
	pop bc
	jp SBEOF		; back to the console, "Ok"

dx_getb:			; A = the next byte of the file, CF = the end
	ld hl,(DXLEFT)
	ld a,h
	or l
	jr nz,dxg_1
	push ix
	ld ix,DXFCB
	ld de,DXFCB+86
	ld bc,256
	call OS_READ
	pop ix
	ret c			; (a read error ends the LOAD too)
	ld a,b
	or c
	scf
	ret z
	ld (DXLEFT),bc
	ld hl,DXFCB+86
	ld (DXPTR),hl
dxg_1:	ld hl,(DXLEFT)
	dec hl
	ld (DXLEFT),hl
	ld hl,(DXPTR)
	ld a,(hl)
	inc hl
	ld (DXPTR),hl
	or a
	ret

; ---- output during SAVE: into the file (EXTTX pushed AF)
DXTX:	pop af
	push bc
	push de
	push hl
	push af
	ld b,a
	ld a,(DXANY)		; LIST starts with an empty line: leave it out
	or a
	jr nz,dxt_1
	ld a,b
	cp 13
	jr z,dxt_9
	cp 10
	jr z,dxt_9
	ld a,1
	ld (DXANY),a
dxt_1:	ld a,b
	call dx_put
dxt_9:	pop af
	pop hl
	pop de
	pop bc
	ret

DXQUIET:			; during LOAD: the echo of each line is not shown
	pop af
	ret

dx_put: ld hl,(DXCNT)		; A into the file's buffer, written when it is full
	ld de,DXFCB+86
	add hl,de
	ld (hl),a
	ld hl,(DXCNT)
	inc hl
	ld (DXCNT),hl
	ld a,h
	or a
	ret z
dx_wout:			; write what the buffer holds
	ld bc,(DXCNT)
	ld a,b
	or c
	ret z
	ld hl,0
	ld (DXCNT),hl
	ld a,(DXERR)		; after a failed write: nothing more
	or a
	ret nz
	push ix
	ld ix,DXFCB
	ld de,DXFCB+86
	call OS_WRITE
	pop ix
	ret nc
	ld (DXERR),a
	ret

dx_close:			; the rest of the buffer, then close.  CF, A = error
	call dx_wout
	push ix
	ld ix,DXFCB
	call OS_CLOSE
	pop ix
	ret c
	ld a,(DXERR)
	or a
	ret z
	scf
	ret

dx_lines:			; the user's LINES setting back (SAVE turned it off)
	ld hl,(OLDLN)
	ld (LINESN),hl
	ld (LINESC),hl
	ret

; ---- PRNTOK: the SAVE is done.  A = IOMODE
DXFIN:	and 0EFh
	ld (IOMODE),a
	ld a,13 		; the last line ends the DOS way
	call dx_put
	ld a,10
	call dx_put
	call dx_close
	call c,dx_msg
	jr dx_lines

; ---- an error: a SAVE or a LOAD stops (its message would not show otherwise)
DXCLR:	push af
	push bc
	push de
	push hl
	ld a,(IOMODE)
	bit 4,a
	jr z,dxc_1
	and 0EFh
	ld (IOMODE),a
	call dx_close
	call dx_lines
dxc_1:	ld a,(IOMODE)
	and 0C3h		; STPRINT, DPRINT, SAVE, LOAD off
	ld (IOMODE),a
	pop hl
	pop de
	pop bc
	pop af
	ret

; ---- a string expression into the name buffer (DXFCB+16).  HL = text pointer, kept
dx_str: call EVAL
	push hl
	call GETLEN		; A = length, HL = the string's descriptor
	jp z,FCERR		; (empty)
	cp 65
	jp nc,FCERR		; (too long)
	inc hl
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld b,a
	ld hl,DXFCB+16
dxs_1:	ld a,(de)
	ld (hl),a
	inc de
	inc hl
	djnz dxs_1
	ld (hl),0
	pop hl
	ret

dx_file:			; the name buffer as a file name: ".BAS" if it has no dot,
	ld hl,DXFCB+16		; then the drive and directory it names.
	ld c,0			; -> HL = the name part; CF: A = error (FFh = said)
dxe_1:	ld a,(hl)
	or a
	jr z,dxe_3
	cp '.'
	jr nz,dxe_2
	ld c,1
dxe_2:	cp 5Ch			; a backslash, ':' or '/' starts a new part
	jr z,dxe_2b
	cp ':'
	jr z,dxe_2b
	cp '/'
	jr nz,dxe_2c
dxe_2b: ld c,0
dxe_2c: inc hl
	jr dxe_1
dxe_3:	dec c
	jr z,dxe_4
	ex de,hl
	ld hl,dx_mbas
	ld bc,DXEXTLEN+1
	ldir
dxe_4:	call OS_HOME		; the disk again, from the current drive and directory
	ld a,0FFh
	ret c
	ld hl,DXFCB+16
	jp OS_RESOLVE
dx_mbas: defb ".BAS",0

dx_msg: cp 0FFh 		; "?" and the message for error A (FFh: already said)
	ret z
	call OS_ERRMSG
	ld a,'?'
	rst 08h
dx_prs: ld a,(hl)
	or a
	jr z,dxp_1
	rst 08h
	inc hl
	jr dx_prs
dxp_1:	xor a
	ld (CURPOS),a
	ld a,13
	rst 08h
	ld a,10
	rst 08h
	ret

dx_fail:			; A = error: say it, and back to "Ok"
	call dx_msg
	pop hl
	jp PRNTOK

; ---- LOAD "name"
DXLOAD: call dx_str
	push hl
	call dx_file
	jr c,dx_fail
	ld ix,DXFCB
	call OS_OPEN
	jr c,dx_fail
	call CLRPTR		; as NEW
	ld hl,0
	ld (DXLEFT),hl
	xor a
	ld (DXPREV),a
	ld a,(IOMODE)
	or 20h
	ld (IOMODE),a
	pop hl
	jp PRNTOK

; ---- SAVE "name"
DXSAVE: call dx_str
	push hl
	call dx_file
	jr c,dx_fail
	ld ix,DXFCB
	call OS_CREATE		; (an old file of that name is replaced)
	jr c,dx_fail
	ld hl,0
	ld (DXCNT),hl
	xor a
	ld (DXANY),a
	ld (DXERR),a
	ld hl,(LINESN)
	ld (OLDLN),hl
	ld hl,7FFFh		; no pause every few lines
	ld (LINESN),hl
	ld (LINESC),hl
	ld a,(IOMODE)
	or 10h
	ld (IOMODE),a
	pop hl
	jp LIST

; ---- DOS "command", or DOS alone: back to ampdos
DXDOS:	jp z,OS_WARM		; nothing follows
	call dx_str
	push hl
	push ix
	ld hl,(ARREND)		; the free memory between the arrays and the
	ex de,hl		; stack, less 300 bytes for the command's own
	ld hl,-300		; stack, is lent to the command (TYPE, COPY ...)
	add hl,sp
	or a
	sbc hl,de
	jr c,dxd_mem
	ld b,h
	ld c,l
	ld hl,DXFCB+16
	call OS_EXEC
	jr nc,dxd_1
dxd_mem:
	ld hl,dx_mmem
	call dx_prs
dxd_1:	xor a			; the command ended its own lines
	ld (CURPOS),a
	pop ix
	pop hl
	ret
dx_mmem: defb "?not enough free memory for DOS",0

; ---- this part's variables
DXFEED: defw 0			; the next character DXARG typed (0 = none)
DXLEFT: defw 0			; LOAD: bytes left in the buffer
DXPTR:	defw 0			; LOAD: the next one
DXPREV: defb 0			; LOAD: the character before
DXCNT:	defw 0			; SAVE: bytes in the buffer
DXANY:	defb 0			; SAVE: 1 = something written
DXERR:	defb 0			; SAVE: the error of a failed write
DXFEEDB: defs 72

; ---- the file's buffers: DXFCB (16 bytes), DXFCB+16 a name (70), DXFCB+86 the
; data (256).  Until BASIC has started they hold the code that starts it: the
; part below, then Searle's (CSTART ... and its messages, which mkbasic.py
; moves here).  Nothing uses the buffers before the first LOAD, SAVE or DOS.
DXFCB:
; ---- the program's arguments (BASIC name): typed for the user at the first "Ok"
DXARG:	ld de,DXFEEDB		; HL = the rest of the command line
	ld a,(hl)
	or a
	jr z,dxa_none
	push hl
	ld hl,dx_mload		; LOAD "name" <Return> RUN <Return>
	call dx_cpy
	pop hl
	ld b,60
dxa_1:	ld a,(hl)
	or a
	jr z,dxa_2
	cp ' '
	jr z,dxa_2
	ld (de),a
	inc hl
	inc de
	djnz dxa_1
dxa_2:	ld hl,dx_mrun
	call dx_cpy
	xor a
	ld (de),a
	ld hl,DXFEEDB
	ld (DXFEED),hl
	ret
dxa_none:
	ld hl,0
	ld (DXFEED),hl
	ret
dx_cpy: ld a,(hl)		; zero-terminated HL to DE (without the zero)
	or a
	ret z
	ld (de),a
	inc hl
	inc de
	jr dx_cpy
dx_mload: defb "LOAD ",34,0
dx_mrun:  defb 34,13,"RUN",13,0

; ---- the memory top (start-up): OS_MEMTOP says (B000h if the OS is too old to have it)
DXTOP:	call OS_VERSION
	ld de,0005h
	or a
	sbc hl,de
	ld hl,0B000h
	ret c
	jp OS_MEMTOP
