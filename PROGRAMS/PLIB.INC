; ==========================================================================
; PLIB.INC - small helpers shared by the utility programs (ATTRIB, TREE,
; XCOPY, UNDELETE, HEAD, TAIL, TR, DIFF, DISKCOMP).  Include it after
; KERNEL/INC/OS.INC and KERNEL/FS/FS.INC; the program defines P_PAT (11
; bytes) and P_NAME (13 bytes).  Only the OS call table is used.
;
;   pl_skip      HL past spaces (A = the character there)
;   pl_word      HL = text -> DE: its next word, zero-terminated, quotes kept
;               out ("a b" is one word); HL after it.  Z = there was none
;   pl_upper     A in upper case
;   pl_dec       HL = text -> DE = a decimal number (HL after it).  CF = none
;   pl_err       A = an error code: print its text, set status 1
;   pl_fail      HL = a message: print it, set status 1
;   pl_pat       HL = a name, may hold * and ? -> P_PAT: 11 bytes, "NAME    EXT"
;               with ? for any character (empty: every name)
;   pl_match     HL = a directory entry -> Z = its name fits P_PAT
;   pl_ename     HL = a directory entry -> DE: "NAME.EXT", 0 (13 bytes); kept
;   pl_entry     HL = a directory entry -> Z = a file or a directory worth
;               listing (not free, deleted, a long-name piece, the label,
;               "." or ".."); A = its attributes
;   pl_cat       DE = the end of a string, HL = text: add it (DE = new end, 0)
; ==========================================================================

pl_skip: ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr pl_skip

pl_word: call pl_skip
	or a
	ret z
	cp '"'
	jr z,pw_q
pw_1:	ld a,(hl)
	or a
	jr z,pw_e
	cp ' '
	jr z,pw_e
	ld (de),a
	inc hl
	inc de
	jr pw_1
pw_q:	inc hl
pw_q1:	ld a,(hl)
	or a
	jr z,pw_e
	inc hl
	cp '"'
	jr z,pw_e
	ld (de),a
	inc de
	jr pw_q1
pw_e:	xor a
	ld (de),a
	inc a			; NZ: a word
	ret

pl_upper:
	cp 'a'
	ret c
	cp 'z'+1
	ret nc
	sub 20h
	ret

pl_dec:	call pl_skip
	ld de,0
	sub '0'
	cp 10
	jr nc,pd_none
pd_1:	ld a,(hl)
	sub '0'
	cp 10
	jr nc,pd_done
	inc hl
	push hl
	ld h,d
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
	jr pd_1
pd_done:
	or a
	ret
pd_none:
	scf
	ret

pl_err:	call OS_ERRMSG
pl_fail: call OS_PUTS
	call OS_CRLF
	ld a,1
	jp OS_STATUS

pl_pat:	ld de,P_PAT		; "NAME.EXT" with wildcards -> 11 bytes
	ld b,11
	ld a,' '
pp_0:	ld (de),a
	inc de
	djnz pp_0
	ld de,P_PAT
	ld a,(hl)
	or a
	jr nz,pp_1
	ld b,11 		; nothing: every name
	ld a,'?'
pp_all: ld (de),a
	inc de
	djnz pp_all
	ret
pp_1:	ld b,8			; the name part
	call pp_part
	ld a,(hl)
	cp '.'
	jr nz,pp_noext
	inc hl
	ld de,P_PAT+8
	ld b,3
	jp pp_part
pp_noext:			; "NAME*" without a dot: any extension
	ld a,(P_PAT+7)
	cp '?'
	ret nz
	ld a,'?'
	ld (P_PAT+8),a
	ld (P_PAT+9),a
	ld (P_PAT+10),a
	ret
pp_part:			; B characters at most into DE, from HL, up to . or the end
	ld a,(hl)
	or a
	ret z
	cp '.'
	ret z
	cp ' '
	ret z
	inc hl
	cp '*'
	jr z,pp_star
	call pl_upper
	ld (de),a
	inc de
	djnz pp_part
pp_skip:			; (too long: the rest is left out)
	ld a,(hl)
	or a
	ret z
	cp '.'
	ret z
	inc hl
	jr pp_skip
pp_star:
	ld a,'?'
pp_s1:	ld (de),a
	inc de
	djnz pp_s1
	jr pp_skip

pl_match:
	push hl
	push de
	push bc
	ld de,P_PAT
	ld b,11
pm_1:	ld a,(de)
	cp '?'
	jr z,pm_2
	cp (hl)
	jr nz,pm_3
pm_2:	inc hl
	inc de
	djnz pm_1
	xor a			; Z
pm_3:	pop bc
	pop de
	pop hl
	ret

pl_ename:
	push hl
	ld de,P_NAME
	ld b,8
pe_1:	ld a,(hl)
	cp ' '
	jr z,pe_2
	ld (de),a
	inc de
pe_2:	inc hl
	djnz pe_1
	ld a,(hl)		; an extension?
	cp ' '
	jr z,pe_4
	ld a,'.'
	ld (de),a
	inc de
	ld b,3
pe_3:	ld a,(hl)
	cp ' '
	jr z,pe_4
	ld (de),a
	inc de
	inc hl
	djnz pe_3
pe_4:	xor a
	ld (de),a
	pop hl
	ld de,P_NAME
	ret

pl_entry:
	ld a,(hl)
	or a
	jr z,pn_no
	cp 0E5h
	jr z,pn_no
	cp '.'
	jr z,pn_no
	push hl
	ld de,DE_ATTR
	add hl,de
	ld a,(hl)
	pop hl
	cp ATTR_LFN
	jr z,pn_no
	bit 3,a 		; the volume label
	jr nz,pn_no
	cp a			; Z
	ret
pn_no:	or 1			; NZ
	ret

pl_cat:	ld a,(hl)
	ld (de),a
	or a
	ret z
	inc hl
	inc de
	jr pl_cat
