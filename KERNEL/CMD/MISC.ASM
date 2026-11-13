; ==========================================================================
; MISC.ASM - small commands: CLEAR, TOUCH, PWD.
;
;   CLEAR (or CLS)   the terminal's own clear (SCREEN CLEAR), or by scrolling:
;                    a screen's worth of empty lines (SCREEN ROWS),
;                    then the prompt on the bottom line.  That works on any
;                    terminal, also one that only ever adds lines at the bottom
;                    (control sequences such as ANSI ESC [2J are not understood
;                    by every terminal).
;   TOUCH name       a new, empty file; if the file exists, it only gets
;                    today's date (its contents are left alone)
;   PWD              where we are (the same as CD without an argument)
; ==========================================================================

cmd_clear:
	xor a			; the terminal's clear, or empty lines (scr_do) ...
	call scr_do
	ld a,1			; ... and no extra empty line before the prompt
	ld (sh_nonl),a
	ret

cmd_pwd:
	call sh_pwd
	jp con_crlf

cmd_touch:
	call sh_open1
	ret c
	push hl
	call fs_name83
	jr c,ct_err
	call dir_find
	jr nc,ct_old
	cp FS_ENOTF
	jr nz,ct_err
	pop hl			; new: create it, close it
	ld ix,sh_fcb2
	call f_create
	jp c,sh_err
	call f_close
	jp c,sh_err
	ret
ct_old: ld de,DE_TIME		; there: only a new time and date
	add hl,de
	ld de,(fs_ftime)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld de,(fs_fdate)
	ld (hl),e
	inc hl
	ld (hl),d
	call dir_put
	jr c,ct_err
	call fs_flush
	jr c,ct_err
	pop hl
	ret
ct_err: pop hl
	jp sh_err
