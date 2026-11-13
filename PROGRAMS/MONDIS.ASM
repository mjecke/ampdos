; ==========================================================================
; MONDIS.ASM - the monitor's U command, and (in DISCORE.ASM) the Z80
; disassembler it uses, also used by DISASM.
; Included at the end of MONBODY.ASM.
;
;   U [start [end]]    16 instructions from start (alone: from where the last
;                      listing ended), or everything up to end
;
;   8000  3E 41        LD A,41h
;   8002  DD 7E 05     LD A,(IX+05h)
;
; dis1 turns the instruction at HL into text (v_dbuf) and its length (v_dlen),
; and returns HL = the next instruction.  The instruction is decoded by its
; bit fields, as the Z80 itself does:
;       op = x y z      x = bits 7-6, y = bits 5-3, z = bits 2-0
;       y = p q         p = bits 5-4, q = bit 3
; so x, y, z (and p, q) pick words from the small tables below, rather than
; a table of 256 opcodes.  After a DD or FD prefix (v_didx = 1 or 2) HL
; becomes IX or IY, (HL) becomes (IX+d), and H, L become IXH, IXL (unless the
; same instruction has a (IX+d) operand).  CB and ED have their own groups.
; Numbers are hex with an h, with a 0 in front where a letter would start.
; A byte that is no instruction (ED xx that the Z80 does not know, DD DD ...)
; is shown as DB.
; ==========================================================================

cmd_u:	ld a,(hl)
	or a
	jr nz,u_arg
	ld de,(v_uaddr) 	; nothing given: go on
	jr u_cnt
u_arg:	call hexnum
	jp c,bad
	call skipsp
	ld a,(hl)
	or a
	jr nz,u_end
u_cnt:	ld (v_uaddr),de
	xor a
	ld (v_umode),a
	ld a,16
	ld (v_ucnt),a
	jr u_loop
u_end:	ld (v_uaddr),de
	call hexnum
	jp c,bad
	ld (v_uend),de
	ld a,1
	ld (v_umode),a
u_loop: ld a,(v_umode)
	or a
	jr z,u_one
	ld hl,(v_uend)		; up to the end address
	ld de,(v_uaddr)
	or a
	sbc hl,de
	ret c
u_one:	ld hl,(v_uaddr)
	call dis1
	call u_print
	ld hl,(v_dpc)
	ld (v_uaddr),hl
	ld de,(v_dstart)
	or a
	sbc hl,de
	ret c			; ran past FFFF
	ld a,(v_umode)
	or a
	jr nz,u_key
	ld hl,v_ucnt
	dec (hl)
	ret z
u_key:	call chkkey
	ret c
	jr u_loop

u_print:			; "8000  3E 41        LD A,41h"
	ld hl,(v_dstart)
	call OS_HEX16
	call space
	call space
	ld hl,(v_dstart)
	ld a,(v_dlen)
	ld c,a
	ld b,4
up_b:	ld a,c
	or a
	jr z,up_pad
	ld a,(hl)
	call OS_HEX8
	inc hl
	dec c
	call space
	jr up_n
up_pad: call space
	call space
	call space
up_n:	djnz up_b
	call space
	ld hl,v_dbuf
	call OS_PUTS
	jp OS_CRLF

dtarget: jp dnum16		; an address in an operand: plain hex in MON

	include "PROGRAMS/DISCORE.ASM"
