; ==========================================================================
; REDIRECT.ASM - output redirection:  command > file   command >> file
;
;   DIR > LIST.TXT        what DIR prints goes into LIST.TXT (made new)
;   ECHO more >> LOG.TXT  added to the end of LOG.TXT (made if it is not there)
;
; While the command runs, what it prints (con_putc) goes into memory: the top
; 8 KB of the TPA (RD_BUF).  When it has ended (back in sh_loop, however it
; ended) rd_end writes that to the file.  Writing the file only then keeps it
; out of the way of the command's own use of the file system (and of the other
; drive's FAT: one disk is mounted at a time).  More than 8 KB is cut, and
; rd_end says so.  Meanwhile commands get the TPA below RD_BUF (sh_bufsz), and
; OS_MEMTOP says RD_BUF, so a program that keeps below it is safe too.
; The > must be outside quotes (FIND "a>b" X is not redirected).  Not for the
; line a program runs (OS_EXEC).
;
;   rd_start   LINEBUF: a redirection at its end?  It is cut off, and the
;              output goes to memory (rd_ptr <> 0)
;   rd_end     the command is over: write the output to its file
;   (con_putc, in LIB/CONSOLE.ASM, does the storing)
; ==========================================================================

RD_SIZE: equ 2000h		; 8 KB
RD_BUF:  equ TPA_TOP-RD_SIZE	; at its start: the file's name (40 bytes) ...
RD_DATA: equ RD_BUF+40		; ... then the output (it ends at TPA_TOP)

rd_start:
	ld a,(sh_exec)		; (not in a line a program runs)
	or a
	ret nz
	ld hl,LINEBUF
	ld c,a			; C = 1 inside quotes
rs_1:	ld a,(hl)
	or a
	ret z			; no >
	inc hl
	cp '"'
	jr nz,rs_2
	inc c
	res 1,c
	jr rs_1
rs_2:	cp '>'
	jr nz,rs_1
	bit 0,c
	jr nz,rs_1
	dec hl			; the command ends here, without the spaces
	push hl 		; before the > (ECHO text > X: "text", not "text ")
rs_t:	ld (hl),0
	dec hl
	ld a,(hl)
	cp ' '
	jr z,rs_t
	pop hl
	inc hl
	ld a,(hl)		; >> appends
	cp '>'
	ld a,0
	jr nz,rs_3
	inc hl
	inc a
rs_3:	ld (rd_app),a		; 1 = >>
	call sh_skipsp
	ld a,(hl)
	or a
	jr z,rs_none
	ld de,RD_BUF		; the name, up to a space (39 characters at most)
	ld b,39
rs_4:	ld a,(hl)
	cp ' '+1
	jr c,rs_5
	ld (de),a
	inc hl
	inc de
	djnz rs_4
rs_5:	xor a
	ld (de),a
	ld (rd_cut),a
	ld hl,RD_DATA		; from now on the output goes to memory
	ld (rd_ptr),hl
	ld hl,RD_BUF-TPA	; and commands use only the memory below it
	ld (sh_bufsz),hl
	ret
rs_none:			; "DIR >": no name, so the command does not run
	ld (LINEBUF),a
	ld hl,m_sh_need1
	jp sh_usage

rd_end: ld hl,(rd_ptr)
	ld a,h
	or l
	ret z			; nothing redirected
	ld de,RD_DATA
	or a
	sbc hl,de
	push hl 		; the bytes to write
	ld hl,0 		; the console again (messages from here show)
	ld (rd_ptr),hl
	call sh_bufdef
	call sh_mount
	jr c,re_pop
	ld hl,RD_BUF
	call sh_resolve
	jr c,re_err
	ld ix,sh_fcb2
	ld a,(rd_app)
	dec a
	jr nz,re_new
	push hl 		; >>: open it, and go to its end
	call f_open
	pop hl
	jr c,re_new		; (not there: made new)
	push ix 		; position = size
	ld b,4
re_1:	ld a,(ix+FCB_SIZE)
	ld (ix+FCB_POS),a
	inc ix
	djnz re_1
	pop ix
	ld l,(ix+FCB_FIRST)	; the cluster holding it: the chain's last
	ld h,(ix+FCB_FIRST+1)
	ld a,h
	or l
	jr z,re_3		; (an empty file has none)
re_2:	ld (ix+FCB_CLUS),l
	ld (ix+FCB_CLUS+1),h
	call fat_next
	jr nc,re_2
	cp FS_EEND
	jr nz,re_err
re_3:	ld (ix+FCB_MODE),1	; written to now: f_close updates its entry
	jr re_wr
re_new: call f_create
	jr c,re_err
re_wr:	pop bc
	ld de,RD_DATA
	call f_write
	jr c,re_err1
	call f_close
	jr c,re_err1
	ld a,(rd_cut)
	or a
	ret z
	ld hl,m_rd_cut
	jp con_puts
re_err: pop bc
re_err1:
	jp sh_err
re_pop: pop bc
	ret

m_rd_cut:
	defm "(output cut at 8 KB)"
	defb 13,10,0
