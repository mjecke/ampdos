; made by PROGRAMS/BASIC/mkbasic.py: do not edit (edit the files in PROGRAMS/BASIC/)
	include "KERNEL/INC/OS.INC"
;==================================================================================
; The updates to the original BASIC within this file are copyright Grant Searle
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.hostei.com/grant/index.html
;
; eMail: home.micros01@btinternet.com
;
; If the above don't work, please perform an Internet search to see if I have
; updated the web page hosting service.
;
;==================================================================================

; NASCOM ROM BASIC Ver 4.7, (C) 1978 Microsoft
; Scanned from source published in 80-BUS NEWS from Vol 2, Issue 3
; (May-June 1983) to Vol 3, Issue 3 (May-June 1984)
; Adapted for the freeware Zilog Macro Assembler 2.10 to produce
; the original ROM code (checksum A934H). PA

; GENERAL EQUATES

CTRLC: equ    03H
CTRLG: equ    07H
BKSP: equ    08H
LF: equ    0AH
CS: equ    0CH
CR: equ    0DH
CTRLO: equ    0FH
CTRLQ: equ	11H
CTRLR: equ    12H
CTRLS: equ    13H
CTRLU: equ    15H
ESC: equ    1BH
DEL: equ    7FH
WRKSPC: equ 0A09Fh
USR: equ    WRKSPC+3H
OUTSUB: equ    WRKSPC+6H
OTPORT: equ    WRKSPC+7H
DIVSUP: equ    WRKSPC+9H
DIV1: equ    WRKSPC+0AH
DIV2: equ    WRKSPC+0EH
DIV3: equ    WRKSPC+12H
DIV4: equ    WRKSPC+15H
SEED: equ    WRKSPC+17H
LSTRND: equ    WRKSPC+3AH
INPSUB: equ    WRKSPC+3EH
INPORT: equ    WRKSPC+3FH
NULLS: equ    WRKSPC+41H
LWIDTH: equ    WRKSPC+42H
COMMAN: equ    WRKSPC+43H
NULFLG: equ    WRKSPC+44H
CTLOFG: equ    WRKSPC+45H
LINESC: equ    WRKSPC+46H
LINESN: equ    WRKSPC+48H
CHKSUM: equ    WRKSPC+4AH
NMIFLG: equ    WRKSPC+4CH
BRKFLG: equ    WRKSPC+4DH
RINPUT: equ    WRKSPC+4EH
POINT: equ    WRKSPC+51H
PSET: equ    WRKSPC+54H
RESET: equ    WRKSPC+57H
STRSPC: equ    WRKSPC+5AH
LINEAT: equ    WRKSPC+5CH
BASTXT: equ    WRKSPC+5EH
BUFFER: equ    WRKSPC+61H
STACK: equ    WRKSPC+66H
CURPOS: equ    WRKSPC+0ABH
LCRFLG: equ    WRKSPC+0ACH
TYPE: equ    WRKSPC+0ADH
DATFLG: equ    WRKSPC+0AEH
LSTRAM: equ    WRKSPC+0AFH
TMSTPT: equ    WRKSPC+0B1H
TMSTPL: equ    WRKSPC+0B3H
TMPSTR: equ    WRKSPC+0BFH
STRBOT: equ    WRKSPC+0C3H
CUROPR: equ    WRKSPC+0C5H
LOOPST: equ    WRKSPC+0C7H
DATLIN: equ    WRKSPC+0C9H
FORFLG: equ    WRKSPC+0CBH
LSTBIN: equ    WRKSPC+0CCH
READFG: equ    WRKSPC+0CDH
BRKLIN: equ    WRKSPC+0CEH
NXTOPR: equ    WRKSPC+0D0H
ERRLIN: equ    WRKSPC+0D2H
CONTAD: equ    WRKSPC+0D4H
PROGND: equ    WRKSPC+0D6H
VAREND: equ    WRKSPC+0D8H
ARREND: equ    WRKSPC+0DAH
NXTDAT: equ    WRKSPC+0DCH
FNRGNM: equ    WRKSPC+0DEH
FNARG: equ    WRKSPC+0E0H
FPREG: equ    WRKSPC+0E4H
FPEXP: equ    FPREG+3
SGNRES: equ    WRKSPC+0E8H
PBUFF: equ    WRKSPC+0E9H
MULVAL: equ    WRKSPC+0F6H
PROGST: equ    WRKSPC+0F9H
STLOOK: equ    WRKSPC+15DH
NF: equ    00H
SN: equ    02H
RG: equ    04H
OD: equ    06H
FC: equ    08H
OV: equ    0AH
OM: equ    0CH
UL: equ    0EH
BS: equ    10H
DD: equ    12H
DZ: equ    14H
ID: equ    16H
TM: equ    18H
OS: equ    1AH
LS: equ    1CH
ST: equ    1EH
CN: equ    20H
UF: equ    22H
MO: equ    24H
HX: equ    26H
BN: equ    28H
  org 8000h
COLD: JP      STARTB
WARM: JP      WARMST
STARTB: CALL	DXARG
  LD	  IX,0
  JP	  CSTART
  defw	 DEINT
  defw	 ABPASS
WARMST: LD	SP,STACK
BRKRET: CALL	CLREG
  JP	  PRNTOK
FNCTAB: defw   SGN
  defw	 INT
  defw	 ABS
  defw	 USR
  defw	 FRE
  defw	 INP
  defw	 POS
  defw	 SQR
  defw	 RND
  defw	 LOG
  defw	 EXP
  defw	 COS
  defw	 SIN
  defw	 TAN
  defw	 ATN
  defw	 PEEK
  defw	 DEEK
  defw	 POINT
  defw	 LEN
  defw	 STR
  defw	 VAL
  defw	 ASC
  defw	 CHR
  defw	 HEX
  defw	 BIN
  defw	 LEFT
  defw	 RIGHT
  defw	 MID
WORDS: defb   197,"ND"
  defb	 198,"OR"
  defb	 206,"EXT"
  defb	 196,"ATA"
  defb	 201,"NPUT"
  defb	 196,"IM"
  defb	 210,"EAD"
  defb	 204,"ET"
  defb	 199,"OTO"
  defb	 210,"UN"
  defb	 201,"F"
  defb	 210,"ESTORE"
  defb	 199,"OSUB"
  defb	 210,"ETURN"
  defb	 210,"EM"
  defb	 211,"TOP"
  defb	 207,"UT"
  defb	 207,"N"
  defb	 204,"OAD"
  defb	 215,"AIT"
  defb	 196,"EF"
  defb	 208,"OKE"
  defb	 196,"OKE"
  defb	 211,"TPRINT"
  defb	 204,"INES"
  defb	 196,"OS"
  defb	 215,"IDTH"
  defb	 211,"AVE"
  defb	 196,"PRINT"
  defb	 211,"LEEP"
  defb	 208,"RINT"
  defb	 195,"ONT"
  defb	 204,"IST"
  defb	 195,"LEAR"
  defb	 211,"LOAD"
  defb	 211,"SAVE"
  defb	 206,"EW"
  defb	 212,"AB("
  defb	 212,"O"
  defb	 198,"N"
  defb	 211,"PC("
  defb	 212,"HEN"
  defb	 206,"OT"
  defb	 211,"TEP"
  defb	 171
  defb	 173
  defb	 170
  defb	 175
  defb	 222
  defb	 193,"ND"
  defb	 207,"R"
  defb	 190
  defb	 189
  defb	 188
  defb	 211,"GN"
  defb	 201,"NT"
  defb	 193,"BS"
  defb	 213,"SR"
  defb	 198,"RE"
  defb	 201,"NP"
  defb	 208,"OS"
  defb	 211,"QR"
  defb	 210,"ND"
  defb	 204,"OG"
  defb	 197,"XP"
  defb	 195,"OS"
  defb	 211,"IN"
  defb	 212,"AN"
  defb	 193,"TN"
  defb	 208,"EEK"
  defb	 196,"EEK"
  defb	 208,"OINT"
  defb	 204,"EN"
  defb	 211,"TR$"
  defb	 214,"AL"
  defb	 193,"SC"
  defb	 195,"HR$"
  defb	 200,"EX$"
  defb	 194,"IN$"
  defb	 204,"EFT$"
  defb	 210,"IGHT$"
  defb	 205,"ID$"
  defb	 80H
WORDTB: defw   PEND
  defw	 FOR
  defw	 NEXT
  defw	 DATA
  defw	 INPUT
  defw	 DIM
  defw	 READ
  defw	 LET
  defw	 GOTO
  defw	 RUN
  defw	 IF
  defw	 RESTOR
  defw	 GOSUB
  defw	 RETURN
  defw	 REM
  defw	 STOP
  defw	 POUT
  defw	 ON
  defw	 DXLOAD
  defw	 WAIT
  defw	 DEF
  defw	 POKE
  defw	 DOKE
  defw	 STPRINT
  defw	 LINES
  defw	 DXDOS
  defw	 WIDTH
  defw	 DXSAVE
  defw	 DPRINT
  defw	 SLEEP
  defw	 PRINT
  defw	 CONT
  defw	 LIST
  defw	 CLEAR
  defw	 SLOAD
  defw	 SSAVE
  defw	 NEW
ZEND: equ    080H
ZFOR: equ    081H
ZDATA: equ    083H
ZGOTO: equ    088H
ZGOSUB: equ    08CH
ZREM: equ    08EH
ZPRINT: equ    09EH
ZNEW: equ    0A4H
ZTAB: equ    0A5H
ZTO: equ    0A6H
ZFN: equ    0A7H
ZSPC: equ    0A8H
ZTHEN: equ    0A9H
ZNOT: equ    0AAH
ZSTEP: equ    0ABH
ZPLUS: equ    0ACH
ZMINUS: equ    0ADH
ZTIMES: equ    0AEH
ZDIV: equ    0AFH
ZOR: equ    0B2H
ZGTR: equ    0B3H
ZEQUAL: equ    0B4H
ZLTH: equ    0B5H
ZSGN: equ    0B6H
ZPOINT: equ    0C7H
ZLEFT: equ    0CDH +2
PRITAB: defb   79H
  defw	 PADD
  defb	 79H
  defw	 PSUB
  defb	 7CH
  defw	 MULT
  defb	 7CH
  defw	 DIV
  defb	 7FH
  defw	 POWER
  defb	 50H
  defw	 PAND
  defb	 46H
  defw	 POR
ERRORS: defb   "NF"
  defb	 "SN"
  defb	 "RG"
  defb	 "OD"
  defb	 "FC"
  defb	 "OV"
  defb	 "OM"
  defb	 "UL"
  defb	 "BS"
  defb	 "DD"
  defb	 "/0"
  defb	 "ID"
  defb	 "TM"
  defb	 "OS"
  defb	 "LS"
  defb	 "ST"
  defb	 "CN"
  defb	 "UF"
  defb	 "MO"
  defb	 "HX"
  defb	 "BN"
ERRMSG: defb   " Error",0
INMSG: defb   " in ",0
ZERBYT: equ    $-1
OKMSG: defb   "Ok",CR,LF,0,0
BRKMSG: defb   "Break",0
BAKSTK: LD	HL,4
  ADD	  HL,SP
LOKFOR: LD	A,(HL)
  INC	  HL
  CP	  ZFOR
  RET	  NZ
  LD	  C,(HL)
  INC	  HL
  LD	  B,(HL)
  INC	  HL
  PUSH	  HL
  LD	  L,C
  LD	  H,B
  LD	  A,D
  OR	  E
  EX	  DE,HL
  JR	  Z,INDFND
  EX	  DE,HL
  CALL	  CPDEHL
INDFND: LD	BC,16-3
  POP	  HL
  RET	  Z
  ADD	  HL,BC
  JR	  LOKFOR
MOVUP: CALL    ENFMEM
MOVSTR: PUSH	BC
  EX	  (SP),HL
  POP	  BC
MOVLP: PUSH    DE
  PUSH	  HL
  OR	  A
  SBC	  HL,DE
  INC	  HL
  EX	  (SP),HL
  LD	  D,B
  LD	  E,C
  POP	  BC
  LDDR
  INC	  HL
  INC	  DE
  LD	  B,D
  LD	  C,E
  POP	  DE
  LD	  A,(HL)
  CP	  A
  RET
CHKSTK: PUSH	HL
  LD	  HL,(ARREND)
  LD	  B,0
  ADD	  HL,BC
  ADD	  HL,BC
  defb	 3EH
ENFMEM: PUSH	HL
  LD	  A,0D0H
  SUB	  L
  LD	  L,A
  LD	  A,0FFH
  SBC	  A,H
  JR	  C,OMERR
  LD	  H,A
  ADD	  HL,SP
  POP	  HL
  RET	  C
OMERR: LD      E,OM
  JR	  ERROR
DATSNR: LD	HL,(DATLIN)
  LD	  (LINEAT),HL
SNERR: LD      E,SN
  defb	 01H
DZERR: LD      E,DZ
  defb	 01H
NFERR: LD      E,NF
  defb	 01H
DDERR: LD      E,DD
  defb	 01H
UFERR: LD      E,UF
  defb	 01H
OVERR: LD      E,OV
  defb	 01H
TMERR: LD      E,TM
ERROR: CALL    EXTCLR
  CALL	  CLREG
  LD	  (CTLOFG),A
  CALL	  STTLIN
  LD	  HL,ERRORS
  LD	  D,A
  LD	  A,'?'
  CALL	  OUTC
  ADD	  HL,DE
  LD	  A,(HL)
  CALL	  OUTC
  CALL	  GETCHR
  CALL	  OUTC
  LD	  HL,ERRMSG
ERRIN: CALL    PRS
  LD	  HL,(LINEAT)
  LD	  DE,-2
  CALL	  CPDEHL
  JP	  Z,CSTART
  LD	  A,H
  AND	  L
  INC	  A
  CALL	  NZ,LINEIN
  defb	 3EH
POPNOK: POP	BC
PRNTOK: CALL	EXTEND
  XOR	  A
  LD	  (CTLOFG),A
  CALL	  STTLIN
  LD	  HL,OKMSG
  CALL	  PRS
GETCMD: LD	HL,-1
  LD	  (LINEAT),HL
  CALL	  GETLIN
  JR	  C,GETCMD
  CALL	  GETCHR
  INC	  A
  DEC	  A
  JR	  Z,GETCMD
  PUSH	  AF
  CALL	  ATOH
  PUSH	  DE
  CALL	  CRUNCH
  LD	  B,A
  POP	  DE
  POP	  AF
  JP	  NC,EXCUTE
  PUSH	  DE
  PUSH	  BC
  XOR	  A
  LD	  (LSTBIN),A
  CALL	  GETCHR
  OR	  A
  PUSH	  AF
  CALL	  SRCHLN
  JR	  C,LINFND
  POP	  AF
  PUSH	  AF
  JP	  Z,ULERR
  OR	  A
LINFND: PUSH	BC
  JR	  NC,INEWLN
  EX	  DE,HL
  LD	  HL,(PROGND)
SFTPRG: LD	A,(DE)
  LD	  (BC),A
  INC	  BC
  INC	  DE
  CALL	  CPDEHL
  JR	  NZ,SFTPRG
  LD	  H,B
  LD	  L,C
  LD	  (PROGND),HL
INEWLN: POP	DE
  POP	  AF
  JR	  Z,SETPTR
  LD	  HL,(PROGND)
  EX	  (SP),HL
  POP	  BC
  ADD	  HL,BC
  PUSH	  HL
  CALL	  MOVUP
  POP	  HL
  LD	  (PROGND),HL
  EX	  DE,HL
  LD	  (HL),H
  POP	  DE
  INC	  HL
  INC	  HL
  LD	  (HL),E
  INC	  HL
  LD	  (HL),D
  INC	  HL
  LD	  DE,BUFFER
MOVBUF: LD	A,(DE)
  LD	  (HL),A
  INC	  HL
  INC	  DE
  OR	  A
  JR	  NZ,MOVBUF
SETPTR: CALL	RUNFST
  INC	  HL
  EX	  DE,HL
PTRLP: LD      H,D
  LD	  L,E
  LD	  A,(HL)
  INC	  HL
  OR	  (HL)
  JR	  Z,GETCMD
  INC	  HL
  INC	  HL
  INC	  HL
  XOR	  A
FNDEND: CP	(HL)
  INC	  HL
  JR	  NZ,FNDEND
  EX	  DE,HL
  LD	  (HL),E
  INC	  HL
  LD	  (HL),D
  JR	  PTRLP
SRCHLN: LD	HL,(BASTXT)
SRCHLP: LD	B,H
  LD	  C,L
  LD	  A,(HL)
  INC	  HL
  OR	  (HL)
  DEC	  HL
  RET	  Z
  INC	  HL
  INC	  HL
  INC	  HL
  LD	  A,(HL)
  CP	  D
  JR	  NZ,SRCHDF
  DEC	  HL
  LD	  A,(HL)
  CP	  E
  JR	  NZ,SRCHDF
  LD	  H,B
  LD	  L,C
  LD	  A,(HL)
  INC	  HL
  LD	  H,(HL)
  LD	  L,A
  SCF
  RET
SRCHDF: LD	H,B
  LD	  L,C
  LD	  A,(HL)
  INC	  HL
  LD	  H,(HL)
  LD	  L,A
  JR	  C,SRCHLP
  RET
NEW: RET     NZ
CLRPTR: LD	HL,(BASTXT)
  XOR	  A
  LD	  (HL),A
  INC	  HL
  LD	  (HL),A
  INC	  HL
  LD	  (PROGND),HL
RUNFST: LD	HL,(BASTXT)
  DEC	  HL
INTVAR: LD	(BRKLIN),HL
  LD	  HL,(LSTRAM)
  LD	  (STRBOT),HL
  XOR	  A
  CALL	  RESTOR
  LD	  HL,(PROGND)
  LD	  (VAREND),HL
  LD	  (ARREND),HL
CLREG: POP     BC
  LD	  HL,(STRSPC)
  LD	  SP,HL
  LD	  HL,TMSTPL
  LD	  (TMSTPT),HL
  XOR	  A
  LD	  L,A
  LD	  H,A
  LD	  (CONTAD),HL
  LD	  (FORFLG),A
  LD	  (FNRGNM),HL
  PUSH	  HL
  PUSH	  BC
DOAGN: LD      HL,(BRKLIN)
  RET
PROMPT: LD	A,'?'
  CALL	  OUTC
  LD	  A,' '
  CALL	  OUTC
  JP	  RINPUT
CRUNCH: XOR	A
  LD	  (DATFLG),A
  LD	  C,2+3
  LD	  DE,BUFFER
CRNCLP: LD	A,(HL)
  CP	  ' '
  JR	  Z,MOVDIR
  LD	  B,A
  CP	  '"'
  JP	  Z,CPYLIT
  OR	  A
  JP	  Z,ENDBUF
  LD	  A,(DATFLG)
  OR	  A
  LD	  A,(HL)
  JR	  NZ,MOVDIR
  CP	  '?'
  LD	  A,ZPRINT
  JR	  Z,MOVDIR
  LD	  A,(HL)
  CP	  '0'
  JR	  C,FNDWRD
  CP	  60
  JR	  C,MOVDIR
FNDWRD: PUSH	DE
  LD	  DE,WORDS-1
  PUSH	  BC
  LD	  BC,RETNAD
  PUSH	  BC
  LD	  B,ZEND-1
  LD	  A,(HL)
  CP	  'a'
  JR	  C,SEARCH
  CP	  'z'+1
  JR	  NC,SEARCH
  AND	  01011111B
  LD	  (HL),A
SEARCH: LD	C,(HL)
  EX	  DE,HL
GETNXT: INC	HL
  OR	  (HL)
  JP	  P,GETNXT
  INC	  B
  LD	  A, (HL)
  AND	  01111111B
  RET	  Z
  CP	  C
  JR	  NZ,GETNXT
  EX	  DE,HL
  PUSH	  HL
NXTBYT: INC	DE
  LD	  A,(DE)
  OR	  A
  JP	  M,MATCH
  LD	  C,A
  LD	  A,B
  CP	  ZGOTO
  JR	  NZ,NOSPC
  CALL	  GETCHR
  DEC	  HL
NOSPC: INC     HL
  LD	  A,(HL)
  CP	  'a'
  JR	  C,NOCHNG
  AND	  01011111B
NOCHNG: CP	C
  JR	  Z,NXTBYT
  POP	  HL
  JR	  SEARCH
MATCH: LD      C,B
  POP	  AF
  EX	  DE,HL
  RET
RETNAD: EX	DE,HL
  LD	  A,C
  POP	  BC
  POP	  DE
MOVDIR: INC	HL
  LD	  (DE),A
  INC	  DE
  INC	  C
  SUB	  ':'
  JR	  Z,SETLIT
  CP	  ZDATA-3AH
  JR	  NZ,TSTREM
SETLIT: LD	(DATFLG),A
TSTREM: SUB	ZREM-3AH
  JP	  NZ,CRNCLP
  LD	  B,A
NXTCHR: LD	A,(HL)
  OR	  A
  JR	  Z,ENDBUF
  CP	  B
  JR	  Z,MOVDIR
CPYLIT: INC	HL
  LD	  (DE),A
  INC	  C
  INC	  DE
  JR	  NXTCHR
ENDBUF: LD	HL,BUFFER-1
  LD	  (DE),A
  INC	  DE
  LD	  (DE),A
  INC	  DE
  LD	  (DE),A
  RET
DODEL: LD      A,(NULFLG)
  OR	  A
  LD	  A,0
  LD	  (NULFLG),A
  JR	  NZ,ECHDEL
  DEC	  B
  JR	  Z,GETLIN
  CALL	  OUTC
  defb	 3EH
ECHDEL: DEC	B
  DEC	  HL
  JR	  Z,OTKLN
  LD	  A,(HL)
  CALL	  OUTC
  JR	  MORINP
DELCHR: DEC	B
  DEC	  HL
  CALL	  OUTC
  JR	  NZ,MORINP
OTKLN: CALL    OUTC
KILIN: CALL    PRNTCRLF
  JR	  TTYLIN
GETLIN:
TTYLIN: LD	HL,BUFFER
  LD	  B,1
  XOR	  A
  LD	  (NULFLG),A
MORINP: CALL	CLOTST
  LD	  C,A
  CP	  DEL
  JR	  Z,DODEL
  LD	  A,(NULFLG)
  OR	  A
  JR	  Z,PROCES
  LD	  A,0
  CALL	  OUTC
  XOR	  A
  LD	  (NULFLG),A
PROCES: LD	A,C
  CP	  CTRLG
  JR	  Z,PUTCTL
  CP	  CTRLC
  CALL	  Z,PRNTCRLF
  SCF
  RET	  Z
  CP	  CR
  JP	  Z,ENDINP
  CP	  CTRLU
  JR	  Z,KILIN
  CP	  BKSP
  JR	  Z,DELCHR
  CP	  CTRLR
  JR	  NZ,PUTBUF
  PUSH	  BC
  PUSH	  DE
  PUSH	  HL
  LD	  (HL),0
  CALL	  OUTNCR
  LD	  HL,BUFFER
  CALL	  PRS
  POP	  HL
  POP	  DE
  POP	  BC
  JR	  MORINP
PUTBUF: CP	' '
  JR	  C,MORINP
PUTCTL: LD	A,B
  CP	  72+1
  LD	  A,CTRLG
  JR	  NC,OUTNBS
  LD	  A,C
  LD	  (HL),C
  LD	  (LSTBIN),A
  INC	  HL
  INC	  B
OUTIT: CALL    OUTC
  JR	  MORINP
OUTNBS: CALL	OUTC
  LD	  A,BKSP
  JR	  OUTIT
CPDEHL: LD	A,H
  SUB	  D
  RET	  NZ
  LD	  A,L
  SUB	  E
  RET
CHKSYN: LD	A,(HL)
  EX	  (SP),HL
  CP	  (HL)
  INC	  HL
  EX	  (SP),HL
  JP	  Z,GETCHR
  JP	  SNERR
OUTC: PUSH    AF
  LD	  A,(CTLOFG)
  OR	  A
  JP	  NZ,POPAF
  POP	  AF
  PUSH	  BC
  PUSH	  AF
  CP	  ' '
  JR	  C,DINPOS
  LD	  A,(LWIDTH)
  LD	  B,A
  LD	  A,(CURPOS)
  INC	  B
  JR	  Z,INCLEN
  DEC	  B
  CP	  B
  CALL	  Z,PRNTCRLF
INCLEN: INC	A
  LD	  (CURPOS),A
DINPOS: POP	AF
  POP	  BC
  CALL	  MONOUT
  RET
CLOTST: CALL	GETINP
  AND	  01111111B
  CP	  CTRLO
  RET	  NZ
  LD	  A,(CTLOFG)
  CPL
  LD	  (CTLOFG),A
  XOR	  A
  RET
LIST: CALL    ATOH
  RET	  NZ
  POP	  BC
  CALL	  SRCHLN
  PUSH	  BC
  CALL	  SETLIN
LISTLP: POP	HL
  LD	  C,(HL)
  INC	  HL
  LD	  B,(HL)
  INC	  HL
  LD	  A,B
  OR	  C
  JP	  Z,PRNTOK
  CALL	  COUNT
  CALL	  TSTBRK
  PUSH	  BC
  CALL	  PRNTCRLF
  LD	  E,(HL)
  INC	  HL
  LD	  D,(HL)
  INC	  HL
  PUSH	  HL
  EX	  DE,HL
  CALL	  PRNTHL
  LD	  A,' '
  POP	  HL
LSTLP2: CALL	OUTC
LSTLP3: LD	A,(HL)
  OR	  A
  INC	  HL
  JR	  Z,LISTLP
  JP	  P,LSTLP2
  SUB	  ZEND-1
  LD	  C,A
  LD	  DE,WORDS
FNDTOK: LD	A,(DE)
  INC	  DE
  OR	  A
  JP	  P,FNDTOK
  DEC	  C
  JR	  NZ,FNDTOK
OUTWRD: AND	01111111B
  CALL	  OUTC
  LD	  A,(DE)
  INC	  DE
  OR	  A
  JP	  P,OUTWRD
  JR	  LSTLP3
SETLIN: PUSH	HL
  LD	  HL,(LINESN)
  LD	  (LINESC),HL
  POP	  HL
  RET
COUNT: PUSH    HL
  PUSH	  DE
  LD	  HL,(LINESC)
  LD	  DE,-1
  ADC	  HL,DE
  LD	  (LINESC),HL
  POP	  DE
  POP	  HL
  RET	  P
  PUSH	  HL
  LD	  HL,(LINESN)
  LD	  (LINESC),HL
  CALL	  GETINP
  CP	  CTRLC
  JR	  Z,RSLNBK
  POP	  HL
  JR	  COUNT
RSLNBK: LD	HL,(LINESN)
  LD	  (LINESC),HL
  JP	  BRKRET
FOR: LD      A,64H
  LD	  (FORFLG),A
  CALL	  LET
  POP	  BC
  PUSH	  HL
  CALL	  DATA
  LD	  (LOOPST),HL
  LD	  HL,2
  ADD	  HL,SP
FORSLP: CALL	LOKFOR
  POP	  DE
  JR	  NZ,FORFND
  ADD	  HL,BC
  PUSH	  DE
  DEC	  HL
  LD	  D,(HL)
  DEC	  HL
  LD	  E,(HL)
  INC	  HL
  INC	  HL
  PUSH	  HL
  LD	  HL,(LOOPST)
  CALL	  CPDEHL
  POP	  HL
  JR	  NZ,FORSLP
  POP	  DE
  LD	  SP,HL
FORFND: EX	DE,HL
  LD	  C,8
  CALL	  CHKSTK
  PUSH	  HL
  LD	  HL,(LOOPST)
  EX	  (SP),HL
  PUSH	  HL
  LD	  HL,(LINEAT)
  EX	  (SP),HL
  CALL	  TSTNUM
  CALL	  CHKSYN
  defb	 ZTO
  CALL	  GETNUM
  PUSH	  HL
  CALL	  BCDEFP
  POP	  HL
  PUSH	  BC
  PUSH	  DE
  LD	  BC,8100H
  LD	  D,C
  LD	  E,D
  LD	  A,(HL)
  CP	  ZSTEP
  LD	  A,1
  JR	  NZ,SAVSTP
  CALL	  GETCHR
  CALL	  GETNUM
  PUSH	  HL
  CALL	  BCDEFP
  CALL	  TSTSGN
  POP	  HL
SAVSTP: PUSH	BC
  PUSH	  DE
  PUSH	  AF
  INC	  SP
  PUSH	  HL
  LD	  HL,(BRKLIN)
  EX	  (SP),HL
PUTFID: LD	B,ZFOR
  PUSH	  BC
  INC	  SP
RUNCNT: CALL	TSTBRK
  LD	  (BRKLIN),HL
  LD	  A,(HL)
  CP	  ':'
  JR	  Z,EXCUTE
  OR	  A
  JP	  NZ,SNERR
  INC	  HL
  LD	  A,(HL)
  INC	  HL
  OR	  (HL)
  JR	  Z,ENDPRG
  INC	  HL
  LD	  E,(HL)
  INC	  HL
  LD	  D,(HL)
  EX	  DE,HL
  LD	  (LINEAT),HL
  EX	  DE,HL
EXCUTE: CALL	GETCHR
  LD	  DE,RUNCNT
  PUSH	  DE
IFJMP: RET     Z
ONJMP: SUB     ZEND
  JP	  C,LET
  CP	  ZNEW+1-ZEND
  JP	  NC,SNERR
  RLCA
  LD	  C,A
  LD	  B,0
  EX	  DE,HL
  LD	  HL,WORDTB
  ADD	  HL,BC
  LD	  C,(HL)
  INC	  HL
  LD	  B,(HL)
  PUSH	  BC
  EX	  DE,HL
GETCHR: INC	HL
  LD	  A,(HL)
  CP	  ':'
  RET	  NC
  CP	  ' '
  JR	  Z,GETCHR
  CP	  '0'
  CCF
  INC	  A
  DEC	  A
  RET
RESTOR: EX	DE,HL
  LD	  HL,(BASTXT)
  JR	  Z,RESTNL
  EX	  DE,HL
  CALL	  ATOH
  PUSH	  HL
  CALL	  SRCHLN
  LD	  H,B
  LD	  L,C
  POP	  DE
  JP	  NC,ULERR
RESTNL: DEC	HL
UPDATA: LD	(NXTDAT),HL
  EX	  DE,HL
  RET
TSTBRK: RST	18H
  RET	  Z
  RST	  10H
  CP	  ESC
  JR	  Z,BRK
  CP	  CTRLC
  JR	  Z,BRK
  CP	  CTRLS
  RET	  NZ
STALL: RST     10H
  CP	  CTRLQ
  RET	   Z
  CP	  CTRLC
  JP	  Z,EXTSTP
  JR	  STALL
BRK: CALL    EXTBRK
  LD	  A,0FFh
  LD	  (BRKFLG),A
STOP: RET     NZ
  defb	 0F6H
PEND: RET     NZ
  LD	  (BRKLIN),HL
  defb	 21H
INPBRK: OR	11111111B
  POP	  BC
ENDPRG: LD	HL,(LINEAT)
  PUSH	  AF
  LD	  A,L
  AND	  H
  INC	  A
  JR	  Z,NOLIN
  LD	  (ERRLIN),HL
  LD	  HL,(BRKLIN)
  LD	  (CONTAD),HL
NOLIN: XOR     A
  LD	  (CTLOFG),A
  CALL	  STTLIN
  POP	  AF
  LD	  HL,BRKMSG
  JP	  NZ,ERRIN
  JP	  PRNTOK
CONT: LD      HL,(CONTAD)
  LD	  A,H
  OR	  L
  LD	  E,CN
  JP	  Z,ERROR
  EX	  DE,HL
  LD	  HL,(ERRLIN)
  LD	  (LINEAT),HL
  EX	  DE,HL
  RET
NULL: CALL    GETINT
  RET	  NZ
  LD	  (NULLS),A
  RET
ACCSUM: PUSH	HL
  LD	  HL,(CHKSUM)
  LD	  B,0
  LD	  C,A
  ADD	  HL,BC
  LD	  (CHKSUM),HL
  POP	  HL
  RET
CHKLTR: LD	A,(HL)
  CP	  'A'
  RET	  C
  CP	  'Z'+1
  CCF
  RET
FPSINT: CALL	GETCHR
POSINT: CALL	GETNUM
DEPINT: CALL	TSTSGN
  JP	  M,FCERR
DEINT: LD      A,(FPEXP)
  CP	  80H+16
  JP	  C,FPINT
  LD	  BC,9080H
  LD	  DE,0000
  PUSH	  HL
  CALL	  CMPNUM
  POP	  HL
  LD	  D,C
  RET	  Z
FCERR: LD      E,FC
  JP	  ERROR
ATOH: DEC     HL
GETLN: LD      DE,0
GTLNLP: CALL	GETCHR
  RET	  NC
  PUSH	  HL
  PUSH	  AF
  LD	  HL,65529/10
  CALL	  CPDEHL
  JP	  C,SNERR
  LD	  H,D
  LD	  L,E
  ADD	  HL,DE
  ADD	  HL,HL
  ADD	  HL,DE
  ADD	  HL,HL
  POP	  AF
  SUB	  '0'
  LD	  E,A
  LD	  D,0
  ADD	  HL,DE
  EX	  DE,HL
  POP	  HL
  JR	  GTLNLP
CLEAR: JP      Z,INTVAR
  CALL	  POSINT
  DEC	  HL
  CALL	  GETCHR
  PUSH	  HL
  LD	  HL,(LSTRAM)
  JR	  Z,STORED
  POP	  HL
  CALL	  CHKSYN
  defb	    ','
  PUSH	  DE
  CALL	  POSINT
  DEC	  HL
  CALL	  GETCHR
  JP	  NZ,SNERR
  EX	  (SP),HL
  EX	  DE,HL
STORED: LD	A,L
  SUB	  E
  LD	  E,A
  LD	  A,H
  SBC	  A,D
  LD	  D,A
  JP	  C,OMERR
  PUSH	  HL
  LD	  HL,(PROGND)
  LD	  BC,40
  ADD	  HL,BC
  CALL	  CPDEHL
  JP	  NC,OMERR
  EX	  DE,HL
  LD	  (STRSPC),HL
  POP	  HL
  LD	  (LSTRAM),HL
  POP	  HL
  JP	  INTVAR
RUN: JP      Z,RUNFST
  CALL	  INTVAR
  LD	  BC,RUNCNT
  JR	  RUNLIN
GOSUB: LD      C,3
  CALL	  CHKSTK
  POP	  BC
  PUSH	  HL
  PUSH	  HL
  LD	  HL,(LINEAT)
  EX	  (SP),HL
  LD	  A,ZGOSUB
  PUSH	  AF
  INC	  SP
RUNLIN: PUSH	BC
GOTO: CALL    ATOH
  CALL	  REM
  PUSH	  HL
  LD	  HL,(LINEAT)
  CALL	  CPDEHL
  POP	  HL
  INC	  HL
  CALL	  C,SRCHLP
  CALL	  NC,SRCHLN
  LD	  H,B
  LD	  L,C
  DEC	  HL
  RET	  C
ULERR: LD      E,UL
  JP	  ERROR
RETURN: RET	NZ
  LD	  D,-1
  CALL	  BAKSTK
  LD	  SP,HL
  CP	  ZGOSUB
  LD	  E,RG
  JP	  NZ,ERROR
  POP	  HL
  LD	  (LINEAT),HL
  INC	  HL
  LD	  A,H
  OR	  L
  JR	  NZ,RETLIN
  LD	  A,(LSTBIN)
  OR	  A
  JP	  NZ,POPNOK
RETLIN: LD	HL,RUNCNT
  EX	  (SP),HL
  defb	    3EH
NXTDTA: POP	HL
DATA: defb	01H,3AH
REM: LD      C,0
  LD	  B,0
NXTSTL: LD	A,C
  LD	  C,B
  LD	  B,A
NXTSTT: LD	A,(HL)
  OR	  A
  RET	  Z
  CP	  B
  RET	  Z
  INC	  HL
  CP	  '"'
  JR	  Z,NXTSTL
  JR	  NXTSTT
LET: CALL    GETVAR
  CALL	  CHKSYN
  defb	    ZEQUAL
  PUSH	  DE
  LD	  A,(TYPE)
  PUSH	  AF
  CALL	  EVAL
  POP	  AF
  EX	  (SP),HL
  LD	  (BRKLIN),HL
  RRA
  CALL	  CHKTYP
  JR	  Z,LETNUM
LETSTR: PUSH	HL
  LD	  HL,(FPREG)
  PUSH	  HL
  INC	  HL
  INC	  HL
  LD	  E,(HL)
  INC	  HL
  LD	  D,(HL)
  LD	  HL,(BASTXT)
  CALL	  CPDEHL
  JR	  NC,CRESTR
  LD	  HL,(STRSPC)
  CALL	  CPDEHL
  POP	  DE
  JR	  NC,MVSTPT
  LD	  HL,TMPSTR
  CALL	  CPDEHL
  JR	  NC,MVSTPT
  defb	 3EH
CRESTR: POP	DE
  CALL	  BAKTMP
  EX	  DE,HL
  CALL	  SAVSTR
MVSTPT: CALL	BAKTMP
  POP	  HL
  CALL	  DETHL4
  POP	  HL
  RET
LETNUM: PUSH	HL
  CALL	  FPTHL
  POP	  DE
  POP	  HL
  RET
ON: CALL    GETINT
  LD	  A,(HL)
  LD	  B,A
  CP	  ZGOSUB
  JR	  Z,ONGO
  CALL	  CHKSYN
  defb	 ZGOTO
  DEC	  HL
ONGO: LD      C,E
ONGOLP: DEC	C
  LD	  A,B
  JP	  Z,ONJMP
  CALL	  GETLN
  CP	  ','
  RET	  NZ
  JR	  ONGOLP
IF: CALL    EVAL
  LD	  A,(HL)
  CP	  ZGOTO
  JR	  Z,IFGO
  CALL	  CHKSYN
  defb	    ZTHEN
  DEC	  HL
IFGO: CALL    TSTNUM
  CALL	  TSTSGN
  JP	  Z,REM
  CALL	  GETCHR
  JP	  C,GOTO
  JP	  IFJMP
MRPRNT: DEC	HL
  CALL	  GETCHR
PRINT: JR      Z,PRNTCRLF
PRNTLP: RET	Z
  CP	  ZTAB
  JR	  Z,DOTAB
  CP	  ZSPC
  JR	  Z,DOTAB
  PUSH	  HL
  CP	  ','
  JR	  Z,DOCOM
  CP	  59
  JP	  Z,NEXITM
  POP	  BC
  CALL	  EVAL
  PUSH	  HL
  LD	  A,(TYPE)
  OR	  A
  JR	  NZ,PRNTST
  CALL	  NUMASC
  CALL	  CRTST
  LD	  (HL),' '
  LD	  HL,(FPREG)
  INC	  (HL)
  LD	  HL,(FPREG)
  LD	  A,(LWIDTH)
  LD	  B,A
  INC	  B
  JR	  Z,PRNTNB
  INC	  B
  LD	  A,(CURPOS)
  ADD	  A,(HL)
  DEC	  A
  CP	  B
  CALL	  NC,PRNTCRLF
PRNTNB: CALL	PRS1
  XOR	  A
PRNTST: CALL	NZ,PRS1
  POP	  HL
  JR	  MRPRNT
STTLIN: LD	A,(CURPOS)
  OR	  A
  RET	  Z
  JR	  PRNTCRLF
ENDINP: LD	(HL),0
  LD	  HL,BUFFER-1
PRNTCRLF: LD	A,CR
  CALL	  OUTC
  LD	  A,LF
  CALL	  OUTC
DONULL: XOR	A
  LD	  (CURPOS),A
  LD	  A,(NULLS)
NULLP: DEC     A
  RET	  Z
  PUSH	  AF
  XOR	  A
  CALL	  OUTC
  POP	  AF
  JR	  NULLP
DOCOM: LD      A,(COMMAN)
  LD	  B,A
  LD	  A,(CURPOS)
  CP	  B
  CALL	  NC,PRNTCRLF
  JR	  NC,NEXITM
ZONELP: SUB	14
  JR	  NC,ZONELP
  CPL
  JR	  ASPCS
DOTAB: PUSH    AF
  CALL	  FNDNUM
  CALL	  CHKSYN
  defb	 ")"
  DEC	  HL
  POP	  AF
  SUB	  ZSPC
  PUSH	  HL
  JR	  Z,DOSPC
  LD	  A,(CURPOS)
DOSPC: CPL
  ADD	  A,E
  JR	  NC,NEXITM
ASPCS: INC     A
  LD	  B,A
  LD	  A,' '
SPCLP: CALL    OUTC
  DEC	  B
  JR	  NZ,SPCLP
NEXITM: POP	HL
  CALL	  GETCHR
  JP	  PRNTLP
REDO: defb   "?Redo from start",CR,LF,0
BADINP: LD	A,(READFG)
  OR	  A
  JP	  NZ,DATSNR
  POP	  BC
  LD	  HL,REDO
  CALL	  PRS
  JP	  DOAGN
INPUT: CALL    IDTEST
  LD	  A,(HL)
  CP	  '"'
  LD	  A,0
  LD	  (CTLOFG),A
  JR	  NZ,NOPMPT
  CALL	  QTSTR
  CALL	  CHKSYN
  defb	 ';'
  PUSH	  HL
  CALL	  PRS1
  defb	 3EH
NOPMPT: PUSH	HL
  CALL	  PROMPT
  POP	  BC
  JP	  C,INPBRK
  INC	  HL
  LD	  A,(HL)
  OR	  A
  DEC	  HL
  PUSH	  BC
  JP	  Z,NXTDTA
  LD	  (HL),','
  JR	  NXTITM
READ: PUSH    HL
  LD	  HL,(NXTDAT)
  defb	 0F6H
NXTITM: XOR	A
  LD	  (READFG),A
  EX	  (SP),HL
  JR	  GTVLUS
NEDMOR: CALL	CHKSYN
  defb	    ','
GTVLUS: CALL	GETVAR
  EX	  (SP),HL
  PUSH	  DE
  LD	  A,(HL)
  CP	  ','
  JR	  Z,ANTVLU
  LD	  A,(READFG)
  OR	  A
  JR	  NZ,FDTLP
  LD	  A,'?'
  CALL	  OUTC
  CALL	  PROMPT
  POP	  DE
  POP	  BC
  JP	  C,INPBRK
  INC	  HL
  LD	  A,(HL)
  OR	  A
  DEC	  HL
  PUSH	  BC
  JP	  Z,NXTDTA
  PUSH	  DE
ANTVLU: LD	A,(TYPE)
  OR	  A
  JR	  Z,INPBIN
  CALL	  GETCHR
  LD	  D,A
  LD	  B,A
  CP	  '"'
  JR	  Z,STRENT
  LD	  A,(READFG)
  OR	  A
  LD	  D,A
  JR	  Z,ITMSEP
  LD	  D,':'
ITMSEP: LD	B,','
  DEC	  HL
STRENT: CALL	DTSTR
  EX	  DE,HL
  LD	  HL,LTSTND
  EX	  (SP),HL
  PUSH	  DE
  JP	  LETSTR
INPBIN: CALL	GETCHR
  CALL	  ASCTFP
  EX	  (SP),HL
  CALL	  FPTHL
  POP	  HL
LTSTND: DEC	HL
  CALL	  GETCHR
  JR	  Z,MORDT
  CP	  ','
  JP	  NZ,BADINP
MORDT: EX      (SP),HL
  DEC	  HL
  CALL	  GETCHR
  JR	  NZ,NEDMOR
  POP	  DE
  LD	  A,(READFG)
  OR	  A
  EX	  DE,HL
  JP	  NZ,UPDATA
  PUSH	  DE
  OR	  (HL)
  LD	  HL,EXTIG
  CALL	  NZ,PRS
  POP	  HL
  RET
EXTIG: defb   "?Extra ignored",CR,LF,0
FDTLP: CALL    DATA
  OR	  A
  JR	  NZ,FANDT
  INC	  HL
  LD	  A,(HL)
  INC	  HL
  OR	  (HL)
  LD	  E,OD
  JP	  Z,ERROR
  INC	  HL
  LD	  E,(HL)
  INC	  HL
  LD	  D,(HL)
  EX	  DE,HL
  LD	  (DATLIN),HL
  EX	  DE,HL
FANDT: CALL    GETCHR
  CP	  ZDATA
  JR	  NZ,FDTLP
  JP	  ANTVLU
NEXT: LD      DE,0
NEXT1: CALL    NZ,GETVAR
  LD	  (BRKLIN),HL
  CALL	  BAKSTK
  JP	  NZ,NFERR
  LD	  SP,HL
  PUSH	  DE
  LD	  A,(HL)
  INC	  HL
  PUSH	  AF
  PUSH	  DE
  CALL	  PHLTFP
  EX	  (SP),HL
  PUSH	  HL
  CALL	  ADDPHL
  POP	  HL
  CALL	  FPTHL
  POP	  HL
  CALL	  LOADFP
  PUSH	  HL
  CALL	  CMPNUM
  POP	  HL
  POP	  BC
  SUB	  B
  CALL	  LOADFP
  JR	  Z,KILFOR
  EX	  DE,HL
  LD	  (LINEAT),HL
  LD	  L,C
  LD	  H,B
  JP	  PUTFID
KILFOR: LD	SP,HL
  LD	  HL,(BRKLIN)
  LD	  A,(HL)
  CP	  ','
  JP	  NZ,RUNCNT
  CALL	  GETCHR
  CALL	  NEXT1
GETNUM: CALL	EVAL
TSTNUM: defb	  0F6H
TSTSTR: SCF
CHKTYP: LD	A,(TYPE)
  ADC	  A,A
  OR	  A
  RET	  PE
  JP	  TMERR
OPNPAR: CALL	CHKSYN
  defb	 "("
EVAL: DEC     HL
  LD	  D,0
EVAL1: PUSH    DE
  LD	  C,1
  CALL	  CHKSTK
  CALL	  OPRND
EVAL2: LD      (NXTOPR),HL
EVAL3: LD      HL,(NXTOPR)
  POP	  BC
  LD	  A,B
  CP	  78H
  CALL	  NC,TSTNUM
  LD	  A,(HL)
  LD	  D,0
RLTLP: SUB     ZGTR
  JR	  C,FOPRND
  CP	  ZLTH+1-ZGTR
  JR	  NC,FOPRND
  CP	  ZEQUAL-ZGTR
  RLA
  XOR	  D
  CP	  D
  LD	  D,A
  JP	  C,SNERR
  LD	  (CUROPR),HL
  CALL	  GETCHR
  JP	  RLTLP
FOPRND: LD	A,D
  OR	  A
  JP	  NZ,TSTRED
  LD	  A,(HL)
  LD	  (CUROPR),HL
  SUB	  ZPLUS
  RET	  C
  CP	  ZOR+1-ZPLUS
  RET	  NC
  LD	  E,A
  LD	  A,(TYPE)
  DEC	  A
  OR	  E
  LD	  A,E
  JP	  Z,CONCAT
  RLCA
  ADD	  A,E
  LD	  E,A
  LD	  HL,PRITAB
  ADD	  HL,DE
  LD	  A,B
  LD	  D,(HL)
  CP	  D
  RET	  NC
  INC	  HL
  CALL	  TSTNUM
STKTHS: PUSH	BC
  LD	  BC,EVAL3
  PUSH	  BC
  LD	  B,E
  LD	  C,D
  CALL	  STAKFP
  LD	  E,B
  LD	  D,C
  LD	  C,(HL)
  INC	  HL
  LD	  B,(HL)
  INC	  HL
  PUSH	  BC
  LD	  HL,(CUROPR)
  JP	  EVAL1
OPRND: XOR     A
  LD	  (TYPE),A
  CALL	  GETCHR
  LD	  E,MO
  JP	  Z,ERROR
  JP	  C,ASCTFP
  CALL	  CHKLTR
  JR	  NC,CONVAR
  CP		'&'
  JR		NZ, NOTAMP
  CALL	  GETCHR
  CP	  'H'
  JP	  Z,HEXTFP
  CP	  'B'
  JP	  Z,BINTFP
  LD	  E,SN
  JP	  Z,ERROR
NOTAMP: CP	ZPLUS
  JR	  Z,OPRND
  CP	  '.'
  JP	  Z,ASCTFP
  CP	  ZMINUS
  JR	  Z,MINUS
  CP	  '"'
  JP	  Z,QTSTR
  CP	  ZNOT
  JP	  Z,EVNOT
  CP	  ZFN
  JP	  Z,DOFN
  SUB	  ZSGN
  JR	  NC,FNOFST
EVLPAR: CALL	OPNPAR
  CALL	  CHKSYN
  defb	 ")"
  RET
MINUS: LD      D,7DH
  CALL	  EVAL1
  LD	  HL,(NXTOPR)
  PUSH	  HL
  CALL	  INVSGN
RETNUM: CALL	TSTNUM
  POP	  HL
  RET
CONVAR: CALL	GETVAR
FRMEVL: PUSH	HL
  EX	  DE,HL
  LD	  (FPREG),HL
  LD	  A,(TYPE)
  OR	  A
  CALL	  Z,PHLTFP
  POP	  HL
  RET
FNOFST: LD	B,0
  RLCA
  LD	  C,A
  PUSH	  BC
  CALL	  GETCHR
  LD	  A,C
  CP	  2*(ZLEFT-ZSGN)-1
  JR	  C,FNVAL
  CALL	  OPNPAR
  CALL	  CHKSYN
  defb	    ','
  CALL	  TSTSTR
  EX	  DE,HL
  LD	  HL,(FPREG)
  EX	  (SP),HL
  PUSH	  HL
  EX	  DE,HL
  CALL	  GETINT
  EX	  DE,HL
  EX	  (SP),HL
  JR	  GOFUNC
FNVAL: CALL    EVLPAR
  EX	  (SP),HL
  LD	  DE,RETNUM
  PUSH	  DE
GOFUNC: LD	BC,FNCTAB
  ADD	  HL,BC
  LD	  C,(HL)
  INC	  HL
  LD	  H,(HL)
  LD	  L,C
  JP	  (HL)
SGNEXP: DEC	D
  CP	  ZMINUS
  RET	  Z
  CP	  '-'
  RET	  Z
  INC	  D
  CP	  '+'
  RET	  Z
  CP	  ZPLUS
  RET	  Z
  DEC	  HL
  RET
POR: defb      0F6H
PAND: XOR     A
  PUSH	  AF
  CALL	  TSTNUM
  CALL	  DEINT
  POP	  AF
  EX	  DE,HL
  POP	  BC
  EX	  (SP),HL
  EX	  DE,HL
  CALL	  FPBCDE
  PUSH	  AF
  CALL	  DEINT
  POP	  AF
  POP	  BC
  LD	  A,C
  LD	  HL,ACPASS
  JR	  NZ,POR1
  AND	  E
  LD	  C,A
  LD	  A,B
  AND	  D
  JP	  (HL)
POR1: OR      E
  LD	  C,A
  LD	  A,B
  OR	  D
  JP	  (HL)
TSTRED: LD	HL,CMPLOG
  LD	  A,(TYPE)
  RRA
  LD	  A,D
  RLA
  LD	  E,A
  LD	  D,64H
  LD	  A,B
  CP	  D
  RET	  NC
  JP	  STKTHS
CMPLOG: defw   CMPLG1
CMPLG1: LD	A,C
  OR	  A
  RRA
  POP	  BC
  POP	  DE
  PUSH	  AF
  CALL	  CHKTYP
  LD	  HL,CMPRES
  PUSH	  HL
  JP	  Z,CMPNUM
  XOR	  A
  LD	  (TYPE),A
  PUSH	  DE
  CALL	  GSTRCU
  LD	  A,(HL)
  INC	  HL
  INC	  HL
  LD	  C,(HL)
  INC	  HL
  LD	  B,(HL)
  POP	  DE
  PUSH	  BC
  PUSH	  AF
  CALL	  GSTRDE
  CALL	  LOADFP
  POP	  AF
  LD	  D,A
  POP	  HL
CMPSTR: LD	A,E
  OR	  D
  RET	  Z
  LD	  A,D
  SUB	  1
  RET	  C
  XOR	  A
  CP	  E
  INC	  A
  RET	  NC
  DEC	  D
  DEC	  E
  LD	  A,(BC)
  CP	  (HL)
  INC	  HL
  INC	  BC
  JR	  Z,CMPSTR
  CCF
  JP	  FLGDIF
CMPRES: INC	A
  ADC	  A,A
  POP	  BC
  AND	  B
  ADD	  A,-1
  SBC	  A,A
  JP	  FLGREL
EVNOT: LD      D,5AH
  CALL	  EVAL1
  CALL	  TSTNUM
  CALL	  DEINT
  LD	  A,E
  CPL
  LD	  C,A
  LD	  A,D
  CPL
  CALL	  ACPASS
  POP	  BC
  JP	  EVAL3
DIMRET: DEC	HL
  CALL	  GETCHR
  RET	  Z
  CALL	  CHKSYN
  defb	    ','
DIM: LD      BC,DIMRET
  PUSH	  BC
  defb	    0F6H
GETVAR: XOR	A
  LD	  (LCRFLG),A
  LD	  B,(HL)
GTFNAM: CALL	CHKLTR
  JP	  C,SNERR
  XOR	  A
  LD	  C,A
  LD	  (TYPE),A
  CALL	  GETCHR
  JR	  C,SVNAM2
  CALL	  CHKLTR
  JR	  C,CHARTY
SVNAM2: LD	C,A
ENDNAM: CALL	GETCHR
  JR	  C,ENDNAM
  CALL	  CHKLTR
  JR	  NC,ENDNAM
CHARTY: SUB	'$'
  JR	  NZ,NOTSTR
  INC	  A
  LD	  (TYPE),A
  RRCA
  ADD	  A,C
  LD	  C,A
  CALL	  GETCHR
NOTSTR: LD	A,(FORFLG)
  DEC	  A
  JP	  Z,ARLDSV
  JP	  P,NSCFOR
  LD	  A,(HL)
  SUB	  '('
  JR	  Z,SBSCPT
NSCFOR: XOR	A
  LD	  (FORFLG),A
  PUSH	  HL
  LD	  D,B
  LD	  E,C
  LD	  HL,(FNRGNM)
  CALL	  CPDEHL
  LD	  DE,FNARG
  JP	  Z,POPHRT
  LD	  HL,(VAREND)
  EX	  DE,HL
  LD	  HL,(PROGND)
FNDVAR: LD	A,L
  SUB	  E
  JR	  NZ,FNDV1
  LD	  A,H
  SUB	  D
  JR	  Z,CFEVAL
FNDV1: LD      A,C
  SUB	  (HL)
  INC	  HL
  JR	  NZ,FNDV2
  LD	  A,B
  SUB	  (HL)
FNTHR: INC     HL
  JR	  Z,RETADR
  INC	  HL
  INC	  HL
  INC	  HL
  INC	  HL
  JP	  FNDVAR
FNDV2: INC     HL
  INC	  HL
  INC	  HL
  INC	  HL
  INC	  HL
  JP	  FNDVAR
CFEVAL: POP	HL
  EX	  (SP),HL
  PUSH	  DE
  LD	  DE,FRMEVL
  CALL	  CPDEHL
  POP	  DE
  JR	  Z,RETNUL
  EX	  (SP),HL
  PUSH	  HL
  PUSH	  BC
  LD	  BC,6
  LD	  HL,(ARREND)
  PUSH	  HL
  ADD	  HL,BC
  POP	  BC
  PUSH	  HL
  CALL	  MOVUP
  POP	  HL
  LD	  (ARREND),HL
  LD	  H,B
  LD	  L,C
  LD	  (VAREND),HL
ZEROLP: DEC	HL
  LD	  (HL),0
  CALL	  CPDEHL
  JR	  NZ,ZEROLP
  POP	  DE
  LD	  (HL),E
  INC	  HL
  LD	  (HL),D
  INC	  HL
RETADR: EX	DE,HL
  POP	  HL
  RET
RETNUL: LD	(FPEXP),A
  LD	  HL,ZERBYT
  LD	  (FPREG),HL
  POP	  HL
  RET
SBSCPT: PUSH	HL
  LD	  HL,(LCRFLG)
  EX	  (SP),HL
  LD	  D,A
SCPTLP: PUSH	DE
  PUSH	  BC
  CALL	  FPSINT
  POP	  BC
  POP	  AF
  EX	  DE,HL
  EX	  (SP),HL
  PUSH	  HL
  EX	  DE,HL
  INC	  A
  LD	  D,A
  LD	  A,(HL)
  CP	  ','
  JR	  Z,SCPTLP
  CALL	  CHKSYN
  defb	    ")"
  LD	  (NXTOPR),HL
  POP	  HL
  LD	  (LCRFLG),HL
  LD	  E,0
  PUSH	  DE
  defb	    11H
ARLDSV: PUSH	HL
  PUSH	  AF
  LD	  HL,(VAREND)
  defb	    3EH
FNDARY: ADD	HL,DE
  EX	  DE,HL
  LD	  HL,(ARREND)
  EX	  DE,HL
  CALL	  CPDEHL
  JR	  Z,CREARY
  LD	  A,(HL)
  CP	  C
  INC	  HL
  JR	  NZ,NXTARY
  LD	  A,(HL)
  CP	  B
NXTARY: INC	HL
  LD	  E,(HL)
  INC	  HL
  LD	  D,(HL)
  INC	  HL
  JR	  NZ,FNDARY
  LD	  A,(LCRFLG)
  OR	  A
  JP	  NZ,DDERR
  POP	  AF
  LD	  B,H
  LD	  C,L
  JP	  Z,POPHRT
  SUB	  (HL)
  JR	  Z,FINDEL
BSERR: LD      E,BS
  JP	  ERROR
CREARY: LD	DE,4
  POP	  AF
  JP	  Z,FCERR
  LD	  (HL),C
  INC	  HL
  LD	  (HL),B
  INC	  HL
  LD	  C,A
  CALL	  CHKSTK
  INC	  HL
  INC	  HL
  LD	  (CUROPR),HL
  LD	  (HL),C
  INC	  HL
  LD	  A,(LCRFLG)
  RLA
  LD	  A,C
CRARLP: LD	BC,10+1
  JR	  NC,DEFSIZ
  POP	  BC
  INC	  BC
DEFSIZ: LD	(HL),C
  INC	  HL
  LD	  (HL),B
  INC	  HL
  PUSH	  AF
  PUSH	  HL
  CALL	  MLDEBC
  EX	  DE,HL
  POP	  HL
  POP	  AF
  DEC	  A
  JR	  NZ,CRARLP
  PUSH	  AF
  LD	  B,D
  LD	  C,E
  EX	  DE,HL
  ADD	  HL,DE
  JP	  C,OMERR
  CALL	  ENFMEM
  LD	  (ARREND),HL
ZERARY: DEC	HL
  LD	  (HL),0
  CALL	  CPDEHL
  JR	  NZ,ZERARY
  INC	  BC
  LD	  D,A
  LD	  HL,(CUROPR)
  LD	  E,(HL)
  EX	  DE,HL
  ADD	  HL,HL
  ADD	  HL,BC
  EX	  DE,HL
  DEC	  HL
  DEC	  HL
  LD	  (HL),E
  INC	  HL
  LD	  (HL),D
  INC	  HL
  POP	  AF
  JR	  C,ENDDIM
FINDEL: LD	B,A
  LD	  C,A
  LD	  A,(HL)
  INC	  HL
  defb	    16H
FNDELP: POP	HL
  LD	  E,(HL)
  INC	  HL
  LD	  D,(HL)
  INC	  HL
  EX	  (SP),HL
  PUSH	  AF
  CALL	  CPDEHL
  JR	  NC,BSERR
  PUSH	  HL
  CALL	  MLDEBC
  POP	  DE
  ADD	  HL,DE
  POP	  AF
  DEC	  A
  LD	  B,H
  LD	  C,L
  JR	  NZ,FNDELP
  ADD	  HL,HL
  ADD	  HL,HL
  POP	  BC
  ADD	  HL,BC
  EX	  DE,HL
ENDDIM: LD	HL,(NXTOPR)
  RET
FRE: LD      HL,(ARREND)
  EX	  DE,HL
  LD	  HL,0
  ADD	  HL,SP
  LD	  A,(TYPE)
  OR	  A
  JR	  Z,FRENUM
  CALL	  GSTRCU
  CALL	  GARBGE
  LD	  HL,(STRSPC)
  EX	  DE,HL
  LD	  HL,(STRBOT)
FRENUM: LD	A,L
  SUB	  E
  LD	  C,A
  LD	  A,H
  SBC	  A,D
ACPASS: LD	B,C
ABPASS: LD	D,B
  LD	  E,0
  LD	  HL,TYPE
  LD	  (HL),E
  LD	  B,80H+16
  JP	  RETINT
POS: LD      A,(CURPOS)
PASSA: LD      B,A
  XOR	  A
  JR	  ABPASS
DEF: CALL    CHEKFN
  CALL	  IDTEST
  LD	  BC,DATA
  PUSH	  BC
  PUSH	  DE
  CALL	  CHKSYN
  defb	    "("
  CALL	  GETVAR
  PUSH	  HL
  EX	  DE,HL
  DEC	  HL
  LD	  D,(HL)
  DEC	  HL
  LD	  E,(HL)
  POP	  HL
  CALL	  TSTNUM
  CALL	  CHKSYN
  defb	    ")"
  CALL	  CHKSYN
  defb	    ZEQUAL
  LD	  B,H
  LD	  C,L
  EX	  (SP),HL
  LD	  (HL),C
  INC	  HL
  LD	  (HL),B
  JP	  SVSTAD
DOFN: CALL    CHEKFN
  PUSH	  DE
  CALL	  EVLPAR
  CALL	  TSTNUM
  EX	  (SP),HL
  LD	  E,(HL)
  INC	  HL
  LD	  D,(HL)
  INC	  HL
  LD	  A,D
  OR	  E
  JP	  Z,UFERR
  LD	  A,(HL)
  INC	  HL
  LD	  H,(HL)
  LD	  L,A
  PUSH	  HL
  LD	  HL,(FNRGNM)
  EX	  (SP),HL
  LD	  (FNRGNM),HL
  LD	  HL,(FNARG+2)
  PUSH	  HL
  LD	  HL,(FNARG)
  PUSH	  HL
  LD	  HL,FNARG
  PUSH	  DE
  CALL	  FPTHL
  POP	  HL
  CALL	  GETNUM
  DEC	  HL
  CALL	  GETCHR
  JP	  NZ,SNERR
  POP	  HL
  LD	  (FNARG),HL
  POP	  HL
  LD	  (FNARG+2),HL
  POP	  HL
  LD	  (FNRGNM),HL
  POP	  HL
  RET
IDTEST: PUSH	HL
  LD	  HL,(LINEAT)
  INC	  HL
  LD	  A,H
  OR	  L
  POP	  HL
  RET	  NZ
  LD	  E,ID
  JP	  ERROR
CHEKFN: CALL	CHKSYN
  defb	    ZFN
  LD	  A,80H
  LD	  (FORFLG),A
  OR	  (HL)
  LD	  B,A
  CALL	  GTFNAM
  JP	  TSTNUM
STR: CALL    TSTNUM
  CALL	  NUMASC
STR1: CALL    CRTST
  CALL	  GSTRCU
  LD	  BC,TOPOOL
  PUSH	  BC
SAVSTR: LD	A,(HL)
  INC	  HL
  INC	  HL
  PUSH	  HL
  CALL	  TESTR
  POP	  HL
  LD	  C,(HL)
  INC	  HL
  LD	  B,(HL)
  CALL	  CRTMST
  PUSH	  HL
  LD	  L,A
  CALL	  TOSTRA
  POP	  DE
  RET
MKTMST: CALL	TESTR
CRTMST: LD	HL,TMPSTR
  PUSH	  HL
  LD	  (HL),A
  INC	  HL
SVSTAD: INC	HL
  LD	  (HL),E
  INC	  HL
  LD	  (HL),D
  POP	  HL
  RET
CRTST: DEC     HL
QTSTR: LD      B,'"'
  LD	  D,B
DTSTR: PUSH    HL
  LD	  C,-1
QTSTLP: INC	HL
  LD	  A,(HL)
  INC	  C
  OR	  A
  JR	  Z,CRTSTE
  CP	  D
  JR	  Z,CRTSTE
  CP	  B
  JR	  NZ,QTSTLP
CRTSTE: CP	'"'
  CALL	  Z,GETCHR
  EX	  (SP),HL
  INC	  HL
  EX	  DE,HL
  LD	  A,C
  CALL	  CRTMST
TSTOPL: LD	DE,TMPSTR
  LD	  HL,(TMSTPT)
  LD	  (FPREG),HL
  LD	  A,1
  LD	  (TYPE),A
  CALL	  DETHL4
  CALL	  CPDEHL
  LD	  (TMSTPT),HL
  POP	  HL
  LD	  A,(HL)
  RET	  NZ
  LD	  E,ST
  JP	  ERROR
PRNUMS: INC	HL
PRS: CALL    CRTST
PRS1: CALL    GSTRCU
  CALL	  LOADFP
  INC	  E
PRSLP: DEC     E
  RET	  Z
  LD	  A,(BC)
  CALL	  OUTC
  CP	  CR
  CALL	  Z,DONULL
  INC	  BC
  JR	  PRSLP
TESTR: OR      A
  defb	    0EH
GRBDON: POP	AF
  PUSH	  AF
  LD	  HL,(STRSPC)
  EX	  DE,HL
  LD	  HL,(STRBOT)
  CPL
  LD	  C,A
  LD	  B,-1
  ADD	  HL,BC
  INC	  HL
  CALL	  CPDEHL
  JR	  C,TESTOS
  LD	  (STRBOT),HL
  INC	  HL
  EX	  DE,HL
POPAF: POP     AF
  RET
TESTOS: POP	AF
  LD	  E,OS
  JP	  Z,ERROR
  CP	  A
  PUSH	  AF
  LD	  BC,GRBDON
  PUSH	  BC
GARBGE: LD	HL,(LSTRAM)
GARBLP: LD	(STRBOT),HL
  LD	  HL,0
  PUSH	  HL
  LD	  HL,(STRSPC)
  PUSH	  HL
  LD	  HL,TMSTPL
GRBLP: EX      DE,HL
  LD	  HL,(TMSTPT)
  EX	  DE,HL
  CALL	  CPDEHL
  LD	  BC,GRBLP
  JR	  NZ,STPOOL
  LD	  HL,(PROGND)
SMPVAR: EX	DE,HL
  LD	  HL,(VAREND)
  EX	  DE,HL
  CALL	  CPDEHL
  JR	  Z,ARRLP
  LD	  A,(HL)
  INC	  HL
  INC	  HL
  OR	  A
  CALL	  STRADD
  JR	  SMPVAR
GNXARY: POP	BC
ARRLP: EX      DE,HL
  LD	  HL,(ARREND)
  EX	  DE,HL
  CALL	  CPDEHL
  JR	  Z,SCNEND
  CALL	  LOADFP
  LD	  A,E
  PUSH	  HL
  ADD	  HL,BC
  OR	  A
  JP	  P,GNXARY
  LD	  (CUROPR),HL
  POP	  HL
  LD	  C,(HL)
  LD	  B,0
  ADD	  HL,BC
  ADD	  HL,BC
  INC	  HL
GRBARY: EX	DE,HL
  LD	  HL,(CUROPR)
  EX	  DE,HL
  CALL	  CPDEHL
  JR	  Z,ARRLP
  LD	  BC,GRBARY
STPOOL: PUSH	BC
  OR	  80H
STRADD: LD	A,(HL)
  INC	  HL
  INC	  HL
  LD	  E,(HL)
  INC	  HL
  LD	  D,(HL)
  INC	  HL
  RET	  P
  OR	  A
  RET	  Z
  LD	  B,H
  LD	  C,L
  LD	  HL,(STRBOT)
  CALL	  CPDEHL
  LD	  H,B
  LD	  L,C
  RET	  C
  POP	  HL
  EX	  (SP),HL
  CALL	  CPDEHL
  EX	  (SP),HL
  PUSH	  HL
  LD	  H,B
  LD	  L,C
  RET	  NC
  POP	  BC
  POP	  AF
  POP	  AF
  PUSH	  HL
  PUSH	  DE
  PUSH	  BC
  RET
SCNEND: POP	DE
  POP	  HL
  LD	  A,L
  OR	  H
  RET	  Z
  DEC	  HL
  LD	  B,(HL)
  DEC	  HL
  LD	  C,(HL)
  PUSH	  HL
  DEC	  HL
  DEC	  HL
  LD	  L,(HL)
  LD	  H,0
  ADD	  HL,BC
  LD	  D,B
  LD	  E,C
  DEC	  HL
  LD	  B,H
  LD	  C,L
  LD	  HL,(STRBOT)
  CALL	  MOVSTR
  POP	  HL
  LD	  (HL),C
  INC	  HL
  LD	  (HL),B
  LD	  L,C
  LD	  H,B
  DEC	  HL
  JP	  GARBLP
CONCAT: PUSH	BC
  PUSH	  HL
  LD	  HL,(FPREG)
  EX	  (SP),HL
  CALL	  OPRND
  EX	  (SP),HL
  CALL	  TSTSTR
  LD	  A,(HL)
  PUSH	  HL
  LD	  HL,(FPREG)
  PUSH	  HL
  ADD	  A,(HL)
  LD	  E,LS
  JP	  C,ERROR
  CALL	  MKTMST
  POP	  DE
  CALL	  GSTRDE
  EX	  (SP),HL
  CALL	  GSTRHL
  PUSH	  HL
  LD	  HL,(TMPSTR+2)
  EX	  DE,HL
  CALL	  SSTSA
  CALL	  SSTSA
  LD	  HL,EVAL2
  EX	  (SP),HL
  PUSH	  HL
  JP	  TSTOPL
SSTSA: POP     HL
  EX	  (SP),HL
  LD	  A,(HL)
  INC	  HL
  INC	  HL
  LD	  C,(HL)
  INC	  HL
  LD	  B,(HL)
  LD	  L,A
TOSTRA: INC	L
TSALP: DEC     L
  RET	  Z
  LD	  A,(BC)
  LD	  (DE),A
  INC	  BC
  INC	  DE
  JR	  TSALP
GETSTR: CALL	TSTSTR
GSTRCU: LD	HL,(FPREG)
GSTRHL: EX	DE,HL
GSTRDE: CALL	BAKTMP
  EX	  DE,HL
  RET	  NZ
  PUSH	  DE
  LD	  D,B
  LD	  E,C
  DEC	  DE
  LD	  C,(HL)
  LD	  HL,(STRBOT)
  CALL	  CPDEHL
  JR	  NZ,POPHL
  LD	  B,A
  ADD	  HL,BC
  LD	  (STRBOT),HL
POPHL: POP     HL
  RET
BAKTMP: LD	HL,(TMSTPT)
  DEC	  HL
  LD	  B,(HL)
  DEC	  HL
  LD	  C,(HL)
  DEC	  HL
  DEC	  HL
  CALL	  CPDEHL
  RET	  NZ
  LD	  (TMSTPT),HL
  RET
LEN: LD      BC,PASSA
  PUSH	  BC
GETLEN: CALL	GETSTR
  XOR	  A
  LD	  D,A
  LD	  (TYPE),A
  LD	  A,(HL)
  OR	  A
  RET
ASC: LD      BC,PASSA
  PUSH	  BC
GTFLNM: CALL	GETLEN
  JP	  Z,FCERR
  INC	  HL
  INC	  HL
  LD	  E,(HL)
  INC	  HL
  LD	  D,(HL)
  LD	  A,(DE)
  RET
CHR: LD      A,1
  CALL	  MKTMST
  CALL	  MAKINT
  LD	  HL,(TMPSTR+2)
  LD	  (HL),E
TOPOOL: POP	BC
  JP	  TSTOPL
LEFT: CALL    LFRGNM
  XOR	  A
RIGHT1: EX	(SP),HL
  LD	  C,A
MID1: PUSH    HL
  LD	  A,(HL)
  CP	  B
  JR	  C,ALLFOL
  LD	  A,B
  defb	    11H
ALLFOL: LD	C,0
  PUSH	  BC
  CALL	  TESTR
  POP	  BC
  POP	  HL
  PUSH	  HL
  INC	  HL
  INC	  HL
  LD	  B,(HL)
  INC	  HL
  LD	  H,(HL)
  LD	  L,B
  LD	  B,0
  ADD	  HL,BC
  LD	  B,H
  LD	  C,L
  CALL	  CRTMST
  LD	  L,A
  CALL	  TOSTRA
  POP	  DE
  CALL	  GSTRDE
  JP	  TSTOPL
RIGHT: CALL    LFRGNM
  POP	  DE
  PUSH	  DE
  LD	  A,(DE)
  SUB	  B
  JR	  RIGHT1
MID: EX      DE,HL
  LD	  A,(HL)
  CALL	  MIDNUM
  INC	  B
  DEC	  B
  JP	  Z,FCERR
  PUSH	  BC
  LD	  E,255
  CP	  ')'
  JR	  Z,RSTSTR
  CALL	  CHKSYN
  defb	    ','
  CALL	  GETINT
RSTSTR: CALL	CHKSYN
  defb	    ")"
  POP	  AF
  EX	  (SP),HL
  LD	  BC,MID1
  PUSH	  BC
  DEC	  A
  CP	  (HL)
  LD	  B,0
  RET	  NC
  LD	  C,A
  LD	  A,(HL)
  SUB	  C
  CP	  E
  LD	  B,A
  RET	  C
  LD	  B,E
  RET
VAL: CALL    GETLEN
  JP	  Z,RESZER
  LD	  E,A
  INC	  HL
  INC	  HL
  LD	  A,(HL)
  INC	  HL
  LD	  H,(HL)
  LD	  L,A
  PUSH	  HL
  ADD	  HL,DE
  LD	  B,(HL)
  LD	  (HL),D
  EX	  (SP),HL
  PUSH	  BC
  LD	  A,(HL)
  CP	'$'
  JR	NZ,VAL1
  CALL	HEXTFP
  JR	VAL3
VAL1: CP	'%'
  JR	NZ,VAL2
  CALL	BINTFP
  JR	VAL3
VAL2: CALL    ASCTFP
VAL3: POP     BC
  POP	  HL
  LD	  (HL),B
  RET
LFRGNM: EX	DE,HL
  CALL	  CHKSYN
  defb	    ")"
MIDNUM: POP	BC
  POP	  DE
  PUSH	  BC
  LD	  B,E
  RET
INP: CALL    MAKINT
  LD	  (INPORT),A
  CALL	  INPSUB
  JP	  PASSA
POUT: CALL    SETIO
  JP	  OUTSUB
WAIT: CALL    SETIO
  PUSH	  AF
  LD	  E,0
  DEC	  HL
  CALL	  GETCHR
  JR	  Z,NOXOR
  CALL	  CHKSYN
  defb	    ','
  CALL	  GETINT
NOXOR: POP     BC
WAITLP: CALL	INPSUB
  XOR	  E
  AND	  B
  JR	  Z,WAITLP
  RET
SETIO: CALL    GETINT
  LD	  (INPORT),A
  LD	  (OTPORT),A
  CALL	  CHKSYN
  defb	    ','
  JP	  GETINT
FNDNUM: CALL	GETCHR
GETINT: CALL	GETNUM
MAKINT: CALL	DEPINT
  LD	  A,D
  OR	  A
  JP	  NZ,FCERR
  DEC	  HL
  CALL	  GETCHR
  LD	  A,E
  RET
PEEK: CALL    DEINT
  LD	  A,(DE)
  JP	  PASSA
POKE: CALL    GETNUM
  CALL	  DEINT
  PUSH	  DE
  CALL	  CHKSYN
  defb	    ','
  CALL	  GETINT
  POP	  DE
  LD	  (DE),A
  RET
ROUND: LD      HL,HALF
ADDPHL: CALL	LOADFP
  JR	  FPADD
SUBPHL: CALL	LOADFP
  defb	    21H
PSUB: POP     BC
  POP	  DE
SUBCDE: CALL	INVSGN
FPADD: LD      A,B
  OR	  A
  RET	  Z
  LD	  A,(FPEXP)
  OR	  A
  JP	  Z,FPBCDE
  SUB	  B
  JR	  NC,NOSWAP
  CPL
  INC	  A
  EX	  DE,HL
  CALL	  STAKFP
  EX	  DE,HL
  CALL	  FPBCDE
  POP	  BC
  POP	  DE
NOSWAP: CP	24+1
  RET	  NC
  PUSH	  AF
  CALL	  SIGNS
  LD	  H,A
  POP	  AF
  CALL	  SCALE
  OR	  H
  LD	  HL,FPREG
  JP	  P,MINCDE
  CALL	  PLUCDE
  JR	  NC,RONDUP
  INC	  HL
  INC	  (HL)
  JP	  Z,OVERR
  LD	  L,1
  CALL	  SHRT1
  JP	  RONDUP
MINCDE: XOR	A
  SUB	  B
  LD	  B,A
  LD	  A,(HL)
  SBC	  A, E
  LD	  E,A
  INC	  HL
  LD	  A,(HL)
  SBC	  A,D
  LD	  D,A
  INC	  HL
  LD	  A,(HL)
  SBC	  A,C
  LD	  C,A
CONPOS: CALL	C,COMPL
BNORM: LD      L,B
  LD	  H,E
  XOR	  A
BNRMLP: LD	B,A
  LD	  A,C
  OR	  A
  JR	  NZ,PNORM
  LD	  C,D
  LD	  D,H
  LD	  H,L
  LD	  L,A
  LD	  A,B
  SUB	  8
  CP	  -24-8
  JR	  NZ,BNRMLP
RESZER: XOR	A
SAVEXP: LD	(FPEXP),A
  RET
NORMAL: DEC	B
  ADD	  HL,HL
  RL	  D
  RL	  C
PNORM: JP      P,NORMAL
  LD	  A,B
  LD	  E,H
  LD	  B,L
  OR	  A
  JR	  Z,RONDUP
  LD	  HL,FPEXP
  ADD	  A,(HL)
  LD	  (HL),A
  JR	  NC,RESZER
  RET	  Z
RONDUP: LD	A,B
RONDB: LD      HL,FPEXP
  OR	  A
  CALL	  M,FPROND
  LD	  B,(HL)
  INC	  HL
  LD	  A,(HL)
  AND	  10000000B
  XOR	  C
  LD	  C,A
  JP	  FPBCDE
FPROND: INC	E
  RET	  NZ
  INC	  D
  RET	  NZ
  INC	  C
  RET	  NZ
  LD	  C,80H
  INC	  (HL)
  RET	  NZ
  JP	  OVERR
PLUCDE: LD	A,(HL)
  ADD	  A,E
  LD	  E,A
  INC	  HL
  LD	  A,(HL)
  ADC	  A,D
  LD	  D,A
  INC	  HL
  LD	  A,(HL)
  ADC	  A,C
  LD	  C,A
  RET
COMPL: LD      HL,SGNRES
  LD	  A,(HL)
  CPL
  LD	  (HL),A
  XOR	  A
  LD	  L,A
  SUB	  B
  LD	  B,A
  LD	  A,L
  SBC	  A,E
  LD	  E,A
  LD	  A,L
  SBC	  A,D
  LD	  D,A
  LD	  A,L
  SBC	  A,C
  LD	  C,A
  RET
SCALE: LD      B,0
SCALLP: SUB	8
  JR	  C,SHRITE
  LD	  B,E
  LD	  E,D
  LD	  D,C
  LD	  C,0
  JP	  SCALLP
SHRITE: ADD	A,8+1
  LD	  L,A
SHRLP: XOR     A
  DEC	  L
  RET	  Z
  LD	  A,C
SHRT1: RRA
  LD	  C,A
  RR	  D
  RR	  E
  RR	  B
  JP	  SHRLP
UNITY: defb	  000H,000H,000H,081H
LOGTAB: defb	  3
  defb	    0AAH,056H,019H,080H
  defb	    0F1H,022H,076H,080H
  defb	    045H,0AAH,038H,082H
LOG: CALL    TSTSGN
  OR	  A
  JP	  PE,FCERR
  LD	  HL,FPEXP
  LD	  A,(HL)
  LD	  BC,8035H
  LD	  DE,04F3H
  SUB	  B
  PUSH	  AF
  LD	  (HL),B
  PUSH	  DE
  PUSH	  BC
  CALL	  FPADD
  POP	  BC
  POP	  DE
  INC	  B
  CALL	  DVBCDE
  LD	  HL,UNITY
  CALL	  SUBPHL
  LD	  HL,LOGTAB
  CALL	  SUMSER
  LD	  BC,8080H
  LD	  DE,0000H
  CALL	  FPADD
  POP	  AF
  CALL	  RSCALE
MULLN2: LD	BC,8031H
  LD	  DE,7218H
  defb	    21H
MULT: POP     BC
  POP	  DE
FPMULT: CALL	TSTSGN
  RET	  Z
  LD	  L,0
  CALL	  ADDEXP
  LD	  A,(FPREG)
  LD	  B,A
  XOR	  A
  LD	  H,A
  LD	  L,A
  CALL	  FMUL8
  EX	  AF,AF'
  LD	  A,(FPREG+1)
  LD	  B,A
  EX	  AF,AF'
  CALL	  FMUL8
  EX	  AF,AF'
  LD	  A,(FPREG+2)
  LD	  B,A
  EX	  AF,AF'
  CALL	  FMUL8
  LD	  C,A
  LD	  D,H
  LD	  E,L
  JP	  BNORM
POPHRT: POP	HL
  RET
FMUL8: INC     B
  DEC	  B
  JR	  Z,FMULZ
  SRL	  B
  JR	  NC,FMS0
  ADD	  HL,DE
  ADC	  A,C
FMS0: RRA
  RR	  H
  RR	  L
  RR	  B
  JR	  NC,FMS1
  ADD	  HL,DE
  ADC	  A,C
FMS1: RRA
  RR	  H
  RR	  L
  RR	  B
  JR	  NC,FMS2
  ADD	  HL,DE
  ADC	  A,C
FMS2: RRA
  RR	  H
  RR	  L
  RR	  B
  JR	  NC,FMS3
  ADD	  HL,DE
  ADC	  A,C
FMS3: RRA
  RR	  H
  RR	  L
  RR	  B
  JR	  NC,FMS4
  ADD	  HL,DE
  ADC	  A,C
FMS4: RRA
  RR	  H
  RR	  L
  RR	  B
  JR	  NC,FMS5
  ADD	  HL,DE
  ADC	  A,C
FMS5: RRA
  RR	  H
  RR	  L
  RR	  B
  JR	  NC,FMS6
  ADD	  HL,DE
  ADC	  A,C
FMS6: RRA
  RR	  H
  RR	  L
  RR	  B
  JR	  NC,FMS7
  ADD	  HL,DE
  ADC	  A,C
FMS7: RRA
  RR	  H
  RR	  L
  RR	  B
  RET
FMULZ: LD      B,L
  LD	  L,H
  LD	  H,A
  XOR	  A
  RET
DIV10: CALL    STAKFP
  LD	  BC,8420H
  LD	  DE,0000H
  CALL	  FPBCDE
DIV: POP     BC
  POP	  DE
DVBCDE: CALL	TSTSGN
  JP	  Z,DZERR
  LD	  L,-1
  CALL	  ADDEXP
  INC	  (HL)
  INC	  (HL)
  LD	  A,C
  EX	  DE,HL
  LD	  B,A
  LD	  DE,(FPREG)
  LD	  A,(FPREG+2)
  LD	  C,A
  EXX
  XOR	  A
  LD	  C,A
  LD	  D,A
  LD	  E,A
  EXX
DIVLP: OR      A
  SBC	  HL,DE
  LD	  A,B
  SBC	  A,C
  JR	  C,DIVNO
DIVYES: LD	B,A
  EXX
  BIT	  7,C
  SCF
  JR	  NZ,DIVFIN
  RL	  E
  RL	  D
  RL	  C
  EXX
DIVSH: ADD     HL,HL
  RL	  B
  JR	  NC,DIVLP
  OR	  A
  SBC	  HL,DE
  LD	  A,B
  SBC	  A,C
  JR	  DIVYES
DIVNO: ADD     HL,DE
  EXX
  BIT	  7,C
  JR	  NZ,DIVFN0
  SLA	  E
  RL	  D
  RL	  C
  LD	  A,C
  OR	  D
  OR	  E
  EXX
  JR	  NZ,DIVSH
  PUSH	  HL
  LD	  HL,FPEXP
  DEC	  (HL)
  POP	  HL
  JR	  NZ,DIVSH
  JP	  OVERR
DIVFN0: OR	A
DIVFIN: LD	A,0
  RRA
  PUSH	  BC
  PUSH	  DE
  EXX
  POP	  DE
  POP	  BC
  JP	  RONDB
ADDEXP: LD	A,B
  OR	  A
  JR	  Z,OVTST3
  LD	  A,L
  LD	  HL,FPEXP
  XOR	  (HL)
  ADD	  A,B
  LD	  B,A
  RRA
  XOR	  B
  LD	  A,B
  JP	  P,OVTST2
  ADD	  A,80H
  LD	  (HL),A
  JP	  Z,POPHRT
  CALL	  SIGNS
  LD	  (HL),A
  DEC	  HL
  RET
OVTST1: CALL	TSTSGN
  CPL
  POP	  HL
OVTST2: OR	A
OVTST3: POP	HL
  JP	  P,RESZER
  JP	  OVERR
MLSP10: CALL	BCDEFP
  LD	  A,B
  OR	  A
  RET	  Z
  ADD	  A,2
  JP	  C,OVERR
  LD	  B,A
  CALL	  FPADD
  LD	  HL,FPEXP
  INC	  (HL)
  RET	  NZ
  JP	  OVERR
TSTSGN: LD	A,(FPEXP)
  OR	  A
  RET	  Z
  LD	  A,(FPREG+2)
  defb	    0FEH
RETREL: CPL
  RLA
FLGDIF: SBC	A,A
  RET	  NZ
  INC	  A
  RET
SGN: CALL    TSTSGN
FLGREL: LD	B,80H+8
  LD	  DE,0
RETINT: LD	HL,FPEXP
  LD	  C,A
  LD	  (HL),B
  LD	  B,0
  INC	  HL
  LD	  (HL),80H
  RLA
  JP	  CONPOS
ABS: CALL    TSTSGN
  RET	  P
INVSGN: LD	HL,FPREG+2
  LD	  A,(HL)
  XOR	  80H
  LD	  (HL),A
  RET
STAKFP: EX	DE,HL
  LD	  HL,(FPREG)
  EX	  (SP),HL
  PUSH	  HL
  LD	  HL,(FPREG+2)
  EX	  (SP),HL
  PUSH	  HL
  EX	  DE,HL
  RET
PHLTFP: CALL	LOADFP
FPBCDE: EX	DE,HL
  LD	  (FPREG),HL
  LD	  H,B
  LD	  L,C
  LD	  (FPREG+2),HL
  EX	  DE,HL
  RET
BCDEFP: LD	HL,FPREG
LOADFP: LD	E,(HL)
  INC	  HL
  LD	  D,(HL)
  INC	  HL
  LD	  C,(HL)
  INC	  HL
  LD	  B,(HL)
INCHL: INC     HL
  RET
FPTHL: LD      DE,FPREG
DETHL4: LD	B,4
DETHLB: LD	A,(DE)
  LD	  (HL),A
  INC	  DE
  INC	  HL
  DEC	  B
  JR	  NZ,DETHLB
  RET
SIGNS: LD      HL,FPREG+2
  LD	  A,(HL)
  RLCA
  SCF
  RRA
  LD	  (HL),A
  CCF
  RRA
  INC	  HL
  INC	  HL
  LD	  (HL),A
  LD	  A,C
  RLCA
  SCF
  RRA
  LD	  C,A
  RRA
  XOR	  (HL)
  RET
CMPNUM: LD	A,B
  OR	  A
  JR	  Z,TSTSGN
  LD	  HL,RETREL
  PUSH	  HL
  CALL	  TSTSGN
  LD	  A,C
  RET	  Z
  LD	  HL,FPREG+2
  XOR	  (HL)
  LD	  A,C
  RET	  M
  CALL	  CMPFP
  RRA
  XOR	  C
  RET
CMPFP: INC     HL
  LD	  A,B
  CP	  (HL)
  RET	  NZ
  DEC	  HL
  LD	  A,C
  CP	  (HL)
  RET	  NZ
  DEC	  HL
  LD	  A,D
  CP	  (HL)
  RET	  NZ
  DEC	  HL
  LD	  A,E
  SUB	  (HL)
  RET	  NZ
  POP	  HL
  POP	  HL
  RET
FPINT: LD      B,A
  LD	  C,A
  LD	  D,A
  LD	  E,A
  OR	  A
  RET	  Z
  PUSH	  HL
  CALL	  BCDEFP
  CALL	  SIGNS
  XOR	  (HL)
  LD	  H,A
  CALL	  M,DCBCDE
  LD	  A,80H+24
  SUB	  B
  CALL	  SCALE
  LD	  A,H
  RLA
  CALL	  C,FPROND
  LD	  B,0
  CALL	  C,COMPL
  POP	  HL
  RET
DCBCDE: DEC	DE
  LD	  A,D
  AND	  E
  INC	  A
  RET	  NZ
  DEC	  BC
  RET
INT: LD      HL,FPEXP
  LD	  A,(HL)
  CP	  80H+24
  LD	  A,(FPREG)
  RET	  NC
  LD	  A,(HL)
  CALL	  FPINT
  LD	  (HL),80H+24
  LD	  A,E
  PUSH	  AF
  LD	  A,C
  RLA
  CALL	  CONPOS
  POP	  AF
  RET
MLDEBC: LD	HL,0
  LD	  A,B
  OR	  C
  RET	  Z
  LD	  A,16
MLDBLP: ADD	HL,HL
  JP	  C,BSERR
  EX	  DE,HL
  ADD	  HL,HL
  EX	  DE,HL
  JR	  NC,NOMLAD
  ADD	  HL,BC
  JP	  C,BSERR
NOMLAD: DEC	A
  JR	  NZ,MLDBLP
  RET
ASCTFP: CP	'-'
  PUSH	  AF
  JR	  Z,CNVNUM
  CP	  '+'
  JR	  Z,CNVNUM
  DEC	  HL
CNVNUM: CALL	FASTN
  CALL	  RESZER
  LD	  B,A
  LD	  D,A
  LD	  E,A
  CPL
  LD	  C,A
MANLP: CALL    GETCHR
  JR	  C,ADDIG
  CP	  '.'
  JR	  Z,DPOINT
  CP	  'E'
  JR	  NZ,CONEXP
  CALL	  GETCHR
  CALL	  SGNEXP
EXPLP: CALL    GETCHR
  JR	  C,EDIGIT
  INC	  D
  JR	  NZ,CONEXP
  XOR	  A
  SUB	  E
  LD	  E,A
  INC	  C
DPOINT: INC	C
  JR	  Z,MANLP
CONEXP: PUSH	HL
  LD	  A,E
  SUB	  B
SCALMI: CALL	P,SCALPL
  JP	  P,ENDCON
  PUSH	  AF
  CALL	  DIV10
  POP	  AF
  INC	  A
ENDCON: JR	NZ,SCALMI
ENDCN2:
  POP	  DE
  POP	  AF
  CALL	  Z,INVSGN
  EX	  DE,HL
  RET
SCALPL: RET	Z
MULTEN: PUSH	AF
  CALL	  MLSP10
  POP	  AF
  DEC	  A
  RET
ADDIG: PUSH    DE
  LD	  D,A
  LD	  A,B
  ADC	  A,C
  LD	  B,A
  PUSH	  BC
  PUSH	  HL
  PUSH	  DE
  CALL	  MLSP10
  POP	  AF
  SUB	  '0'
  CALL	  RSCALE
  POP	  HL
  POP	  BC
  POP	  DE
  JP	  MANLP
RSCALE: CALL	STAKFP
  CALL	  FLGREL
PADD: POP     BC
  POP	  DE
  JP	  FPADD
EDIGIT: LD	A,E
  RLCA
  RLCA
  ADD	  A,E
  RLCA
  ADD	  A,(HL)
  SUB	  '0'
  LD	  E,A
  JR	  EXPLP
LINEIN: PUSH	HL
  LD	  HL,INMSG
  CALL	  PRS
  POP	  HL
PRNTHL: EX	DE,HL
  XOR	  A
  LD	  B,80H+24
  CALL	  RETINT
  LD	  HL,PRNUMS
  PUSH	  HL
NUMASC: LD	HL,PBUFF
  PUSH	  HL
  CALL	  TSTSGN
  LD	  (HL),' '
  JP	  P,SPCFST
  LD	  (HL),'-'
SPCFST: INC	HL
  LD	  (HL),'0'
  JP	  Z,JSTZER
  PUSH	  HL
  CALL	  M,INVSGN
  XOR	  A
  PUSH	  AF
  CALL	  RNGTST
SIXDIG: LD	BC,9143H
  LD	  DE,4FF8H
  CALL	  CMPNUM
  OR	  A
  JP	  PO,INRNG
  POP	  AF
  CALL	  MULTEN
  PUSH	  AF
  JR	  SIXDIG
GTSIXD: CALL	DIV10
  POP	  AF
  INC	  A
  PUSH	  AF
  CALL	  RNGTST
INRNG: CALL    ROUND
  INC	  A
  CALL	  FPINT
  CALL	  FPBCDE
  LD	  BC,0306H
  POP	  AF
  ADD	  A,C
  INC	  A
  JP	  M,MAKNUM
  CP	  6+1+1
  JR	  NC,MAKNUM
  INC	  A
  LD	  B,A
  LD	  A,2
MAKNUM: DEC	A
  DEC	  A
  POP	  HL
  PUSH	  AF
  LD	  DE,POWERS
  DEC	  B
  JR	  NZ,DIGTXT
  LD	  (HL),'.'
  INC	  HL
  LD	  (HL),'0'
  INC	  HL
DIGTXT: DEC	B
  LD	  (HL),'.'
  CALL	  Z,INCHL
  PUSH	  BC
  PUSH	  HL
  PUSH	  DE
  CALL	  BCDEFP
  POP	  HL
  LD	  B, '0'-1
TRYAGN: INC	B
  LD	  A,E
  SUB	  (HL)
  LD	  E,A
  INC	  HL
  LD	  A,D
  SBC	  A,(HL)
  LD	  D,A
  INC	  HL
  LD	  A,C
  SBC	  A,(HL)
  LD	  C,A
  DEC	  HL
  DEC	  HL
  JR	  NC,TRYAGN
  CALL	  PLUCDE
  INC	  HL
  CALL	  FPBCDE
  EX	  DE,HL
  POP	  HL
  LD	  (HL),B
  INC	  HL
  POP	  BC
  DEC	  C
  JR	  NZ,DIGTXT
  DEC	  B
  JR	  Z,DOEBIT
SUPTLZ: DEC	HL
  LD	  A,(HL)
  CP	  '0'
  JR	  Z,SUPTLZ
  CP	  '.'
  CALL	  NZ,INCHL
DOEBIT: POP	AF
  JR	  Z,NOENED
  LD	  (HL),'E'
  INC	  HL
  LD	  (HL),'+'
  JP	  P,OUTEXP
  LD	  (HL),'-'
  CPL
  INC	  A
OUTEXP: LD	B,'0'-1
EXPTEN: INC	B
  SUB	  10
  JR	  NC,EXPTEN
  ADD	  A,'0'+10
  INC	  HL
  LD	  (HL),B
JSTZER: INC	HL
  LD	  (HL),A
  INC	  HL
NOENED: LD	(HL),C
  POP	  HL
  RET
RNGTST: LD	BC,9474H
  LD	  DE,23F7H
  CALL	  CMPNUM
  OR	  A
  POP	  HL
  JP	  PO,GTSIXD
  JP	  (HL)
HALF: defb	00H,00H,00H,80H
POWERS: defb	  0A0H,086H,001H
  defb	    010H,027H,000H
  defb	    0E8H,003H,000H
  defb	    064H,000H,000H
  defb	    00AH,000H,000H
  defb	    001H,000H,000H
NEGAFT: LD  HL,INVSGN
  EX	  (SP),HL
  JP	  (HL)
SQR: CALL    STAKFP
  LD	  HL,HALF
  CALL	  PHLTFP
POWER: POP     BC
  POP	  DE
  CALL	  TSTSGN
  LD	  A,B
  JR	  Z,EXP
  JP	  P,POWER1
  OR	  A
  JP	  Z,DZERR
POWER1: OR	A
  JP	  Z,SAVEXP
  PUSH	  DE
  PUSH	  BC
  LD	  A,C
  OR	  01111111B
  CALL	  BCDEFP
  JP	  P,POWER2
  PUSH	  DE
  PUSH	  BC
  CALL	  INT
  POP	  BC
  POP	  DE
  PUSH	  AF
  CALL	  CMPNUM
  POP	  HL
  LD	  A,H
  RRA
POWER2: POP	HL
  LD	  (FPREG+2),HL
  POP	  HL
  LD	  (FPREG),HL
  CALL	  C,NEGAFT
  CALL	  Z,INVSGN
  PUSH	  DE
  PUSH	  BC
  CALL	  LOG
  POP	  BC
  POP	  DE
  CALL	  FPMULT
EXP: CALL    STAKFP
  LD	  BC,08138H
  LD	  DE,0AA3BH
  CALL	  FPMULT
  LD	  A,(FPEXP)
  CP	  80H+8
  JP	  NC,OVTST1
  CALL	  INT
  ADD	  A,80H
  ADD	  A,2
  JP	  C,OVTST1
  PUSH	  AF
  LD	  HL,UNITY
  CALL	  ADDPHL
  CALL	  MULLN2
  POP	  AF
  POP	  BC
  POP	  DE
  PUSH	  AF
  CALL	  SUBCDE
  CALL	  INVSGN
  LD	  HL,EXPTAB
  CALL	  SMSER1
  LD	  DE,0
  POP	  BC
  LD	  C,D
  JP	  FPMULT
EXPTAB: defb	  8
  defb	    040H,02EH,094H,074H
  defb	    070H,04FH,02EH,077H
  defb	    06EH,002H,088H,07AH
  defb	    0E6H,0A0H,02AH,07CH
  defb	    050H,0AAH,0AAH,07EH
  defb	    0FFH,0FFH,07FH,07FH
  defb	    000H,000H,080H,081H
  defb	    000H,000H,000H,081H
SUMSER: CALL	STAKFP
  LD	  DE,MULT
  PUSH	  DE
  PUSH	  HL
  CALL	  BCDEFP
  CALL	  FPMULT
  POP	  HL
SMSER1: CALL	STAKFP
  LD	  A,(HL)
  INC	  HL
  CALL	  PHLTFP
  defb	    06H
SUMLP: POP     AF
  POP	  BC
  POP	  DE
  DEC	  A
  RET	  Z
  PUSH	  DE
  PUSH	  BC
  PUSH	  AF
  PUSH	  HL
  CALL	  FPMULT
  POP	  HL
  CALL	  LOADFP
  PUSH	  HL
  CALL	  FPADD
  POP	  HL
  JR	  SUMLP
RND: CALL    TSTSGN
  LD	  HL,SEED+2
  JP	  M,RESEED
  LD	  HL,LSTRND
  CALL	  PHLTFP
  LD	  HL,SEED+2
  RET	  Z
  ADD	  A,(HL)
  AND	  00000111B
  LD	  B,0
  LD	  (HL),A
  INC	  HL
  ADD	  A,A
  ADD	  A,A
  LD	  C,A
  ADD	  HL,BC
  CALL	  LOADFP
  CALL	  FPMULT
  LD	  A,(SEED+1)
  INC	  A
  AND	  00000011B
  LD	  B,0
  CP	  1
  ADC	  A,B
  LD	  (SEED+1),A
  LD	  HL,RNDTAB-4
  ADD	  A,A
  ADD	  A,A
  LD	  C,A
  ADD	  HL,BC
  CALL	  ADDPHL
RND1: CALL    BCDEFP
  LD	  A,E
  LD	  E,C
  XOR	  01001111B
  LD	  C,A
  LD	  (HL),80H
  DEC	  HL
  LD	  B,(HL)
  LD	  (HL),80H
  LD	  HL,SEED
  INC	  (HL)
  LD	  A,(HL)
  SUB	  171
  JR	  NZ,RND2
  LD	  (HL),A
  INC	  C
  DEC	  D
  INC	  E
RND2: CALL    BNORM
  LD	  HL,LSTRND
  JP	  FPTHL
RESEED: LD	(HL),A
  DEC	  HL
  LD	  (HL),A
  DEC	  HL
  LD	  (HL),A
  JR	  RND1
RNDTAB: defb   068H,0B1H,046H,068H
  defb	 099H,0E9H,092H,069H
  defb	 010H,0D1H,075H,068H
COS: LD      HL,HALFPI
  CALL	  ADDPHL
SIN: CALL    STAKFP
  LD	  BC,8349H
  LD	  DE,0FDBH
  CALL	  FPBCDE
  POP	  BC
  POP	  DE
  CALL	  DVBCDE
  CALL	  STAKFP
  CALL	  INT
  POP	  BC
  POP	  DE
  CALL	  SUBCDE
  LD	  HL,QUARTR
  CALL	  SUBPHL
  CALL	  TSTSGN
  SCF
  JP	  P,SIN1
  CALL	  ROUND
  CALL	  TSTSGN
  OR	  A
SIN1: PUSH    AF
  CALL	  P,INVSGN
  LD	  HL,QUARTR
  CALL	  ADDPHL
  POP	  AF
  CALL	  NC,INVSGN
  LD	  HL,SINTAB
  JP	  SUMSER
HALFPI: defb   0DBH,00FH,049H,081H
QUARTR: defb   000H,000H,000H,07FH
SINTAB: defb   5
  defb	 0BAH,0D7H,01EH,086H
  defb	 064H,026H,099H,087H
  defb	 058H,034H,023H,087H
  defb	 0E0H,05DH,0A5H,086H
  defb	 0DAH,00FH,049H,083H
TAN: CALL    STAKFP
  CALL	  SIN
  POP	  BC
  POP	  HL
  CALL	  STAKFP
  EX	  DE,HL
  CALL	  FPBCDE
  CALL	  COS
  JP	  DIV
ATN: CALL    TSTSGN
  CALL	  M,NEGAFT
  CALL	  M,INVSGN
  LD	  A,(FPEXP)
  CP	  81H
  JR	  C,ATN1
  LD	  BC,8100H
  LD	  D,C
  LD	  E,C
  CALL	  DVBCDE
  LD	  HL,SUBPHL
  PUSH	  HL
ATN1: LD      HL,ATNTAB
  CALL	  SUMSER
  LD	  HL,HALFPI
  RET
ATNTAB: defb   9
  defb	 04AH,0D7H,03BH,078H
  defb	 002H,06EH,084H,07BH
  defb	 0FEH,0C1H,02FH,07CH
  defb	 074H,031H,09AH,07DH
  defb	 084H,03DH,05AH,07DH
  defb	 0C8H,07FH,091H,07EH
  defb	 0E4H,0BBH,04CH,07EH
  defb	 06CH,0AAH,0AAH,07FH
  defb	 000H,000H,000H,081H
ARET: RET
GETINP: JP	EXTRX
  RET
CLS:
  LD	  A,CS
  JP	  MONOUT
WIDTH: CALL    GETINT
  LD	  A,E
  LD	  (LWIDTH),A
  RET
LINES: CALL    GETNUM
  CALL	  DEINT
  LD	  (LINESC),DE
  LD	  (LINESN),DE
  RET
DEEK: CALL    DEINT
  PUSH	  DE
  POP	  HL
  LD	  B,(HL)
  INC	  HL
  LD	  A,(HL)
  JP	  ABPASS
DOKE: CALL    GETNUM
  CALL	  DEINT
  PUSH	  DE
  CALL	  CHKSYN
  defb	    ','
  CALL	  GETNUM
  CALL	  DEINT
  EX	  (SP),HL
  LD	  (HL),E
  INC	  HL
  LD	  (HL),D
  POP	  HL
  RET
HEX: CALL	TSTNUM
  CALL	DEINT
  PUSH	BC
  LD	    HL,PBUFF
  LD	    A,D
  CP	  00h
  JR	  Z,HEX2
  CALL	  BYT2ASC
  LD	  A,B
  CP	  '0'
  JR	  Z,HEX1
  LD	    (HL),B
  INC	    HL
HEX1: LD	    (HL),C
  INC	  HL
HEX2: LD	    A,E
  CALL	  BYT2ASC
  LD	  A,D
  CP	  00h
  JR	  NZ,HEX3
  LD	  A,B
  CP	  '0'
  JR	  Z,HEX4
HEX3: LD      (HL),B
  INC	  HL
HEX4: LD      (HL),C
  INC	  HL
  XOR	  A
  LD	  (HL),A
  INC	  HL
  LD	  (HL),A
  POP	  BC
  LD	  HL,PBUFF
  JP	  STR1
BYT2ASC: LD	 B,A
  AND	  00Fh
  CP	  00Ah
  JR	  C,ADD30
  ADD	  A,007h
ADD30: ADD     A,030h
  LD	  C,A
  LD	  A,B
  RRCA
  RRCA
  RRCA
  RRCA
  AND	  00Fh
  CP	  00Ah
  JR	  C,ADD301
  ADD	  A,007h
ADD301: ADD	A,030h
  LD	  B,A
  RET
HEXTFP: EX	DE,HL
  LD	  HL,00000h
  CALL	  GETHEX
  JR	  C,HXERR
  JR	  HEXLP1
HEXLP: CALL    GETHEX
  JR	  C,HEXIT
HEXLP1: ADD	HL,HL
  ADD	  HL,HL
  ADD	  HL,HL
  ADD	  HL,HL
  OR	  L
  LD	  L,A
  JR	  HEXLP
GETHEX: INC	DE
  LD	  A,(DE)
  CP	  ' '
  JR	  Z,GETHEX
  SUB	  030h
  RET	  C
  CP	  00Ah
  JR	  C,NOSUB7
  SUB	  007h
  CP	  00Ah
  RET	  C
NOSUB7: CP	010h
  CCF
  RET
HEXIT: EX      DE,HL
  LD	  A,D
  LD	  C,E
  PUSH	  HL
  CALL	  ACPASS
  POP	  HL
  RET
HXERR: LD      E,HX
  JP	  ERROR
BIN: CALL    TSTNUM
  CALL	  DEINT
BIN2: PUSH    BC
  LD	  HL,PBUFF
  LD	  B,17
ZEROSUP:
  DEC	  B
  LD	  A,B
  CP	  001h
  JR	  Z,BITOUT
  RL	  E
  RL	  D
  JR	  NC,ZEROSUP
  JR	  BITOUT2
BITOUT:
  RL	  E
  RL	  D
BITOUT2:
  LD	  A,'0'
  ADC	  A,0
  LD	  (HL),A
  INC	  HL
  DEC	  B
  JR	  NZ,BITOUT
  XOR	  A
  LD	  (HL),A
  INC	  HL
  LD	  (HL),A
  POP	  BC
  LD	  HL,PBUFF
  JP	  STR1
BINTFP: EX	DE,HL
  LD	  HL,00000h
  CALL	  CHKBIN
  JR	  C,BINERR
BINIT: SUB     '0'
  ADD	  HL,HL
  OR	  L
  LD	  L,A
  CALL	  CHKBIN
  JR	  NC,BINIT
  EX	  DE,HL
  LD	  A,D
  LD	  C,E
  PUSH	  HL
  CALL	  ACPASS
  POP	  HL
  RET
CHKBIN: INC	DE
  LD	  A,(DE)
  CP	  ' '
  JR	  Z,CHKBIN
  CP	  '0'
  RET	  C
  CP	  '2'
  CCF
  RET
BINERR: LD	E,BN
  JP	  ERROR
MONOUT: JR	EXTTX
MONITR:
  JP	  00000h
ARETN: RETN
TSTBIT: PUSH	AF
  AND	  B
  POP	  BC
  CP	  B
  LD	  A,0
  RET
OUTNCR: CALL	OUTC
  JP	  PRNTCRLF
IOMODE: equ    NMIFLG
OLDLN: equ    CHKSUM
DARTAD: equ    80H
DARTAC: equ    84H
DARTBD: equ    88H
DARTBC: equ    8CH
CTCB: equ    50H
CTCBTC: equ    13
BRKSET: equ    02H
BRKCLR: equ    03H
CTCS: equ    60H
EOFCH: equ    1AH
EXTTX: PUSH    AF
  LD	  A,(IOMODE)
  AND	  3DH
  JR	  Z,SBCON
  BIT	  4,A
  JP	  NZ,DXTX
  BIT	  5,A
  JP	  NZ,DXQUIET
  LD	  A,(IOMODE)
  AND	  0DH
  AND	  08H
  JR	  NZ,SBTEE
  POP	  AF
SBTX: PUSH    AF
SBTX2: IN      A,(DARTBC)
  BIT	  2,A
  JR	  Z,SBTX2
  POP	  AF
  OUT	  (DARTBD),A
  RET
SBCON: POP     AF
  JP	  0008H
SBTEE: POP     AF
  CALL	  SBTX
  JP	  0008H
EXTRX: JP      DXRX
EXTRX2: LD	A,(IOMODE)
  AND	  02H
  JR	  NZ,SBRX
  RST	  10H
  RET
SBRX: CALL    RTSON
SBRX1: IN      A,(DARTAC)
  BIT	  0,A
  JR	  NZ,SBABRT
  IN	  A,(DARTBC)
  BIT	  0,A
  JR	  Z,SBRX1
  IN	  A,(DARTBD)
  CP	  EOFCH
  JR	  Z,SBEOF
  CP	  0AH
  JR	  Z,SBRX1
  CP	  0DH
  RET	  NZ
  JR	  RTSOFF
SBABRT: IN	A,(DARTAD)
SBEOF: LD      A,(IOMODE)
  AND	  0DDH
  LD	  (IOMODE),A
  CALL	  RTSOFF
  PUSH	  HL
  LD	  HL,SBOK
SBMSG: LD      A,(HL)
  OR	  A
  JR	  Z,SBMSGE
  RST	  08H
  INC	  HL
  JR	  SBMSG
SBMSGE: POP	HL
  LD	  A,0DH
  RET
SBOK: defb   13,10,"Ok",13,10,0
RTSON: PUSH    AF
  LD	  A,05H
  OUT	  (DARTBC),A
  LD	  A,0EAH
  OUT	  (DARTBC),A
  POP	  AF
  RET
RTSOFF: PUSH	AF
  LD	  A,05H
  OUT	  (DARTBC),A
  LD	  A,0E8H
  OUT	  (DARTBC),A
  POP	  AF
  RET
EXTEND: LD	A,(IOMODE)
  BIT	  4,A
  CALL	  NZ,DXFIN
  LD	  A,(IOMODE)
  AND	  0F3H
  LD	  (IOMODE),A
  AND	  01H
  RET	  Z
  LD	  A,0DH
  CALL	  SBTX
  LD	  A,0AH
  CALL	  SBTX
  LD	  A,EOFCH
  CALL	  SBTX
  LD	  A,(IOMODE)
  AND	  0FEH
  LD	  (IOMODE),A
  LD	  HL,(OLDLN)
  LD	  (LINESN),HL
  LD	  (LINESC),HL
  RET
EXTCLR: JP	DXCLR
  PUSH	  AF
  LD	  A,(IOMODE)
  AND	  0F3H
  LD	  (IOMODE),A
  POP	  AF
  RET
SSAVE: RET     NZ
  PUSH	  HL
  LD	  HL,(LINESN)
  LD	  (OLDLN),HL
  LD	  HL,7FFFH
  LD	  (LINESN),HL
  LD	  (LINESC),HL
  POP	  HL
  LD	  A,(IOMODE)
  OR	  01H
  LD	  (IOMODE),A
  JP	  LIST
SLOAD: RET     NZ
  CALL	  CLRPTR
  LD	  A,(IOMODE)
  OR	  02H
  LD	  (IOMODE),A
  JP	  PRNTOK
STPRINT: PUSH	AF
  LD	  A,(IOMODE)
  OR	  04H
  LD	  (IOMODE),A
  POP	  AF
  CALL	  PRINT
  PUSH	  AF
  LD	  A,(IOMODE)
  AND	  0FBH
  LD	  (IOMODE),A
  POP	  AF
  RET
DPRINT: PUSH	AF
  LD	  A,(IOMODE)
  OR	  08H
  LD	  (IOMODE),A
  POP	  AF
  CALL	  PRINT
  PUSH	  AF
  LD	  A,(IOMODE)
  AND	  0F7H
  LD	  (IOMODE),A
  POP	  AF
  RET
SLEEP: CALL    GETNUM
  CALL	  DEPINT
  PUSH	  HL
  LD	  A,D
  OR	  E
  JR	  Z,SLDONE
  LD	  A,07H
  OUT	  (CTCS),A
  LD	  A,250
  OUT	  (CTCS),A
  LD	  B,10
SLWT: DJNZ    SLWT
  IN	  A,(CTCS)
  LD	  B,A
SLLOOP: IN	A,(CTCS)
  CP	  B
  LD	  B,A
  JR	  C,SLLOOP
  JR	  Z,SLLOOP
  PUSH	  DE
  CALL	  TSTBRK
  POP	  DE
  DEC	  DE
  LD	  A,D
  OR	  E
  JR	  NZ,SLLOOP
SLDONE: POP	HL
  RET
EXTBRK: PUSH	AF
  PUSH	  BC
  XOR	  A
  OUT	  (BRKSET),A
  LD	  B,0
EXTBL: DJNZ    EXTBL
  OUT	  (BRKCLR),A
  POP	  BC
  POP	  AF
  RET
EXTSTP: CALL	EXTBRK
  JP	  STOP
FASTN:	push hl
	ld de,0
fn_1:	inc hl
	ld a,(hl)
	cp ' '
	jr z,fn_1
	sub '0'
	cp 10
	jr nc,fn_end
	push hl
	ld h,d
	ld l,e
	add hl,hl
	jr c,fn_big
	add hl,hl
	jr c,fn_big
	add hl,de
	jr c,fn_big
	add hl,hl
	jr c,fn_big
	ld e,a
	ld d,0
	add hl,de
	jr c,fn_big
	ex de,hl
	pop hl
	jr fn_1
fn_big: pop hl
	pop hl
	ret
fn_end: ld a,(hl)
	cp '.'
	jr z,fn_slow
	cp 'E'
	jr z,fn_slow
	ld a,d
	or e
	jr z,fn_slow
	pop af
	pop af
	push hl
	ex de,hl
	ld b,80h+16
	ld a,h
	or a
	jr nz,fn_n
	ld h,l
	ld l,a
	ld b,80h+8
fn_n:	bit 7,h
	jr nz,fn_f
	add hl,hl
	dec b
	jr fn_n
fn_f:	res 7,h
	ld (FPREG+1),hl
	xor a
	ld (FPREG),a
	ld a,b
	ld (FPEXP),a
	jp ENDCN2
fn_slow:
	pop hl
	ret
DXEXTLEN: equ 4
DXRX:	ld a,(IOMODE)
	bit 5,a
	jr nz,dx_frx
	push hl
	ld hl,(DXFEED)
	ld a,h
	or l
	jr z,dxr_old
	ld a,(hl)
	inc hl
	ld (DXFEED),hl
	or a
	jr z,dxr_end
	pop hl
	ret
dxr_end:
	ld hl,0
	ld (DXFEED),hl
dxr_old:
	pop hl
	jp EXTRX2
dx_frx: in a,(DARTAC)
	bit 0,a
	jp nz,SBABRT
	push bc
	push de
	push hl
dxf_1:	call dx_getb
	jr c,dxf_eof
	ld b,a
	ld a,(DXPREV)
	ld c,a
	ld a,b
	ld (DXPREV),a
	cp 10
	jr nz,dxf_2
	ld a,c
	cp 13
	jr z,dxf_1
	ld a,13
	jr dxf_ok
dxf_2:	cp 1Ah
	jr z,dxf_eof
dxf_ok: pop hl
	pop de
	pop bc
	ret
dxf_eof:
	pop hl
	pop de
	pop bc
	jp SBEOF
dx_getb:
	ld hl,(DXLEFT)
	ld a,h
	or l
	jr nz,dxg_1
	push ix
	ld ix,DXFCB
	ld de,DXFCB+86
	ld bc,256
	call OS_READ
	pop ix
	ret c
	ld a,b
	or c
	scf
	ret z
	ld (DXLEFT),bc
	ld hl,DXFCB+86
	ld (DXPTR),hl
dxg_1:	ld hl,(DXLEFT)
	dec hl
	ld (DXLEFT),hl
	ld hl,(DXPTR)
	ld a,(hl)
	inc hl
	ld (DXPTR),hl
	or a
	ret
DXTX:	pop af
	push bc
	push de
	push hl
	push af
	ld b,a
	ld a,(DXANY)
	or a
	jr nz,dxt_1
	ld a,b
	cp 13
	jr z,dxt_9
	cp 10
	jr z,dxt_9
	ld a,1
	ld (DXANY),a
dxt_1:	ld a,b
	call dx_put
dxt_9:	pop af
	pop hl
	pop de
	pop bc
	ret
DXQUIET:
	pop af
	ret
dx_put: ld hl,(DXCNT)
	ld de,DXFCB+86
	add hl,de
	ld (hl),a
	ld hl,(DXCNT)
	inc hl
	ld (DXCNT),hl
	ld a,h
	or a
	ret z
dx_wout:
	ld bc,(DXCNT)
	ld a,b
	or c
	ret z
	ld hl,0
	ld (DXCNT),hl
	ld a,(DXERR)
	or a
	ret nz
	push ix
	ld ix,DXFCB
	ld de,DXFCB+86
	call OS_WRITE
	pop ix
	ret nc
	ld (DXERR),a
	ret
dx_close:
	call dx_wout
	push ix
	ld ix,DXFCB
	call OS_CLOSE
	pop ix
	ret c
	ld a,(DXERR)
	or a
	ret z
	scf
	ret
dx_lines:
	ld hl,(OLDLN)
	ld (LINESN),hl
	ld (LINESC),hl
	ret
DXFIN:	and 0EFh
	ld (IOMODE),a
	ld a,13
	call dx_put
	ld a,10
	call dx_put
	call dx_close
	call c,dx_msg
	jr dx_lines
DXCLR:	push af
	push bc
	push de
	push hl
	ld a,(IOMODE)
	bit 4,a
	jr z,dxc_1
	and 0EFh
	ld (IOMODE),a
	call dx_close
	call dx_lines
dxc_1:	ld a,(IOMODE)
	and 0C3h
	ld (IOMODE),a
	pop hl
	pop de
	pop bc
	pop af
	ret
dx_str: call EVAL
	push hl
	call GETLEN
	jp z,FCERR
	cp 65
	jp nc,FCERR
	inc hl
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld b,a
	ld hl,DXFCB+16
dxs_1:	ld a,(de)
	ld (hl),a
	inc de
	inc hl
	djnz dxs_1
	ld (hl),0
	pop hl
	ret
dx_file:
	ld hl,DXFCB+16
	ld c,0
dxe_1:	ld a,(hl)
	or a
	jr z,dxe_3
	cp '.'
	jr nz,dxe_2
	ld c,1
dxe_2:	cp 5Ch
	jr z,dxe_2b
	cp ':'
	jr z,dxe_2b
	cp '/'
	jr nz,dxe_2c
dxe_2b: ld c,0
dxe_2c: inc hl
	jr dxe_1
dxe_3:	dec c
	jr z,dxe_4
	ex de,hl
	ld hl,dx_mbas
	ld bc,DXEXTLEN+1
	ldir
dxe_4:	call OS_HOME
	ld a,0FFh
	ret c
	ld hl,DXFCB+16
	jp OS_RESOLVE
dx_mbas: defb ".BAS",0
dx_msg: cp 0FFh
	ret z
	call OS_ERRMSG
	ld a,'?'
	rst 08h
dx_prs: ld a,(hl)
	or a
	jr z,dxp_1
	rst 08h
	inc hl
	jr dx_prs
dxp_1:	xor a
	ld (CURPOS),a
	ld a,13
	rst 08h
	ld a,10
	rst 08h
	ret
dx_fail:
	call dx_msg
	pop hl
	jp PRNTOK
DXLOAD: call dx_str
	push hl
	call dx_file
	jr c,dx_fail
	ld ix,DXFCB
	call OS_OPEN
	jr c,dx_fail
	call CLRPTR
	ld hl,0
	ld (DXLEFT),hl
	xor a
	ld (DXPREV),a
	ld a,(IOMODE)
	or 20h
	ld (IOMODE),a
	pop hl
	jp PRNTOK
DXSAVE: call dx_str
	push hl
	call dx_file
	jr c,dx_fail
	ld ix,DXFCB
	call OS_CREATE
	jr c,dx_fail
	ld hl,0
	ld (DXCNT),hl
	xor a
	ld (DXANY),a
	ld (DXERR),a
	ld hl,(LINESN)
	ld (OLDLN),hl
	ld hl,7FFFh
	ld (LINESN),hl
	ld (LINESC),hl
	ld a,(IOMODE)
	or 10h
	ld (IOMODE),a
	pop hl
	jp LIST
DXDOS:	jp z,OS_WARM
	call dx_str
	push hl
	push ix
	ld hl,(ARREND)
	ex de,hl
	ld hl,-300
	add hl,sp
	or a
	sbc hl,de
	jr c,dxd_mem
	ld b,h
	ld c,l
	ld hl,DXFCB+16
	call OS_EXEC
	jr nc,dxd_1
dxd_mem:
	ld hl,dx_mmem
	call dx_prs
dxd_1:	xor a
	ld (CURPOS),a
	pop ix
	pop hl
	ret
dx_mmem: defb "?not enough free memory for DOS",0
DXFEED: defw 0
DXLEFT: defw 0
DXPTR:	defw 0
DXPREV: defb 0
DXCNT:	defw 0
DXANY:	defb 0
DXERR:	defb 0
DXFEEDB: defs 72
DXFCB:
DXARG:	ld de,DXFEEDB
	ld a,(hl)
	or a
	jr z,dxa_none
	push hl
	ld hl,dx_mload
	call dx_cpy
	pop hl
	ld b,60
dxa_1:	ld a,(hl)
	or a
	jr z,dxa_2
	cp ' '
	jr z,dxa_2
	ld (de),a
	inc hl
	inc de
	djnz dxa_1
dxa_2:	ld hl,dx_mrun
	call dx_cpy
	xor a
	ld (de),a
	ld hl,DXFEEDB
	ld (DXFEED),hl
	ret
dxa_none:
	ld hl,0
	ld (DXFEED),hl
	ret
dx_cpy: ld a,(hl)
	or a
	ret z
	ld (de),a
	inc hl
	inc de
	jr dx_cpy
dx_mload: defb "LOAD ",34,0
dx_mrun:  defb 34,13,"RUN",13,0
DXTOP:	call OS_VERSION
	ld de,0005h
	or a
	sbc hl,de
	ld hl,0B000h
	ret c
	jp OS_MEMTOP
CSTART: LD	HL,WRKSPC
  LD	  SP,HL
  JP	  INITST
INIT: LD      HL,WRKSPC+INITBE-INITAB+3
  LD	  SP,HL
  CALL	  CLREG
  CALL	  PRNTCRLF
  LD	  (BUFFER+72+1),A
  LD	  (PROGST),A
  CALL	  EXTINIT
MSIZE: CALL    DXTOP
  JR	  SETTOP
SETTOP: DEC	HL
  LD	  DE,STLOOK-1
  CALL	  CPDEHL
  JR	  C,MSIZE
  LD	  DE,0-50
  LD	  (LSTRAM),HL
  ADD	  HL,DE
  LD	  (STRSPC),HL
  CALL	  CLRPTR
  LD	  HL,(STRSPC)
  LD	  DE,0-17
  ADD	  HL,DE
  LD	  DE,PROGST
  LD	  A,L
  SUB	  E
  LD	  L,A
  LD	  A,H
  SBC	  A,D
  LD	  H,A
  PUSH	  HL
  LD	  HL,SIGNON
  CALL	  PRS
  POP	  HL
  CALL	  PRNTHL
  LD	  HL,BFREE
  CALL	  PRS
  JP	  WARMST
BFREE: defb   " Bytes free.  DOS alone goes back to ampDOS.",CR,LF,0,0
SIGNON: defb   "Z80 BASIC Ver 4.7b",CR,LF
  defb	 "Copyright ",40,"C",41
  defb	 " 1978 by Microsoft",CR,LF,0,0
EXTINIT: LD	 A,47H
  OUT	  (CTCB),A
  LD	  A,CTCBTC
  OUT	  (CTCB),A
  LD	  HL,SBINIT
  LD	  B,9
  LD	  C,DARTBC
  OTIR
  RET
SBINIT: defb   18H
  defb	 04H,44H
  defb	 01H,00H
  defb	 03H,0C1H
  defb	 05H,0E8H
INITST: LD	A,0
  LD	  (BRKFLG),A
  JP	  INIT
	defs DXFCB+342-$
WRKSPC0:
INITAB: JP	WARMST
  JP	  FCERR
  OUT	  (0),A
  RET
  SUB	  0
  LD	  L,A
  LD	  A,H
  SBC	  A,0
  LD	  H,A
  LD	  A,B
  SBC	  A,0
  LD	  B,A
  LD	  A,0
  RET
  defb	 0,0,0
  defb	 035H,04AH,0CAH,099H
  defb	 039H,01CH,076H,098H
  defb	 022H,095H,0B3H,098H
  defb	 00AH,0DDH,047H,098H
  defb	 053H,0D1H,099H,099H
  defb	 00AH,01AH,09FH,098H
  defb	 065H,0BCH,0CDH,098H
  defb	 0D6H,077H,03EH,098H
  defb	 052H,0C7H,04FH,080H
  IN	  A,(0)
  RET
  defb	 1
  defb	 255
  defb	 28
  defb	 0
  defb	 0
  defw	 20
  defw	 20
  defw	 0
  defb	 0
  defb	 0
  JP	  TTYLIN
  JP	  00000h
  JP	  00000h
  JP	  00000h
  defw	 STLOOK
  defw	 -2
  defw	 PROGST+1
INITBE:
  defb	 " Er"
