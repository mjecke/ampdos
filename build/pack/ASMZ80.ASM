; ==========================================================================
; ASMZ80.ASM - ASM: the instructions and the directives.
;
;   mnlook    DE, B = a word -> A = its handler, C = the handler's value.
;             CF = not an instruction or directive
;   operands  HL = text: the instruction's operands -> O1, O2, v_nops, and
;             v_pfx / v_disp / v_hasd for IX and IY
;   h_...     one handler for each group of instructions; d_... directives.
;             C = the value from the table (usually the opcode); HL = the text
;             after the instruction's operands
;
; The encodings follow the usual pattern of the Z80's opcodes: r is a
; register's number (B C D E H L (HL) A = 0..7), rp a pair's (BC DE HL SP =
; 0..3), cc a condition's (NZ Z NC C PO PE P M = 0..7).  IX and IY are HL
; with a prefix byte (DDh, FDh) in front, and (IX+d) is (HL) with d after
; the opcode.
; ==========================================================================

; ---- handlers
HD_FIX1:  equ 0 		 ; one byte, no operands
HD_ED:	  equ 1 		 ; EDh + one byte, no operands
HD_ALU:   equ 2 		 ; ADD ADC SUB SBC AND XOR OR CP
HD_INCDEC: equ 3		 ; INC DEC
HD_ROT:   equ 4 		 ; RLC RRC RL RR SLA SRA SLL SRL
HD_BIT:   equ 5 		 ; BIT RES SET
HD_JP:	  equ 6
HD_JR:	  equ 7 		 ; JR DJNZ
HD_CALL:  equ 8
HD_RET:   equ 9
HD_RST:   equ 10
HD_PUSH:  equ 11		 ; PUSH POP
HD_EX:	  equ 12
HD_IN:	  equ 13
HD_OUT:   equ 14
HD_IM:	  equ 15
HD_LD:	  equ 16
HD_DIR:   equ 17		 ; from here: directives
HD_ORG:   equ 17
HD_EQU:   equ 18
HD_DEFB:  equ 19		 ; DEFB DEFM DB DM
HD_DEFW:  equ 20
HD_DEFS:  equ 21
HD_INCL:  equ 22
HD_INCBIN: equ 23
HD_IF:	  equ 24
HD_ELSE:  equ 25
HD_ENDIF: equ 26

htab:	defw h_fix1,h_ed,h_alu,h_incdec,h_rot,h_bit,h_jp,h_jr,h_call,h_ret
	defw h_rst,h_push,h_ex,h_in,h_out,h_im,h_ld
	defw d_org,d_equ,d_defb,d_defw,d_defs,d_incl,d_incbin,d_if,d_else,d_endif

; ---- operand kinds
KR:	 equ 1			; r: B C D E H L (HL) A, also (IX+d) and IXH ...
KRP:	 equ 2			; rp: BC DE HL SP (and IX, IY)
KAF:	 equ 3
KAFX:	 equ 4			; AF'
KI:	 equ 5
KRR:	 equ 6			; R
KIBC:	 equ 7			; (BC)
KIDE:	 equ 8			; (DE)
KISP:	 equ 9			; (SP)
KIC:	 equ 10 		; (C)
KIND:	 equ 11 		; (nn)
KIMM:	 equ 12 		; nn
KCC:	 equ 13 		; a condition (C itself comes as KR 1)

; ---------------------------------------------------------------- the words
; Each: the name (the last character + 80h), handler, value.  Grouped by the
; first letter; a group ends with 0.
mnlook: ld a,(de)
	call upper
	sub 'A'
	cp 26
	ccf
	ret c
	push de
	add a,a
	ld e,a
	ld d,0
	ld hl,mnidx
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	pop de
ml_1:	ld a,(hl)
	or a
	scf
	ret z			; not in the group
	push bc
	push de
	call mncmp
	pop de
	pop bc
	jr z,ml_2
	inc hl
	inc hl
	jr ml_1
ml_2:	ld a,(hl)
	inc hl
	ld c,(hl)
	or a
	ret

; mncmp: HL = a name in a table (the last character + 80h), DE = a word, B = its
; length -> Z = the same (in any case); HL = after the table's name either way
mncmp:	ld a,(de)
	call upper
	ld c,a
	ld a,(hl)
	and 7Fh
	cp c
	jr nz,mc_skip
	bit 7,(hl)
	jr nz,mc_last
	inc hl
	inc de
	djnz mncmp
mc_skip:			; (ours is shorter, or different)
	bit 7,(hl)
	inc hl
	jr z,mc_skip
	ret			; NZ
mc_last:
	inc hl
	dec b			; the same only if ours ends here too
	ret

mnidx:	defw mn_a,mn_b,mn_c,mn_d,mn_e,mn_none,mn_none,mn_h,mn_i,mn_j,mn_none
	defw mn_l,mn_none,mn_n,mn_o,mn_p,mn_none,mn_r,mn_s,mn_none,mn_none
	defw mn_none,mn_none,mn_x,mn_none,mn_none

mn_a:	defm "AD"
	defb 80h+'C',HD_ALU,08h
	defm "AD"
	defb 80h+'D',HD_ALU,00h
	defm "AN"
	defb 80h+'D',HD_ALU,20h
mn_none: defb 0
mn_b:	defm "BI"
	defb 80h+'T',HD_BIT,40h
	defb 0
mn_c:	defm "CAL"
	defb 80h+'L',HD_CALL,0
	defm "CC"
	defb 80h+'F',HD_FIX1,3Fh
	defm "C"
	defb 80h+'P',HD_ALU,38h
	defm "CP"
	defb 80h+'D',HD_ED,0A9h
	defm "CPD"
	defb 80h+'R',HD_ED,0B9h
	defm "CP"
	defb 80h+'I',HD_ED,0A1h
	defm "CPI"
	defb 80h+'R',HD_ED,0B1h
	defm "CP"
	defb 80h+'L',HD_FIX1,2Fh
	defb 0
mn_d:	defm "DEF"
	defb 80h+'B',HD_DEFB,0
	defm "DEF"
	defb 80h+'M',HD_DEFB,0
	defm "DEF"
	defb 80h+'W',HD_DEFW,0
	defm "DEF"
	defb 80h+'S',HD_DEFS,0
	defm "DE"
	defb 80h+'C',HD_INCDEC,1
	defm "DJN"
	defb 80h+'Z',HD_JR,10h
	defm "D"
	defb 80h+'B',HD_DEFB,0
	defm "D"
	defb 80h+'M',HD_DEFB,0
	defm "D"
	defb 80h+'W',HD_DEFW,0
	defm "D"
	defb 80h+'S',HD_DEFS,0
	defm "DA"
	defb 80h+'A',HD_FIX1,27h
	defm "D"
	defb 80h+'I',HD_FIX1,0F3h
	defb 0
mn_e:	defm "EQ"
	defb 80h+'U',HD_EQU,0
	defm "E"
	defb 80h+'X',HD_EX,0
	defm "EX"
	defb 80h+'X',HD_FIX1,0D9h
	defm "E"
	defb 80h+'I',HD_FIX1,0FBh
	defm "ELS"
	defb 80h+'E',HD_ELSE,0
	defm "ENDI"
	defb 80h+'F',HD_ENDIF,0
	defb 0
mn_h:	defm "HAL"
	defb 80h+'T',HD_FIX1,76h
	defb 0
mn_i:	defm "IN"
	defb 80h+'C',HD_INCDEC,0
	defm "I"
	defb 80h+'N',HD_IN,0
	defm "I"
	defb 80h+'F',HD_IF,0
	defm "INCLUD"
	defb 80h+'E',HD_INCL,0
	defm "INCBI"
	defb 80h+'N',HD_INCBIN,0
	defm "I"
	defb 80h+'M',HD_IM,0
	defm "IN"
	defb 80h+'D',HD_ED,0AAh
	defm "IND"
	defb 80h+'R',HD_ED,0BAh
	defm "IN"
	defb 80h+'I',HD_ED,0A2h
	defm "INI"
	defb 80h+'R',HD_ED,0B2h
	defb 0
mn_j:	defm "J"
	defb 80h+'P',HD_JP,0
	defm "J"
	defb 80h+'R',HD_JR,18h
	defb 0
mn_l:	defm "L"
	defb 80h+'D',HD_LD,0
	defm "LDI"
	defb 80h+'R',HD_ED,0B0h
	defm "LD"
	defb 80h+'I',HD_ED,0A0h
	defm "LDD"
	defb 80h+'R',HD_ED,0B8h
	defm "LD"
	defb 80h+'D',HD_ED,0A8h
	defb 0
mn_n:	defm "NO"
	defb 80h+'P',HD_FIX1,00h
	defm "NE"
	defb 80h+'G',HD_ED,44h
	defb 0
mn_o:	defm "O"
	defb 80h+'R',HD_ALU,30h
	defm "OR"
	defb 80h+'G',HD_ORG,0
	defm "OU"
	defb 80h+'T',HD_OUT,0
	defm "OTI"
	defb 80h+'R',HD_ED,0B3h
	defm "OTD"
	defb 80h+'R',HD_ED,0BBh
	defm "OUT"
	defb 80h+'I',HD_ED,0A3h
	defm "OUT"
	defb 80h+'D',HD_ED,0ABh
	defb 0
mn_p:	defm "PUS"
	defb 80h+'H',HD_PUSH,0C5h
	defm "PO"
	defb 80h+'P',HD_PUSH,0C1h
	defb 0
mn_r:	defm "RE"
	defb 80h+'T',HD_RET,0
	defm "RE"
	defb 80h+'S',HD_BIT,80h
	defm "R"
	defb 80h+'R',HD_ROT,18h
	defm "R"
	defb 80h+'L',HD_ROT,10h
	defm "RR"
	defb 80h+'A',HD_FIX1,1Fh
	defm "RL"
	defb 80h+'A',HD_FIX1,17h
	defm "RRC"
	defb 80h+'A',HD_FIX1,0Fh
	defm "RLC"
	defb 80h+'A',HD_FIX1,07h
	defm "RR"
	defb 80h+'C',HD_ROT,08h
	defm "RL"
	defb 80h+'C',HD_ROT,00h
	defm "RS"
	defb 80h+'T',HD_RST,0
	defm "RET"
	defb 80h+'I',HD_ED,4Dh
	defm "RET"
	defb 80h+'N',HD_ED,45h
	defm "RL"
	defb 80h+'D',HD_ED,6Fh
	defm "RR"
	defb 80h+'D',HD_ED,67h
	defb 0
mn_s:	defm "SB"
	defb 80h+'C',HD_ALU,18h
	defm "SU"
	defb 80h+'B',HD_ALU,10h
	defm "SR"
	defb 80h+'L',HD_ROT,38h
	defm "SL"
	defb 80h+'A',HD_ROT,20h
	defm "SR"
	defb 80h+'A',HD_ROT,28h
	defm "SL"
	defb 80h+'L',HD_ROT,30h
	defm "SC"
	defb 80h+'F',HD_FIX1,37h
	defm "SE"
	defb 80h+'T',HD_BIT,0C0h
	defb 0
mn_x:	defm "XO"
	defb 80h+'R',HD_ALU,28h
	defb 0

; registers and conditions: the name, kind, value, prefix
regs:	defb 80h+'A',KR,7,0
	defb 80h+'B',KR,0,0
	defb 80h+'C',KR,1,0
	defb 80h+'D',KR,2,0
	defb 80h+'E',KR,3,0
	defb 80h+'H',KR,4,0
	defb 80h+'L',KR,5,0
	defm "H"
	defb 80h+'L',KRP,2,0
	defm "B"
	defb 80h+'C',KRP,0,0
	defm "D"
	defb 80h+'E',KRP,1,0
	defm "S"
	defb 80h+'P',KRP,3,0
	defm "I"
	defb 80h+'X',KRP,2,0DDh
	defm "I"
	defb 80h+'Y',KRP,2,0FDh
	defm "A"
	defb 80h+'F',KAF,3,0
	defm "N"
	defb 80h+'Z',KCC,0,0
	defb 80h+'Z',KCC,1,0
	defm "N"
	defb 80h+'C',KCC,2,0
	defm "P"
	defb 80h+'O',KCC,4,0
	defm "P"
	defb 80h+'E',KCC,5,0
	defb 80h+'P',KCC,6,0
	defb 80h+'M',KCC,7,0
	defb 80h+'I',KI,0,0
	defb 80h+'R',KRR,0,0
	defm "IX"
	defb 80h+'H',KR,4,0DDh
	defm "IX"
	defb 80h+'L',KR,5,0DDh
	defm "IY"
	defb 80h+'H',KR,4,0FDh
	defm "IY"
	defb 80h+'L',KR,5,0FDh
	defb 0

; regword: DE, B = a word -> A = kind, C = value, B = prefix.  CF = not a register
; (DE is kept)
regword:
	ld a,b
	cp 4
	ccf
	ret c			; (no register name is longer than 3)
	ld hl,regs
rw_1:	ld a,(hl)
	or a
	scf
	ret z
	push bc
	push de
	call mncmp
	pop de
	pop bc
	jr z,rw_2
	inc hl
	inc hl
	inc hl
	jr rw_1
rw_2:	ld a,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	or a
	ret

; ---------------------------------------------------------------- operands
operands:
	xor a
	ld (O1+OP_K),a
	ld (O2+OP_K),a
	ld (O2+OP_PFX),a
	ld (O2+OP_HASD),a
	ld (v_nops),a
	ld (v_pfx),a
	ld (v_hasd),a
	ld (v_disp),a
	call skipsp
	call iseos
	ret z
	ld iy,O1
	call opnd
	ld a,1
	ld (v_nops),a
	call skipsp
	cp ','
	jr nz,os_pfx
	inc hl
	ld iy,O2
	call opnd
	ld a,2
	ld (v_nops),a
os_pfx: ld a,(O1+OP_PFX)	; IX or IY: the prefix, and the displacement
	ld b,a
	ld a,(O2+OP_PFX)
	or a
	jr z,os_1
	ld c,a
	ld a,b
	or a
	jr z,os_0
	cp c
	jr nz,e_ops		; IX and IY at once
os_0:	ld b,c
os_1:	ld a,b
	ld (v_pfx),a
	ld a,(O1+OP_HASD)
	or a
	ld a,(O1+OP_D)
	jr nz,os_2
	ld a,(O2+OP_HASD)
	or a
	ret z
	ld a,(O2+OP_D)
os_2:	ld (v_disp),a
	ld a,1
	ld (v_hasd),a
	ret
e_ops:	ld hl,m_ops
	jp errx

; opnd: HL = text, IY = an operand record -> the record; HL = after the operand
opnd:	xor a
	ld (iy+OP_PFX),a
	ld (iy+OP_HASD),a
	ld (iy+OP_D),a
	call skipsp
	cp '('
	jr z,op_par
	call getid
	jr c,op_imm		; not a name: an expression
	push hl
	call regword
	pop hl
	jr c,op_name
	cp KAF			; AF' ?
	jr nz,op_reg
	ld a,(hl)
	cp 27h
	ld a,KAF
	jr nz,op_reg
	inc hl
	ld a,KAFX
op_reg: ld (iy+OP_K),a
	ld (iy+OP_V),c
	ld (iy+OP_V+1),0
	ld (iy+OP_PFX),b
	ret
op_name:
	ex de,hl		; a name that is not a register: an expression
op_imm: call expr
	ld a,KIMM
op_val: ld (iy+OP_K),a
	ld (iy+OP_V),e
	ld (iy+OP_V+1),d
	ret

op_par: push hl 		; ( : a register in brackets, (nn), or an expression
	inc hl
	call skipsp
	call getid
	jp c,op_pexp
	push hl
	call regword
	pop hl
	jp c,op_pexp
	cp KRP
	jr z,op_prp
	cp KR
	jr nz,op_pexp
	ld a,c			; (C)
	cp 1
	jr nz,op_pexp
	ld a,b
	or a
	jr nz,op_pexp
	ld a,KIC
	jr op_pclose
op_prp: ld a,b			; (IX) (IY) (IX+d)
	or a
	jr nz,op_pix
	ld a,c			; (BC) (DE) (HL) (SP)
	ld b,KIBC
	or a
	jr z,op_pk
	ld b,KIDE
	dec a
	jr z,op_pk
	ld b,KISP
	cp 2
	jr z,op_pk
	ld a,6			; (HL) is register 6
	ld c,a
	ld b,KR
op_pk:	ld a,b
op_pclose:
	ld b,a
	call skipsp
	cp ')'
	jr nz,op_pexp
	inc hl
	pop af			; (the saved "(")
	ld (iy+OP_K),b
	ld (iy+OP_V),c
	ld (iy+OP_V+1),0
	ret
op_pix: ld (iy+OP_PFX),b
	ld (iy+OP_HASD),1
	call skipsp
	cp ')'
	jr z,op_px2
	call expr		; +d or -d
	ld a,(v_pass)
	cp 2
	jr nz,op_px1
	ld a,e			; -128 .. 127
	rlca
	sbc a,a
	cp d
	jr z,op_px1
	push hl
	ld hl,m_range
	call err
	pop hl
op_px1: ld (iy+OP_D),e
	call skipsp
	cp ')'
	jp nz,e_paren
op_px2: inc hl
	pop af
	ld (iy+OP_K),KR
	ld (iy+OP_V),6
	ld (iy+OP_V+1),0
	ret
op_pexp:			; not a register: (nn) if the brackets hold the
	pop hl			; whole operand, else an expression that starts with (
	push hl
	call pmatch
	call skipsp
	call iseos
	jr z,op_ind
	cp ','
	jr z,op_ind
	pop hl
	jp op_imm
op_ind: pop hl
	call expr
	ld a,KIND
	jp op_val

; pmatch: HL at ( -> HL after its )
pmatch: ld c,0
pm_1:	ld a,(hl)
	or a
	ret z
	inc hl
	cp '('
	jr nz,pm_2
	inc c
	jr pm_1
pm_2:	cp ')'
	jr nz,pm_3
	dec c
	ret z
	jr pm_1
pm_3:	cp 27h			; a character: ')' is not a bracket
	jr nz,pm_1
	ld a,(hl)
	cp 5Ch
	jr nz,pm_4
	inc hl
pm_4:	inc hl
	ld a,(hl)
	cp 27h
	jr nz,pm_1
	inc hl
	jr pm_1

; ---------------------------------------------------------------- emitting
e_op:	push af 		; A = an opcode: [prefix] opcode [displacement]
	ld a,(v_pfx)
	or a
	call nz,emit
	pop af
	call emit
	ld a,(v_hasd)
	or a
	ret z
	ld a,(v_disp)
	jp emit
e_cb:	push af 		; A = a CBh opcode: CB op, or prefix CB d op
	ld a,(v_pfx)
	or a
	jr z,ec_1
	call emit
	ld a,0CBh
	call emit
	ld a,(v_disp)
	call emit
	pop af
	jp emit
ec_1:	ld a,0CBh
	call emit
	pop af
	jp emit
e_ed:	push af 		; A = an EDh opcode
	ld a,0EDh
	call emit
	pop af
	jp emit
e_w2:	ld de,(O2+OP_V) 	; the second operand as a word
	jr e_word
e_w1:	ld de,(O1+OP_V) 	; the first
e_word: ld a,e
	call emit
	ld a,d
	jp emit
e_b2:	ld de,(O2+OP_V) 	; the second operand as a byte
e_byte: ld a,d			; DE as a byte: 0..255 or -256..-1
	inc a
	cp 2
	jr c,eb_1
	push hl
	ld hl,m_range
	call err
	pop hl
eb_1:	ld a,e
	jp emit

e_bad:	ld hl,m_ops
	jp errx

; getcc: O1 is a condition -> A = cc (CF = it is not)
getcc:	ld a,(O1+OP_K)
	cp KCC
	jr z,gc_1
	cp KR			; C, the register, is the condition C too
	jr nz,gc_no
	ld a,(O1+OP_PFX)
	or a
	jr nz,gc_no
	ld a,(O1+OP_V)
	cp 1
	jr nz,gc_no
	ld a,3
	ret
gc_1:	ld a,(O1+OP_V)
	or a
	ret
gc_no:	scf
	ret

x8:	rlca			; A * 8
	rlca
	rlca
	ret
x16:	rlca			; A * 16
	rlca
	rlca
	rlca
	ret

; ---------------------------------------------------------------- the instructions
h_fix1: ld a,(v_nops)		; NOP, HALT, EXX ...
	or a
	jr nz,e_bad
	ld a,c
	jp emit

h_ed:	ld a,(v_nops)		; LDIR, NEG, RETI ...
	or a
	jr nz,e_bad
	ld a,c
	jp e_ed

h_alu:	ld a,(v_nops)		; ADD ADC SUB SBC AND XOR OR CP (C = op * 8)
	or a
	jr z,e_bad
	cp 2
	jr nz,al_1
	ld a,(O1+OP_K)
	cp KRP
	jr z,al_16
	cp KR			; op A,x
	jr nz,e_bad
	ld a,(O1+OP_V)
	cp 7
	jr nz,e_bad
	ld a,(O1+OP_PFX)
	or a
	jr nz,e_bad
	ld iy,O2
	jr al_x
al_1:	ld iy,O1		; op x
al_x:	ld a,(iy+OP_K)
	cp KR
	jr nz,al_n
	ld a,(iy+OP_V)		; op r: 80h + op + r
	or c
	or 80h
	jp e_op
al_n:	cp KIMM
	jp nz,e_bad
	ld a,c			; op n: C6h + op, n
	or 0C6h
	call emit
	ld e,(iy+OP_V)
	ld d,(iy+OP_V+1)
	jp e_byte
al_16:	ld a,(O1+OP_V)		; ADD/ADC/SBC HL,rp (ADD IX,rp)
	cp 2
	jp nz,e_bad
	ld a,(O2+OP_K)
	cp KRP
	jp nz,e_bad
	ld a,(O2+OP_V)
	cp 2
	jr nz,al_16b
	ld a,(O1+OP_PFX)	; ADD IX,IX: the same register twice
	ld b,a
	ld a,(O2+OP_PFX)
	cp b
	jr nz,e_bad2
al_16b: ld a,(O2+OP_V)
	call x16
	ld b,a
	ld a,c
	or a
	jr nz,al_16c
	ld a,b			; ADD: 09h + rp * 16
	or 09h
	jp e_op
al_16c: ld a,(v_pfx)		; ADC and SBC have no IX form
	or a
	jr nz,e_bad2
	ld a,c
	cp 08h
	ld a,4Ah		; ADC: ED 4Ah + rp * 16
	jr z,al_16d
	ld a,c
	cp 18h
	jr nz,e_bad2
	ld a,42h		; SBC: ED 42h + rp * 16
al_16d: or b
	jp e_ed
e_bad2: jp e_bad

h_incdec:			; INC DEC (C = 0, 1)
	ld a,(v_nops)
	dec a
	jr nz,e_bad2
	ld a,(O1+OP_K)
	cp KR
	jr nz,id_16
	ld a,(O1+OP_V)		; r: 04h / 05h + r * 8
	call x8
	or 04h
	or c
	jp e_op
id_16:	cp KRP
	jr nz,e_bad2
	ld a,c			; rp: 03h / 0Bh + rp * 16
	call x8
	or 03h
	ld b,a
	ld a,(O1+OP_V)
	call x16
	or b
	jp e_op

h_rot:	ld a,(v_nops)		; RLC ... SRL r (C = op * 8): CB op+r
	dec a
	jr nz,e_bad2
	ld a,(O1+OP_K)
	cp KR
	jr nz,e_bad2
	ld a,(O1+OP_V)
	or c
	jp e_cb

h_bit:	ld a,(v_nops)		; BIT RES SET n,r (C = 40h, 80h, C0h)
	cp 2
	jr nz,e_bad2
	ld a,(O1+OP_K)
	cp KIMM
	jr nz,e_bad2
	ld a,(O2+OP_K)
	cp KR
	jr nz,e_bad2
	ld de,(O1+OP_V)
	ld a,e
	cp 8
	jr nc,bt_bad
	ld a,d
	or a
	jr z,bt_1
bt_bad: push hl
	ld hl,m_range
	call err
	pop hl
bt_1:	ld a,e
	and 7
	call x8
	or c
	ld c,a
	ld a,(O2+OP_V)
	or c
	jp e_cb

h_jp:	ld a,(v_nops)
	cp 1
	jr nz,jp_cc
	ld a,(O1+OP_K)
	cp KIMM
	jr nz,jp_ind
	ld a,0C3h		; JP nn
jp_w:	call emit
	jp e_w1
jp_ind: cp KR			; JP (HL) / (IX) / (IY)
	jr nz,e_bad3
	ld a,(O1+OP_V)
	cp 6
	jr nz,e_bad3
	ld a,(v_disp)
	or a
	jr nz,e_bad3
	ld a,(v_pfx)
	or a
	call nz,emit
	ld a,0E9h
	jp emit
jp_cc:	cp 2			; JP cc,nn: C2h + cc * 8
	jr nz,e_bad3
	call getcc
	jr c,e_bad3
	call x8
	or 0C2h
cc_w:	ld b,a
	ld a,(O2+OP_K)
	cp KIMM
	jr nz,e_bad3
	ld a,b
	call emit
	jp e_w2
e_bad3: jp e_bad

h_jr:	ld a,(v_nops)		; JR e, JR cc,e (cc = NZ Z NC C), DJNZ e
	cp 1
	jr z,jr_1
	cp 2
	jr nz,e_bad3
	ld a,c
	cp 18h
	jr nz,e_bad3
	call getcc
	jr c,e_bad3
	cp 4
	jr nc,e_bad3
	call x8
	or 20h
	ld c,a
	ld iy,O2
	jr jr_go
jr_1:	ld iy,O1
jr_go:	ld a,(iy+OP_K)
	cp KIMM
	jr nz,e_bad3
	ld a,c
	call emit
	push hl
	ld l,(iy+OP_V)		; e = the target - (the instruction's address + 2)
	ld h,(iy+OP_V+1)
	ld de,(v_lpc)
	inc de
	inc de
	or a
	sbc hl,de
	ld a,(v_pass)
	cp 2
	jr nz,jr_2
	ld a,l			; -128 .. 127?
	rlca
	sbc a,a
	cp h
	jr z,jr_2
	push hl
	ld hl,m_jr
	call err
	pop hl
jr_2:	ld a,l
	pop hl
	jp emit

h_call: ld a,(v_nops)
	cp 1
	jr nz,cl_cc
	ld a,(O1+OP_K)
	cp KIMM
	jr nz,e_bad3
	ld a,0CDh		; CALL nn
	jp jp_w
cl_cc:	cp 2			; CALL cc,nn: C4h + cc * 8
	jr nz,e_bad3
	call getcc
	jr c,e_bad3
	call x8
	or 0C4h
	jp cc_w

h_ret:	ld a,(v_nops)
	or a
	ld a,0C9h		; RET
	jp z,emit
	ld a,(v_nops)
	dec a
	jp nz,e_bad3
	call getcc		; RET cc: C0h + cc * 8
	jp c,e_bad3
	call x8
	or 0C0h
	jp emit

h_rst:	ld a,(v_nops)		; RST n: C7h + n (n = 0, 8, ... 38h)
	dec a
	jp nz,e_bad4
	ld a,(O1+OP_K)
	cp KIMM
	jp nz,e_bad4
	ld de,(O1+OP_V)
	ld a,e
	and 0C7h
	or d
	jr z,rs_1
	push hl
	ld hl,m_range
	call err
	pop hl
rs_1:	ld a,e
	and 38h
	or 0C7h
	jp emit

h_push: ld a,(v_nops)		; PUSH POP rp (BC DE HL AF; IX IY) (C = C5h, C1h)
	dec a
	jr nz,e_bad4
	ld a,(O1+OP_K)
	cp KAF
	jr z,pu_1
	cp KRP
	jr nz,e_bad4
	ld a,(O1+OP_V)
	cp 3
	jr z,e_bad4		; (not SP)
pu_1:	ld a,(O1+OP_V)
	call x16
	or c
	jp e_op

h_ex:	ld a,(v_nops)		; EX DE,HL / EX AF,AF' / EX (SP),HL (IX IY)
	cp 2
	jr nz,e_bad4
	ld a,(O1+OP_K)
	cp KAF
	jr z,ex_af
	cp KISP
	jr z,ex_sp
	cp KRP
	jr nz,e_bad4
	ld a,(O1+OP_V)
	cp 1
	jr nz,e_bad4
	ld a,(O2+OP_K)
	cp KRP
	jr nz,e_bad4
	ld a,(O2+OP_V)
	cp 2
	jr nz,e_bad4
	ld a,(v_pfx)
	or a
	jr nz,e_bad4
	ld a,0EBh
	jp emit
ex_af:	ld a,(O2+OP_K)
	cp KAFX
	jr nz,e_bad4
	ld a,08h
	jp emit
ex_sp:	ld a,(O2+OP_K)
	cp KRP
	jr nz,e_bad4
	ld a,(O2+OP_V)
	cp 2
	jr nz,e_bad4
	ld a,0E3h
	jp e_op
e_bad4: jp e_bad

h_in:	ld a,(v_nops)		; IN A,(n) / IN r,(C)
	cp 2
	jr nz,e_bad4
	ld a,(O1+OP_K)
	cp KR
	jr nz,e_bad4
	ld a,(O1+OP_PFX)
	or a
	jr nz,e_bad4
	ld a,(O2+OP_K)
	cp KIC
	jr z,in_c
	cp KIND
	jr nz,e_bad4
	ld a,(O1+OP_V)
	cp 7
	jr nz,e_bad4
	ld a,0DBh
	call emit
	jp e_b2
in_c:	ld a,(O1+OP_V)		; ED 40h + r * 8
	call x8
	or 40h
	jp e_ed

h_out:	ld a,(v_nops)		; OUT (n),A / OUT (C),r
	cp 2
	jr nz,e_bad4
	ld a,(O2+OP_K)
	cp KR
	jr nz,e_bad4
	ld a,(O2+OP_PFX)
	or a
	jr nz,e_bad4
	ld a,(O1+OP_K)
	cp KIC
	jr z,out_c
	cp KIND
	jr nz,e_bad4
	ld a,(O2+OP_V)
	cp 7
	jr nz,e_bad4
	ld a,0D3h
	call emit
	ld de,(O1+OP_V)
	jp e_byte
out_c:	ld a,(O2+OP_V)		; ED 41h + r * 8
	call x8
	or 41h
	jp e_ed

h_im:	ld a,(v_nops)		; IM 0/1/2: ED 46h / 56h / 5Eh
	dec a
	jr nz,e_bad4
	ld a,(O1+OP_K)
	cp KIMM
	jp nz,e_bad4
	ld a,(O1+OP_V)
	ld c,46h
	or a
	jr z,im_1
	ld c,56h
	dec a
	jr z,im_1
	ld c,5Eh
	dec a
	jr z,im_1
	push hl
	ld hl,m_range
	call err
	pop hl
im_1:	ld a,c
	jp e_ed

h_ld:	ld a,(v_nops)
	cp 2
	jp nz,e_bad4
	ld a,(O1+OP_K)
	ld b,a
	ld a,(O2+OP_K)
	ld c,a
	ld a,b
	cp KR
	jr nz,ld_2
	ld a,c			; LD r, ...
	cp KR
	jr nz,ld_1b
	ld a,(O1+OP_V)		; LD r,r': 40h + r * 8 + r'
	cp 6
	jr nz,ld_1a
	ld a,(O2+OP_V)
	cp 6
	jp z,e_bad4		; (that would be HALT)
ld_1a:	ld a,(O1+OP_V)
	call x8
	ld b,a
	ld a,(O2+OP_V)
	or b
	or 40h
	jp e_op
ld_1b:	cp KIMM 		; LD r,n: 06h + r * 8, n
	jr nz,ld_1c
	ld a,(O1+OP_V)
	call x8
	or 06h
	call e_op
	jp e_b2
ld_1c:	ld a,(O1+OP_V)		; LD A,(BC) (DE) (nn) I R
	cp 7
	jp nz,e_bad5
	ld a,(O1+OP_PFX)
	or a
	jp nz,e_bad5
	ld a,c
	cp KIBC
	ld a,0Ah
	jp z,emit
	ld a,c
	cp KIDE
	ld a,1Ah
	jp z,emit
	ld a,c
	cp KI
	ld a,57h
	jp z,e_ed
	ld a,c
	cp KRR
	ld a,5Fh
	jp z,e_ed
	ld a,c
	cp KIND
	jp nz,e_bad5
	ld a,3Ah
	call emit
	jp e_w2
ld_2:	ld a,c			; LD (BC) (DE) (nn) I R, A
	cp KR
	jr nz,ld_3
	ld a,(O2+OP_V)
	cp 7
	jp nz,e_bad5
	ld a,(O2+OP_PFX)
	or a
	jp nz,e_bad5
	ld a,b
	cp KIBC
	ld a,02h
	jp z,emit
	ld a,b
	cp KIDE
	ld a,12h
	jp z,emit
	ld a,b
	cp KI
	ld a,47h
	jp z,e_ed
	ld a,b
	cp KRR
	ld a,4Fh
	jp z,e_ed
	ld a,b
	cp KIND
	jr nz,e_bad5
	ld a,32h
	call emit
	jp e_w1
ld_3:	ld a,b			; LD rp, ...
	cp KRP
	jr nz,ld_4
	ld a,c
	cp KIMM 		; LD rp,nn: 01h + rp * 16
	jr nz,ld_3b
	ld a,(O1+OP_V)
	call x16
	or 01h
	call e_op
	jp e_w2
ld_3b:	cp KIND 		; LD HL,(nn): 2Ah; LD rp,(nn): ED 4Bh + rp * 16
	jr nz,ld_3c
	ld a,(O1+OP_V)
	cp 2
	ld a,2Ah
	jr z,ld_3w
	ld a,(O1+OP_V)
	call x16
	or 4Bh
	call e_ed
	jp e_w2
ld_3w:	call e_op
	jp e_w2
ld_3c:	cp KRP			; LD SP,HL (IX IY): F9h
	jr nz,e_bad5
	ld a,(O1+OP_V)
	cp 3
	jr nz,e_bad5
	ld a,(O2+OP_V)
	cp 2
	jr nz,e_bad5
	ld a,0F9h
	jp e_op
ld_4:	cp KIND 		; LD (nn),HL: 22h; LD (nn),rp: ED 43h + rp * 16
	jr nz,e_bad5
	ld a,c
	cp KRP
	jr nz,e_bad5
	ld a,(O2+OP_V)
	cp 2
	ld a,22h
	jr z,ld_4w
	ld a,(O2+OP_V)
	call x16
	or 43h
	call e_ed
	jp e_w1
ld_4w:	call e_op
	jp e_w1
e_bad5: jp e_bad

; ---------------------------------------------------------------- directives
d_org:	call known		; ORG addr
	ld (v_pc),de
	ret

; known: an expression whose value pass 1 must know (ORG, DEFS, IF)
known:	call expr
	ld a,(v_undef)
	or a
	ret z
	ld a,(v_pass)
	cp 1
	ret nz
	ld hl,m_known
	jp errx1

d_equ:	ld a,(v_haslab) 	; name: EQU value
	or a
	jr nz,eq_1
	ld hl,m_equ
	jp errx
eq_1:	call expr
	push hl
	ex de,hl		; HL = the value
	ld a,(v_pass)
	cp 2
	jr z,eq_2
	ld a,(v_undef)		; pass 1: a value that needs a later label is
	or a			; worked out in pass 2
	jr nz,eq_end
	call labset
	jr eq_end
eq_2:	push hl 		; pass 2: the value now (it may not be there yet)
	ld de,(v_lab)
	ld a,(v_labn)
	ld b,a
	ld a,(v_labh)
	ld c,a
	call symfind
	pop de
	jr c,eq_new
	ld (hl),e
	inc hl
	ld (hl),d
	jr eq_end
eq_new: ex de,hl
	ld de,(v_lab)
	call symadd
eq_end: pop hl
	jp ln_end

d_defb: call skipsp		; DEFB / DEFM: bytes and "strings"
db_1:	cp '"'
	jr z,db_str
	call expr
	call e_byte
	jr db_2
db_str: call dstr
db_2:	call skipsp
	cp ','
	ret nz
	inc hl
	call skipsp
	jr db_1

; dstr: HL at " : the string's bytes
dstr:	inc hl
ds_1:	ld a,(hl)
	or a
	jr z,e_quote
	cp '"'
	jr z,ds_end
	cp 5Ch
	jr nz,ds_2
	call escape
	call emit
	jr ds_1
ds_2:	call emit
	inc hl
	jr ds_1
ds_end: inc hl
	ret
e_quote:
	ld hl,m_quote
	jp errx

d_defw: call expr		; DEFW: words
	call e_word
	call skipsp
	cp ','
	ret nz
	inc hl
	jr d_defw

d_defs: call known		; DEFS n [,fill]
	push de
	ld c,0
	call skipsp
	cp ','
	jr nz,df_1
	inc hl
	call expr
	call e_byte_v		; (checks the range)
	ld c,e
df_1:	pop de
df_2:	ld a,d
	or e
	ret z
	ld a,c
	call emit
	dec de
	jr df_2
e_byte_v:			; check DE like e_byte, without emitting
	ld a,d
	inc a
	cp 2
	ret c
	push hl
	ld hl,m_range
	call err
	pop hl
	ret

; fname: HL = text: a file name in quotes -> HL at its first character, DE = after
; the closing quote
fname:	call skipsp
	cp '"'
	jr nz,e_quote
	inc hl
	push hl
fn_1:	ld a,(hl)
	or a
	jr z,e_quote
	inc hl
	cp '"'
	jr nz,fn_1
	ex de,hl
	pop hl
	ret

; nextrec: IX = the record after the file being read (for an include or incbin)
nextrec:
	ld a,(v_depth)
	cp MAXINC-1
	jr nc,nr_deep
	ld ix,(v_lev)
	ld de,IR_LEN
	add ix,de
	ret
nr_deep:
	ld hl,m_deep
	jp errx1

d_incl: call fname		; INCLUDE "file"
	push de
	call nextrec
	push ix
	call fopen
	pop ix
	jr c,inc_err
	ld (v_lev),ix
	ld hl,v_depth
	inc (hl)
	pop hl
	ret
inc_err:			; "cannot open: KERNEL/X.ASM"
	push ix
	pop hl
	ld de,IR_NAME
	add hl,de
	ld (v_ep),hl
	ld b,0
ie_1:	ld a,(hl)
	or a
	jr z,ie_2
	inc hl
	inc b
	jr ie_1
ie_2:	ld a,b
	ld (v_en),a
	ld hl,m_cant
	jp errx1

d_incbin:			; INCBIN "file": its bytes
	call fname
	push de
	call nextrec
	push ix
	call fopen
	pop ix
	jr c,inc_err
	ld a,(v_pass)
	cp 2
	jr z,ib_2
	ld a,(ix+FCB_SIZE+2)	; pass 1: only its size
	or (ix+FCB_SIZE+3)
	jr nz,ib_big
	ld e,(ix+FCB_SIZE)
	ld d,(ix+FCB_SIZE+1)
	ld hl,(v_pc)
	add hl,de
	ld (v_pc),hl
	ld hl,(v_size)
	add hl,de
	ld (v_size),hl
	ld a,(v_first)		; (the first bytes?)
	or a
	jr z,ib_end
	xor a
	ld (v_first),a
	ld hl,(v_lpc)
	ld (v_start),hl
ib_end: pop hl
	ret
ib_2:	call ctxrec		; pass 2: read it and pass it on
	ld e,(ix+IR_BUF)
	ld d,(ix+IR_BUF+1)
	push de
	ld bc,IBSIZE
	push ix
	call OS_READ
	pop ix
	pop hl
	jp c,e_read
	ld a,b
	or c
	jr z,ib_end
ib_3:	ld a,(hl)
	call emit
	inc hl
	dec c
	jr nz,ib_3
	jr ib_2
ib_big: ld hl,m_big
	jp errx1

d_if:	ld a,(v_skip)		; IF expr
	or a
	jr z,if_1
	inc a			; inside a skipped part: only count it
	ld (v_skip),a
	jr if_n
if_1:	call known
	ld a,d
	or e
	jr nz,if_n
	ld a,1			; false: skip to its ELSE or ENDIF
	ld (v_skip),a
if_n:	ld a,(v_ifn)
	inc a
	ld (v_ifn),a
	ret

d_else: ld a,(v_ifn)		; ELSE
	or a
	jr nz,el_ok
	ld hl,m_else
	jp errx
el_ok:
	ld a,(v_skip)
	cp 2
	ret nc			; inside a skipped part
	xor 1			; 0 -> 1 (the IF was true), 1 -> 0
	ld (v_skip),a
	ret

d_endif:
	ld a,(v_ifn)		; ENDIF
	or a
	jr nz,en_ok
	ld hl,m_endif
	jp errx
en_ok:
	dec a
	ld (v_ifn),a
	ld a,(v_skip)
	or a
	ret z
	dec a
	ld (v_skip),a
	ret

m_ops:	defm "bad operands"
	defb 0
m_range: defm "value out of range"
	defb 0
m_jr:	defm "relative jump too far"
	defb 0
m_known: defm "the value must be known here (it uses a later label)"
	defb 0
m_equ:	defm "EQU needs a name"
	defb 0
m_quote: defm "missing quote"
	defb 0
m_deep: defm "includes nested too deep"
	defb 0
m_cant: defm "cannot open: "
	defb 0
m_big:	defm "file too big"
	defb 0
m_else: defm "ELSE without IF"
	defb 0
m_endif: defm "ENDIF without IF"
	defb 0
