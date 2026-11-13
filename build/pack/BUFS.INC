; ==========================================================================
; BUFS.INC - the OS's buffers: in the RAM under the ROM, above the OS code
; (which must end below 5F00h), so that programs get 8000h-FBFFh (31 KB).
; Only the variables (FC00h, where programs may look, e.g. OS_MIRROR), the
; command line, the stack and the call table are at the top.  Include it
; before KERNEL/INC/RAM.INC.
; ==========================================================================
; ---- big buffers
SHBUF:	 equ 05F00h	; 512 bytes  (5F00-60FF): the shell's own: command history, PATH (RAM.INC)
BATBUF:  equ 06100h	; 256 bytes  (6100-61FF): batch files
BATARGS: equ BATBUF	;   80 bytes: the batch file's name and arguments (%0 %1 ...)
BATRAW:  equ BATBUF+50h ;   80 bytes: a line as read, before %n is replaced
BATFCB0: equ BATBUF+0A0h ;  16 bytes: its file control block just after opening (for GOTO)
BATLBL:  equ BATBUF+0B0h ;  16 bytes: the label GOTO looks for (0 = none)
WCLINES: equ BATBUF+0E0h ;  4 bytes: WC: lines
WCWORDS: equ BATBUF+0E4h ;  4 bytes: WC: words
WCBYTES: equ BATBUF+0E8h ;  4 bytes: WC: bytes
WCIN:	 equ BATBUF+0ECh ;  WC: 1 = inside a word
VFYBUF:  equ 06200h	; 512 bytes  (6200-63FF): fd_flush reads written sectors back here
			; (NOT SECBUF: callers write from SECBUF while a flush happens)
TRKBUF:  equ 06400h	; 4608 bytes (6400-75FF): the track cache (FD.ASM)
FATBUF:  equ 07600h	; 1024 bytes (7600-79FF): the whole FAT (2 sectors on a 360K disk)
SECBUF:  equ 07A00h	; 512 bytes  (7A00-7BFF): sector being read or written by FILE.ASM
DIRBUF:  equ 07C00h	; 512 bytes  (7C00-7DFF): the directory sector being looked at
SH_PATH0: equ 07E00h	; 128 bytes  (7E00-7E7F): current directory of drive A ("\SUB\X", 0)
SH_PATH1: equ 07E80h	; 128 bytes  (7E80-7EFF): current directory of drive B
VARS2:	 equ 07F00h	; 256 bytes  (7F00-7FFF): more variables (shell)
