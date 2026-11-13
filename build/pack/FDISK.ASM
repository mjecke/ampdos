; ==========================================================================
; FDISK.ASM - FDISK (also FORMAT): make a fresh DOS 360K disk.
;
;   FDISK              the current drive, full format
;   FDISK B:           drive B
;   FDISK A: /Q        quick: only a new boot sector, FAT and root directory
;                      (the disk must already be formatted)
; A full format writes all 80 tracks with Write Track (fd_fmt_track) and
; reads each one back.  A track that does not read back is a bad track: its
; clusters are marked bad (FF7h) in the FAT so no file ever uses them (but
; tracks 0 and 1 hold the boot sector, FATs and root, so they must be good).
; Then the system area is written, the same in both modes:
;   sector 0       boot sector with the BIOS parameter block of a 360K disk
;   sectors 1-4    two copies of the FAT: FD FF FF, then free (or bad) clusters
;   sectors 5-11   the root directory, all zeros (112 empty entries)
; The track image is built in the TPA, which the shell is free to use.
; ==========================================================================

cmd_fdisk:
	call sh_noexec		; (its track image needs the TPA)
	ret c
	ld a,(sh_drive) 	; defaults: this drive, a full format
	ld (sh_fdrv),a
	xor a
	ld (sh_quick),a
	ld (sh_nbad),a
	ld hl,sh_badmap
	ld b,10
cfd_z:	ld (hl),a
	inc hl
	djnz cfd_z
	ld hl,(sh_args)
cfd_arg:
	call sh_skipsp
	ld a,(hl)
	or a
	jr z,cfd_ask
	cp '/'
	jr z,cfd_opt
	cp '-'
	jr z,cfd_opt
	and 0DFh		; a drive: A: or B:
	sub 'A'
	cp 2
	jr nc,cfd_usage
	ld c,a
	inc hl
	ld a,(hl)
	cp ':'
	jr nz,cfd_usage
	inc hl
	ld a,c
	ld (sh_fdrv),a
	jr cfd_next
cfd_opt:
	inc hl			; an option: /Q
	ld a,(hl)
	and 0DFh
	cp 'Q'
	jr nz,cfd_usage
	inc hl
	ld a,1
	ld (sh_quick),a
cfd_next:
	ld a,(hl)
	or a
	jr z,cfd_ask
	cp ' '
	jr z,cfd_arg
cfd_usage:
	ld hl,m_fd_usage
	jp con_puts

cfd_ask:			; last chance
	ld hl,m_fd_ask1
	call con_puts
	ld a,(sh_fdrv)
	add a,'A'
	call con_putc
	ld hl,m_fd_full
	ld a,(sh_quick)
	or a
	jr z,cfd_a1
	ld hl,m_fd_quick
cfd_a1: call con_puts
	ld hl,m_fd_ask2
	call sh_yes
	jr z,cfd_go
	ld hl,m_fd_cancel
	jp con_puts

cfd_go: ld a,(sh_fdrv)
	call md_select
	jr nc,cfd_g0
	ld a,FS_EWRITE
	jp sh_err
cfd_g0: call is360		; FDISK lays out 360K floppies (FAT, root, boot
	ld a,FS_EGEOM		; sector as below): another drive needs its own
	jp nz,sh_err
cfd_g1: call md_drop		; nothing cached from the old disk counts any more
	ld a,(sh_quick)
	or a
	jr nz,cfd_g2
	call cfd_full
	jr c,cfd_back
cfd_g2: call cfd_system
	jr c,cfd_back
	call cfd_report
cfd_back:
	call md_drop
	ld a,(sh_drive) 	; back to the current drive
	call md_select
	ld hl,0 		; that disk's directories are gone: its root now
	ld a,(sh_fdrv)
	or a
	jr nz,cfd_b1
	ld (sh_cwd0),hl
	ld (SH_PATH0),a 	; (A = 0 here)
	jr cfd_b2
cfd_b1: ld (sh_cwd1),hl
	xor a
	ld (SH_PATH1),a
cfd_b2: ld a,(sh_fdrv)
	ld b,a
	ld a,(sh_drive)
	cp b
	ret nz
	ld (fs_cwd),hl
	ret

; ---------------------------------------------------------------- all tracks
cfd_full:			; CF = stopped (and a message printed)
	ld hl,FMTBUF
	call md_mkimg
	call md_present 	; Write Track waits for the index hole: without a
	jr nc,cff_go		; disk turning it would wait for ever
	ld hl,m_fd_nodisk
	call con_puts
	scf
	ret
cff_go: call md_restore
	xor a
	ld (sh_cyl),a
cff_cyl:
	ld hl,m_fd_cyl		; "formatting cylinder nn" on one line, over and over
	call con_puts
	ld a,(sh_cyl)
	call con_dec2
	call con_kbhit		; Esc stops
	jr z,cff_c1
	call con_getc
	cp 1Bh
	jr nz,cff_c1
	ld hl,m_fd_stop
	call con_puts
	scf
	ret
cff_c1: xor a
	ld (sh_side),a
cff_side:
	ld a,3
	ld (sh_try),a
cff_try:
	ld a,(sh_side)
	ld c,a
	ld a,(sh_cyl)
	ld hl,FMTBUF
	call md_fmt
	jr nc,cff_vfy
	bit 6,a 		; write protected: no point trying again
	jr nz,cff_wp
	ld hl,sh_try
	dec (hl)
	jr nz,cff_try
	push af
	ld hl,m_fd_cant
	call con_puts
	pop af
	call con_hex8
	jp con_crlf_scf
cff_wp: ld hl,m_fd_wp
	call con_puts
	scf
	ret
cff_vfy:
	ld a,(sh_side)
	ld c,a
	ld a,(sh_cyl)
	call md_vfytrk
	jr nc,cff_ok
	ld a,(sh_cyl)		; a bad track: track number = cyl * 2 + side
	add a,a
	ld hl,sh_side
	or (hl)
	cp 2
	jr nc,cff_bad
	ld hl,m_fd_t01		; on tracks 0 and 1 nothing can be done
	call con_puts
	scf
	ret
cff_bad:
	call cfd_bit		; HL = its byte in sh_badmap, A = its bit
	or (hl)
	ld (hl),a
	ld hl,sh_nbad
	inc (hl)
cff_ok: ld a,(sh_side)
	xor 1
	ld (sh_side),a
	jr nz,cff_side
	ld a,(sh_cyl)
	inc a
	ld (sh_cyl),a
	cp 40
	jp nz,cff_cyl
	call con_crlf
	or a
	ret

con_crlf_scf:
	call con_crlf
	scf
	ret

cfd_bit:			; A = track 0..79 -> HL = its byte in sh_badmap, A = its bit
	ld c,a
	srl a
	srl a
	srl a
	ld e,a
	ld d,0
	ld hl,sh_badmap
	add hl,de
	ld a,c
	and 7
	ld b,a
	ld a,1
	inc b
cfb_1:	dec b
	ret z
	add a,a
	jr cfb_1

; ---------------------------------------------------------------- system area
cfd_system:			; CF = failed (message printed)
	ld hl,SECBUF		; the boot sector
	call cfd_zsec
	ld hl,cfd_boot
	ld de,SECBUF
	ld bc,cfd_boot_n
	ldir
	ld hl,(sh_date) 	; a volume serial number: the date and something
	ld (SECBUF+39),hl	; that changes all the time
	ld a,r
	ld (SECBUF+41),a
	ld a,(sh_cyl)
	ld (SECBUF+42),a
	ld a,55h
	ld (SECBUF+510),a
	ld a,0AAh
	ld (SECBUF+511),a
	ld hl,0
	ld de,SECBUF
	call md_write
	jr nc,cfs_1
	ld hl,m_fd_unf		; quick on a disk that was never formatted
	call con_puts
	scf
	ret
cfs_1:	ld hl,FATBUF		; the FAT: 1024 bytes of zeros ...
	ld de,FATBUF+1
	ld bc,1023
	ld (hl),0
	ldir
	ld hl,FATBUF		; ... FD FF FF in front (FD = a 360K disk) ...
	ld (hl),0FDh
	inc hl
	ld (hl),0FFh
	inc hl
	ld (hl),0FFh
	ld a,2			; ... and bad tracks' clusters marked FF7
	ld (sh_cyl),a		; (sh_cyl counts tracks here)
cfs_2:	ld a,(sh_cyl)
	call cfd_bit
	and (hl)
	jr z,cfs_4
	ld a,(sh_cyl)		; sectors t*9 .. t*9+8: cluster = (lba - 12) / 2 + 2
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,de		; HL = t * 9
	ld b,9
cfs_3:	push bc
	push hl
	ld de,12
	or a
	sbc hl,de
	jr c,cfs_3a		; (track 1 starts in the root directory)
	srl h
	rr l
	inc hl
	inc hl
	ld de,0FF7h
	call fat_set
cfs_3a: pop hl
	pop bc
	inc hl
	djnz cfs_3
cfs_4:	ld a,(sh_cyl)
	inc a
	ld (sh_cyl),a
	cp 80
	jr nz,cfs_2
	ld hl,1 		; FAT 1 = sectors 1, 2; FAT 2 = sectors 3, 4
	ld de,FATBUF
	call cfd_wr
	ret c
	ld hl,2
	ld de,FATBUF+512
	call cfd_wr
	ret c
	ld hl,3
	ld de,FATBUF
	call cfd_wr
	ret c
	ld hl,4
	ld de,FATBUF+512
	call cfd_wr
	ret c
	ld hl,SECBUF		; the root directory: sectors 5 to 11, zeros
	call cfd_zsec
	ld hl,5
cfs_5:	push hl
	ld de,SECBUF
	call cfd_wr
	pop hl
	ret c
	inc hl
	ld a,l
	cp 12
	jr nz,cfs_5
	call md_flush		; all of it onto the disk
	ret nc
	ld a,FS_EWRITE
	call sh_err
	scf
	ret

cfd_wr: call md_write	; HL = sector, DE = data.  CF = failed (message printed)
	ret nc
	ld a,FS_EWRITE
	call sh_err
	scf
	ret

cfd_zsec:			; HL = 512 bytes to clear
	ld d,h
	ld e,l
	inc de
	ld bc,511
	ld (hl),0
	ldir
	ret

cfd_report:			; count the FAT's free and bad clusters
	ld hl,0
	ld (sh_free),hl
	ld (sh_free+2),hl
	ld (sh_total),hl
	ld (sh_total+2),hl
	ld bc,2
cfr_1:	ld h,b
	ld l,c
	call fat_get
	ld a,h
	or l
	jr nz,cfr_2
	ld hl,(sh_free)
	inc hl
	ld (sh_free),hl
	jr cfr_3
cfr_2:	ld de,0FF7h
	or a
	sbc hl,de
	jr nz,cfr_3
	ld hl,(sh_total)
	inc hl
	ld (sh_total),hl
cfr_3:	inc bc
	ld a,c			; clusters 2 .. 355 on a 360K disk
	cp 356 & 0FFh
	jr nz,cfr_1
	ld a,b
	cp 356 >> 8
	jr nz,cfr_1
	ld hl,sh_free		; x 1024 bytes per cluster
	ld a,10
	call num_shl32
	ld b,0
	call con_dec32
	ld hl,m_fd_free
	call con_puts
	ld hl,sh_total
	ld a,10
	call num_shl32
	ld b,0
	call con_dec32
	ld hl,m_fd_bad
	jp con_puts

is360:				; Z = the selected drive is a 360K floppy that can be
	call md_geom		; formatted (md_geom: 720 sectors, 9 a track, 2 heads)
	dec a
	ret nz
	ld a,d
	cp 9
	ret nz
	ld a,e
	cp 2
	ret nz
	ld de,720
	or a
	sbc hl,de
	ret

cfd_boot:			; the first 66 bytes of the boot sector
	defb 0EBh,03Ch,090h	; (a PC's "jump over the parameters")
	defm "AMPDOS  " 	; who formatted it
	defw 512		; bytes per sector
	defb 2			; sectors per cluster
	defw 1			; reserved sectors (the boot sector)
	defb 2			; FATs
	defw 112		; root directory entries
	defw 720		; sectors
	defb 0FDh		; media: 360K
	defw 2			; sectors per FAT
	defw 9			; sectors per track
	defw 2			; sides
	defw 0,0		; hidden sectors
	defw 0,0		; (large sector count)
	defb 0,0		; drive number, reserved
	defb 29h		; "the next fields are there"
	defb 0,0,0,0		; serial number (filled in)
m_fd_noname: defm "NO NAME    "     ; volume label (LABEL uses it too)
	defm "FAT12   " 	; file system type
	defb 0CDh,018h		; boot code for a PC: INT 18h ("no system on this disk"),
	defb 0EBh,0FEh		; then stay here
cfd_boot_n: equ $-cfd_boot

m_fd_usage: defm "FDISK [A:|B:] [/Q]"
	defb 13,10,0
m_fd_ask1:  defm "Format drive "
	defb 0
m_fd_full:  defm ":"
	defb 0
m_fd_quick: defm ": (quick)"
	defb 0
m_fd_ask2:  defm " - all on it lost.  Y to go on: "
	defb 0
m_fd_cancel: defm "nothing done"
	defb 13,10,0
m_fd_cyl:   defb 13
	defm "cylinder "
	defb 0
m_fd_stop:  defb 13,10
	defm "stopped: only partly formatted"
	defb 13,10,0
m_fd_cant:  defb 13,10
	defm "cannot format: status "
	defb 0
m_fd_wp:    defb 13,10
	defm "write protected"
	defb 13,10,0
m_fd_t01:   defb 13,10
	defm "track 0 or 1 bad: disk unusable"
	defb 13,10,0
m_fd_nodisk: defm "no disk turning"
	defb 13,10,0
m_fd_unf:   defm "cannot read: not formatted? (FDISK without /Q)"
	defb 13,10,0
m_fd_free:  defm " bytes free, "
	defb 0
m_fd_bad:   defm " bad"
	defb 13,10,0
