; ==========================================================================
; CONDRV.ASM - the AMPRO's console: DART channel A (SIOA.ASM).  It provides
; mc_init, mc_out, mc_in, mc_stat (docs/PORTING.md).  build.py points
; GEN/MACHCON.ASM here; KERNEL/LIB/CONSOLE.ASM includes that.
; ==========================================================================

	include "KERNEL/MACHINE/AMPRO/SIOA.ASM"
