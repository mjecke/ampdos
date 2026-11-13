; ==========================================================================
; DISCORE.ASM - the Z80 disassembler itself, shared by MON (U) and DISASM.
; The includer defines the variables v_dstart ... v_dlen, v_dbuf, v_dbias
; (the byte at address A is read from A + v_dbias: 0 in MON), and dtarget
; (HL = an address used as an operand: add its text; usually "jr dnum16").
;
;   dis1: HL = address -> the instruction's text in v_dbuf, its length in v_dlen,
;   HL = the address of the next one.  How it decodes is described in MONDIS.ASM
;   (the bit fields x y z p q, small tables; DD / FD index prefixes; CB, ED).
; ==========================================================================

; ---------------------------------------------------------------- building the text
dch:				; append the character A to the text (keeps all)
	push hl
	ld hl,(v_dpt)
	ld (hl),a
	inc hl
	ld (v_dpt),hl
	pop hl
	ret

dstr:				; append the 0-terminated string at HL
	ld a,(hl)
	inc hl
	or a
	ret z
	call dch
	jr dstr

dnth:				; HL = table of strings, A = n: append the n'th
	or a
	jr z,dstr
	ld b,a
dnt_1:	ld a,(hl)
	inc hl
	or a
	jr nz,dnt_1
	djnz dnt_1
	jr dstr

dsp:	ld a,' '
	jr dch
dcomma: ld a,','
	jr dch

dhexd:				; A = 0..15: append its hex digit
	add a,'0'
	cp '9'+1
	jr c,dhx_1
	add a,7
dhx_1:	jr dch

dhex2:				; A = a byte: two hex digits
	ld b,a
	rrca
	rrca
	rrca
	rrca
	and 0Fh
	call dhexd
	ld a,b
	and 0Fh
	jr dhexd

dnum8:				; A = a byte: "41h", or "0F0h"
	ld c,a
	cp 0A0h
	jr c,dn8_1
	ld a,'0'
	call dch
dn8_1:	ld a,c
	call dhex2
	ld a,'h'
	jr dch

dnum16: 			; HL = a word: "8000h", "0C000h"
	ld a,h
	cp 0A0h
	jr c,dn16_1
	ld a,'0'
	call dch
dn16_1: ld a,h
	call dhex2
	ld a,l
	call dhex2
	ld a,'h'
	jr dch

dfetch: 			; A = the next byte of the instruction (keeps the rest).
	push hl 		; v_dpc is its address as the program sees it; the
	push de 		; byte is really at v_dpc + v_dbias (0 in MON)
	ld hl,(v_dpc)
	ld de,(v_dbias)
	inc hl
	ld (v_dpc),hl
	dec hl
	add hl,de
	ld a,(hl)
	pop de
	pop hl
	ret

dn:	call dfetch		; an 8-bit number
	jr dnum8
dnn:	call dfetch		; a 16-bit number
	ld e,a
	call dfetch
	ld h,a
	ld l,e
	jp dtarget		; (an address: a program may show it as a label)
drel:	call dfetch		; a relative jump: show where it goes
	ld e,a
	rla
	sbc a,a
	ld d,a
	ld hl,(v_dpc)
	add hl,de
	jp dtarget

ddisp:				; A = a displacement: "+05h)" or "-02h)"
	ld c,a
	ld a,'+'
	bit 7,c
	jr z,dds_1
	ld a,c
	neg
	ld c,a
	ld a,'-'
dds_1:	call dch
	ld a,c
	call dnum8
	ld a,')'
	jp dch

dxy:	ld a,(v_didx)		; X or Y
	cp 2
	ld a,'X'
	jr nz,dxy_1
	ld a,'Y'
dxy_1:	jp dch

drr:				; A = register number 0..7: B C D E H L (HL) A
	ld c,a
	ld a,(v_didx)
	or a
	jr z,dr_plain
	ld a,c
	cp 6
	jr z,dr_mem
	cp 4
	jr c,dr_plain
	cp 6
	jr nc,dr_plain
	ld a,(v_dmem)		; H, L: IXH, IXL, unless there is a (IX+d) as well
	or a
	jr nz,dr_plain
	ld a,'I'
	call dch
	call dxy
	ld a,c
	cp 4
	ld a,'H'
	jr z,dr_hl
	ld a,'L'
dr_hl:	jp dch
dr_plain:
	ld a,c
	ld hl,t_r
	jp dnth
dr_mem: ld a,'('
	call dch
	ld a,'I'
	call dch
	call dxy
	call dfetch
	jr ddisp

drp:				; A = pair number 0..3: BC DE HL SP (HL = IX, IY)
	ld c,a
	cp 2
	jr nz,drp_1
	ld a,(v_didx)
	or a
	jr z,drp_1
	ld a,'I'
	call dch
	jr dxy
drp_1:	ld a,c
	ld hl,t_rp
	jp dnth

drp2:				; the same for PUSH / POP: AF instead of SP
	cp 3
	jr nz,drp
	ld hl,s_af
	jp dstr

dhl:	ld a,2			; HL, or IX / IY
	jr drp

; ---------------------------------------------------------------- decoding
dfields:			; A = the opcode: v_dx, v_dy, v_dz, v_dp, v_dq
	ld (v_dop),a
	ld c,a
	and 7
	ld (v_dz),a
	ld a,c
	rrca
	rrca
	rrca
	and 7
	ld (v_dy),a
	ld b,a
	srl a
	ld (v_dp),a
	ld a,b
	and 1
	ld (v_dq),a
	ld a,c
	rlca
	rlca
	and 3
	ld (v_dx),a
	ret

djt:				; HL = table of addresses, A = n: jump to the n'th
	add a,a
	ld e,a
	ld d,0
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	jp (hl)

dis1:				; HL = address -> v_dbuf, v_dlen; HL = the next address
	ld (v_dstart),hl
	ld (v_dpc),hl
	ld hl,v_dbuf
	ld (v_dpt),hl
	xor a
	ld (v_didx),a
	call dfetch
	cp 0DDh
	jr z,di_ix
	cp 0FDh
	jr nz,d_main
di_ix:	cp 0DDh
	ld a,1
	jr z,di_1
	inc a
di_1:	ld (v_didx),a
	call dfetch
	cp 0DDh
	jp z,d_db
	cp 0FDh
	jp z,d_db
	cp 0EDh
	jp z,d_db
	cp 0CBh
	jp z,d_ddcb

d_main: call dfields
	xor a			; does this instruction have a (HL) operand?
	ld (v_dmem),a		; (then with IX / IY it is (IX+d))
	ld a,(v_didx)
	or a
	jr z,dm_end
	ld a,(v_dx)
	cp 1
	jr z,dm_1
	cp 2
	jr z,dm_2
	or a
	jr nz,dm_end
	ld a,(v_dz)		; x = 0: INC (HL), DEC (HL), LD (HL),n
	cp 4
	jr c,dm_end
	cp 7
	jr nc,dm_end
	ld a,(v_dy)
	cp 6
	jr nz,dm_end
	jr dm_set
dm_1:	ld a,(v_dy)		; x = 1: LD r,r' with one side (HL); HALT has both
	cp 6
	jr nz,dm_1b
	ld a,(v_dz)
	cp 6
	jr z,dm_end
	jr dm_set
dm_1b:	ld a,(v_dz)
	cp 6
	jr nz,dm_end
	jr dm_set
dm_2:	ld a,(v_dz)		; x = 2: ALU with (HL)
	cp 6
	jr nz,dm_end
dm_set: ld a,1
	ld (v_dmem),a
dm_end: ld a,(v_dx)
	or a
	jr nz,dm_x1
	ld a,(v_dz)
	ld hl,t_x0
	jp djt
dm_x1:	cp 1
	jr z,d_x1
	cp 2
	jr z,d_x2
	ld a,(v_dz)
	ld hl,t_x3
	jp djt

d_done: 			; the text ends; v_dlen = the length
	xor a
	call dch
	ld hl,(v_dpc)
	ld de,(v_dstart)
	or a
	sbc hl,de
	ld a,l
	ld (v_dlen),a
	ld hl,(v_dpc)
	ret

d_str:	call dstr
	jp d_done

d_db:				; not an instruction: DB first byte
	ld hl,(v_dstart)
	inc hl
	ld (v_dpc),hl
	ld hl,v_dbuf
	ld (v_dpt),hl
	ld hl,s_db
	call dstr
	ld hl,(v_dstart)
	ld de,(v_dbias)
	add hl,de
	ld a,(hl)
	call dnum8
	jp d_done

; ---- x = 1: LD r,r'  HALT
d_x1:	ld a,(v_dy)
	cp 6
	jr nz,x1_ld
	ld a,(v_dz)
	cp 6
	jr nz,x1_ld
	ld hl,s_halt
	jp d_str
x1_ld:	ld hl,s_ld
	call dstr
	ld a,(v_dy)
	call drr
	call dcomma
	ld a,(v_dz)
	call drr
	jp d_done

; ---- x = 2: ADD A,r  ADC  SUB  SBC  AND  XOR  OR  CP
d_x2:	ld a,(v_dy)
	ld hl,t_alu
	call dnth
	ld a,(v_dz)
	call drr
	jp d_done

; ---- x = 0
x0z0:	ld a,(v_dy)		; NOP  EX AF,AF'  DJNZ  JR  JR cc
	or a
	ld hl,s_nop
	jp z,d_str
	cp 1
	ld hl,s_exaf
	jp z,d_str
	cp 2
	ld hl,s_djnz
	jr z,x0z0_r
	cp 3
	ld hl,s_jr
	jr z,x0z0_r
	ld hl,s_jr
	call dstr
	ld a,(v_dy)
	sub 4
	ld hl,t_cc
	call dnth
	call dcomma
	call drel
	jp d_done
x0z0_r: call dstr
	call drel
	jp d_done

x0z1:	ld a,(v_dq)		; LD rp,nn   ADD HL,rp
	or a
	jr nz,x0z1_b
	ld hl,s_ld
	call dstr
	ld a,(v_dp)
	call drp
	call dcomma
	call dnn
	jp d_done
x0z1_b: ld hl,s_add
	call dstr
	call dhl
	call dcomma
	ld a,(v_dp)
	call drp
	jp d_done

x0z2:	ld a,(v_dp)		; LD (BC),A  LD (DE),A  LD (nn),HL  LD (nn),A  and back
	cp 2
	jr nc,x0z2_b
	ld a,(v_dq)
	add a,a
	ld b,a
	ld a,(v_dp)
	add a,b
	ld hl,t_ldbd
	call dnth
	jp d_done
x0z2_b: ld hl,s_ld
	call dstr
	ld a,(v_dq)
	or a
	jr nz,x0z2_c
	ld a,'('
	call dch
	call dnn
	ld a,')'
	call dch
	call dcomma
	ld a,(v_dp)
	cp 2
	jr nz,x0z2_a
	call dhl
	jp d_done
x0z2_a: ld a,'A'
	call dch
	jp d_done
x0z2_c: ld a,(v_dp)
	cp 2
	jr nz,x0z2_d
	call dhl
	jr x0z2_e
x0z2_d: ld a,'A'
	call dch
x0z2_e: call dcomma
	ld a,'('
	call dch
	call dnn
	ld a,')'
	call dch
	jp d_done

x0z3:	ld a,(v_dq)		; INC rp  DEC rp
	or a
	ld hl,s_inc
	jr z,x0z3_a
	ld hl,s_dec
x0z3_a: call dstr
	ld a,(v_dp)
	call drp
	jp d_done

x0z4:	ld hl,s_inc		; INC r
	call dstr
	ld a,(v_dy)
	call drr
	jp d_done
x0z5:	ld hl,s_dec		; DEC r
	call dstr
	ld a,(v_dy)
	call drr
	jp d_done
x0z6:	ld hl,s_ld		; LD r,n
	call dstr
	ld a,(v_dy)
	call drr
	call dcomma
	call dn
	jp d_done
x0z7:	ld a,(v_dy)		; RLCA  RRCA  RLA  RRA  DAA  CPL  SCF  CCF
	ld hl,t_acc
	call dnth
	jp d_done

; ---- x = 3
x3z0:	ld hl,s_ret1		; RET cc
	call dstr
	ld a,(v_dy)
	ld hl,t_cc
	call dnth
	jp d_done
x3z1:	ld a,(v_dq)		; POP rp2  RET  EXX  JP (HL)  LD SP,HL
	or a
	jr nz,x3z1_b
	ld hl,s_pop
	call dstr
	ld a,(v_dp)
	call drp2
	jp d_done
x3z1_b: ld a,(v_dp)
	or a
	ld hl,s_ret
	jp z,d_str
	dec a
	ld hl,s_exx
	jp z,d_str
	dec a
	jr z,x3z1_j
	ld hl,s_ldsp
	call dstr
	call dhl
	jp d_done
x3z1_j: ld hl,s_jp
	call dstr
	ld a,'('
	call dch
	call dhl
	ld a,')'
	call dch
	jp d_done
x3z2:	ld hl,s_jp		; JP cc,nn
	call dstr
	ld a,(v_dy)
	ld hl,t_cc
	call dnth
	call dcomma
	call dnn
	jp d_done
x3z3:	ld a,(v_dy)
	ld hl,t_x3z3
	jp djt
x3z3_0: ld hl,s_jp		; JP nn
	call dstr
	call dnn
	jp d_done
x3z3_2: ld hl,s_out		; OUT (n),A
	call dstr
	call dn
	ld hl,s_pa
	jp d_str
x3z3_3: ld hl,s_ina		; IN A,(n)
	call dstr
	call dn
	ld a,')'
	call dch
	jp d_done
x3z3_4: ld hl,s_exsp		; EX (SP),HL
	call dstr
	call dhl
	jp d_done
x3z3_5: ld hl,s_exde
	jp d_str
x3z3_6: ld hl,s_di
	jp d_str
x3z3_7: ld hl,s_ei
	jp d_str
x3z4:	ld hl,s_call		; CALL cc,nn
	call dstr
	ld a,(v_dy)
	ld hl,t_cc
	call dnth
	call dcomma
	call dnn
	jp d_done
x3z5:	ld a,(v_dq)		; PUSH rp2  CALL nn  (ED)
	or a
	jr nz,x3z5_b
	ld hl,s_push
	call dstr
	ld a,(v_dp)
	call drp2
	jp d_done
x3z5_b: ld a,(v_dp)
	cp 2
	jp z,d_ed
	ld hl,s_call
	call dstr
	call dnn
	jp d_done
x3z6:	ld a,(v_dy)		; ADD A,n ...
	ld hl,t_alu
	call dnth
	call dn
	jp d_done
x3z7:	ld hl,s_rst		; RST 00h .. 38h
	call dstr
	ld a,(v_dy)
	add a,a
	add a,a
	add a,a
	call dnum8
	jp d_done

; ---- CB: rotates, BIT, RES, SET.  DD CB d op and FD CB d op have the displacement first.
d_cb:	call dfetch
	call dcb
	jp d_done
d_ddcb: call dfetch
	ld (v_ddv),a
	call dfetch
	call dcb
	jp d_done

dcb:	call dfields		; A = the CB opcode
	ld a,(v_dx)
	or a
	jr nz,cb_1
	ld a,(v_dy)
	ld hl,t_rot
	call dnth
	call dsp
	jr cb_op
cb_1:	dec a
	ld hl,s_bit
	jr z,cb_2
	dec a
	ld hl,s_res
	jr z,cb_2
	ld hl,s_set
cb_2:	call dstr
	ld a,(v_dy)
	add a,'0'
	call dch
	call dcomma
cb_op:	ld a,(v_didx)
	or a
	jr z,cb_plain
	ld a,'('
	call dch
	ld a,'I'
	call dch
	call dxy
	ld a,(v_ddv)
	call ddisp
	ld a,(v_dx)		; (IX+d),r: the result also goes to a register
	cp 1
	ret z
	ld a,(v_dz)
	cp 6
	ret z
	call dcomma
	ld a,(v_dz)
	ld hl,t_r
	jp dnth
cb_plain:
	ld a,(v_dz)
	jp drr

; ---- ED
d_ed:	call dfetch
	call dfields
	ld a,(v_dx)
	cp 1
	jr z,ed_1
	cp 2
	jp nz,d_db
	ld a,(v_dz)		; block instructions: z 0-3, y 4-7
	cp 4
	jp nc,d_db
	ld a,(v_dy)
	cp 4
	jp c,d_db
	sub 4
	ld b,a
	ld a,(v_dz)
	add a,a
	add a,a
	add a,b
	ld hl,t_bli
	call dnth
	jp d_done
ed_1:	ld a,(v_dz)
	ld hl,t_edz
	jp djt
edz0:	ld hl,s_in		; IN r,(C)
	call dstr
	ld a,(v_dy)
	cp 6
	ld a,'F'
	jr z,edz0_a
	ld a,(v_dy)
	ld hl,t_r
	call dnth
	jr edz0_b
edz0_a: call dch
edz0_b: ld hl,s_c
	jp d_str
edz1:	ld hl,s_outc		; OUT (C),r
	call dstr
	ld a,(v_dy)
	cp 6
	ld a,'0'
	jr z,edz1_a
	ld a,(v_dy)
	ld hl,t_r
	call dnth
	jp d_done
edz1_a: call dch
	jp d_done
edz2:	ld a,(v_dq)		; SBC HL,rp   ADC HL,rp
	or a
	ld hl,s_sbc
	jr z,edz2_a
	ld hl,s_adc
edz2_a: call dstr
	ld a,(v_dp)
	call drp
	jp d_done
edz3:	ld a,(v_dq)		; LD (nn),rp   LD rp,(nn)
	or a
	jr nz,edz3_b
	ld hl,s_ldp
	call dstr
	call dnn
	ld a,')'
	call dch
	call dcomma
	ld a,(v_dp)
	call drp
	jp d_done
edz3_b: ld hl,s_ld
	call dstr
	ld a,(v_dp)
	call drp
	call dcomma
	ld a,'('
	call dch
	call dnn
	ld a,')'
	call dch
	jp d_done
edz4:	ld hl,s_neg
	jp d_str
edz5:	ld a,(v_dy)
	cp 1
	ld hl,s_reti
	jp z,d_str
	ld hl,s_retn
	jp d_str
edz6:	ld hl,s_im		; IM 0 / 1 / 2
	call dstr
	ld a,(v_dy)
	ld hl,t_im
	call dnth
	jp d_done
edz7:	ld a,(v_dy)		; LD I,A  LD R,A  LD A,I  LD A,R  RRD  RLD  NOP  NOP
	ld hl,t_ed7
	call dnth
	jp d_done

; ---------------------------------------------------------------- jump tables
t_x0:	defw x0z0,x0z1,x0z2,x0z3,x0z4,x0z5,x0z6,x0z7
t_x3:	defw x3z0,x3z1,x3z2,x3z3,x3z4,x3z5,x3z6,x3z7
t_x3z3: defw x3z3_0,d_cb,x3z3_2,x3z3_3,x3z3_4,x3z3_5,x3z3_6,x3z3_7
t_edz:	defw edz0,edz1,edz2,edz3,edz4,edz5,edz6,edz7

; ---------------------------------------------------------------- the words
t_r:	defm "B"
	defb 0
	defm "C"
	defb 0
	defm "D"
	defb 0
	defm "E"
	defb 0
	defm "H"
	defb 0
	defm "L"
	defb 0
	defm "(HL)"
	defb 0
	defm "A"
	defb 0
t_rp:	defm "BC"
	defb 0
	defm "DE"
	defb 0
	defm "HL"
	defb 0
	defm "SP"
	defb 0
t_cc:	defm "NZ"
	defb 0
	defm "Z"
	defb 0
	defm "NC"
	defb 0
	defm "C"
	defb 0
	defm "PO"
	defb 0
	defm "PE"
	defb 0
	defm "P"
	defb 0
	defm "M"
	defb 0
t_alu:	defm "ADD A,"
	defb 0
	defm "ADC A,"
	defb 0
	defm "SUB "
	defb 0
	defm "SBC A,"
	defb 0
	defm "AND "
	defb 0
	defm "XOR "
	defb 0
	defm "OR "
	defb 0
	defm "CP "
	defb 0
t_rot:	defm "RLC"
	defb 0
	defm "RRC"
	defb 0
	defm "RL"
	defb 0
	defm "RR"
	defb 0
	defm "SLA"
	defb 0
	defm "SRA"
	defb 0
	defm "SLL"
	defb 0
	defm "SRL"
	defb 0
t_acc:	defm "RLCA"
	defb 0
	defm "RRCA"
	defb 0
	defm "RLA"
	defb 0
	defm "RRA"
	defb 0
	defm "DAA"
	defb 0
	defm "CPL"
	defb 0
	defm "SCF"
	defb 0
	defm "CCF"
	defb 0
t_ldbd: defm "LD (BC),A"
	defb 0
	defm "LD (DE),A"
	defb 0
	defm "LD A,(BC)"
	defb 0
	defm "LD A,(DE)"
	defb 0
t_im:	defm "0"
	defb 0
	defm "0"
	defb 0
	defm "1"
	defb 0
	defm "2"
	defb 0
	defm "0"
	defb 0
	defm "0"
	defb 0
	defm "1"
	defb 0
	defm "2"
	defb 0
t_ed7:	defm "LD I,A"
	defb 0
	defm "LD R,A"
	defb 0
	defm "LD A,I"
	defb 0
	defm "LD A,R"
	defb 0
	defm "RRD"
	defb 0
	defm "RLD"
	defb 0
	defm "NOP"
	defb 0
	defm "NOP"
	defb 0
t_bli:	defm "LDI"
	defb 0
	defm "LDD"
	defb 0
	defm "LDIR"
	defb 0
	defm "LDDR"
	defb 0
	defm "CPI"
	defb 0
	defm "CPD"
	defb 0
	defm "CPIR"
	defb 0
	defm "CPDR"
	defb 0
	defm "INI"
	defb 0
	defm "IND"
	defb 0
	defm "INIR"
	defb 0
	defm "INDR"
	defb 0
	defm "OUTI"
	defb 0
	defm "OUTD"
	defb 0
	defm "OTIR"
	defb 0
	defm "OTDR"
	defb 0

s_nop:	defm "NOP"
	defb 0
s_exaf: defm "EX AF,AF'"
	defb 0
s_djnz: defm "DJNZ "
	defb 0
s_jr:	defm "JR "
	defb 0
s_ld:	defm "LD "
	defb 0
s_ldp:	defm "LD ("
	defb 0
s_ldsp: defm "LD SP,"
	defb 0
s_add:	defm "ADD "
	defb 0
s_inc:	defm "INC "
	defb 0
s_dec:	defm "DEC "
	defb 0
s_halt: defm "HALT"
	defb 0
s_ret:	defm "RET"
	defb 0
s_ret1: defm "RET "
	defb 0
s_pop:	defm "POP "
	defb 0
s_push: defm "PUSH "
	defb 0
s_exx:	defm "EXX"
	defb 0
s_jp:	defm "JP "
	defb 0
s_call: defm "CALL "
	defb 0
s_out:	defm "OUT ("
	defb 0
s_pa:	defm "),A"
	defb 0
s_ina:	defm "IN A,("
	defb 0
s_exsp: defm "EX (SP),"
	defb 0
s_exde: defm "EX DE,HL"
	defb 0
s_di:	defm "DI"
	defb 0
s_ei:	defm "EI"
	defb 0
s_rst:	defm "RST "
	defb 0
s_db:	defm "DB "
	defb 0
s_bit:	defm "BIT "
	defb 0
s_res:	defm "RES "
	defb 0
s_set:	defm "SET "
	defb 0
s_in:	defm "IN "
	defb 0
s_outc: defm "OUT (C),"
	defb 0
s_c:	defm ",(C)"
	defb 0
s_sbc:	defm "SBC HL,"
	defb 0
s_adc:	defm "ADC HL,"
	defb 0
s_neg:	defm "NEG"
	defb 0
s_reti: defm "RETI"
	defb 0
s_retn: defm "RETN"
	defb 0
s_im:	defm "IM "
	defb 0
s_af:	defm "AF"
	defb 0
