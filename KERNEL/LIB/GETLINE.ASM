; ==========================================================================
; GETLINE.ASM - read a line from the keyboard, with backspace, and (at the
; shell's prompt) the command history.
;
;   con_getline   HL = buffer, B = most characters allowed
;                 returns B = characters typed; the buffer ends with a 0.
;                 Return ends the line; Backspace or Delete removes the last
;                 character; other control keys are ignored.
; Preserves HL.
;
; With gl_hist = 1 (the shell sets it for its prompt, programs never get it):
;   Up arrow or Ctrl-P     the line before (again: the one before that ...)
;   Down arrow or Ctrl-N   the line after (past the newest: an empty line)
;   Esc                    clear the line
; The arrows come from a terminal as Esc [ A and Esc [ B (or Esc O A / B);
; an Esc with nothing after it within ~40 ms is the Esc key itself.
; The line shown is erased with backspace, space, backspace and the other one
; typed out, so this works on any terminal.  The history itself is in HIST
; (KERNEL/INC/RAM.INC): hs_get finds a line there; the shell's hs_add
; (SHELL/HISTORY.ASM) keeps them.
; ==========================================================================

con_getline:
	push hl
	push de
	ld d,b			; D = room
	ld e,0			; E = typed so far
	xor a
	ld (hs_pos),a
gl_key: call con_getc
	cp 13
	jr z,gl_done
	cp 8
	jr z,gl_bs
	cp 7Fh
	jr z,gl_bs
	ld c,a
	ld a,(gl_hist)		; the history keys, at the shell's prompt only
	or a
	ld a,c
	jr z,gl_char
	cp 10h			; Ctrl-P
	jr z,gl_up
	cp 0Eh			; Ctrl-N
	jp z,gl_down
	cp 1Bh
	jr z,gl_esc
gl_char:
	cp ' '
	jr c,gl_key		; other control keys: ignore
	ld b,a
	ld a,e
	cp d
	jr nc,gl_key		; full: ignore
	ld a,b
	ld (hl),a
	inc hl
	inc e
	call con_putc		; echo
	jr gl_key
gl_bs:	ld a,e
	or a
	jr z,gl_key		; nothing to remove
	call gl_back
	jr gl_key
gl_done:
	ld (hl),0
	ld b,e
	call con_crlf
	pop de
	pop hl
	ret

gl_back:			; take back one character: HL, E and the screen
	dec hl
	dec e
	ld a,8			; back, space, back
	call con_putc
	ld a,' '
	call con_putc
	ld a,8
	jp con_putc

gl_erase:			; take back the whole line
	ld a,e
	or a
	ret z
	call gl_back
	jr gl_erase

gl_esc: call gl_wait		; Esc [ A, Esc O B ... or the Esc key alone?
	jr c,gl_clear
	call con_getc
	cp '['
	jr z,gl_e1
	cp 'O'
	jr nz,gl_key		; something else: forget both
gl_e1:	call gl_wait
	jr c,gl_key
	call con_getc
	cp '0'			; (Esc [ 1 ; 5 A and the like: skip the numbers)
	jr c,gl_e2
	cp ';'+1
	jr c,gl_e1
gl_e2:	cp 'A'
	jr z,gl_up
	cp 'B'
	jr z,gl_down
	jp gl_key		; left, right, ...: nothing (yet)
gl_clear:
	call gl_erase
	xor a
	ld (hs_pos),a
	jp gl_key

gl_up:	ld a,(hs_pos)		; one line further back, if there is one
	inc a
	call hs_get
	jp c,gl_key
	ld (hs_pos),a
	jr gl_set
gl_down:
	ld a,(hs_pos)		; one line forward; past the newest: empty
	or a
	jp z,gl_key
	dec a
	ld (hs_pos),a
	jr z,gl_clear
	call hs_get
gl_set: call gl_erase		; BC = the line to show instead
gs_1:	ld a,e
	cp d
	jp nc,gl_key
	ld a,(bc)
	or a
	jp z,gl_key
	ld (hl),a
	inc hl
	inc e
	inc bc
	call con_putc
	jr gs_1

gl_wait:			; wait up to ~40 ms for a key.  CF = none came
	push bc
	ld bc,1200
glw_1:	call con_kbhit
	jr nz,glw_2
	dec bc
	ld a,b
	or c
	jr nz,glw_1
	pop bc
	scf
	ret
glw_2:	pop bc
	or a
	ret

; ---------------------------------------------------------------- the history
; HIST holds the lines oldest first, each ending with a 0, and hs_end points
; just past the newest.  hs_get counts back from there.

hs_get: 			; A = n (1 = the newest) -> BC = that line.  CF = there
	push hl 		; are fewer lines.  Keeps A, DE, HL
	push de
	push af
	ld b,a
	ld hl,(hs_end)
hg_1:	ld de,HIST		; HL = just past a line's 0 (or the end)
	or a
	sbc hl,de
	jr z,hg_none		; at the start: no line before
	add hl,de
	dec hl			; on that line's 0
hg_2:	or a			; back to its first character: HIST, or just after a 0
	sbc hl,de
	add hl,de
	jr z,hg_3
	dec hl
	ld a,(hl)
	or a
	jr nz,hg_2
	inc hl
hg_3:	djnz hg_1		; (its start is "just past" the line before it)
	ld b,h
	ld c,l
	pop af
	pop de
	pop hl
	or a
	ret
hg_none:
	pop af
	pop de
	pop hl
	scf
	ret
