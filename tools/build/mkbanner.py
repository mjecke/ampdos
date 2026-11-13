#!/usr/bin/env python3
"""Pack KERNEL/CMD/BANNER.TXT into GEN/BANNER.INC for BANNER.ASM.
"""
import collections, os
import sys
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
src = os.path.join(root, 'KERNEL', 'CMD', 'BANNER.TXT')
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, 'build', 'GEN', 'BANNER.INC')
lines = [l.rstrip() for l in open(src).read().rstrip('\n').split('\n')]
stream = '\n'.join(lines) + '\n\0'               # a line end after the last line too, then the end mark
order = [ch for ch, n in collections.Counter(stream).most_common() if ch != '\0'] + ['\0']
bits = ''.join('1' * order.index(ch) + '0' for ch in stream)
bits += '0' * (-len(bits) % 8)
data = [int(bits[i:i + 8], 2) for i in range(0, len(bits), 8)]
def row(bs): return '        defb ' + ','.join('%03Xh' % b for b in bs)
with open(out, 'w') as f:
    f.write('; made by tools/build/mkbanner.py from BANNER.TXT (%d characters -> %d bytes): do not edit\n'
            % (len(stream), len(data)))
    f.write('bn_tab:\n' + row(ord(c) for c in order) + '\n')
    f.write('bn_data:\n' + '\n'.join(row(data[i:i + 16]) for i in range(0, len(data), 16)) + '\n')
print('banner: %d characters, %d table + %d data bytes' % (len(stream), len(order), len(data)))
