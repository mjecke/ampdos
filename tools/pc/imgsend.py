#!/usr/bin/env python3
"""Send a 360K disk image to IMGWRITE on the Ampro over Serial B.   

  pip install pyserial

  imgsend.py [PORT] disk.img

On the Ampro (ampDOS):
  IMGWRITE A: (or B:)   then put the disk to write in, and press Y.
Start the two sides in either order.  The Ampro asks for each of the 80
tracks (4608 bytes), checks its sum, formats, writes and reads it back, then
asks for the next.  About 8 minutes for a full disk; empty tracks (all one
byte) go as 3 bytes instead of 4611, so a disk that is mostly empty, like the
ampDOS boot disk, takes 2-3 minutes.  A status line shows
it: a spinner until the Ampro answers, then a bar with the track being sent
(and how much of it), the Ampro writing it, and the time left.

PORT: as for serxfer.py (/dev/cu.usbserial-210, else the first USB serial
adapter; COM3 or similar on Windows -- I hardcoded my usbserial-210 as default
here to be sure it was selected every time on my mac as I was doing development)

9600 baud 8N1.
"""
import sys, os, glob, time

SYN, TRK, NTRK, SIZE = 0x16, 4608, 80, 368640
ERRS = {1: "a track could not be written and read back (a bad disk?)",
        2: "it stopped hearing from the PC", 3: "Esc was pressed on the Ampro"}
DEFAULT_PORT = "/dev/cu.usbserial-210"

def find_port():
    if os.path.exists(DEFAULT_PORT):
        return DEFAULT_PORT
    for pat in ("/dev/cu.usbserial*", "/dev/cu.usb*", "/dev/ttyUSB*"):
        found = sorted(glob.glob(pat))
        if found:
            return found[0]
    sys.exit("No USB serial adapter found: plug it in or give the port name.")

SPIN = "|/-\\"
CHUNK = 256                                # bytes sent between progress updates

class Status:
    """one status line, rewritten in place"""
    def __init__(self):
        self.started = None                # when the first track was asked for
        self.done = 0                      # tracks written and checked on the Ampro
        self.width = 0
    def show(self, text):
        pad = max(0, self.width - len(text))
        print("\r" + text + " " * pad, end="", flush=True)
        self.width = len(text)
    def bar(self, track, what, part=0.0):
        """track (0-79), what is happening, part of this track sent (0-1)"""
        frac = (self.done + part) / NTRK
        n = int(frac * 16)
        el = time.time() - self.started
        left = ""
        if self.done:
            left = f", ~{el / self.done * (NTRK - self.done) / 60:.1f} min left"
        self.show(f"[{'#' * n}{'.' * (16 - n)}] {frac * 100:3.0f}%  {track + 1:2d}/{NTRK} "
                  f"{what}  {el / 60:.1f} min{left}")

def send_track(ser, st, t, blk, again, fills):
    """the track, a chunk at a time, the bar moving as it goes out.  A track of
    one byte only goes as 'F' b b, if the Ampro understands it (fills)"""
    if fills and blk.count(blk[0]) == TRK:
        ser.write(b'F' + bytes([blk[0], blk[0]]))
        st.bar(t, f"empty, Ampro formatting{again}", 0.5)
        return
    pkt = b'D' + blk + (sum(blk) & 0xFFFF).to_bytes(2, 'little')
    for i in range(0, len(pkt), CHUNK):
        ser.write(pkt[i:i + CHUNK])
        ser.flush()                        # (waits until it is on the wire)
        st.bar(t, f"sending{again} {min(100, (i + CHUNK) * 100 // len(pkt)):3d}%",
               min(1.0, (i + CHUNK) / len(pkt)) * 0.5)
    st.bar(t, f"Ampro writing{again}", 0.5)

def main():
    args = sys.argv[1:]
    port = None
    if args and (args[0].startswith('/dev/') or args[0].upper().startswith('COM')):
        port = args.pop(0)
    if len(args) != 1:
        sys.exit(__doc__)
    data = open(args[0], 'rb').read()
    if len(data) != SIZE:
        sys.exit(f"{args[0]} is {len(data)} bytes: a 360K image is {SIZE}")
    try:
        import serial
    except ImportError:
        sys.exit("pyserial is missing:  pip install pyserial")
    ser = serial.Serial(port or find_port(), 9600, bytesize=8, parity='N', stopbits=1, timeout=0.25)
    print(f"{args[0]}: on the Ampro, run IMGWRITE and press Y (Ctrl-C here stops)")
    st = Status()
    prev, waited, last, spin = 0, time.time(), time.time(), 0
    done, heard, fills, nI = set(), False, False, 0
    while True:
        b = ser.read(1)
        if not b:
            quiet = time.time() - last
            if quiet > (900 if not done else 120):
                sys.exit("\nthe Ampro has not said anything for a long time: giving up")
            spin += 1
            if not done:
                what = "the Ampro is there, starting" if heard else "waiting for the Ampro"
                st.show(f"{SPIN[spin % 4]} {what}...  {time.time() - waited:.0f} s")
            elif quiet > 20:               # a track takes ~6 s on the Ampro: say if it is slow
                st.bar(max(done), f"Ampro busy {quiet:.0f} s {SPIN[spin % 4]}", 0.5)
            continue
        last = time.time()
        c = b[0]
        if prev == SYN and c == ord('J'):          # the Ampro is waiting to start, and
            ser.write(b'G')                        # takes 'F' for empty tracks
            heard = fills = True
        elif prev == SYN and c == ord('I') and not fills:
            nI += 1                                # an IMGWRITE that asks for I only:
            if nI >= 2:                            # every track in full
                ser.write(b'G')
                heard = True
        elif c == ord('T'):                        # it asks for a track
            t = ser.read(1)
            if not t or t[0] >= NTRK:
                prev = c
                continue
            t = t[0]
            if st.started is None:
                st.started = time.time()
                if st.width:
                    print()                        # (keep the waiting line)
                    st.width = 0
            st.done = t                            # every track before it is written and checked
            again = " (again)" if t in done else ""
            done.add(t)
            send_track(ser, st, t, data[t * TRK:(t + 1) * TRK], again, fills)
        elif c == ord('Z'):
            st.done = NTRK
            st.bar(NTRK - 1, "done")
            print(f"\ndone: all {NTRK} tracks written and checked on the Ampro, "
                  f"in {(time.time() - st.started) / 60:.1f} min")
            return
        elif c == ord('E'):
            code = ser.read(1)
            code = code[0] if code else 0
            sys.exit("\nthe Ampro stopped: " + ERRS.get(code, f"error {code}"))
        prev = c

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit("\nstopped")
