; ==========================================================================
; DISKCOPY.ASM - DISKCOPY s: d:   copy a whole disk, track by track.
;
;   DISKCOPY A: B:     the disk in A to the disk in B
;   DISKCOPY A: A:     in one drive: it asks for the source and the target
;                      disk in turn (as many times as memory needs)
; The target is formatted as it is written, so it need not be formatted
; first (and anything on it is lost).  Every track written is read back
; (CRC check).  The copy is exact, boot sector and all: a copy of a boot disk
; boots.  Only 360K disks (40 cylinders, 2 sides, 9 sectors of 512 bytes).
;
; Memory: as many whole tracks (4608 bytes) as fit in the TPA (sh_buf) are
; read in one pass, then written: 6 at a time (14 passes, a swap each in one
; drive).  The Write Track image (fd_mk_image, 6400 bytes) goes in the file
; system's buffers, TRKBUF up to the end of DIRBUF (6656 bytes, in a row): the
; file system is not used meanwhile, and the next command reads the disk again.
; ==========================================================================

DC_SRC:  equ BATBUF+0C0h	; source drive
DC_DST:  equ BATBUF+0C1h	; target drive
DC_SAME: equ BATBUF+0C2h	; 1 = the same drive (swap disks)
DC_N:	 equ BATBUF+0C3h	; tracks per pass
DC_T0:	 equ BATBUF+0C4h	; first track of this pass (track = cylinder * 2 + side)
DC_T:	 equ BATBUF+0C5h	; the track being read or written
DC_I:	 equ BATBUF+0C6h	; tracks left in this pass
DC_PTR:  equ BATBUF+0C7h	; word: its place in memory
DC_NTRK: equ 80
DC_TLEN: equ 4608

cmd_diskcopy:
	call sh_noexec
	ret c
	ld hl,(sh_args) 	; two drives: "A: B:"
	call dc_drv
	jp c,dc_use
	ld (DC_SRC),a
	call dc_drv
	jp c,dc_use
	ld (DC_DST),a
	ld a,(hl)
	or a
	jp nz,dc_use
	ld a,(DC_SRC)		; it copies 360K floppies, track by track
	call md_select
	call is360
	ld a,FS_EGEOM
	jp nz,sh_err
	ld a,(DC_SRC)
	ld b,a
	ld a,(DC_DST)
	sub b
	jr z,dc_1
	ld a,1
dc_1:	xor 1
	ld (DC_SAME),a
	ld hl,(sh_bufsz)	; how many tracks fit
	ld de,DC_TLEN
	ld b,0
dc_2:	or a
	sbc hl,de
	jr c,dc_3
	inc b
	jr dc_2
dc_3:	ld a,b
	or a
	jp z,dc_nomem
	ld (DC_N),a
	ld hl,m_dc_one		; what is about to happen
	ld a,(DC_SAME)
	or a
	jr nz,dc_4
	ld hl,m_dc_from
	call con_puts
	ld a,(DC_SRC)
	call dc_pdrv
	ld hl,m_dc_to
	call con_puts
	ld a,(DC_DST)
	call dc_pdrv
	ld hl,m_dc_lost
dc_4:	call con_puts
	ld hl,m_dc_go
	call con_puts
	call con_getc
	push af
	call con_crlf
	pop af
	cp 1Bh
	ret z

	call fs_flush		; the file system lets go of its buffers
	jp c,sh_err
	call md_drop
	xor a
	ld (fs_mounted),a
	ld (fs_fatdirty),a
	ld hl,0FFFFh
	ld (fs_dirsec),hl
	ld hl,TRKBUF		; the format image
	call md_mkimg
	xor a
	ld (DC_T0),a

dc_pass:			; ---- read a pass's tracks from the source
	ld a,(DC_SAME)
	or a
	jr z,dc_r0
	ld hl,m_dc_src
	call dc_ask
	jp c,dc_stop
dc_r0:	ld a,(DC_SRC)
	call dc_sel
	jp c,dc_end
	call dc_first
dc_r1:	call dc_cs
	call md_rdtrk
	ld hl,m_dc_rerr
	jp c,dc_terr
	call dc_step
	jr nz,dc_r1

	ld a,(DC_SAME)		; ---- write them to the target
	or a
	jr z,dc_w0
	ld hl,m_dc_dst
	call dc_ask
	jp c,dc_stop
dc_w0:	ld a,(DC_DST)
	call dc_sel
	jp c,dc_end
	call dc_first
dc_w1:	call dc_cs		; format, write, read back
	ld hl,TRKBUF
	call md_fmt
	ld hl,m_dc_ferr
	jp c,dc_terr
	call dc_cs
	call md_wrtrk
	ld hl,m_dc_werr
	jp c,dc_terr
	call dc_cs
	call md_vfytrk
	ld hl,m_dc_verr
	jp c,dc_terr
	ld a,(DC_T)		; a dot for each cylinder done
	and 1
	ld a,'.'
	call nz,con_putc
	call sh_brk
	jp c,dc_stop
	call dc_step
	jr nz,dc_w1
	ld a,(DC_T0)		; the next pass
	ld b,a
	ld a,(DC_N)
	add a,b
	ld (DC_T0),a
	cp DC_NTRK
	jp c,dc_pass
	call con_crlf
	ld hl,m_dc_done
	call con_puts
	jr dc_end

dc_stop:
	call con_crlf
	ld hl,m_dc_stop
dc_msg: call sh_fail
	call con_puts
dc_end: jp md_drop		; (nothing in the track cache is from a mounted disk)

dc_use: ld hl,m_dc_use
	jp sh_usage
dc_nomem:
	ld hl,m_dc_mem
	jp sh_usage

dc_terr:			; HL = what failed, on track DC_T
	call con_crlf
	call con_puts
	ld hl,m_dc_cyl
	call con_puts
	ld a,(DC_T)
	srl a
	ld l,a
	ld h,0
	call con_dec16
	ld hl,m_dc_side
	call con_puts
	ld a,(DC_T)
	and 1
	add a,'0'
	call con_putc
	call con_crlf
	ld hl,m_dc_stop
	jr dc_msg

dc_first:			; the first track of the pass, the first buffer
	ld a,(DC_T0)
	ld (DC_T),a
	ld a,(DC_N)
	ld (DC_I),a
	ld hl,(sh_buf)
	ld (DC_PTR),hl
	ret

dc_cs:	ld a,(DC_T)		; A = cylinder, C = side, HL = its buffer
	ld c,a
	srl a
	ld b,a
	ld a,c
	and 1
	ld c,a
	ld a,b
	ld hl,(DC_PTR)
	ret

dc_step:			; to the next track of the pass.  Z = the pass is done
	ld hl,(DC_PTR)
	ld de,DC_TLEN
	add hl,de
	ld (DC_PTR),hl
	ld hl,DC_T
	inc (hl)
	ld a,(hl)
	cp DC_NTRK
	ret z			; the end of the disk
	ld hl,DC_I
	dec (hl)
	ret

dc_sel: 			; A = drive: select it, is there a disk?  CF = no (said)
	push af
	call md_select
	pop bc
	ld hl,m_dc_wsel
	jr c,dc_s1
	push bc
	call md_present
	pop bc
	ret nc
	ld hl,m_dc_nodisk
dc_s1:	call con_crlf
	call con_puts
	ld a,b
	call dc_pdrv
	call con_crlf
	ld hl,m_dc_stop
	call sh_fail
	call con_puts
	scf
	ret

dc_ask: 			; HL = "SOURCE" or "TARGET": ask for that disk.
	push hl 		; CF = Esc
	call con_crlf
	ld hl,m_dc_ins
	call con_puts
	pop hl
	call con_puts
	ld hl,m_dc_in
	call con_puts
	ld a,(DC_SRC)
	call dc_pdrv
	ld hl,m_dc_key
	call con_puts
	call con_getc
	push af
	call con_crlf
	pop af
	cp 1Bh
	scf
	ret z
	or a
	ret

dc_pdrv:			; A = drive: print "A:"
	add a,'A'
	call con_putc
	ld a,':'
	jp con_putc

dc_drv: 			; HL = text: skip spaces, "A:" or "B:" -> A = 0 or 1,
	call sh_skipsp		; HL past it (and the spaces after).  CF = not that
	ld a,(hl)
	and 0DFh
	sub 'A'
	cp 2
	ccf
	ret c
	inc hl
	ld b,a
	ld a,(hl)
	cp ':'
	scf
	ret nz
	inc hl
	call sh_skipsp
	ld a,b
	or a
	ret

m_dc_from: defm "Copy the disk in "
	defb 0
m_dc_to:   defm " to the disk in "
	defb 0
m_dc_lost: defm "; everything on that one is lost."
	defb 13,10,0
m_dc_one:  defm "One drive: you will be asked for each disk in turn."
	defb 13,10,0
m_dc_go:   defm "Press a key to start (Esc stops) "
	defb 0
m_dc_ins:  defm "Put the "
	defb 0
m_dc_src:  defm "SOURCE"
	defb 0
m_dc_dst:  defm "TARGET"
	defb 0
m_dc_in:   defm " disk in "
	defb 0
m_dc_key:  defm ", press a key (Esc stops) "
	defb 0
m_dc_rerr: defm "cannot read the source"
	defb 0
m_dc_ferr: defm "cannot format the target (write-protected?)"
	defb 0
m_dc_werr: defm "cannot write the target"
	defb 0
m_dc_verr: defm "the target does not read back"
	defb 0
m_dc_cyl:  defm ": cylinder "
	defb 0
m_dc_side: defm ", side "
	defb 0
m_dc_nodisk: defm "no disk in "
	defb 0
m_dc_wsel: defm "cannot switch to "
	defb 0
m_dc_stop: defm "DISKCOPY stopped: the target disk is not a whole copy"
	defb 13,10,0
m_dc_done: defm "Disk copied: 40 cylinders, 2 sides."
	defb 13,10,0
m_dc_use:  defm "DISKCOPY A: B:   (or A: A: to swap disks in one drive)"
	defb 13,10,0
m_dc_mem:  defm "not enough memory"
	defb 13,10,0
