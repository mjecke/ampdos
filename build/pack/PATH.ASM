; ==========================================================================
; PATH.ASM - drives and directories behind file names.
;
; A file argument may name a drive and a path:   [d:][\]dir\dir\name
;   README.MD        here
;   B:README.MD      drive B, in B's current directory
;   \DOCS\A.TXT      from the root of this drive
;   SUB\X\           a directory (the name part is empty); so are . and ..
; sh_resolve walks there: afterwards the right drive is selected, its disk is
; mounted, fs_cwd is the right directory, and HL points at the name part.
; The next command's sh_mount comes back home, so a command never has to.
;
; "Home" is sh_drive with its directory sh_cwd0 / sh_cwd1: those two words
; are the truth about where each drive is.  fs_cwd is only the directory the
; file system is working in at the moment.
;
;   sh_ctx      A = drive, HL = directory   select, mount, fs_cwd = HL.  CF = failed
;   sh_cwdp     A = drive                   HL = address of its sh_cwd word
;   sh_resolve  HL = file argument          as above.  CF = failed, A = code;
;                                           the name part is also copied to sh_comp
;   sh_fname2txt DE = buffer                fs_fname as "NAME.EXT", 0-terminated
; ==========================================================================

sh_ctx:
	ld (fs_cwd),hl		; (fs_mount checks it is still a directory)
	call md_select
	ld a,FS_EWRITE
	ret c
	call fs_mount
	ret c
	ld hl,(sh_date) 	; new files get today's date
	ld (fs_fdate),hl
	ld hl,0
	ld (fs_ftime),hl
	or a
	ret

sh_cwdp:
	ld hl,sh_cwd0
	or a
	ret z
	ld hl,sh_cwd1
	ret

sh_resolve:
	ld a,(sh_drive) 	; a drive letter?
	ld (sh_rdrv),a
	ld a,(hl)		; (not in an empty argument: the byte after its end
	or a			;  is left over from an older command line)
	jr z,sr_1
	inc hl
	ld a,(hl)
	dec hl
	cp ':'
	jr nz,sr_1
	ld a,(hl)
	and 0DFh
	sub 'A'
	cp 2
	jr nc,sr_baddrv
	ld (sh_rdrv),a
	inc hl
	inc hl
sr_1:	push hl 		; start in that drive's directory, or in its root
	ld a,(sh_rdrv)
	call sh_cwdp
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	pop de
	ld a,(de)
	cp 5Ch
	jr z,sr_root
	cp '/'
	jr nz,sr_2
sr_root:
	inc de
	ld hl,0
sr_2:	push de
	ld a,(sh_rdrv)
	call sh_ctx
	pop hl
	ret c
sr_3:	call sr_part		; next part -> sh_comp; DE = at what ends it
	ret c
	ld a,(de)
	cp 5Ch			; a separator follows: that part is a directory
	jr z,sr_dir
	cp '/'
	jr z,sr_dir
	ld a,(sh_comp)		; . or .. at the end: a directory too ("COPY X ..")
	cp '.'
	jr z,sr_dot
	or a			; the end: HL = the name part (may be empty)
	ret
sr_dot: push de
	ld hl,sh_comp
	call fs_chdir
	pop hl			; HL = the end: no name part
	ret
sr_dir: push de
	push hl
	ld hl,sh_comp
	call fs_chdir
	pop hl
	pop de
	ret c
	ex de,hl
	inc hl			; past the separator
	jr sr_3
sr_baddrv:
	ld a,FS_EPATH
	scf
	ret

sr_part:			; HL = text: copy one part to sh_comp (at most 12
	push hl 		; characters).  HL kept, DE = after the part.  CF = too long
	ld de,sh_comp
	ld b,13
srp_1:	ld a,(hl)
	or a
	jr z,srp_2
	cp ' '
	jr z,srp_2
	cp 5Ch
	jr z,srp_2
	cp '/'
	jr z,srp_2
	dec b
	jr z,srp_long
	ld (de),a
	inc de
	inc hl
	jr srp_1
srp_2:	xor a
	ld (de),a
	ex de,hl		; DE = after the part
	pop hl			; HL = its start
	or a
	ret
srp_long:
	pop hl
	ld a,FS_EPATH
	scf
	ret

sh_fname2txt:			; fs_fname "README  MD " -> (DE) "README.MD", 0
	ld hl,fs_fname
	ld b,8
sft_1:	ld a,(hl)
	cp ' '
	jr z,sft_2
	ld (de),a
	inc de
	inc hl
	djnz sft_1
sft_2:	ld a,(fs_fname+8)
	cp ' '
	jr z,sft_4
	ld a,'.'
	ld (de),a
	inc de
	ld hl,fs_fname+8
	ld b,3
sft_3:	ld a,(hl)
	cp ' '
	jr z,sft_4
	ld (de),a
	inc de
	inc hl
	djnz sft_3
sft_4:	xor a
	ld (de),a
	ret

sh_noname:			; Z = HL points at an empty name part
	ld a,(hl)
	or a
	ret z
	cp ' '
	ret
