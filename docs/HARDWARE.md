# The AMPRO Little Board/Z80: hardware notes

The board's ports, the WD1772 floppy controller, and what was measured on a
real board while writing ampDOS's driver (`KERNEL/MACHINE/AMPRO/FD.ASM`). Read
this before changing the floppy code: much of it is not obvious from the
datasheets.

---------------------------------------------------------------------------------------------

## 1. Hardware reference

### 1.1 I/O ports

| Port | Name | Use |
|------|------|-----|
| 00h  | BCR  | Board control register (write) |
| C0h  | FCMD | WD1772 command (write) / status (read at C4h, see below) |
| C1h  | FTRK | track register write (read at C5h) |
| C2h  | FSEC | sector register write |
| C3h  | FDAT | data register write |
| C4h  | FSTA | status register read |
| C5h  | FRTRK| track register read |
| C7h  | FRDAT| data register read |
| 80h / 84h | DART A data / control | console (Serial A) |
| 88h / 8Ch | DART B data / control | Serial B (the PC link) |
| 40h  | CTC ch0 | baud rate generator for DART A (the console) |
| 50h  | CTC ch1 | baud rate generator for DART B |
| 60h  | CTC ch2 | free-running timer |
| 29h  | ID   | the board's ID jumpers (input) |

Reads of the 1772 registers use C4h (status), C5h (track), C6h (sector, rarely needed), C7h (data).
Writes use C0h (command), C1h (track), C2h (sector), C3h (data). The names are in
`KERNEL/MACHINE/AMPRO/HW.INC`.

### 1.2 BCR (port 00h)

| Bit | Meaning |
|-----|---------|
| 0 | select drive A |
| 1 | select drive B |
| 4 | side select: 0 = side 0, 1 = side 1 |
| 5 | /DDEN: **0 = double density (MFM)**, which is what is always used |
| 6 | ROM disable: 1 = all 64 K is RAM. ampDOS runs this way (BCR = 41h / 51h for drive A). **Floppy access works fine with it set** |
| 7 | FDC clock select (never used or tested) |

The register is write-only so the driver keeps a copy of the value it last wrote.

### 1.3 WD1772 commands

| Command | Hex | Notes |
|---------|-----|-------|
| Restore | `05h` | step out to track 0, **V=1 verifies** (reads an ID). Status afterwards `A4h` = good. `B6h` just means "verify found a different cylinder than the track register" |
| Restore, no verify | `08h` | h = 1: works with no disk in the drive (4.9) |
| Seek (no verify) | `10h`/`11h` | target track in FDAT (C3h), current track in the track register. No settle delay, no verify. Used for formatting blank tracks |
| Seek (verify) | `14h`/`15h` | the same, with the 15 ms settle and an ID verify. For normal access |
| Read sector | `80h` | single sector (E = 0: no 15 ms delay, so that sectors can follow each other) |
| Write sector | `A0h` | single sector |
| Read address | `C4h` | returns 6 bytes: cyl, side, sec, size code, CRC1, CRC2. **The best diagnostic tool**: it tells you what is physically under the head |
| Write track | `F4h` | formats a track from a stream of bytes (see 3) |
| Force interrupt | `D0h` | abort. **Afterwards the status register shows Type I bits**, not Type II/III |

The low two bits of the Type I commands are the step rate (1.3, 4.7: only 6 ms works).
Wait about 65 microseconds after issuing any command before reading status, so the 1772 has
time to raise BUSY (a `djnz` loop of 20 is about right at 4 MHz).

### 1.4 Status register (C4h)

Type II/III (read/write sector, address, track):

| Bit | Meaning |
|-----|---------|
| 7 | motor on (on the 1772 this is MOTOR ON, not "not ready") |
| 6 | write protect |
| 5 | record type / write fault |
| 4 | record not found (RNF) |
| 3 | CRC error |
| 2 | lost data |
| 1 | DRQ (a data byte is waiting / wanted) |
| 0 | busy |

Type I (restore, seek, step): 7 motor on, 6 write protect, 5 head loaded, 4 seek error,
3 CRC error, 2 track 0, 1 index, 0 busy.

Typical error masks: after a read use `AND 1Ch`, after a write or format use `AND 7Ch`.
Status `90h` after a read means motor on + RNF (the ID you asked for isn't there).

### 1.5 Serial B (the PC link)

9600 baud (the board really runs 9615), 8N1, no flow control.

```
        ld   a,47h        ; CTC ch1: timer, prescale 16, time-constant follows
        out  (50h),a
        ld   a,13         ; divisor -> 9615 baud
        out  (50h),a
        ld   hl,SBTAB     ; DART B init string
        ld   b,9
        ld   c,8Ch
        otir
SBTAB:  defb 18h,04h,44h,01h,00h,03h,0C1h,05h,0EAh
```

Poll `in a,(8Ch)`: bit 0 = receive byte available (read it at 88h), bit 2 = transmit buffer empty (write at 88h).
The DART has only a 3-byte receive FIFO, so a polled receiver must not do anything slow.
After a block, read register 1 (`out (8Ch),01h` then `in a,(8Ch)`) and check `AND 70h` for overrun/framing/parity errors.

---------------------------------------------------------------------------------------------

## 2. Disk geometry and layout

Everything here is the standard DOS 360K format: 40 cylinders, 2 sides, 9 sectors per track,
512 bytes per sector, MFM at 250 kbit/s, 300 rpm. Sectors are numbered **1 to 9** in the ID fields.

- Total 720 sectors (LBA 0..719).
- LBA to CHS: `track = LBA / 9`, `sector = LBA % 9 + 1`, `side = track & 1`, `cylinder = track >> 1`.
- Image files (`.img`, 368640 bytes) are in LBA order: cylinder 0 side 0, cylinder 0 side 1, cylinder 1 side 0, ...
- One 4608-byte block in the IMGWRITE protocol = one track = 9 sectors.

### 2.1 Physical interleave vs access order

The disk is formatted 1:1 (sectors 1..9 in order). A single-sector command cannot be
issued fast enough to catch the next sector, so reading sector after sector in order costs
a whole revolution per sector (200 ms). Whole-track transfers visit the sectors in steps
of 2 (1,3,5,7,9,2,4,6,8): two turns for the track (4.7).

---------------------------------------------------------------------------------------------

## 3. Formatting (Write Track)

The Write Track stream is an IBM System 34 MFM track. In the 1772's Write Track command,
certain byte values are special: `F5h` writes the A1 sync byte (missing clock), `F6h` writes C2,
`F7h` writes the 2-byte CRC. The image is 6400 bytes, more than one turn (6250 bytes): the
controller ends the track at the index pulse, and the rest is never sent.

```
 80 x 4Eh                      gap 4a
 12 x 00h
  3 x F6h                      -> C2 C2 C2
     FCh                       index mark
 50 x 4Eh                      gap 1
 then for each sector s = 1..9:
 12 x 00h
  3 x F5h                      -> A1 A1 A1
     FEh                       ID address mark
     cyl, side, s, 02h         02 = 512-byte sectors   (cyl and side are patched per track)
     F7h                       CRC
 22 x 4Eh                      gap 2
 12 x 00h
  3 x F5h
     FBh                       data address mark
512 x E5h                      fill byte
     F7h                       CRC
 80 x 4Eh                      gap 3
 then 4Eh padding up to 6400 bytes total
```

The nine ID fields sit 652 bytes apart; the first cylinder byte is at offset 162
(`fd_mk_image` builds it, and each track patches `cyl` and `side`). The stream loop:

```
        ld   hl,TMPL
        ld   c,FDAT
        ld   b,0
        ld   d,25
WT1:    in   a,(FSTA)
        rrca
        jr   nc,WTE        ; not busy: finished (or refused)
        rrca
        jr   nc,WT1        ; wait for DRQ
        outi               ; send a byte
        jp   nz,WT1
        dec  d
        jr   nz,WT1
WT2:    in   a,(FSTA)      ; template used up: wait for the index pulse to end the track
        rrca
        jr   c,WT2
WTE:    in   a,(FSTA)
        and  7Ch           ; non-zero = error
```

### 3.1 The order for formatting a track

1. Step (seek without verify, with the target track in FDAT) with the side that is currently
   selected, and wait for the controller to become idle (see 4.1 on how long).
2. Wait about 30 ms for the head to settle.
3. Select the side in BCR, wait again.
4. Issue `F4h` and stream the image.
5. Read the track back to check it.

---------------------------------------------------------------------------------------------

## 4. Details on the driver working

### 4.1 Busy-waits must outlast motor spin-up

If the motor has been idle (it switches off after roughly 10 idle revolutions, about 2 seconds),
a command with the h bit clear first waits for **6 index pulses (about 1.2 s at 300 rpm)**
before doing anything. Any code that gives up waiting for BUSY to clear after less than that, and
then issues the next command or starts pushing data, produces a mess:

- Write Track fails with lost data (status `86h`).
- Seeks apparently do not happen (`FRTRK` stays behind the target).
- Tracks are written one cylinder out, with the first sector missing, because they were
  written at the wrong physical position while the track register said otherwise.
- Writes to the data register while a seek is pending corrupt the seek target.

A wait that gives up after 0.8 s passes every back-to-back test and fails only after a pause
(IMGWRITE waits seconds for each track from the PC). **Every wait on BUSY needs a timeout of at
least 3 seconds**: `fd_wait` waits about 3.4 s.

### 4.3 Always restore before the first access

After a reset or after another program, the head's physical position is unknown. The 1772's track
register is just a number. If it says 0 and the head is really on cylinder 1, every read of "track 0" fails
with RNF (`90h`). The driver restores each drive and waits for it before its first access.

### 4.4 Use Read Address to see the truth

When something is wrong, issue `C4h` repeatedly and print cylinder / side / sector. If the ID cylinder
does not match the track register, the head or the format is off.

### 4.5 Miscellaneous

- **Running this floppy driver code from a ROM doesn't work** 
  (the EPROM is seemingly too slow for the data loops). The OS
  runs from RAM with the ROM switched off.
  Reads work from the ROM, which is how it boots ampDOS.
- Force interrupt (`D0h`) changes the status register to Type I meaning. 
   Don't interpret bit 4 as RNF afterwards.
- A seek with verify includes the 15 ms settle; without verify there is none, so add a delay.
- When a read fails, "restore, seek, read" again is enough; the driver tries three times.
- The driver keeps the BCR side bit in sync and waits for the side only **when it changes**,
  to avoid paying for it on every sector.
- Don't poll the keyboard or write to the console in the middle of a track transfer.

### 4.6 The transfer loop's speed

This part took me forever to figure out. 
The symptom of a loop that is too slow: sector writes fail at random with status `84h` (motor on +
lost data), about 1 write in 10, whatever the sector order, side delay or command bits. The command
does not abort: the 1772 writes a zero byte in place of the missed one and carries on, so a
retry takes no longer. Reads with an equally slow loop seldom fail, so it looks like a write-only
problem.

A loop that polls the status, tests DRQ, tests BUSY, counts a timeout and then moves the byte can
take up to ~25 us to answer DRQ. A byte passes every 32 us, and the controller wants the next
byte before that. AMPRO's own loop (in its `AD.ASM` 3.3: test BUSY, then DRQ) is no faster and
failed even more often. Command bits make no real difference (`A0`, `A8` = spin-up check
off, `A4` = 15 ms settle; 100 writes each).

So `fd_rd_sector` / `fd_wr_sector` work in three phases:

1. Wait for the first DRQ in an ordinary loop with a timeout (BUSY dropping first = error).
2. Move the **first byte at once**, then the other 511 with the tightest loop possible:

   ```
   loop: in   a,(FSTA)
         rrca               ; CF = BUSY
         jr   nc,short      ; command ended early: a byte was missed -> error
         rrca               ; CF = DRQ
         jr   nc,loop
         ini / outi         ; C = data port, B counts 255, then a pass of 256
         jr   nz,loop
   ```

   One poll is 38 T-states (9.5 us at 4 MHz); DRQ is answered within ~18 us. Keep the BUSY test:
   without it, one missed DRQ hangs the loop forever (the controller sends no more requests).
3. Wait for BUSY to clear (the 1772 checks or writes the CRC) and check the status.

The first byte matters because a **read gives no extra time for byte 0**: it is overwritten 32 us
after DRQ like any other byte. (A write does give slack: the 1772 waits 22 byte times after the ID
for the first byte.) Setting up registers between the first DRQ and the first `INI` takes ~33 us
and breaks every read on the board.

Measured: 0 failures in 300 writes (the slow loop: 12 in 100), 10 verified track writes in a row.

### 4.7 Measured numbers

- Step rate: only 6 ms (`r1 r0 = 00`) works; 3 ms and 2 ms lose steps.
- Side-select delay: reads work even with none; the driver uses ~2 ms. AMPRO's utility uses 50 ms.
- A full track read takes ~0.26 s (one disk turn is 0.2 s).
- A full track write visiting sectors in steps of 2 (1,3,5,7,9,2,4,6,8) takes ~0.41 s: two turns.
  In order 1..9 it misses the next sector each time and takes ~1 s.

### 4.8 Two drives, formatting, and verifying

- **Drive select**: BCR bit 0 selects drive A, bit 1 drive B (as in AMPRO's AD.ASM: drive n -> bit n).
  The WD1772 has **one** track register for both drives: before switching, save the track
  register (read C5h) for the old drive, and write the new drive's saved value to C1h. A drive
  that was never used is restored first.
- **Write Track needs index pulses**: the command starts and ends at the index hole and has no
  timeout of its own, so with no disk turning (or the door open) it waits for ever. Before
  formatting, watch status bit 1 (the index input, valid after a Type I command) for about a
  second and refuse if it never rises.
- **Seek without verify when formatting**: a seek with verify fails on a blank track.
  Use 10h + the step bits, then wait ~30 ms for the head to settle.
- **Check a format by reading it back**, not just by the Write Track status: an image with a
  wrong sector number in its ID fields writes without error, and nothing can read it.
- **The verify buffer**: reading a written track back must not use a buffer the caller may be
  writing from. The read-back has a buffer of its own (and checks only the CRC: a byte lost
  while writing already shows in the write status).

### 4.9 An empty drive

With no disk, every command that needs the index hole (any read, write, read address, or a
seek with verify) waits until the driver's own ~3.4 s timeout, and the retries multiply that
to half a minute. The quick test that works:

1. Seek to the track the head is on, **without verify and with h = 1** (`18h` + step bits).
   It ends at once, disk or no disk, and turns the motor on.
2. Watch status bit 1 (the index input; valid after a Type I command) for ~1 s. Count only a
   change from 0 to 1 that happens after you start looking: the hole is visible for a few
   ms, so a check started while it shows must wait for the next one.
3. If the motor was off before (status bit 7 was 0), wait ~5 more turns: the controller
   saw the motor on and will not do its own spin-up wait for the next command.

Restoring a drive that was never used the same way (`08h`: restore, h = 1, no verify) also
works without a disk, so switching to an empty drive B costs no time either.


---------------------------------------------------------------------------------------------

## 6. Known gaps

- BCR bit 7 and its effect on the FDC clock (and so on step rates and bit rates) are unexplored.
- 5.25" 360K double-density media only. 80-track drives and high density are untested.
- The console is polled, so keys typed during long disk operations can be lost (3-byte DART FIFO).
