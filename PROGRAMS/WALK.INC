; ==========================================================================
; WALK.INC - a path being walked (TREE, XCOPY): v_path (80 bytes), v_plen,
; v_tmp (80 bytes) are the program's.
;
;   w_norm    v_path: a \ after it unless it is empty or ends in \ or :;
;             v_plen = its length
;   w_add     HL = a name: v_path + name + \.  CF = too long (v_path as it was)
;   w_res     go to v_path's directory (OS_RESOLVE of v_path + "*").  CF = no
;             (the error is printed)
; ==========================================================================
W_MAX:	equ 70

w_norm: ld hl,v_path
	ld b,0
wn_1:	ld a,(hl)
	or a
	jr z,wn_2
	inc hl
	inc b
	jr wn_1
wn_2:	ld a,b
	ld (v_plen),a
	or a
	ret z
	dec hl
	ld a,(hl)
	inc hl
	cp 5Ch
	ret z
	cp ':'
	ret z
	ld (hl),5Ch
	inc hl
	ld (hl),0
	ld hl,v_plen
	inc (hl)
	ret

w_add:	ld a,(v_plen)
	ld e,a
	ld d,0
	push hl
	ld hl,v_path
	add hl,de
	ex de,hl		; DE = the end of the path
	pop hl
	ld b,a
wa_1:	ld a,(hl)
	or a
	jr z,wa_2
	ld (de),a
	inc hl
	inc de
	inc b
	ld a,b
	cp W_MAX
	jr nc,wa_long
	jr wa_1
wa_2:	ld a,5Ch
	ld (de),a
	inc de
	xor a
	ld (de),a
	inc b
	ld a,b
	ld (v_plen),a
	or a
	ret
wa_long:
	ld a,(v_plen)		; as it was
	ld e,a
	ld d,0
	ld hl,v_path
	add hl,de
	ld (hl),0
	scf
	ret

w_res:	ld hl,v_path		; v_tmp = v_path + "*"
	ld de,v_tmp
	call pl_cat
	ld a,'*'
	ld (de),a
	inc de
	xor a
	ld (de),a
	ld hl,v_tmp
	call OS_RESOLVE
	ret nc
	push af
	ld hl,v_path
	call OS_PUTS
	ld a,':'
	call OS_PUTC
	ld a,' '
	call OS_PUTC
	pop af
	call pl_err
	scf
	ret
