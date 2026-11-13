; ==========================================================================
; HEXED.ASM - HEXED.BIN: a full-screen hex editor.
;
;   HEXED [d:][dir\]name       (a new file if there is none of that name)
;
;   0000  3E 0A CD 03 FF 76 48 65  6C 6C 6F 0D 0A 00 00 00 |>....vHello.....|
;
; The file is in memory (26 KB at most).  The screen is the terminal's own
; (SETUP: its rows, and the cursor moves UP DOWN LEFT RIGHT, HOME if it has
; it); the cursor is put where it must go by those moves alone, so no cursor
; addressing is needed.  Keys (letters, any case; no arrow keys needed):
;   A D W S        left, right, up, down (one byte, one line); H J K L too.
;                  A move key is acted on once: for ~0.15 s after it, more of
;                  them (a key held a little long, or bouncing) are let go by
;   Space / B      a page on / back       T / E   the top / the end
;   G              go to an offset (hex)
;   /  N           find hex bytes (1B 45) or "text"; N finds the next
;   Tab            the hex side or the text side
;   Return         edit: on the hex side type hex digits, on the text side
;                  characters; Backspace goes back, Esc ends it.  Typing past
;                  the end adds to the file
;   I  X           insert a 00 byte here; delete the byte here
;   P              put the file on the disk (to HEXED.TMP, then in its place)
;   Q              quit (asks if there are changes not written)
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

BUF:	equ 9400h		; the file
BUFMAX: equ 0FB00h-BUF		; 26,368 bytes
LW:	equ 74			; a line on the screen: its width

S_CLEAR: equ 0
S_HOME: equ 1
S_UP:	equ 4
S_DOWN: equ 5
S_RIGHT: equ 6
S_LEFT: equ 7

v_len:	equ 9000h		; word: the file's length
v_top:	equ 9002h		; word: the offset of the first line shown
v_cur:	equ 9004h		; word: the byte the cursor is on
v_pane: equ 9006h		; 0 hex, 1 text
v_nib:	equ 9007h		; editing hex: 0 the first digit, 1 the second
v_mode: equ 9008h		; 0 moving, 1 editing
v_chg:	equ 9009h		; 1 = changed since written
v_rows: equ 900Ah
v_cols: equ 900Bh
v_dl:	equ 900Ch		; lines of bytes on the screen
v_r:	equ 900Dh		; where the terminal's cursor is: row, column
v_c:	equ 900Eh
v_home: equ 900Fh		; 1 = HOME works
v_msg:	equ 9010h		; word: a message for the status line (0 = none)
v_n:	equ 9012h		; word
v_i:	equ 9014h		; word
v_flen: equ 9016h		; what to find: its length
v_find: equ 9017h		; 16 bytes
v_in:	equ 9028h		; 34 bytes: a typed line
v_inl:	equ 904Ah		; its length
v_name: equ 9050h		; 64 bytes: the name as typed
v_fcb:	equ 9090h		; 16 bytes
v_sbuf: equ 90A0h		; 80 bytes: the status line being made
v_sp:	equ 90F0h		; word: the stack at the start
v_dz:	equ 90F2h		; a digit was written (sdec16)
v_mv:	equ 90F3h		; 1 = the last key moved the cursor
v_pend: equ 90F4h		; a key debounce read that is not a move (0 = none)
DEBOUNCE: equ 4000		; turns of debounce's loop (~150 T each): about 0.15 s at 4 MHz
P_PAT:	equ 9100h
P_NAME: equ 9110h

start:	ld (v_sp),sp
	ld de,v_name
	call pl_word
	jp z,use
	ld a,8			; the screen
	call OS_SCREEN
	jr nc,st_1
	ld hl,80*256+24
st_1:	ld a,l
	ld (v_rows),a
	sub 4
	jp c,small
	cp 4
	jp c,small
	ld (v_dl),a
	ld a,h
	ld (v_cols),a
	cp LW+2
	jp c,small
	ld a,S_RIGHT		; the moves it needs
	call OS_SCREEN
	jp c,nomoves
	ld a,S_LEFT
	call OS_SCREEN
	jp c,nomoves
	ld a,S_DOWN
	call OS_SCREEN
	jp c,nomoves
	ld a,S_UP
	call OS_SCREEN
	jp c,nomoves
	ld a,S_HOME		; and HOME if there is one
	call OS_SCREEN
	ld a,0
	jr c,st_2
	inc a
st_2:	ld (v_home),a
	call load
	ret c
	xor a
	ld (v_pane),a
	ld (v_nib),a
	ld (v_mode),a
	ld (v_chg),a
	ld (v_flen),a
	ld (v_mv),a
	ld (v_pend),a
	ld hl,0
	ld (v_top),hl
	ld (v_cur),hl
	call redraw

; ---------------------------------------------------------------- the keys
key:	ld a,(v_mv)		; after a move: repeats of it are let go by
	or a
	call nz,debounce
	call place
	call getkey
	ld b,a
	ld a,(v_mode)
	or a
	jp nz,ekey
	ld a,b
	call pl_upper
	call ismove		; A W S D (and H J K L): a move
	jr nz,k_nomv
	ld a,1
	ld (v_mv),a
	ld a,c
	cp 'A'
	jp z,k_left
	cp 'H'
	jp z,k_left
	cp 'D'
	jp z,k_right
	cp 'L'
	jp z,k_right
	cp 'W'
	jp z,k_up
	cp 'K'
	jp z,k_up
	jp k_down		; (S, J)
k_nomv: ld a,c
	cp ' '
	jp z,k_pgdn
	cp 'F'
	jp z,k_pgdn
	cp 'B'
	jp z,k_pgup
	cp 'T'
	jp z,k_top
	cp 'E'
	jp z,k_end
	cp 9
	jp z,k_tab
	cp 13
	jp z,k_edit
	cp 'G'
	jp z,k_goto
	cp '/'
	jp z,k_find
	cp 'N'
	jp z,k_next
	cp 'I'
	jp z,k_ins
	cp 'X'
	jp z,k_del
	cp 'P'
	jp z,k_write
	cp 'Q'
	jp z,k_quit
	jp key

ismove: 			; A = a key (in capitals): Z = a move (C = the key, kept)
	ld c,a
	cp 'A'
	ret z
	cp 'W'
	ret z
	cp 'S'
	ret z
	cp 'D'
	ret z
	cp 'H'
	ret z
	cp 'J'
	ret z
	cp 'K'
	ret z
	cp 'L'
	ret

getkey: ld a,(v_pend)		; A = the next key (one kept by debounce first)
	or a
	jp z,OS_GETC
	push af
	xor a
	ld (v_pend),a
	pop af
	ret

debounce:			; for ~0.15 s after a move, more of the move keys are
	xor a			; dropped: a key held a little long, or one that
	ld (v_mv),a		; bounces, moves once.  Another key is kept (v_pend)
	ld de,DEBOUNCE
db_1:	push de
	call OS_KBHIT
	jr z,db_2
	call OS_GETC
	ld b,a
	call pl_upper
	call ismove
	jr z,db_2
	ld a,b			; not a move: it is the next key
	ld (v_pend),a
	pop de
	ret
db_2:	pop de
	dec de
	ld a,d
	or e
	jr nz,db_1
	ret

maxcur: 			; HL = the last place the cursor may be: the last
	ld hl,(v_len)		; byte, or (editing) one past it, to add a byte
	ld a,(v_mode)
	or a
	ret nz
	ld a,h
	or l
	ret z
	dec hl
	ret

k_left: ld hl,(v_cur)
	ld a,h
	or l
	jp z,key
	dec hl
k_set:	ld (v_cur),hl		; the cursor to HL (on the screen, or the page moves)
	call seen
	call status
	jp key
k_right:
	call maxcur
	ld de,(v_cur)
	or a
	sbc hl,de
	jp z,key
	ex de,hl
	inc hl
	jr k_set
k_up:	ld hl,(v_cur)
	ld de,16
	or a
	sbc hl,de
	jp c,key
	jr k_set
k_down: ld hl,(v_cur)
	ld de,16
	add hl,de
	ex de,hl
	call maxcur
	or a
	sbc hl,de
	jp c,key
	ex de,hl
	jr k_set
k_top:	ld hl,0
	jr k_set
k_end:	call maxcur
	jr k_set
k_pgdn: call pagebytes		; a page on: the view and the cursor
	ld hl,(v_top)
	add hl,de
	push hl
	ld hl,(v_len)
	pop de
	or a
	sbc hl,de		; (not past the end)
	jp c,key
	jp z,key
	ld (v_top),de
	call pagebytes
	ld hl,(v_cur)
	add hl,de
	ex de,hl		; DE = the cursor a page on; HL = the last place
	call maxcur
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,k_pg1		; past it: the last place
	ex de,hl
k_pg1:	ld (v_cur),hl
	call redraw
	jp key
k_pgup: ld hl,(v_top)
	ld a,h
	or l
	jp z,key
	call pagebytes
	or a
	sbc hl,de
	jr nc,k_pu1
	ld hl,0
k_pu1:	ld (v_top),hl
	ld hl,(v_cur)
	or a
	sbc hl,de
	jr nc,k_pu2
	ld hl,0
k_pu2:	ld (v_cur),hl
	call redraw
	jp key
k_tab:	ld a,(v_pane)
	xor 1
	ld (v_pane),a
	xor a
	ld (v_nib),a
	call status
	jp key
k_edit: ld a,1
	ld (v_mode),a
	xor a
	ld (v_nib),a
	call status
	jp key

pagebytes:			; DE = the bytes of a page (lines x 16)
	ld a,(v_dl)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ex de,hl
	ret

; ---------------------------------------------------------------- editing
ekey:	ld a,b			; editing: B = the key
	cp 1Bh
	jp z,e_end
	cp 9
	jp z,k_tab
	cp 8
	jp z,e_back
	cp 7Fh
	jp z,e_back
	cp 13
	jp z,e_end
	ld a,(v_pane)
	or a
	jr nz,e_text
	ld a,b			; the hex side: a hex digit
	call pl_upper
	sub '0'
	jp c,key
	cp 10
	jr c,e_dig
	sub 7
	cp 10
	jp c,key
	cp 16
	jp nc,key
e_dig:	ld c,a
	push bc
	call room		; (past the end: a new byte, 00)
	pop bc
	jp c,key
	ld a,(hl)
	ld b,a
	ld a,(v_nib)
	or a
	jr nz,e_lo
	ld a,c			; the first digit
	rlca
	rlca
	rlca
	rlca
	ld c,a
	ld a,b
	and 0Fh
	or c
	call setbyte
	ld a,1
	ld (v_nib),a
	call status
	jp key
e_lo:	ld a,b			; the second: then the next byte
	and 0F0h
	or c
	call setbyte
	xor a
	ld (v_nib),a
	jr e_next
e_text: ld a,b			; the text side: a printable character
	cp ' '
	jp c,key
	cp 7Fh
	jp nc,key
	push bc
	call room
	pop bc
	jp c,key
	ld a,b
	call setbyte
e_next: call maxcur
	ld de,(v_cur)
	or a
	sbc hl,de
	jr z,e_n1
	inc de
	ld (v_cur),de
e_n1:	call seen
	call status
	jp key
e_back: ld a,(v_nib)
	or a
	jr z,e_b1
	xor a
	ld (v_nib),a
	call status
	jp key
e_b1:	ld hl,(v_cur)
	ld a,h
	or l
	jp z,key
	dec hl
	ld (v_cur),hl
	call seen
	call status
	jp key
e_end:	xor a			; back to moving: on a byte of the file
	ld (v_mode),a
	ld (v_nib),a
	call maxcur
	ld de,(v_cur)
	or a
	sbc hl,de
	jr nc,e_e1
	add hl,de
	ld (v_cur),hl
e_e1:	call seen
	call status
	jp key

room:				; HL = the byte at the cursor; past the end, one more
	ld hl,(v_cur)		; (00).  CF = no room
	ld de,(v_len)
	or a
	sbc hl,de
	jr c,ro_in
	ld hl,(v_len)		; adding one
	ld de,BUFMAX
	or a
	sbc hl,de
	jr c,ro_add
	ld hl,m_full
	ld (v_msg),hl
	call status
	scf
	ret
ro_add: ld hl,(v_len)
	inc hl
	ld (v_len),hl
	ld hl,(v_cur)
	ld de,BUF
	add hl,de
	ld (hl),0
	push hl
	call title
	pop hl
	or a
	ret
ro_in:	ld hl,(v_cur)
	ld de,BUF
	add hl,de
	or a
	ret

setbyte:			; A = the byte at the cursor: in memory and on the screen
	push af
	ld hl,(v_cur)
	ld de,BUF
	add hl,de
	pop af
	ld (hl),a
	ld a,1
	ld (v_chg),a
	ld hl,(v_cur)
	jp drawbyte

; ---------------------------------------------------------------- I, X
k_ins:	ld hl,(v_len)		; a 00 byte at the cursor
	ld de,BUFMAX
	or a
	sbc hl,de
	jr c,ki_1
	ld hl,m_full
	ld (v_msg),hl
	call status
	jp key
ki_1:	ld hl,(v_len)		; the rest up one: from the end down
	ld de,(v_cur)
	or a
	sbc hl,de		; HL = how many
	ld b,h
	ld c,l
	ld hl,(v_len)
	ld de,BUF-1
	add hl,de		; HL = the last byte
	ld d,h
	ld e,l
	inc de
	ld a,b
	or c
	jr z,ki_2
	lddr
ki_2:	ld hl,(v_cur)
	ld de,BUF
	add hl,de
	ld (hl),0
	ld hl,(v_len)
	inc hl
	ld (v_len),hl
	jr kx_done
k_del:	ld hl,(v_len)		; the byte at the cursor goes
	ld de,(v_cur)
	or a
	sbc hl,de
	jp z,key
	jp c,key
	dec hl			; HL = the bytes after it
	ld b,h
	ld c,l
	ld hl,(v_cur)
	ld de,BUF
	add hl,de
	ld d,h
	ld e,l
	inc hl
	ld a,b
	or c
	jr z,kd_1
	ldir
kd_1:	ld hl,(v_len)
	dec hl
	ld (v_len),hl
	call maxcur		; (the cursor stays in the file)
	ld de,(v_cur)
	or a
	sbc hl,de
	jr nc,kx_done
	add hl,de
	ld (v_cur),hl
kx_done:
	ld a,1
	ld (v_chg),a
	call title
	ld hl,(v_cur)		; the lines from the cursor's down, again
	ld de,(v_top)
	or a
	sbc hl,de
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld a,l
kx_1:	ld hl,v_dl
	cp (hl)
	jr nc,kx_2
	push af
	call drawline
	pop af
	inc a
	jr kx_1
kx_2:	call status
	jp key

; ---------------------------------------------------------------- G, /, N
k_goto: ld hl,m_goto
	call prompt
	jr c,kg_x
	ld hl,v_in
	call hexword
	jr c,kg_bad
	call maxcur		; (past the end: the last byte)
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,kg_1
	ex de,hl
kg_1:	ld (v_cur),hl
	call seen
kg_x:	call status
	jp key
kg_bad: ld hl,m_badhex
	ld (v_msg),hl
	jr kg_x

k_find: ld hl,m_find
	call prompt
	jr c,kg_x
	call findpat
	jr c,kg_bad
k_next: ld a,(v_flen)
	or a
	jp z,key
	ld hl,(v_cur)		; from the byte after the cursor
	inc hl
	ld (v_i),hl
kf_1:	ld hl,(v_i)		; i + length <= the file's length?
	ld a,(v_flen)
	ld e,a
	ld d,0
	add hl,de
	ex de,hl
	ld hl,(v_len)
	or a
	sbc hl,de
	jr c,kf_no
	ld hl,(v_i)
	ld de,BUF
	add hl,de
	ld de,v_find
	ld a,(v_flen)
	ld b,a
kf_2:	ld a,(de)
	cp (hl)
	jr nz,kf_3
	inc hl
	inc de
	djnz kf_2
	ld hl,(v_i)		; found
	ld (v_cur),hl
	call seen
	call status
	jp key
kf_3:	ld hl,(v_i)
	inc hl
	ld (v_i),hl
	jr kf_1
kf_no:	ld hl,m_nofind
	ld (v_msg),hl
	call status
	jp key

findpat:			; v_in -> v_find: "text", or hex bytes.  CF = not that
	ld hl,v_in
	call pl_skip
	cp '"'
	jr nz,fp_hex
	inc hl
	ld de,v_find
	ld b,0
fp_t:	ld a,(hl)
	or a
	jr z,fp_te
	cp '"'
	jr z,fp_te
	ld (de),a
	inc hl
	inc de
	inc b
	ld a,b
	cp 16
	jr c,fp_t
fp_te:	ld a,b
	ld (v_flen),a
	or a
	scf
	ret z
	ccf
	ret
fp_hex: ld de,v_find
	ld b,0
fp_h1:	call pl_skip
	or a
	jr z,fp_te
	ld a,b
	cp 16
	jr nc,fp_te
	call hexd
	ret c
	ld c,a
	inc hl
	ld a,(hl)
	or a
	jr z,fp_h2
	cp ' '
	jr z,fp_h2
	call hexd
	ret c
	inc hl
	push af
	ld a,c
	rlca
	rlca
	rlca
	rlca
	ld c,a
	pop af
	or c
	ld c,a
fp_h2:	ld a,c
	ld (de),a
	inc de
	inc b
	jr fp_h1

hexd:	ld a,(hl)		; (HL) a hex digit -> A.  CF = not one
	call pl_upper
	sub '0'
	ret c
	cp 10
	ccf
	ret nc
	sub 7
	cp 10
	ret c
	cp 16
	ccf
	ret

hexword:			; HL = hex digits -> DE.  CF = not that
	call pl_skip
	ld de,0
	ld b,0
hw_1:	ld a,(hl)
	or a
	jr z,hw_e
	cp ' '
	jr z,hw_e
	call hexd
	ret c
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	or l
	ld l,a
	ex de,hl
	inc hl
	inc b
	ld a,b
	cp 5
	ccf
	ret c
	jr hw_1
hw_e:	ld a,b
	or a
	scf
	ret z
	ccf
	ret

; ---------------------------------------------------------------- W, Q
k_write:
	call save
	call status
	jp key

save:	ld hl,v_name		; HEXED.TMP there, then in the file's place
	call OS_RESOLVE
	jr c,sv_err
	push hl 		; (the name part)
	ld hl,m_tmp
	ld ix,v_fcb
	call OS_CREATE
	jr c,sv_err1
	ld de,BUF
	ld bc,(v_len)
	ld a,b
	or c
	jr z,sv_1
	ld ix,v_fcb
	call OS_WRITE
	jr c,sv_err1
sv_1:	ld ix,v_fcb
	call OS_CLOSE
	jr c,sv_err1
	pop hl
	push hl
	call OS_DELETE		; (not there yet: a new file)
	pop de
	ld hl,m_tmp
	call OS_RENAME
	jr c,sv_err
	xor a
	ld (v_chg),a
	ld hl,m_saved
	ld (v_msg),hl
	call title
	or a
	ret
sv_err1:
	pop hl
sv_err: call OS_ERRMSG
	ld (v_msg),hl
	scf
	ret

k_quit: ld a,(v_chg)
	or a
	jr z,quit
	ld hl,m_unsaved
	call prompt0
kq_1:	call OS_GETC
	call pl_upper
	cp 'P'
	jr z,kq_w
	cp 'Q'
	jr z,quit
	call status
	jp key
kq_w:	call save
	jr nc,quit
	call status
	jp key
quit:	xor a
	call OS_SCREEN
	ld sp,(v_sp)
	ret

; ---------------------------------------------------------------- load
load:				; the file -> BUF.  CF = it cannot be (said so)
	ld hl,0
	ld (v_len),hl
	ld (v_msg),hl
	ld hl,v_name
	call OS_RESOLVE
	jr c,ld_err
	ld ix,v_fcb
	call OS_OPEN
	jr nc,ld_1
	cp FS_ENOTF		; not there: a new file
	jr nz,ld_err
	ld hl,m_new
	ld (v_msg),hl
	or a
	ret
ld_1:	ld a,(v_fcb+FCB_SIZE+2) ; too big?
	or a
	jr nz,ld_big
	ld hl,(v_fcb+FCB_SIZE)
	ld de,BUFMAX+1
	or a
	sbc hl,de
	jr nc,ld_big
	ld ix,v_fcb
	ld de,BUF
	ld bc,BUFMAX
	call OS_READ
	jr c,ld_err
	ld (v_len),bc
	or a
	ret
ld_big: xor a
	call OS_SCREEN
	ld hl,m_big
	jp pl_fail1
ld_err: push af
	xor a
	call OS_SCREEN
	pop af
	call pl_err
	scf
	ret

; ---------------------------------------------------------------- the screen
redraw: 			; all of it
	xor a
	call OS_SCREEN
	xor a
	ld (v_r),a
	ld (v_c),a
	call title
	xor a
rd_1:	ld hl,v_dl
	cp (hl)
	jr nc,rd_2
	push af
	call drawline
	pop af
	inc a
	jr rd_1
rd_2:	ld a,(v_dl)		; the keys, under the status line
	add a,2
	ld d,a
	ld e,0
	call gotoxy
	ld hl,m_keys1
	call puts
	ld a,(v_dl)
	add a,3
	ld d,a
	ld e,0
	call gotoxy
	ld hl,m_keys2
	call puts
	jp status

title:				; the top line: "HEXED  NAME   1234 bytes"
	ld de,0
	call gotoxy
	ld hl,m_title
	call puts
	ld hl,v_name
	call puts
	ld a,' '
	call putc
	call putc
	ld hl,(v_len)
	call putdec
	ld hl,m_bytes
	call puts
	ld a,(v_c)		; (the rest: spaces, over what was there)
	ld b,a
	ld a,LW
	sub b
	ret c
	ret z
	ld b,a
	jp spaces

drawline:			; A = a line (0 ..) of bytes: drawn
	push af
	inc a
	ld d,a
	ld e,0
	call gotoxy
	pop af
	ld l,a			; HL = the offset of its first byte
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,(v_top)
	add hl,de
	ld (v_n),hl
	ex de,hl		; past the end: blank (but the line where one is added)
	ld hl,(v_len)
	or a
	sbc hl,de
	jr nc,dl_1
	ld b,LW
	jp spaces
dl_1:	ld hl,(v_n)
	call puthex16
	ld a,' '
	call putc
	call putc
	ld c,0
dl_2:	ld a,c			; the bytes in hex
	cp 8
	ld a,' '
	call z,putc
	call dl_byte
	jr c,dl_3
	call puthex8
	jr dl_4
dl_3:	ld a,' '
	call putc
	call putc
dl_4:	ld a,' '
	call putc
	inc c
	ld a,c
	cp 16
	jr nz,dl_2
	ld a,'|'		; then as text
	call putc
	ld c,0
dl_5:	call dl_byte
	jr nc,dl_6
	ld a,' '
	jr dl_7
dl_6:	call printable
dl_7:	call putc
	inc c
	ld a,c
	cp 16
	jr nz,dl_5
	ld a,'|'
	jp putc
dl_byte:			; A = byte C of this line.  CF = past the end
	push hl
	push de
	ld hl,(v_n)
	ld e,c
	ld d,0
	add hl,de
	ex de,hl
	ld hl,(v_len)
	scf
	sbc hl,de		; len - 1 - offset: CF = past the end
	jr c,db_x
	ld hl,BUF
	add hl,de
	ld a,(hl)
	or a
db_x:	pop de
	pop hl
	ret

drawbyte:			; HL = an offset on the screen: its two places again
	ld (v_n),hl
	call xy_of		; D = the row, E = the byte's place (0-15)
	push de
	ld a,e
	call hexcol
	ld e,a
	call gotoxy
	ld hl,(v_n)
	ld de,BUF
	add hl,de
	ld a,(hl)
	push af
	call puthex8
	pop af
	pop de
	push af
	ld a,e
	add a,57
	ld e,a
	call gotoxy
	pop af
	call printable
	jp putc

xy_of:				; HL = an offset -> D = its screen row, E = its place
	ld de,(v_top)		; in the line
	or a
	sbc hl,de
	ld a,l
	and 0Fh
	ld e,a
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld a,l
	inc a
	ld d,a
	ret

hexcol: 			; A = a place (0-15) -> A = its hex column
	ld b,a
	add a,a
	add a,b
	add a,6
	ld c,a
	ld a,b
	cp 8
	ld a,c
	ret c
	inc a
	ret

printable:			; A -> itself, or "." if it is not printable
	cp 20h
	jr c,pr_dot
	cp 7Fh
	ret c
pr_dot: ld a,'.'
	ret

seen:				; the cursor's byte on the screen: else a new page
	ld hl,(v_cur)		; with it in the middle
	ld de,(v_top)
	or a
	sbc hl,de
	jr c,se_new
	call pagebytes
	or a
	sbc hl,de
	ret c
se_new: ld hl,(v_cur)
	ld a,l
	and 0F0h
	ld l,a
	ld a,(v_dl)		; (top = its line - half the lines)
	srl a
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ex de,hl
	or a
	sbc hl,de
	jr nc,se_1
	ld hl,0
se_1:	ld (v_top),hl
	jp redraw

place:				; the terminal's cursor where the editing is
	ld hl,(v_cur)
	call xy_of
	ld a,(v_pane)
	or a
	jr nz,pl_text
	ld a,e
	call hexcol
	ld e,a
	ld a,(v_nib)
	add a,e
	ld e,a
	jp gotoxy
pl_text:
	ld a,e
	add a,57
	ld e,a
	jp gotoxy

status: 			; the line under the bytes: where, what, how
	ld de,v_sbuf
	ld hl,m_at
	call pl_cat
	ld hl,(v_cur)
	call shex16
	ld hl,m_of
	call pl_cat
	ld hl,(v_len)
	call shex16
	ld hl,(v_cur)		; the byte there: hex, decimal, character
	ld bc,(v_len)
	or a
	sbc hl,bc
	jr nc,stt_1
	add hl,bc
	ld bc,BUF
	add hl,bc
	ld a,(hl)
	push af
	ld hl,m_byte
	call pl_cat
	pop af
	push af
	call shex8
	ld a,' '
	ld (de),a
	inc de
	pop af
	push af
	call sdec8
	ld hl,m_q1
	call pl_cat
	pop af
	call printable
	ld (de),a
	inc de
	ld a,27h		; (')
	ld (de),a
	inc de
stt_1:	ld hl,m_hexs
	ld a,(v_pane)
	or a
	jr z,stt_2
	ld hl,m_texts
stt_2:	call pl_cat
	ld a,(v_mode)
	or a
	jr z,stt_3
	ld hl,m_editing
	call pl_cat
stt_3:	ld a,(v_chg)
	or a
	jr z,stt_4
	ld hl,m_changed
	call pl_cat
stt_4:	ld hl,(v_msg)		; a message: once
	ld a,h
	or l
	jr z,stt_5
	push hl
	ld hl,m_sp2
	call pl_cat
	pop hl
	call pl_cat
	ld hl,0
	ld (v_msg),hl
stt_5:	ld a,(v_dl)
	inc a
	ld d,a
	ld e,0
	call gotoxy
	ld hl,v_sbuf
	call puts
	ld a,(v_c)		; spaces over the rest
	ld b,a
	ld a,LW+2
	sub b
	ret c
	ret z
	ld b,a
	jp spaces

prompt: 			; HL = a question on the status line: a typed line ->
	call prompt0		; v_in.  CF = Esc
	ld hl,v_in
	ld b,0
pq_1:	call OS_GETC
	cp 1Bh
	scf
	ret z
	cp 13
	jr z,pq_e
	cp 8
	jr z,pq_bs
	cp 7Fh
	jr z,pq_bs
	cp ' '
	jr c,pq_1
	ld c,a
	ld a,b
	cp 32
	jr nc,pq_1
	ld a,c
	ld (hl),a
	inc hl
	inc b
	call putc
	jr pq_1
pq_bs:	ld a,b
	or a
	jr z,pq_1
	dec hl
	dec b
	push hl
	ld a,S_LEFT
	call OS_SCREEN
	ld a,' '
	call OS_PUTC
	ld a,S_LEFT
	call OS_SCREEN
	pop hl
	ld a,(v_c)
	dec a
	ld (v_c),a
	jr pq_1
pq_e:	ld (hl),0
	or a
	ret
prompt0:			; the status line: HL, and spaces after it
	push hl
	ld a,(v_dl)
	inc a
	ld d,a
	ld e,0
	call gotoxy
	ld b,LW+2
	call spaces
	ld a,(v_dl)
	inc a
	ld d,a
	ld e,0
	call gotoxy
	pop hl
	jp puts

; ---------------------------------------------------------------- the cursor
gotoxy: 			; D = row, E = column: the terminal's cursor there, by
	ld a,(v_home)		; moves (from HOME, if that is fewer)
	or a
	jr z,gx_rel
	ld a,(v_r)		; |row - D| + |col - E|  against  D + E + 1
	sub d
	jr nc,gx_1
	neg
gx_1:	ld b,a
	ld a,(v_c)
	sub e
	jr nc,gx_2
	neg
gx_2:	add a,b
	ld b,a			; B = the moves from here
	ld a,d
	add a,e
	inc a
	cp b
	jr nc,gx_rel
	ld a,S_HOME
	call OS_SCREEN
	xor a
	ld (v_r),a
	ld (v_c),a
gx_rel: ld a,(v_r)		; up or down
	cp d
	jr z,gx_h
	jr c,gx_dn
	ld a,S_UP
	call OS_SCREEN
	ld hl,v_r
	dec (hl)
	jr gx_rel
gx_dn:	ld a,S_DOWN
	call OS_SCREEN
	ld hl,v_r
	inc (hl)
	jr gx_rel
gx_h:	ld a,(v_c)		; then left or right (CR first, if that is fewer)
	cp e
	ret z
	jr c,gx_rt
	sub e			; A = moves left; CR then E right?
	ld b,a
	ld a,e
	inc a
	cp b
	jr nc,gx_lf
	ld a,13
	call OS_PUTC
	xor a
	ld (v_c),a
	jr gx_h
gx_lf:	ld a,S_LEFT
	call OS_SCREEN
	ld hl,v_c
	dec (hl)
	jr gx_h
gx_rt:	ld a,S_RIGHT
	call OS_SCREEN
	ld hl,v_c
	inc (hl)
	jr gx_h

putc:	push hl 		; A to the screen (the column counted)
	call OS_PUTC
	ld hl,v_c
	inc (hl)
	pop hl
	ret
puts:	ld a,(hl)
	or a
	ret z
	call putc
	inc hl
	jr puts
spaces: ld a,' '		; B spaces
sp_1:	call putc
	djnz sp_1
	ret
puthex8:
	push af
	rrca
	rrca
	rrca
	rrca
	call ph_1
	pop af
ph_1:	and 0Fh
	add a,'0'
	cp '9'+1
	jr c,ph_2
	add a,7
ph_2:	jp putc
puthex16:
	ld a,h
	call puthex8
	ld a,l
	jp puthex8
putdec: 			; HL in decimal (the column counted)
	ld de,v_in
	push de
	call sdec16
	xor a
	ld (de),a
	pop hl
	jp puts

; (into the text at DE: hex, decimal)
shex16: ld a,h
	call shex8
	ld a,l
shex8:	push af
	rrca
	rrca
	rrca
	rrca
	call sh_1
	pop af
sh_1:	and 0Fh
	add a,'0'
	cp '9'+1
	jr c,sh_2
	add a,7
sh_2:	ld (de),a
	inc de
	xor a
	ld (de),a
	ret
sdec8:	ld l,a
	ld h,0
sdec16: 			; HL -> decimal at DE (no leading zeros)
	xor a
	ld (v_dz),a
	ld bc,10000
	call sd_d
	ld bc,1000
	call sd_d
	ld bc,100
	call sd_d
	ld bc,10
	call sd_d
	ld a,l
	add a,'0'
	ld (de),a
	inc de
	xor a
	ld (de),a
	ret
sd_d:	ld a,'0'-1		; one digit: HL / BC
sd_1:	inc a
	or a
	sbc hl,bc
	jr nc,sd_1
	add hl,bc
	cp '0'
	jr nz,sd_2
	ld b,a
	ld a,(v_dz)		; a leading 0: left out
	or a
	ret z
	ld a,b
sd_2:	ld (de),a
	inc de
	ld a,1
	ld (v_dz),a
	ret

; ---------------------------------------------------------------- the end
small:	ld hl,m_small
	jp pl_fail
nomoves:
	ld hl,m_moves
	jp pl_fail
use:	ld hl,m_use
	jp pl_fail
pl_fail1:
	call pl_fail
	scf
	ret

m_use:	defm "HEXED [d:][dir\\]name   (a full-screen hex editor)"
	defb 0
m_small:
	defm "HEXED needs a screen of 8 rows and 76 columns at least (SCREEN ROWS, COLS)"
	defb 0
m_moves:
	defm "HEXED needs the terminal's cursor moves UP DOWN LEFT RIGHT: run SETUP"
	defb 0
m_big:	defm "too big for HEXED (26 KB at most)"
	defb 0
m_title:
	defm "HEXED  "
	defb 0
m_bytes:
	defm " bytes"
	defb 0
m_keys1:
	defm "A D W S move  Space B page  T E top end  G go to  / N find  Tab hex/text"
	defb 0
m_keys2:
	defm "Return edit (Esc ends)  I insert 00  X delete  P put on disk  Q quit"
	defb 0
m_at:	defm "at "
	defb 0
m_of:	defm " of "
	defb 0
m_byte: defm "   "
	defb 0
m_q1:	defm " '"
	defb 0
m_hexs: defm "   hex"
	defb 0
m_texts:
	defm "   text"
	defb 0
m_editing:
	defm "  EDITING"
	defb 0
m_changed:
	defm "  changed"
	defb 0
m_sp2:	defm "  "
	defb 0
m_goto: defm "go to (hex offset): "
	defb 0
m_find: defm "find (hex bytes, or ",34,"text",34,"): "
	defb 0
m_badhex:
	defm "(hex, please)"
	defb 0
m_nofind:
	defm "not found"
	defb 0
m_full: defm "full (26 KB)"
	defb 0
m_new:	defm "a new file"
	defb 0
m_saved:
	defm "written"
	defb 0
m_unsaved:
	defm "Not on the disk yet: P put it there and quit, Q quit anyway, another key back "
	defb 0
m_tmp:	defm "HEXED.TMP"
	defb 0

	include "PROGRAMS/PLIB.INC"
