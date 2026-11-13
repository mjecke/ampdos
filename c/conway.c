/* conway.c - Conway's Game of Life, 78 x 24, for ampDOS (uc80).
 *
 * Build:  ./ampcc.sh conway.c  -> CONWAY.BIN     Run:  CONWAY
 *
 * A random grid, then generation after generation as fast as the terminal
 * takes them: each one is made in memory, then drawn over the last from the
 * top left corner (os_screen(SCR_HOME)) in one go with os_write, so the
 * picture stays still while the next one is worked out.  The edges wrap
 * around.
 *
 * Keys: Esc, Q or Ctrl-C ends it; Space, Return or any letter or digit
 * starts a new random grid.  Other control characters are ignored: a
 * terminal may send XON/XOFF (11h/13h) by itself while it is busy.
 *
 * The random numbers are a 16-bit xorshift, not rand(): uc80's rand() is a
 * 16-bit linear congruential generator whose low bits repeat every few
 * numbers, so rand() & 3 marked exactly every 4th cell.
 */
#include <stdio.h>
#include "ampdos.h"

#define W 78
#define H 24
#define BW (W + 2)                      /* with a border row and column all round, */
#define BH (H + 2)                      /* the wrapped-around neighbours */

static unsigned char a[BH][BW], b[BH][BW];
static unsigned char rr;                /* the Z80's R register: a little randomness */
static unsigned rnd = 0xACE1;           /* the xorshift state (never 0) */

static unsigned xrand(void)             /* xorshift16 (7, 9, 8): all 65535 states */
{
    rnd ^= rnd << 7;
    rnd ^= rnd >> 9;
    rnd ^= rnd << 8;
    return rnd;
}

static void reseed(void)
{
    asm("\tLD\tA,R");
    asm("\tLD\t(_rr),A");
    rnd ^= (unsigned)rr << 8 | rr;      /* mixed in: each grid starts elsewhere */
    if (rnd == 0)
        rnd = 0xACE1;
}

static void randomize(unsigned char (*g)[BW])
{
    int y, x;

    reseed();
    for (y = 1; y <= H; y++)
        for (x = 1; x <= W; x++)
            g[y][x] = (xrand() >> 14) == 0;  /* the top bits: a quarter of the cells alive */
}

static void wrap(unsigned char (*g)[BW])  /* the border copies the far side */
{
    int y, x;

    for (y = 1; y <= H; y++) {
        g[y][0] = g[y][W];
        g[y][W + 1] = g[y][1];
    }
    for (x = 0; x < BW; x++) {
        g[0][x] = g[H][x];
        g[H + 1][x] = g[1][x];
    }
}

static void step(unsigned char (*g)[BW], unsigned char (*n)[BW])
{
    int y, x, c;
    unsigned char *up, *mid, *dn;

    wrap(g);
    for (y = 1; y <= H; y++) {
        up = g[y - 1];
        mid = g[y];
        dn = g[y + 1];
        for (x = 1; x <= W; x++) {
            c = up[x - 1] + up[x] + up[x + 1]
              + mid[x - 1] + mid[x + 1]
              + dn[x - 1] + dn[x] + dn[x + 1];
            n[y][x] = c == 3 || (c == 2 && mid[x]);
        }
    }
}

/* the whole picture is made in memory first, then sent in one go with
   os_write: the screen stays still while the next generation is worked out,
   then changes as fast as the line takes it.  Every row is sent whole, 78
   characters, spaces too, so it overwrites what was there: no terminal
   codes but "cursor home" are needed. */
static char frame[H * (W + 2)];         /* the rows, each with CR LF but the last */

static void draw(unsigned char (*g)[BW])
{
    int y, x;
    unsigned char *c;
    char *f = frame;

    for (y = 0; y < H; y++) {           /* first the picture, in memory */
        c = g[y + 1] + 1;
        for (x = 0; x < W; x++)
            *f++ = c[x] ? 'O' : ' ';
        if (y < H - 1) {                /* not after the last row: no scrolling */
            *f++ = '\r';
            *f++ = '\n';
        }
    }
    os_screen(SCR_HOME);                /* then out in one go */
    os_write(frame, f - frame);
}

/* the keys waiting: 2 = quit, 1 = a new grid, 0 = nothing (or only noise) */
static int keys(void)
{
    int c, r = 0;

    while (os_kbhit()) {
        c = os_getc() & 0x7F;
        if (c == 27 || c == 3 || c == 'q' || c == 'Q')
            return 2;
        if (c == ' ' || c == 13 || c > ' ')
            r = 1;
    }
    return r;
}

int main(void)
{
    int k;

    unsigned char (*cur)[BW] = a, (*nxt)[BW] = b, (*t)[BW];

    os_screen(SCR_CLEAR);
    randomize(cur);
    for (;;) {
        draw(cur);
        k = keys();
        if (k == 2)
            break;
        if (k == 1) {
            randomize(cur);
            continue;
        }
        step(cur, nxt);
        t = cur;
        cur = nxt;
        nxt = t;
    }
    os_screen(SCR_CLEAR);
    return 0;
}
