; ==========================================================================
; MONBODY.ASM - the machine code monitor (MON.BIN).  Type MON at the prompt.
;
;   D [start [end]]          dump memory in hex and ASCII (alone: go on)
;   E addr [bytes]           put bytes in; with no bytes it asks for them line
;                            by line (Return keeps one, "." ends)
;   F start end byte         fill
;   M start end dest         move (overlap is fine)
;   C start end other        compare two blocks, show the differences
;   S start end bytes        search; bytes are hex, or "text" in quotes
;   U [start [end]]          disassemble (alone: go on; 16 instructions)
;   G addr [args]            call addr (HL = args); a RET comes back here
;   L name [addr]            load a file (at 8000 if no address)
;   W name start end         write memory to a file
;   I port    O port value   read / write an I/O port
;   H a b                    a+b and a-b
;   Q                        back to the OS         ?  help
; All numbers are hex.  Esc stops a listing, any other key pauses it.
;
; The monitor lives at BC00h and up (PROGRAMS/MON.INC), so 8000h-BBFFh is
; yours.  There are no breakpoints or register display: G is a plain CALL.
; MON.ASM (the file MON.BIN) copies this code to BC00h and jumps to it.
; ==========================================================================
	include "PROGRAMS/MON.INC"
	org MONBASE

	include "KERNEL/INC/OS.INC"

; ---- variables (MV...)
v_line:   equ MV	     ; 80 bytes: the line typed
v_daddr:  equ MV+50h	     ; D: where the next dump starts
v_uaddr:  equ MV+52h	     ; U: where the next listing starts
v_rs:	  equ MV+54h	     ; start of a range
v_re:	  equ MV+56h	     ; end of a range
v_ap:	  equ MV+58h	     ; where the text after a range goes on
v_rem:	  equ MV+5Ah	     ; bytes left to dump (0 = 65536)
v_sp:	  equ MV+5Ch	     ; the OS's stack, for Q
v_np:	  equ MV+5Eh	     ; L, W: where the file name is
v_la:	  equ MV+60h	     ; L: load address
v_lcap:   equ MV+62h	     ; L: room there
v_wn:	  equ MV+64h	     ; W: bytes to write
v_w1:	  equ MV+66h	     ; a number kept for a moment
v_pp:	  equ MV+68h	     ; S: where the next pattern byte goes
v_plen:   equ MV+6Ah	     ; S: pattern length
v_cnt:	  equ MV+6Bh	     ; C, S: how many found
v_umode:  equ MV+6Ch	     ; U: 0 = 16 instructions, 1 = up to an end address
v_ucnt:   equ MV+6Dh	     ; U: instructions left
v_uend:   equ MV+6Eh	     ; U: the end address
v_fcb:	  equ MV+0A0h	     ; 16 bytes: a file control block
v_pat:	  equ MV+0B0h	     ; 16 bytes: S's pattern
; the disassembler's (MONDIS.ASM)
v_dstart: equ MV+70h
v_dpc:	  equ MV+72h
v_dpt:	  equ MV+74h
v_didx:   equ MV+76h
v_dmem:   equ MV+77h
v_dop:	  equ MV+78h
v_dx:	  equ MV+79h
v_dy:	  equ MV+7Ah
v_dz:	  equ MV+7Bh
v_dp:	  equ MV+7Ch
v_dq:	  equ MV+7Dh
v_ddv:	  equ MV+7Eh
v_dlen:   equ MV+7Fh
v_dbuf:   equ MV+0C0h	     ; 32 bytes: the text of one instruction
v_dbias:  equ MV+0E0h	     ; word: 0 (the disassembler reads memory as it is)

start:	pop hl			; (the stub pushed the arguments: not used)
	ld (v_sp),sp		; where to return to: the OS
	ld sp,MSTACK
	ld hl,0
	ld (v_dbias),hl
	ld hl,TPA
	ld (v_daddr),hl
	ld (v_uaddr),hl
	ld hl,m_hello
	call OS_PUTS

main:	ld sp,MSTACK
	ld hl,m_prompt
	call OS_PUTS
	ld hl,v_line
	ld b,78
	call OS_GETLINE
	ld hl,v_line
	call skipsp
	ld a,(hl)
	or a
	jr z,main
	inc hl
	cp '?'
	jr nz,mn_1
	ld a,'H'
	jr mn_2
mn_1:	and 0DFh		; upper case
mn_2:	ld c,a
	call skipsp		; HL = the arguments
	ld de,ctab
mn_3:	ld a,(de)
	or a
	jr z,bad2		; not a command
	inc de
	cp c
	jr z,mn_4
	inc de
	inc de
	jr mn_3
mn_4:	push hl 		; the handler's address -> DE
	ex de,hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	pop hl
	ld bc,main		; a handler's RET comes back to main
	push bc
	push de
	ret
bad2:	ld hl,m_what
	call OS_PUTS
	jr main

ctab:	defb 'D'
	defw cmd_d
	defb 'E'
	defw cmd_e
	defb 'F'
	defw cmd_f
	defb 'M'
	defw cmd_m
	defb 'C'
	defw cmd_c
	defb 'S'
	defw cmd_s
	defb 'U'
	defw cmd_u
	defb 'G'
	defw cmd_g
	defb 'L'
	defw cmd_l
	defb 'W'
	defw cmd_w
	defb 'I'
	defw cmd_i
	defb 'O'
	defw cmd_o
	defb 'H'
	defw cmd_h
	defb 'Q'
	defw cmd_q
	defb 0

bad:	ld hl,m_bad		; (jumped to: the RET inside OS_PUTS goes to main)
	jp OS_PUTS

cmd_q:	ld sp,(v_sp)		; back to the OS
	ret

; ---------------------------------------------------------------- numbers
skipsp: ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr skipsp

skipword:			; HL past a word
	ld a,(hl)
	or a
	ret z
	cp ' '
	ret z
	inc hl
	jr skipword

hexdig: 			; A = a character -> its value; CF = not a hex digit
	cp '0'
	ret c
	cp '9'+1
	jr nc,hd_1
	sub '0'
	or a
	ret
hd_1:	and 0DFh
	cp 'A'
	ret c
	cp 'G'
	ccf
	ret c
	sub 'A'-10
	or a
	ret

hexnum: 			; HL = text: spaces, then 1 to 4 hex digits, then a space
	call skipsp		; or the end -> DE.  HL after the number.  CF = not that
	ld de,0
	ld b,0
hn_1:	ld a,(hl)
	call hexdig
	jr c,hn_2
	push hl
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	or l
	ld l,a
	ex de,hl
	pop hl
	inc hl
	inc b
	ld a,b
	cp 5
	jr c,hn_1
	scf			; five digits: too many
	ret
hn_2:	ld a,b
	or a
	jr z,hn_bad		; no digit at all
	ld a,(hl)
	or a
	ret z
	cp ' '
	ret z
hn_bad: scf
	ret

bytearg:			; like hexnum, but 0..FF (E = the value)
	call hexnum
	ret c
	ld a,d
	or a
	ret z
	scf
	ret

getrange:			; HL = "start end ..." -> v_rs, v_re, BC = how many bytes
	call hexnum		; (0 = 65536), v_ap = the text that follows.  CF = bad
	ret c
	ld (v_rs),de
	call hexnum
	ret c
	ld (v_re),de
	ld (v_ap),hl
	ld hl,(v_rs)
	ex de,hl		; HL = end, DE = start
	or a
	sbc hl,de
	ret c			; the end is before the start
	inc hl
	ld b,h
	ld c,l
	or a
	ret

rangebc:			; BC = the size of the range v_rs..v_re (0 = 65536).
	push de 		; Keeps everything else (parsing a number uses B)
	ld hl,(v_re)
	ld de,(v_rs)
	or a
	sbc hl,de
	inc hl
	ld b,h
	ld c,l
	pop de
	ret

chkkey: 			; a key pressed? Esc: CF.  Another key pauses until one more
	call OS_KBHIT
	jr nz,ck_1
	or a
	ret
ck_1:	call OS_GETC
	cp 1Bh
	jr z,ck_esc
	call OS_GETC
	cp 1Bh
	jr z,ck_esc
	or a
	ret
ck_esc: scf
	ret

space:	ld a,' '
	jp OS_PUTC

; ---------------------------------------------------------------- D
cmd_d:	ld a,(hl)
	or a
	jr nz,d_arg
	ld de,(v_daddr) 	; nothing given: go on from where the last one ended
	jr d_one
d_arg:	call hexnum
	jp c,bad
	call skipsp
	ld a,(hl)
	or a
	jr nz,d_range
d_one:	ld (v_rs),de		; a start only: 128 bytes
	ld bc,128
	jr d_go
d_range:
	ld (v_rs),de
	call hexnum
	jp c,bad
	ld hl,(v_rs)
	ex de,hl
	or a
	sbc hl,de
	jp c,bad
	inc hl
	ld b,h
	ld c,l
d_go:	ld (v_rem),bc
	ld hl,(v_rs)
d_line: ld bc,(v_rem)		; E = bytes on this line: 16, or what is left
	ld a,b
	or a
	jr nz,d_16
	ld a,c
	or a
	jr z,d_16
	cp 16
	jr c,d_n
d_16:	ld a,16
d_n:	ld e,a
	push hl
	call OS_HEX16
	ld a,':'
	call OS_PUTC
	ld b,16
	ld d,e
d_h:	call space
	ld a,d
	or a
	jr z,d_pad
	ld a,(hl)
	call OS_HEX8
	inc hl
	dec d
	jr d_hn
d_pad:	call space
	call space
d_hn:	djnz d_h
	call space
	call space
	pop hl			; the same bytes again, as characters
	ld b,e
d_a:	ld a,(hl)
	inc hl
	cp ' '
	jr c,d_dot
	cp 7Fh
	jr c,d_ok
d_dot:	ld a,'.'
d_ok:	call OS_PUTC
	djnz d_a
	call OS_CRLF
	ld (v_daddr),hl
	ld hl,(v_rem)
	ld d,0
	or a
	sbc hl,de
	ld (v_rem),hl
	ld a,h
	or l
	ret z
	call chkkey
	ret c
	ld hl,(v_daddr)
	jr d_line

; ---------------------------------------------------------------- E
cmd_e:	call hexnum
	jp c,bad
	push de
	pop ix			; IX = the address
	call skipsp
	ld a,(hl)
	or a
	jr z,e_ask
e_list: call skipsp
	ld a,(hl)
	or a
	ret z
	call bytearg
	jp c,bad
	ld (ix+0),e
	inc ix
	jr e_list
e_ask:	push ix 		; "8000 3E : "
	pop hl
	call OS_HEX16
	call space
	ld a,(ix+0)
	call OS_HEX8
	ld a,':'
	call OS_PUTC
	call space
	ld hl,v_line
	ld b,40
	call OS_GETLINE
	ld hl,v_line
	call skipsp
	ld a,(hl)
	or a
	jr z,e_next		; Return: leave it, go on
	cp '.'
	ret z			; "." ends
e_new:	call skipsp
	ld a,(hl)
	or a
	jr z,e_ask
	call bytearg
	jr c,e_bad
	ld (ix+0),e
	inc ix
	jr e_new
e_next: inc ix
	jr e_ask
e_bad:	ld hl,m_bad
	call OS_PUTS
	jr e_ask

; ---------------------------------------------------------------- F  M  C
cmd_f:	call getrange
	jp c,bad
	ld hl,(v_ap)
	call bytearg
	jp c,bad
	call rangebc
	ld hl,(v_rs)
	ld (hl),e
	dec bc
	ld a,b
	or c
	ret z
	ld d,h
	ld e,l
	inc de
	ldir
	ret

cmd_m:	call getrange
	jp c,bad
	ld hl,(v_ap)
	call hexnum
	jp c,bad		; DE = the destination
	call rangebc
	ld hl,(v_rs)
	or a
	sbc hl,de
	jr c,m_back		; start < dest: copy from the end
	ld hl,(v_rs)
	ldir
	ret
m_back: ex de,hl		; HL = dest
	add hl,bc
	dec hl			; its last byte
	ex de,hl
	ld hl,(v_re)
	lddr
	ret

cmd_c:	call getrange
	jp c,bad
	ld hl,(v_ap)
	call hexnum
	jp c,bad
	call rangebc
	xor a
	ld (v_cnt),a
	ld hl,(v_rs)		; HL = first block, DE = the other one
c_lp:	ld a,(de)
	cp (hl)
	jr z,c_same
	ld a,1
	ld (v_cnt),a
	push bc
	push de
	push hl
	call OS_HEX16		; "8000 3E  9000 3F"
	call space
	ld a,(hl)
	call OS_HEX8
	call space
	call space
	ex de,hl
	call OS_HEX16
	call space
	ld a,(hl)
	call OS_HEX8
	call OS_CRLF
	pop hl
	pop de
	pop bc
	call chkkey
	ret c
c_same: inc hl
	inc de
	dec bc
	ld a,b
	or c
	jr nz,c_lp
	ld a,(v_cnt)
	or a
	ret nz
	ld hl,m_same
	jp OS_PUTS

; ---------------------------------------------------------------- S
cmd_s:	call getrange
	jp c,bad
	ld hl,(v_ap)		; the pattern: hex bytes and "text"
	push hl
	ld hl,v_pat
	ld (v_pp),hl
	xor a
	ld (v_plen),a
	pop hl
s_pl:	call skipsp
	ld a,(hl)
	or a
	jr z,s_pend
	cp '"'
	jr nz,s_hex
	inc hl
s_q:	ld a,(hl)
	or a
	jr z,s_pend
	inc hl
	cp '"'
	jr z,s_pl
	call s_put
	jp c,bad
	jr s_q
s_hex:	call bytearg
	jp c,bad
	ld a,e
	call s_put
	jp c,bad
	jr s_pl
s_pend: ld a,(v_plen)
	or a
	jp z,bad
	xor a
	ld (v_cnt),a
	call rangebc
	ld a,b			; 65536 bytes: one short (the count is 16 bits)
	or c
	jr nz,s_ok
	ld bc,0FFFFh
s_ok:	ld hl,(v_rs)
s_lp:	ld a,b			; stop when fewer bytes are left than the pattern
	or a
	jr nz,s_try
	ld a,(v_plen)
	cp c
	jr z,s_try
	jr nc,s_none
s_try:	push hl
	push bc
	ld de,v_pat
	ld a,(v_plen)
	ld b,a
s_cmp:	ld a,(de)
	cp (hl)
	jr nz,s_no
	inc hl
	inc de
	djnz s_cmp
	pop bc
	pop hl
	ld a,1
	ld (v_cnt),a
	call OS_HEX16
	call OS_CRLF
	call chkkey
	ret c
	jr s_nx
s_no:	pop bc
	pop hl
s_nx:	inc hl
	dec bc
	jr s_lp
s_none: ld a,(v_cnt)
	or a
	ret nz
	ld hl,m_nofound
	jp OS_PUTS

s_put:				; A = a pattern byte.  CF = pattern too long
	push hl
	ld hl,(v_pp)
	ld (hl),a
	inc hl
	ld (v_pp),hl
	ld hl,v_plen
	inc (hl)
	ld a,(hl)
	cp 17
	ccf
	pop hl
	ret

; ---------------------------------------------------------------- G
cmd_g:	call hexnum
	jp c,bad
	call skipsp		; HL = the arguments for the program
	ld bc,g_back
	push bc
	push de
	ret			; = call (DE)
g_back: jp main

; ---------------------------------------------------------------- I O H
cmd_i:	call bytearg
	jp c,bad
	ld c,e
	ld b,0
	in a,(c)
	call OS_HEX8
	jp OS_CRLF

cmd_o:	call bytearg
	jp c,bad
	ld a,e
	ld (v_w1),a
	call bytearg
	jp c,bad
	ld a,(v_w1)
	ld c,a
	ld b,0
	ld a,e
	out (c),a
	ret

cmd_h:	ld a,(hl)		; "H" alone is also what "?" gets: the help
	or a
	jr z,h_help
	call hexnum
	jp c,bad
	ld (v_w1),de
	call hexnum
	jp c,bad
	ld hl,(v_w1)
	add hl,de
	call OS_HEX16		; sum
	call space
	call space
	ld hl,(v_w1)
	or a
	sbc hl,de
	call OS_HEX16		; difference
	jp OS_CRLF
h_help: ld hl,m_help
	jp OS_PUTS

; ---------------------------------------------------------------- L W
fserr:	call OS_ERRMSG		; A = code -> the text
	call OS_PUTS
	jp OS_CRLF

cmd_l:	ld a,(hl)
	or a
	jp z,bad
	ld (v_np),hl
	call skipword
	call skipsp
	ld de,TPA
	ld a,(hl)
	or a
	jr z,l_go
	call hexnum
	jp c,bad
l_go:	ld (v_la),de
	ld hl,MONBASE		; room: up to the monitor
	or a
	sbc hl,de
	jp c,l_nospace
	ld a,h
	or l
	jp z,l_nospace
	ld (v_lcap),hl
	ld hl,(v_np)
	call OS_RESOLVE
	jr c,fserr
	ld ix,v_fcb
	call OS_OPEN
	jr c,fserr
	ld ix,v_fcb
	ld de,(v_la)
	ld bc,(v_lcap)
	call OS_READ
	jr c,fserr
	ld (v_w1),bc
	ld a,b
	or c
	ld hl,m_empty
	jp z,OS_PUTS
	ld h,b
	ld l,c
	call OS_DEC16
	ld hl,m_loaded
	call OS_PUTS
	ld hl,(v_la)
	call OS_HEX16
	ld a,'-'
	call OS_PUTC
	ld hl,(v_la)
	ld de,(v_w1)
	add hl,de
	dec hl
	call OS_HEX16
	call OS_CRLF
	ld hl,(v_fcb+4) 	; the file's size (4 bytes at FCB+2): more than fitted?
	ld a,h
	or l
	jr nz,l_cut
	ld hl,(v_lcap)
	ld de,(v_fcb+2)
	or a
	sbc hl,de
	ret nc			; room >= size: all of it
l_cut:	ld hl,m_cut
	jp OS_PUTS
l_nospace:
	ld hl,m_nospace
	jp OS_PUTS

cmd_w:	ld a,(hl)
	or a
	jp z,bad
	ld (v_np),hl
	call skipword
	call skipsp
	call getrange
	jp c,bad
	ld a,b			; 65536 bytes will not do
	or c
	jp z,bad
	ld (v_wn),bc
	ld hl,(v_np)
	call OS_RESOLVE
	jp c,fserr
	ld ix,v_fcb
	call OS_CREATE
	jp c,fserr
	ld ix,v_fcb
	ld de,(v_rs)
	ld bc,(v_wn)
	call OS_WRITE
	jr c,w_fail
	ld ix,v_fcb
	call OS_CLOSE
	jp c,fserr
	ld hl,(v_wn)
	call OS_DEC16
	ld hl,m_written
	jp OS_PUTS
w_fail: call fserr
	ld hl,m_chk
	jp OS_PUTS

; ---------------------------------------------------------------- the texts
m_hello:  defm "ampDOS monitor.  ? lists the commands, Q quits.  Numbers are hex."
	  defb 13,10,0
m_prompt: defm "* "
	  defb 0
m_what:   defm "? (type ? for the commands)"
	  defb 13,10,0
m_bad:	  defm "bad argument (? lists the commands)"
	  defb 13,10,0
m_same:   defm "no differences"
	  defb 13,10,0
m_nofound: defm "not found"
	  defb 13,10,0
m_empty:  defm "the file is empty"
	  defb 13,10,0
m_loaded: defm " bytes loaded at "
	  defb 0
m_cut:	  defm "(the file is longer: loading stopped at the monitor)"
	  defb 13,10,0
m_nospace: defm "no room there (the monitor starts at BC00)"
	  defb 13,10,0
m_written: defm " bytes written"
	  defb 13,10,0
m_chk:	  defm "(the file may be incomplete: CHKDSK /F will tidy up)"
	  defb 13,10,0
m_help:
	defm "D [start [end]]  dump          E addr [bytes]  edit (no bytes: asks; . ends)"
	defb 13,10
	defm "F start end byte fill          M start end dest  move"
	defb 13,10
	defm "C start end other compare      S start end bytes|",34,"text",34,"  search"
	defb 13,10
	defm "U [start [end]]  disassemble   G addr [args]  call (RET comes back)"
	defb 13,10
	defm "L name [addr]  load a file (8000 if no addr)   W name start end  write a file"
	defb 13,10
	defm "I port   O port value   H a b (a+b, a-b)   Q quit   ? this list"
	defb 13,10
	defm "All numbers are hex.  Esc stops a listing, another key pauses it."
	defb 13,10,0

	include "PROGRAMS/MONDIS.ASM"
