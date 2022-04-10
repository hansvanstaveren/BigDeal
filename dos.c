
static char rcsid[] = "$Header: /home/sater/bridge/bigdeal/RCS/dos.c,v 1.9 2000/08/26 14:15:22 sater Exp $";

#include <conio.h>
#include <time.h>
#include <ctype.h>
#include <stdio.h>
#include "types.h"
#include "bigdeal.h"
#include "collect.h"

extern FILE *flog;

/*
 * Find the best clock to use in this environment
 * We prefer uclock, since it generates more bits
 * But it is not ansi, so use clock as an alternative
 */
#ifdef UCLOCKS_PER_SEC
int
bestclock()
{

	return (int) uclock();
}
#else
#ifdef CLOCKS_PER_SEC
int
bestclock()
{

	return (int) clock();
}
#else
There is no clock, this program needs it, so do not compile
#endif
#endif

#define MAX_INTERVAL_ENTROPY	6

int
getchtm(int *nbits)
/*
 * Read one character from standard input
 * Time the wait, and use bits for random
 * MUST be in cbreak mode for this to work
 */
{
	int t1, t2;
	int tdiff;
	int c;
	int shift;
	int b;

	/*
	 * First get the best clock we have
	 */
	t1 = bestclock();
	/*
	 * Now get one character
	 */
	c = getch();
	/*
	 * If it is zero, which can happen with getch() under DOS
	 * we have a two character sequence(function key probably)
	 * and we make one character out of it by appending the next
	 */
	if (c == 0)
		c = getch() + 256;
	/*
	 * and get the clock after the keypress
	 */
	t2 = bestclock();
	/*
	 * Number of ticks we waited goes to tdiff
	 */
	tdiff = t2 - t1;
	/*
	 * Now we are going to believe half the bits we get
	 */
	for (shift = tdiff, b = 0; shift>2 ; shift >>= 2, b++)
		;
	if (b < MAX_INTERVAL_ENTROPY)
		*nbits = b;
	else
		*nbits = MAX_INTERVAL_ENTROPY;
	/*
	 * We send all the bits to the collect pool
	 * but do not count the bits yet (parameter 0)
	 * because higher layers might decide not to believe this
	 * character, and its associated timing
	 */
	collect_more((byte *) &t1, sizeof(t1), 0);
	collect_more((byte *) &t2, sizeof(t2), 0);
	if (flog)
		fprintf(flog, "Collected character %d, timediff %d, timebits %d\n",
			c, tdiff, *nbits);
	return c;
}

void
os_collect() {
	time_t t;

	(void) time(&t);
	/* Trust 6 bits of seconds */
	collect_more((byte *) &t, sizeof(t), 6);
}

void
cbreak()
{

}

void
cooked()
{

}

void
os_start()
{

	/*
	 * Start the clock running
	 */
	(void) bestclock();

}

void
os_finish()
{

}

int
legal_filename_prefix(char *s)
/*
 * Legal prefix to make legal name when three letter suffix added
 */
{

	if (*s == 0)	/* Too short */
		return 0;
	if (strlen(s) > 8)
		return 0;
	while (*s) {
		if (!isalnum(*s) && *s != '-' && *s != '_')
			return 0;
		s++;
	}
	return 1;
}

char *os_init_file_name()
{

	return "bigdeal.ini";
}
