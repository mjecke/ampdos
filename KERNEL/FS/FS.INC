; ==========================================================================
; FS.INC - FAT12 names shared by the file-system modules and their users
; ==========================================================================

; ---- error codes (returned in A with carry set)
FS_EEND:    equ 0	   ; no more entries (not really an error)
FS_EREAD:   equ 1	   ; the disk could not be read
FS_EFMT:    equ 2	   ; not a FAT12 disk we understand
FS_EGEOM:   equ 3	   ; not a disk this drive can read (md_geom: its size, its tracks)
FS_EBAD:    equ 4	   ; broken cluster chain
FS_ENOTF:   equ 5	   ; no such file
FS_ENAME:   equ 6	   ; not a valid 8.3 file name
FS_EISDIR:  equ 7	   ; that name is a directory, not a file
FS_EFULL:   equ 8	   ; no free cluster left
FS_EDIRFULL: equ 9	   ; no free directory entry left
FS_EEXIST:  equ 10	   ; a file with the new name exists already
FS_EWRITE:  equ 11	   ; the disk could not be written
FS_ENOTDIR: equ 12	   ; that name is a file, not a directory
FS_ENOTEMPTY: equ 13	   ; the directory still holds files
FS_EPATH:   equ 14	   ; path too long or not valid
FS_ENODISK: equ 15	   ; no disk turning in the drive
FS_ERO:     equ 16	   ; the file is read-only (ATTRIB -R)

; ---- a directory entry is 32 bytes
DE_NAME:    equ 0	   ; 8 bytes, padded with spaces; first byte 00 = end, E5 = deleted
DE_EXT:     equ 8	   ; 3 bytes
DE_ATTR:    equ 11	   ; attribute bits, below
DE_TIME:    equ 22	   ; word: hhhhhmmm mmmsssss (seconds / 2)
DE_DATE:    equ 24	   ; word: yyyyyyym mmmddddd (year - 1980)
DE_CLUS:    equ 26	   ; word: first cluster (0 = empty file)
DE_SIZE:    equ 28	   ; 4 bytes: size in bytes

ATTR_RO:    equ 01h
ATTR_HID:   equ 02h
ATTR_SYS:   equ 04h
ATTR_VOL:   equ 08h	   ; volume label, not a file
ATTR_DIR:   equ 10h	   ; subdirectory
ATTR_ARC:   equ 20h
ATTR_LFN:   equ 0Fh	   ; all four low bits: a Windows long-name piece, skip it

FAT_EOC:    equ 0FF8h	   ; FAT values from here up mean "end of chain"

; ---- a file control block (FCB): one per open file, 16 bytes, pointed to by IX
FCB_FIRST:  equ 0	   ; word: first cluster
FCB_SIZE:   equ 2	   ; 4 bytes: file size
FCB_POS:    equ 6	   ; 4 bytes: position of the next byte to read
FCB_CLUS:   equ 10	   ; word: the cluster that holds FCB_POS
FCB_DIRIX:  equ 12	   ; word: directory entry number (for updating it later)
FCB_MODE:   equ 14	   ; 0 = opened for reading, 1 = created for writing
FCB_LEN:    equ 16

FS_DEFDATE: equ ((2026-1980) << 9) | (1 << 5) | 1   ; 2026-01-01, until there is a clock
