; ==========================================================================
; XFER.ASM - SERRECV and SERSEND: single files over Serial B.  Built into
; the OS so that a system can be set up from blank disks and the cable alone.
; The PC side is tools/pc/serxfer.py.
;
;   SERRECV [name]   from the PC   (PC: serxfer.py send FILE [DOSNAME])
;                    no name, or only a directory (B:\IN\): the PC's name
;   SERSEND name     to the PC     (PC: serxfer.py get [FILE])
;
; The protocol, 9615 baud 8N1:
;   Ampro: SYN 'R' (SERRECV) or SYN 'S' (SERSEND), once a second; PC: 'G'
;   header:  'F'  size (4 bytes, low first)  name (13 bytes, 0-padded)
;   blocks:  'D'  length (1 byte, 0 = 256)  the data  sum (2 bytes, low first)
;   replies: ACK (06h) = fine, NAK (15h) = send that block again,
;            'E' + an error code = given up
;   the end: 'Z'
; The sum is the 16-bit sum of the data bytes.  Whoever sends waits for the
; reply to every block, so the other side may take its time (disk writes).
; SYN (16h) never appears in console text, so the PC finds the start among
; the console text that is copied to Serial B; during the transfer itself
; the console copy is switched off.  Blocks go through the TPA.
; ==========================================================================

XF_SYN:  equ 16h
XF_ACK:  equ 06h
XF_NAK:  equ 15h
XF_TRIES: equ 10		; a block is sent at most this often

; ---------------------------------------------------------------- SERRECV
cmd_serrecv:
	call sh_mount
	ret c
	xor a
	ld (xf_open),a
	ld hl,m_xf_r
	ld a,'R'
	call xf_hello		; console copy off, wait for the PC's 'G'
	call xf_rx		; ---- the header
	jp c,xr_lost
	cp 'F'
	jp nz,xr_lost
	ld hl,xf_size		; size: 4 bytes
	ld b,4
xr_h1:	call xf_rx
	jp c,xr_lost
	ld (hl),a
	inc hl
	djnz xr_h1
	ld hl,sh_sname		; name: 13 bytes
	ld b,13
xr_h2:	call xf_rx
	jp c,xr_lost
	ld (hl),a
	inc hl
	djnz xr_h2
	ld (hl),0
	ld hl,(sh_args) 	; where it goes: the argument (a name, or only a
	call sh_resolve 	; directory, or nothing) ...
	jp c,xr_err
	call sh_noname
	jr nz,xr_h3
	ld hl,sh_sname		; ... with the PC's name if none was given
xr_h3:	call xf_copyname
	ld hl,sh_dname
	ld ix,sh_fcb1
	call f_create
	jp c,xr_err
	ld a,1
	ld (xf_open),a
	call xf_ack
	ld hl,(xf_size)
	ld (xf_left),hl
	ld hl,(xf_size+2)
	ld (xf_left+2),hl

xr_blk: call xf_setlen		; ---- the blocks
	jr z,xr_done
	ld a,XF_TRIES
	ld (xf_try),a
xr_b1:	call xr_block		; CF = it did not arrive whole: ask again
	jr nc,xr_b2
	call xf_drain
	ld a,XF_NAK
	call siob_putc
	ld hl,xf_try
	dec (hl)
	jr nz,xr_b1
	ld hl,m_xf_tries
	jr xr_fail
xr_b2:	ld ix,sh_fcb1		; on the disk with it, then say so
	ld de,(sh_buf)
	ld bc,(xf_len)
	call f_write
	jr c,xr_err
	call xf_ack
	call xf_sub
	jr xr_blk

xr_done:
	ld ix,sh_fcb1
	call f_close
	jr c,xr_err
	ld a,'Z'
	call siob_putc
	call xf_loud
	ld hl,m_xf_got
	jp xf_say

xr_block:			; 'D', length, data, sum into TPA.  CF = bad
	call xf_rx
	ret c
	cp 'D'
	scf
	ret nz
	call xf_rx		; the length must be the one expected
	ret c
	ld b,a
	ld a,(xf_len)
	cp b
	scf
	ret nz
	ld hl,(sh_buf)
	ld bc,(xf_len)
xrk_1:	call xf_rx
	ret c
	ld (hl),a
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,xrk_1
	call xf_rx16		; the sum must be right
	ret c
	push de
	call xf_sumbuf
	pop de
	ld hl,(xf_sum)
	or a
	sbc hl,de
	ret z
	scf
	ret

xr_lost:
	ld hl,m_xf_lost
xr_fail:			; HL = a message: tell the PC 'E' 0, then here
	xor a
	call xf_give
	call con_puts
	jr xr_clean
xr_err: call xf_give		; A = an error code: to the PC, then here
	call sh_err
xr_clean:
	ld a,(xf_open)		; half a file is no file
	or a
	jp z,sh_loop
	ld ix,sh_fcb1
	call f_close
	ld hl,sh_dname
	call f_delete
	jp sh_loop

xf_give:			; send 'E' and code A, console copy back on.  Keeps HL, A
	push af
	ld a,'E'
	call siob_putc
	pop af
	call siob_putc
	push af
	call xf_loud
	pop af
	ret

; ---------------------------------------------------------------- SERSEND
cmd_sersend:
	call sh_open1	      ; open it before anything is said to the PC
	ret c
	call xf_copyname
	ld hl,sh_dname
	ld ix,sh_fcb1
	call f_open
	jp c,sh_err
	ld hl,sh_fcb1+FCB_SIZE
	ld de,xf_size
	ld bc,4
	ldir
	ld hl,m_xf_s
	ld a,'S'
	call xf_hello
	ld a,'F'		; ---- the header: 'F', size, name (0-padded to 13)
	call siob_putc
	ld hl,xf_size
	ld b,4
xs_h1:	ld a,(hl)
	call siob_putc
	inc hl
	djnz xs_h1
	ld hl,sh_dname
	ld b,13
xs_h2:	ld a,(hl)
	call siob_putc
	or a
	jr z,xs_h3
	inc hl
xs_h3:	djnz xs_h2
	call xs_reply
	jr nz,xs_gaveup

xs_blk: ld ix,sh_fcb1		; ---- the blocks
	ld de,(sh_buf)
	ld bc,256
	call f_read
	jr c,xs_err
	ld a,b
	or c
	jr z,xs_done
	ld (xf_len),bc
	call xf_sumbuf
	ld a,XF_TRIES
	ld (xf_try),a
xs_b1:	ld a,'D'		; 'D', length, data, sum
	call siob_putc
	ld a,(xf_len)
	call siob_putc
	ld hl,(sh_buf)
	ld bc,(xf_len)
xs_b2:	ld a,(hl)
	call siob_putc
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,xs_b2
	ld de,(xf_sum)
	ld a,e
	call siob_putc
	ld a,d
	call siob_putc
	call xs_reply		; ACK: the next; NAK or nothing: again
	jr z,xs_blk
	cp 'E'
	jr z,xs_gaveup
	ld hl,xf_try
	dec (hl)
	jr nz,xs_b1
	ld hl,m_xf_tries
	jr xf_stop

xs_done:
	ld a,'Z'
	call siob_putc
	call xf_loud
	ld hl,m_xf_sent
	jp xf_say

xs_reply:			; the PC's answer (waiting ~10 s).  Z = ACK
	ld b,10
	call xf_rxw
	jr c,xs_r1
	cp XF_ACK
	ret
xs_r1:	ld a,0FFh		; nothing: NZ
	or a
	ret

xs_gaveup:
	ld hl,m_xf_gave
	jr xf_stop
xs_err: push af
	call xf_loud
	pop af
	jp sh_err

; ---------------------------------------------------------------- shared
xf_hello:			; HL = what to tell the user, A = 'R' or 'S':
	ld (xf_ltr),a		; console copy off, then SYN + the letter once a
	call con_puts		; second until the PC answers 'G' (Esc stops)
	ld a,(con_mirror)
	ld (xf_mir),a
	xor a
	ld (con_mirror),a
xh_1:	ld a,XF_SYN
	call siob_putc
	ld a,(xf_ltr)
	call siob_putc
	ld b,1
	call xf_rxw
	jr c,xh_2
	cp 'G'
	ret z
xh_2:	call con_kbhit
	jr z,xh_1
	call con_getc
	cp 1Bh
	jr nz,xh_1
	ld hl,m_xf_esc
	jr xf_stop

xf_stop:			; HL = a message: console copy back on, say it, prompt
	push hl
	call xf_loud
	pop hl
	call con_puts
	jp sh_loop

xf_loud:
	ld a,(xf_mir)
	ld (con_mirror),a
	ret

xf_ack: ld a,XF_ACK
	jp siob_putc

xf_rx:				; A = the next byte, waiting ~2 s.  CF = nothing came.
	push bc 		; Keeps BC (callers count bytes in B) and DE.
	ld b,2
	call xf_rxw
	pop bc
	ret
xf_rxw: 			; ... waiting B times ~1 s
	push bc
	push de
xw_1:	ld de,0
xw_2:	call siob_getc
	jr nc,xw_3
	dec de
	ld a,d
	or e
	jr nz,xw_2
	djnz xw_1
	scf
xw_3:	pop de
	pop bc
	ret

xf_drain:			; throw away what comes in until the line is quiet
	ld de,8000h
xd_1:	call siob_getc
	jr nc,xf_drain
	dec de
	ld a,d
	or e
	jr nz,xd_1
	ret

xf_sumbuf:			; xf_sum = the sum of the xf_len bytes at TPA
	ld hl,(sh_buf)
	ld bc,(xf_len)
	ld de,0
xsm_1:	ld a,(hl)
	add a,e
	ld e,a
	jr nc,xsm_2
	inc d
xsm_2:	inc hl
	dec bc
	ld a,b
	or c
	jr nz,xsm_1
	ld (xf_sum),de
	ret

xf_rx16:			; DE = the next two bytes, low first.  CF = timeout
	call xf_rx
	ret c
	ld e,a
	call xf_rx
	ld d,a
	ret

xf_sub: 			; xf_left = xf_left - xf_len
	ld hl,(xf_left)
	ld de,(xf_len)
	or a
	sbc hl,de
	ld (xf_left),hl
	ret nc
	ld hl,(xf_left+2)
	dec hl
	ld (xf_left+2),hl
	ret

xf_setlen:			; xf_len = min(256, xf_left).  Z = nothing left
	ld hl,(xf_left+2)
	ld a,h
	or l
	jr nz,xl_full
	ld hl,(xf_left)
	ld a,h
	or l
	ret z
	ld de,257
	or a
	sbc hl,de
	add hl,de
	jr c,xl_set
xl_full:
	ld hl,256
xl_set: ld (xf_len),hl
	ld a,1			; NZ
	or a
	ret

xf_copyname:			; HL = a name (to a space or 0) -> sh_dname
	ld de,sh_dname
	ld b,13
xc_1:	ld a,(hl)
	or a
	jr z,xc_2
	cp ' '
	jr z,xc_2
	ld (de),a
	inc hl
	inc de
	djnz xc_1
xc_2:	xor a
	ld (de),a
	ret

xf_say: 			; "received 1234 bytes: NAME"
	call con_puts
	ld hl,xf_size
	ld b,0
	call con_dec32
	ld hl,m_xf_bytes
	call con_puts
	ld hl,sh_dname
	call con_puts
	jp con_crlf

m_xf_r:  defm "SERRECV: on the PC run  serxfer.py send FILE   (Esc stops)"
	defb 13,10,0
m_xf_s:  defm "SERSEND: on the PC run  serxfer.py get   (Esc stops)"
	defb 13,10,0
m_xf_esc: defm "stopped"
	defb 13,10,0
m_xf_lost: defm "the PC stopped"
	defb 13,10,0
m_xf_tries: defm "too many bad blocks"
	defb 13,10,0
m_xf_gave: defm "the PC gave up"
	defb 13,10,0
m_xf_got: defm "received "
	defb 0
m_xf_sent: defm "sent "
	defb 0
m_xf_bytes: defm " bytes: "
	defb 0
