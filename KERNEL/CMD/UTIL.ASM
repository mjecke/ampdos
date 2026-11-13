; ==========================================================================
; UTIL.ASM - small commands:
;   SLEEP s[.mmm]   wait that many seconds, to the millisecond (Esc stops it)
;   TRUE, FALSE     do nothing, with the status success / failure
;   WC name ...     lines, words and bytes of each file
;   ID [B]          the ID jumpers (port 29h): in hex, or with B in binary
;   MIRROR [ON|OFF] copy the console to Serial B too (for a log on the PC), or not
;   GO hhhh [args]  call that address (exactly 4 hex digits), HL = the args;
;                   RET comes back to the prompt, as from a program
; The status: every command starts with 0 (success); sh_fail makes it 1.
; Errors (sh_err), a missing argument and an unknown command fail too.
; IF ERRORLEVEL n tests it (the status of the command before the IF).
; ==========================================================================

sh_fail:			; the command now running has failed.  Keeps all
	push af
	ld a,1
	ld (sh_status),a
	pop af
	ret

sh_usage:			; HL = a message: it is a failure, say it (CF)
	call sh_fail
	call con_puts
	scf
	ret

sh_yes: 			; HL = a question: ask it.  Z = the answer is Y
	call con_puts
	call con_getc
	call con_putc
	call con_crlf
	and 0DFh
	cp 'Y'
	ret

sh_colsp:			; print ": "
	ld a,':'
	call con_putc
	ld a,' '
	jp con_putc

sh_upper:			; A in upper case
	cp 'a'
	ret c
	cp 'z'+1
	ret nc
	sub 20h
	ret

cmd_true:			; TRUE: success (as every command starts)
	ret

cmd_false:			; FALSE: failure
	jr sh_fail

; ---------------------------------------------------------------- numbers
cu_num: 			; HL = decimal digits -> DE (0..65535), HL past them.
	ld de,0 		; CF = no digit there
	ld a,(hl)
	sub '0'
	cp 10
	ccf
	ret c
cun_1:	ld a,(hl)
	sub '0'
	cp 10
	ccf
	ccf
	ret nc			; (NC: done)
	inc hl
	push hl
	ld h,d			; DE = DE * 10 + digit
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
	jr cun_1

; ---------------------------------------------------------------- SLEEP
; SLEEP 1.892 waits 1892 ms.  More than three decimals are rounded to the
; millisecond.  Up to 65535 seconds.  The time comes from CTC channel 2 as a
; timer: 4 MHz / 16 = 250 kHz, so 250 counts are 1 ms.  The counter is polled:
; when its count goes up it has just reloaded, and one more millisecond is over
; (the time between polls does not add up, so there is no drift).

cmd_sleep:
	call sh_need1
	ret c
	call cu_num		; the seconds (none: ".5" is half a second)
	push de
	ld de,0 		; then up to 3 decimals: the milliseconds
	ld a,(hl)
	cp '.'
	jr nz,csl_3
	inc hl
	ld b,3
csl_1:	push hl 		; DE = DE * 10 (+ the digit, if there is one)
	ld h,d
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	add hl,hl
	ex de,hl
	pop hl
	ld a,(hl)
	sub '0'
	cp 10
	jr nc,csl_2
	inc hl
	add a,e
	ld e,a
	jr nc,csl_2
	inc d
csl_2:	djnz csl_1
	ld a,(hl)		; a fourth decimal: 5 or more rounds up
	sub '0'
	cp 10
	jr nc,csl_3
	cp 5
	jr c,csl_s
	inc de
csl_s:	inc hl			; (the rest of the decimals do not count)
	ld a,(hl)
	sub '0'
	cp 10
	jr c,csl_s
csl_3:	ld a,(hl)		; then nothing more may follow
	or a
	jr z,csl_4
	cp ' '
	jr z,csl_4
	pop de
	call sh_fail
	ld hl,m_cu_sleep
	jp con_puts
csl_4:	pop hl			; HL = seconds, DE = milliseconds (0..1000)
	push de
csl_5:	ld a,h
	or l
	jr z,csl_6
	push hl
	ld de,1000
	call mach_wait
	pop hl
	jr c,csl_esc
	dec hl
	jr csl_5
csl_6:	pop de
	call mach_wait
	ret nc
	jp sh_fail		; (Esc: stopped early, a failure)
csl_esc:
	pop de
	jp sh_fail

m_cu_sleep: defm "SLEEP seconds, e.g. SLEEP 2 or SLEEP 1.892"
	defb 13,10,0

; ---------------------------------------------------------------- WC
cmd_wc: 			; WC name [name ...]
	call sh_need1
	ret c
cw_1:	call sh_skipsp
	ld a,(hl)
	or a
	ret z
	ld (sh_args),hl 	; this name ...
	call sh_skipword
	ld a,(hl)
	or a
	jr z,cw_2
	ld (hl),0
	inc hl
cw_2:	ld (sh_wcn),hl		; ... and where the next one starts
	call cw_file
	ld hl,(sh_wcn)
	jr cw_1

cw_file:			; "  lines   words   bytes  NAME" for (sh_args)
	ld hl,WCLINES
	ld b,13 		; the three counts and WCIN
cwf_0:	ld (hl),0
	inc hl
	djnz cwf_0
	call ct_open
	ret c
cwf_1:	call ct_piece		; BC bytes at sh_buf
	ret c
	ld a,b
	or c
	jr z,cwf_show
	ld hl,(sh_buf)
cwf_2:	ld a,(hl)
	push hl
	ld hl,WCBYTES
	call cw_inc
	cp 10
	jr nz,cwf_3
	ld hl,WCLINES
	call cw_inc
cwf_3:	cp ' '+1		; a space, tab, CR, LF ...: between words
	ld hl,WCIN
	jr nc,cwf_4
	ld (hl),0
	jr cwf_5
cwf_4:	ld a,(hl)		; the first letter of a word
	ld (hl),1
	or a
	jr nz,cwf_5
	ld hl,WCWORDS
	call cw_inc
cwf_5:	pop hl
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,cwf_2
	jr cwf_1
cwf_show:
	ld b,8
	ld hl,WCLINES
	call con_dec32
	ld hl,WCWORDS
	call con_dec32
	ld hl,WCBYTES
	call con_dec32
	ld a,' '
	call con_putc
	call con_putc
	ld hl,(sh_args)
	call con_puts
	jp con_crlf

cw_inc: inc (hl)		; the 4-byte number at HL + 1.  Keeps A
	ret nz
	inc hl
	inc (hl)
	ret nz
	inc hl
	inc (hl)
	ret nz
	inc hl
	inc (hl)
	ret

; ---------------------------------------------------------------- ID
cmd_id: 			; ID: "A5"   ID B: "10100101"
	call mach_id
	ld b,a
	ld hl,(sh_args)
	ld a,(hl)
	and 0DFh
	cp 'B'
	ld a,b
	jr z,cid_b
	call con_hex8
	jp con_crlf
cid_b:	ld c,8			; the bits, 7 first
cid_1:	rlc b
	ld a,'0'
	adc a,0
	call con_putc
	dec c
	jr nz,cid_1
	jp con_crlf

; ---------------------------------------------------------------- GO
cmd_go: 			; GO hhhh [args]
	call sh_noexec		; (not from BASIC: it could land anywhere)
	ret c
	ld hl,(sh_args)
	call cu_hex4		; DE = the address
	jr c,cgo_bad
	call sh_skipsp
	push hl
	push de
	call fs_flush		; (the disk safe first)
	pop de
	pop hl			; HL = the arguments, as for a program
	ld bc,sh_cleanup	; RET there makes the OS whole again, then the prompt
	push bc
	push de
	ret			; = call (DE)
cgo_bad:
	call sh_fail
	ld hl,m_cu_go
	jp con_puts

cu_hex4:			; HL = exactly 4 hex digits, then the end or a space
	ld de,0 		; -> DE, HL past them.  CF = not that
	ld b,4
ch4_1:	ld a,(hl)
	sub '0'
	cp 10
	jr c,ch4_2
	and 0DFh		; a-f as A-F
	sub 7
	cp 10
	ccf
	ret c
	cp 16
	ccf
	ret c
ch4_2:	inc hl
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	or l
	ld l,a
	ex de,hl
	djnz ch4_1
	ld a,(hl)
	or a
	ret z
	cp ' '
	ret z
	scf
	ret

m_cu_go:    defm "GO hhhh: four hex digits, e.g. GO 8000"
	defb 13,10,0

; ---------------------------------------------------------------- MIRROR
cmd_mirror:			; MIRROR ON / OFF; alone: say which
	ld hl,(sh_args)
	ld a,(hl)
	or a
	jr z,cmi_show
	push hl
	ld de,m_bt_on
	call bt_word
	pop hl
	ld a,1
	jr z,cmi_set
	ld de,m_bt_off
	call bt_word
	ld a,0
	jr z,cmi_set
	call sh_fail
	ld hl,m_cu_mir
	jp con_puts
cmi_set:
	ld (con_mirror),a
cmi_show:
	ld hl,m_cu_mir1 	; "MIRROR is on" / "... off"
	call con_puts
	ld a,(con_mirror)
	or a
	ld hl,m_bt_on
	jr nz,cmi_1
	ld hl,m_bt_off
cmi_1:	call con_puts
	ld hl,m_cu_mir2
	jp con_puts

m_cu_mir:   defm "MIRROR ON or MIRROR OFF"
	defb 13,10,0
m_cu_mir1:  defm "MIRROR (console to Serial B) is "
	defb 0
m_cu_mir2:  defb 13,10,0
