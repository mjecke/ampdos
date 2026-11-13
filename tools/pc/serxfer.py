#!/usr/bin/env python3
"""
This is the current way to copy single files between a host computer 
(with python) and the ampDOS machine over Serial B.  

pip install pyserial

serxfer.py [PORT] send FILE [DOSNAME]   PC -> Ampro  (in ampDOS: SERRECV [name])
serxfer.py [PORT] get [FILE]            Ampro -> PC  (in ampDOS: SERSEND [name])

PORT is optional: /dev/cu.usbserial-210 is first (hardcoded because that is my 
dev machine's adapter), else the first USB serial adapter found
(on Windows give COM3 or similar).  9600 baud 8N1.

DOSNAME: the 8.3 name the file gets on the Ampro if SERRECV is run without a 
name (default: FILE's own name, upper case). 

Start the trasnfer from the two computer sides in either order.

The protocol (the Ampro side is KERNEL/CMD/XFER.ASM, built into ampDOS):
Ampro: SYN 'R' (SERRECV) or SYN 'S' (SERSEND), once a second; PC answers 'G'
header: 'F' size(4, low first) name(13, 0-padded)        -> ACK, or 'E' code
blocks: 'D' length(1, 0 = 256) data sum(2: 16-bit sum)   -> ACK / NAK / 'E' code
end:    'Z'
"""
import sys, os, glob, time

SYN, ACK, NAK = 0x16, 0x06, 0x15
BLOCK, TRIES = 256, 10
ERRORS = {0: "it gave up", 1: "disk read error", 2: "not a FAT12 disk", 3: "not a 360K disk",
          4: "broken cluster chain", 5: "file not found", 6: "bad file name",
          7: "that is a directory", 8: "disk full", 9: "directory full",
          10: "a file with that name exists", 11: "disk write error",
          12: "not a directory", 13: "directory not empty", 14: "bad path",
          15: "no disk in the drive"}

class Failed(Exception):
    pass

# ---- the protocol, as generators: they yield ('read', n) and get bytes back,
#      or yield ('write', data).  run() drives them over a serial port

def wait_for(letter):
    """skip whatever arrives (console text) until SYN + letter"""
    prev = 0
    while True:
        b = (yield ('read', 1))[0]
        if prev == SYN and b == letter:
            return
        prev = b

def reply():
    r = (yield ('read', 1))[0]
    if r == ord('E'):
        code = (yield ('read', 1))[0]
        raise Failed("the Ampro says: " + ERRORS.get(code, "error %d" % code))
    return r

def proto_send(data, dosname, show=print):
    """PC -> Ampro: the Ampro runs SERRECV"""
    yield from wait_for(ord('R'))
    yield ('write', b'G')
    yield ('write', b'F' + len(data).to_bytes(4, 'little') + dosname.encode().ljust(13, b'\0')[:13])
    if (yield from reply()) != ACK:
        raise Failed("the Ampro did not take the header")
    for o in range(0, len(data), BLOCK):
        blk = data[o:o + BLOCK]
        pkt = b'D' + bytes([len(blk) & 255]) + blk + (sum(blk) & 0xFFFF).to_bytes(2, 'little')
        for t in range(TRIES):
            yield ('write', pkt)
            r = yield from reply()
            if r == ACK:
                break
        else:
            raise Failed("block at %d sent %d times without success" % (o, TRIES))
        show(o + len(blk))
    if (yield ('read', 1))[0] != ord('Z'):
        raise Failed("no end mark from the Ampro")

def proto_get(show=print):
    """Ampro -> PC: the Ampro runs SERSEND.  Returns (name, data)."""
    yield from wait_for(ord('S'))
    yield ('write', b'G')
    hdr = yield ('read', 18)
    if hdr[0] != ord('F'):
        raise Failed("no header from the Ampro")
    size = int.from_bytes(hdr[1:5], 'little')
    name = hdr[5:18].split(b'\0')[0].decode('ascii', 'replace')
    yield ('write', bytes([ACK]))
    data = bytearray()
    while len(data) < size:
        want = min(BLOCK, size - len(data))
        head = yield ('read', 2)
        if head[0] != ord('D') or (head[1] or 256) != want:
            raise Failed("the Ampro's blocks are out of step")
        body = yield ('read', want + 2)
        blk, s = body[:want], int.from_bytes(body[want:], 'little')
        if sum(blk) & 0xFFFF == s:
            data += blk
            yield ('write', bytes([ACK]))
            show(len(data))
        else:
            yield ('write', bytes([NAK]))
    if (yield ('read', 1))[0] != ord('Z'):
        raise Failed("no end mark from the Ampro")
    return name, bytes(data)

# ---- driving them over a real serial port

def run(gen, ser, first_wait=120, wait=30):
    """first_wait: seconds to wait for the Ampro to start; wait: for each answer"""
    try:
        req = next(gen)
        started = False
        while True:
            if req[0] == 'write':
                ser.write(req[1])
                req = gen.send(None)
            else:
                n, buf = req[1], b''
                end = time.time() + (wait if started else first_wait)
                while len(buf) < n:
                    part = ser.read(n - len(buf))
                    if part:
                        buf += part
                    elif time.time() > end:
                        raise Failed("the Ampro does not answer" if started else
                                     "the Ampro did not start (run SERRECV / SERSEND there)")
                req = gen.send(buf)
                if not started and req[0] == 'write' and req[1] == b'G':
                    started = True
    except StopIteration as e:
        return e.value

DEFAULT_PORT = "/dev/cu.usbserial-210"

def find_port():
    if os.path.exists(DEFAULT_PORT):
        return DEFAULT_PORT
    for pat in ("/dev/cu.usbserial*", "/dev/cu.usb*", "/dev/ttyUSB*"):
        found = sorted(glob.glob(pat))
        if found:
            return found[0]
    sys.exit("No USB serial adapter found: plug it in or give the port name.")

def dos83(path):
    base = os.path.basename(path).upper()
    stem, _, ext = base.partition('.')
    return stem[:8] + ('.' + ext[:3] if ext else '')

def main():
    args = sys.argv[1:]
    port = None
    if args and (args[0].startswith('/dev/') or args[0].upper().startswith('COM')):
        port = args.pop(0)
    if not args or args[0] not in ('send', 'get') or (args[0] == 'send' and len(args) < 2):
        sys.exit(__doc__)
    try:
        import serial
    except ImportError:
        sys.exit("pyserial is missing:  pip install pyserial")
    ser = serial.Serial(port or find_port(), 9600, bytesize=8, parity='N', stopbits=1, timeout=0.5)
    progress = lambda n: print("\r  %d bytes" % n, end='', flush=True)
    try:
        if args[0] == 'send':
            data = open(args[1], 'rb').read()
            name = args[2] if len(args) > 2 else dos83(args[1])
            print("sending %s (%d bytes) as %s: waiting for SERRECV on the Ampro..." % (args[1], len(data), name))
            run(proto_send(data, name, progress), ser)
            print("\ndone")
        else:
            print("waiting for SERSEND on the Ampro...")
            name, data = run(proto_get(progress), ser)
            out = args[1] if len(args) > 1 else name
            open(out, 'wb').write(data)
            print("\nsaved %d bytes as %s" % (len(data), out))
    except Failed as e:
        sys.exit("\nfailed: %s" % e)
    except KeyboardInterrupt:
        sys.exit("\nstopped")

if __name__ == '__main__':
    main()
