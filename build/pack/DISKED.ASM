; ==========================================================================
; DISKED.ASM - DISKED.BIN: look at and change the raw sectors of a 360K disk:
; the boot sector (and its BPB), the FATs, the root directory, anything DIR
; does not show.  Type  DISKED [B:]
;
;   R [n]          read sector n (0-719, decimal) into the buffer and show it
;   + -            the next / the previous sector
;   D [a [b]]      dump the buffer (hex offsets): alone, 256 bytes, then the rest
;   E a [bytes]    put bytes in the buffer: hex, or "text" in quotes.  With no
;                  bytes it asks line by line (Return keeps one, "." ends)
;   F a b byte     fill part of the buffer
;   W [n]          write the buffer to sector n (alone: where it was read from)
;   B              the buffer as a boot sector: each BPB field by name
;   M              the sector map of the disk: boot, FATs, root, data
;   C n [v]        cluster n (decimal): its sectors and chain; with v (hex, 0-FFF)
;                  set its FAT entry, in every FAT
;   A: B:          use that drive               Q   quit      ?   help
; Sector and cluster numbers are decimal (as DIR and CHKDSK say them), offsets
; and bytes are hex.  Nothing reaches the disk until W (or C n v) and a Y.
;
; The prompt says where you are:  A:0>  = drive A, sector 0 (a * after it: the
; buffer has changes that are not written).  It reads sectors with OS_RDLBA, so
; a disk the file system cannot mount (a broken BPB) can still be looked at and
; repaired.  Only 360K disks (9 sectors per track, 2 sides).
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"

VARS:	  equ 9C00h
v_line:   equ VARS		; 80 bytes: the line typed
v_sec:	  equ VARS+50h		; word: the sector in the buffer
v_drv:	  equ VARS+52h		; 0 = A, 1 = B
v_mod:	  equ VARS+53h		; 1 = the buffer has changes not written
v_dpos:   equ VARS+54h		; word: where the next dump goes on
v_sp:	  equ VARS+56h		; the OS's stack
v_rs:	  equ VARS+58h		; word: a number kept for a moment
v_rem:	  equ VARS+5Ah		; word: bytes left to dump
v_ep:	  equ VARS+5Ch		; word: E: where the next byte goes (in the buffer)
v_cnt:	  equ VARS+5Eh
v_dn:	  equ VARS+60h		; "A:", 0
v_known:  equ VARS+64h		; 1 = the BPB below is read
v_ok:	  equ VARS+65h		; 1 = sector 0 is a FAT12 boot sector
v_res:	  equ VARS+66h		; word: reserved sectors
v_spf:	  equ VARS+68h		; word: sectors per FAT
v_nfat:   equ VARS+6Ah
v_spc:	  equ VARS+6Bh		; sectors per cluster
v_rootn:  equ VARS+6Ch		; word: root directory entries
v_total:  equ VARS+6Eh		; word: total sectors
v_data0:  equ VARS+70h		; word: the first data sector
v_rsec:   equ VARS+72h		; word: sectors of the root directory
v_maxc:   equ VARS+74h		; word: the highest cluster number
v_cl:	  equ VARS+76h		; word: cluster
v_val:	  equ VARS+78h		; word: a FAT entry
v_tab:	  equ VARS+7Ah		; word: B: where its table is
v_bn:	  equ VARS+7Ch		; B: the field's offset (word)
v_arg:	  equ VARS+7Eh		; C: the text after the cluster number

STACK:	  equ 9E00h		; (grows down; the line and variables are below 9C80)
SECBUF:   equ 9E00h		; 512: the sector being looked at
BPBBUF:   equ 0A000h		; 512: sector 0, for the layout
FATBUF:   equ 0A200h		; 1536: FAT 1 (up to 3 sectors)

start:	ld (v_sp),sp
	ld sp,STACK
	push hl
	call OS_DRIVE
	ld (v_drv),a
	xor a
	ld (v_mod),a
	ld (v_known),a
	ld hl,0
	ld (v_sec),hl
	ld (v_dpos),hl
	pop hl
	call skipsp
	ld a,(hl)
	or a
	jr z,st_go
	and 0DFh		; A or B, with or without the colon
	sub 'A'
	cp 2
	jr nc,st_use
	ld b,a
	inc hl
	ld a,(hl)
	or a
	jr z,st_d
	cp ':'
	jr nz,st_use
st_d:	ld a,b
	ld (v_drv),a
	call usedrv
st_go:	ld hl,m_hello
	call OS_PUTS
	ld hl,0
	call goto
	jp main
st_use: ld hl,m_use
	call OS_PUTS
	jr quit

quit:	ld sp,(v_sp)		; back to the OS
	ret

main:	ld sp,STACK
	ld a,(v_drv)		; the prompt:  A:12*>
	add a,'A'
	call OS_PUTC
	ld a,':'
	call OS_PUTC
	ld hl,(v_sec)
	call OS_DEC16
	ld a,(v_mod)
	or a
	jr z,mn_p
	ld a,'*'
	call OS_PUTC
mn_p:	ld hl,m_prompt
	call OS_PUTS
	ld hl,v_line
	ld b,78
	call OS_GETLINE
	ld hl,v_line
	call skipsp
	ld a,(hl)
	or a
	jr z,main
	inc hl
	ld c,a
	ld a,(hl)		; "A:" or "B:" : another drive
	cp ':'
	jr nz,mn_c
	ld a,c
	and 0DFh
	sub 'A'
	cp 2
	jr nc,mn_c
	ld bc,main
	push bc
	jp cmd_drive
mn_c:	ld a,c
	cp '?'
	jr nz,mn_1
	ld a,'H'
	jr mn_2
mn_1:	cp '+'
	jr z,mn_2
	cp '-'
	jr z,mn_2
	and 0DFh		; upper case
mn_2:	ld c,a
	call skipsp		; HL = the arguments
	ld de,ctab
mn_3:	ld a,(de)
	or a
	jr z,bad2		; not a command
	inc de
	cp c
	jr z,mn_4
	inc de
	inc de
	jr mn_3
mn_4:	push hl 		; the handler's address -> DE
	ex de,hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	pop hl
	ld bc,main		; a handler's RET comes back to main
	push bc
	push de
	ret
bad2:	ld hl,m_what
	call OS_PUTS
	jp main

ctab:	defb 'R'
	defw cmd_r
	defb '+'
	defw cmd_next
	defb '-'
	defw cmd_prev
	defb 'D'
	defw cmd_d
	defb 'E'
	defw cmd_e
	defb 'F'
	defw cmd_f
	defb 'W'
	defw cmd_w
	defb 'B'
	defw cmd_b
	defb 'M'
	defw cmd_m
	defb 'C'
	defw cmd_c
	defb 'H'
	defw cmd_h
	defb 'Q'
	defw cmd_q
	defb 0

bad:	ld hl,m_bad		; (jumped to: the RET inside OS_PUTS goes to main)
	jp OS_PUTS

cmd_q:	call chkmod
	ret c
	jp quit

cmd_h:	ld hl,m_help
	jp OS_PUTS

; ---------------------------------------------------------------- helpers
skipsp: ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr skipsp

hexdig: 			; A = a character -> its value; CF = not a hex digit
	cp '0'
	ret c
	cp '9'+1
	jr nc,hd_1
	sub '0'
	or a
	ret
hd_1:	and 0DFh
	cp 'A'
	ret c
	cp 'G'
	ccf
	ret c
	sub 'A'-10
	or a
	ret

hexnum: 			; HL = text: spaces, then 1 to 4 hex digits, then a space
	call skipsp		; or the end -> DE.  HL after the number.  CF = not that
	ld de,0
	ld b,0
hn_1:	ld a,(hl)
	call hexdig
	jr c,hn_2
	push hl
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	or l
	ld l,a
	ex de,hl
	pop hl
	inc hl
	inc b
	ld a,b
	cp 5
	jr c,hn_1
	scf			; five digits: too many
	ret
hn_2:	ld a,b
	or a
	jr z,hn_bad		; no digit at all
	ld a,(hl)
	or a
	ret z
	cp ' '
	ret z
hn_bad: scf
	ret

bytearg:			; like hexnum, but 0..FF (E = the value)
	call hexnum
	ret c
	ld a,d
	or a
	ret z
	scf
	ret

decnum: 			; like hexnum, but decimal (up to 4 digits)
	call skipsp
	ld de,0
	ld b,0
dn_1:	ld a,(hl)
	sub '0'
	jr c,dn_2
	cp 10
	jr nc,dn_2
	push hl
	ld h,d
	ld l,e
	add hl,hl		; x2
	add hl,hl		; x4
	add hl,de		; x5
	add hl,hl		; x10
	ld e,a
	ld d,0
	add hl,de
	ex de,hl
	pop hl
	inc hl
	inc b
	ld a,b
	cp 5
	jr c,dn_1
	scf
	ret
dn_2:	ld a,b
	or a
	jr z,dn_bad
	ld a,(hl)
	or a
	ret z
	cp ' '
	ret z
dn_bad: scf
	ret

chksec: 			; DE = a sector number: CF (and a message) if over 719
	push hl
	ld hl,719
	or a
	sbc hl,de
	pop hl
	ret nc
	ld hl,m_range
	call OS_PUTS
	scf
	ret

chkoff: 			; DE = an offset in the buffer: CF (and a message) if over 1FF
	push hl
	ld hl,511
	or a
	sbc hl,de
	pop hl
	ret nc
	ld hl,m_off
	call OS_PUTS
	scf
	ret

space:	ld a,' '
	jp OS_PUTC

chkkey: 			; a key pressed? Esc: CF.  Another key pauses until one more
	call OS_KBHIT
	jr nz,ck_1
	or a
	ret
ck_1:	call OS_GETC
	cp 1Bh
	jr z,ck_esc
	call OS_GETC
	cp 1Bh
	jr z,ck_esc
	or a
	ret
ck_esc: scf
	ret

yesno:				; NC = Y
	call OS_GETC
	and 0DFh
	cp 'Y'
	jr nz,yn_n
	ld a,'Y'
	call OS_PUTC
	call OS_CRLF
	or a
	ret
yn_n:	ld hl,m_no
	call OS_PUTS
	scf
	ret

chkmod: 			; changes in the buffer: ask.  CF = keep them
	ld a,(v_mod)
	or a
	ret z
	ld hl,m_disc
	call OS_PUTS
	call yesno
	ret c
	xor a
	ld (v_mod),a
	ret

; ---------------------------------------------------------------- disk
usedrv: 			; make v_drv the drive raw reads go to (OS_RESOLVE does
	ld a,(v_drv)		; that, and mounts it; a disk that cannot be mounted is
	add a,'A'		; fine: it is selected all the same)
	ld (v_dn),a
	ld a,':'
	ld (v_dn+1),a
	xor a
	ld (v_dn+2),a
	ld (v_known),a
	ld hl,v_dn
	call OS_RESOLVE
	ret nc
	call OS_ERRMSG		; "(the file system cannot use it: ...)"
	push hl
	ld hl,m_nofs
	call OS_PUTS
	pop hl
	call OS_PUTS
	ld a,')'
	call OS_PUTC
	call OS_CRLF
	ret

rdsec:				; HL = sector, DE = where to.  CF = failed (said so)
	call OS_RDLBA
	ret nc
	ld hl,m_rderr
	call OS_PUTS
	scf
	ret

wrsec:				; HL = sector, DE = from.  CF = failed (said so)
	call OS_WRLBA
	jr c,ws_bad
	call OS_FLUSH		; (the track goes to the disk now)
	ret nc
ws_bad: ld hl,m_wrerr
	call OS_PUTS
	scf
	ret

loadsec:			; HL = a sector -> the buffer.  CF = failed
	push hl
	ld de,SECBUF
	call rdsec
	pop hl
	ret c
	ld (v_sec),hl
	xor a
	ld (v_mod),a
	ld hl,0
	ld (v_dpos),hl
	ret

goto:	call loadsec		; read sector HL, say what it is, show its first half
	ret c
	call header
	jp dump

getbpb: 			; the layout of the disk from sector 0 (not the buffer)
	xor a
	ld (v_ok),a
	inc a
	ld (v_known),a
	ld hl,0
	ld de,BPBBUF
	call rdsec
	ret c
	ld hl,(BPBBUF+11)	; 512 bytes per sector
	ld de,512
	or a
	sbc hl,de
	ret nz
	ld a,(BPBBUF+13)
	or a
	ret z
	ld (v_spc),a
	ld a,(BPBBUF+16)
	or a
	ret z
	ld (v_nfat),a
	ld hl,(BPBBUF+14)
	ld a,h
	or l
	ret z
	ld (v_res),hl
	ld hl,(BPBBUF+22)
	ld a,h
	or l
	ret z
	ld (v_spf),hl
	ld hl,(BPBBUF+17)
	ld (v_rootn),hl
	ld de,15		; root sectors = (entries + 15) / 16
	add hl,de
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld (v_rsec),hl
	ld hl,(BPBBUF+19)
	ld a,h
	or l
	jr nz,gb_1
	ld hl,720
gb_1:	ld (v_total),hl
	ld hl,(v_res)		; the first data sector = reserved + FATs + root
	ld a,(v_nfat)
	ld b,a
	ld de,(v_spf)
gb_2:	add hl,de
	djnz gb_2
	ld de,(v_rsec)
	add hl,de
	ld (v_data0),hl
	ex de,hl
	ld hl,(v_total)
	or a
	sbc hl,de
	ret c
	ld a,(v_spc)		; the highest cluster = (data sectors / spc) + 1
	ld e,a
	ld d,0
	ld bc,1
gb_3:	or a
	sbc hl,de
	jr c,gb_4
	inc bc
	jr gb_3
gb_4:	ld (v_maxc),bc
	ld a,1
	ld (v_ok),a
	ret

needbpb:
	ld a,(v_known)
	or a
	ret nz
	jp getbpb

; ---------------------------------------------------------------- R + -
header: 			; "Sector 5 (drive A): FAT 1, sector 2 of 2"
	ld hl,m_sector
	call OS_PUTS
	ld hl,(v_sec)
	call OS_DEC16
	ld hl,m_drive
	call OS_PUTS
	ld a,(v_drv)
	add a,'A'
	call OS_PUTC
	ld hl,m_close
	call OS_PUTS
	call needbpb
	ld a,(v_ok)
	or a
	jr nz,ds_1
	ld hl,m_nolay
	call OS_PUTS
	jp OS_CRLF
ds_1:	call describe
	jp OS_CRLF

describe:			; what the sector (v_sec) is, from the layout
	ld hl,(v_sec)
	ld de,(v_res)
	or a
	sbc hl,de
	jr nc,ds_f
	ld hl,(v_sec)
	ld a,h
	or l
	ld hl,m_boot
	jr z,ds_p
	ld hl,m_resv
ds_p:	jp OS_PUTS
ds_f:	ld a,(v_nfat)		; HL = sectors past the reserved ones
	ld b,a
	ld de,(v_spf)
	ld c,1			; C = which FAT
ds_f1:	or a
	sbc hl,de
	jr c,ds_f2
	inc c
	djnz ds_f1
	jr ds_root
ds_f2:	add hl,de		; HL = sector within that FAT
	ld a,c
	ld (v_cnt),a
	push hl
	ld hl,m_fat
	call OS_PUTS
	ld a,(v_cnt)
	ld l,a
	ld h,0
	call OS_DEC16
	ld hl,m_secof
	call OS_PUTS
	pop hl
	inc hl
	call OS_DEC16
	ld hl,m_of
	call OS_PUTS
	ld hl,(v_spf)
	jp OS_DEC16
ds_root:			; HL = sectors past the FATs
	ld de,(v_rsec)
	push hl
	or a
	sbc hl,de
	pop hl
	jr nc,ds_data
	push hl
	ld hl,m_root
	call OS_PUTS
	pop hl
	add hl,hl		; x16 : its first entry
	add hl,hl
	add hl,hl
	add hl,hl
	push hl
	call OS_DEC16
	ld hl,m_to
	call OS_PUTS
	pop hl
	ld de,15
	add hl,de
	jp OS_DEC16
ds_data:
	or a
	sbc hl,de		; HL = sector in the data area
	ld a,(v_spc)
	ld e,a
	ld d,0
	ld bc,2 		; BC = the cluster
ds_d1:	or a
	sbc hl,de
	jr c,ds_d2
	inc bc
	jr ds_d1
ds_d2:	add hl,de		; HL = sector within the cluster
	push hl
	push bc
	ld hl,m_clus
	call OS_PUTS
	pop hl
	call OS_DEC16
	ld hl,m_secof
	call OS_PUTS
	pop hl
	inc hl
	call OS_DEC16
	ld hl,m_of
	call OS_PUTS
	ld a,(v_spc)
	ld l,a
	ld h,0
	jp OS_DEC16

cmd_r:	ld a,(hl)
	or a
	jr nz,r_1
	ld hl,(v_sec)		; no number: read this sector again
	jr r_go
r_1:	call decnum
	jp c,bad
	call chksec
	ret c
	ex de,hl
r_go:	push hl
	call chkmod
	pop hl
	ret c
	jp goto

cmd_next:
	ld hl,(v_sec)
	inc hl
	ld de,720
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,r_go
	ld hl,m_end
	jp OS_PUTS

cmd_prev:
	ld hl,(v_sec)
	ld a,h
	or l
	jr nz,pv_1
	ld hl,m_first
	jp OS_PUTS
pv_1:	dec hl
	jr r_go

cmd_drive:			; A = the drive (0, 1)
	ld (v_rs),a
	call chkmod
	ret c
	ld a,(v_rs)
	ld (v_drv),a
	call usedrv
	ld hl,0
	jp goto

; ---------------------------------------------------------------- D
cmd_d:	ld a,(hl)
	or a
	jr nz,d_arg
dump:	ld de,(v_dpos)		; alone: the next 256 bytes
	ld a,d
	cp 2
	jr c,d_cnt
	ld de,0
	jr d_cnt
d_arg:	call hexnum
	jp c,bad
	ld (v_rs),de
	call chkoff
	ret c
	call skipsp
	ld a,(hl)
	or a
	jr z,d_one
	call hexnum
	jp c,bad
	call chkoff
	ret c
	ld hl,(v_rs)		; a range: start end
	ex de,hl
	or a
	sbc hl,de
	jp c,bad
	inc hl
	ld b,h
	ld c,l
	jr d_go
d_one:	ld de,(v_rs)
d_cnt:	ld hl,512		; 256 bytes, or what is left of the sector
	or a
	sbc hl,de
	ld bc,256
	push hl
	or a
	sbc hl,bc
	pop hl
	jr nc,d_go
	ld b,h
	ld c,l
d_go:	ld (v_rem),bc
	ld (v_rs),de
d_line: ld bc,(v_rem)		; E = bytes on this line: 16, or what is left
	ld a,b
	or a
	jr nz,d_16
	ld a,c
	cp 16
	jr c,d_n
d_16:	ld a,16
d_n:	ld (v_cnt),a
	ld hl,(v_rs)		; the offset
	call OS_HEX16
	ld a,':'
	call OS_PUTC
	ld de,SECBUF
	add hl,de
	ld a,(v_cnt)
	ld e,a
	push hl
	ld b,16
	ld d,e
d_h:	call space
	ld a,d
	or a
	jr z,d_pad
	ld a,(hl)
	call OS_HEX8
	inc hl
	dec d
	jr d_hn
d_pad:	call space
	call space
d_hn:	djnz d_h
	call space
	call space
	pop hl			; the same bytes again, as characters
	ld b,e
d_a:	ld a,(hl)
	inc hl
	cp ' '
	jr c,d_dot
	cp 7Fh
	jr c,d_ok
d_dot:	ld a,'.'
d_ok:	call OS_PUTC
	djnz d_a
	call OS_CRLF
	ld a,(v_cnt)		; that many bytes done
	ld e,a
	ld d,0
	ld hl,(v_rs)
	add hl,de
	ld (v_rs),hl
	ld (v_dpos),hl
	ld hl,(v_rem)
	or a
	sbc hl,de
	ld (v_rem),hl
	ld a,h
	or l
	ret z
	call chkkey
	ret c
	jr d_line

; ---------------------------------------------------------------- E  F
cmd_e:	call hexnum
	jp c,bad
	call chkoff
	ret c
	ld a,d
	add a,SECBUF>>8
	ld d,a
	ld (v_ep),de
	call skipsp
	ld a,(hl)
	or a
	jr z,e_ask
	call e_list
	jp c,bad
	ret
e_list: call skipsp		; bytes and "text" up to the end of the line.  CF = bad
	ld a,(hl)
	or a
	ret z
	cp '"'
	jr nz,e_hex
	inc hl
e_q:	ld a,(hl)
	or a
	ret z
	inc hl
	cp '"'
	jr z,e_list
	call e_put
	ret c
	jr e_q
e_hex:	call bytearg
	ret c
	ld a,e
	call e_put
	ret c
	jr e_list
e_put:	push hl 		; A = a byte into the buffer, if there is room
	ld hl,(v_ep)
	ld d,a
	ld a,h
	cp (SECBUF>>8)+2
	jr nc,e_full
	ld (hl),d
	inc hl
	ld (v_ep),hl
	ld a,1
	ld (v_mod),a
	pop hl
	or a
	ret
e_full: ld hl,m_full
	call OS_PUTS
	pop hl
	scf
	ret
e_ask:	ld hl,(v_ep)		; "0003 41 : "
	ld a,h
	cp (SECBUF>>8)+2
	ret nc
	ld de,SECBUF
	or a
	sbc hl,de
	call OS_HEX16
	call space
	ld hl,(v_ep)
	ld a,(hl)
	call OS_HEX8
	ld a,':'
	call OS_PUTC
	call space
	ld hl,v_line
	ld b,40
	call OS_GETLINE
	ld hl,v_line
	call skipsp
	ld a,(hl)
	or a
	jr z,e_next		; Return: leave it, go on
	cp '.'
	ret z			; "." ends
	call e_list
	jr nc,e_ask
	ld hl,m_bad
	call OS_PUTS
	jr e_ask
e_next: ld hl,(v_ep)
	inc hl
	ld (v_ep),hl
	jr e_ask

cmd_f:	call hexnum		; start end byte
	jp c,bad
	call chkoff
	ret c
	ld (v_rs),de
	call hexnum
	jp c,bad
	call chkoff
	ret c
	ld (v_rem),de
	call bytearg
	jp c,bad
	ld hl,(v_rem)		; HL = end, DE = value: count = end - start + 1
	push de
	ld de,(v_rs)
	or a
	sbc hl,de
	jr c,f_bad
	inc hl
	ld b,h
	ld c,l
	ld hl,SECBUF
	add hl,de
	pop de
	ld (hl),e
	ld a,1
	ld (v_mod),a
	dec bc
	ld a,b
	or c
	ret z
	ld d,h
	ld e,l
	inc de
	ldir
	ret
f_bad:	pop de
	jp bad

; ---------------------------------------------------------------- W
cmd_w:	ld a,(hl)
	or a
	jr nz,w_1
	ld hl,(v_sec)
	jr w_go
w_1:	call decnum
	jp c,bad
	call chksec
	ret c
	ex de,hl
w_go:	ld (v_rs),hl
	ld hl,m_wr1		; "Write the buffer to sector 5 of drive A? (Y/N) "
	call OS_PUTS
	ld hl,(v_rs)
	call OS_DEC16
	ld hl,m_drive2
	call OS_PUTS
	ld a,(v_drv)
	add a,'A'
	call OS_PUTC
	ld hl,m_wr2
	call OS_PUTS
	call yesno
	ret c
	ld hl,(v_rs)
	ld de,SECBUF
	call wrsec
	ret c
	xor a
	ld (v_known),a		; (the layout may have changed)
	ld hl,(v_rs)
	ld de,(v_sec)
	or a
	sbc hl,de
	jr nz,w_done
	xor a
	ld (v_mod),a
w_done: ld hl,m_done
	jp OS_PUTS

; ---------------------------------------------------------------- B
cmd_b:	ld hl,m_bhead
	call OS_PUTS
	ld hl,btab
	ld (v_tab),hl
b_next: ld hl,(v_tab)
	ld e,(hl)		; the field's offset
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)		; its kind
	inc hl
	ld (v_cnt),a
	ld a,d
	cp 0FFh
	ret z			; (the end of the table)
	ld (v_bn),de
	push hl
	ex de,hl
	call OS_HEX16
	call space
	call space
	pop hl
	ld b,0			; the name, padded to 26 columns
b_nm:	ld a,(hl)
	inc hl
	or a
	jr z,b_pad
	call OS_PUTC
	inc b
	jr b_nm
b_pad:	ld (v_tab),hl
	ld a,26
	sub b
	jr nc,b_pd
	xor a
b_pd:	ld b,a
	inc b
b_pl:	call space
	djnz b_pl
	ld hl,(v_bn)
	ld de,SECBUF
	add hl,de		; HL = the field in the buffer
	ld a,(v_cnt)
	call bshow
	call OS_CRLF
	jr b_next

bshow:	cp 0			; kinds: 0 = hex bytes (3), 1 = text (8), 2 = word, 3 = byte,
	jr z,bs_hex3		; 4 = byte in hex, 5 = 32-bit number, 6 = text (11),
	cp 1			; 7 = the ID (4 bytes, hex), 8 = a signature (2 bytes, hex)
	jr z,bs_t8
	cp 2
	jr z,bs_w
	cp 3
	jr z,bs_b
	cp 4
	jr z,bs_hx
	cp 5
	jr z,bs_d
	cp 6
	jr z,bs_t11
	cp 7
	jr z,bs_id
	ld a,(hl)		; 8: bytes in order
	call OS_HEX8
	inc hl
	ld a,(hl)
	jp OS_HEX8
bs_hex3:
	ld b,3
bs_h3:	ld a,(hl)
	call OS_HEX8
	call space
	inc hl
	djnz bs_h3
	ret
bs_t8:	ld b,8
	jr bs_txt
bs_t11: ld b,11
bs_txt: ld a,'"'
	call OS_PUTC
bs_tl:	ld a,(hl)
	inc hl
	cp ' '
	jr c,bs_dot
	cp 7Fh
	jr c,bs_tp
bs_dot: ld a,'.'
bs_tp:	call OS_PUTC
	djnz bs_tl
	ld a,'"'
	jp OS_PUTC
bs_w:	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	jp OS_DEC16
bs_b:	ld l,(hl)
	ld h,0
	jp OS_DEC16
bs_hx:	ld a,(hl)
	call OS_HEX8
	ld a,'h'
	jp OS_PUTC
bs_d:	ld b,1			; a 32-bit number: OS_DEC32 (HL = its address)
	jp OS_DEC32
bs_id:	inc hl
	inc hl
	inc hl
	ld a,(hl)
	call OS_HEX8
	dec hl
	ld a,(hl)
	call OS_HEX8
	ld a,'-'
	call OS_PUTC
	dec hl
	ld a,(hl)
	call OS_HEX8
	dec hl
	ld a,(hl)
	jp OS_HEX8

; offset (word), kind, name.  Offsets: the BPB (DOS 2/3.31/4+) and the extended part
btab:	defw 00h
	defb 0
	defm "jump"
	defb 0
	defw 03h
	defb 1
	defm "OEM name"
	defb 0
	defw 0Bh
	defb 2
	defm "bytes per sector"
	defb 0
	defw 0Dh
	defb 3
	defm "sectors per cluster"
	defb 0
	defw 0Eh
	defb 2
	defm "reserved sectors"
	defb 0
	defw 10h
	defb 3
	defm "FATs"
	defb 0
	defw 11h
	defb 2
	defm "root directory entries"
	defb 0
	defw 13h
	defb 2
	defm "total sectors"
	defb 0
	defw 15h
	defb 4
	defm "media descriptor"
	defb 0
	defw 16h
	defb 2
	defm "sectors per FAT"
	defb 0
	defw 18h
	defb 2
	defm "sectors per track"
	defb 0
	defw 1Ah
	defb 2
	defm "heads"
	defb 0
	defw 1Ch
	defb 5
	defm "hidden sectors"
	defb 0
	defw 20h
	defb 5
	defm "total sectors (32 bit)"
	defb 0
	defw 24h
	defb 4
	defm "drive number"
	defb 0
	defw 26h
	defb 4
	defm "extended boot signature"
	defb 0
	defw 27h
	defb 7
	defm "volume ID"
	defb 0
	defw 2Bh
	defb 6
	defm "volume label"
	defb 0
	defw 36h
	defb 1
	defm "file system"
	defb 0
	defw 1FEh
	defb 8
	defm "boot signature (55AA)"
	defb 0
	defw 0FFFFh
	defb 0

; ---------------------------------------------------------------- M
cmd_m:	call needbpb
	ld a,(v_ok)
	or a
	jr nz,m_1
	ld hl,m_nolay
	call OS_PUTS
	jp OS_CRLF
m_1:	ld hl,m_mhead
	call OS_PUTS
	ld hl,0 		; the boot sector (and any other reserved ones)
	ld de,(v_res)
	dec de
	ld bc,m_boot
	ld a,d
	or e
	jr z,m_b
	ld bc,m_resv
m_b:	call mrange
	call OS_CRLF
	ld a,1
	ld (v_cnt),a		; the FATs
m_f:	ld hl,(v_rs)
	ld de,(v_spf)
	add hl,de
	dec hl
	ex de,hl
	ld hl,(v_rs)
	ld bc,m_fat
	call mrange
	ld a,(v_cnt)
	ld l,a
	ld h,0
	call OS_DEC16
	call OS_CRLF
	ld a,(v_cnt)
	ld b,a
	inc a
	ld (v_cnt),a
	ld a,(v_nfat)
	cp b
	jr nz,m_f
	ld hl,(v_rs)		; the root directory
	ld de,(v_rsec)
	add hl,de
	dec hl
	ex de,hl
	ld hl,(v_rs)
	ld bc,m_rootl
	call mrange
	ld hl,(v_rootn)
	call OS_DEC16
	ld hl,m_entr
	call OS_PUTS
	ld hl,(v_rs)		; and the data, to the end
	ld de,(v_total)
	dec de
	ld bc,m_datal
	call mrange
	ld hl,(v_maxc)
	call OS_DEC16
	ld hl,m_clr
	call OS_PUTS
	ld a,(v_spc)
	ld l,a
	ld h,0
	call OS_DEC16
	ld hl,m_secs
	jp OS_PUTS

mrange: 			; "  5-11   text" for sectors HL to DE (just one: "  5"), BC = the
	ld (v_rem),hl		; text.  v_rs = the sector after
	push bc
	push de
	xor a
	ld (v_bn),a		; (columns printed so far)
	call space
	call space
	ld hl,(v_rem)
	call decw
	pop de
	ld hl,(v_rem)
	or a
	sbc hl,de
	jr z,m_p1
	push de
	ld a,'-'
	call OS_PUTC
	ld a,(v_bn)
	inc a
	ld (v_bn),a
	pop hl
	push hl
	call decw
	pop de
m_p1:	inc de
	ld (v_rs),de
	ld a,(v_bn)
	ld b,a
	ld a,11
	sub b
	jr nc,m_p2
	xor a
m_p2:	ld b,a
	inc b
m_p3:	call space
	djnz m_p3
	pop hl
	jp OS_PUTS

decw:				; HL in decimal, and the digits are counted in v_bn
	ld b,1
	ld de,10
	call dw_c
	ld de,100
	call dw_c
	ld de,1000
	call dw_c
	ld a,(v_bn)
	add a,b
	ld (v_bn),a
	jp OS_DEC16
dw_c:	push hl
	or a
	sbc hl,de
	pop hl
	ret c
	inc b
	ret

; ---------------------------------------------------------------- C
cmd_c:	push hl
	call needbpb
	pop hl
	ld a,(v_ok)
	or a
	jr nz,c_1
	ld hl,m_nolay
	call OS_PUTS
	jp OS_CRLF
c_1:	ld a,(hl)
	or a
	jp z,bad
	call decnum
	jp c,bad
	ld (v_cl),de
	ld (v_arg),hl
	ld hl,(v_maxc)		; 2 .. the highest cluster
	or a
	sbc hl,de
	jr c,c_range
	ld hl,(v_cl)
	ld de,2
	or a
	sbc hl,de
	jr nc,c_2
c_range:
	ld hl,m_crange
	call OS_PUTS
	ld hl,(v_maxc)
	call OS_DEC16
	jp OS_CRLF
c_2:	ld hl,(v_spf)		; the FAT must fit in FATBUF (3 sectors)
	ld de,4
	or a
	sbc hl,de
	jr c,c_3
	ld hl,m_bigfat
	jp OS_PUTS
c_3:	call loadfat
	ret c
	ld hl,(v_cl)
	call secof		; v_rs = the cluster's first sector
	ld hl,m_clus
	call OS_PUTS
	ld hl,(v_cl)
	call OS_DEC16
	ld hl,m_secs2
	call OS_PUTS
	ld hl,(v_rs)
	call OS_DEC16
	ld a,(v_spc)
	cp 1
	jr z,c_4
	ld a,'-'
	call OS_PUTC
	ld a,(v_spc)
	ld e,a
	ld d,0
	ld hl,(v_rs)
	add hl,de
	dec hl
	call OS_DEC16
c_4:	call OS_CRLF
	ld hl,(v_cl)
	call fatget		; HL = its FAT entry
	ld (v_val),hl
	ld hl,m_entry
	call OS_PUTS
	ld hl,(v_val)
	call hex3
	call OS_CRLF
	ld hl,(v_arg)		; a new value after the number?
	call skipsp
	ld a,(hl)
	or a
	jr nz,c_set
	jr chain_show

c_set:				; HL = the value's text
	call hexnum
	jp c,bad
	ld a,d
	cp 10h
	jp nc,bad
	ld (v_val),de
	ld hl,m_set1		; "Set the FAT entry of cluster 5 to 006h in every FAT? (Y/N) "
	call OS_PUTS
	ld hl,(v_cl)
	call OS_DEC16
	ld hl,m_set2
	call OS_PUTS
	ld hl,(v_val)
	call hex3
	ld hl,m_set3
	call OS_PUTS
	call yesno
	ret c
	ld hl,(v_cl)
	ld de,(v_val)
	call fatput
	call savefat
	ret c
	xor a
	ld (v_known),a
	ld hl,m_done
	call OS_PUTS
chain_show:
	call chain
	jp OS_CRLF

; ---- FAT12 helpers (the FAT is in FATBUF)
loadfat:			; FAT 1 -> FATBUF.  CF = failed
	ld hl,(v_spf)
	ld b,l
	ld hl,(v_res)
	ld de,FATBUF
lf_1:	push bc
	push hl
	push de
	call rdsec
	pop de
	pop hl
	pop bc
	ret c
	inc hl
	inc d
	inc d
	djnz lf_1
	or a
	ret

savefat:			; FATBUF -> every FAT.  CF = failed
	ld a,(v_nfat)
	ld c,a
	ld hl,(v_res)
sv_1:	ld a,(v_spf)
	ld b,a
	ld de,FATBUF
sv_2:	push bc
	push hl
	push de
	call wrsec
	pop de
	pop hl
	pop bc
	ret c
	inc hl
	inc d
	inc d
	djnz sv_2
	dec c
	jr nz,sv_1
	or a
	ret

fatget: 			; HL = a cluster -> HL = its 12-bit entry
	push hl
	ld d,h
	ld e,l
	srl h
	rr l
	add hl,de		; n + n/2
	ld de,FATBUF
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)		; DE = the two bytes
	pop hl
	bit 0,l
	jr nz,fg_odd
	ld a,d
	and 0Fh
	ld d,a
	ex de,hl
	ret
fg_odd: ex de,hl		; HL = the 16 bits: the entry is the high 12
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ret

fatput: 			; HL = a cluster, DE = its new 12-bit entry
	push de
	push hl
	ld d,h
	ld e,l
	srl h
	rr l
	add hl,de
	ld de,FATBUF
	add hl,de		; HL = the byte
	pop de			; DE = the cluster
	pop bc			; BC = the value
	bit 0,e
	jr nz,fp_odd
	ld (hl),c		; even: the low byte, and the low nibble of the next
	inc hl
	ld a,(hl)
	and 0F0h
	ld d,a
	ld a,b
	and 0Fh
	or d
	ld (hl),a
	ret
fp_odd: ld a,(hl)		; odd: the high nibble of this byte, and all the next
	and 0Fh
	ld d,a
	ld a,c
	and 0Fh
	rlca
	rlca
	rlca
	rlca
	or d
	ld (hl),a
	inc hl
	ld a,c			; the value >> 4
	srl b
	rra
	srl b
	rra
	srl b
	rra
	srl b
	rra
	ld (hl),a
	ret

secof:				; HL = a cluster -> v_rs = its first sector
	ld de,2
	or a
	sbc hl,de
	ld a,(v_spc)
	ld c,a
	ld b,0
	ld de,0
sc_1:	ld a,h
	or l
	jr z,sc_2
	ex de,hl
	add hl,bc
	ex de,hl
	dec hl
	jr sc_1
sc_2:	ex de,hl
	ld de,(v_data0)
	add hl,de
	ld (v_rs),hl
	ret

chain:				; "chain: 5 6 7 end" from v_cl
	ld hl,m_chain
	call OS_PUTS
	ld hl,(v_cl)
	ld b,40 		; (a loop of clusters stops after 40)
ch_1:	push bc
	push hl
	call OS_DEC16
	call space
	pop hl
	call fatget
	pop bc
	ld a,h			; 0: free; FF7: bad; FF8-FFF: the end
	or l
	jr z,ch_free
	ld de,0FF7h
	push hl
	or a
	sbc hl,de
	pop hl
	jr z,ch_bad
	jr nc,ch_end
	ld de,(v_maxc)		; a link outside the disk
	push hl
	inc de
	or a
	sbc hl,de
	pop hl
	jr nc,ch_inv
	ld de,2
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,ch_inv
	djnz ch_1
	ld hl,m_more
	jp OS_PUTS
ch_free:
	ld hl,m_free
	jp OS_PUTS
ch_bad: ld hl,m_badc
	jp OS_PUTS
ch_end: ld hl,m_end2
	jp OS_PUTS
ch_inv: ld hl,m_inv
	jp OS_PUTS

hex3:				; HL (0-FFF) as three hex digits and an h
	ld a,h
	and 0Fh
	add a,'0'
	cp '9'+1
	jr c,h3_1
	add a,7
h3_1:	call OS_PUTC
	ld a,l
	call OS_HEX8
	ld a,'h'
	jp OS_PUTC

; ---------------------------------------------------------------- text
m_hello:  defm "ampDOS disk editor.  ? lists the commands, Q quits.  Sector and cluster"
	  defb 13,10
	  defm "numbers are decimal, offsets and bytes hex.  Nothing is written until W."
	  defb 13,10,0
m_use:	  defm "DISKED [A: | B:]"
	  defb 13,10,0
m_prompt: defm "> "
	  defb 0
m_what:   defm "? (type ? for the commands)"
	  defb 13,10,0
m_bad:	  defm "bad argument (? lists the commands)"
	  defb 13,10,0
m_no:	  defm "N"
	  defb 13,10,0
m_disc:   defm "The buffer has changes that are not written.  Throw them away? (Y/N) "
	  defb 0
m_range:  defm "Sectors are 0 to 719."
	  defb 13,10,0
m_off:	  defm "Offsets are 0 to 1FF (hex)."
	  defb 13,10,0
m_end:	  defm "That is the last sector."
	  defb 13,10,0
m_first:  defm "That is the first sector."
	  defb 13,10,0
m_full:   defm "Past the end of the sector."
	  defb 13,10,0
m_rderr:  defm "Cannot read that sector (no disk, or a bad one)."
	  defb 13,10,0
m_wrerr:  defm "Cannot write that sector (write protected? no disk?)."
	  defb 13,10,0
m_nofs:   defm "(the file system cannot use this disk: "
	  defb 0
m_sector: defm "Sector "
	  defb 0
m_drive:  defm " (drive "
	  defb 0
m_close:  defm "): "
	  defb 0
m_nolay:  defm "layout unknown (sector 0 is not a FAT12 boot sector)"
	  defb 0
m_boot:   defm "boot sector"
	  defb 0
m_resv:   defm "reserved sectors"
	  defb 0
m_fat:	  defm "FAT "
	  defb 0
m_root:   defm "root directory, entries "
	  defb 0
m_to:	  defm "-"
	  defb 0
m_clus:   defm "cluster "
	  defb 0
m_secof:  defm ", sector "
	  defb 0
m_of:	  defm " of "
	  defb 0
m_wr1:	  defm "Write the buffer to sector "
	  defb 0
m_drive2: defm " of drive "
	  defb 0
m_wr2:	  defm "? (Y/N) "
	  defb 0
m_done:   defm "Done."
	  defb 13,10,0
m_bhead:  defm "The buffer as a boot sector (offset in hex; E changes a field):"
	  defb 13,10,0
m_mhead:  defm "Sectors of this disk:"
	  defb 13,10,0
m_rootl:  defm "root directory, "
	  defb 0
m_entr:   defm " entries"
	  defb 13,10,0
m_datal:  defm "data, clusters 2-"
	  defb 0
m_clr:	  defm ", "
	  defb 0
m_secs:   defm " sectors each"
	  defb 13,10,0
m_crange: defm "Clusters are 2 to "
	  defb 0
m_bigfat: defm "The FAT is too big for DISKED (3 sectors at most)."
	  defb 13,10,0
m_secs2:  defm ": sectors "
	  defb 0
m_entry:  defm "  FAT entry "
	  defb 0
m_set1:   defm "Set the FAT entry of cluster "
	  defb 0
m_set2:   defm " to "
	  defb 0
m_set3:   defm " in every FAT? (Y/N) "
	  defb 0
m_chain:  defm "  chain: "
	  defb 0
m_more:   defm "..."
	  defb 0
m_free:   defm "(free)"
	  defb 0
m_badc:   defm "(bad cluster)"
	  defb 0
m_end2:   defm "(end)"
	  defb 0
m_inv:	  defm "(not a cluster of this disk)"
	  defb 0
m_help:   defm "R [n]        read sector n (0-719, decimal) and show it; alone: again"
	  defb 13,10
	  defm "+  -          the next / the previous sector"
	  defb 13,10
	  defm "D [a [b]]     dump the buffer (hex offsets); alone: the next 256 bytes"
	  defb 13,10
	  defm "E a [bytes]   change bytes: hex or "
	  defb 22h
	  defm "text"
	  defb 22h
	  defm "; alone: asks line by line"
	  defb 13,10
	  defm "F a b byte    fill     W [n]  write the buffer to sector n (alone: this one)"
	  defb 13,10
	  defm "B             the buffer as a boot sector, field by field"
	  defb 13,10
	  defm "M             the sector map: boot, FATs, root, data"
	  defb 13,10
	  defm "C n [v]       cluster n: sectors, chain; with v (hex) set its FAT entry"
	  defb 13,10
	  defm "A: B:         use that drive          Q  quit"
	  defb 13,10,0
