/* ctest.c - how much of C works on ampDOS with uc80.  Run: CTEST
 * Each check prints ok: or FAIL:; the exit status is the number of failures.
 * The last one asks you to type a number.  It is big (about 27 KB: the
 * float, 64-bit and scanf code), so malloc has only about 3 KB here: from the end of the
 * program to 255 bytes under the stack. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <setjmp.h>

static int fails, checks;

static void check(int good, const char *what)
{
    checks++;
    printf("%s %s\n", good ? "ok:  " : "FAIL:", what);
    if (!good)
        fails++;
}

static int near(double a, double b)     /* single precision: 5 digits or so */
{
    double d = a - b;
    if (d < 0)
        d = -d;
    return d < 0.0005 || d < 0.0005 * (b < 0 ? -b : b);
}

/* ---- for the language checks */
struct pt { int x, y; long z; };

static struct pt pt_add(struct pt a, struct pt b)
{
    struct pt r;
    r.x = a.x + b.x;
    r.y = a.y + b.y;
    r.z = a.z + b.z;
    return r;
}

static int ack(int m, int n)
{
    if (m == 0)
        return n + 1;
    if (n == 0)
        return ack(m - 1, 1);
    return ack(m - 1, ack(m, n - 1));
}

static int fib(int n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
static int deep(int n) { return n == 0 ? 0 : 1 + deep(n - 1); }
static int twice(int v) { return v * 2; }
static int square(int v) { return v * v; }
static int cmpint(const void *a, const void *b)
{
    int x = *(const int *)a, y = *(const int *)b;
    return x < y ? -1 : x > y;
}

static jmp_buf jb;
static void jumper(int n) { if (n > 3) longjmp(jb, n); jumper(n + 1); }

int main(void)
{
    char buf[64], word[16];
    int i, n, ok;
    float f;
    long l;

    printf("--- math.h (single precision float)\n");
    check(near(sin(3.14159265 / 6), 0.5), "sin(pi/6) = 0.5");
    check(near(cos(0.0), 1.0), "cos(0) = 1");
    check(near(sqrt(2.0) * sqrt(2.0), 2.0), "sqrt(2)^2 = 2");
    check(near(exp(1.0), 2.71828), "exp(1) = 2.71828");
    check(near(log(exp(2.0)), 2.0), "log(exp(2)) = 2");
    check(near(pow(2.0, 10.0), 1024.0), "pow(2,10) = 1024");
    check(near(atan2(1.0, 1.0) * 4, 3.14159), "atan2(1,1) * 4 = pi");
    check(floor(-2.5) == -3.0 && ceil(-2.5) == -2.0 && fabs(-4.25) == 4.25, "floor, ceil, fabs");
    sprintf(buf, "%.3f %e", 3.14159, 12345.0);
    check(strncmp(buf, "3.142 1.234", 11) == 0, "printf %.3f and %e");

    printf("--- integers\n");
    check(-7 / 2 == -3 && -7 % 2 == -1, "-7/2 = -3, -7%2 = -1");
    check((unsigned)65535 + 1u == 0, "unsigned 16-bit wraps");
    check((1 << 15) == (int)0x8000 && (0x8000u >> 15) == 1 && (-16 >> 2) == -4, "shifts");
    l = 100000L * 3 + 7;
    check(l == 300007L && l / 1000 == 300 && l % 1000 == 7, "long (32-bit) * / %");
    {
        long long q = 123456789LL * 1000;
        check(q == 123456789000LL && q / 7 == 17636684142LL && (1LL << 40) > 1000000000000LL,
              "long long (64-bit)");
        sprintf(buf, "%lld", q);
        check(strcmp(buf, "123456789000") == 0, "printf %lld");
    }

    printf("--- the library\n");
    {
        int v[10] = { 5, 3, 9, 1, 7, 0, 8, 2, 6, 4 }, key = 6, *p;
        qsort(v, 10, sizeof v[0], cmpint);
        for (ok = 1, i = 0; i < 10; i++)
            if (v[i] != i)
                ok = 0;
        check(ok, "qsort");
        p = bsearch(&key, v, 10, sizeof v[0], cmpint);
        check(p && *p == 6, "bsearch");
    }
    n = sscanf("12 abc 3.5", "%d %15s %f", &i, word, &f);
    check(n == 3 && i == 12 && strcmp(word, "abc") == 0 && near(f, 3.5), "sscanf %d %s %f");
    check(strtol("ff", NULL, 16) == 255 && strtol("-101", NULL, 2) == -5 && atoi("  42x") == 42,
          "strtol bases, atoi");
    strcpy(buf, "hello");
    strcat(buf, ", world");
    check(strcmp(buf, "hello, world") == 0 && strlen(buf) == 12, "strcpy, strcat, strlen");
    check(strstr(buf, "wor") == buf + 7 && strchr(buf, ',') == buf + 5 && strrchr(buf, 'o') == buf + 8,
          "strstr, strchr, strrchr");
    memmove(buf + 1, buf, 5);
    check(strncmp(buf, "hhello", 6) == 0, "memmove overlapping");
    check(toupper('q') == 'Q' && isdigit('7') && !isalpha('7') && isspace('\t'), "ctype");
    n = setjmp(jb);
    if (n == 0)
        jumper(0);
    check(n == 4, "setjmp / longjmp");
    for (ok = 1, i = 0; i < 200; i++) {
        char *m = malloc(500);
        if (!m) {
            ok = 0;
            break;
        }
        m[0] = m[499] = 1;
        free(m);
    }
    check(ok, "malloc/free 500 bytes, 200 times");
    {
        char *m1 = malloc(1000), *m2 = malloc(1000);
        check(m1 && m2 && m1 != m2, "two 1000-byte blocks at once");
        free(m1);
        free(m2);
    }
    check(malloc(40000u) == NULL, "malloc(40000) fails (there is not that much)");

    printf("--- the language\n");
    check(ack(2, 3) == 9 && fib(20) == 6765, "recursion: ack(2,3), fib(20)");
    check(deep(200) == 200, "recursion 200 deep");
    {
        struct pt a = { 1, 2, 100000L }, b = { 10, 20, 1L }, c;
        c = pt_add(a, b);
        check(c.x == 11 && c.y == 22 && c.z == 100001L, "structs passed and returned by value");
    }
    {
        int (*fn[2])(int) = { twice, square };
        check(fn[0](7) == 14 && fn[1](7) == 49, "function pointers");
    }
    {
        union { long l; unsigned char c[4]; } u;
        struct { unsigned a : 3; unsigned b : 5; unsigned c : 8; } bf;
        u.l = 0x04030201L;
        check(u.c[0] == 1 && u.c[3] == 4, "union (little-endian)");
        bf.a = 7;
        bf.b = 31;
        bf.c = 200;
        bf.a++;
        check(bf.a == 0 && bf.b == 31 && bf.c == 200, "bitfields");
    }
    {
        static int once = 5;
        int s = 0;
        switch (once) {
        case 5: s += 1;                 /* falls through */
        case 6: s += 2; break;
        default: s = 99;
        }
        check(s == 3, "switch falls through");
    }

    printf("--- the keyboard\n");
    printf("type 42 and Return: ");
    n = scanf("%d", &i);
    check(n == 1 && i == 42, "scanf %d from the keyboard");

    printf("%d of %d checks failed\n", fails, checks);
    return fails;
}
