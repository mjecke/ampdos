; ==========================================================================
; OS.INC - what a program run by the ampDOS shell needs to know.
;
; A program is a plain binary assembled for TPA (org 8000h).  It may use the
; RAM up to OS_MEMTOP: TPA_TOP (FC00h), 8 KB less while its output goes to a
; file (PROG > X).
; The shell loads NAME.BIN there and CALLs it with HL = the rest of the
; command line (zero-terminated, leading spaces skipped).  RET returns to
; the shell, and so does JP OS_WARM.  File names are in the current
; directory of the current drive.  The stack is the shell's: there is
; room for about 300 bytes.
;
; The OS is reached through the call table at OSCALLS.  The entries never
; move, so a program keeps working when the OS behind them changes.
; Registers, inputs and outputs are as for the routine named, in the OS
; sources.  Files: put a 16-byte file control block (FCB_LEN) in your own
; memory and pass it in IX; the error codes and FCB_... names are in
; KERNEL/FS/FS.INC.  Close files you write: unclosed data is thrown away when
; the program ends.
; ==========================================================================

TPA:	    equ 8000h
TPA_TOP:    equ 0FC00h		; the first address past the TPA (OS_MEMTOP says how much
				;  there is now)
OSCALLS:    equ 0FF00h
OS_MIRROR:  equ 0FC00h		; byte: 1 = console output is copied to Serial B too
				; (0 at start; the MIRROR command sets it).
				; A program that uses Serial B itself sets it to 0
				; and puts it back before it ends.

OS_WARM:    equ OSCALLS+0	; back to the shell
OS_PUTC:    equ OSCALLS+3	; A = character                      (con_putc)
OS_GETC:    equ OSCALLS+6	; wait for a key -> A                (con_getc)
OS_KBHIT:   equ OSCALLS+9	; NZ = a key is waiting              (con_kbhit)
OS_PUTS:    equ OSCALLS+12	; HL = zero-terminated text          (con_puts)
SPC:	    equ 80h		; in OS_PUTS text: SPC+n (n = 1..127) prints n spaces
OS_CRLF:    equ OSCALLS+15	; new line                           (con_crlf)
OS_HEX8:    equ OSCALLS+18	; A in hex                           (con_hex8)
OS_HEX16:   equ OSCALLS+21	; HL in hex                          (con_hex16)
OS_DEC16:   equ OSCALLS+24	; HL in decimal                      (con_dec16)
OS_GETLINE: equ OSCALLS+27	; HL = buffer, B = max -> B = length (con_getline)
OS_MOUNT:   equ OSCALLS+30	; read the disk's layout             (fs_mount)
OS_OPEN:    equ OSCALLS+33	; IX = FCB, HL = name                (f_open)
OS_READ:    equ OSCALLS+36	; IX, DE = to, BC = count -> BC      (f_read)
OS_CREATE:  equ OSCALLS+39	; IX = FCB, HL = name                (f_create)
OS_WRITE:   equ OSCALLS+42	; IX, DE = from, BC = count          (f_write)
OS_CLOSE:   equ OSCALLS+45	; IX                                 (f_close)
OS_DELETE:  equ OSCALLS+48	; HL = name                          (f_delete)
OS_RENAME:  equ OSCALLS+51	; HL = old, DE = new                 (f_rename)
OS_FLUSH:   equ OSCALLS+54	; write everything changed to disk   (fs_flush)
OS_ERRMSG:  equ OSCALLS+57	; A = error code -> HL = text        (fs_errmsg)
OS_DIRFIRST: equ OSCALLS+60	; HL = first directory entry         (dir_first)
OS_DIRNEXT: equ OSCALLS+63	; HL = next directory entry          (dir_next)
OS_RDLBA:   equ OSCALLS+66	; HL = sector, DE = to               (md_read)
OS_WRLBA:   equ OSCALLS+69	; HL = sector, DE = from             (md_write)
OS_VERSION: equ OSCALLS+72	; HL = version, H = major, L = minor; A = patch
OS_DATE:    equ OSCALLS+75	; HL = today, DOS format (yyyyyyym mmmddddd)
OS_DRIVE:   equ OSCALLS+78	; A = current drive, 0 = A, 1 = B
OS_RESOLVE: equ OSCALLS+81	; HL = "[d:][path\]name" -> that drive and directory become
				; the ones files are found in; HL = the name part.  CF = error
				; (the shell goes back home after the program ends)
OS_DEC32:   equ OSCALLS+84	; HL = address of a 4-byte number, B = width: decimal
OS_EXEC:    equ OSCALLS+87	; HL = a shell command line, DE = memory it may use, BC = its
				; size (512 or more): runs one built-in command (not programs,
				; not FDISK) and comes back.  CF = refused.
OS_MEMTOP:  equ OSCALLS+90	; HL = the first address past the TPA
OS_HOME:    equ OSCALLS+93	; read the disk again, back to the current drive and directory
				; (after OS_RESOLVE).  CF = failed, message printed
OS_STATUS:  equ OSCALLS+96	; A = the program's exit status, 0 = success: a batch file's
				; IF ERRORLEVEL n is true for n <= it
OS_SCREEN:  equ OSCALLS+99	; A = a screen action: 0 clear the screen (cursor home),
				; 1 cursor home, 2 erase to the end of the line, 3 to the end
				; of the screen, 4 up, 5 down, 6 right, 7 left.  CF = this
				; terminal cannot (clear always can: empty lines)
; The directory and the FAT, for ATTRIB, UNDELETE and the like.  They
; work on the current directory of the current disk (after OS_RESOLVE: that
; one).  Change only what you mean to: then OS_DIRPUT, and OS_FLUSH.
OS_DIRGET:  equ OSCALLS+102	; HL = entry number (0 ...) -> HL = that 32-byte entry, in use,
				; deleted (first byte E5h) or empty (00h: none after it).
				; CF past the end.  It stays valid until the next directory call
OS_DIRPUT:  equ OSCALLS+105	; write the sector of the last entry got back (after changing it)
OS_FATGET:  equ OSCALLS+108	; HL = cluster -> HL = its FAT entry (0 free, FF8+ the end)
OS_FATSET:  equ OSCALLS+111	; HL = cluster, DE = its new entry (in memory until OS_FLUSH)
OS_DISK:    equ OSCALLS+114	; A = sectors per cluster, HL = data clusters (2 .. HL+1)
				; (an entry's fields, DE_..., and ATTR_... are in KERNEL/FS/FS.INC)
