#!/bin/sh
# ampcc.sh - compile a C program with uc80 into an ampDOS .BIN (loads at 8000h)
#   ./ampcc.sh [-f] prog.c [more.c ...]      -> PROG.BIN
# Needs: pip install uc80 um80, and ampcrt0.mac, ampbdos.mac, ampdos.h and lib/
# next to this script.  #include "ampdos.h" for system() and the os_ functions.
#
# It links once with the file functions in the stub, and looks at what the
# linker put in: a program with no fopen, freopen, tmpfile, remove or rename
# can never reach a file, so it is linked again with the console-only stub
# (about 1.2 KB smaller, and 1 KB more memory).  -f keeps the file stub
# anyway (for a program that calls the BDOS file functions itself).
set -e
force=0
if [ "$1" = "-f" ]; then force=1; shift; fi
here=$(cd "$(dirname "$0")" && pwd)
lib=$(uc80 --print-lib-dir)
out=$(basename "$1" .c | tr a-z A-Z).BIN
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

uc80 --no-embed-startup -I "$here" "$@" -o "$tmp/prog.mac"
for m in "$here"/lib/*.mac; do         # ampdos.h's functions: a library, so
    um80 "$m" -o "$tmp/$(basename "$m" .mac).rel" >/dev/null   # only those used are linked
done
ulib80 -c "$tmp/ampdos.lib" "$tmp"/os*.rel "$tmp"/system.rel >/dev/null
um80 "$tmp/prog.mac" -o "$tmp/prog.rel" >/dev/null

link() {        # $1 = 1 with files, 0 the console alone
    um80 -D FILES=$1 "$here/ampcrt0.mac" -o "$tmp/ampcrt0.rel" >/dev/null
    um80 -D FILES=$1 "$here/ampbdos.mac" -o "$tmp/ampbdos.rel" >/dev/null
    if [ "$1" = 1 ]; then top=F7FD; else top=FBFD; fi
    ul80 --bin -p 8000 --ram-end $top -o "$out" -S "$tmp/prog.sym" \
         "$tmp/ampcrt0.rel" "$tmp/prog.rel" "$tmp/ampbdos.rel" \
         "$tmp/ampdos.lib" "$lib/libc.lib" "$lib/runtime.lib" >/dev/null
}

link 1
how="with files"
if [ $force = 0 ] && ! grep -qiE '\b_(fopen|freopen|tmpfile|remove|rename)\b' "$tmp/prog.sym"; then
    link 0
    how="console only"
fi
echo "$out: $(wc -c < "$out") bytes ($how)"
