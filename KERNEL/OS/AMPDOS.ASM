; ==========================================================================
; AMPDOS.ASM - ampDOS: the whole OS, at 0000h.  The boot sector of an ampDOS
; disk (KERNEL/MACHINE/AMPRO/BOOTSEC.ASM) loads it from AMPDOS.SYS into the RAM under
; the AMPRO's ROM, switches the ROM off and starts it here.  Its buffers are
; above the code (KERNEL/INC/BUFS.INC); programs get 8000h-FBFFh (31 KB).
; Here: the restart vectors, then the OS itself (BODY.ASM).
; ==========================================================================
	org 0000h

TPA_TOP: equ 0FC00h		; programs: 8000h up to here (the variables follow)
OSTOP:	 equ 05F00h		; the code must end below the buffers (SHBUF)

	include "GEN/MACHINE.INC"	; the machine: its ports, its constants
	include "KERNEL/INC/BUFS.INC"
	include "KERNEL/INC/RAM.INC"
	include "KERNEL/FS/FS.INC"

os_start:			; 0000h: reset (and RESTART)
	di
	jp rd_boot
	defs 08h-$
	jp mc_out		; RST 08h: print A  (the console calls BASIC and old
	defs 10h-$		;  programs expect, as in the AMPRO monitor ROM)
	jp mc_in		; RST 10h: wait for a key -> A
	defs 18h-$
	jp mc_stat		; RST 18h: NZ = a key is waiting
	defs 38h-$
	ret			; RST 38h / interrupt mode 1: nothing
	defs 66h-$
	retn			; NMI: nothing

rd_boot:
	ld sp,OSSTACK
	call mc_init		; the console, set up as the monitor would
	jp sh_cold

	include "KERNEL/OS/BODY.ASM"
os_end:
