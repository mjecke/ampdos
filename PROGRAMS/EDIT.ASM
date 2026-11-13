; ==========================================================================
; EDIT.ASM - EDIT: a small line editor for text files.  Run as  EDIT name.
;
; The whole file is kept in memory, as lines ending in LF (a CR is dropped
; when reading and put back when writing, so files stay PC text files).
; Lines are numbered from 1; the "current line" is where commands work when
; no line number is given.  A command is an optional line number or range,
; then a letter:
;
;   12        go to line 12 and show it      Return   show the next 16 lines
;   -         show the 16 lines before       L        list 16 lines from here
;   5,30L     list lines 5 to 30             I        insert before this line
;   12I       insert before line 12          A        add lines at the end
;   D  5,9D   delete this line / lines 5-9   E  12E   retype this line / line 12
;   F text    find the next line holding "text"
;   R/old/new/  5,30R/a/b/   replace "old" with "new" in this line / lines 5-30
;   5,9,20C   copy lines 5-9 to before line 20     5,9,20M   move them there
;   T name  20T name   read a file in, before this line / line 20
;   W  write the file   Q  quit   X  write and quit   H or ?  this help
; In a line number "." means the current line and "$" the last one.
; While inserting, a line holding only "." stops.  Esc stops a long listing.
;
; Memory: the program, then the text up to ED_TOP, then the variables.
; Only the OS call table is used (KERNEL/INC/OS.INC), so EDIT runs on any ampdos.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

ED_TOP:   equ 0FA00h		; the text ends below this (some 28 KB)
ED_PAGE:  equ 16		; lines per page
ED_WIDTH: equ 120		; longest line that can be typed

ed_end:   equ 0FA00h		; word: one past the last byte of text
ed_cur:   equ 0FA02h		; word: current line
ed_dirty: equ 0FA04h		; 1 = changed since the last write
ed_a:	  equ 0FA06h		; word: first line number given
ed_b:	  equ 0FA08h		; word: second line number given
ed_nnum:  equ 0FA0Ah		; how many numbers were given (0, 1 or 2)
ed_sp:	  equ 0FA0Ch		; word: the stack pointer at the start
ed_ptr:   equ 0FA0Eh		; word: where the command parser is
ed_fcb:   equ 0FA10h		; 16 bytes: the file
ed_name:  equ 0FA20h		; 16 bytes: its name
ed_line:  equ 0FA40h		; 128 bytes: a typed line
ed_out:   equ 0FAC0h		; 64 bytes: what is being written
ED_OUTN:  equ 64
ed_outn:  equ 0FB00h		; bytes in ed_out
ed_cnt:   equ 0FB02h		; word: a counter
ed_shown: equ 0FB04h		; 1 = the current line has been shown (Return goes on after it)
ed_c:	  equ 0FB06h		; word: a third number (C, M)
ed_src:   equ 0FB08h		; word: C, M: where the lines are
ed_dst:   equ 0FB0Ah		; word: where they go
ed_len:   equ 0FB0Ch		; word: their length
ed_nch:   equ 0FB0Eh		; word: R: lines changed
ed_old:   equ 0FB10h		; 64 bytes: R: the text to replace
ed_new:   equ 0FB50h		; 64 bytes: and what replaces it
ed_arg:   equ 0FB90h		; 64 bytes: the file name as given (T comes back to its directory)
ed_tfcb:  equ 0FBD0h		; 16 bytes: T: the file read in

start:	ld (ed_sp),sp
	ld a,(hl)		; HL = the arguments: the file name
	or a
	jr nz,ed_s0
	ld hl,m_use
	jp OS_PUTS
ed_s0:	push hl 		; (its memory is the TPA's top: not while output
	call OS_MEMTOP		;  goes to a file)
	ld de,TPA_TOP
	or a
	sbc hl,de
	pop hl
	jr z,ed_s0a
	ld hl,m_redir
	jp OS_PUTS
ed_s0a: push hl 		; keep the name as given
	ld de,ed_arg
	ld b,63
ed_sa:	ld a,(hl)
	ld (de),a
	or a
	jr z,ed_sb
	cp ' '
	jr z,ed_sb
	inc hl
	inc de
	djnz ed_sa
ed_sb:	xor a
	ld (de),a
	pop hl
ed_s1:	call OS_RESOLVE 	; [d:][path\]name: its drive and directory
	jp c,ed_oserr
	ld de,ed_name		; keep the name (the command line will be reused)
	ld b,15
ed_s2:	ld a,(hl)
	or a
	jr z,ed_s3
	cp ' '
	jr z,ed_s3
	ld (de),a
	inc hl
	inc de
	djnz ed_s2
ed_s3:	xor a
	ld (de),a
	ld hl,text
	ld (ed_end),hl
	ld hl,1
	ld (ed_cur),hl
	xor a
	ld (ed_dirty),a
	ld (ed_shown),a
	call ed_load
	jp c,ed_oserr

; ---------------------------------------------------------------- commands
ed_loop:
	call OS_CRLF
	ld a,'*'
	call OS_PUTC
	ld hl,ed_line
	ld b,ED_WIDTH
	call OS_GETLINE
	ld hl,ed_line
	ld (ed_ptr),hl
	call ed_range		; numbers in front
	jr c,ed_bad
	call ed_skip
	ld a,(hl)
	inc hl
	ld (ed_ptr),hl
	and 0DFh		; upper case (and 0 stays 0)
	jr z,ed_nocmd
	ld hl,ed_cmds
ed_l1:	cp (hl) 		; find the letter in the table
	inc hl
	jr z,ed_l2
	inc hl
	inc hl
	bit 7,(hl)		; (the table ends with FFh)
	jr z,ed_l1
	ld a,(ed_line)		; "-" and "?" are not letters
	cp '-'
	jr nz,ed_l1a
	call ed_back
	jr ed_loop
ed_l1a: cp '?'
	jr nz,ed_bad
	call ed_help
	jr ed_loop
ed_bad: ld hl,m_what
	call OS_PUTS
	jr ed_loop
ed_l2:	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call ed_jphl
	jr ed_loop
ed_jphl:
	jp (hl)
ed_nocmd:			; just a number: go there; nothing: next page
	ld a,(ed_nnum)
	or a
	jr nz,ed_nc1
	call ed_next		; (ed_next ends with RET: call it)
	jp ed_loop
ed_nc1: call ed_line1		; ed_a must be a line
	jr c,ed_loop
	ld hl,(ed_a)
	ld (ed_cur),hl
	call ed_show
	jp ed_loop

ed_cmds:
	defb 'L'
	defw ed_list
	defb 'I'
	defw ed_ins
	defb 'A'
	defw ed_app
	defb 'D'
	defw ed_del
	defb 'E'
	defw ed_edit
	defb 'F'
	defw ed_find
	defb 'W'
	defw ed_write
	defb 'Q'
	defw ed_quit
	defb 'X'
	defw ed_exit
	defb 'H'
	defw ed_help
	defb 'R'
	defw ed_repl
	defb 'C'
	defw ed_copy
	defb 'M'
	defw ed_move
	defb 'T'
	defw ed_tran
	defb 0FFh

; ---------------------------------------------------------------- parsing
ed_range:			; [n[,m]] -> ed_a, ed_b, ed_nnum.  CF = bad
	xor a
	ld (ed_nnum),a
	call ed_num
	ret c
	ret z			; no number
	ld (ed_a),hl
	ld (ed_b),hl
	ld a,1
	ld (ed_nnum),a
	call ed_skip
	ld a,(hl)
	cp ','
	jr nz,ed_r1
	inc hl
	ld (ed_ptr),hl
	call ed_num
	ret c
	scf
	ret z			; "5," with nothing after it
	ld (ed_b),hl
	ld a,2
	ld (ed_nnum),a
	call ed_skip		; a third (C, M)
	ld a,(hl)
	cp ','
	jr nz,ed_r1
	inc hl
	ld (ed_ptr),hl
	call ed_num
	ret c
	scf
	ret z
	ld (ed_c),hl
	ld a,3
	ld (ed_nnum),a
ed_r1:	or a
	ret

ed_num: 			; a number at ed_ptr -> HL.  Z = none, CF = bad
	call ed_skip
	ld a,(hl)
	cp '.'
	jr z,ed_n_dot
	cp '$'
	jr z,ed_n_last
	sub '0'
	cp 10
	jr nc,ed_n_none
	ld de,0
ed_n1:	ld a,(hl)
	sub '0'
	cp 10
	jr nc,ed_n2
	inc hl
	push hl
	ld h,d			; DE = DE * 10 + digit
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	add hl,hl
	ld e,a
	ld d,0
	add hl,de
	ex de,hl
	pop hl
	jr ed_n1
ed_n2:	ld (ed_ptr),hl
	ex de,hl
	jr ed_n_got
ed_n_dot:
	inc hl
	ld (ed_ptr),hl
	ld hl,(ed_cur)
	jr ed_n_got
ed_n_last:
	inc hl
	ld (ed_ptr),hl
	call ed_count
ed_n_got:
	ld a,1			; NZ, NC
	or a
	ret
ed_n_none:
	xor a			; Z, NC
	ret

ed_skip:			; HL = ed_ptr past spaces
	ld hl,(ed_ptr)
ed_sk1: ld a,(hl)
	cp ' '
	jr nz,ed_sk2
	inc hl
	jr ed_sk1
ed_sk2: ld (ed_ptr),hl
	ret

ed_defs:			; no numbers given: ed_a = ed_b = the current line
	ld a,(ed_nnum)
	or a
	ret nz
	ld hl,(ed_cur)
	ld (ed_a),hl
	ld (ed_b),hl
	ret

ed_line1:			; ed_a must be a line of the text.  CF = no (message)
	ld hl,(ed_a)
ed_isline:			; HL must be a line: 1 .. count.  CF = no (message)
	push hl
	call ed_count
	pop de
	ld a,d
	or e
	jr z,ed_l1no
	or a
	sbc hl,de
	ret nc
ed_l1no:
	ld hl,m_noline
	call OS_PUTS
	scf
	ret

; ---------------------------------------------------------------- the text
ed_count:			; HL = number of lines (= number of LFs)
	ld hl,text
	ld bc,0
ed_c1:	push hl
	ld de,(ed_end)
	or a
	sbc hl,de
	pop hl
	jr nc,ed_c2
	ld a,(hl)
	inc hl
	cp 10
	jr nz,ed_c1
	inc bc
	jr ed_c1
ed_c2:	ld h,b
	ld l,c
	ret

ed_find_ln:			; HL = line number -> HL = where it starts
	ex de,hl		; (past the last line: ed_end)
	ld hl,text
ed_f1:	dec de
	ld a,d
	or e
	ret z
ed_f2:	push hl
	push de
	ld de,(ed_end)
	or a
	sbc hl,de
	pop de
	pop hl
	ret nc
	ld a,(hl)
	inc hl
	cp 10
	jr nz,ed_f2
	jr ed_f1

ed_show:			; print line ed_cur as "  12  text"
	ld a,1
	ld (ed_shown),a
	ld hl,(ed_cur)
ed_showhl:			; print line HL
	push hl
	call ed_pnum
	ld a,' '
	call OS_PUTC
	call OS_PUTC
	pop hl
	call ed_find_ln
ed_sh1: push hl
	ld de,(ed_end)
	or a
	sbc hl,de
	pop hl
	jr nc,ed_sh2
	ld a,(hl)
	inc hl
	cp 10
	jr z,ed_sh2
	call OS_PUTC
	jr ed_sh1
ed_sh2: jp OS_CRLF

ed_pnum:			; HL in decimal, in 5 columns
	push hl
	ld de,10000		; a space for each column the number does not use
	call ed_pn
	ld de,1000
	call ed_pn
	ld de,100
	call ed_pn
	ld de,10
	call ed_pn
	pop hl
	jp OS_DEC16
ed_pn:	or a			; HL < DE: one space (HL is kept)
	sbc hl,de
	add hl,de
	ret nc
	ld a,' '
	jp OS_PUTC

; ---------------------------------------------------------------- showing
ed_list:			; L: a page from here,  12L: a page from line 12,
	call ed_defs		; 5,30L: lines 5 to 30
	ld hl,(ed_a)
	ld a,h			; (line 0 is line 1)
	or l
	jr nz,ed_li0
	inc hl
	ld (ed_a),hl
ed_li0: ld a,(ed_nnum)
	cp 2
	jr z,ed_li1
	ld de,ED_PAGE-1
	add hl,de
	ld (ed_b),hl
ed_li1: ld a,1
	ld (ed_shown),a
	call ed_count		; never past the end
	ex de,hl
	ld hl,(ed_b)
	or a
	sbc hl,de
	jr c,ed_li2
	ld (ed_b),de
ed_li2: ld hl,(ed_a)
	push hl 		; nothing left to show?
	ld de,(ed_b)
	ex de,hl
	or a
	sbc hl,de
	pop hl
	jr nc,ed_li3
	push hl
	ld hl,m_end
	call OS_PUTS
	pop hl
	ret
ed_li3: ld de,(ed_b)		; show ed_a .. ed_b
	push hl
	or a
	sbc hl,de
	pop hl
	jr z,ed_li4
	ret nc
ed_li4: push hl
	call ed_showhl
	pop hl
	ld (ed_cur),hl
	call OS_KBHIT		; Esc stops
	jr z,ed_li5
	call OS_GETC
	cp 1Bh
	ret z
ed_li5: inc hl
	jr ed_li3

ed_next:			; Return: the next page
	call ed_count
	ld a,h
	or l
	jr z,ed_empty
	ld de,(ed_cur)		; from the line after the last one shown (or from
	ld a,(ed_shown) 	; the current line, if it has not been shown yet)
	or a
	jr z,ed_nx1
	inc de
ed_nx1: ld (ed_a),de
	ld hl,ED_PAGE-1
	add hl,de
	ld (ed_b),hl
	ld a,2
	ld (ed_nnum),a
	jp ed_list

ed_back:			; "-": the page before
	ld hl,(ed_cur)
	ld de,ED_PAGE*2 	 ; the page before the one shown last
	or a
	sbc hl,de
	jr nc,ed_bk1
	ld hl,0
ed_bk1: inc hl
	ld (ed_a),hl
	ld de,ED_PAGE-1
	add hl,de
	ld (ed_b),hl
	ld a,2
	ld (ed_nnum),a
	jp ed_list

ed_empty:
	ld hl,m_empty
	jp OS_PUTS

; ---------------------------------------------------------------- changing
ed_app: 			; A: insert after the last line
	call ed_count
	inc hl
	ld (ed_a),hl
	jr ed_ins1
ed_ins: 			; [n]I: insert before line n
	call ed_defs
	call ed_count		; at most count + 1 (the end)
	inc hl
	ex de,hl
	ld hl,(ed_a)
	ld a,h
	or l
	jr z,ed_l1no2
	ex de,hl
	or a
	sbc hl,de
	jr c,ed_l1no2
ed_ins1:
	ld hl,(ed_a)
	ld (ed_cur),hl
ed_ins2:
	ld hl,(ed_cur)		; prompt: the line number
	call ed_pnum
	ld a,':'
	call OS_PUTC
	ld a,' '
	call OS_PUTC
	ld hl,ed_line
	ld b,ED_WIDTH
	call OS_GETLINE
	ld a,(ed_line)		; "." alone ends
	cp '.'
	jr nz,ed_ins3
	ld a,(ed_line+1)
	or a
	ret z
ed_ins3:
	ld c,b			; C = length
	ld hl,(ed_cur)
	call ed_find_ln
	call ed_put		; the line + LF at HL
	ret c
	ld hl,(ed_cur)
	inc hl
	ld (ed_cur),hl
	jr ed_ins2
ed_l1no2:
	ld hl,m_noline
	jp OS_PUTS

ed_put: 			; insert ed_line (C bytes) + LF at HL.  CF = no room
	push hl
	ld b,0			; room: ed_end + C + 1 <= ED_TOP?
	ld hl,(ed_end)
	add hl,bc
	inc hl
	ld de,ED_TOP+1
	or a
	sbc hl,de
	pop hl
	jr c,ed_p1
	ld hl,m_full
	call OS_PUTS
	scf
	ret
ed_p1:	push hl 		; move HL .. ed_end up by C + 1
	push bc
	ex de,hl
	ld hl,(ed_end)
	or a
	sbc hl,de		; HL = bytes to move
	ld a,h
	or l
	jr z,ed_p2
	push hl
	ld hl,(ed_end)		; from the top down (LDDR)
	dec hl
	ld d,h
	ld e,l
	inc c			; BC = C + 1 (C < 128: B stays 0)
	add hl,bc		; HL = the last byte's new place
	ex de,hl		; LDDR: HL = source, DE = target
	pop bc
	lddr
ed_p2:	pop bc
	ld hl,(ed_end)		; the text is C + 1 longer
	add hl,bc
	inc hl
	ld (ed_end),hl
	pop de			; DE = where the line goes
	ld hl,ed_line
	ld a,c
	or a
	jr z,ed_p3
	ldir
ed_p3:	ld a,10
	ld (de),a
	ld a,1
	ld (ed_dirty),a
	xor a
	ld (ed_shown),a
	ret

ed_del: 			; D: this line,  5D: line 5,  5,9D: lines 5 to 9
	call ed_defs
	ld hl,(ed_a)
	call ed_isline
	ret c
	ld hl,(ed_b)
	call ed_isline
	ret c
	call ed_line1b
	ret c
	ld hl,(ed_b)		; HL = after line b, DE = start of line a
	inc hl
	call ed_find_ln
	push hl
	ld hl,(ed_a)
	call ed_find_ln
	ex de,hl
	pop hl
	call ed_cut		; remove DE .. HL
	ld hl,(ed_a)		; the current line: the one after the gap
	ld (ed_cur),hl
	ret

ed_line1b:			; ed_a <= ed_b?  CF = no (message)
	ld hl,(ed_b)
	ld de,(ed_a)
	or a
	sbc hl,de
	ret nc
	jp ed_l1no

ed_cut: 			; remove the bytes DE .. HL-1
	push de
	push hl
	ex de,hl		; bytes after the cut: ed_end - HL
	ld hl,(ed_end)
	or a
	sbc hl,de
	ld b,h
	ld c,l
	pop hl			; source: HL, target: DE
	pop de
	push de
	push hl
	ld a,b
	or c
	jr z,ed_ct1
	ldir
ed_ct1: pop hl			; ed_end -= HL - DE
	pop de
	or a
	sbc hl,de
	ex de,hl
	ld hl,(ed_end)
	or a
	sbc hl,de
	ld (ed_end),hl
	ld a,1
	ld (ed_dirty),a
	xor a
	ld (ed_shown),a
	ret

ed_edit:			; [n]E: show the line, type it again
	call ed_defs
	call ed_line1
	ret c
	ld hl,(ed_a)
	ld (ed_cur),hl
	call ed_show
	ld hl,(ed_cur)
	call ed_pnum
	ld a,':'
	call OS_PUTC
	ld a,' '
	call OS_PUTC
	ld hl,ed_line
	ld b,ED_WIDTH
	call OS_GETLINE
	ld a,b
	or a
	ret z			; Return alone: no change
	push bc
	ld hl,(ed_cur)		; out with the old line ...
	inc hl
	call ed_find_ln
	push hl
	ld hl,(ed_cur)
	call ed_find_ln
	ex de,hl
	pop hl
	call ed_cut
	pop bc
	ld c,b			; ... in with the new
	ld hl,(ed_cur)
	call ed_find_ln
	jp ed_put

ed_find:			; F text: the next line holding the text
	call ed_skip		; HL = the text to find
	ld a,(hl)
	or a
	ret z
	ld (ed_ptr),hl
	call ed_count
	ld (ed_cnt),hl
	ld hl,(ed_cur)
ed_fd1: inc hl			; line by line, from the one after the current
	push hl
	ld de,(ed_cnt)
	ex de,hl
	or a
	sbc hl,de
	pop hl
	jr c,ed_fd_no
	push hl
	call ed_find_ln
	call ed_has		; does line HL hold the text?
	pop hl
	jr nz,ed_fd1
	ld (ed_cur),hl
	jp ed_show
ed_fd_no:
	ld hl,m_nofind
	jp OS_PUTS

ed_has: 			; HL = a line.  Z = it holds the text at ed_ptr
ed_ha1: ld a,(hl)
	cp 10
	jr z,ed_ha_no
	push hl 		; does the text start here?
	ld de,(ed_ptr)
ed_ha2: ld a,(de)
	or a
	jr z,ed_ha_yes
	cp (hl)
	jr nz,ed_ha3
	inc hl
	inc de
	jr ed_ha2
ed_ha3: pop hl
	inc hl
	jr ed_ha1
ed_ha_yes:
	pop hl
	xor a
	ret
ed_ha_no:
	or a			; NZ (A = 10)
	ret

; ---------------------------------------------------------------- R C M T
ed_repl:			; [a[,b]]R/old/new/: in each line, every "old" becomes "new"
	call ed_defs
	ld hl,(ed_a)
	call ed_isline
	ret c
	ld hl,(ed_b)
	call ed_isline
	ret c
	call ed_line1b
	ret c
	call ed_skip		; the delimiter: the character after R
	ld a,(hl)
	or a
	jp z,ed_rbad
	ld c,a
	inc hl
	ld de,ed_old
	call ed_rpart
	ld a,(ed_old)
	or a
	jp z,ed_rbad
	ld de,ed_new
	call ed_rpart
	ld hl,0
	ld (ed_nch),hl
	ld hl,(ed_a)
ed_rl:	ld (ed_cnt),hl		; line by line, a .. b
	call ed_find_ln
	push hl
	ld de,ed_line		; the line, with the changes, into ed_line
	ld b,0			; B = its length, C = 1 if changed
	ld c,0
ed_rc:	ld a,(hl)
	cp 10
	jr z,ed_rdone
	call ed_rhas		; "old" here?
	jr nz,ed_rcp
	push hl 		; yes: "new" instead
	ld hl,ed_new
ed_rn:	ld a,(hl)
	or a
	jr z,ed_rn2
	ld (de),a
	inc hl
	inc de
	inc b
	bit 7,b
	jr nz,ed_rlong
	jr ed_rn
ed_rn2: pop hl
	ld c,1
	push de 		; and on past "old"
	ld de,ed_old
ed_rsk: ld a,(de)
	or a
	jr z,ed_rsk2
	inc hl
	inc de
	jr ed_rsk
ed_rsk2:
	pop de
	jr ed_rc
ed_rcp: ld a,(hl)		; no: the character as it is
	ld (de),a
	inc hl
	inc de
	inc b
	bit 7,b
	jr z,ed_rc
	push hl
ed_rlong:
	pop hl
	pop hl
	ld hl,m_long		; (longer than 127: left as it was)
	call OS_PUTS
	call OS_CRLF
	jr ed_rnext
ed_rdone:
	pop hl			; HL = where the line starts
	ld a,c
	or a
	jr z,ed_rnext
	push bc
	push hl 		; out with the old line ...
	ld hl,(ed_cnt)
	inc hl
	call ed_find_ln
	pop de
	push de
	call ed_cut
	pop hl
	pop bc
	ld c,b			; ... in with the new (C bytes from ed_line)
	call ed_put
	ret c
	ld hl,(ed_cnt)
	ld (ed_cur),hl
	ld hl,(ed_nch)
	inc hl
	ld (ed_nch),hl
ed_rnext:
	ld hl,(ed_cnt)
	ld de,(ed_b)
	or a
	sbc hl,de
	ld hl,(ed_cnt)
	inc hl
	jp c,ed_rl
	ld hl,(ed_nch)
	ld a,h
	or l
	jr z,ed_rnone
	call OS_DEC16
	ld hl,m_changed
	call OS_PUTS
	call OS_CRLF
	jp ed_show
ed_rnone:
	ld hl,m_nofind
	jp OS_PUTS
ed_rbad:
	ld hl,m_rbad
	jp OS_PUTS

ed_rpart:			; text from HL up to the delimiter C (or the end) -> DE, 0
	ld b,63
ed_rp1: ld a,(hl)
	or a
	jr z,ed_rp2
	inc hl
	cp c
	jr z,ed_rp2
	ld (de),a
	inc de
	djnz ed_rp1
ed_rp2: xor a
	ld (de),a
	ret

ed_rhas:			; HL = in a line: Z = ed_old starts here
	push hl
	push de
	ld de,ed_old
ed_rh1: ld a,(de)
	or a
	jr z,ed_rh2
	cp (hl)
	jr nz,ed_rh2
	inc hl
	inc de
	jr ed_rh1
ed_rh2: pop de
	pop hl
	ret

ed_copy:			; a,b,cC: copy lines a..b to before line c
	call ed_cm
	ret c
	ld hl,(ed_c)
	ld (ed_cur),hl
	jp ed_show

ed_move:			; a,b,cM: move them there
	call ed_cm
	ret c
	ld h,d			; out with them where they were
	ld l,e
	add hl,bc
	call ed_cut
	ld hl,(ed_c)		; the current line: the first moved
	ld de,(ed_a)
	or a
	sbc hl,de
	ld hl,(ed_c)
	jr c,ed_mv1
	jr z,ed_mv1
	ld de,(ed_b)		; (they were above: c - (b - a + 1))
	or a
	sbc hl,de
	ld de,(ed_a)
	add hl,de
	dec hl
ed_mv1: ld (ed_cur),hl
	jp ed_show

ed_cm:				; C and M: lines a..b copied to before line c.  DE = where
	ld a,(ed_nnum)		; the old ones are now, BC = their length.  CF = no (said)
	cp 3
	jr z,ed_cm1
	ld hl,m_need3
	call OS_PUTS
	scf
	ret
ed_cm1: ld hl,(ed_a)
	call ed_isline
	ret c
	ld hl,(ed_b)
	call ed_isline
	ret c
	call ed_line1b
	ret c
	call ed_count		; 1 <= c <= count + 1
	inc hl
	ld de,(ed_c)
	ld a,d
	or e
	jp z,ed_l1no
	or a
	sbc hl,de
	jp c,ed_l1no
	ld hl,(ed_c)		; not inside themselves: c <= a or c > b
	ld de,(ed_a)
	or a
	sbc hl,de
	jr c,ed_cm2
	jr z,ed_cm2
	ld hl,(ed_b)
	ld de,(ed_c)
	or a
	sbc hl,de
	jr c,ed_cm2
	ld hl,m_inside
	call OS_PUTS
	scf
	ret
ed_cm2: ld hl,(ed_b)		; the lines: ed_src, ed_len
	inc hl
	call ed_find_ln
	push hl
	ld hl,(ed_a)
	call ed_find_ln
	ld (ed_src),hl
	ex de,hl
	pop hl
	or a
	sbc hl,de
	ld (ed_len),hl
	ld de,(ed_end)		; room for them?
	add hl,de
	ld de,ED_TOP+1
	or a
	sbc hl,de
	jr c,ed_cm3
	ld hl,m_full
	call OS_PUTS
	scf
	ret
ed_cm3: ld hl,(ed_c)		; where they go
	call ed_find_ln
	ld (ed_dst),hl
	ex de,hl		; a gap there: what is after it, up by ed_len
	ld hl,(ed_end)
	or a
	sbc hl,de
	ld a,h
	or l
	jr z,ed_cm4
	ld b,h
	ld c,l
	ld hl,(ed_end)
	dec hl
	push hl
	ld de,(ed_len)
	add hl,de
	ex de,hl
	pop hl
	lddr
ed_cm4: ld hl,(ed_src)		; were they after the gap?  They moved up too
	ld de,(ed_dst)
	or a
	sbc hl,de
	jr c,ed_cm5
	ld hl,(ed_src)
	ld de,(ed_len)
	add hl,de
	ld (ed_src),hl
ed_cm5: ld hl,(ed_src)		; the copy into the gap
	ld de,(ed_dst)
	ld bc,(ed_len)
	ldir
	ld hl,(ed_end)
	ld de,(ed_len)
	add hl,de
	ld (ed_end),hl
	ld a,1
	ld (ed_dirty),a
	xor a
	ld (ed_shown),a
	ld de,(ed_src)
	ld bc,(ed_len)
	or a
	ret

ed_tran:			; [n]T name: read a file in before line n
	call ed_defs
	call ed_count		; n: 1 .. count + 1
	inc hl
	ld de,(ed_a)
	ld a,d
	or e
	jp z,ed_l1no
	or a
	sbc hl,de
	jp c,ed_l1no
	call ed_skip
	ld a,(hl)
	or a
	jp z,ed_rbad
	call OS_RESOLVE 	; (its directory: EDIT's own again after it)
	jp c,ed_terr
	ld ix,ed_tfcb
	call OS_OPEN
	jp c,ed_terr
	ld hl,ED_TOP-1		; it must fit after the text (and an LF)
	ld de,(ed_end)
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ld a,(ed_tfcb+FCB_SIZE+2)
	ld hl,ed_tfcb+FCB_SIZE+3
	or (hl)
	jp nz,ed_tfull
	ld hl,(ed_tfcb+FCB_SIZE)
	push hl
	or a
	sbc hl,bc
	pop bc
	jp nc,ed_tfull
	ld de,(ed_end)		; read it there
	ld ix,ed_tfcb
	call OS_READ
	jp c,ed_terr
	ld hl,(ed_end)		; drop CRs, stop at ^Z, end it with an LF
	ld d,h
	ld e,l
ed_t1:	ld a,b
	or c
	jr z,ed_t2
	ld a,(hl)
	inc hl
	dec bc
	cp 1Ah
	jr z,ed_t2
	cp 13
	jr z,ed_t1
	ld (de),a
	inc de
	jr ed_t1
ed_t2:	ld hl,(ed_end)		; (nothing: done)
	or a
	sbc hl,de
	jr z,ed_tback
	dec de
	ld a,(de)
	inc de
	cp 10
	jr z,ed_t3
	ld a,10
	ld (de),a
	inc de
ed_t3:	push de 		; DE = its end.  Its lines, counted now:
	ld hl,(ed_end)
	ld bc,0
ed_t4:	push hl
	or a
	sbc hl,de
	pop hl
	jr nc,ed_t4b
	ld a,(hl)
	inc hl
	cp 10
	jr nz,ed_t4
	inc bc
	jr ed_t4
ed_t4b: ld (ed_cnt),bc
	ld hl,(ed_a)		; turn it round into its place: reverse
	call ed_find_ln 	; P..end, end..its end, P..its end
	ld (ed_dst),hl
	ld de,(ed_end)
	call ed_rev
	ld hl,(ed_end)
	pop de
	push de
	call ed_rev
	ld hl,(ed_dst)
	pop de
	push de
	call ed_rev
	pop hl
	ld (ed_end),hl
	ld bc,(ed_cnt)
ed_t5:	ld h,b
	ld l,c
	call OS_DEC16
	ld hl,m_tread
	call OS_PUTS
	ld a,1
	ld (ed_dirty),a
	xor a
	ld (ed_shown),a
	ld hl,(ed_a)
	ld (ed_cur),hl
	jr ed_tback
ed_tfull:
	ld hl,m_full
	call OS_PUTS
	jr ed_tback
ed_terr:
	call OS_ERRMSG
	call OS_PUTS
ed_tback:			; back to EDIT's own file's directory
	ld hl,ed_arg
	call OS_RESOLVE
	ret

ed_rev: 			; reverse the bytes HL .. DE-1
	dec de
ed_rv1: push hl
	or a
	sbc hl,de
	pop hl
	ret nc
	ld a,(de)
	ld c,(hl)
	ld (hl),a
	ld a,c
	ld (de),a
	inc hl
	dec de
	jr ed_rv1

; ---------------------------------------------------------------- the file
ed_load:			; read the file into text.  CF = error (A = code)
	ld hl,ed_name
	ld ix,ed_fcb
	call OS_OPEN
	jr nc,ed_ld1
	cp FS_ENOTF
	scf
	ret nz
	ld hl,m_new		; a new file
	call OS_PUTS
	or a
	ret
ed_ld1: ld a,(ed_fcb+FCB_SIZE+2)	; does it fit?
	ld hl,ed_fcb+FCB_SIZE+3
	or (hl)
	jr nz,ed_big
	ld hl,(ed_fcb+FCB_SIZE)
	ld de,ED_TOP-text-1
	or a
	sbc hl,de
	jr nc,ed_big
	ld de,text
	ld bc,ED_TOP-text
	call OS_READ
	ret c
	ld hl,text		; drop CRs, stop at ^Z
	ld d,h
	ld e,l
ed_ld2: ld a,b
	or c
	jr z,ed_ld4
	ld a,(hl)
	inc hl
	dec bc
	cp 1Ah
	jr z,ed_ld4
	cp 13
	jr z,ed_ld2
	ld (de),a
	inc de
	jr ed_ld2
ed_ld4: ld (ed_end),de
	ld hl,text		; the last line must end in LF
	or a
	sbc hl,de
	jr z,ed_ld5
	dec de
	ld a,(de)
	inc de
	cp 10
	jr z,ed_ld5
	ld a,10
	ld (de),a
	inc de
	ld (ed_end),de
ed_ld5: call ed_count
	call OS_DEC16
	ld hl,m_lines
	call OS_PUTS
	or a
	ret
ed_big: ld hl,m_big
	call OS_PUTS
	ld sp,(ed_sp)
	ret

ed_write:			; W: write the file (CR LF line ends)
	ld hl,ed_name
	ld ix,ed_fcb
	call OS_CREATE
	jr c,ed_werr
	xor a
	ld (ed_outn),a
	ld hl,text
ed_w1:	push hl
	ld de,(ed_end)
	or a
	sbc hl,de
	pop hl
	jr nc,ed_w3
	ld a,(hl)
	inc hl
	cp 10
	jr nz,ed_w2
	ld a,13
	call ed_byte
	jr c,ed_werr
	ld a,10
ed_w2:	call ed_byte
	jr c,ed_werr
	jr ed_w1
ed_w3:	call ed_flushout
	jr c,ed_werr
	ld ix,ed_fcb
	call OS_CLOSE
	jr c,ed_werr
	xor a
	ld (ed_dirty),a
	call ed_count
	call OS_DEC16
	ld hl,m_written
	jp OS_PUTS
ed_werr:
	call OS_ERRMSG
	call OS_PUTS
	scf
	ret

ed_byte:			; A into ed_out; write it out when full.  CF = error
	push hl
	ld hl,ed_outn
	ld e,(hl)
	inc (hl)
	ld d,0
	ld hl,ed_out
	add hl,de
	ld (hl),a
	pop hl
	ld a,(ed_outn)
	cp ED_OUTN
	ccf
	ret nc			; not full yet (carry clear)
ed_flushout:			; write ed_out.  CF = error
	push hl
	ld a,(ed_outn)
	ld c,a
	ld b,0
	or a
	jr z,ed_fo1
	ld ix,ed_fcb
	ld de,ed_out
	call OS_WRITE
ed_fo1: ld a,0			; (LD leaves the carry alone)
	ld (ed_outn),a
	pop hl
	ret

ed_exit:			; X: write, then quit
	call ed_write
	ret c
ed_quit:			; Q: quit (ask first if there are changes)
	ld a,(ed_dirty)
	or a
	jr z,ed_q1
	ld hl,m_unsaved
	call OS_PUTS
	call OS_GETC
	call OS_PUTC
	and 0DFh
	cp 'Y'
	ret nz
ed_q1:	call OS_CRLF
	ld sp,(ed_sp)		; back to the shell
	ret

ed_help:
	ld hl,m_help
	jp OS_PUTS

ed_oserr:			; print error A and stop
	call OS_ERRMSG
	call OS_PUTS
	jp OS_CRLF

m_use:	defm "EDIT name   (a line editor; H inside it lists the commands)"
	defb 13,10,0
m_new:	defm "new file"
	defb 0
m_lines: defm " lines"
	defb 0
m_written: defm " lines written"
	defb 0
m_big:	defm "too big for EDIT (about 28 KB at most)"
	defb 13,10,0
m_full: defm "no more room"
	defb 13,10,0
m_what: defm "? (H for help)"
	defb 0
m_noline: defm "no such line"
	defb 0
m_nofind: defm "not found"
	defb 0
m_empty: defm "(no lines yet: A adds some)"
	defb 0
m_end:	defm "(end of the text)"
	defb 0
m_redir: defm "EDIT cannot run while its output goes to a file"
	defb 13,10,0
m_changed: defm " lines changed"
	defb 0
m_rbad: defm "R/old/new/   (any character instead of /)"
	defb 0
m_long: defm "(a line would be too long: left as it was)"
	defb 0
m_need3: defm "lines and where: 5,9,20C  (or M)"
	defb 0
m_inside: defm "they cannot go inside themselves"
	defb 0
m_tread: defm " lines read in"
	defb 0
m_unsaved: defm "Not written. Quit anyway (Y/N)? "
	defb 0
m_help: defm "  12  go to line 12      Return  next page      -  page before"
	defb 13,10
	defm "  L  5,30L  list         I  12I  insert before   A  add at the end"
	defb 13,10
	defm "  D  5,9D  delete        E  12E  retype a line   F text  find"
	defb 13,10
	defm "  R/old/new/  5,30R/a/b/  replace   5,9,20C  copy   5,9,20M  move (before 20)"
	defb 13,10
	defm "  T name  20T name  read a file in (before this line / line 20)"
	defb 13,10
	defm "  W  write   Q  quit   X  write and quit.   . = this line, $ = the last"
	defb 13,10
	defm "  When inserting, a line with only . stops."
	defb 0

text:				; the text starts here and grows up to ED_TOP
