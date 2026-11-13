; ==========================================================================
; HISTORY.ASM - the command history: the lines typed at the prompt, for Up
; and Down (LIB/GETLINE.ASM), and HISTORY to list them.
; HIST (KERNEL/INC/RAM.INC) holds them packed, oldest first, each ending with
; a 0; hs_end points just past the newest.  When a new line does not fit, the
; oldest lines make room.  256 bytes: some 15 to 30 commands.
;   hs_add     HL = a line     keep it (not an empty one, nor the newest again)
; ==========================================================================

hs_add: 			; keep the line at HL in the history (not an empty one,
	push hl 		; nor the newest again).  Keeps HL
	call sh_skipsp
	ld a,(hl)
	pop hl
	or a
	ret z
	ld a,1			; the same as the newest?
	call hs_get
	jr c,ha_new
	push hl
ha_cmp: ld a,(bc)
	cp (hl)
	jr nz,ha_diff
	inc hl
	inc bc
	or a
	jr nz,ha_cmp
	pop hl			; the same: nothing to do
	ret
ha_diff:
	pop hl
ha_new: push hl 		; C = its length with the 0
	ld c,0
ha_len: inc c
	ld a,(hl)
	inc hl
	or a
	jr nz,ha_len
	pop hl
ha_fit: push hl 		; room for it?  (used + C <= HISTLEN)
	ld hl,(hs_end)
	ld de,HIST
	or a
	sbc hl,de		; HL = used
	push hl
	ld b,0
	add hl,bc
	ld de,HISTLEN+1
	or a
	sbc hl,de
	pop de			; DE = used
	pop hl
	jr c,ha_copy
	push hl 		; no: the oldest line goes
	push bc
	ld hl,HIST		; B = its length with the 0
	ld b,0
ha_old: inc b
	ld a,(hl)
	inc hl
	or a
	jr nz,ha_old
	ex de,hl		; HL = used, DE = the line after it
	ld c,b
	ld b,0
	or a
	sbc hl,bc		; HL = what stays
	push hl
	ld hl,(hs_end)
	sbc hl,bc		; (no carry: the end is past the oldest line)
	ld (hs_end),hl
	pop bc
	ld a,b
	or c
	jr z,ha_old1		; nothing stays (LDIR would copy 64 KB)
	ex de,hl
	ld de,HIST
	ldir
ha_old1:
	pop bc
	pop hl
	jr ha_fit
ha_copy:
	push hl 		; copy it to the end
	ld de,(hs_end)
	ld b,0
	ldir
	ld (hs_end),de
	pop hl
	ret

cmd_history:			; HISTORY: the lines kept, oldest first
	ld hl,HIST
chi_1:	ld de,(hs_end)
	or a
	sbc hl,de
	add hl,de
	ret z
	ld a,(hl)
	inc hl
	or a
	jr z,chi_2
	call con_putc
	jr chi_1
chi_2:	call con_crlf
	jr chi_1
