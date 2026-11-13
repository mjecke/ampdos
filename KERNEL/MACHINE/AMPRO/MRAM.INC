; ==========================================================================
; MRAM.INC - the AMPRO machine layer's variables, in VARS+01h .. VARS+2Fh
; (KERNEL/INC/RAM.INC includes this through GEN/MACHRAM.INC).
; ==========================================================================
; floppy driver (MACHINE/AMPRO/FD.ASM)
fd_bcrbase: equ VARS+10h   ; BCR value for side 0 (41h: drive A, the ROM off)
fd_bcr:     equ VARS+11h   ; BCR value last written
fd_ebit:    equ VARS+12h   ; 04h = use the 15 ms head-settle delay on r/w commands
fd_step:    equ VARS+13h   ; step rate bits (r1 r0): 0 = 6 ms, 1 = 12, 2 = 2, 3 = 3
fd_try:     equ VARS+14h   ; retry counter
fd_cache:   equ VARS+15h   ; track number + 1 held in TRKBUF (0 = nothing)
fd_tcyl:    equ VARS+16h   ; cylinder of the current request
fd_tside:   equ VARS+17h   ; side of the current request
fd_tsec:    equ VARS+18h   ; sector (1..9) of the current request
fd_ttrk:    equ VARS+19h   ; track index = cyl*2+side
fd_tdest:   equ VARS+1Ah   ; word: buffer pointer of the current request
fd_wstride: equ VARS+1Ch   ; sector step when writing a track: 1 = in order, 2 = every other sector...
fd_sidewait: equ VARS+1Dh  ; side-select delay in units of ~0.85 ms (36 = 30 ms)
fd_cnt:     equ VARS+1Eh   ; sectors left in the current track transfer
fd_nfail:   equ VARS+2Ah   ; count of track-write failures (tests)
fd_lstat:   equ VARS+28h   ; status register at the last track-write failure
fd_lcnt:    equ VARS+29h   ; sectors still to write at that failure
fd_dirty:   equ VARS+2Bh   ; 1 = TRKBUF was written to and is not on the disk yet
fd_vtry:    equ VARS+2Ch   ; fd_flush retry counter
fd_fcyl:    equ VARS+2Dh   ; fd_flush: cylinder of the cached track
fd_fside:   equ VARS+2Eh   ; fd_flush: side of the cached track
fd_vfy:     equ VARS+2Fh   ; 1 = fd_rd_track reads every sector into VFYBUF (verify by CRC)
fd_drive:   equ VARS+01h   ; selected drive: 0 = A, 1 = B
fd_dtrk:    equ VARS+02h   ; 2 bytes: head position (track register) of drive A, B
fd_dknown:  equ VARS+04h   ; 2 bytes: 1 = that drive has been restored
fd_ftmp:    equ VARS+06h   ; fd_fmt_track: side
fd_idbuf:   equ VARS+20h   ; 6 bytes: last ID read by fd_readid (cyl, side, sec, size, crc, crc)
md_drive:   equ fd_drive   ; (the machine layer's name: the selected drive)
