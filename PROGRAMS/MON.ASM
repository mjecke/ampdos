; ==========================================================================
; MON.ASM - MON.BIN: the machine code monitor (the part that gets loaded).
; Programs load at 8000h, but a monitor that sat there would be in the way of
; whatever you want to look at.  So this stub only moves the monitor itself
; (MONBODY.ASM, built first as bin/monbody.bin) up to MONBASE and starts it.
; ==========================================================================
	org 8000h
	include "PROGRAMS/MON.INC"

	push hl 		; (the arguments: the monitor takes them off again)
	ld hl,image
	ld de,MONBASE
	ld bc,image_end-image
	ldir
	jp MONBASE

image:	incbin "BIN/MONBODY.BIN"
image_end:
