; ==========================================================================
; HELLO.ASM - the smallest program for the ampdos shell.  Put HELLO.BIN on a
; disk, type HELLO (or HELLO some words) at the A> prompt.
; It shows how a program gets its arguments and talks to the OS.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"

	push hl 		; HL = the rest of the command line
	ld hl,m_hi
	call OS_PUTS
	pop hl
	ld a,(hl)
	or a
	jr z,none
	push hl
	ld hl,m_args
	call OS_PUTS
	pop hl
	call OS_PUTS
	ld a,'"'
	call OS_PUTC
	call OS_CRLF
	ret
none:	ld hl,m_none
	call OS_PUTS
	ret			; back to the shell

m_hi:	defm "Hello from a program loaded off the disk!"
	defb 13,10,0
m_args: defm "You gave me: \""
	defb 0
m_none: defm "(no arguments)"
	defb 13,10,0
