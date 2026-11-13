; ==========================================================================
; MACHINE.INC - the AMPRO Little Board: what the rest of ampDOS needs to know
; about the machine (docs/PORTING.md).  build.py points GEN/MACHINE.INC here.
;
; Machine: AMPRO Little Board/Z80 (a 4 MHz Z80, 64 KB RAM, WD1772 floppies, Z80 DART serial)
; ==========================================================================

	include "KERNEL/MACHINE/AMPRO/HW.INC"	; its ports

M_CLOCK: equ 4000		; the CPU clock, kHz
M_DRIVES: equ 2 		; drives A: and B:
M_SERIAL2: equ 1		; a second serial port (Serial B): SERSEND, SERRECV,
				; TERM, MIRROR
M_ROWS:  equ 24 		; the screen at the start (SETUP keeps the real one)
M_COLS:  equ 80
