#!/usr/bin/env python3
"""The source disks: ampDOS's own sources on 360K floppies, for ASM to build ampDOS with.

    build.py makes them (release/ampdos_src1.img to ampdos_src3.img)
    python3 tools/build/srcdisk.py --pack FILE ...   tab-pack sources in place

The sources in KERNEL/ and PROGRAMS/ are kept the way they go on the disks: 8.3
names in capitals, runs of spaces as tabs (at 8-column stops, as an editor shows
them), no trailing spaces, LF line ends (as EDIT keeps them).  So they are copied
onto a disk as they are, at the same paths.  (They would not fit with spaces:
about 550 KB of source becomes 400 KB.)  A source that is not packed stops the
build; --pack packs it.

What the sources include and nobody edits is made by build.py under build/, at
the path it has on the disk (build/GEN/VERSION.INC is GEN\\VERSION.INC there,
build/PROGRAMS/BASIC/BASIC.ASM is PROGRAMS\\BASIC\\BASIC.ASM): those are packed
as they are copied.  Files under BIN/ (incbin'd) are made on the Ampro by BUILD.
"""
import os, re, subprocess, sys

def compact(text):
    """spaces -> tabs outside quotes, no trailing spaces, LF"""
    out = []
    for line in text.replace('\r\n', '\n').split('\n'):
        res, col, run, quote = '', 0, 0, None
        for c in line.rstrip():
            if c == ' ' and quote is None:
                run += 1
                col += 1
                if col % 8 == 0:                 # a tab stop: the run becomes a tab
                    res += '\t' if run > 1 else ' '
                    run = 0
                continue
            res += ' ' * run
            run = 0
            if quote:
                if c == quote:
                    quote = None
            elif c in '"\'' and not res.lower().endswith('af,af'):
                quote = c
            elif c == ';':
                quote = ';'                      # a comment: no more quotes to watch
            res += c
            col = (col // 8 + 1) * 8 if c == '\t' else col + 1
        out.append(res)
    while out and out[-1] == '':
        out.pop()
    return '\n'.join(out) + '\n'

def is83(path):
    return all(re.fullmatch(r'[A-Z0-9_$~!#%&@^-]{1,8}(\.[A-Z0-9_]{1,3})?', p) for p in path.split('/'))

def where(name):
    """a name as a source gives it -> (the file here, generated?)"""
    if os.path.exists(name):
        return name, False
    if os.path.exists('build/' + name):
        return 'build/' + name, True
    sys.exit(f'srcdisk: {name} is included but not there (run build.py)')

def tree(name, acc):
    """name and every file it includes (incbin'd files too), as disk paths"""
    if name not in acc:
        acc.append(name)
    for line in open(where(name)[0], errors='replace'):
        m = re.match(r'\s*\w*:?\s*(include|incbin)\s+"([^"]+)"', line, re.I)
        if m and m.group(2) not in acc:
            if m.group(1).lower() == 'include':
                tree(m.group(2), acc)
            else:
                acc.append(m.group(2))
    return acc

def put(img, names, tmp):
    """copy files to the disk image at their paths (generated ones packed)"""
    made = set()
    os.makedirs(tmp, exist_ok=True)
    for name in names:
        if not is83(name):
            sys.exit(f'srcdisk: {name}: not an 8.3 name in capitals')
        f, generated = where(name)
        data = open(f, 'rb').read()
        if generated:
            data = compact(data.decode('latin-1')).encode('latin-1')
        elif data.decode('latin-1') != compact(data.decode('latin-1')):
            sys.exit(f'srcdisk: {name} is not packed: python3 tools/build/srcdisk.py --pack {name}')
        parts = name.split('/')
        d = ''
        for p in parts[:-1]:
            d += '/' + p
            if d not in made:
                subprocess.run(['mmd', '-i', img, '::' + d], check=True, stderr=subprocess.DEVNULL)
                made.add(d)
        t = os.path.join(tmp, parts[-1])
        open(t, 'wb').write(data)
        subprocess.run(['mcopy', '-i', img, t, '::' + name], check=True)

def make(out, sources, root, dirs, tmp, label):
    """a disk: root = files for its root directory (mkdisk), the folders dirs,
    sources (and all they include) at their paths.  -> bytes free"""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import mkdisk, contextlib, io
    names = []
    for src in sources:
        tree(src, names)
    with contextlib.redirect_stdout(io.StringIO()):
        mkdisk.make(out, root, boot_code=open("build/BIN/BOOTSEC.BIN", "rb").read(), label=label)
    for d in dirs:
        subprocess.run(['mmd', '-i', out, '::/' + d], check=True)
    put(out, [n for n in names if not n.startswith('BIN/')], tmp)
    info = subprocess.run(['mdir', '-i', out, '::/'], capture_output=True, text=True).stdout
    m = re.search(r'([\d ]+) bytes free', info)
    return int(m.group(1).replace(' ', '')) if m else -1

if __name__ == '__main__':
    if len(sys.argv) < 3 or sys.argv[1] != '--pack':
        sys.exit(__doc__)
    for f in sys.argv[2:]:
        t = open(f, encoding='latin-1').read()
        open(f, 'w', encoding='latin-1', newline='').write(compact(t))
