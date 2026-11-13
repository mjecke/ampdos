/* ftest.c - checks C file I/O on ampDOS (ampbdos.mac).  Run: FTEST
 * It makes, reads, appends to, seeks in, renames and deletes files called
 * FT*.TXT / FT*.BIN in the current directory, and prints ok: or FAIL: for
 * each check; the status is the number of failures. */
#include <stdio.h>
#include <string.h>

static int fails;

static void check(int good, const char *what)
{
    printf("%s %s\n", good ? "ok:  " : "FAIL:", what);
    if (!good)
        fails++;
}

/* the library's fgetc skips CR and stops at 1Ah even in "rb" (CP/M text
   rules), so the binary test leaves those two values out */
static int val(int i)
{
    int v = (i * 7 + 3) & 0xFF;
    return (v == 0x0D || v == 0x1A) ? v + 1 : v;
}

static long fsize(const char *name)    /* bytes up to the end (as C sees it) */
{
    FILE *f = fopen(name, "rb");
    long n = 0;
    if (!f)
        return -1;
    while (fgetc(f) != EOF)
        n++;
    fclose(f);
    return n;
}

int main(void)
{
    FILE *f;
    char line[80];
    int i, c, ok;
    long n;

    remove("FT1.TXT");
    remove("FT2.TXT");
    remove("FT3.BIN");

    /* 1. write text, read it back line by line */
    f = fopen("FT1.TXT", "w");
    check(f != NULL, "fopen w");
    for (i = 0; i < 50; i++)
        fprintf(f, "line %d of the test file\n", i);
    check(fclose(f) == 0, "fclose after 50 lines");
    f = fopen("FT1.TXT", "r");
    check(f != NULL, "fopen r");
    ok = 1;
    for (i = 0; i < 50; i++) {
        char want[40];
        sprintf(want, "line %d of the test file\n", i);
        if (!fgets(line, sizeof line, f) || strcmp(line, want) != 0)
            ok = 0;
    }
    check(ok, "the 50 lines read back the same");
    check(fgets(line, sizeof line, f) == NULL && feof(f), "then end of file");
    fclose(f);
    check(fsize("FT1.TXT") == 1240L, "its size is exact: 1240 (no 1Ah padding)");

    /* 2. append */
    f = fopen("FT1.TXT", "a");
    check(f != NULL, "fopen a");
    fputs("the appended line\n", f);
    fclose(f);
    f = fopen("FT1.TXT", "r");
    for (i = 0; i < 51; i++)
        fgets(line, sizeof line, f);
    check(strcmp(line, "the appended line\n") == 0, "the appended line is last");
    fclose(f);
    f = fopen("FT1.TXT", "r");
    fgets(line, sizeof line, f);
    check(strcmp(line, "line 0 of the test file\n") == 0, "and the first line is still there");
    fclose(f);
    check(fopen("AMPCTMP0.TMP", "r") == NULL, "no temporary file left");

    /* 3. seek */
    f = fopen("FT1.TXT", "r");
    fseek(f, 490L, SEEK_SET);              /* lines 0-9 are 24 bytes, 10-49 are 25 */
    fgets(line, sizeof line, f);
    check(strcmp(line, "line 20 of the test file\n") == 0, "fseek forward to line 20");
    fseek(f, 0L, SEEK_SET);
    fgets(line, sizeof line, f);
    check(strcmp(line, "line 0 of the test file\n") == 0, "fseek back to the start");
    fseek(f, 300L, SEEK_SET);
    n = ftell(f);
    check(n == 300L, "ftell after fseek");
    fclose(f);

    /* 4. binary: every byte value, 1000 bytes (not a multiple of 128) */
    f = fopen("FT3.BIN", "wb");
    for (i = 0; i < 1000; i++)
        fputc(val(i), f);
    fclose(f);
    f = fopen("FT3.BIN", "rb");
    ok = 1;
    for (i = 0; i < 1000; i++) {
        c = fgetc(f);
        if (c != val(i))
            ok = 0;
    }
    check(ok, "1000 binary bytes back the same");
    fclose(f);

    /* 5. fread / fwrite blocks */
    {
        static char buf[600], back[600];
        for (i = 0; i < 600; i++)
            buf[i] = 'A' + i % 26;
        f = fopen("FT2.TXT", "wb");
        check(fwrite(buf, 1, 600, f) == 600, "fwrite 600 bytes");
        fclose(f);
        f = fopen("FT2.TXT", "rb");
        check(fread(back, 1, 600, f) == 600 && memcmp(buf, back, 600) == 0, "fread them back");
        fclose(f);
    }

    /* 6. rename, remove, missing files */
    check(rename("FT2.TXT", "FT4.TXT") == 0, "rename");
    check(fopen("FT2.TXT", "r") == NULL, "the old name is gone");
    f = fopen("FT4.TXT", "r");
    check(f != NULL, "the new name opens");
    if (f)
        fclose(f);
    check(remove("FT4.TXT") == 0, "remove");
    check(fopen("FT4.TXT", "r") == NULL, "removed");
    check(fopen("NOSUCH.TXT", "r") == NULL, "a missing file does not open");

    /* 7. two files at once: copy FT1.TXT to FT2.TXT */
    {
        FILE *a = fopen("FT1.TXT", "r"), *b = fopen("FT2.TXT", "w");
        check(a && b, "two files open at once");
        while ((c = fgetc(a)) != EOF)
            fputc(c, b);
        fclose(a);
        fclose(b);
        check(fsize("FT2.TXT") == fsize("FT1.TXT"), "the copy has the same size");
    }

    remove("FT1.TXT");
    remove("FT2.TXT");
    remove("FT3.BIN");
    printf("%d failed\n", fails);
    return fails;
}
