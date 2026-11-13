; ==========================================================================
; SYS.ASM - SYS [d:]: make a disk boot ampDOS.
;
; It writes the boot code (KERNEL/MACHINE/AMPRO/BOOTSEC.ASM, assembled into bin/
; bootsec.bin and kept here) into the disk's boot sector, keeping that
; sector's BPB (so the disk's layout and its files stay as they are), and
; saves the OS that is running now as AMPDOS.SYS in the root directory.
; Any ampDOS disk will do: FDISK, then SYS, makes a new boot disk.  An
; original AMPRO boot ROM then boots it: the boot code finds AMPDOS.SYS.
;
; The running OS is the image itself: the OS never writes to its own code, so
; 0000h up to os_end is exactly what was loaded.  To update the OS on a disk
; instead: SERRECV AMPDOS.SYS (a new build: bin/ampdos.bin), then EXIT to boot it.
; ==========================================================================

cmd_sys:
	ld a,(sh_drive) 	; this drive, or the one named
	ld hl,(sh_args)
	ld c,(hl)
	inc c
	dec c
	jr z,csy_1
	ld a,c
	and 0DFh
	sub 'A'
	cp 2
	jr c,csy_1
	ld hl,m_sh_nodrv
	jp con_puts
csy_1:	ld hl,0 		; that drive, its root
	call sh_ctx
	jp c,sh_err
	ld hl,0 		; the boot sector: our code around its BPB
	ld de,SECBUF
	call md_read
	jp c,sh_err
	ld hl,sys_boot		; 00-0A: 3E 3C 90, the JR, "ampDOS"
	ld de,SECBUF
	ld bc,11
	ldir
	ld hl,sys_boot+3Eh	; 3E-1FF: the loader, and 55 AA
	ld de,SECBUF+3Eh
	ld bc,200h-3Eh
	ldir
	ld hl,0
	ld de,SECBUF
	call md_write
	jp c,sh_err
	ld hl,m_sys_name	; the OS itself
	ld ix,sh_fcb2
	call f_create
	jp c,sh_err
	ld de,0
	ld bc,os_end
	call f_write
	jp c,sh_err
	call f_close
	jp c,sh_err
	call fs_flush
	jp c,sh_err
	ld hl,os_end		; "AMPDOS.SYS: 15582 bytes.  This disk boots ampDOS now."
	ld de,m_sys_name
	ex de,hl
	call con_puts
	ex de,hl
	call sh_colsp
	call con_dec16
	ld hl,m_sys_done
	jp con_puts

m_sys_name: defm "AMPDOS.SYS"
	defb 0
m_sys_done: defm " bytes.  This disk boots ampDOS now."
	defb 13,10,0

sys_boot:
	incbin "BIN/BOOTSEC.BIN"
