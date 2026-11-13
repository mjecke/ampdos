; ==========================================================================
; CALLS.ASM - the OS call table.  os_install copies it to OSCALLS (FF00h),
; where programs find it (KERNEL/INC/OS.INC lists the entries).  Only ever ADD
; entries at the end: programs depend on the positions.
; ==========================================================================

os_calls:
	jp sh_warm		; OS_WARM
	jp con_putc		; OS_PUTC
	jp con_getc		; OS_GETC
	jp con_kbhit		; OS_KBHIT
	jp con_puts		; OS_PUTS
	jp con_crlf		; OS_CRLF
	jp con_hex8		; OS_HEX8
	jp con_hex16		; OS_HEX16
	jp con_dec16		; OS_DEC16
	jp con_getline		; OS_GETLINE
	jp os_mount		; OS_MOUNT
	jp f_open		; OS_OPEN
	jp f_read		; OS_READ
	jp f_create		; OS_CREATE
	jp f_write		; OS_WRITE
	jp f_close		; OS_CLOSE
	jp f_delete		; OS_DELETE
	jp f_rename		; OS_RENAME
	jp fs_flush		; OS_FLUSH
	jp fs_errmsg		; OS_ERRMSG
	jp dir_first		; OS_DIRFIRST
	jp dir_next		; OS_DIRNEXT
	jp md_read		; OS_RDLBA
	jp md_write 	; OS_WRLBA
	jp os_version		; OS_VERSION
	jp os_date		; OS_DATE
	jp os_drive		; OS_DRIVE
	jp sh_resolve		; OS_RESOLVE
	jp con_dec32		; OS_DEC32
	jp os_exec		; OS_EXEC
	jp os_memtop		; OS_MEMTOP
	jp sh_mount		; OS_HOME
	jp os_status		; OS_STATUS
	jp scr_do		; OS_SCREEN
	jp os_dirget		; OS_DIRGET
	jp dir_put		; OS_DIRPUT
	jp fat_get		; OS_FATGET
	jp fat_set		; OS_FATSET
	jp os_disk		; OS_DISK
os_calls_n: equ $-os_calls

os_install:			; put the table where programs look for it
	ld hl,os_calls
	ld de,OSCALLS
	ld bc,os_calls_n
	ldir
	ret

	include "GEN/VERSION.INC" ; OS_VER (H major, L minor), OS_PATCH (from VERSION)

os_version:
	ld hl,OS_VER
	ld a,OS_PATCH
	ret

os_date:			; HL = today (DOS format)
	ld hl,(sh_date)
	ret

os_memtop:			; HL = the first address past the TPA
	ld hl,(rd_ptr)		; (less the top 8 KB while the output is redirected)
	ld a,h
	or l
	ld hl,TPA_TOP
	ret z
	ld hl,RD_BUF
	ret

os_status:			; A = the status the program leaves (0 = success):
	ld (sh_status),a	; IF ERRORLEVEL n sees it after the program ends
	ret

os_dirget:			; HL = an entry number -> HL = that entry, whatever it
	ld (fs_dirix),hl	; holds (CF past the end)
	jp dir_get

os_disk:			; A = sectors per cluster, HL = number of data clusters
	ld a,(fs_spc)		; (clusters are 2 .. HL+1)
	ld hl,(fs_nclus)
	ret

os_drive:			; A = current drive, 0 = A, 1 = B
	ld a,(sh_drive)
	ret
