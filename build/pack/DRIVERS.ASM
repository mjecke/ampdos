; ==========================================================================
; DRIVERS.ASM - the rest of the AMPRO's machine layer: Serial B (SIOB.ASM),
; the floppy drives (FD.ASM, the md_ routines) and the mach_ routines
; (docs/PORTING.md).  build.py points GEN/MACHDRV.ASM here; BODY.ASM includes
; that.
; ==========================================================================

	include "KERNEL/MACHINE/AMPRO/SIOB.ASM"
	include "KERNEL/MACHINE/AMPRO/FD.ASM"
	include "KERNEL/MACHINE/AMPRO/MACH.ASM"
