; ==========================================================================
; CRC.ASM - CRC name: the CRC-32 of a file, to check a transfer.
;
;   A> crc hello.bin
;   0E1D2C3B  115  hello.bin
;
; It is the usual CRC-32 (the one of zip, gzip, PNG; the polynomial EDB88320h,
; start and end value FFFFFFFFh), so the PC says the same:
;   python3 -c "import zlib,sys; print('%08X' % zlib.crc32(open(sys.argv[1],'rb').read()))" hello.bin
; or crc32 hello.bin.  The checksum runs bit by bit in the second register
; set (DE' HL'): slow (about 6 KB a second) but short.
; ==========================================================================

cmd_crc:
	call ct_open		; the file, as for TYPE (says why not)
	ret c
	exx
	ld de,0FFFFh
	ld hl,0FFFFh
	exx
crc_rd: call ct_piece		; BC = bytes in sh_buf
	ret c
	ld a,b
	or c
	jr z,crc_end
	ld hl,(sh_buf)
crc_b:	ld a,(hl)
	inc hl
	exx
	xor l
	ld l,a
	ld b,8
crc_bit:
	srl d
	rr e
	rr h
	rr l
	jr nc,crc_nx
	ld a,d
	xor 0EDh
	ld d,a
	ld a,e
	xor 0B8h
	ld e,a
	ld a,h
	xor 83h
	ld h,a
	ld a,l
	xor 20h
	ld l,a
crc_nx: djnz crc_bit
	exx
	dec bc
	ld a,b
	or c
	jr nz,crc_b
	jr crc_rd
crc_end:
	exx
	ld a,d			; the end value: all bits turned over
	cpl
	ld d,a
	ld a,e
	cpl
	ld e,a
	push hl
	ex de,hl
	call con_hex16
	pop hl
	ld a,l
	cpl
	ld l,a
	ld a,h
	cpl
	ld h,a
	call con_hex16
	exx
	ld a,' '
	call con_putc
	call con_putc
	ld hl,sh_fcb1+FCB_SIZE
	ld b,0
	call con_dec32
	ld a,' '
	call con_putc
	call con_putc
	ld hl,(sh_args)
	call con_puts
	jp con_crlf
