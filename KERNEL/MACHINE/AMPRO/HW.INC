; ==========================================================================
; HW.INC - AMPRO Little Board hardware: I/O ports and ROM services
; ==========================================================================

; ---- board control register (write only)
BCR:	 equ 00h	; bit0 drive 1, bit4 side, bit5 /DDEN (0 = MFM),
			; bit6 ROM off (all RAM), bit7 FDC clock (untested)

; ---- WD1772 floppy controller (writes at C0..C3, reads at C4..C7)
FCMD:	 equ 0C0h	; write: command
FTRK:	 equ 0C1h	; write: track register
FSEC:	 equ 0C2h	; write: sector register
FDAT:	 equ 0C3h	; write: data register
FSTA:	 equ 0C4h	; read:  status
FRTRK:	 equ 0C5h	; read:  track register
FRSEC:	 equ 0C6h	; read:  sector register
FRDAT:	 equ 0C7h	; read:  data register

; ---- Z80 DART serial ports: A = console, B = the PC link
DARTAD:  equ 80h
DARTAC:  equ 84h
DARTBD:  equ 88h
DARTBC:  equ 8Ch

; ---- Z80 CTC
CTC0:	 equ 40h	; CTC channel 0: baud rate for the console (DART A)
CTC1:	 equ 50h	; baud rate generator for DART B
IDPORT:  equ 29h	; the board's ID jumpers (8 bits, input only)
CTC2:	 equ 60h	; free-running timer

; ---- restart vectors (the OS's own, KERNEL/OS/AMPDOS.ASM, as the old AMPRO
;      monitor ROM had them: BASIC and older programs use them)
;   rst 08h  print the character in A on the console
;   rst 10h  wait for a key, returns it in A
;   rst 18h  test for a key: NZ = a key is waiting (read it with rst 10h)
