; ==========================================================================
; MON.INC - where MON.BIN keeps itself (shared by MON.ASM and MONBODY.ASM)
;   8000-BBFF  free for what you examine, load, patch and run
;   BC00-D5FF  the monitor (MONBODY.ASM), copied here by the stub in MON.BIN
;   D600-D7FF  its variables and line buffer
;   D800-DAFF  its stack
; All of it is in the program area (it ends at FC00h).
; ==========================================================================
MONBASE: equ 0BC00h
MV:	 equ 0D600h
MSTACK:  equ 0DB00h
