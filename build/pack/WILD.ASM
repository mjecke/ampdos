; ==========================================================================
; WILD.ASM - names with wildcards:  *.BAS   TEST?.TXT   A*   *.*
;
;   wc_make    HL = a name as typed      wc_pat = it in directory form, with
;                                        "?" for each wildcard place; wc_on =
;                                        1 if it has a wildcard.  CF = not a
;                                        valid name (A = FS_ENAME).  Keeps HL
;   wc_match   HL = a directory entry    Z = its name fits wc_pat.  Keeps all
;                                        but AF
;
; "?" stands for any one character (or none, at the end of a part), "*" for
; the rest of the name or of the extension: "A*.B?S" is "A???????B?S".  A
; name without a dot that ends in "*" takes any extension, so "*" is "*.*".
; Without wildcards wc_pat is the same as fs_name83 would make.
; ==========================================================================

wc_make:
	push hl
	ld hl,wc_pat		; start from all spaces
	ld b,11
wm_1:	ld (hl),' '
	inc hl
	djnz wm_1
	xor a
	ld (wc_on),a
	pop hl
	push hl
	ld de,wc_pat
	ld b,8			; the name part: 1 to 8 places
	call wm_part
	jr c,wm_bad
	ld a,b
	cp 8
	jr z,wm_bad		; nothing before the dot
	ld a,(hl)
	cp '.'
	jr nz,wm_nodot
	inc hl
	ld de,wc_pat+8
	ld b,3			; the extension: 0 to 3 places
	call wm_part
	jr c,wm_bad
	ld a,(hl)
	cp '.'
	jr z,wm_bad		; a second dot
	jr wm_end
wm_nodot:
	dec c			; no dot: did the name end with "*"?
	jr nz,wm_end
	ld a,'?'		; then any extension
	ld (wc_pat+8),a
	ld (wc_pat+9),a
	ld (wc_pat+10),a
wm_end: call fn_term
	jr nz,wm_bad		; something left over
	pop hl
	or a
	ret
wm_bad: pop hl
	ld a,FS_ENAME
	scf
	ret

wm_part:			; one part to DE, at most B places.  B = places left,
	ld c,0			; C = 1 if it ended with "*".  CF = bad
wp_1:	ld a,(hl)
	cp '.'
	ret z
	call fn_term
	ret z
	cp '*'
	jr z,wp_star
	cp '?'
	jr z,wp_q
	call fn_char
	ret c
wp_put: inc b			; room left?
	dec b
	scf
	ret z
	ld (de),a
	inc de
	inc hl
	dec b
	jr wp_1
wp_q:	ld a,1
	ld (wc_on),a
	ld a,'?'
	jr wp_put
wp_star:
	ld a,1
	ld (wc_on),a
	ld c,a
wps_1:	inc b			; the rest of the part: "?"
	dec b
	jr z,wps_2
	ld a,'?'
	ld (de),a
	inc de
	dec b
	jr wps_1
wps_2:	inc hl			; (what follows a "*" in the same part does not count)
	ld a,(hl)
	cp '.'
	ret z
	call fn_term
	ret z
	jr wps_2

wc_match:
	push hl
	push de
	push bc
	ld de,wc_pat
	ld b,11
wmt_1:	ld a,(de)
	cp '?'
	jr z,wmt_2
	cp (hl)
	jr nz,wmt_no
wmt_2:	inc hl
	inc de
	djnz wmt_1
	xor a			; Z: it fits
wmt_no: pop bc
	pop de
	pop hl
	ret
