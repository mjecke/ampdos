; ==========================================================================
; ASMEXPR.ASM - ASM: names, the symbol table, numbers and expressions.
;
;   skipsp    HL = text -> HL at the first character that is not a space or
;             a tab, A = that character
;   iseos     A = a character: Z = the end of the statement (0 or ;)
;   getid     HL = text: a name there?  DE = its start, B = its length,
;             C = its hash, HL = after it.  CF = no name (HL unchanged)
;   symfind   DE, B, C = a name -> HL = its value's address.  CF = not defined
;   symadd    DE, B, C = a name, HL = its value: a new symbol
;   expr      HL = text -> DE = its value, HL = after it.  v_undef = 1 if it
;             used a name with no value (yet); that name counts as 0
;   upper     A = a character -> upper case
; ==========================================================================

skipsp: ld a,(hl)
	cp ' '
	jr z,sk_1
	cp 9
	ret nz
sk_1:	inc hl
	jr skipsp

iseos:	cp ';'
	ret z
	or a
	ret

upper:	cp 'a'
	ret c
	cp 'z'+1
	ret nc
	sub 20h
	ret

; idchr: A = a character: NC = it may be in a name (a letter, a digit, _ or .)
idchr:	cp '_'
	jr z,ic_y
	cp '.'
	jr z,ic_y
alnum:	cp '0'			; (alnum: NC = a letter or a digit)
	ret c
	cp '9'+1
	jr c,ic_y
	cp 'A'
	ret c
	cp 'Z'+1
	jr c,ic_y
	cp 'a'
	ret c
	cp 'z'+1
	ccf
	ret
ic_y:	or a
	ret

getid:	ld a,(hl)
	call idchr
	ret c
	cp '0'			; a digit starts a number, not a name
	jr c,gi_go
	cp '9'+1
	jr nc,gi_go
	scf
	ret
gi_go:	ld d,h
	ld e,l
	ld bc,0 		; B = length, C = hash
gi_1:	ld a,(hl)
	call idchr
	jr c,gi_end
	rlc c			; hash = (hash rotated left) xor character
	xor c
	ld c,a
	inc hl
	inc b
	jr gi_1
gi_end: or a			; NC
	ret

; ---------------------------------------------------------------- symbols
; A symbol: next (word), value (word), name (its last character + 80h).
; Each of the 256 chains in HASH holds the names with one hash.

headp:	push hl 		; A = a hash -> DE = the address of its chain
	ld l,a
	ld h,0
	add hl,hl
	ld de,HASH
	add hl,de
	ex de,hl
	pop hl
	ret

symfind:
	push de
	ld a,c
	call headp
	ex de,hl		; HL = the chain
	pop de
sf_1:	ld a,(hl)		; the next symbol in it
	inc hl
	ld h,(hl)
	ld l,a
	or h
	jr z,sf_no
	push hl
	push de
	push bc
	inc hl			; its name
	inc hl
	inc hl
	inc hl
sf_2:	ld a,(de)
	xor (hl)		; 0 = the same, 80h = the same and the symbol's last
	jr z,sf_3
	cp 80h
	jr nz,sf_diff
	dec b			; the symbol's name ends here: ours must too
	jr nz,sf_diff
	pop bc
	pop de
	pop hl
	inc hl			; found: HL = its value
	inc hl
	or a
	ret
sf_3:	inc hl
	inc de
	djnz sf_2
sf_diff:			; (ours ended first, or a different character)
	pop bc
	pop de
	pop hl
	jr sf_1
sf_no:	scf
	ret

symadd: ld (v_tmp),hl		; the value
	push de
	ld hl,(v_symtop)	; room for 4 + length bytes?
	ld e,b
	ld d,0
	add hl,de
	inc hl
	inc hl
	inc hl
	inc hl
	ex de,hl		; DE = the new end
	ld hl,(v_memtop)
	or a
	sbc hl,de
	jp c,e_full
	ld hl,(v_symtop)
	ld (v_symtop),de
	push hl 		; HL = the new symbol: in front of its chain
	ld a,c
	call headp
	ld a,(de)		; its next = the chain's first
	ld (hl),a
	inc hl
	inc de
	ld a,(de)
	ld (hl),a
	inc hl
	ex (sp),hl		; the chain's first = it
	ld a,h
	ld (de),a
	dec de
	ld a,l
	ld (de),a
	pop hl
	ld de,(v_tmp)		; its value
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	pop de			; its name
sa_1:	ld a,(de)
	inc de
	dec b
	jr z,sa_2
	ld (hl),a
	inc hl
	jr sa_1
sa_2:	or 80h
	ld (hl),a
	ld hl,(v_nsym)
	inc hl
	ld (v_nsym),hl
	ret

; ---------------------------------------------------------------- expressions
; Precedence, from the loosest:  |   ^   &   << >>   + -   * / %
; and in front of a value: - + ~ ( ).  The arithmetic is 16-bit.
expr:	xor a
	ld (v_undef),a
ex_any: ld b,1			; take every operator
ex_prec:			; B = take only operators of this precedence or more
	push bc
	call unary		; DE = the left side
	pop bc
ex_loop:
	call skipsp
	call binop		; C = the operator, A = its precedence
	ret c			; none: done
	cp b
	ret c			; looser than we may take: our caller's
	inc a			; its right side: only what binds tighter
	push bc 		; (B, and C = the operator)
	push de 		; the left side
	ld b,a
	inc hl			; past the operator (<< and >> are two characters)
	ld a,c
	cp 3
	jr z,el_2
	cp 4
	jr nz,el_1
el_2:	inc hl
el_1:	call ex_prec		; DE = the right side
	ld (v_txt),hl
	pop hl			; HL = the left side
	pop bc
	call apply		; DE = HL op DE
	ld hl,(v_txt)
	jr ex_loop

; binop: A = the character at HL: an operator?  C = its number, A = its
; precedence (HL does not move).  CF = not an operator.
binop:	ld c,0
	cp '|'
	jr z,bo_p
	inc c
	cp '^'
	jr z,bo_p
	inc c
	cp '&'
	jr z,bo_p
	inc c
	cp '<'
	jr z,bo_2
	inc c
	cp '>'
	jr z,bo_2
	inc c
	cp '+'
	jr z,bo_p
	inc c
	cp '-'
	jr z,bo_p
	inc c
	cp '*'
	jr z,bo_p
	inc c
	cp '/'
	jr z,bo_p
	inc c
	cp '%'
	jr z,bo_p
	scf
	ret
bo_2:	inc hl			; << and >>: the character twice
	cp (hl)
	dec hl
	jr z,bo_p
	scf
	ret
bo_p:	push hl
	ld hl,opprec
	ld a,c
	add a,l
	ld l,a
	jr nc,bo_p2
	inc h
bo_p2:	ld a,(hl)
	pop hl
	or a
	ret
opprec: defb 1,2,3,4,4,5,5,6,6,6

apply:	push bc 		; HL op DE -> DE, C = the operator
	call ap_go
	pop bc
	ret
ap_go:	push hl
	ld a,c
	add a,a
	ld c,a
	ld b,0
	ld hl,aptab
	add hl,bc
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ex (sp),hl		; HL = the left side again; to the routine
	ret
aptab:	defw ap_or,ap_xor,ap_and,ap_shl,ap_shr,ap_add,ap_sub,ap_mul,ap_div,ap_mod

ap_or:	ld a,h
	or d
	ld d,a
	ld a,l
	or e
	ld e,a
	ret
ap_xor: ld a,h
	xor d
	ld d,a
	ld a,l
	xor e
	ld e,a
	ret
ap_and: ld a,h
	and d
	ld d,a
	ld a,l
	and e
	ld e,a
	ret
ap_shl: call shcnt		; A = the count (0 if 16 or more)
	jr z,ap_sh0
as_1:	add hl,hl
	dec a
	jr nz,as_1
	ex de,hl
	ret
ap_shr: call shcnt
	jr z,ap_sh0
ar_1s:	srl h
	rr l
	dec a
	jr nz,ar_1s
	ex de,hl
	ret
ap_sh0: ex de,hl		; a count of 0: unchanged; 16 or more: 0
	ret nc
	ld de,0
	ret
shcnt:	ld a,d			; DE = a shift count -> A = it, Z = shift nothing
	or a			; (CF too: shift everything out)
	jr nz,sc_all
	ld a,e
	cp 16
	jr nc,sc_all
	or a
	ret
sc_all: xor a
	scf
	ret
ap_add: add hl,de
	ex de,hl
	ret
ap_sub: or a
	sbc hl,de
	ex de,hl
	ret
ap_mul: ld b,h			; HL * DE: shift and add
	ld c,l
	ld hl,0
	ld a,16
am_1:	add hl,hl
	sla e
	rl d
	jr nc,am_2
	add hl,bc
am_2:	dec a
	jr nz,am_1
	ex de,hl
	ret
ap_div: call div16		; HL / DE
	ld d,b
	ld e,c
	ret
ap_mod: call div16		; HL % DE
	ex de,hl
	ret
div16:	ld a,d			; HL / DE -> BC, remainder HL (unsigned)
	or e
	jr nz,dv_0
	push hl
	ld hl,m_div
	call err
	pop hl
	ld bc,0
	ld h,b
	ld l,c
	ret
dv_0:	ld b,h
	ld c,l
	ld hl,0
	ld a,16
dv_1:	sla c			; the next bit of the dividend into HL
	rl b
	adc hl,hl
	jr c,dv_big
	or a
	sbc hl,de
	jr nc,dv_2
	add hl,de
	jr dv_3
dv_big: or a
	sbc hl,de
dv_2:	inc c
dv_3:	dec a
	jp nz,dv_1
	ret

; unary: a value, maybe with - + ~ in front, or ( expression )
unary:	call skipsp
	cp '-'
	jr z,un_neg
	cp '+'
	jr z,un_pos
	cp '~'
	jr z,un_cpl
	cp '('
	jr nz,primary
	inc hl
	call ex_any
	call skipsp
	cp ')'
	jr nz,e_paren
	inc hl
	ret
un_pos: inc hl
	jr unary
un_neg: inc hl
	call unary
neg_de: ld a,e
	cpl
	ld e,a
	ld a,d
	cpl
	ld d,a
	inc de
	ret
un_cpl: inc hl
	call unary
	ld a,e
	cpl
	ld e,a
	ld a,d
	cpl
	ld d,a
	ret
e_paren:
	ld hl,m_paren
	jp errx

; primary: a number, a name, $ or a character
primary:
	cp '$'
	jr z,pr_dol
	cp 27h
	jr z,pr_chr
	cp '0'
	jr c,pr_sym
	cp '9'+1
	jp c,number
pr_sym: call getid
	jr c,e_expr
	push hl
	call symfind
	jr c,pr_und
	ld e,(hl)
	inc hl
	ld d,(hl)
	pop hl
	ret
pr_und: ld a,1			; not defined (yet)
	ld (v_undef),a
	ld (v_ep),de
	ld a,b
	ld (v_en),a
	ld hl,m_undef
	call err
	ld de,0
	pop hl
	ret
e_expr: ld hl,m_expr
	jp errx
pr_dol: inc hl			; $FF, or $ = here
	ld a,(hl)
	call hexdig
	jr nc,pr_dhex
	ld de,(v_lpc)
	ret
pr_dhex:
	ld c,16
	jr nu_go
pr_chr: inc hl			; 'c'
	ld a,(hl)
	or a
	jr z,e_expr
	cp 5Ch
	jr nz,pc_1
	call escape
	jr pc_2
pc_1:	inc hl
pc_2:	ld e,a
	ld d,0
	ld a,(hl)
	cp 27h
	jr nz,e_expr
	inc hl
	ret

; escape: HL at a backslash -> A = the character it means, HL = after it
escape: inc hl
	ld a,(hl)
	or a
	ret z
	inc hl
	cp 'n'
	jr nz,es_1
	ld a,10
	ret
es_1:	cp 'r'
	jr nz,es_2
	ld a,13
	ret
es_2:	cp 't'
	jr nz,es_3
	ld a,9
	ret
es_3:	cp '0'
	ret nz
	xor a
	ret

hexdig: call alnum		; A = a character: NC = a hex digit, A = its value
	ret c
	call upper
	sub '0'
	cp 10
	ccf
	ret nc			; 0-9
	sub 'A'-'0'
	cp 6
	jr nc,hd_no
	add a,10
	or a
	ret
hd_no:	scf
	ret

; number: HL at its first digit.  123, 0FFh, 101b, 17o (or 17q), 99d, 0x1F
number: ld c,0			; C = the base (0: from the suffix)
	inc hl
	ld a,(hl)
	dec hl
	or 20h
	cp 'x'
	jr nz,nu_go
	ld a,(hl)
	cp '0'
	jr nz,nu_go
	inc hl			; 0x...
	inc hl
	ld c,16
nu_go:	push hl 		; the digits: up to the first character that is
	ld b,0			; not a letter or a digit
nu_1:	ld a,(hl)
	call alnum
	jr c,nu_2
	inc hl
	inc b
	jr nu_1
nu_2:	ld a,b
	or a
	jr z,e_num
	ld a,c
	or a
	jr nz,nu_5		; the base is known
	dec hl			; the last one: a suffix?
	ld a,(hl)
	inc hl
	or 20h
	ld c,16
	cp 'h'
	jr z,nu_4
	ld c,2
	cp 'b'
	jr z,nu_4
	ld c,8
	cp 'o'
	jr z,nu_4
	cp 'q'
	jr z,nu_4
	ld c,10
	cp 'd'
	jr nz,nu_5
nu_4:	dec b			; (the suffix is not a digit)
nu_5:	ex (sp),hl		; HL = the first digit, (SP) = after the number
	ld de,0
	ld a,b
	or a
	jr z,nu_end
nu_6:	ld a,(hl)
	call hexdig
	jr c,e_num
	cp c
	jr nc,e_num		; not a digit of this base
	push hl 		; DE = DE * base + digit
	push bc
	ld h,d
	ld l,e
	ld b,c
	ld de,0
nu_7:	ex de,hl
	add hl,de
	ex de,hl
	djnz nu_7
	pop bc
	pop hl
	add a,e
	ld e,a
	jr nc,nu_8
	inc d
nu_8:	inc hl
	djnz nu_6
nu_end: pop hl
	ret
e_num:	pop hl
	ld hl,m_num
	jp errx

m_div:	defm "division by zero"
	defb 0
m_paren: defm "missing )"
	defb 0
m_undef: defm "undefined: "
	defb 0
m_expr: defm "bad expression"
	defb 0
m_num:	defm "bad number"
	defb 0
