; ==========================================================================
; FD.ASM - WD1772 floppy driver for the AMPRO Little Board, drives A and B
;
; Geometry: DOS 360K -- 40 cylinders, 2 sides, 9 sectors/track (numbered
; 1..9), 512 bytes.  LBA = (cyl*2 + side)*9 + (sector-1).
; Two drives share the controller; fd_select switches between them and keeps
; each drive's head position (the controller has only one track register).
;
; Lessons built into this code (see docs/HARDWARE.md):
;  * every wait for BUSY lasts ~3.4 s -- a command after the motor has stopped
;    first waits ~1.2 s for spin-up;
;  * the head position is unknown until a restore: call fd_init first;
;  * sector commands use E=0 (no 15 ms settle delay) so that sectors 1..9 can
;    be transferred back to back on a 1:1 formatted track, one revolution
;    per track instead of one revolution per sector.
;
; Conventions: carry set = error.  Treat AF, BC, DE and HL as clobbered by
; every routine unless its description says otherwise (fd_rd_sector and
; fd_wr_sector preserve BC and DE).  Variables live in KERNEL/INC/RAM.INC.
;
;   fd_init                          set defaults, restore (CF = failed)
;   fd_restore                       step to track 0 (CF = failed)
;   fd_off                           let go of the drive (no disk: its motor stops)
;   fd_seek        A=cylinder        seek with verify (CF = failed)
;   fd_setside     A=0/1             select the head
;   fd_rd_sector   A=sec  HL=dest    read one sector; HL += 512
;   fd_wr_sector   A=sec  HL=src     write one sector; HL += 512
;   fd_readid                        read the next sector ID passing under the head (CF = none);
;                                    A = its sector number, details in fd_idbuf
;   fd_rd_track    A=cyl  C=side  HL=dest(4608)   read a whole track (starts at the next sector
;                                    to pass, so there is no wait for sector 1)
;   fd_wr_track    A=cyl  C=side  HL=src (4608)   write a whole track, sectors visited in steps of
;                                    fd_wstride (2 = every other sector)
;   fd_read_lba    HL=LBA DE=dest    read a sector through the track cache
;   fd_write_lba   HL=LBA DE=src     write a sector into the track cache (marks it dirty)
;   fd_flush                         write the cached track if dirty, read back, compare
;   fd_drop                          forget the cached track (after a disk change)
;   fd_select      A=drive (0/1)     switch drives (flushes the cache first)
;   fd_vfy_track   A=cyl  C=side     read a track, checking only the CRCs
;   fd_mk_image    HL=buffer         build a Write Track image (6400 bytes)
;   fd_fmt_track   A=cyl C=side HL=image   format one track
;   fd_index                         CF = no index pulses (no disk turning)
;   fd_present                       CF = no disk turning (quick: under ~1 s)
; fd_rd_track and fd_wr_track are raw: they do not look at the track cache.
; ==========================================================================

; ---- defaults (override by writing the variables after fd_init)
FD_DEF_BCR:  equ 41h	; drive A, MFM, the ROM off (the OS runs in the RAM under it)
FD_DEF_STEP: equ 0	; step rate bits: 6 ms (safe)

; ---------------------------------------------------------------- basics
fd_fw:				; ~65 us so the controller can raise BUSY
	push bc
	ld b,20
fd_fw1: djnz fd_fw1
	pop bc
	ret

fd_settle:			; side-select delay: fd_sidewait * ~0.85 ms (default 2 = ~2 ms; measured: 0 works too)
	push bc
	ld a,(fd_sidewait)
	or a
	jr z,fd_settle3
	ld c,a
fd_settle1:
	ld b,0
fd_settle2:
	djnz fd_settle2
	dec c
	jr nz,fd_settle1
fd_settle3:
	pop bc
	ret

fd_command:			; A = command byte.  (The drive is selected again
	push af 		; first: fd_off may have let go of it.)
	ld a,(fd_bcr)
	out (BCR),a
	pop af
	out (FCMD),a
	jr fd_fw

fd_offc:			; fd_off, and CF
	call fd_off
	scf
	ret
md_off:			; (the machine layer's name for it)
fd_off: 			; let go of the drive: with no disk in it the 1772
	ld a,(fd_bcr)		; would keep its motor on (it stops it only after
	and 0FCh		; index pulses, and an empty drive gives none).  The
	out (BCR),a		; next command selects it again.
	ret

fd_wait:			; wait for not-busy, ~3.4 s.  A = status, CF = timeout
	push bc
	push de
	ld de,0600h
	ld b,0
fd_wait1:
	in a,(FSTA)
	rrca
	jr nc,fd_wait2
	djnz fd_wait1
	dec e
	jr nz,fd_wait1
	dec d
	jr nz,fd_wait1
	in a,(FSTA)
	scf
	jr fd_wait3
fd_wait2:
	in a,(FSTA)
	or a
fd_wait3:
	pop de
	pop bc
	ret

; ---------------------------------------------------------------- positioning
md_init:			; (the machine layer's name for it)
fd_init:
	ld a,FD_DEF_BCR
	ld (fd_bcrbase),a
	ld (fd_bcr),a
	out (BCR),a
	xor a
	ld (fd_ebit),a
	ld (fd_cache),a
	ld (fd_dirty),a
	ld (fd_vfy),a
	ld (fd_drive),a 	; drive A
	ld hl,0
	ld (fd_dtrk),hl
	ld hl,0001h		; drive A is restored right now, drive B on first use
	ld (fd_dknown),hl
	ld a,FD_DEF_STEP
	ld (fd_step),a
	ld a,2
	ld (fd_sidewait),a
	ld a,2
	ld (fd_wstride),a	; writes cannot follow each other back to back (measured: see docs/HARDWARE.md)
	; fall through
md_restore:			; (the machine layer's name for it)
fd_restore:
	ld a,(fd_step)
	or 04h			; restore, verify
	call fd_command
	call fd_wait
	ret

fd_seek:			; A = cylinder
	ld d,a
	in a,(FRTRK)
	cp d
	ret z			; already there (carry is clear)
	ld a,d
	out (FDAT),a
	ld a,(fd_step)
	or 14h			; seek, verify (includes the settle delay)
	call fd_command
	call fd_wait
	ret c
	and 10h 		; seek error?
	ret z
	scf
	ret

fd_setside:			; A = 0 or 1
	and 1
	rlca
	rlca
	rlca
	rlca			; -> bit 4
	ld b,a
	ld a,(fd_bcrbase)
	or b
	ld b,a
	ld a,(fd_bcr)
	cp b
	ret z			; unchanged
	ld a,b
	ld (fd_bcr),a
	out (BCR),a
	jp fd_settle

; ---------------------------------------------------------------- one sector
; A sector transfer runs in three phases:
;   1. wait for the first DRQ, with a ~3.4 s timeout.  If BUSY drops first, the
;      command ended without data (write protect, record not found).  The first
;      byte is moved right here: on a read it must be taken within 32 us of DRQ,
;      and setting up the fast loop first took too long (seen on the board).
;   2. move the 512 bytes in the tightest loop possible: status into carry twice
;      (BUSY, then DRQ), move a byte with OUTI / INI.  One poll is 38 T-states
;      (9.5 us at 4 MHz); DRQ is answered within ~18 us.  Speed matters: a byte
;      passes every 32 us, and on a write the controller gives less slack than that.
;      The old loop took up to ~25 us and lost a byte in about 1 write in 10
;      (measured).  BUSY is still tested so a missed byte cannot hang
;      the loop: the command ends, BUSY drops, and we return an error.
;   3. wait for BUSY to clear (CRC checked / written) and check the status.

fd_rd_sector:
	out (FSEC),a
	ld a,(fd_ebit)
	or 80h			; read sector
	call fd_command
	push bc
	push de
	ld de,0600h
	ld b,0
fd_rx1: 			; phase 1
	in a,(FSTA)
	bit 1,a 		; DRQ
	jr nz,fd_rx2
	rrca			; BUSY
	jr nc,fd_rxdone
	djnz fd_rx1
	dec e
	jr nz,fd_rx1
	dec d
	jr nz,fd_rx1
	ld a,0D0h		; timeout: force interrupt
	call fd_command
	scf
	jr fd_rxend
fd_rx2: 			; phase 2.  The first byte must be taken at once:
	in a,(FRDAT)		; a read gives only one byte time (32 us) per byte,
	ld (hl),a		; the first one included
	inc hl
	ld bc,0FF00h+FRDAT	; B = 255 bytes in the first pass, C = data port
	ld d,2			; then one more pass of 256: 1 + 255 + 256 = 512
fd_rx3:
	in a,(FSTA)
	rrca			; CF = BUSY
	jr nc,fd_rxshort	; ended before 512 bytes: a byte was missed
	rrca			; CF = DRQ
	jr nc,fd_rx3
	ini			; (HL) <- data, HL+1, B-1
	jr nz,fd_rx3
	dec d
	jr nz,fd_rx3
	call fd_wait		; phase 3
	jr c,fd_rxend
	jr fd_rxdone
fd_rxshort:
	in a,(FSTA)
	scf
	jr fd_rxend
fd_rxdone:
	in a,(FSTA)
	and 1Ch 		; record not found, CRC error, lost data
	jr z,fd_rxend		; carry is clear
	scf
fd_rxend:
	pop de
	pop bc
	ret

fd_wr_sector:
	out (FSEC),a
	ld a,(fd_ebit)
	or 0A0h 		; write sector
	call fd_command
	push bc
	push de
	ld de,0600h
	ld b,0
fd_tx1: 			; phase 1
	in a,(FSTA)
	bit 1,a
	jr nz,fd_tx2
	rrca
	jr nc,fd_txdone
	djnz fd_tx1
	dec e
	jr nz,fd_tx1
	dec d
	jr nz,fd_tx1
	ld a,0D0h
	call fd_command
	scf
	jr fd_txend
fd_tx2: 			; phase 2 (same shape as the read: first byte at once)
	ld a,(hl)
	out (FDAT),a
	inc hl
	ld bc,0FF00h+FDAT	; B = 255, C = data port; then a pass of 256
	ld d,2
fd_tx3:
	in a,(FSTA)
	rrca			; CF = BUSY
	jr nc,fd_txshort	; ended before 512 bytes: a byte was missed
	rrca			; CF = DRQ
	jr nc,fd_tx3
	outi			; data <- (HL), HL+1, B-1
	jr nz,fd_tx3
	dec d
	jr nz,fd_tx3
	call fd_wait		; phase 3
	jr c,fd_txend
	jr fd_txdone
fd_txshort:
	in a,(FSTA)
	scf
	jr fd_txend
fd_txdone:
	in a,(FSTA)
	and 7Ch 		; protect, fault, RNF, CRC, lost data
	jr z,fd_txend
	scf
fd_txend:
	pop de
	pop bc
	ret

; ---------------------------------------------------------------- whole track
fd_readid:			; A = sector number, CF = no ID found
	push bc
	push de
	push hl
	ld a,0C4h		; read address
	call fd_command
	ld hl,fd_idbuf
	ld de,0600h
	ld b,0
fd_ri1:
	in a,(FSTA)
	bit 1,a
	jr nz,fd_ri2
	rrca
	jr nc,fd_ridone
	djnz fd_ri1
	dec e
	jr nz,fd_ri1
	dec d
	jr nz,fd_ri1
	ld a,0D0h		; timeout
	call fd_command
	scf
	jr fd_riend
fd_ri2:
	in a,(FRDAT)
	ld (hl),a
	inc hl
	jr fd_ri1
fd_ridone:
	in a,(FSTA)
	and 18h 		; record not found / CRC error
	jr z,fd_riok
	scf
	jr fd_riend
fd_riok:
	ld a,(fd_idbuf+2)	; the sector number (never 0: carry stays clear)
	or a
fd_riend:
	pop hl
	pop de
	pop bc
	ret

fd_nextsec:			; A = sector, B = step -> A = sector + B wrapped into 1..9
	add a,b
	cp 10
	ret c
	sub 9
	ret

fd_firstsec:			; choose where to start: the sector after the one under the head
	call fd_readid
	jr c,fd_fs1
	ld b,1
	call fd_nextsec 	; the one that is coming next
	ret
fd_fs1:
	ld a,1			; unreadable: start at sector 1
	ret

fd_sec2addr:			; A = sector -> HL = fd_tdest + (sector-1)*512
	ld hl,fd_vfy		; (verify mode: every sector into VFYBUF, only the
	bit 0,(hl)		;  controller's CRC check matters)
	ld hl,VFYBUF
	ret nz
	dec a
	add a,a
	ld h,a
	ld l,0
	ld de,(fd_tdest)
	add hl,de
	ret

md_rdtrk:			; (the machine layer's name for it)
fd_rd_track:
	ld (fd_tcyl),a
	ld a,c
	ld (fd_tside),a
	ld (fd_tdest),hl
	ld a,3
	ld (fd_try),a
fd_rt_again:
	ld a,(fd_tcyl)
	call fd_seek
	jr c,fd_rt_fail
	ld a,(fd_tside)
	call fd_setside
	call fd_firstsec
	ld (fd_tsec),a
	ld a,9
	ld (fd_cnt),a
fd_rt_sec:
	ld a,(fd_tsec)
	call fd_sec2addr
	ld a,(fd_tsec)
	call fd_rd_sector
	jr c,fd_rt_fail
	ld a,(fd_tsec)
	ld b,1
	call fd_nextsec
	ld (fd_tsec),a
	ld hl,fd_cnt
	dec (hl)
	jr nz,fd_rt_sec
	or a			; success
	ret
fd_rt_fail:
	ld a,(fd_try)
	dec a
	ld (fd_try),a
	jr z,fd_rt_dead
	call fd_restore
	jr fd_rt_again
fd_rt_dead:
	scf
	ret

md_wrtrk:			; (the machine layer's name for it)
fd_wr_track:
	ld (fd_tcyl),a
	ld a,c
	ld (fd_tside),a
	ld (fd_tdest),hl	; (raw: this does not look at the track cache)
	ld a,3
	ld (fd_try),a
fd_wt_again:
	ld a,(fd_tcyl)
	call fd_seek
	jr c,fd_wt_fail
	ld a,(fd_tside)
	call fd_setside
	call fd_firstsec
	ld (fd_tsec),a
	ld a,9
	ld (fd_cnt),a
fd_wt_sec:
	ld a,(fd_tsec)
	call fd_sec2addr
	ld a,(fd_tsec)
	call fd_wr_sector
	jr c,fd_wt_fail
	ld a,(fd_wstride)
	ld b,a
	ld a,(fd_tsec)
	call fd_nextsec
	ld (fd_tsec),a
	ld hl,fd_cnt
	dec (hl)
	jr nz,fd_wt_sec
	or a
	ret
fd_wt_fail:
	ld hl,fd_nfail
	inc (hl)
	in a,(FSTA)		; remember what went wrong (for the tests)
	ld (fd_lstat),a
	ld a,(fd_cnt)
	ld (fd_lcnt),a
	ld a,(fd_try)
	dec a
	ld (fd_try),a
	jr z,fd_wt_dead
	call fd_restore
	jr fd_wt_again
fd_wt_dead:
	scf
	ret

; ---------------------------------------------------------------- LBA layer
; A write-back track cache.  TRKBUF holds one whole track (fd_cache = track
; index + 1, 0 = none).  Single sectors are read from and written into that
; copy.  A track that was written to is "dirty" and goes to the disk only when
; another track is needed or when fd_flush is called -- so fd_flush MUST be
; called (fs_flush and f_close do it) before the disk is taken out or the
; machine is reset.
; fd_flush writes the whole track (two disk turns with fd_wstride = 2) and reads
; it back, up to 3 tries.  The read-back goes sector by sector into VFYBUF and
; only the controller's CRC check counts: a byte lost while writing shows up
; in the write status already, and a weak spot on the disk as a CRC error.
; That is ~1 s per track of 9 sectors, against ~0.3 s per sector one by one.
fd_lba2chs:			; HL = LBA -> fd_ttrk, fd_tcyl, fd_tside, fd_tsec
	ld de,9
	ld b,0			; B = track index
fd_l2a:
	or a
	sbc hl,de
	jr c,fd_l2b
	inc b
	jr fd_l2a
fd_l2b:
	add hl,de
	inc l			; sector 1..9
	ld a,l
	ld (fd_tsec),a
	ld a,b
	ld (fd_ttrk),a
	and 1
	ld (fd_tside),a
	ld a,b
	srl a
	ld (fd_tcyl),a
	ret

fd_secaddr:			; HL = address of sector fd_tsec inside TRKBUF
	ld a,(fd_tsec)
	dec a
	add a,a 		; (sector-1)*2 * 256 = (sector-1)*512
	ld h,a
	ld l,0
	ld bc,TRKBUF
	add hl,bc
	ret

fd_load:			; get track fd_ttrk into TRKBUF.  CF = failed
	ld a,(fd_ttrk)
	inc a
	ld b,a
	ld a,(fd_cache)
	cp b
	ret z			; already there (carry is clear)
	call fd_flush		; the old track goes out first, if it was changed
	ret c
	ld a,(fd_tsec)		; fd_rd_track reuses fd_tsec: keep the wanted sector
	push af
	ld a,(fd_tside)
	ld c,a
	ld a,(fd_tcyl)
	ld hl,TRKBUF
	call fd_rd_track
	pop bc
	ld a,b
	ld (fd_tsec),a		; (LD and POP leave the carry alone)
	jr c,fd_ld_bad
	ld a,(fd_ttrk)
	inc a
	ld (fd_cache),a
	or a
	ret
fd_ld_bad:
	xor a
	ld (fd_cache),a
	scf
	ret

md_read:			; (the machine layer's name for it)
fd_read_lba:
	push de
	call fd_lba2chs
	call fd_load
	pop de
	ret c
	call fd_secaddr
	ld bc,512
	ldir
	or a
	ret

md_write:			; (the machine layer's name for it)
fd_write_lba:
	push de
	call fd_lba2chs
	call fd_load		; the rest of the track must be kept as it is
	pop hl
	ret c
	push hl
	call fd_secaddr
	ex de,hl		; DE = the sector in TRKBUF
	pop hl			; HL = source
	ld bc,512
	ldir
	ld a,1
	ld (fd_dirty),a
	or a
	ret

md_flush:			; (the machine layer's name for it)
fd_flush:			; write the cached track if it was changed.  CF = failed
	ld a,(fd_dirty)
	or a
	ret z
	ld hl,(fd_tcyl) 	; keep the caller's request (fd_tcyl..fd_ttrk)
	push hl
	ld hl,(fd_tsec)
	push hl
	ld a,(fd_cache) 	; which track: cache - 1 = cyl*2 + side
	dec a
	ld b,a
	and 1
	ld (fd_fside),a
	ld a,b
	srl a
	ld (fd_fcyl),a
	ld a,3
	ld (fd_vtry),a
fd_ff_again:
	ld a,(fd_fside)
	ld c,a
	ld a,(fd_fcyl)
	ld hl,TRKBUF
	call fd_wr_track
	jr c,fd_ff_retry
	ld a,(fd_fside) 	; read it back: every sector must pass the CRC check
	ld c,a
	ld a,(fd_fcyl)
	call fd_vfy_track
	jr c,fd_ff_retry
	xor a
	ld (fd_dirty),a
	pop hl
	ld (fd_tsec),hl
	pop hl
	ld (fd_tcyl),hl
	or a
	ret
fd_ff_retry:
	ld a,(fd_vtry)
	dec a
	ld (fd_vtry),a
	jr z,fd_ff_dead
	call fd_restore
	jr fd_ff_again
fd_ff_dead:
	pop hl			; the track stays dirty: a later flush can try again
	ld (fd_tsec),hl
	pop hl
	ld (fd_tcyl),hl
	scf
	ret

md_drop:			; (the machine layer's name for it)
fd_drop:			; forget the cached track without writing it (disk changed)
	xor a
	ld (fd_cache),a
	ld (fd_dirty),a
	ret

; ---------------------------------------------------------------- verify, drives
md_vfytrk:			; (the machine layer's name for it)
fd_vfy_track:			; A = cyl, C = side: read the track, CRC check only
	ld hl,fd_vfy		; CF = failed.  (VFYBUF is overwritten.)
	ld (hl),1
	ld hl,VFYBUF
	call fd_rd_track
	ld hl,fd_vfy		; (LD leaves the carry alone)
	ld (hl),0
	ret

md_select:			; (the machine layer's name for it)
fd_select:			; A = drive, 0 = A or 1 = B.  CF = the old drive's
	ld b,a			; cached track could not be written
	ld a,(fd_drive)
	cp b
	ret z			; already selected (carry is clear)
	push bc
	call fd_flush		; the cache belongs to the old drive
	pop bc
	ret c
	call fd_drop
	ld a,(fd_drive) 	; one track register for both drives: keep the old
	ld e,a			; drive's head position
	ld d,0
	ld hl,fd_dtrk
	add hl,de
	in a,(FRTRK)
	ld (hl),a
	ld a,b
	ld (fd_drive),a
	ld a,1			; BCR: bit 0 selects drive A, bit 1 drive B
	inc b
	dec b
	jr z,fd_sel1
	add a,a
fd_sel1:
	ld c,a
	ld a,(fd_bcrbase)
	and 0F0h
	or c
	ld (fd_bcrbase),a
	ld (fd_bcr),a		; side 0
	out (BCR),a
	call fd_settle
	ld a,(fd_drive) 	; the new drive's head position
	ld e,a
	ld d,0
	ld hl,fd_dtrk
	add hl,de
	ld a,(hl)
	out (FTRK),a
	ld hl,fd_dknown 	; never used yet: find track 0 first
	add hl,de
	ld a,(hl)
	or a
	ret nz
	ld (hl),1
	ld a,(fd_step)		; restore WITHOUT verify and without waiting for the
	or 08h			; motor (h bit): quick, and it works with no disk in
	call fd_command 	; the drive (an empty drive shows up at the first read)
	call fd_wait
	or a
	ret

; ---------------------------------------------------------------- formatting
; A track is written with Write Track (F4h): the controller writes the bytes it
; is given from one index pulse to the next, as an IBM System 34 MFM track.
; Byte values F5h, F6h and F7h are special: F5 writes the A1 sync mark, F6 the
; C2 mark, F7 the two CRC bytes.  The image is built once by fd_mk_image;
; fd_fmt_track only patches the cylinder and side into the nine ID fields.
; (docs/HARDWARE.md section 3 has the layout and the lessons.)

FD_IMGLEN:  equ 6400		; more than one turn (6250 bytes): the rest is gap
FD_ID0:     equ 162		; offset of the first ID field's cylinder byte
FD_IDSTEP:  equ 652		; bytes from one sector to the next

md_mkimg:			; (the machine layer's name for it)
fd_mk_image:			; HL = buffer (FD_IMGLEN bytes): build the track image
	ld (fd_tdest),hl
	ex de,hl
	ld hl,fd_img_head	; gap 4a, index mark, gap 1
	call fd_mk_run
	ld b,9			; nine sectors, numbered 1 to 9
	ld c,1
fd_mk1: push bc
	ld hl,fd_img_id1	; sync, ID mark
	call fd_mk_run		; (this uses BC: get the sector number back)
	pop bc
	push bc
	xor a			; cylinder, side: patched per track
	ld (de),a
	inc de
	ld (de),a
	inc de
	ld a,c			; sector number
	ld (de),a
	inc de
	ld hl,fd_img_id2	; size code 2 (512), CRC, gap 2, sync, data mark,
	call fd_mk_run		; 512 x F6h (written as C2h: the WD1772 takes F5-F7 as marks), CRC, gap 3
	pop bc
	inc c
	djnz fd_mk1
	ld hl,(fd_tdest)	; gap 4b: fill the rest with 4Eh
	ld bc,FD_IMGLEN
	add hl,bc
fd_mk2: ld a,e
	cp l
	jr nz,fd_mk3
	ld a,d
	cp h
	ret z
fd_mk3: ld a,4Eh
	ld (de),a
	inc de
	jr fd_mk2

fd_mk_run:			; copy runs (count word, byte) from HL to DE; count 0 ends
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld a,b
	or c
	ret z
	ld a,(hl)
	inc hl
fd_mkr1:
	ld (de),a
	inc de
	dec bc
	push af
	ld a,b
	or c
	jr z,fd_mkr2
	pop af
	jr fd_mkr1
fd_mkr2:
	pop af
	jr fd_mk_run

fd_img_head:
	defw 80
	defb 4Eh		; gap 4a
	defw 12
	defb 00h
	defw 3
	defb 0F6h		; -> C2 C2 C2
	defw 1
	defb 0FCh		; index mark
	defw 50
	defb 4Eh		; gap 1
	defw 0
fd_img_id1:
	defw 12
	defb 00h
	defw 3
	defb 0F5h		; -> A1 A1 A1
	defw 1
	defb 0FEh		; ID address mark
	defw 0
fd_img_id2:
	defw 1
	defb 02h		; 512-byte sectors
	defw 1
	defb 0F7h		; ID CRC
	defw 22
	defb 4Eh		; gap 2
	defw 12
	defb 00h
	defw 3
	defb 0F5h
	defw 1
	defb 0FBh		; data address mark
	defw 512
	defb 0F6h		; the data
	defw 1
	defb 0F7h		; data CRC
	defw 80
	defb 4Eh		; gap 3
	defw 0

md_fmt:			; (the machine layer's name for it)
fd_fmt_track:			; A = cyl, C = side, HL = image.  CF = failed, A = status
	ld (fd_tdest),hl
	ld (fd_tcyl),a
	ld a,c
	ld (fd_ftmp),a
	ld de,FD_ID0		; patch the nine ID fields
	add hl,de
	ld de,FD_IDSTEP
	ld b,9
fd_ft1: ld a,(fd_tcyl)
	ld (hl),a
	inc hl
	ld a,(fd_ftmp)
	ld (hl),a
	dec hl
	add hl,de
	djnz fd_ft1
	ld a,(fd_tcyl)		; seek WITHOUT verify: the track may hold nothing yet
	out (FDAT),a
	ld a,(fd_step)
	or 10h
	call fd_command
	call fd_wait
	ret c
	ld b,36 		; let the head settle (~30 ms)
fd_ft2: push bc
	ld b,0
fd_ft3: djnz fd_ft3
	pop bc
	djnz fd_ft2
	ld a,(fd_ftmp)
	call fd_setside
	ld a,0F4h		; write track, with the 15 ms settle delay
	call fd_command
	ld hl,(fd_tdest)
	ld c,FDAT
fd_ft4: in a,(FSTA)		; the same tight loop as for sectors, but no count:
	rrca			; the command ends by itself at the next index pulse
	jr nc,fd_ft5		; (the image is longer than one turn)
	rrca
	jr nc,fd_ft4
	outi
	jr fd_ft4
fd_ft5: in a,(FSTA)
	and 44h 		; write protect, lost data
	ret z
	in a,(FSTA)
	scf
	ret

fd_index:			; is a disk turning?  Call after a Type I command
	push bc 		; (restore, seek): its status shows the index hole
	push de 		; in bit 1.  NC = an index pulse began within ~1 s;
	ld de,0 		; CF = none (no disk, or the door is open).
	in a,(FSTA)		; C = the index bit as it is now: only a change
	and 2			; from 0 to 1 after this counts (if the hole is
	ld c,a			; showing right now, wait for the next one)
fd_ix1: in a,(FSTA)
	and 2
	cp c
	ld c,a
	jr z,fd_ix2
	or a			; it changed: did it go from 0 to 1?
	jr nz,fd_ix3
fd_ix2: dec de
	ld a,d
	or e
	jr nz,fd_ix1
	pop de
	pop bc
	scf
	ret
fd_ix3: pop de
	pop bc
	or a
	ret

md_present:			; (the machine layer's name for it)
fd_present:			; CF = no disk turning in the selected drive.  A seek
	in a,(FSTA)		; to where the head already is, without waiting for
	push af 		; the motor (h bit): it ends at once, turns the motor
	in a,(FRTRK)		; on, and leaves the index hole visible in the status.
	out (FDAT),a		; Then: does the hole come round within ~1 s?
	ld a,(fd_step)
	or 18h
	call fd_command
	call fd_wait
	call fd_index
	pop bc			; B = the status before: bit 7 = the motor was on
	jp c,fd_offc		; (no disk: let go of the drive)
	bit 7,b
	ret nz
	ld b,5			; it was off: the controller will not wait for it
fd_pr1: push bc 		; now (the motor is on), so wait here, as it would
	call fd_index		; have: 5 more turns, ~1 s, for the disk to get
	pop bc			; up to speed
	jp c,fd_offc
	djnz fd_pr1
	ret
