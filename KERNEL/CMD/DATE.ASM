; ==========================================================================
; DATE.ASM - DATE: show and set today's date (new files are stamped with it).
;
;   DATE              show it, ask for a new one (Return keeps it)
;   DATE 2026-11-05   set it
; There is no clock: the date starts at SH_DEFDATE (the day the OS was built:
; build.py writes GEN/BLDDATE.INC) at every start, and the
; shell asks for it once at start (sh_askdate).  Written yyyy-mm-dd; / and .
; work as separators too, and single-digit months and days are fine.
; ==========================================================================

	include "GEN/BLDDATE.INC"	; BUILD_Y/M/D: the day of the build (build.py)
SH_DEFDATE: equ ((BUILD_Y-1980) << 9) | (BUILD_M << 5) | BUILD_D

cmd_date:
	ld hl,(sh_args)
	ld a,(hl)
	or a
	jr z,sh_askdate
	call sh_setdate
	ret nc
	ld hl,m_dt_bad
	jp con_puts

sh_askdate:
	ld hl,m_dt_now
	call con_puts
	ld de,(sh_date)
	call sh_pdate
	ld hl,m_dt_ask
	call con_puts
	ld hl,LINEBUF
	ld b,12
	call con_getline
	ld a,b
	or a
	ret z			; Return: keep it
	ld hl,LINEBUF
	call sh_skipsp
	call sh_setdate
	ret nc
	ld hl,m_dt_bad
	call con_puts
	jr sh_askdate

sh_setdate:			; HL = "yyyy-mm-dd" -> sh_date.  CF = not a date
	call sd_num		; the year: 1980 .. 2107
	ret c
	ld (sh_y),de
	ex de,hl
	push de
	ld de,1980
	or a
	sbc hl,de
	pop de
	ret c
	push de
	ld de,2107-1980+1
	or a
	sbc hl,de
	pop de
	ccf
	ret c
	ex de,hl
	call sd_sep
	ret c
	call sd_num		; the month: 1 .. 12
	ret c
	ld a,d
	or a
	scf
	ret nz
	ld a,e
	or a
	scf
	ret z
	cp 13
	ccf
	ret c
	ld (sh_m),a
	call sd_sep
	ret c
	call sd_num		; the day: 1 .. days in that month
	ret c
	ld a,(hl)		; and nothing after it
	or a
	jr z,sd_1
	cp ' '
	scf
	ret nz
sd_1:	ld a,d
	or a
	scf
	ret nz
	ld a,e
	or a
	scf
	ret z
	ld (sh_d),a
	call sd_dim		; A = days in the month
	ld b,a
	ld a,(sh_d)
	dec a
	cp b
	ccf
	ret c
	ld hl,(sh_y)		; DOS date: (year - 1980) << 9 | month << 5 | day
	ld de,1980
	or a
	sbc hl,de
	ld h,l
	ld l,0
	add hl,hl		; year in bits 15..9
	ld a,(sh_m)
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl		; month << 5
	add hl,de
	ld a,(sh_d)
	ld e,a
	ld d,0
	add hl,de
	ld (sh_date),hl
	ld (fs_fdate),hl
	or a
	ret

sd_num: 			; HL = digits -> DE = number (up to 4 digits). CF = none
	ld de,0
	ld b,0			; digits seen
sdn_1:	ld a,(hl)
	sub '0'
	jr c,sdn_2
	cp 10
	jr nc,sdn_2
	push hl 		; DE = DE * 10 + digit
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
	inc hl
	inc b
	ld a,b
	cp 5
	jr c,sdn_1
	scf			; 5 digits: no
	ret
sdn_2:	ld a,b
	cp 1			; CF if no digit at all
	ret

sd_sep: 			; HL at "-", "/" or "." -> past it.  CF = something else
	ld a,(hl)
	inc hl
	cp '-'
	ret z
	cp '/'
	ret z
	cp '.'
	ret z
	scf
	ret

sd_dim: 			; A = days in month sh_m of year sh_y
	ld a,(sh_m)
	ld e,a
	ld d,0
	ld hl,sd_days-1
	add hl,de
	ld a,(hl)
	cp 28
	ret nz
	ld a,(sh_y)		; February: 29 when the year divides by 4
	and 3			; (and 2100 does not: it is the only such year here)
	ld a,28
	ret nz
	ld hl,(sh_y)
	ld de,2100
	or a
	sbc hl,de
	ld a,28
	ret z
	inc a
	ret
sd_days: defb 31,28,31,30,31,30,31,31,30,31,30,31

m_dt_now: defm "The date is "
	defb 0
m_dt_ask: defm ".  New date (yyyy-mm-dd), or Return to keep: "
	defb 0
m_dt_bad: defm "not a date: yyyy-mm-dd, e.g. 2026-11-02"
	defb 13,10,0
