
static char rcsid[] = "$Header: /home/sater/bridge/bigdeal/RCS/unix.c,v 1.11 2000/08/25 15:55:53 sater Exp $";

#include <sys/termios.h>
#include <sys/time.h>
#include <ctype.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include "types.h"
#include "bigdeal.h"
#include "collect.h"

extern FILE *flog;

#ifdef TIOCSETA
/*
 * For example on BSDI
 */
#define GTTY	TIOCGETA
#define STTY	TIOCSETA

#else
/*
 * For example on SunOS
 */

#define GTTY	TCGETS
#define STTY	TCSETSF

#endif /* TIOCSETA */

static int subsecbits = 5;
#define MAX_INTERVAL_ENTROPY	6

void
gettod(struct timeval *tp)
/*
 * Fill in *tp with gettimeofday values
 * Side effect: calculate approx precision
 */
{
	int b;

	gettimeofday(tp, (struct timezone *) 0);
	/* Find how many bits are set in usec field */
	for(b = 0; b < 20; b++) {
		if (tp->tv_usec&(1<<b))
			break;
	}
	if (20-b > subsecbits) {
		subsecbits = 20-b;
	}
}

int
getchtm(int *nbits)
/*
 * Read one character from standard input
 * Time the wait, and use bits for random
 * MUST be in cbreak mode for this to work
 */
{
	struct timeval t1, t2;
	long sdiff, mdiff;
	int c;
	long shift;
	int b;

	gettod(&t1);
	c = getchar();
	gettod(&t2);
	mdiff = t2.tv_usec - t1.tv_usec;
	sdiff = t2.tv_sec - t1.tv_sec;
	if (sdiff > 1000)
		sdiff = 1000;
	mdiff += sdiff * 1000000;
	/*
	 * Everything slower than 1/8 second can be faked
	 * Trust at most half of the rest
	 */
	for (shift = mdiff, b= 0; shift>3 ; shift >>= 2, b++)
		;
	if (b <= MAX_INTERVAL_ENTROPY)
		*nbits = b;
	else
		*nbits = MAX_INTERVAL_ENTROPY;
	collect_more((byte *) &t1, sizeof(t1), 0);
	collect_more((byte *) &t2, sizeof(t2), 0);
	if (flog)
		fprintf(flog, "Collected character %d, timediff %ld, timebits %d\n",
			c, mdiff, *nbits);
	return c;
}

void
os_collect() {
	int pid;
	struct timeval t;

	pid = getpid();
	/* Trust about 8 bits of randomness in pid */
	collect_more((byte *) &pid, sizeof(pid), 8);
	gettod(&t);
	/* Trust 6 bits of seconds, and half the subsecond bits */
	collect_more((byte *) &t, sizeof(t), 6+subsecbits/2);
	if (flog)
		fprintf(flog, "First TOD=(%ld, %ld), subsecbits = %d\n",
			t.tv_sec, t.tv_usec, subsecbits);
}

static struct termios tios;

void
cbreak()
/*
 * Set terminal to state where characters can be read one at a time
 * Also disable echo
 */
{
	struct termios newtios;

	newtios = tios;

	/* fiddle newtios */
	newtios.c_lflag &= ~(ICANON|ECHO);
	newtios.c_cc[VMIN] = 1;
	newtios.c_cc[VTIME] = 0;
	ioctl(0, STTY, &newtios);
}

void
cooked()
/*
 * Reset terminal to original state
 */
{

	ioctl(0, STTY, &tios);
}

void
os_start() {

	ioctl(0, GTTY, &tios);
}

void
os_finish() {

	cooked();
}

int
legal_filename_prefix(char *s)
/*
 * Legal prefix to make legal name when three letter suffix added
 */
{

	if (*s == 0)	/* Too short */
		return 0;
	if (strlen(s) > 10)	/* Worst case, System V */
		return 0;
	while (*s) {
		if (*s == '/' || *s == ' ')	/* disallow space */
			return 0;
		s++;
	}
	return 1;
}

char *os_init_file_name()
{

	return ".bigdealrc";
}
