/* ampdos.h - ampDOS from C (uc80): link with lib/ (ampcc.sh does it).
 * Only the functions a program calls are linked in. */
#ifndef AMPDOS_H
#define AMPDOS_H

/* a built-in shell command: system("SLEEP 2"), system("CLEAR"),
   system("DIR B:"), system("COPY A.TXT B:") ...  0, or -1 when the shell
   refuses it (.BIN programs and FDISK cannot run from a program).  It cannot
   tell whether the command worked.  Do not run a disk-writing command on a
   disk the program has files open on (close them first). */
int system(const char *command);

/* the terminal, with the codes SETUP saved: 0 or -1 = this terminal cannot */
#define SCR_CLEAR  0            /* clear the screen, cursor home */
#define SCR_HOME   1
#define SCR_EOL    2            /* erase to the end of the line */
#define SCR_EOS    3            /* erase to the end of the screen */
#define SCR_UP     4
#define SCR_DOWN   5
#define SCR_RIGHT  6
#define SCR_LEFT   7
int os_screen(int action);
int os_rows(void);              /* the screen's size, as SETUP found it (24 x 80 */
int os_cols(void);              /*   before ampDOS 0.8.6) */
int os_wrap(void);              /* 1 = it wraps by itself after the last column */
int os_flags(void);             /* SCREEN WRAP's flags: */
#define SCR_F_WRAP     1        /*   it wraps by itself after the last column */
#define SCR_F_EOLLINE  2        /*   SCR_EOL erases the whole line: use it at column 0 */
#define SCR_F_EOSLINE  4        /*   SCR_EOS erases from the start of the line down */

int os_kbhit(void);             /* 1 = a key is waiting (getchar() gets it) */
int os_getc(void);              /* wait for a key, without showing it */
void os_write(const char *buf, unsigned n); /* n bytes to the screen, raw (\n is not CR LF): fast */
void os_status(int n);          /* the exit status, ERRORLEVEL (exit(n) drops n) */
int os_drive(void);             /* the current drive: 0 = A, 1 = B */
unsigned os_version(void);      /* major * 256 + minor: 0.8.5 is 0x0008 */
int os_patch(void);             /* the third number: 5 */

#endif
