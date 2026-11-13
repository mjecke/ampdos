/* systest.c - ampdos.h: system() and the os_ functions.  Run: SYSTEST */
#include <stdio.h>
#include "ampdos.h"

int main(void)
{
    unsigned v = os_version();
    int n = 0;

    printf("ampDOS %u.%u.%d, drive %c:\n", v >> 8, v & 0xFF, os_patch(), 'A' + os_drive());
    printf("system(NULL) = %d\n", system(NULL));
    printf("system(\"VER\"):\n");
    printf(" -> %d\n", system("VER"));
    printf("system(\"SLEEP 1\") ...");
    printf(" -> %d\n", system("SLEEP 1"));
    printf("system(\"NOSUCH\") -> %d (refused)\n", system("NOSUCH"));
    printf("system(\"DIR\"):\n");
    system("DIR");
    printf("press a key to stop counting: ");
    while (!os_kbhit())
        n++;
    getchar();
    printf("\ncounted to %d.  Clear the screen? (y/n) ", n);
    if (getchar() == 'y')
        os_screen(SCR_CLEAR);
    printf("exit status 3 (IF ERRORLEVEL 3 sees it)\n");
    os_status(3);
    return 0;
}
