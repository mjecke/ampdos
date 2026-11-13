#!/usr/bin/env python3

""" Build program for the ampDOS Operating System for z80 Little Board and 
    similar machines.
    This script builds the OS and all it's programs, along with a BASIC 
    interpreter, and packs the released boot disk and source disks as images.

    python3 build.py                       everything
    python3 build.py NAME ...              only these (and what they need), e.g. ampdos basic
    python3 build.py --machine NAME ...    to specific a specific machine (currently only AMPRO)

Needs z80asm (Bas Wijnen's, 1.8) and Python; the source disks also need the
mtools programs.  How it goes:

  1. build/GEN/ is the small files the sources include: the version (from
    VERSION), today's date, the packed banner, and four one-line files that
    point at the machine's folder (docs/PORTING.md).
  2. Each program in PROGRAMS (below) is assembled into build/BIN/NAME.BIN.
    z80asm runs with -I build, so "GEN/VERSION.INC" and "BIN/BOOTSEC.BIN" are
    found there, as they are on the source disks.
  3. release/ folder is for the disks, made from the same table: the boot disk
    (ampdos_boot.img, with the machine's README.TXT) and the three source
    disks (ampdos_src1.img to ampdos_src3.img).

build/ is only working files; release/ is what you write to floppy disk.
"""
import contextlib, datetime, io, os, shutil, subprocess, sys
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, "tools/build")
import mkdisk

ROOT, BIN, NOWHERE = "root", "BIN", None      # where a program goes on the boot disk

# Every program goes in the order it is assembled.  For each:
#   name     build/BIN/NAME.BIN, and NAME.BIN on the disks
#   source   its top file (the machine's folder: {m})
#   at, top  its load address, and the address it must end below
#   disk     where it goes on the boot disk: ROOT, BIN (\BIN, on the PATH) or NOWHERE
#   src      the source disk that carries its sources (1, 2, 3), and BUILD.BAT builds it
PROGRAMS = [
    # name        source                                at      top     disk     src
    ("bootsec",  "KERNEL/MACHINE/{m}/BOOTSEC.ASM",     0x9000, 0x9200, NOWHERE, 1),
    ("ampdos",   "KERNEL/OS/AMPDOS.ASM",               0x0000, 0x5F00, NOWHERE, 1),
    ("hello",    "PROGRAMS/HELLO.ASM",                 0x8000, 0xFC00, ROOT,    2),
    ("edit",     "PROGRAMS/EDIT.ASM",                  0x8000, 0xFC00, BIN,     2),
    ("imgwrite", "PROGRAMS/IMGWRITE.ASM",              0x8000, 0x9400, ROOT,    2),
    ("monbody",  "PROGRAMS/MONBODY.ASM",               0xBC00, 0xD600, NOWHERE, 2),
    ("disasm",   "PROGRAMS/DISASM.ASM",                0x8000, 0x9A00, BIN,     2),
    ("mon",      "PROGRAMS/MON.ASM",                   0x8000, 0xBC00, BIN,     2),
    ("asm",      "PROGRAMS/ASM.ASM",                   0x8000, 0x9C00, BIN,     2),
    ("basic",    "build/PROGRAMS/BASIC/BASIC.ASM",     0x8000, 0xFC00, ROOT,    2),
    ("setup",    "PROGRAMS/SETUP.ASM",                 0x8000, 0x9F00, ROOT,    3),
    ("disked",   "PROGRAMS/DISKED.ASM",                0x8000, 0x9C00, BIN,     3),
    ("attrib",   "PROGRAMS/ATTRIB.ASM",                0x8000, 0x9000, BIN,     3),
    ("tree",     "PROGRAMS/TREE.ASM",                  0x8000, 0x9000, BIN,     3),
    ("xcopy",    "PROGRAMS/XCOPY.ASM",                 0x8000, 0x9000, BIN,     3),
    ("undelete", "PROGRAMS/UNDELETE.ASM",              0x8000, 0x9000, BIN,     3),
    ("head",     "PROGRAMS/HEAD.ASM",                  0x8000, 0x9000, BIN,     3),
    ("tail",     "PROGRAMS/TAIL.ASM",                  0x8000, 0x9000, BIN,     3),
    ("tr",       "PROGRAMS/TR.ASM",                    0x8000, 0x9000, BIN,     3),
    ("diff",     "PROGRAMS/DIFF.ASM",                  0x8000, 0x9000, BIN,     3),
    ("diskcomp", "PROGRAMS/DISKCOMP.ASM",              0x8000, 0x8F00, BIN,     3),
    ("dump",     "PROGRAMS/DUMP.ASM",                  0x8000, 0x9000, BIN,     3),
    ("hexed",    "PROGRAMS/HEXED.ASM",                 0x8000, 0x9000, BIN,     3),
    ("defrag",   "PROGRAMS/DEFRAG.ASM",                0x8000, 0x9000, BIN,     3),
    ("scandisk", "PROGRAMS/SCANDISK.ASM",              0x8000, 0x9000, BIN,     3),
    ("memmap",   "PROGRAMS/MEMMAP.ASM",                0x8000, 0x9000, BIN,     3),
    ("ascii",    "PROGRAMS/ASCII.ASM",                 0x8000, 0x9000, BIN,     3),
]
NEEDS = {"ampdos": ["bootsec"], "mon": ["monbody"]}      # binaries a source incbins
INCBIN = {"bootsec", "monbody"}                          # assembled into BIN\, not NEW\, by BUILD.BAT
SOURCE_DISKS = {1: "the OS source files", 2: "the programs and BASIC", 3: "the utilities"}

def binary(name):
    return f"build/BIN/{name.upper()}.BIN"

def program(name):
    return next(p for p in PROGRAMS if p[0] == name)

# ---------------------------------------------------------------- the machine
def machine_title(m):
    """the "; Machine: ..." line of its MACHINE.INC"""
    for line in open(f"KERNEL/MACHINE/{m}/MACHINE.INC"):
        if line.startswith("; Machine:"):
            return line.split(":", 1)[1].strip()
    return m

# ---------------------------------------------------------------- 1. build/GEN
def generate(m):
    os.makedirs("build/GEN", exist_ok=True)
    os.makedirs("build/BIN", exist_ok=True)
    version = open("VERSION").read().strip()                     # the one place it is written
    major, minor, patch = (int(x) for x in version.split("."))
    today = datetime.date.today()                                # the OS starts with this date
    files = {
        "VERSION.INC": f"; made by build.py from VERSION\nOS_VER:     equ {major * 256 + minor:04X}h\n"
                       f"OS_PATCH:   equ {patch}\n",
        "VERTEXT.INC": f'        defm "{version}"\n',
        "BLDDATE.INC": f"; made by build.py: the day of this build\nBUILD_Y: equ {today.year}\n"
                       f"BUILD_M: equ {today.month}\nBUILD_D: equ {today.day}\n",
        # the machine layer: one line each, into KERNEL/MACHINE/<m>/
        "MACHINE.INC": f'\tinclude "KERNEL/MACHINE/{m}/MACHINE.INC"\n',
        "MACHRAM.INC": f'\tinclude "KERNEL/MACHINE/{m}/MRAM.INC"\n',
        "MACHCON.ASM": f'\tinclude "KERNEL/MACHINE/{m}/CONDRV.ASM"\n',
        "MACHDRV.ASM": f'\tinclude "KERNEL/MACHINE/{m}/DRIVERS.ASM"\n',
    }
    for name, text in files.items():
        open(f"build/GEN/{name}", "w").write(text)
    subprocess.run([sys.executable, "tools/build/mkbanner.py", "build/GEN/BANNER.INC"],
                   check=True, stdout=subprocess.DEVNULL)
    return version, today

# ---------------------------------------------------------------- 2. assemble
def assemble(name, m):
    """build/BIN/NAME.BIN -> (a report line, or None; an error, or None)"""
    _, source, at, top, _, _ = program(name)
    source = source.format(m=m)
    out = binary(name)
    if os.path.exists(out):
        os.remove(out)                                           # never an old binary left behind
    if name == "basic":                                          # BASIC's source is made first
        r = subprocess.run([sys.executable, "PROGRAMS/BASIC/mkbasic.py", "build/PROGRAMS/BASIC"],
                           capture_output=True, text=True)
        if r.returncode:
            return None, f"basic: mkbasic.py failed\n{r.stdout}{r.stderr}"
    r = subprocess.run(["z80asm", "-I", "build", "-o", out, source], capture_output=True, text=True)
    if r.returncode:
        return None, f"{name}: assembly failed\n{r.stdout}{r.stderr}"
    size = os.path.getsize(out)
    line = f"  {name:9} {size:6} bytes at {at:04X}h, {top - at - size:5} free below {top:04X}h"
    if at + size > top:
        return line, f"{name} ends at {at + size:04X}h: past {top:04X}h"
    return line, None

# ---------------------------------------------------------------- 3. the disks
def boot_disk(m, out="release/ampdos_boot.img"):
    """a FAT12 360K disk: the boot sector, AMPDOS.SYS, the programs, and the
    machine's README.TXT (KERNEL/MACHINE/<m>/README.TXT, written as it is)"""
    boot = open(binary("bootsec"), "rb").read()
    assert len(boot) == 512 and boot[0] == 0x3E and boot[510:] == b"\x55\xAA", "bad boot sector"
    shutil.copy(binary("ampdos"), "build/AMPDOS.SYS")
    assert os.path.getsize("build/AMPDOS.SYS") <= 0x6000, "the OS is too big for the boot loader (24 KB)"
    readme = open(f"KERNEL/MACHINE/{m}/README.TXT").read()
    open("build/README.TXT", "w", newline="\r\n").write(readme)       # CR LF, as DOS has it
    files = (["build/AMPDOS.SYS"]
             + [binary(p[0]) for p in PROGRAMS if p[4] == ROOT]
             + [(binary(p[0]), "BIN") for p in PROGRAMS if p[4] == BIN]
             + ["build/README.TXT"])
    with contextlib.redirect_stdout(io.StringIO()):
        mkdisk.make(out, files, boot_code=boot)
    return f"  boot disk    {out}"

def build_bat(n, m):
    """BUILD.BAT for source disk n: assemble its programs into NEW\\ (or BIN\\, for
    the ones other sources incbin), then compare each with the one on A:"""
    progs = [p for p in PROGRAMS if p[5] == n]
    lines = ["@ECHO OFF",
             f"REM BUILD.BAT - assemble {SOURCE_DISKS[n]} from the sources on this disk.",
             "REM Boot the ampDOS disk in A:, put this one in B:, then  B:  and  BUILD.",
             "REM CMP compares each new one with the one on A: (the same bytes, unless a",
             "REM source was changed).",
             "B:"]
    for name, source, *_ in progs:
        dos = source.format(m=m).removeprefix("build/").replace("/", "\\")
        target = f"BIN\\{name.upper()}.BIN" if name in INCBIN else f"NEW\\{name.upper()}.BIN"
        if name == "ampdos":
            target = "NEW\\AMPDOS.SYS"
        lines += [f"ECHO {name.upper()}", f"A:\\BIN\\ASM {dos} {target}", "IF ERRORLEVEL 1 GOTO FAIL"]
    for name, _, _, _, disk, _ in progs:
        if name == "ampdos":
            lines.append("CMP NEW\\AMPDOS.SYS A:\\AMPDOS.SYS")
        elif disk is not NOWHERE:
            where = "" if disk == ROOT else "BIN\\"
            lines.append(f"CMP NEW\\{name.upper()}.BIN A:\\{where}{name.upper()}.BIN")
    lines += ["GOTO END", ":FAIL", "ECHO The build failed.", ":END"]
    if n == 1:
        lines.insert(5, "REM To boot a new OS: COPY NEW\\AMPDOS.SYS A:\\AMPDOS.SYS and then EXIT.")
    return "\n".join(lines) + "\n"

def source_disks(m):
    """the source disks: everything ampDOS is assembled from, nothing assembled"""
    if not all(shutil.which(t) for t in ("mcopy", "mmd", "mdir")):
        return ["  source disks: skipped: they need the mtools programs (mcopy, mmd, mdir),",
                "    not the pip package of that name:  brew install mtools  (Mac),",
                "    apt install mtools  (Debian, Ubuntu)"]
    import srcdisk
    lines = []
    for n, what in SOURCE_DISKS.items():
        out = f"release/ampdos_src{n}.img"
        tops = [p[1].format(m=m).removeprefix("build/") for p in PROGRAMS if p[5] == n]
        open("build/BUILD.BAT", "w", newline="\r\n").write(build_bat(n, m))
        open("build/README.TXT", "w", newline="\r\n").write(
            f"ampDOS source disk {n}: the sources of {what}.\n"
            "Boot the ampDOS disk in A:, put this one in B:, then B: and BUILD:\n"
            "ASM (on A:\\BIN) assembles them, and CMP compares each with the one\n"
            "on A:.  The files are the same as in the project's KERNEL\\ and PROGRAMS\\.\n")
        free = srcdisk.make(out, tops, ["build/BUILD.BAT", "build/README.TXT"],
                            ["BIN", "NEW"], "build/pack", f"AMPDOS SRC{n}")   # srcdisk follows the includes
        lines.append(f"  source disk  {out}  ({what}; {free // 1024} KB free)")
    return lines

# ---------------------------------------------------------------- main
def main():
    args = sys.argv[1:]
    m = "AMPRO"  # default is AMPRO machine (currently the only one)
    if "--machine" in args:
        i = args.index("--machine")
        m = args[i + 1].upper()
        del args[i:i + 2]
    if not os.path.isdir(f"KERNEL/MACHINE/{m}"):
        sys.exit(f"build.py: there is no machine layer KERNEL/MACHINE/{m}/")
    names = args or [p[0] for p in PROGRAMS]
    unknown = [n for n in names if n not in [p[0] for p in PROGRAMS]]
    if unknown:
        sys.exit(f"build.py: no such program: {', '.join(unknown)}")
    for n in list(names):                                        # what they incbin comes first
        for dep in NEEDS.get(n, []):
            if dep not in names:
                names.insert(names.index(n), dep)

    version, today = generate(m)
    print(f"ampDOS {version}")
    print(f"  machine      {machine_title(m)}  (KERNEL/MACHINE/{m}/)")
    print(f"  start date   {today.isoformat()} (the OS's date until it is set)")
    print()
    os.makedirs("release", exist_ok=True)
    errors = []
    for n in names:
        line, error = assemble(n, m)
        if line:
            print(line)
        if error:
            errors.append(error)
    if not errors and all(os.path.exists(binary(p[0])) for p in PROGRAMS):
        print()
        print(boot_disk(m))
        print("\n".join(source_disks(m)))
    if errors:
        print("\n" + "\n".join(errors))
    sys.exit(1 if errors else 0)

if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        pass
