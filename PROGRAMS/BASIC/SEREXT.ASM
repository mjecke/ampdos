; ===========================================================================
; SEREXT.ASM - BASIC's Serial B extension, in the same assembler dialect as 
; BAS32K.ASM is in. 
; (mkbasic.py patches BAS32K.ASM to call it, appends it, then converts the
; whole to z80asm). 
; SSAVE / SLOAD streams out list / loads into list a prog over Serial B.
; STPRINT is just basic PRINT but it prints silently to Serial B
; DPRINT is a 'dual' PRINT to Serial B and to screen
; SLEEP is a sleep in n seconds (decimals are milliseconds)
; also added and a pulse on the parallel port's strobe line when a program is 
; stopped with Ctrl-C (for a trigger for some future external hardware)
; ============================================================================

IOMODE  .EQU    NMIFLG          ; bit flags: 01 = SSAVE (LIST to B), 02 = SLOAD (input from B), 04 = STPRINT (PRINT to B), 08 = DPRINT (PRINT to both)
OLDLN   .EQU    CHKSUM          ; saves the user's LINES setting during SSAVE
DARTAD  .EQU    80H
DARTAC  .EQU    84H
DARTBD  .EQU    88H
DARTBC  .EQU    8CH
CTCB    .EQU    50H             ; CTC channel 1 -- clock DART B
CTCBTC  .EQU    13              ; same divisor as channel A: 9615 baud
BRKSET  .EQU    02H             ; parallel port strobe SET(pulse start on break)
BRKCLR  .EQU    03H             ; parallel port strobe CLEAR (pulse end)
CTCS    .EQU    60H             ; CTC channel 2: SLEEP timer 
EOFCH   .EQU    1AH             ; Ctrl-Z ends a transfer

EXTINIT: LD      A,47H           ; counter mode, TC follows, reset
        OUT     (CTCB),A
        LD      A,CTCBTC
        OUT     (CTCB),A
        LD      HL,SBINIT
        LD      B,9
        LD      C,DARTBC
        OTIR
        RET
SBINIT: .BYTE   18H             ; WR0: channel reset
        .BYTE   04H,44H         ; WR4: x16, 1 stop, no parity
        .BYTE   01H,00H         ; WR1: no interrupts
        .BYTE   03H,0C1H        ; WR3: Rx 8 bits, enabled
        .BYTE   05H,0E8H        ; WR5: DTR on, Tx 8 bits, Tx on, RTS OFF

; --- output: console, serial B, or both (see IOMODE bits)
EXTTX:  PUSH    AF
        LD      A,(IOMODE)
        AND     0DH             ; SSAVE, STPRINT or DPRINT active?
        JR      Z,SBCON         ; no: console only
        AND     08H             ; DPRINT?
        JR      NZ,SBTEE
        POP     AF              ; SSAVE / STPRINT: serial B only
SBTX:   PUSH    AF
SBTX2:  IN      A,(DARTBC)
        BIT     2,A             ; Tx buffer empty?
        JR      Z,SBTX2
        POP     AF
        OUT     (DARTBD),A
        RET
SBCON:  POP     AF
        JP      0008H           ; console (ROM stub TXA)
SBTEE:  POP     AF              ; DPRINT: serial B first, then the console
        CALL    SBTX            ; (both lines then shift out in parallel)
        JP      0008H

; --- input: console unless SLOAD is running
EXTRX:  LD      A,(IOMODE)
        AND     02H             ; SLOAD active?
        JR      NZ,SBRX
        RST     10H             ; console
        RET
SBRX:   CALL    RTSON           ; tell the sender we are ready
SBRX1:  IN      A,(DARTAC)      ; any console key aborts
        BIT     0,A
        JR      NZ,SBABRT
        IN      A,(DARTBC)
        BIT     0,A             ; char waiting on B?
        JR      Z,SBRX1
        IN      A,(DARTBD)
        CP      EOFCH
        JR      Z,SBEOF
        CP      0AH             ; ignore LF so CRLF files load
        JR      Z,SBRX1
        CP      0DH
        RET     NZ
        JP      RTSOFF          ; end of line: hold sender off while BASIC works
SBABRT: IN      A,(DARTAD)      ; discard the key
SBEOF:  LD      A,(IOMODE)
        AND     0FDH
        LD      (IOMODE),A      ; back to console input
        CALL    RTSOFF
        PUSH    HL              ; TTYLIN keeps its buffer pointer in HL
        LD      HL,SBOK         ; BASIC stays silent after an empty line, so say so
SBMSG:  LD      A,(HL)
        OR      A
        JR      Z,SBMSGE
        RST     08H
        INC     HL
        JR      SBMSG
SBMSGE: POP     HL
        LD      A,0DH           ; finish the line in progress
        RET
SBOK:   .BYTE   13,10,"Ok",13,10,0

RTSON:  PUSH    AF
        LD      A,05H
        OUT     (DARTBC),A
        LD      A,0EAH
        OUT     (DARTBC),A
        POP     AF
        RET
RTSOFF: PUSH    AF
        LD      A,05H
        OUT     (DARTBC),A
        LD      A,0E8H
        OUT     (DARTBC),A
        POP     AF
        RET

; --- called at PRNTOK: if an SSAVE just finished, terminate the file
EXTEND: LD      A,(IOMODE)
        AND     0F3H            ; an STPRINT/DPRINT can never outlive its statement
        LD      (IOMODE),A
        AND     01H             ; was an SSAVE running?
        RET     Z
        LD      A,0DH
        CALL    SBTX
        LD      A,0AH
        CALL    SBTX
        LD      A,EOFCH
        CALL    SBTX
        LD      A,(IOMODE)
        AND     0FEH
        LD      (IOMODE),A
        LD      HL,(OLDLN)      ; restore the user's LINES setting
        LD      (LINESN),HL
        LD      (LINESC),HL
        RET

; --- called at ERROR: drop STPRINT redirection so the message shows on screen
EXTCLR: PUSH    AF
        LD      A,(IOMODE)
        AND     0F3H
        LD      (IOMODE),A
        POP     AF
        RET

; --- SSAVE : send the program as text to serial B
SSAVE:  RET     NZ              ; nothing may follow
        PUSH    HL
        LD      HL,(LINESN)
        LD      (OLDLN),HL
        LD      HL,7FFFH        ; no 20-line pause while saving
        LD      (LINESN),HL
        LD      (LINESC),HL
        POP     HL
        LD      A,(IOMODE)
        OR      01H
        LD      (IOMODE),A
        JP      LIST

; --- SLOAD : NEW, then take program text from serial B until Ctrl-Z
SLOAD:  RET     NZ
        CALL    CLRPTR          ; same as NEW
        LD      A,(IOMODE)
        OR      02H
        LD      (IOMODE),A
        JP      PRNTOK

; --- STPRINT : exactly PRINT, but the text goes out of serial B, not the screen
;     (entered like PRINT: HL = code pointer, Z set if nothing follows)
STPRINT: PUSH   AF
        LD      A,(IOMODE)
        OR      04H
        LD      (IOMODE),A
        POP     AF
        CALL    PRINT
        PUSH    AF
        LD      A,(IOMODE)
        AND     0FBH
        LD      (IOMODE),A
        POP     AF
        RET

; --- DPRINT : exactly PRINT, but the text goes to the screen AND serial B
DPRINT: PUSH    AF
        LD      A,(IOMODE)
        OR      08H
        LD      (IOMODE),A
        POP     AF
        CALL    PRINT
        PUSH    AF
        LD      A,(IOMODE)
        AND     0F7H
        LD      (IOMODE),A
        POP     AF
        RET

; --- SLEEP n : wait n milliseconds (n = 0..65535, any numeric expression)
;     CTC channel 2 runs in timer mode: 4 MHz / 16 = 250 kHz, 250 counts = 1 ms.
;     The down-counter is polled; a reading that goes UP means it reloaded,
;     i.e. exactly one more millisecond has passed (no drift, no BASIC overhead).
SLEEP:  CALL    GETNUM          ; evaluate the millisecond count
        CALL    DEPINT          ; DE = 0..65535 (negative gives ?FC Error)
        PUSH    HL              ; keep the text pointer
        LD      A,D
        OR      E
        JR      Z,SLDONE        ; SLEEP 0 does nothing
        LD      A,07H           ; timer mode, /16, auto start, TC follows, reset
        OUT     (CTCS),A
        LD      A,250           ; 250 x 4 us = 1 ms
        OUT     (CTCS),A        ; the timer starts now
        LD      B,10            ; let it get going (about 30 us)
SLWT:   DJNZ    SLWT
        IN      A,(CTCS)
        LD      B,A             ; previous reading
SLLOOP: IN      A,(CTCS)
        CP      B               ; the count normally falls ...
        LD      B,A
        JR      C,SLLOOP        ; ... so a lower reading = same millisecond
        JR      Z,SLLOOP
        PUSH    DE              ; count rose: reloaded, one more ms is over
        CALL    TSTBRK          ; Ctrl-C / ESC break, Ctrl-S pause
        POP     DE
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,SLLOOP
SLDONE: POP     HL
        RET

; --- Ctrl-C / ESC break: pulse the parallel-port strobe line (about 0.8 ms)
;     so external hardware knows the program was interrupted.  Flags are
;     preserved because BRK / STOP test Z right after we return.
EXTBRK: PUSH    AF
        PUSH    BC
        XOR     A
        OUT     (BRKSET),A      ; strobe line: set (value is ignored)
        LD      B,0             ; 256 passes of DJNZ = about 0.8 ms at 4 MHz
EXTBL:  DJNZ    EXTBL
        OUT     (BRKCLR),A      ; strobe line: clear
        POP     BC
        POP     AF
        RET
EXTSTP: CALL    EXTBRK          ; second Ctrl-C while paused with Ctrl-S
        JP      STOP
