#!/usr/bin/env python3
"""Make BASIC.BIN: Microsoft (NASCOM) BASIC 4.7 in Grant Searle's Z80 version, as
an ampDOS program (loaded at 8000h like any other).  build.py runs this.

  BAS32K.ASM   Grant Searle's source, unchanged (his dialect)
  SEREXT.ASM   the Serial B extension: SSAVE SLOAD STPRINT DPRINT SLEEP (his dialect)
  DOSEXT.ASM   the ampDOS extension: LOAD SAVE DOS (z80asm)
  FASTFP.ASM   numbers in the program read the quick way (z80asm)
  this file    the patches that hook both into BASIC, the speed patches (Z80 code
               for Searle's 8080-style multiply, divide, shifts, line search,
               variable search and memory move; BASIC_PLAIN=1 leaves them out), the
               size patches (the start-up table and code, JP -> JR),
               then the conversion of BAS32K.ASM + SEREXT.ASM to z80asm, then
               FASTFP.ASM and DOSEXT.ASM on the end

The keywords that give up their places: CLOAD CSAVE (-> SLOAD SSAVE), SCREEN
(-> STPRINT), SET RESET (-> DPRINT SLEEP), NULL MONITOR CLS (-> LOAD SAVE DOS).
PROGRAMS/BASIC/README.md lists every keyword.

usage: mkbasic.py OUTDIR      -> OUTDIR/BASIC.ASM (assembled to find its end: OUTDIR/BASIC.BIN)
"""
import os, re, subprocess, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'tools', 'build'))
from srcdisk import compact

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.abspath(sys.argv[1])
os.makedirs(out, exist_ok=True)
src = open(os.path.join(here, 'BAS32K.ASM'), 'rb').read().decode('latin-1').replace('\r', '')

def ser1(old_re, new, flags=0):         # (the Serial B patches: "new" is a re template)
    global src
    src, n = re.subn(old_re, new, src, count=1, flags=flags)
    assert n == 1, 'patch failed: ' + old_re

def sub1(old_re, new):                  # (the ampDOS patches)
    global src
    src, n = re.subn(old_re, lambda m: m.expand(new), src, count=1)
    assert n == 1, 'patch failed: ' + old_re

# ======== Serial B: hook SEREXT.ASM in
# 1. keyword names (same length, so the table layout is unchanged)
ser1(r"\.BYTE\s+'C'\+80H,\"LOAD\"", ".BYTE   'S'+80H,\"LOAD\"")
ser1(r"\.BYTE\s+'C'\+80H,\"SAVE\"", ".BYTE   'S'+80H,\"SAVE\"")
# 2. dispatch table: the two dummy REM entries between CLEAR and NEW
ser1(r"\.WORD\s+CLEAR\n\s+\.WORD\s+REM\n\s+\.WORD\s+REM\n\s+\.WORD\s+NEW",
     ".WORD   CLEAR\n        .WORD   SLOAD\n        .WORD   SSAVE\n        .WORD   NEW")
# 2b. STPRINT takes over the unused SCREEN token (97h, was a dummy REM)
ser1(r"\.BYTE\s+'S'\+80H,\"CREEN\"", ".BYTE   'S'+80H,\"TPRINT\"")
ser1(r"\.WORD\s+DOKE\n\s+\.WORD\s+REM\n\s+\.WORD\s+LINES",
     ".WORD   DOKE\n        .WORD   STPRINT\n        .WORD   LINES")
# 2b2. DPRINT takes over the unused SET token (9Ch, a graphics stub)
ser1(r"\.BYTE\s+'S'\+80H,\"ET\"", ".BYTE   'D'+80H,\"PRINT\"")
ser1(r"\.WORD\s+PSET\n\s+\.WORD\s+RESET", ".WORD   DPRINT\n        .WORD   RESET")
# 2b3. SLEEP takes over the unused RESET token (9Dh, a graphics stub)
ser1(r"\.BYTE\s+'R'\+80H,\"ESET\"", ".BYTE   'S'+80H,\"LEEP\"")
ser1(r"\.WORD\s+DPRINT\n\s+\.WORD\s+RESET", ".WORD   DPRINT\n        .WORD   SLEEP")
# 2b4. signal external hardware when the user breaks out with Ctrl-C / ESC
ser1(r"BRK\s+LD\s+A,\$FF", "BRK:    CALL    EXTBRK          ; pulse the parallel-port strobe\n        LD      A,$FF")
ser1(r"JR\s+Z,STOP\s+; Break during hold exits prog", "JP      Z,EXTSTP        ; Break during hold exits prog (and signals)")
# 2c. errors must print on the console even if they happen inside STPRINT
ser1(r"ERROR:  CALL    CLREG", "ERROR:  CALL    EXTCLR          ; error text goes to the console\n        CALL    CLREG")
# 3. character input and output now go through the extension
ser1(r"GETINP: RST\s+10H[^\n]*\n", "GETINP: JP      EXTRX           ; input a character (serial B aware)\n")
ser1(r"MONOUT:\s*\n\s+JP\s+\$0008[^\n]*\n", "MONOUT: JP      EXTTX           ; output a char (serial B aware)\n")
# 4. end-of-SSAVE hook at PRNTOK ("Ok" is also reached after errors)
ser1(r"PRNTOK: XOR     A", "PRNTOK: CALL    EXTEND          ; finish an SSAVE if one is running\n        XOR     A")
# 5. cold start: bring up channel B
ser1(r"(\s+LD\s+\(PROGST\),A[^\n]*\n)", r"\1        CALL    EXTINIT         ; set up CTC ch.1 + DART channel B\n")

src = src.rstrip()
assert src.endswith('.end')
src = src[:-4] + open(os.path.join(here, 'SEREXT.ASM')).read() + '\n.end\n'

# ======== ampDOS: hook DOSEXT.ASM in
# ---- keywords: same token numbers, new names and routines
sub1(r"\.BYTE\s+'N'\+80H,\"ULL\"", '.BYTE   \'L\'+80H,"OAD"')
sub1(r"\.BYTE\s+'M'\+80H,\"ONITOR\"", '.BYTE   \'S\'+80H,"AVE"')
sub1(r"\.BYTE\s+'C'\+80H,\"LS\"", '.BYTE   \'D\'+80H,"OS"')
sub1(r"\.WORD\s+NULL\n", ".WORD   DXLOAD\n")
sub1(r"\.WORD\s+MONITR\n", ".WORD   DXSAVE\n")
sub1(r"\.WORD\s+CLS\n", ".WORD   DXDOS\n")
# ---- start: remember the arguments (BASIC name); memory top from the OS, not a RAM scan
sub1(r"STARTB: \n", "STARTB: CALL    DXARG           ; HL = the shell's arguments\n")
sub1(r"(?s)MSIZE:  LD      HL,MEMMSG.*?JP      SETTOP          ; Top of RAM found\n",
     "MSIZE:  CALL    DXTOP           ; HL = the top of the TPA (the OS says)\n"
     "        JP      SETTOP\n")
sub1(r'BFREE:  \.BYTE   " Bytes free",CR,LF,0,0',
     r'BFREE:  .BYTE   " Bytes free.  DOS alone goes back to ampDOS.",CR,LF,0,0')
# ---- output: SAVE (bit 4) into the file; while LOADing (bit 5) nothing is shown
sub1(r"AND\s+0DH\s+; SSAVE, STPRINT or DPRINT active\?\n\s+JR\s+Z,SBCON[^\n]*\n",
     "AND     3DH             ; SSAVE, STPRINT, DPRINT, SAVE or LOAD active?\n"
     "        JR      Z,SBCON         ; no: console only\n"
     "        BIT     4,A\n        JP      NZ,DXTX         ; SAVE: into the file\n"
     "        BIT     5,A\n        JP      NZ,DXQUIET      ; LOAD: the lines are not echoed\n"
     "        LD      A,(IOMODE)\n        AND     0DH\n")
# ---- input: the file (LOAD), then the typed-for-you text (BASIC name), then as before
sub1(r"EXTRX:  LD      A,\(IOMODE\)\n", "EXTRX:  JP      DXRX\nEXTRX2: LD      A,(IOMODE)\n")
sub1(r"SBEOF:  LD      A,\(IOMODE\)\n\s+AND\s+0FDH", "SBEOF:  LD      A,(IOMODE)\n        AND     0DDH")
# ---- end of SAVE (at PRNTOK), and an error during SAVE or LOAD
sub1(r"EXTEND: LD      A,\(IOMODE\)\n",
     "EXTEND: LD      A,(IOMODE)\n        BIT     4,A\n        CALL    NZ,DXFIN        ; SAVE done: close the file\n        LD      A,(IOMODE)\n")
sub1(r"EXTCLR: PUSH    AF\n", "EXTCLR: JP      DXCLR\n        PUSH    AF\n")

PLAIN = os.environ.get('BASIC_PLAIN')   # (=1: without the speed patches, for tests/emu/BASICFP.py)
# ======== speed: Searle's routines are 8080 code; these do the same in Z80 code.
# Every result is the same, bit for bit (checked: tests/emu/BASICFP.py).
def spd1(old_re, new):
    if not PLAIN:
        sub1(old_re, new)

def block(start, end, new):
    if PLAIN:
        return
    """the lines from the one starting with label START up to (not including) the
    one starting with label END become NEW"""
    global src
    i = src.index('\n' + start) + 1
    j = src.index('\n' + end, i) + 1
    src = src[:i] + new + src[j:]

# ---- line input: '@' (kill the line) and '_' (delete a character) are ordinary
# characters, so they can be typed and LOADed; Backspace and Delete still delete
spd1(r"        CP      '@'             ; Is it \"kill line\"\?\n        JP      Z,OTKLN         ; Yes - Kill line\n"
     r"        CP      '_'             ; Is it delete\?\n        JP      Z,DELCHR        ; Yes - Delete character\n", "")

# ---- multiply: the partial product in A:H:L:B instead of in memory, the
# multiplier's byte shifting out of B as the product shifts in (B's old bits
# would only be shifted out), and the 8 steps unrolled.  CDE = the multiplier.
STEP = ''.join(f"""        JR      NC,FMS{i}
        ADD     HL,DE           ; + the multiplier
        ADC     A,C
FMS{i}:   RRA                     ; the product right, with the carry
        RR      H
        RR      L
        RR      B               ; ... and the next bit of the multiplicand out
""" for i in range(8))
block('FPMULT:', 'DIV10:', """FPMULT: CALL    TSTSGN          ; Test sign of FPREG
        RET     Z               ; Return zero if zero
        LD      L,0             ; Flag add exponents
        CALL    ADDEXP          ; Add exponents
        LD      A,(FPREG)       ; the multiplicand's bytes, LSB first
        LD      B,A
        XOR     A
        LD      H,A
        LD      L,A
        CALL    FMUL8
        EX      AF,AF'
        LD      A,(FPREG+1)
        LD      B,A
        EX      AF,AF'
        CALL    FMUL8
        EX      AF,AF'
        LD      A,(FPREG+2)
        LD      B,A
        EX      AF,AF'
        CALL    FMUL8
        LD      C,A             ; the product to CDEB, as BNORM takes it
        LD      D,H
        LD      E,L
        JP      BNORM
POPHRT: POP     HL              ; Restore address of number
        RET

FMUL8:  INC     B               ; a zero byte: the product moves 8 bits right
        DEC     B
        JR      Z,FMULZ
        SRL     B               ; the first bit
""" + STEP + """        RET
FMULZ:  LD      B,L
        LD      L,H
        LD      H,A
        XOR     A
        RET

""")

# ---- divide: the same restoring division, in registers: B:H:L = the
# remainder, C:D:E = the divisor, C':D':E' = the quotient; the remainder's 25th
# bit (Searle's DIV4) is the carry out of its doubling.  DIVSUP is not used.
block('        LD      A,(HL)          ; Get MSB of dividend', 'ADDEXP:', """        LD      A,C             ; the dividend to B:H:L
        EX      DE,HL
        LD      B,A
        LD      DE,(FPREG)      ; the divisor to C:D:E
        LD      A,(FPREG+2)
        LD      C,A
        EXX
        XOR     A
        LD      C,A
        LD      D,A
        LD      E,A
        EXX
DIVLP:  OR      A               ; remainder - divisor
        SBC     HL,DE
        LD      A,B
        SBC     A,C
        JR      C,DIVNO         ; a borrow: it did not go
DIVYES: LD      B,A             ; it went: a 1 bit
        EXX
        BIT     7,C             ; the quotient full: done (this bit rounds)
        SCF
        JR      NZ,DIVFIN
        RL      E
        RL      D
        RL      C
        EXX
DIVSH:  ADD     HL,HL           ; the remainder doubled
        RL      B
        JR      NC,DIVLP
        OR      A               ; its 25th bit set: the subtraction goes, whatever
        SBC     HL,DE           ; the borrow (Searle's DIV4 pays it)
        LD      A,B
        SBC     A,C
        JR      DIVYES
DIVNO:  ADD     HL,DE           ; the remainder back: a 0 bit
        EXX
        BIT     7,C
        JR      NZ,DIVFN0
        SLA     E
        RL      D
        RL      C
        LD      A,C             ; still 0: a leading zero, the exponent down instead
        OR      D
        OR      E
        EXX
        JR      NZ,DIVSH
        PUSH    HL
        LD      HL,FPEXP
        DEC     (HL)
        POP     HL
        JR      NZ,DIVSH
        JP      OVERR           ; Overflow error
DIVFN0: OR      A
DIVFIN: LD      A,0
        RRA                     ; A bit 7 = the rounding bit
        PUSH    BC
        PUSH    DE
        EXX
        POP     DE              ; the quotient to CDE
        POP     BC
        JP      RONDB

""")
spd1(r"(INC\s+\(HL\)\s+; Add 2 to exponent to adjust\n\s+INC\s+\(HL\)\n)\s+DEC\s+HL\s+; Point to MSB\n", r"\1")

# ---- the shifts in add and normalise: Z80 rotates instead of through A
block('SHRLP:', 'UNITY:', """SHRLP:  XOR     A               ; Flag for all done
        DEC     L               ; All shifting done?
        RET     Z               ; Yes - Return
        LD      A,C             ; Get MSB
SHRT1:  RRA                     ; Shift it right
        LD      C,A             ; Re-save
        RR      D
        RR      E
        RR      B
        JP      SHRLP           ; More bits to do

""")
block('NORMAL:', 'PNORM:', """NORMAL: DEC     B               ; Count bits
        ADD     HL,HL           ; Shift HL left
        RL      D
        RL      C
""")

# ---- variables: the same search, a tighter loop
block('FNDVAR:', 'CFEVAL:', """FNDVAR: LD      A,L             ; End of variable list table?
        SUB     E
        JR      NZ,FNDV1
        LD      A,H
        SUB     D
        JP      Z,CFEVAL        ; Yes - Called from EVAL?
FNDV1:  LD      A,C             ; Get second byte of name
        SUB     (HL)            ; Compare with name in list
        INC     HL
        JR      NZ,FNDV2        ; Different - Find another
        LD      A,B             ; Get first byte of name
        SUB     (HL)            ; Compare with name in list
FNTHR:  INC     HL              ; Move on to LSB of value
        JP      Z,RETADR        ; Found - Return address
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        JP      FNDVAR
FNDV2:  INC     HL
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        JP      FNDVAR

""")

# ---- GOTO, GOSUB, RESTORE: the line search, the line number compared in place
# (the same BC, HL, A and flags out as Searle's loop)
block('SRCHLP:', 'NEW:', """SRCHLP: LD      B,H             ; BC = Address to look at
        LD      C,L
        LD      A,(HL)          ; Get address of next line
        INC     HL
        OR      (HL)            ; End of program found?
        DEC     HL
        RET     Z               ; Yes - Line not found
        INC     HL
        INC     HL
        INC     HL
        LD      A,(HL)          ; MSB of the line number
        CP      D
        JR      NZ,SRCHDF
        DEC     HL
        LD      A,(HL)          ; LSB
        CP      E
        JR      NZ,SRCHDF
        LD      H,B             ; found: HL = the next line, Z and C
        LD      L,C
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        SCF
        RET
SRCHDF: LD      H,B             ; HL = the next line
        LD      L,C
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        JR      C,SRCHLP        ; this one is lower: on
        RET                     ; higher: not found (NC, NZ), BC = where it goes

""")

# ---- moving memory up (a new line, a new variable, strings): LDDR, with the
# registers left as Searle's loop leaves them
block('MOVLP:', 'CHKSTK:', """MOVLP:  PUSH    DE              ; HL down to DE goes to BC down
        PUSH    HL
        OR      A
        SBC     HL,DE
        INC     HL
        EX      (SP),HL         ; (the count)
        LD      D,B
        LD      E,C
        POP     BC
        LDDR
        INC     HL              ; HL = the last byte moved, BC = where it went
        INC     DE
        LD      B,D
        LD      C,E
        POP     DE
        LD      A,(HL)
        CP      A               ; (Z, NC)
        RET

""")

# ---- numbers in the program: a whole number 1 .. 65535 the quick way (FASTFP.ASM)
spd1(r"CNVNUM: CALL    RESZER", "CNVNUM: CALL    FASTN           ; (a whole number: it does it all)\n        CALL    RESZER")
spd1(r"ENDCON: JP      NZ,SCALMI       ; More to do\n", "ENDCON: JP      NZ,SCALMI       ; More to do\nENDCN2:\n")

# ======== size: what only the start needs is not kept
def cut(start, end):
    """the lines from label START up to (not including) the line starting END: out of src"""
    global src
    i = src.index('\n' + start) + 1
    j = src.index('\n' + end, i) + 1
    text, src = src[i:j], src[:i] + src[j:]
    return text

initab = startup = ''
if not PLAIN:
    # ---- the start-up table (a ROM's): copied to WRKSPC at the start.  Now it is
    # assembled at the end, as the first bytes of WRKSPC itself: nothing to copy.
    # (The copy took 3 bytes more, the start of " Error": they come along.)
    initab = cut('INITAB:', 'ERRMSG:') + '        .BYTE   " Er"           ; (as the copy left them)\n'
    # ---- the start-up code and its messages: they go where DOSEXT's file buffers
    # are (DXFCB), which nothing uses before the first LOAD, SAVE or DOS
    startup = cut('CSTART:', 'WARMST:')
    startup = re.sub(r"(?s)INIT:   LD      DE,INITAB.*?LD      SP,HL[^\n]*\n",
                     "INIT:   LD      HL,WRKSPC+INITBE-INITAB+3 ; (the stack, where the copy left it)\n"
                     "        LD      SP,HL\n", startup, count=1)
    i, j = startup.index('TSTMEM:'), startup.index('SETTOP:')      # (the RAM test: ampDOS says)
    startup = startup[:i] + startup[j:]
    msgs = cut('BFREE:', 'FNCTAB:')
    msgs = re.sub(r'MEMMSG:[^\n]*\n', '', msgs)                    # ("Memory top": not asked)
    startup += ('        JP      WARMST          ; (it went on into WARMST)\n' + msgs
                + cut('EXTINIT:', '; --- output') + cut('INITST:', 'ARETN:'))
    cut('JJUMP1:', 'MONOUT:')                                       # (never used)
    assert 'INITAB' not in src.replace('INITAB-', '') and 'MEMMSG' not in src


# ======== Searle's dialect -> z80asm
def convert(text, org, wrk):
    def fixnums(s):                     # $1234 -> 01234h (outside quotes)
        parts = re.split(r'("[^"]*"|\'[^\']*\')', s)
        for i in range(0, len(parts), 2):
            parts[i] = re.sub(r'\$([0-9A-Fa-f]+)', lambda m: '0' + m.group(1) + 'h', parts[i])
        return ''.join(parts)
    res = []
    for ln in text.split('\n'):
        if ln.strip().lower() == '.end':
            continue
        code, cm, inq = ln, '', None    # split off the comment (not inside quotes)
        for i, ch in enumerate(ln):
            if inq:
                if ch == inq:
                    inq = None
            elif ch in '"\'':
                inq = ch
            elif ch == ';':
                code, cm = ln[:i], ln[i:]
                break
        c = code.rstrip()
        if not c.strip():
            res.append(cm)
            continue
        label, rest = None, c.strip()
        if c[0] not in ' \t':
            m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)(:?)\s*(.*)$', c)
            label, rest = m.group(1), m.group(3)
        rest = re.sub(r'^\.EQU\b', 'equ', rest, flags=re.I)
        rest = re.sub(r'^\.ORG\b', 'org', rest, flags=re.I)
        rest = re.sub(r'^\.BYTE\b', 'defb', rest, flags=re.I)
        rest = re.sub(r'^\.WORD\b', 'defw', rest, flags=re.I)
        rest = re.sub(r"'(.)'\s*\+\s*80H", lambda m: str(ord(m.group(1)) + 0x80), rest, flags=re.I)
        rest = fixnums(rest)
        if label == 'WRKSPC':
            rest = 'equ ' + wrk
        if rest.lower().startswith('org'):
            rest = 'org ' + org
        res.append((f'{label}: {rest} {cm}' if label else f'  {rest} {cm}').rstrip())
    return '\n'.join(res) + '\n'

conv = convert(src, '8000h', 'WRKSPC0')
conv_start = convert(startup, '8000h', 'WRKSPC0')
conv_init = convert(initab, '8000h', 'WRKSPC0')
ext = (('' if PLAIN else open(os.path.join(here, 'FASTFP.ASM')).read())   # (DOSEXT.ASM ends where BASIC's RAM starts)
       + open(os.path.join(here, 'DOSEXT.ASM')).read())

# BASIC's variables (WRKSPC) start right after the code.  z80asm reads a forward
# label in an EQU as 0, so: assemble once to find where the code ends, then again
# with that address written in (the code is the same size either way).
def bare(text):
    """the comments go, but for the first block (the copyright notices): BASIC.ASM
    goes on the source disk, and with them it would not fit (146 KB -> 66 KB)"""
    out, head = [], True
    for l in text.split('\n'):
        s = l.strip()
        if head and (not s or s.startswith(';') or s.lower().startswith('include')):
            out.append(l)
            continue
        head, q, cut = False, None, len(l)
        for i, c in enumerate(l):
            if q:
                if c == q:
                    q = None
            elif c in '"\'' and not l[:i].lower().endswith('af,af'):
                q = c
            elif c == ';':
                cut = i
                break
        l = l[:cut].rstrip()
        if l:
            out.append(l)
    return '\n'.join(out) + '\n'

# ---- JP -> JR wherever the target is near (2 bytes instead of 3).  Not: right
# after a skip byte (".BYTE 3EH" swallows the next instruction: its length
# counts), in the start-up table (WRKSPC0 on: its offsets count), the entry
# jumps, or an unconditional JP in the busiest routines (a JR is 2 T-states slower
# when it jumps; a conditional one is 3 faster when it does not)
HOT = set("""GETCHR RUNCNT EXCUTE IFJMP ONJMP FNDVAR FNDV1 FNDV2 FNTHR SRCHLP SRCHDF EVAL
    EVAL1 EVAL2 EVAL3 OPRND RLTLP NOTAMP FOPRND STKTHS CONVAR GETVAR GTFNAM SVNAM2
    ENDNAM CHARTY NOTSTR NSCFOR FPADD NOSWAP MINCDE CONPOS BNORM BNRMLP NORMAL PNORM
    RONDUP RONDB PLUCDE SCALE SCALLP SHRITE SHRLP SHRT1 LET LETNUM LETSTR NEXT NEXT1
    KILFOR FOR LOADFP STAKFP FPBCDE BCDEFP CMPNUM TSTSGN ADDEXP SIGNS MLSP10 ADDIG
    MANLP CNVNUM ASCTFP FPMULT FMUL8 DVBCDE DIVLP DIVYES DIVSH DIVNO MOVLP TSTBRK""".split())
JPLINE = re.compile(r'^(\w+:)?(\s*)(JP)(\s+)((?:Z|NZ|C|NC),)?([A-Za-z_]\w*)\s*$', re.I)

def jrify(text, wrk):
    lines = text.split('\n')
    labels = {m.group(1) for m in (re.match(r'^(\w+):(?!\s*equ\b)', l, re.I) for l in lines) if m}
    for _ in range(6):
        marked, cur, prev, stop = [], None, '', False
        for n, l in enumerate(lines):
            m = re.match(r'^(\w+):', l)
            if m:
                cur = m.group(1)
                stop = stop or cur == 'WRKSPC0'
            j = JPLINE.match(l)
            if (j and not stop and cur not in ('COLD', 'WARM') and j.group(6) in labels
                    and not re.match(r'^(\w+:)?\s*(defb|\.BYTE)\b', prev, re.I)
                    and not (cur in HOT and not j.group(5))):
                marked.append(n)
            if l.strip():
                prev = l
        tmp = os.path.join(out, 'JRTMP')
        open(tmp + '.ASM', 'w').write('\n'.join(
            ('JRQ%d:\n' % n if n in marked else '') + l for n, l in enumerate(lines)))
        subprocess.run(['z80asm', '-o', tmp + '.BIN', '-L' + tmp + '.LBL', tmp + '.ASM'],
                       check=True, capture_output=True)
        at = {}
        for line in open(tmp + '.LBL'):
            m = re.match(r'(\w+):\s+equ \$([0-9a-f]+)', line)
            if m:
                at[m.group(1)] = int(m.group(2), 16)
        changed = 0
        for n in marked:
            j = JPLINE.match(lines[n])
            d = at[j.group(6)] - (at['JRQ%d' % n] + 2)
            if -128 <= d <= 127:
                lines[n] = (j.group(1) or '') + j.group(2) + 'JR' + j.group(4) + (j.group(5) or '') + j.group(6)
                changed += 1
        if not changed:
            break
    for e in ('.ASM', '.BIN', '.LBL'):
        os.remove(tmp + e)
    return '\n'.join(lines)

def make(wrk):
    text = ('; made by PROGRAMS/BASIC/mkbasic.py: do not edit (edit the files in PROGRAMS/BASIC/)\n'
            '        include "KERNEL/INC/OS.INC"\n' + conv.replace('equ WRKSPC0', 'equ 0%04Xh' % wrk) + '\n' + ext
            + conv_start + '\tdefs DXFCB+342-$\t; (the buffers: 16 + 70 + 256)\nWRKSPC0:\n' + conv_init)
    text = bare(compact(text))
    if not PLAIN:
        text = jrify(text, wrk)
    open(os.path.join(out, 'BASIC.ASM'), 'w', newline='').write(compact(text))
    lbl = os.path.join(out, 'BASIC.LBL')
    subprocess.run(['z80asm', '-o', os.path.join(out, 'BASIC.BIN'), '-L' + lbl,
                    os.path.join(out, 'BASIC.ASM')], check=True, capture_output=True)
    for line in open(lbl):
        if line.startswith('WRKSPC0:'):
            return int(line.split('$')[1], 16)
first = make(0xA000)
for _ in range(4):                      # (the JRs can move the end: until it stands still)
    again = make(first)
    if again == first:
        break
    first = again
assert make(first) == first
print('BASIC: code 8000h-%04Xh, its variables from %04Xh' % (first - 1, first))
