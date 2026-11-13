; ==========================================================================
; RAM.INC - the RAM map: every variable address, and the fixed areas.  The
; big buffers are in BUFS.INC, which must be included before this file.
;
;   0000-5EFF  the OS code (in the RAM under the ROM, which is switched off)
;   5F00-7FFF  its buffers (BUFS.INC)
;   8000-FBFF  programs (the TPA)
;   FC00-FCFF  variables
;   FD00-FD7F  the command line
;   FD80-FEFF  stack (starts at FF00h, grows down)
;   FF00-FF5F  OS call table (KERNEL/INC/OS.INC): programs call the OS through it
; ==========================================================================

; ---- areas
TPA:	 equ 08000h	; where programs are loaded and started
; (TPA_TOP, the first address past the TPA, is in KERNEL/OS/AMPDOS.ASM: FC00h)
OSSTACK: equ 0FF00h	; initial stack pointer
OSCALLS: equ 0FF00h	; the OS call table

; ---- the big buffers and VARS2: KERNEL/INC/BUFS.INC, which must be included BEFORE this file
LINEBUF: equ 0FD00h	; 128 bytes  (FD00-FD7F): the command line
FMTBUF:  equ TPA	; 6400 bytes: FDISK builds its track image in the TPA

; ---- variables (FC00-FCFF)
VARS:	 equ 0FC00h

; console / serial
con_mirror: equ VARS+00h   ; nonzero = also send console output to Serial B (MIRROR ON; 0 at start)

; the machine layer's own variables: VARS+01h .. VARS+2Fh (KERNEL/MACHINE/*/MRAM.INC)
	include "GEN/MACHRAM.INC"

; file system (FS/MOUNT.ASM, FS/FAT.ASM, FS/DIRENT.ASM)
fs_mounted: equ VARS+80h   ; 1 = a disk is mounted and the values below are valid
fs_spc:     equ VARS+81h   ; sectors per cluster
fs_cshift:  equ VARS+82h   ; log2(bytes per cluster): 10 for 2 x 512
fs_nfats:   equ VARS+83h   ; number of FAT copies
fs_fatsecs: equ VARS+84h   ; sectors per FAT
fs_rootsecs: equ VARS+85h  ; sectors in the root directory
fs_fatlba:  equ VARS+86h   ; word: first sector of FAT 1
fs_rootlba: equ VARS+88h   ; word: first sector of the root directory
fs_datalba: equ VARS+8Ah   ; word: first sector of cluster 2
fs_rootents: equ VARS+8Ch  ; word: number of root directory entries
fs_total:   equ VARS+8Eh   ; word: sectors on the disk
fs_nclus:   equ VARS+90h   ; word: number of data clusters
fs_clend:   equ VARS+92h   ; word: first cluster number past the end (nclus + 2)
fs_bpc:     equ VARS+94h   ; word: bytes per cluster
fs_dirix:   equ VARS+96h   ; word: directory entry index being looked at
fs_dirsec:  equ VARS+98h   ; word: sector held in DIRBUF (FFFFh = none)
fs_fatdirty: equ VARS+0ACh ; 1 = FATBUF was changed and is not on the disk yet
fs_fdate:   equ VARS+0AEh  ; word: date stamped on new files (DOS format)
fs_ftime:   equ VARS+0B0h  ; word: time stamped on new files
fs_hint:    equ VARS+0B2h  ; word: where fat_alloc starts looking
fs_cwd:     equ VARS+0E8h  ; word: current directory: its first cluster, 0 = root
fs_t1:	    equ VARS+62h   ; word: SUBDIR.ASM scratch (a cluster)
fs_t2:	    equ VARS+64h   ; word: SUBDIR.ASM scratch (an entry number)
fs_t3:	    equ VARS+66h   ; word: SUBDIR.ASM scratch (the parent directory)
xf_size:    equ VARS+68h   ; 4 bytes: SERRECV / SERSEND: the file's size
xf_left:    equ VARS+6Ch   ; 4 bytes: bytes still to go
xf_len:     equ VARS+70h   ; word: this block's length (1..256)
xf_sum:     equ VARS+72h   ; word: a block's sum
xf_try:     equ VARS+74h   ; tries left for this block
xf_mir:     equ VARS+75h   ; the console-copy setting to put back
xf_ltr:     equ VARS+76h   ; xf_ready's letter
xf_open:    equ VARS+77h   ; 1 = SERRECV has created its file (to remove it on a failure)
sh_exec:    equ VARS+78h   ; 1 = a command is running for a program (OS_EXEC)
sh_exsp:    equ VARS+79h   ; word: OS_EXEC: the stack to go back to
sh_bat:     equ VARS+7Bh   ; 1 = a batch file is running (its lines replace the typed ones)
sh_bdrv:    equ VARS+7Ch   ; the batch file's drive
sh_becho:   equ VARS+7Dh   ; 1 = the batch file's lines are shown (ECHO ON)
sh_bch:     equ VARS+7Eh   ; the character just read from it
sh_xbat:    equ VARS+7Fh   ; 1 = a program name is now tried with .BAT
sh_ifnot:   equ VARS2+0B8h ; IF: 1 = NOT
sh_ifr:     equ VARS2+0B9h ; word: IF: the command after the condition
sh_status:  equ VARS2+0BCh ; the last command's status: 0 = success, 1 = failure
sh_lstat:   equ VARS2+0BDh ;   (the one before the command now running: IF ERRORLEVEL)
sh_wcn:     equ VARS2+0BEh ; word: WC: the next name
sh_bhome:   equ VARS+0FEh  ; 1 = bat_line mounted the batch file's drive: go home after
sh_dot:     equ VARS+0FDh  ; 1 = the program name was typed with an extension
fs_fname2:  equ VARS+0B4h  ; 11 bytes (B4-BE): f_rename's new name
f_lba:	    equ VARS+0C8h  ; word: f_write's sector
fs_fname:   equ VARS+9Ah   ; 11 bytes (9A-A4): a name in directory form, "README  MD "
f_dest:     equ VARS+0A6h  ; word: f_read destination pointer
f_cnt:	    equ VARS+0A8h  ; word: f_read bytes still wanted
f_done:     equ VARS+0AAh  ; word: f_read bytes delivered

; numbers (LIB/NUMBER.ASM)
num_tmp:    equ VARS+0C0h  ; 4 bytes: work value of con_dec32
num_val:    equ VARS+0C4h  ; 4 bytes: con_dec16w puts its number here
rd_ptr:     equ VARS+0CAh  ; word: > redirection: where the next output byte goes (0 = none)
rd_app:     equ VARS+0CCh  ; 1 = >> (add to the file)
rd_cut:     equ VARS+0CDh  ; not 0 = the output did not all fit

; test programs: their own page inside the TPA, so a test run from the shell
; cannot disturb the OS variables

; shell (SHELL/*.ASM, CMD/*.ASM)
sh_cmd:     equ VARS+0F0h  ; 13 bytes (F0-FC): the command word, upper case
sh_word:    equ VARS+0D0h  ; word: where the command word starts in LINEBUF
sh_args:    equ VARS+0D2h  ; word: where its arguments start
sh_arg2:    equ VARS+0D4h  ; word: the second argument
sh_cnt:     equ VARS+0D6h  ; word: counter
sh_name:    equ VARS+0D8h  ; 14 bytes (D8-E5): a program name with ".BIN" added
sh_fcb1:    equ VARS+30h   ; 16 bytes (30-3F): the file a command reads
sh_fcb2:    equ VARS+40h   ; 16 bytes (40-4F): the file a command writes
sh_total:   equ VARS+50h   ; 4 bytes: DIR's total size / COPY's count
sh_free:    equ VARS+54h   ; 4 bytes: DIR's free space
sh_files:   equ VARS+58h   ; word: DIR's file count
sh_ent:     equ VARS+5Ah   ; word: DIR's entry being printed
sh_off:     equ VARS+5Ch   ; 4 bytes: (free: was DUMP's offset)
sh_mode:    equ VARS+60h   ; TYPE: 0 = showing, 1 = after ^Z (just reading on)

; shell, page 2 (VARS2: FB00-FBFF)
sh_date:    equ VARS2+00h  ; word: today, DOS format (DATE)
sh_drive:   equ VARS2+02h  ; current drive: 0 = A, 1 = B
sh_cwd0:    equ VARS2+04h  ; word: current directory of drive A (first cluster, 0 = root)
sh_cwd1:    equ VARS2+06h  ; word: drive B
sh_rdrv:    equ VARS2+08h  ; sh_resolve: the drive a file spec names
sh_sdrv:    equ VARS2+09h  ; COPY: source drive
sh_ddrv:    equ VARS2+0Ah  ; COPY: destination drive
sh_scwd:    equ VARS2+0Ch  ; word: COPY: source directory
sh_dcwd:    equ VARS2+0Eh  ; word: COPY: destination directory
sh_comp:    equ VARS2+10h  ; 14 bytes (10-1D): one part of a path, as typed
sh_quick:   equ VARS2+20h  ; FDISK: 1 = quick
sh_fdrv:    equ VARS2+21h  ; FDISK: drive to format
sh_cyl:     equ VARS2+22h  ; FDISK: cylinder
sh_side:    equ VARS2+23h  ; FDISK: side
sh_try:     equ VARS2+24h  ; FDISK: tries left
sh_nbad:    equ VARS2+25h  ; FDISK: number of bad tracks
sh_badmap:  equ VARS2+26h  ; 10 bytes (26-2F): FDISK: one bit per track, 1 = bad
sh_savecwd: equ VARS2+30h  ; word: CD keeps the old directory here, to undo a failed CD
sh_y:	    equ VARS2+32h  ; DATE: year (word)
sh_m:	    equ VARS2+34h  ; DATE: month
sh_d:	    equ VARS2+35h  ; DATE: day
sh_pathsave: equ VARS2+40h ; 64 bytes (40-7F): CD keeps the old path here
sh_cdate:   equ VARS2+36h  ; word: COPY: the source's date
sh_ctime:   equ VARS2+38h  ; word: COPY: the source's time
sh_dirs:    equ VARS2+3Ah  ; word: DIR: number of directories
sh_sname:   equ VARS2+80h  ; 14 bytes: COPY: the source's name ("NAME.EXT")
sh_dname:   equ VARS2+90h  ; 14 bytes: COPY: the destination's name
sh_buf:     equ VARS2+8Eh  ; word: the memory commands may use (TYPE, COPY, SERRECV ...):
sh_bufsz:   equ VARS2+9Eh  ; word:   the TPA, or what OS_EXEC's caller lends
sh_bfcb:    equ VARS2+0F0h ; 16 bytes (F0-FF): the batch file being run
sh_nonl:    equ VARS2+3Ch  ; 1 = the next prompt starts at the top line (after CLEAR)
sh_word0:   equ VARS2+0C0h ; word: the program name as typed (before sh_resolve)
mt_s1:	    equ VARS2+0C2h ; MEM: the data test leaves out pages mt_s1 .. mt_s2
mt_s2:	    equ VARS2+0C3h
mt_stop:    equ VARS2+0C4h ; MEM: the data test stops at this page (0 = after FFFF)
mt_got:     equ VARS2+0C5h ; MEMTEST: the value read at the first bad address
mt_first:   equ VARS2+0C6h ; word: MEMTEST: the first bad address (FFFFh = none)
scr_rows:   equ VARS2+0C8h ; the terminal's screen: rows (SCREEN ROWS n, 24 at the start),
scr_cols:   equ VARS2+0C9h ;   columns (SCREEN COLS n, 80), and its flags (SCREEN WRAP n):
scr_wrap:   equ VARS2+0CAh ;   1 wraps, 2 EOL is the whole line, 4 EOS from the line's start.  OS_SCREEN 8

; ---- the shell's own area, SHBUF (512 bytes; BUFS.INC says where)
HIST:	  equ SHBUF	  ; 256 bytes (000-0FF): the command history, oldest line first,
HISTLEN:  equ 256	  ;   each ending with a 0, packed; the oldest go when it is full
ENVBUF:   equ SHBUF+100h  ; 64 bytes (100-13F): SET's variables, "NAME=value",0 ... then a 0
ENVLEN:   equ 64
SCRTAB:   equ SHBUF+140h  ; 48 bytes (140-16F): the terminal's codes, 6 for each screen
			  ;   action (SCREEN.ASM); all 0 = a teletype
PATHBUF:  equ SHBUF+170h  ; 64 bytes (170-1AF): PATH, "A:\BIN;B:\TOOLS", 0-terminated
PATHLEN:  equ 64
sh_pbuf:  equ SHBUF+1B0h  ; 80 bytes (1B0-1FF): one PATH directory + "\" + a program name
hs_end:     equ VARS2+0A0h ; word: the end of the history's used part (in HIST)
hs_pos:     equ VARS2+0A2h ; line input: how many lines back Up has gone (0 = the new line)
gl_hist:    equ VARS2+0A3h ; 1 = con_getline offers the history (the shell's prompt only)
wc_pat:     equ VARS2+0A4h ; 11 bytes (A4-AE): a name with wildcards, "????????BAS"
wc_on:	    equ VARS2+0AFh ; 1 = wc_pat has a wildcard in it
sh_cbuf:    equ VARS2+0B0h ; word: COPY: where its data goes (after its list of names)
sh_cbsz:    equ VARS2+0B2h ; word: COPY: how much room there is
sh_nlist:   equ VARS2+0B4h ; word: COPY/DEL: names in the list, or files done
sh_ddir:    equ VARS2+0B6h ; COPY: 1 = "to" is a directory (each copy keeps its name)
sh_ask:     equ VARS2+0B7h ; DEL: 1 = asked already
sh_pnext:   equ VARS2+1Eh  ; word: the next PATH directory to look in
sh_pgmax:   equ VARS2+3Dh  ; MORE: lines to a page (0 = TYPE: no pages)
sh_pg:	    equ VARS2+3Eh  ; MORE: lines left on this page
; (VARS2+3F is free)

SPC:	    equ 80h	   ; in con_puts text: SPC+n (n = 1..127) prints n spaces
