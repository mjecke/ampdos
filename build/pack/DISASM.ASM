; ==========================================================================
; DISASM.ASM - DISASM: disassemble a program file.  Run as
;
;   DISASM file [out] [/O:addr] [/S:addr] [/E:addr] [/D:a-b] [/A]
;
;   file     the program (a .BIN, a ROM image, any file of Z80 code)
;   out      a file for the text; without it the text goes to the screen
;   /O:addr  the address the file's first byte belongs to (default 8000)
;   /S:addr  start listing at this address      (default: the origin)
;   /E:addr  stop after this address            (default: the end of the file)
;   /D:a-b   addresses a to b are data, not code: shown as DB lines
;            (up to 6 of them, e.g. /D:8073-80FF /D:9000-90FF)
;   /A       assembler source instead of a listing: ORG, labels (Lxxxx) at
;            every address that jumps, calls or loads point to, and the data
;            with its text in comments.  The default is a listing:
;                8000  3E 41        LD A,41h
;   All addresses are hex, as the program sees them.
;
; The file is read into memory above the program (what fits: about 20 KB;
; /S picks another part of a bigger file), a bitmap marks the addresses that get labels, and then the
; text is made.  A source with labels takes two passes: the first one only
; finds the labels.  Esc stops, any other key pauses.
; The instructions are decoded by the same code as MON's U (DISCORE.ASM).
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"

; ---- memory: the program from 8000h, its variables from DV, the file after
DV:	  equ 9A00h
BUF:	  equ 0A000h		; the label bitmap, then the file
OBUF:	  equ 9C00h		; 512 bytes of text on its way to the output file
OBUFHI:   equ 9Eh		; (the high byte of the end of OBUF)
DSTACK:   equ 0A000h		; the stack grows down from here (9E00-9FFF)

v_dstart: equ DV+00h
v_dpc:	  equ DV+02h
v_dpt:	  equ DV+04h
v_didx:   equ DV+06h
v_dmem:   equ DV+07h
v_dop:	  equ DV+08h
v_dx:	  equ DV+09h
v_dy:	  equ DV+0Ah
v_dz:	  equ DV+0Bh
v_dp:	  equ DV+0Ch
v_dq:	  equ DV+0Dh
v_ddv:	  equ DV+0Eh
v_dlen:   equ DV+0Fh
v_dbias:  equ DV+10h		; word: file buffer - first address shown
dv_sp:	  equ DV+12h		; the OS's stack
dv_o:	  equ DV+14h		; /O
dv_s:	  equ DV+16h		; /S
dv_e:	  equ DV+18h		; /E
dv_hs:	  equ DV+1Ah		; 1 = /S given
dv_he:	  equ DV+1Bh		; 1 = /E given
dv_mode:  equ DV+1Ch		; 0 = listing, 1 = source (/A)
dv_nd:	  equ DV+1Dh		; how many /D regions
dv_in:	  equ DV+1Eh		; word: the file name (0 = none)
dv_out:   equ DV+20h		; word: the output name (0 = none)
dv_wp:	  equ DV+22h
dv_nx:	  equ DV+24h
dv_cap:   equ DV+26h		; room for the file
dv_bms:   equ DV+28h		; bitmap size
dv_fb:	  equ DV+2Ah		; where the file goes
dv_skip:  equ DV+2Ch
dv_want:  equ DV+2Eh
dv_n:	  equ DV+30h		; bytes of the file in memory
dv_more:  equ DV+32h		; 1 = the file goes on after them
dv_pass:  equ DV+33h		; 0 = only look for labels, 1 = write the text
dv_lab:   equ DV+34h		; 1 = use labels
dv_pc:	  equ DV+35h		; word: the address of the next item
dv_rem:   equ DV+37h		; word: bytes of the window left
dv_ilen:  equ DV+39h		; length of the item
dv_isdata: equ DV+3Ah		; 1 = the item is data
dv_per:   equ DV+3Bh		; DB bytes per line
dv_ofile: equ DV+3Ch		; 1 = writing to a file
dv_op:	  equ DV+3Dh		; word: next byte in OBUF
dv_lines: equ DV+3Fh		; word: lines written
dv_tmp:   equ DV+41h
dv_next:  equ DV+44h		; word: the address after the instruction
dv_dtab:  equ DV+48h		; 6 regions: start, end (4 bytes each)
dv_fcb:   equ DV+60h		; 16 bytes
dv_fcb2:  equ DV+70h		; 16 bytes
dv_args:  equ DV+80h		; 80 bytes: the command line
dv_line:  equ DV+0D0h		; 120 bytes: the line being made
v_dbuf:   equ DV+150h		; 64 bytes: the text of one instruction

; ---------------------------------------------------------------- start
start:	ld (dv_sp),sp		; HL = the command line
	ld sp,DSTACK
	ld de,dv_args		; keep it: the shell's buffer is not ours
	ld b,78
st_1:	ld a,(hl)
	ld (de),a
	or a
	jr z,st_2
	inc hl
	inc de
	djnz st_1
	xor a
	ld (de),a
st_2:	ld hl,8000h
	ld (dv_o),hl
	ld (dv_s),hl
	ld (dv_e),hl
	ld (v_dbias),hl
	ld hl,0
	ld (dv_in),hl
	ld (dv_out),hl
	ld (dv_lines),hl
	ld (dv_more),hl 	; (and dv_pass)
	ld (dv_hs),hl		; (and dv_he)
	ld (dv_mode),hl 	; (and dv_nd)
	ld (dv_ofile),hl
	call ar_parse
	ld hl,(dv_in)
	ld a,h
	or l
	jp z,ar_use
	ld a,(dv_hs)
	or a
	jr nz,st_3
	ld hl,(dv_o)		; no /S: from the origin
	ld (dv_s),hl
st_3:	ld a,(dv_mode)
	ld (dv_lab),a
	ld a,8			; DB lines: 8 bytes in a source, 4 in a listing
	ld (dv_per),a
	ld a,(dv_mode)
	or a
	jr nz,st_4
	ld a,4
	ld (dv_per),a
st_4:

; ---- memory for the file and the bitmap
	call OS_MEMTOP
	ld de,BUF
	or a
	sbc hl,de
	jp c,ar_nomem
	ld d,h
	ld e,l
	srl h			; A/8
	rr l
	srl h
	rr l
	srl h
	rr l
	ex de,hl
	or a
	sbc hl,de		; HL = A - A/8: what the file may take
	ld a,h
	cp 1
	jp c,ar_nomem
	ld (dv_cap),hl
	ld de,7 		; the bitmap: one bit per byte
	add hl,de
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld (dv_bms),hl
	ld de,BUF
	add hl,de
	ld (dv_fb),hl

; ---- the file: skip to /S, read what fits
	ld hl,(dv_in)
	call OS_RESOLVE
	jp c,fl_err
	ld ix,dv_fcb
	call OS_OPEN
	jp c,fl_err
	ld hl,(dv_s)
	ld de,(dv_o)
	or a
	sbc hl,de
	jp c,ar_below
	ld (dv_skip),hl
fl_skip:
	ld hl,(dv_skip)
	ld a,h
	or l
	jr z,fl_read
	ld de,(dv_cap)		; skip it in pieces that fit
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,fl_sk1
	ld h,d
	ld l,e
fl_sk1: ld b,h
	ld c,l
	ld ix,dv_fcb
	ld de,(dv_fb)
	call OS_READ
	jp c,fl_err
	ld a,b
	or c
	jp z,ar_beyond
	ld hl,(dv_skip)
	or a
	sbc hl,bc
	ld (dv_skip),hl
	jr fl_skip
fl_read:
	ld hl,(dv_cap)
	ld a,(dv_he)
	or a
	jr z,fl_rd1
	ld hl,(dv_e)		; /E: no more than up to there
	ld de,(dv_s)
	or a
	sbc hl,de
	jp c,ar_bad
	inc hl
	ld a,h
	or l
	jr z,fl_cap
	ld de,(dv_cap)
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,fl_rd1
fl_cap: ld hl,(dv_cap)
fl_rd1: ld (dv_want),hl
	ld b,h
	ld c,l
	ld ix,dv_fcb
	ld de,(dv_fb)
	call OS_READ
	jp c,fl_err
	ld (dv_n),bc
	ld a,b
	or c
	jp z,ar_empty
	ld hl,(dv_want) 	; filled all the room? is there more?
	ld de,(dv_cap)
	or a
	sbc hl,de
	jr nz,fl_nomore
	ld hl,(dv_n)
	ld de,(dv_cap)
	or a
	sbc hl,de
	jr nz,fl_nomore
	ld bc,1
	ld ix,dv_fcb
	ld de,dv_tmp
	call OS_READ
	jr c,fl_nomore
	ld a,c
	ld (dv_more),a
fl_nomore:
	ld hl,(dv_fb)		; address A is at A + (file buffer - /S)
	ld de,(dv_s)
	or a
	sbc hl,de
	ld (v_dbias),hl

; ---- the output file
	ld hl,(dv_out)
	ld a,h
	or l
	jr z,ou_none
	call OS_RESOLVE
	jp c,fl_err
	ld ix,dv_fcb2
	call OS_CREATE
	jp c,fl_err
	ld a,1
	ld (dv_ofile),a
	ld hl,OBUF
	ld (dv_op),hl
ou_none:

; ---- pass 1: the labels
	ld a,(dv_lab)
	or a
	jr z,pass2
	ld hl,(dv_bms)		; clear the bitmap
	ld b,h
	ld c,l
	dec bc
	ld hl,BUF
	ld (hl),0
	ld de,BUF+1
	ld a,b
	or c
	jr z,p1_go
	ldir
p1_go:	xor a
	ld (dv_pass),a
	call wk_reset
	call wk_walk

; ---- pass 2: the text
pass2:	ld a,1
	ld (dv_pass),a
	call wk_reset
	ld a,(dv_mode)
	or a
	jr z,p2_go
	ld hl,dv_line		; "        ORG 8000h"
	ld (v_dpt),hl
	ld b,8
p2_sp:	call dsp
	djnz p2_sp
	ld hl,s_org
	call dstr
	ld hl,(dv_s)
	call dnum16
	xor a
	call dch
	call ou_line
p2_go:	call wk_walk

; ---- the end
finish: ld a,(dv_ofile)
	or a
	jr z,fin_1
	call ou_flush
	ld ix,dv_fcb2
	call OS_CLOSE
	jp c,fl_err
	ld hl,(dv_lines)
	call OS_DEC16
	ld hl,m_lines
	call OS_PUTS
fin_1:	ld a,(dv_more)
	or a
	jr z,quit
	ld hl,m_more		; "(the file goes on: /S:xxxx)"
	call OS_PUTS
	ld hl,(dv_s)
	ld de,(dv_n)
	add hl,de
	call OS_HEX16
	ld hl,m_more2
	call OS_PUTS
quit:	call OS_HOME
	ld sp,(dv_sp)
	ret

; ---------------------------------------------------------------- errors
fl_err: call OS_ERRMSG		; A = code
	call OS_PUTS
	call OS_CRLF
	jr fail
ar_use: ld hl,m_use
	call OS_PUTS
	jr quit
ar_bad: ld hl,m_bad
	jr ar_msg
ar_nomem:
	ld hl,m_nomem
	jr ar_msg
ar_below:
	ld hl,m_below
	jr ar_msg
ar_beyond:
	ld hl,m_beyond
	jr ar_msg
ar_empty:
	ld hl,m_empty
ar_msg: call OS_PUTS
fail:	ld a,1
	call OS_STATUS
	jr quit

; ---------------------------------------------------------------- the command line
ar_parse:
	ld hl,dv_args
ar_w:	call skipsp
	ld a,(hl)
	or a
	ret z
	push hl 		; the word ends at a space or the end
ar_e:	ld a,(hl)
	or a
	jr z,ar_t
	cp ' '
	jr z,ar_t
	inc hl
	jr ar_e
ar_t:	ld a,(hl)
	or a
	jr z,ar_t1
	ld (hl),0		; (a name or a number ends with a 0)
	inc hl
ar_t1:	ld (dv_nx),hl
	pop hl
	ld a,(hl)
	cp '/'
	jr z,ar_opt
	ld de,(dv_in)		; a name: the file, then the output
	ld a,d
	or e
	jr nz,ar_n2
	ld (dv_in),hl
	jr ar_next
ar_n2:	ld de,(dv_out)
	ld a,d
	or e
	jp nz,ar_bad
	ld (dv_out),hl
ar_next:
	ld hl,(dv_nx)
	jr ar_w

ar_opt: inc hl
	ld a,(hl)
	inc hl
	and 0DFh
	cp 'A'
	jr nz,ao_1
	ld a,1
	ld (dv_mode),a
	jr ao_end
ao_1:	ld c,a
	ld a,(hl)
	cp ':'
	jr z,ao_c
	cp '='
	jr nz,ao_n
ao_c:	inc hl
ao_n:	call hex4
	jp c,ar_bad
	ld a,c
	cp 'O'
	jr nz,ao_2
	ld (dv_o),de
	jr ao_end
ao_2:	cp 'S'
	jr nz,ao_3
	ld (dv_s),de
	ld a,1
	ld (dv_hs),a
	jr ao_end
ao_3:	cp 'E'
	jr nz,ao_4
	ld (dv_e),de
	ld a,1
	ld (dv_he),a
	jr ao_end
ao_4:	cp 'D'
	jp nz,ar_bad
	ld a,(hl)		; a-b
	cp '-'
	jp nz,ar_bad
	inc hl
	push de
	call hex4
	pop bc			; BC = a, DE = b
	jp c,ar_bad
	ld a,(dv_nd)
	cp 6
	jp nc,ar_bad
	push hl
	add a,a
	add a,a
	ld l,a
	ld h,0
	push de
	ld de,dv_dtab
	add hl,de
	pop de
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	ld (hl),e
	inc hl
	ld (hl),d
	ld h,d			; b must not be before a
	ld l,e
	or a
	sbc hl,bc
	jp c,ar_bad
	ld hl,dv_nd
	inc (hl)
	pop hl
ao_end: ld a,(hl)
	or a
	jp nz,ar_bad
	jp ar_next

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

hex4:				; HL = 1 to 4 hex digits -> DE; HL after them.	CF = not that
	ld de,0
	ld b,0
h4_1:	ld a,(hl)
	call hexdig
	jr c,h4_e
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
	jr c,h4_1
	scf
	ret
h4_e:	ld a,b
	or a
	jr z,h4_bad
	or a			; (CF clear)
	ret
h4_bad: scf
	ret

; ---------------------------------------------------------------- the walk
; Goes over the window item by item: an instruction, or a few bytes of data.
; In pass 0 only dtarget does something (marks the labels); in pass 1 each
; item becomes a line (or two).

wk_reset:
	ld hl,(dv_s)
	ld (dv_pc),hl
	ld hl,(dv_n)
	ld (dv_rem),hl
	ret

wk_walk:
	ld hl,(dv_rem)
	ld a,h
	or l
	ret z
	call wk_key
	jp c,wk_stop
	call wk_indata		; A = bytes of data left here (0 = code)
	or a
	jr nz,wk_data
	ld hl,(dv_pc)
	call dis1
	ld (dv_next),hl
	ld a,(v_dlen)
	ld e,a
	ld d,0
	ld hl,(dv_rem)
	or a
	sbc hl,de
	jr nc,wk_fits
	ld a,1			; it runs past the end: a DB for the last bytes
	jr wk_data
wk_fits:
	ld (dv_rem),hl
	ld a,(v_dlen)
	ld (dv_ilen),a
	xor a
	ld (dv_isdata),a
	ld a,(dv_pass)
	or a
	call nz,em_item
	ld hl,(dv_next)
	ld (dv_pc),hl
	jr wk_walk

wk_data:			; A = how many data bytes there are in this region
	ld c,a
	ld a,(dv_per)
	cp c
	jr c,wd_1
	ld a,c
wd_1:	ld c,a			; C = bytes in this line
	ld hl,(dv_rem)
	ld a,h
	or a
	jr nz,wd_2
	ld a,l
	cp c
	jr nc,wd_2
	ld c,a
wd_2:	ld a,(dv_lab)		; a line stops before an address that has a label
	or a
	jr z,wd_3
	ld a,(dv_pass)
	or a
	jr z,wd_3
	ld b,1
wd_t:	ld a,b
	cp c
	jr nc,wd_3
	push bc
	ld hl,(dv_pc)
	ld e,b
	ld d,0
	add hl,de
	call bm_test
	pop bc
	jr nz,wd_cut
	inc b
	jr wd_t
wd_cut: ld c,b
wd_3:	ld a,c
	ld (dv_ilen),a
	ld e,a
	ld d,0
	ld hl,(dv_rem)
	or a
	sbc hl,de
	ld (dv_rem),hl
	ld a,1
	ld (dv_isdata),a
	ld a,(dv_pass)
	or a
	jr z,wd_adv
	call wk_dtext
	call em_item
wd_adv: ld a,(dv_ilen)
	ld e,a
	ld d,0
	ld hl,(dv_pc)
	add hl,de
	ld (dv_pc),hl
	jp wk_walk

wk_stop:
	ld hl,m_stop
	call OS_PUTS
	jp finish

wk_key: 			; a key pressed? Esc: CF.  Another key pauses until one more
	call OS_KBHIT
	jr nz,wky_1
	or a
	ret
wky_1:	call OS_GETC
	cp 1Bh
	jr z,wky_esc
	call OS_GETC
	cp 1Bh
	jr z,wky_esc
	or a
	ret
wky_esc:
	scf
	ret

wk_indata:			; -> A = bytes (1..255) of a /D region from the address, or 0
	ld a,(dv_nd)
	or a
	ret z
	ld b,a
	ld ix,dv_dtab
wi_1:	ld hl,(dv_pc)
	ld e,(ix+0)
	ld d,(ix+1)
	or a
	sbc hl,de
	jr c,wi_n		; before it
	ld hl,(dv_pc)
	ld e,(ix+2)
	ld d,(ix+3)
	ex de,hl		; HL = the end, DE = the address
	or a
	sbc hl,de
	jr c,wi_n		; after it
	ld a,h
	or a
	jr nz,wi_big
	ld a,l
	cp 255
	ret nc
	inc a
	ret
wi_big: ld a,255
	ret
wi_n:	ld de,4
	add ix,de
	djnz wi_1
	xor a
	ret

wk_dtext:			; the text "DB 41h,42h" for dv_ilen bytes at dv_pc
	ld hl,v_dbuf
	ld (v_dpt),hl
	ld hl,s_db
	call dstr
	ld hl,(dv_pc)
	ld a,(dv_ilen)
	ld d,a
wdt_1:	call dpeek
	call dnum8
	inc hl
	dec d
	jr z,wdt_e
	call dcomma
	jr wdt_1
wdt_e:	xor a
	jp dch

dpeek:				; HL = an address -> A = the byte there (keeps the rest)
	push hl
	push de
	ld de,(v_dbias)
	add hl,de
	ld a,(hl)
	pop de
	pop hl
	ret

; ---------------------------------------------------------------- labels
; The bitmap at BUF has a bit for each byte of the window.

bm_pos: 			; HL = offset -> HL = the byte's address, A = the bit
	push bc
	push de
	ld a,l
	and 7
	ld b,a
	inc b
	xor a
	scf
bp_1:	rla
	djnz bp_1
	ld c,a
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld de,BUF
	add hl,de
	ld a,c
	pop de
	pop bc
	ret

bm_set: 			; HL = offset
	call bm_pos
	or (hl)
	ld (hl),a
	ret

bm_test:			; HL = an address -> NZ = it has a label.  Keeps DE.
	push de
	ld de,(dv_s)
	or a
	sbc hl,de
	jr c,bt_no
	ld de,(dv_n)
	push hl
	or a
	sbc hl,de
	pop hl
	jr nc,bt_no
	call bm_pos
	and (hl)
	pop de
	ret
bt_no:	xor a
	pop de
	ret

dtarget:			; (called by the disassembler) HL = an address in an operand
	push de
	call dt_do
	pop de
	ret

dt_do:	ld a,(dv_lab)
	or a
	jp z,dnum16
	push hl
	ld de,(dv_s)
	or a
	sbc hl,de		; its place in the window
	jr c,dt_out
	push hl
	ld de,(dv_n)
	or a
	sbc hl,de
	pop hl
	jr nc,dt_out
	ld a,(dv_pass)
	or a
	call z,bm_set		; pass 1: mark it
	pop hl
	ld a,'L'
	call dch
	jp dlabel_hex
dt_out: pop hl
	jp dnum16

dlabel_hex:			; HL: four hex digits
	ld a,h
	call dhex2
	ld a,l
	jp dhex2

; ---------------------------------------------------------------- the output
; em_item: the item at dv_pc (dv_ilen bytes; its text is in v_dbuf) as a line.

em_item:
	ld a,(dv_lab)
	or a
	jr z,em_1
	ld hl,(dv_pc)		; a label line first
	call bm_test
	jr z,em_1
	ld hl,dv_line
	ld (v_dpt),hl
	ld a,'L'
	call dch
	ld hl,(dv_pc)
	call dlabel_hex
	ld a,':'
	call dch
	xor a
	call dch
	call ou_line
em_1:	ld hl,dv_line
	ld (v_dpt),hl
	ld a,(dv_mode)
	or a
	jr nz,em_src
	ld hl,(dv_pc)		; "8000  3E 41        LD A,41h"
	call dlabel_hex
	call dsp
	call dsp
	ld hl,(dv_pc)
	ld a,(dv_ilen)
	ld c,a
	ld d,4
em_b:	ld a,c
	or a
	jr z,em_pad
	call dpeek
	call dhex2
	call dsp
	inc hl
	dec c
	jr em_n
em_pad: call dsp
	call dsp
	call dsp
em_n:	dec d
	jr nz,em_b
	call dsp
	ld hl,v_dbuf
	call dstr
	jr em_end
em_src: ld b,8
em_s1:	call dsp
	djnz em_s1
	ld hl,v_dbuf
	call dstr
	ld a,(dv_isdata)	; data: its text as a comment
	or a
	jr z,em_end
	ld hl,s_cmt
	call dstr
	ld hl,(dv_pc)
	ld a,(dv_ilen)
	ld c,a
em_t:	call dpeek
	cp 20h
	jr c,em_dot
	cp 7Fh
	jr c,em_ch
em_dot: ld a,'.'
em_ch:	call dch
	inc hl
	dec c
	jr nz,em_t
em_end: xor a
	call dch
	call ou_line
	ld a,(dv_lab)		; labels in the middle of this item
	or a
	ret z
	ld a,(dv_ilen)
	cp 2
	ret c
	ld b,1
em_m:	push bc
	ld hl,(dv_pc)
	ld e,b
	ld d,0
	add hl,de
	push hl
	call bm_test
	pop hl
	jr z,em_mn
	ld a,(dv_ilen)		; "L8002:  EQU $-2"
	pop bc
	push bc
	sub b
	ld c,a
	push bc
	push hl
	ld hl,dv_line
	ld (v_dpt),hl
	ld a,'L'
	call dch
	pop hl
	call dlabel_hex
	ld hl,s_equ
	call dstr
	pop bc
	ld a,c
	add a,'0'
	call dch
	xor a
	call dch
	call ou_line
em_mn:	pop bc
	inc b
	ld a,(dv_ilen)
	cp b
	jr nz,em_m
	ret

ou_line:			; the line in dv_line: to the screen or the file
	ld hl,(dv_lines)
	inc hl
	ld (dv_lines),hl
	ld hl,dv_line
	ld a,(dv_ofile)
	or a
	jr nz,ou_f
	call OS_PUTS
	jp OS_CRLF
ou_f:	ld a,(hl)
	or a
	jr z,ou_f2
	call ou_put
	inc hl
	jr ou_f
ou_f2:	ld a,13
	call ou_put
	ld a,10

ou_put: 			; A = a byte for the output file (keeps all but A)
	push hl
	ld hl,(dv_op)
	ld (hl),a
	inc hl
	ld (dv_op),hl
	ld a,h
	cp OBUFHI		; the buffer is full: write it
	call z,ou_flush
	pop hl
	ret

ou_flush:			; write what is in OBUF
	push hl
	push de
	push bc
	ld hl,(dv_op)
	ld de,OBUF
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ld a,b
	or c
	jr z,of_done
	ld ix,dv_fcb2
	call OS_WRITE
	jp c,of_err
of_done:
	ld hl,OBUF
	ld (dv_op),hl
	pop bc
	pop de
	pop hl
	ret

of_err: call OS_ERRMSG		; the output file could not be written (a full disk?)
	call OS_PUTS
	call OS_CRLF
	ld ix,dv_fcb2		; (close it as far as it got)
	call OS_CLOSE
	ld hl,m_chk
	call OS_PUTS
	jp fail

; ---------------------------------------------------------------- the texts
s_org:	defm "ORG "
	defb 0
s_cmt:	defm "   ; "
	defb 0
s_equ:	defm ":  EQU $-"
	defb 0

m_use:	defm "DISASM file [out] [/O:addr] [/S:addr] [/E:addr] [/D:a-b] [/A]"
	defb 13,10
	defm "  file    the program to disassemble       out  a file for the text"
	defb 13,10
	defm "  /O:     the address of the file's first byte (default 8000)"
	defb 13,10
	defm "  /S: /E: first and last address to show"
	defb 13,10
	defm "  /D:a-b  those addresses are data (DB lines); up to 6 of them"
	defb 13,10
	defm "  /A      assembler source with labels (default: a listing)"
	defb 13,10
	defm "All numbers are hex.  Esc stops, any other key pauses."
	defb 13,10,0
m_bad:	defm "bad argument (DISASM alone shows the options)"
	defb 13,10,0
m_nomem: defm "not enough memory"
	defb 13,10,0
m_below: defm "/S is below the origin /O"
	defb 13,10,0
m_beyond: defm "the file ends before the start address"
	defb 13,10,0
m_empty: defm "nothing to disassemble there"
	defb 13,10,0
m_lines: defm " lines written"
	defb 13,10,0
m_stop: defm "stopped"
	defb 13,10,0
m_chk:	defm "(the output file is incomplete)"
	defb 13,10,0
m_more: defm "(the file goes on: /S:"
	defb 0
m_more2: defm " shows the rest)"
	defb 13,10,0

	include "PROGRAMS/DISCORE.ASM"
