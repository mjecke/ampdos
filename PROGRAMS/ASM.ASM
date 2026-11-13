; ==========================================================================
; ASM.ASM - ASM: a Z80 assembler.  Run as
;
;   ASM source [output]
;
;   source   the program's text, e.g. PROGRAMS/HELLO.ASM
;   output   the binary to write (default: the source's name with .BIN,
;            in the current directory)
;
; It takes the language the ampDOS sources are written in (z80asm's), so
; ampDOS can assemble its own programs and itself:
;   name:  equ / org / defb (db) / defm (dm) / defw (dw) / defs (ds)
;          include "file" / incbin "file" / if expr ... else ... endif
;   all the Z80 instructions, the IX/IY ones, and SLL and IXH/IXL/IYH/IYL
;   numbers 123, 0FFh, $FF, 0x1F, 101b, 17o; 'c' (a character); $ = here
;   operators + - * / % << >> & ^ | ~ and ( ), with C's precedence
;   strings "text" with \\ \" \' \n \r \t \0
; Mnemonics and registers may be in either case; names (labels) are
; case-sensitive.  A label is a name followed by a colon; "name equ x" also
; works at the start of a line.  File names in include and incbin are from
; the current directory, e.g. "KERNEL/INC/OS.INC", and are cut to 8.3 the
; way DOS cuts them (BANNER.ASM is CMD_BANN.ASM on the disk).
;
; How it works: two passes over the source.  Pass 1 reads everything and
; notes the address of each label; pass 2 reads it all again and writes the
; bytes, now that every name has a value.  An EQU whose value uses a label
; further down gets its value in pass 2 (it may then be used only after its
; line).  ORG, DEFS and IF must be able to work out their values in pass 1.
;
; Errors are shown with the file, the line number and the line; there is no
; output file if there was an error.  Esc stops.
;
; Memory: the program at 8000h, its variables and buffers at AV, the symbol
; table from SYMS up to OS_MEMTOP: 20 KB (ampDOS itself needs 17 KB: 1600
; names).
; A symbol takes 4 bytes + its name.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

AV:	 equ 9C00h		; the variables (the program ends below here)
LINE:	 equ AV+100h		; 256: the line being assembled
OBUF:	 equ AV+200h		; 1 KB: bytes on their way to the output file
OBSIZE:  equ 400h		; (big: each write into the cached track sends it to the disk
OBEND:	 equ OBUF+OBSIZE	;  when a source is read from another track)
HASH:	 equ AV+600h		; 512: 256 chains of symbols (by a hash of the name)
INCS:	 equ AV+800h		; 6 x 64: the files being read (0 = the source)
IBUF:	 equ AV+980h		; 6 x 128: their buffers
STKTOP:  equ AV+0F00h		; our stack: AV+0C80h .. AV+0EFFh
SYMS:	 equ AV+0F00h		; the symbol table grows up from here
MAXINC:  equ 6
IBSIZE:  equ 128

; one file being read (64 bytes)
IR_FCB:   equ 0 		 ; 16: its FCB
IR_PTR:   equ 16		 ; word: the next byte in its buffer
IR_LEFT:  equ 18		 ; byte: bytes left in the buffer
IR_EOF:   equ 19		 ; byte: 1 = the file has no more
IR_LINE:  equ 20		 ; word: the line number
IR_BUF:   equ 22		 ; word: its buffer
IR_NAME:  equ 24		 ; 39: its name, as opened
IR_DRV:   equ 63		 ; byte: its drive: 'A', 'B', or '@' = the current one
IR_LEN:   equ 64

; one symbol: next (word: the next in its chain, 0 = none), value (word),
; the name (the last character has bit 7 set)

; ---- variables
v_sp:	 equ AV+00h		; word: the shell's stack
v_pass:  equ AV+02h		; 1 or 2
v_pc:	 equ AV+03h		; word: $, the address of the next byte
v_lpc:	 equ AV+05h		; word: $ at the start of the line
v_size:  equ AV+07h		; word: bytes made
v_errs:  equ AV+09h		; word: errors
v_lev:	 equ AV+0Bh		; word: the file being read now (INCS + n * 64)
v_depth: equ AV+0Dh		; byte: 0 = the source itself, 1 = an include in it ...
v_skip:  equ AV+0Eh		; byte: 0 = assembling; n = inside n IFs being skipped
v_ifn:	 equ AV+0Fh		; byte: IFs open
v_undef: equ AV+10h		; byte: 1 = the last expression used an undefined name
v_linesp: equ AV+11h		; word: the stack at the start of the line (to skip it)
v_symtop: equ AV+13h		; word: the end of the symbol table
v_memtop: equ AV+15h		; word: OS_MEMTOP
v_nsym:  equ AV+17h		; word: symbols
v_op:	 equ AV+19h		; word: the next byte in OBUF
v_pfx:	 equ AV+1Bh		; byte: DDh / FDh: the instruction uses IX / IY
v_disp:  equ AV+1Ch		; byte: its (IX+d) displacement ...
v_hasd:  equ AV+1Dh		; byte: ... if it has one
v_nops:  equ AV+1Eh		; byte: how many operands
v_src:	 equ AV+1Fh		; word: the source's name
v_lab:	 equ AV+21h		; word: the line's label: where its name starts ...
v_labn:  equ AV+23h		; byte: ... its length ...
v_labh:  equ AV+24h		; byte: ... its hash
v_haslab: equ AV+25h		; byte: 1 = the line has a label
v_tmp:	 equ AV+26h		; word
v_txt:	 equ AV+28h		; word: the text pointer while an operator is worked out
v_ofile: equ AV+2Ah		; byte: 1 = the output file is open
v_first: equ AV+2Bh		; byte: 1 = no byte made yet
v_start: equ AV+2Ch		; word: the address of the first byte
v_en:	 equ AV+2Eh		; byte: a name to show after the error message: its length ...
v_ep:	 equ AV+2Fh		; word: ... and where it is
v_e1:	 equ AV+31h		; word: errors pass 1 found
v_cdrv:  equ AV+33h		; byte: the drive mounted now (as IR_DRV)
v_odrv:  equ AV+34h		; byte: the output's drive
O1:	 equ AV+40h		; the first operand (8 bytes) ...
O2:	 equ AV+48h		; ... and the second
v_ofcb:  equ AV+50h		; 16: the output file's FCB
v_out:	 equ AV+60h		; 64: the output file's name
v_args:  equ AV+0A0h		; 96: the command line

; an operand: its kind, value (word), prefix (DDh/FDh/0), displacement, has one (1)
OP_K:	 equ 0
OP_V:	 equ 1
OP_PFX:  equ 3
OP_D:	 equ 4
OP_HASD: equ 5

; ---------------------------------------------------------------- start
start:	ld (v_sp),sp		; HL = the command line
	ld sp,STKTOP
	ld de,v_args		; keep it: the shell's buffer is not ours
	ld b,95
st_1:	ld a,(hl)
	ld (de),a
	or a
	jr z,st_2
	inc hl
	inc de
	djnz st_1
	xor a
	ld (de),a
st_2:	call OS_MEMTOP
	ld (v_memtop),hl
	ld hl,0
	ld (v_errs),hl
	xor a
	ld (v_ofile),a
	ld (v_en),a
	call args
	ld hl,m_p1		; pass 1: the labels
	call OS_PUTS
	ld a,1
	call pass
	ld hl,(v_errs)
	ld (v_e1),hl
	ld a,h
	or l
	jr nz,st_p2		; errors: pass 2 only finds the rest, no output
	ld hl,v_out		; pass 2: the bytes, into the output file
	call drvof
	ld (v_odrv),a
	ld (v_cdrv),a
	call OS_RESOLVE
	jp c,ferr
	ld ix,v_ofcb
	call OS_CREATE
	jp c,ferr
	ld a,1
	ld (v_ofile),a
st_p2:	ld hl,m_p2
	call OS_PUTS
	ld a,2
	call pass
	ld a,(v_ofile)
	or a
	jr z,result
	call oflush
	call oclose

; ---- the result
result: ld hl,(v_errs)
	ld a,h
	or l
	jr nz,rs_err
	ld hl,v_out		; "HELLO.BIN: 112 bytes at 8000h, 5 symbols"
	call OS_PUTS
	ld hl,m_r1
	call OS_PUTS
	ld hl,(v_size)
	call OS_DEC16
	ld hl,m_r2
	call OS_PUTS
	ld hl,(v_start)
	call OS_HEX16
	ld hl,m_r3
	call OS_PUTS
	ld hl,(v_nsym)
	call OS_DEC16
	ld hl,m_r4
	call OS_PUTS
	jr quit
rs_err: call OS_DEC16		; "3 error(s)"
	ld hl,m_errs
	call OS_PUTS
fail:	ld a,1
	call OS_STATUS
quit:	call OS_HOME
	ld sp,(v_sp)
	ret

ferr:	call OS_ERRMSG		; A = a file error: say what, and stop
	call OS_PUTS
	call OS_CRLF
	jr fail

usage:	ld hl,m_use
	call OS_PUTS
	jr quit

; ---------------------------------------------------------------- the command line
args:	ld hl,v_args		; the source ...
	call skipsp
	or a
	jr z,usage
	ld (v_src),hl
	call ar_word
	call skipsp		; ... and the output's name
	or a
	jr z,ar_def
	ld de,v_out
	ld b,62
ar_1:	ld a,(hl)
	or a
	jr z,ar_2
	cp ' '
	jr z,ar_2
	ld (de),a
	inc hl
	inc de
	djnz ar_1
ar_2:	xor a
	ld (de),a
	ret
ar_def: ld hl,(v_src)		; no output name: the source's, with .BIN
	ld d,h
	ld e,l
ar_3:	ld a,(hl)		; DE = after the last \ / or :
	inc hl
	or a
	jr z,ar_4
	cp 5Ch
	jr z,ar_3b
	cp '/'
	jr z,ar_3b
	cp ':'
	jr nz,ar_3
ar_3b:	ld d,h
	ld e,l
	jr ar_3
ar_4:	ex de,hl
	ld de,v_out
	ld b,8
ar_5:	ld a,(hl)		; up to 8 characters of the name
	or a
	jr z,ar_6
	cp '.'
	jr z,ar_6
	call upper
	ld (de),a
	inc hl
	inc de
	djnz ar_5
ar_6:	ld hl,m_bin
	ld bc,5
	ldir
	ret
ar_word:			; zero-terminate the word at HL; HL = after it
	ld a,(hl)
	or a
	ret z
	cp ' '
	jr z,aw_1
	inc hl
	jr ar_word
aw_1:	ld (hl),0
	inc hl
	ret

; ---------------------------------------------------------------- one pass
pass:	ld (v_pass),a		; A = 1 or 2
	ld hl,0
	ld (v_pc),hl
	ld (v_lpc),hl
	ld (v_size),hl
	xor a
	ld (v_skip),a
	ld (v_ifn),a
	ld (v_depth),a
	inc a
	ld (v_first),a
	ld hl,OBUF
	ld (v_op),hl
	ld a,(v_pass)
	cp 1
	jr nz,pa_1
	ld hl,HASH		; pass 1: an empty symbol table
	ld (hl),0
	ld de,HASH+1
	ld bc,511
	ldir
	ld hl,SYMS
	ld (v_symtop),hl
	ld hl,0
	ld (v_nsym),hl
pa_1:	ld hl,INCS
	ld (v_lev),hl
	push hl
	pop ix
	ld hl,(v_src)
	call fopen
	jr nc,pa_line
	push af 		; the source itself is not there
	ld hl,m_open
	call OS_PUTS
	ld hl,(v_src)
	call OS_PUTS
	ld hl,m_dash
	call OS_PUTS
	pop af
	jp ferr
pa_line:
	call rdline		; the next line ...
	jr c,pa_eof
	call line		; ... is assembled
	jr pa_line
pa_eof: ld a,(v_depth)		; the end of an include: back to the file it is in
	or a
	jr z,pa_end
	dec a
	ld (v_depth),a
	ld hl,(v_lev)
	ld de,-IR_LEN
	add hl,de
	ld (v_lev),hl
	jr pa_line
pa_end: ld a,(v_ifn)
	or a
	ret z
	ld hl,m_noend		; IF without ENDIF
	jp err1

; ---------------------------------------------------------------- one line
line:	ld (v_linesp),sp	; (an error that ends the line comes back to here)
	ld hl,(v_pc)
	ld (v_lpc),hl
	call OS_KBHIT		; Esc (or Ctrl-C) stops
	jr z,ln_0
	call OS_GETC
	cp 1Bh
	jp z,stopped
	cp 3
	jp z,stopped
ln_0:	xor a
	ld (v_haslab),a
	ld hl,LINE
	call skipsp
	call getid		; a label?
	jr c,ln_mn
	ld a,(hl)
	cp ':'
	jr nz,ln_nocol
	inc hl
ln_lab: ld (v_lab),de		; yes: keep it
	ld a,b
	ld (v_labn),a
	ld a,c
	ld (v_labh),a
	ld a,1
	ld (v_haslab),a
	jr ln_mn
ln_nocol:			; a name at the very start without a colon: a label
	push hl 		; if EQU follows ("SIZE equ 10")
	ld hl,LINE
	or a
	sbc hl,de
	pop hl
	jr nz,ln_back
	push de
	push bc
	push hl
	call skipsp
	call getid
	jr c,ln_neq
	ld hl,s_equ
	call mncmp
	jr ln_nq
ln_neq: or 1			; (NZ: no)
ln_nq:	pop hl
	pop bc
	pop de
	jr z,ln_lab
ln_back:
	ex de,hl		; no: the name is the instruction
ln_mn:	call skipsp
	call iseos
	jr nz,ln_word
	ld a,(v_skip)		; only a label (or nothing)
	or a
	ret nz
	jp deflab
ln_word:
	call getid
	jr c,ln_junk
	push hl
	call mnlook		; A = handler, C = its value
	pop hl
	jr c,ln_unk
	ld b,a
	ld a,(v_skip)
	or a
	jr nz,ln_skip
	ld a,b
	cp HD_EQU
	jp z,d_equ		; (EQU gives the label its value, not $)
	push bc
	push hl
	call deflab
	pop hl
	pop bc
	ld a,b
	cp HD_DIR
	jr nc,ln_go		; a directive reads its own operands
	push bc
	call operands		; an instruction: its operands into O1, O2
	pop bc
	ld a,b
ln_go:	ld de,ln_end		; the handler returns through ln_end
	push de
	push hl
	add a,a 		; to the handler: A = its number, C = its value
	ld e,a
	ld d,0
	ld hl,htab
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ex (sp),hl
	ret
ln_skip:			; inside a false IF: only IF, ELSE and ENDIF count
	ld a,b
	cp HD_IF
	jp z,d_if
	cp HD_ELSE
	jp z,d_else
	cp HD_ENDIF
	jp z,d_endif
	ret
ln_unk: ld a,(v_skip)
	or a
	ret nz
	ld hl,m_unk
	jp errx
ln_junk:
	ld a,(v_skip)
	or a
	ret nz
	ld hl,m_syn
	jp errx

ln_end: 			; after a handler: the line must be over
	call skipsp
	call iseos
	ret z
	ld hl,m_extra
	jp errx

deflab: ld a,(v_haslab) 	; the line's label = $
	or a
	ret z
	ld hl,(v_lpc)
labset: ld de,(v_lab)		; HL = the value
	ld a,(v_labn)
	ld b,a
	ld a,(v_labh)
	ld c,a
	push hl
	call symfind
	jr c,dl_new
	pop de			; there already
	ld a,(v_pass)
	cp 2
	jr nz,dl_twice
	ld a,(hl)		; pass 2: it must have the value pass 1 gave it
	cp e
	jr nz,dl_phase
	inc hl
	ld a,(hl)
	cp d
	ret z
	dec hl
dl_phase:
	ld (hl),e
	inc hl
	ld (hl),d
	ld hl,(v_e1)		; (after errors in pass 1 that is no news)
	ld a,h
	or l
	ret nz
	call labname
	ld hl,m_phase
	jp err
dl_twice:
	call labname
	ld hl,m_twice
	jp err1
dl_new: pop hl
	jp symadd
labname:			; the error message is followed by the label
	ld hl,(v_lab)
	ld (v_ep),hl
	ld a,(v_labn)
	ld (v_en),a
	ret

; ---------------------------------------------------------------- reading lines
; rdline: the next line of the file being read -> LINE (zero-terminated, no
; CR or LF).  CF = the file has ended.
rdline: ld ix,(v_lev)
	ld l,(ix+IR_PTR)
	ld h,(ix+IR_PTR+1)
	ld b,(ix+IR_LEFT)
	ld de,LINE
	ld c,0			; characters in LINE
rl_1:	ld a,b
	or a
	jr z,rl_fill
	ld a,(hl)
	inc hl
	dec b
	cp 10
	jr z,rl_eol
	cp 13
	jr z,rl_1
	cp 1Ah			; Ctrl-Z: the end of a text file
	jr z,rl_cz
	ld (de),a
	ld a,c
	cp 254			; (a longer line is cut)
	jr nc,rl_1
	inc de
	inc c
	jr rl_1
rl_cz:	ld (ix+IR_EOF),1
	ld b,0
rl_fill:
	ld a,(ix+IR_EOF)
	or a
	jr nz,rl_end
	push de
	push bc
	call ctxrec		; (its drive may not be the one mounted)
	ld e,(ix+IR_BUF)
	ld d,(ix+IR_BUF+1)
	push de
	ld bc,IBSIZE
	call OS_READ
	jp c,e_read
	ld ix,(v_lev)
	pop hl			; the buffer
	ld a,c			; bytes read
	pop bc
	pop de
	ld b,a
	or a
	jr nz,rl_1
	ld (ix+IR_EOF),1
rl_end: ld a,c			; the end of the file: a last line without a LF,
	or a			; or no line at all
	scf
	ret z
rl_eol: xor a
	ld (de),a
	ld (ix+IR_PTR),l
	ld (ix+IR_PTR+1),h
	ld (ix+IR_LEFT),b
	ld l,(ix+IR_LINE)
	ld h,(ix+IR_LINE+1)
	inc hl
	ld (ix+IR_LINE),l
	ld (ix+IR_LINE+1),h
	or a
	ret

; fopen: IX = a file record, HL = the name (ends with 0 or ").  Opens it for
; reading.  CF = failed, A = the error.
fopen:	push ix
	pop de
	ld a,IR_NAME
	add a,e
	ld e,a
	jr nc,fo_1
	inc d
fo_1:	call name83		; the name, cut to 8.3 -> the record
	push ix 		; its buffer: IBUF + (record - INCS) * 2
	pop hl
	ld de,INCS
	or a
	sbc hl,de
	add hl,hl
	ld de,IBUF
	add hl,de
	ld (ix+IR_BUF),l
	ld (ix+IR_BUF+1),h
	xor a
	ld (ix+IR_LEFT),a
	ld (ix+IR_EOF),a
	ld (ix+IR_LINE),a
	ld (ix+IR_LINE+1),a
	push ix
	pop hl
	ld de,IR_NAME
	add hl,de
	call drvof		; its drive
	ld (ix+IR_DRV),a
	ld (v_cdrv),a
	push hl
	push ix
	call OS_FLUSH		; (the output so far: going to another directory reads
	pop ix			;  the disk's FAT again)
	pop hl
	jr c,fo_err
	push ix
	call OS_RESOLVE
	pop ix
	jr c,fo_err
	push ix
	call OS_OPEN
	pop ix
	ret nc
fo_err: scf
	ret

; name83: HL = a name, maybe with a path (ends with 0, " or a space) -> DE: the same,
; upper case, each part cut to 8.3 ("KERNEL/CMD/BANNER.ASM" ->
; "KERNEL/SHELL/CMD_BANN.ASM").  At most 38 characters.
name83: ld b,38
	ld c,8			; characters this part may still take
n8_1:	ld a,(hl)
	or a
	jr z,n8_end
	cp '"'
	jr z,n8_end
	cp ' '
	jr z,n8_end
	inc hl
	cp '/'
	jr z,n8_sep
	cp 5Ch
	jr z,n8_sep
	cp ':'
	jr z,n8_sep
	cp '.'
	jr z,n8_dot
	inc c
	dec c
	jr z,n8_1		; no room left in this part: dropped
	dec c
	call upper
n8_put: ld (de),a
	inc de
	djnz n8_1
n8_end: xor a
	ld (de),a
	ret
n8_sep: ld c,8			; a new part: 8 for its name
	jr n8_put
n8_dot: ld c,3			; and 3 for the extension
	jr n8_put

; ---------------------------------------------------------------- output
; emit: A = the next byte.  Pass 1 only counts it; pass 2 writes it (if there
; is an output file: not after errors in pass 1).
emit:	push hl
	ld hl,(v_pc)
	inc hl
	ld (v_pc),hl
	ld hl,(v_size)
	inc hl
	ld (v_size),hl
	push af
	ld a,(v_ofile)
	or a
	jr z,em_1
	pop af
	ld hl,(v_op)
	ld (hl),a
	inc hl
	ld (v_op),hl
	push af
	ld a,h			; (OBEND is on a 256-byte boundary)
	cp OBEND >> 8
	call z,ofull
	pop af
	pop hl
	ret
em_1:	ld a,(v_first)		; where the first byte goes
	or a
	jr z,em_2
	xor a
	ld (v_first),a
	ld hl,(v_pc)
	dec hl
	ld (v_start),hl
em_2:	pop af
	pop hl
	ret

ofull:	push bc 		; OBUF is full: write it
	ld bc,OBSIZE
ow_go:	push af
	push de
	push hl
	push ix
	push iy
	ld a,(v_odrv)		; to the output's drive, if it is another one
	ld hl,v_out
	call ctxto
	ld de,OBUF
	ld (v_op),de
	ld ix,v_ofcb
	call OS_WRITE
	jp c,e_write
	pop iy
	pop ix
	pop hl
	pop de
	pop af
	pop bc
	ret
oflush: push bc 		; what is left in OBUF
	ld hl,(v_op)
	ld bc,OBUF
	or a
	sbc hl,bc
	ld b,h
	ld c,l
	ld a,b
	or c
	jr nz,ow_go
	pop bc
	ret

oclose: call OS_FLUSH		; close the output (it is found by its name again:
	ld hl,v_out		; its directory entry is in its own directory)
	ld a,(v_odrv)
	ld (v_cdrv),a
	call OS_RESOLVE
	ld ix,v_ofcb
	call OS_CLOSE
	xor a
	ld (v_ofile),a
	ld hl,(v_errs)		; no output if there were errors
	ld a,h
	or l
	ret z
	ld hl,v_out
	call OS_RESOLVE
	ret c
	jp OS_DELETE

; ---------------------------------------------------------------- drives
; The file system has one disk mounted at a time: its FAT is in memory, and
; reads and writes go to its drive.  So before a file on another drive is read
; or written, its drive is mounted again (by finding the file's name again).
; Files on one drive need none of this: the FCB is enough to read and write.

; drvof: HL = a name -> A = its drive: 'A' or 'B' if it starts with one, '@' if not
drvof:	push hl
	inc hl
	ld a,(hl)
	dec hl
	cp ':'
	ld a,'@'
	jr nz,drv_1
	ld a,(hl)
	call upper
drv_1:	pop hl
	ret

; ctxto: A = a drive (as drvof), HL = the name of a file on it: mount it if it
; is not the drive mounted now.  Keeps the registers.
ctxto:	push hl
	ld hl,v_cdrv
	cp (hl)
	pop hl
	ret z
	push af
	push bc
	push de
	push hl
	push ix
	push iy
	ld (v_cdrv),a
	push hl
	call OS_FLUSH		; (what was written to the old one goes to its disk)
	pop hl
	jp c,e_write
	call OS_RESOLVE
	jp c,e_read
	pop iy
	pop ix
	pop hl
	pop de
	pop bc
	pop af
	ret

; ctxrec: IX = a file record: mount its drive (keeps the registers but A)
ctxrec: push hl
	push de
	push ix
	pop hl
	ld de,IR_NAME
	add hl,de
	ld a,(ix+IR_DRV)
	call ctxto
	pop de
	pop hl
	ret

; ---------------------------------------------------------------- errors
; err:   HL = the message.  Shown in pass 2; the line goes on.
; err1:  the same, shown in pass 1 instead (for what pass 1 finds: each error
;        is shown once, and both passes run even after errors).
; errx, errx1: the same, and the rest of the line is skipped.
; All of them keep the registers (errx and errx1 do not come back).
; A name to show after the message: v_ep, v_en (its length) -- set them before.
err:	push af
	ld a,2
	jr er_go
err1:	push af
	ld a,1
er_go:	push hl
	ld hl,v_pass
	cp (hl)
	pop hl
	jr z,er_show
	xor a			; not in this pass
	ld (v_en),a
	pop af
	ret
er_show:
	pop af
	push af
	push bc
	push de
	push hl
	push ix
	push iy
	call report
	pop iy
	pop ix
	pop hl
	pop de
	pop bc
	pop af
	ret
errx:	ld a,(v_pass)
	cp 2
	jr ex_go
errx1:	ld a,(v_pass)
	cp 1
ex_go:	call z,report
	xor a
	ld (v_en),a
abort:	ld sp,(v_linesp)	; the rest of the line is skipped
	ret

report: push hl 		; "KERNEL/FS/MOUNT.ASM:12: bad operands"
	ld ix,(v_lev)
	push ix
	pop hl
	ld de,IR_NAME
	add hl,de
	call OS_PUTS
	ld a,':'
	call OS_PUTC
	ld l,(ix+IR_LINE)
	ld h,(ix+IR_LINE+1)
	call OS_DEC16
	ld hl,m_colon
	call OS_PUTS
	pop hl
	call OS_PUTS
	ld a,(v_en)		; a name after it?
	or a
	jr z,rp_1
	ld b,a
	ld hl,(v_ep)
rp_n:	ld a,(hl)
	call OS_PUTC
	inc hl
	djnz rp_n
	xor a
	ld (v_en),a
rp_1:	call OS_CRLF
	ld hl,m_indent		; and the line
	call OS_PUTS
	ld hl,LINE
	call OS_PUTS
	call OS_CRLF
	ld hl,(v_errs)
	inc hl
	ld (v_errs),hl
	ld a,l
	cp 25			; 25 errors are enough
	ret c
	ld hl,m_many
	call OS_PUTS
	jr stop

; fatal errors: the assembly stops
e_read: ld hl,m_rderr
	jr fatal
e_write:
	ld hl,m_wrerr
	jr fatal
e_full: ld hl,m_full
	jr fatal
stopped:
	ld hl,m_stop
	call OS_PUTS
	ld hl,(v_errs)
	inc hl
	ld (v_errs),hl
	jr stop
fatal:	call report
stop:	ld sp,STKTOP
	ld a,(v_ofile)
	or a
	call nz,oclose		; (there is an error: the output goes)
	jp result

; ---------------------------------------------------------------- texts
m_use:	defm "ASM source [output]  - assemble a Z80 source; the output is"
	defb 13,10
	defm "  the source's name with .BIN unless you name one"
	defb 13,10,0
m_p1:	defm "Pass 1"
	defb 13,10,0
m_p2:	defm "Pass 2"
	defb 13,10,0
m_bin:	defm ".BIN"
	defb 0
s_equ:	defm "EQ"
	defb 80h+'U'
m_r1:	defm ": "
	defb 0
m_r2:	defm " bytes at "
	defb 0
m_r3:	defm "h, "
	defb 0
m_r4:	defm " symbols"
	defb 13,10,0
m_errs: defm " error(s)"
	defb 13,10,0
m_open: defm "cannot open "
	defb 0
m_dash: defm ": "
	defb 0
m_colon: defm ": "
	defb 0
m_indent: defm "  "
	defb 0
m_many: defm "too many errors"
	defb 13,10,0
m_stop: defm "stopped"
	defb 13,10,0
m_rderr: defm "disk read error"
	defb 0
m_wrerr: defm "cannot write the output (disk full?)"
	defb 0
m_full: defm "out of memory for symbols"
	defb 0
m_unk:	defm "unknown instruction"
	defb 0
m_syn:	defm "syntax error"
	defb 0
m_extra: defm "unexpected text"
	defb 0
m_phase: defm "label moved between passes: "
	defb 0
m_twice: defm "defined twice: "
	defb 0
m_noend: defm "IF without ENDIF"
	defb 0

	include "PROGRAMS/ASMEXPR.ASM"
	include "PROGRAMS/ASMZ80.ASM"
