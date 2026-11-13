; ==========================================================================
; DEFRAG.ASM - DEFRAG.BIN: a disk's clusters as a map, and its files in one
; piece again.
;
;   DEFRAG [d:]         the map and a report (nothing is changed)
;   DEFRAG [d:] /F      and then each file in pieces is moved into one free
;                       run, the map changing as it goes
;
;   B: 354 clusters of 1024 bytes
;      2 ###########%%%%%%#########D###.........##%%%%%..........  ...
;   . free   # a file in one piece   % a file in pieces   D a directory
;   B bad    ? lost (CHKDSK /F)      ! two files claim it (CHKDSK)
;
; How a file is moved (so that nothing is lost if it stops half way): its
; clusters are copied into the free run; the run is chained in the FAT and
; written; then the file's directory entry is changed to the run and written;
; only then are the old clusters freed.  Stopped before the end, the old copy
; is still the file, and the run is "lost" clusters CHKDSK /F frees.  A file
; that has no free run as big as it stays as it is; directories are not
; moved.  /F is refused on a disk with lost, crossed or broken chains: run
; CHKDSK /F first.
; ==========================================================================
	org 8000h

	include "KERNEL/INC/OS.INC"
	include "KERNEL/FS/FS.INC"

P_PAT:	equ 9000h
P_NAME: equ 9010h		; 13 bytes
v_ix:	equ 9020h		; word: the entry number in this directory
v_dep:	equ 9022h		; the level
v_fix:	equ 9023h		; 1 = /F
v_plen: equ 9024h
v_pass: equ 9025h		; 0 the map, 1 moving
v_max:	equ 9026h		; word: the last cluster (2 .. v_max)
v_ncl:	equ 9028h		; word: data clusters
v_spc:	equ 902Ah		; sectors a cluster
v_data: equ 902Ch		; word: the first data sector
v_n:	equ 902Eh		; word: clusters in the chain (CHAIN)
v_pcs:	equ 9030h		; word: its pieces
v_bad:	equ 9032h		; 1 = a broken or crossed chain seen
v_files: equ 9034h		; word
v_frag: equ 9036h		; word: files in pieces
v_tpcs: equ 9038h		; word: their pieces
v_dirs: equ 903Ah		; word
v_free: equ 903Ch		; word: free clusters
v_runs: equ 903Eh		; word: free runs
v_big:	equ 9040h		; word: the largest
v_lost: equ 9042h		; word
v_nbad: equ 9044h		; word: bad clusters
v_moved: equ 9046h		; word: files moved
v_left: equ 9048h		; word: files that found no room
v_run:	equ 904Ah		; word: the run found
v_k:	equ 904Ch		; word
v_home: equ 904Eh		; 1 = the terminal has HOME
v_drv:	equ 904Fh		; 'A' or 'B'
v_isdir: equ 9050h
v_path: equ 9060h		; 80 bytes
v_tmp:	equ 90B0h		; 80 bytes
v_stk:	equ 9100h		; 16 x 3 bytes
v_worst: equ 9140h		; 5 x 16: pieces (word), name (13), 0
v_w:	equ 91D0h		; 16 bytes
MAXDEP: equ 16
NWORST: equ 5
CHAIN:	equ 9400h		; words: the clusters of a chain (2048 at most)
MAXCH:	equ 2048
MAP:	equ 0A400h		; a byte a cluster
SBUF:	equ 0B400h		; a cluster's sectors (4 KB at most)
GRIDW:	equ 59			; clusters on a line of the map

K_FREE: equ 0
K_ONE:	equ 1
K_PCS:	equ 2
K_DIR:	equ 3
K_BAD:	equ 4
K_LOST: equ 5
K_TWO:	equ 6

start:	xor a
	ld (v_fix),a
	call OS_DRIVE		; the current drive, unless one is given
	add a,'A'
	ld (v_drv),a
st_1:	ld de,v_w
	call pl_word
	jr z,st_go
	ld a,(v_w)
	cp '/'
	jr z,st_sw
	call pl_upper		; a drive: A, A:, B, B:
	cp 'A'
	jp c,use
	cp 'C'
	jp nc,use
	ld (v_drv),a
	ld a,(v_w+1)
	or a
	jr z,st_1
	cp ':'
	jp nz,use
	jr st_1
st_sw:	ld a,(v_w+1)
	call pl_upper
	cp 'F'
	jp nz,use
	ld a,1
	ld (v_fix),a
	jr st_1
st_go:	call disk		; the layout
	ret c
	xor a
	ld (v_pass),a
	call analyse
	ret c
	call show
	ld a,(v_fix)
	or a
	ret z
	ld a,(v_bad)		; /F: only on a sound disk
	or a
	jp nz,unsound
	ld hl,(v_lost)
	ld a,h
	or l
	jp nz,unsound
	ld hl,(v_frag)
	ld a,h
	or l
	ld hl,m_nofrag
	jp z,OS_PUTS
	ld hl,m_sure
	call OS_PUTS
	ld a,(v_drv)
	call OS_PUTC
	ld hl,m_sure2
	call OS_PUTS
	call OS_GETC
	call pl_upper
	push af
	call OS_PUTC
	call OS_CRLF
	pop af
	cp 'Y'
	ret nz
	ld a,1			; ---- moving
	ld (v_pass),a
	ld hl,0
	ld (v_moved),hl
	ld (v_left),hl
	xor a			; the map at the top, redrawn as files move (if
	call OS_SCREEN		; there is HOME: the screen was just cleared, so
	ld a,1			; trying it moves nothing)
	call OS_SCREEN
	ld a,0
	jr c,st_h
	inc a
st_h:	ld (v_home),a
	or a
	call nz,drawmap
	call walk
	ret c
	xor a			; ---- and the map again, as it is now
	ld (v_pass),a
	call analyse
	ret c
	ld a,(v_home)
	or a
	jr z,st_e
	xor a
	call OS_SCREEN
	jr st_e1
st_e:	call OS_CRLF
	call OS_CRLF
st_e1:	call show
	ld hl,(v_moved)
	call OS_DEC16
	ld hl,m_moved
	call OS_PUTS
	ld hl,(v_left)
	ld a,h
	or l
	ret z
	call OS_DEC16
	ld hl,m_left
	jp OS_PUTS

unsound:
	ld hl,m_unsound
	jp pl_fail
use:	ld hl,m_use
	jp pl_fail

; ---------------------------------------------------------------- the disk
disk:				; the layout: clusters, sectors a cluster, the data's start
	call root
	ret c
	call OS_DISK		; A = sectors a cluster, HL = data clusters
	ld (v_spc),a
	ld (v_ncl),hl
	inc hl
	ld (v_max),hl
	ld de,MAXCH		; (a map this big at most)
	or a
	sbc hl,de
	jr c,dk_1
	ld hl,m_big
	jp pl_fail1
dk_1:	cp 9			; (SBUF: 4 KB)
	jr c,dk_2
	ld hl,m_big
	jp pl_fail1
dk_2:	ld hl,0 		; the boot sector: where the data starts
	ld de,SBUF
	call OS_RDLBA
	jp c,pl_err1
	ld ix,SBUF
	ld l,(ix+16h)		; sectors a FAT x FATs
	ld h,(ix+17h)
	ld b,(ix+10h)
	ex de,hl
	ld hl,0
dk_3:	add hl,de
	djnz dk_3
	ld e,(ix+0Eh)		; + reserved
	ld d,(ix+0Fh)
	add hl,de
	push hl
	ld l,(ix+11h)		; + the root directory's sectors
	ld h,(ix+12h)
	ld de,15
	add hl,de
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	pop de
	add hl,de
	ld (v_data),hl
	or a
	ret

root:				; v_path = "d:\", its directory the current one
	ld hl,v_path
	ld a,(v_drv)
	ld (hl),a
	inc hl
	ld (hl),':'
	inc hl
	ld (hl),5Ch
	inc hl
	ld (hl),0
	ld a,3
	ld (v_plen),a
	xor a
	ld (v_dep),a
	call w_res
	ret

; ---------------------------------------------------------------- the map
analyse:			; MAP and the numbers, from a walk of every directory
	ld hl,MAP		; (all free; the FAT says the rest)
	ld de,MAP+1
	ld bc,MAXCH-1
	ld (hl),K_FREE
	ldir
	ld hl,0
	ld (v_files),hl
	ld (v_frag),hl
	ld (v_tpcs),hl
	ld (v_dirs),hl
	ld (v_free),hl
	ld (v_runs),hl
	ld (v_big),hl
	ld (v_lost),hl
	ld (v_nbad),hl
	xor a
	ld (v_bad),a
	ld hl,v_worst
	ld b,NWORST*16
an_0:	ld (hl),0
	inc hl
	djnz an_0
	call walk
	ret c
	ld hl,2 		; then the clusters no file claims
	ld (v_k),hl
	ld bc,0 		; BC = the free run so far
an_1:	ld hl,(v_k)
	call mapat
	ld a,(hl)
	or a
	jr nz,an_end
	push hl
	push bc
	ld hl,(v_k)
	call OS_FATGET
	pop bc
	ld a,h
	or l
	pop de
	jr z,an_fr
	ld a,h			; FF7: bad; else lost
	cp 0Fh
	jr nz,an_lo
	ld a,l
	cp 0F7h
	jr nz,an_lo
	ld a,K_BAD
	ld (de),a
	ld hl,(v_nbad)
	inc hl
	ld (v_nbad),hl
	jr an_end
an_lo:	ld a,K_LOST
	ld (de),a
	ld hl,(v_lost)
	inc hl
	ld (v_lost),hl
	jr an_end
an_fr:	ld hl,(v_free)		; free: and the run goes on
	inc hl
	ld (v_free),hl
	inc bc
	jr an_nx
an_end: call runend		; (a run ends here)
an_nx:	ld hl,(v_k)
	ld de,(v_max)
	or a
	sbc hl,de
	jr z,an_last
	ld hl,(v_k)
	inc hl
	ld (v_k),hl
	jr an_1
an_last:
	call runend
	or a
	ret
runend: ld a,b			; BC = a free run that has ended (0: none)
	or c
	ret z
	ld hl,(v_runs)
	inc hl
	ld (v_runs),hl
	ld hl,(v_big)
	or a
	sbc hl,bc
	jr nc,re_1
	ld (v_big),bc
re_1:	ld bc,0
	ret

mapat:	ld de,MAP-2		; HL = a cluster -> HL = its place in MAP
	add hl,de
	ret

show:				; the map, what it means, and the numbers
	call drawmap
	ld hl,m_legend
	call OS_PUTS
	ld hl,(v_files)
	call OS_DEC16
	ld hl,m_files
	call OS_PUTS
	ld hl,(v_frag)
	call OS_DEC16
	ld hl,m_inpcs
	call OS_PUTS
	ld hl,(v_tpcs)
	call OS_DEC16
	ld hl,m_pcs
	call OS_PUTS
	ld hl,(v_dirs)
	call OS_DEC16
	ld hl,m_dirs
	call OS_PUTS
	ld hl,(v_free)		; free: clusters x spc / 2 = KB
	call kb
	ld hl,m_kbfree
	call OS_PUTS
	ld hl,(v_runs)
	call OS_DEC16
	ld hl,m_runs
	call OS_PUTS
	ld hl,(v_big)
	call kb
	ld hl,m_kbbig
	call OS_PUTS
	ld hl,(v_nbad)
	ld a,h
	or l
	jr z,sw_1
	call OS_DEC16
	ld hl,m_nbad
	call OS_PUTS
sw_1:	ld hl,(v_lost)
	ld a,h
	or l
	jr z,sw_2
	call OS_DEC16
	ld hl,m_nlost
	call OS_PUTS
sw_2:	ld a,(v_bad)
	or a
	ld hl,m_crossed
	call nz,OS_PUTS
	ld a,(v_worst)		; the files in the most pieces
	ld hl,v_worst
	or (hl)
	inc hl
	or (hl)
	ret z
	ld hl,m_worst
	call OS_PUTS
	ld hl,v_worst
	ld b,NWORST
sw_3:	ld a,(hl)
	inc hl
	or (hl)
	dec hl
	ret z
	push bc
	push hl
	ld a,' '
	call OS_PUTC
	call OS_PUTC
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ex de,hl
	call OS_DEC16
	ld a,' '
	call OS_PUTC
	ex de,hl
	call OS_PUTS
	call OS_CRLF
	pop hl
	ld de,16
	add hl,de
	pop bc
	djnz sw_3
	ret

kb:	ld a,(v_spc)		; HL clusters, in KB (HL x spc / 2)
	ld b,a
	ex de,hl
	ld hl,0
kb_1:	add hl,de
	djnz kb_1
	srl h
	rr l
	jp OS_DEC16

drawmap:			; "B: 354 clusters of 1024 bytes", then the grid
	ld a,(v_drv)
	call OS_PUTC
	ld hl,m_colon
	call OS_PUTS
	ld hl,(v_ncl)
	call OS_DEC16
	ld hl,m_clof
	call OS_PUTS
	ld a,(v_spc)
	ld h,a
	ld l,0
	add hl,hl
	call OS_DEC16
	ld hl,m_bytes
	call OS_PUTS
	ld hl,2
	ld (v_k),hl
dm_1:	ld hl,(v_k)		; a line: "   2 " and GRIDW clusters
	call dec4
	ld a,' '
	call OS_PUTC
	ld b,GRIDW
dm_2:	push bc
	ld hl,(v_k)
	call mapat
	ld a,(hl)
	ld e,a
	ld d,0
	ld hl,m_chars
	add hl,de
	ld a,(hl)
	call OS_PUTC
	pop bc
	ld hl,(v_k)
	ld de,(v_max)
	or a
	sbc hl,de
	jp z,OS_CRLF		; (the last one)
	ld hl,(v_k)
	inc hl
	ld (v_k),hl
	djnz dm_2
	call OS_CRLF
	jr dm_1

dec4:	ld de,1000		; HL in 4 places, spaces before
	call d4_sp
	ld de,100
	call d4_sp
	ld de,10
	call d4_sp
	jp OS_DEC16
d4_sp:	push hl
	or a
	sbc hl,de
	pop hl
	ret nc
	ld a,' '
	jp OS_PUTC

; ---------------------------------------------------------------- the walk
walk:				; every entry of every directory: entry
	call root
	ret c
	ld hl,0
	ld (v_ix),hl
wk_lp:	ld hl,(v_ix)
	call OS_DIRGET
	jr c,wk_up
	ld a,(hl)
	or a
	jr z,wk_up
	call pl_entry
	jr nz,wk_next
	ld (v_isdir),a
	push hl
	call entry
	pop hl
	ret c			; (stopped)
	ld a,(v_isdir)
	bit 4,a
	jr z,wk_next
	ld a,(v_dep)		; a directory: down into it
	cp MAXDEP-1
	jr nc,wk_next
	ld hl,(v_ix)		; (the entry again: entry may have read others)
	call OS_DIRGET
	call pl_ename
	push de
	call push_lv
	pop hl
	call w_add
	jr c,wk_long
	call w_res
	jr c,wk_cant
	ld hl,v_dep
	inc (hl)
	ld hl,0
	ld (v_ix),hl
	jr wk_lp
wk_cant:
wk_long:
	call pop_lv
	call w_res
	ret c
wk_next:
	ld hl,(v_ix)
	inc hl
	ld (v_ix),hl
	jp wk_lp
wk_up:	ld a,(v_dep)
	or a
	ret z			; (NC)
	dec a
	ld (v_dep),a
	call pop_lv
	call w_res
	ret c
	jr wk_next

entry:				; HL = an entry (A = its attributes): the map, or moved
	push hl
	ld de,DE_CLUS
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	pop hl
	ld a,d
	or e
	ret z			; (empty: no clusters)
	push hl
	call chain		; CHAIN, v_n, v_pcs
	pop hl
	ld a,(v_pass)
	or a
	jp nz,move
	push hl 		; ---- the map
	ld a,(v_isdir)
	bit 4,a
	ld c,K_DIR
	jr nz,en_1
	ld hl,(v_files)
	inc hl
	ld (v_files),hl
	ld c,K_ONE
	ld hl,(v_pcs)
	dec hl
	ld a,h
	or l
	jr z,en_1
	ld c,K_PCS
	ld hl,(v_frag)
	inc hl
	ld (v_frag),hl
	ld hl,(v_tpcs)
	ld de,(v_pcs)
	add hl,de
	ld (v_tpcs),hl
	pop hl
	push hl
	call worst		; one of the worst?
	ld c,K_PCS
en_1:	ld a,(v_isdir)
	bit 4,a
	jr z,en_2
	ld hl,(v_dirs)
	inc hl
	ld (v_dirs),hl
en_2:	ld hl,CHAIN		; its clusters on the map (two claims: !)
	ld de,(v_n)
en_3:	ld a,d
	or e
	jr z,en_4
	push de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	ex de,hl
	call mapat
	ld a,(hl)
	or a
	jr z,en_5
	ld a,1
	ld (v_bad),a
	ld (hl),K_TWO
	jr en_6
en_5:	ld (hl),c
en_6:	pop hl
	pop de
	dec de
	jr en_3
en_4:	pop hl
	or a
	ret

chain:				; DE = a first cluster -> CHAIN, v_n clusters, v_pcs
	ld hl,0 		; pieces.  A broken chain (out of the disk, too long):
	ld (v_n),hl		; v_bad, and it ends there
	inc hl
	ld (v_pcs),hl
	ld hl,CHAIN
ch_1:	push hl 		; DE in the disk?
	ld hl,1
	or a
	sbc hl,de
	jr nc,ch_bad
	ld hl,(v_max)
	or a
	sbc hl,de
	jr c,ch_bad
	pop hl
	ld (hl),e		; kept
	inc hl
	ld (hl),d
	inc hl
	push hl
	ld hl,(v_n)
	inc hl
	ld (v_n),hl
	ld bc,MAXCH
	or a
	sbc hl,bc
	jr nc,ch_bad
	push de
	ex de,hl
	call OS_FATGET		; the next
	pop de
	ld a,h			; FF8 and up: the end
	cp 0Fh
	jr nz,ch_2
	ld a,l
	cp 0F8h
	jr nc,ch_end
ch_2:	inc de			; another piece, unless it is the next cluster
	or a
	sbc hl,de
	add hl,de
	jr z,ch_3
	push hl
	ld hl,(v_pcs)
	inc hl
	ld (v_pcs),hl
	pop hl
ch_3:	ex de,hl
	pop hl
	jr ch_1
ch_bad: ld a,1
	ld (v_bad),a
ch_end: pop hl
	ret

worst:				; HL = an entry in v_pcs pieces: among the 5 worst?
	ld (v_k),hl		; (a list, most pieces first)
	ld hl,v_worst
	ld b,NWORST
wo_1:	ld e,(hl)
	inc hl
	ld d,(hl)
	dec hl
	push hl
	ld hl,(v_pcs)
	or a
	sbc hl,de
	pop hl
	jr z,wo_2
	jr nc,wo_ins		; more pieces than this one: here
wo_2:	ld de,16
	add hl,de
	djnz wo_1
	ret
wo_ins: push hl 		; the rest down one (the last goes)
	ld a,b
	dec a
	jr z,wo_3
	ld c,a			; (B - 1) x 16 bytes
	ld b,0
	ex de,hl
	ld h,b
	ld l,c
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld b,h
	ld c,l
	ld hl,v_worst+NWORST*16-17
	ld de,v_worst+NWORST*16-1
	lddr
wo_3:	pop de			; and this one in its place
	ld hl,(v_pcs)
	ex de,hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	push hl
	ld hl,(v_k)
	call pl_ename
	ex de,hl
	pop de
	ld bc,13
	ldir
	xor a
	ld (de),a
	ret

; ---------------------------------------------------------------- moving
move:				; HL = the entry, CHAIN its clusters: in one run
	ld a,(v_isdir)		; (directories, and files in one piece, stay)
	bit 4,a
	ret nz
	ld de,(v_pcs)
	dec de
	ld a,d
	or e
	ret z
	call pl_ename		; "moving NAME.EXT (n clusters, p pieces) ..."
	push de
	call progress
	pop hl
	call OS_PUTS
	ld a,' '
	call OS_PUTC
	call freerun		; a free run of v_n clusters
	jr nc,mv_1
	ld hl,(v_left)
	inc hl
	ld (v_left),hl
	ld hl,m_noroom
	call OS_PUTS
	or a
	ret
mv_1:	ld hl,0 		; ---- 1: the data, cluster by cluster
	ld (v_k),hl
mv_2:	ld hl,(v_k)
	add hl,hl
	ld de,CHAIN
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call lba
	ld de,SBUF
	call rdclus
	jp c,mv_err
	ld hl,(v_run)
	ld de,(v_k)
	add hl,de
	call lba
	ld de,SBUF
	call wrclus
	jp c,mv_err
	ld hl,(v_k)
	inc hl
	ld (v_k),hl
	ld de,(v_n)
	or a
	sbc hl,de
	jr nz,mv_2
	ld hl,0 		; ---- 2: the run chained in the FAT, written
	ld (v_k),hl
mv_3:	ld hl,(v_run)
	ld de,(v_k)
	add hl,de		; HL = this one; DE = the next, or the end
	push hl
	ld hl,(v_k)
	inc hl
	ld (v_k),hl
	ld de,(v_n)
	or a
	sbc hl,de
	pop hl
	ld d,h
	ld e,l
	inc de
	jr nz,mv_4
	ld de,0FFFh
mv_4:	push af
	call OS_FATSET
	pop af
	jr nz,mv_3
	call OS_FLUSH
	jp c,mv_err
	ld hl,(v_ix)		; ---- 3: the entry to the run, written
	call OS_DIRGET
	jp c,mv_err
	ld de,DE_CLUS
	add hl,de
	ld de,(v_run)
	ld (hl),e
	inc hl
	ld (hl),d
	call OS_DIRPUT
	jp c,mv_err
	call OS_FLUSH
	jp c,mv_err
	ld hl,CHAIN		; ---- 4: the old clusters freed, written
	ld bc,(v_n)
mv_5:	push bc
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	ex de,hl
	push hl
	call mapat		; (on the map: free)
	ld (hl),K_FREE
	pop hl
	ld de,0
	call OS_FATSET
	pop hl
	pop bc
	dec bc
	ld a,b
	or c
	jr nz,mv_5
	call OS_FLUSH
	jr c,mv_err
	ld hl,(v_run)		; (the run on the map: one piece)
	ld bc,(v_n)
mv_6:	push hl
	call mapat
	ld (hl),K_ONE
	pop hl
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,mv_6
	ld hl,(v_moved)
	inc hl
	ld (v_moved),hl
	ld hl,m_done
	call OS_PUTS
	ld a,(v_home)		; the map again
	or a
	ret z
	ld a,1
	call OS_SCREEN
	call drawmap
	or a
	ret
mv_err: push af
	call OS_CRLF
	pop af
	call pl_err
	scf
	ret

progress:			; the line under the map (with HOME), or a new line
	ld a,(v_home)
	or a
	jp z,OS_CRLF
	ld a,1			; the map is at the top: its lines, then this one
	call OS_SCREEN
	ld hl,(v_max)		; rows = 1 + ceil((max - 1) / GRIDW) + 1
	dec hl
	ld de,GRIDW
	ld b,1
pg_1:	inc b
	or a
	sbc hl,de
	jr z,pg_2
	jr nc,pg_1
pg_2:	ld a,5			; (DOWN; else line feeds)
	call OS_SCREEN
	jr nc,pg_3
	ld a,10
	call OS_PUTC
pg_3:	djnz pg_2
	ld a,13
	call OS_PUTC
	ld b,70 		; the old text: spaces over it
pg_4:	ld a,' '
	call OS_PUTC
	djnz pg_4
	ld a,13
	call OS_PUTC
	ld hl,m_moving
	jp OS_PUTS

freerun:			; a free run of v_n clusters -> v_run.  CF = none
	ld hl,2
	ld (v_k),hl
	ld bc,0 		; BC = free so far, from v_run
fr_1:	push bc
	ld hl,(v_k)
	call OS_FATGET
	pop bc
	ld a,h
	or l
	jr nz,fr_no
	ld a,b			; free: the run begins or goes on
	or c
	jr nz,fr_2
	ld hl,(v_k)
	ld (v_run),hl
fr_2:	inc bc
	ld hl,(v_n)
	or a
	sbc hl,bc
	ret z			; long enough (NC)
	jr fr_nx
fr_no:	ld bc,0
fr_nx:	ld hl,(v_k)
	ld de,(v_max)
	or a
	sbc hl,de
	scf
	ret z			; none
	ld hl,(v_k)
	inc hl
	ld (v_k),hl
	jr fr_1

lba:				; HL = a cluster -> HL = its first sector
	dec hl
	dec hl
	ld a,(v_spc)
lb_1:	srl a
	jr z,lb_2
	add hl,hl
	jr lb_1
lb_2:	ld de,(v_data)
	add hl,de
	ret
rdclus: ld a,(v_spc)		; HL = a sector, DE = memory: a cluster read
	ld b,a
rc_1:	push bc
	push hl
	push de
	call OS_RDLBA
	pop de
	pop hl
	pop bc
	ret c
	inc hl
	inc d
	inc d
	djnz rc_1
	ret
wrclus: ld a,(v_spc)		; and written
	ld b,a
wc_1:	push bc
	push hl
	push de
	call OS_WRLBA
	pop de
	pop hl
	pop bc
	ret c
	inc hl
	inc d
	inc d
	djnz wc_1
	ret

push_lv:			; keep (v_ix, v_plen) for the level being left
	ld a,(v_dep)
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	ld de,v_stk
	add hl,de
	ld de,(v_ix)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld a,(v_plen)
	ld (hl),a
	ret
pop_lv: ld a,(v_dep)		; and back to it
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	ld de,v_stk
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (v_ix),de
	ld a,(hl)
	ld (v_plen),a
	ld e,a
	ld d,0
	ld hl,v_path
	add hl,de
	ld (hl),0
	ret

pl_err1:
	call pl_err
	scf
	ret
pl_fail1:
	call pl_fail
	scf
	ret

	include "PROGRAMS/WALK.INC"

m_use:	defm "DEFRAG [d:] [/F]   (the map; /F: files in pieces made one again)"
	defb 0
m_big:	defm "DEFRAG: this disk is too big for it"
	defb 0
m_chars:
	defm ".#%DB?!"
m_colon:
	defm ": "
	defb 0
m_clof: defm " clusters of "
	defb 0
m_bytes:
	defm " bytes"
	defb 13,10,0
m_legend:
	defm ". free  # a file in one piece  % a file in pieces  D directory  B bad"
	defb 13,10
	defm "? lost (CHKDSK /F)  ! two files claim it (CHKDSK)"
	defb 13,10,13,10,0
m_files:
	defm " files, "
	defb 0
m_inpcs:
	defm " of them in pieces ("
	defb 0
m_pcs:	defm " pieces); "
	defb 0
m_dirs: defm " directories"
	defb 13,10,0
m_kbfree:
	defm " KB free, in "
	defb 0
m_runs: defm " runs; the largest "
	defb 0
m_kbbig:
	defm " KB"
	defb 13,10,0
m_nbad: defm " clusters marked bad"
	defb 13,10,0
m_nlost:
	defm " lost clusters (CHKDSK /F frees them)"
	defb 13,10,0
m_crossed:
	defm "Broken or crossed chains: run CHKDSK /F"
	defb 13,10,0
m_worst:
	defm "In the most pieces:"
	defb 13,10,0
m_nofrag:
	defm "No file is in pieces: nothing to do."
	defb 13,10,0
m_sure: defm "Move the files in pieces on "
	defb 0
m_sure2:
	defm ":?  (A copy of anything you cannot lose is wise.)  Y/N "
	defb 0
m_unsound:
	defm "Not with lost, broken or crossed chains: run CHKDSK /F first"
	defb 0
m_moving:
	defm "moving "
	defb 0
m_noroom:
	defm "no free run that big: left as it is"
	defb 0
m_done: defm "done"
	defb 0
m_moved:
	defm " files moved into one piece"
	defb 13,10,0
m_left: defm " found no free run as big as they are (more free space would help)"
	defb 13,10,0

	include "PROGRAMS/PLIB.INC"
