/* mandel.c - an ASCII Mandelbrot explorer for ampDOS (uc80, 80x26 terminal)
 *
 * Build:  ./ampcc.sh mandel.c   -> MANDEL.BIN      Run:  MANDEL
 *
 * The picture is 78 x 22 characters; the last three lines are the status,
 * the keys and the prompt, so it all fits in 79 columns and 25 lines.
 * The keys are digits, laid out like a numeric keypad:
 *     8 up   2 down   4 left   6 right   7 zoom in   1 zoom out
 *     9 more iterations   3 fewer   5 start again   0 quit
 *
 * A key pressed while it draws stops the picture there and is the next
 * command.
 *
 * The math is 16-bit fixed point (4.12: 4096 = 1.0), because the Z80 has no
 * floating point and uc80's soft float would take minutes for one picture.
 * A multiply is one 16 x 16 -> 32 bit product, shifted back by 12.  That
 * gives a zoom of about 180x before the pixels are one step (1/4096) apart:
 * the program stops zooming there.
 */
#include <stdio.h>
#include "ampdos.h"              /* os_screen, os_kbhit */

#define ONE     4096            /* 1.0 in 4.12 fixed point */
#define COLS    78              /* the picture */
#define ROWS    22
#define LIM     (2 * ONE)       /* |zr| or |zi| past 2: certainly escaped */
#define START_STEP 184          /* 3.5 wide / 78 columns, in 1/4096ths */
#define MAX_STEP   400
#define START_X (-2458)         /* -0.6 */
#define START_Y 0

/* 8 characters: escaped fast ... escaped slowly, and '#' is in the set */
static const char shade[8] = { ' ', '.', ':', '-', '=', '+', '*', '#' };

static int cx, cy;              /* the centre */
static int step;                /* one column, in 1/4096ths (a row is two) */
static int maxit;

static int fmul(int a, int b)
{
    return (int)(((long)a * (long)b) >> 12);
}

/* the shade of one point c = cr + i ci */
static char point(int cr, int ci)
{
    int zr = 0, zi = 0, zr2, zi2, i;

    for (i = 0; i < maxit; i++) {
        if (zr > LIM || zr < -LIM || zi > LIM || zi < -LIM)
            break;
        zr2 = fmul(zr, zr);
        zi2 = fmul(zi, zi);
        if ((unsigned)zr2 + (unsigned)zi2 > (unsigned)(4 * ONE))
            break;
        zi = 2 * fmul(zr, zi) + ci;
        zr = zr2 - zi2 + cr;
    }
    if (i >= maxit)
        return shade[7];                        /* in the set */
    return shade[(long)i * 7 / maxit];          /* 0 .. 6 */
}

/* a fixed-point number as +d.dddd */
static void pfix(int v)
{
    long a = v;
    char sign = '+';

    if (a < 0) {
        sign = '-';
        a = -a;
    }
    printf("%c%ld.%04ld", sign, a / ONE, (a % ONE) * 10000L / ONE);
}

static void draw(void)
{
    int row, col, cr, ci;
    char line[COLS + 1];

    os_screen(SCR_CLEAR);
    for (row = 0; row < ROWS; row++) {
        if (os_kbhit())                         /* a key: stop drawing, it is the next command */
            break;
        ci = cy + (row - ROWS / 2) * 2 * step;  /* characters are about twice as tall */
        for (col = 0; col < COLS; col++) {
            cr = cx + (col - COLS / 2) * step;
            line[col] = point(cr, ci);
        }
        line[COLS] = 0;
        printf("%s\n", line);                   /* a row at a time: you see it come */
    }
    printf("x=");
    pfix(cx);
    printf("  y=");
    pfix(-cy);                                  /* up is +y */
    printf("  width=");
    pfix(step * COLS);
    printf("  iterations=%d", maxit);
    if (step == 1)
        printf("  (max zoom)");
    printf("\n8 up 2 down 4 left 6 right 7 zoom in 1 out  9 more iter 3 less  5 reset 0 quit\n");
    printf("> ");
}

static void clampc(void)
{
    if (cx > 10240) cx = 10240;                 /* the centre stays within 2.5 */
    if (cx < -10240) cx = -10240;
    if (cy > 10240) cy = 10240;
    if (cy < -10240) cy = -10240;
}

int main(void)
{
    int c, panx, pany;

    cx = START_X;
    cy = START_Y;
    step = START_STEP;
    maxit = 24;
    draw();
    for (;;) {
        c = getchar();
        panx = step * (COLS / 4);               /* a move is a quarter of the view */
        pany = step * 2 * (ROWS / 4);
        switch (c) {
        case '8': cy -= pany; break;
        case '2': cy += pany; break;
        case '4': cx -= panx; break;
        case '6': cx += panx; break;
        case '7': if (step > 1) step /= 2; break;
        case '1': if (step * 2 <= MAX_STEP) step *= 2; break;
        case '9': if (maxit < 250) maxit += 8; break;
        case '3': if (maxit > 8) maxit -= 8; break;
        case '5': cx = START_X; cy = START_Y; step = START_STEP; maxit = 24; break;
        case '0': case 'q': case 'Q': case 27:
            printf("\n");
            return 0;
        default:
            continue;                           /* Return, anything else: ignored */
        }
        clampc();
        draw();
    }
}
