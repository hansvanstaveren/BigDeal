/*
 * Collect various pieces of randomness
 */

#include "types.h"
#include "rmd160.h"
#include "bigdeal.h"
#include <stdio.h>

static dword MDbuf[RMDdwords];		/* Contains state of RIPEMD-160 */
static byte variousbytes[64];
static int vbytesindex;

int nrandombits;			/* Collected bits of randomness */
static int nhashbytes;			/* Number of bytes hashed */

extern FILE *flog;

void
collect_start(void)
/*
 * Set everything to zero, and init the hashing engine
 */
{

	MDinit(MDbuf);
	vbytesindex = 0;
	nhashbytes = 0;
	nrandombits = 0;
}

static void
collect_byte(byte b)
/*
 * Throw another byte into the machine. If it fills up the buffer run the 
 * buffer through the hashing engine
 */
{
	dword X[16];
	int i;
	byte *bp;

	nhashbytes++;
	variousbytes[vbytesindex++] = b;
	if (vbytesindex == 64) {
		bp = variousbytes;
		for (i=0; i<16; i++) {
			X[i] = BYTES_TO_DWORD(bp);
			bp += 4;
		}
		compress(MDbuf, X);
		vbytesindex = 0;
	}
}

void
collect_more(byte *bp, int nbytes, int entropybits)
/*
 * Throw a bunch of information into the machine.
 * The user supplies a hopefully pessimistic estimate of the entropy
 */
{

	nrandombits += entropybits;
#ifdef BIGDEALX
	if (flog) {
		int i;

		fprintf(flog, "collect_more(");
		for (i=0; i < nbytes; i++)
			fprintf(flog, "%02x", bp[i]);
		fprintf(flog, ", %d, %d) -> %d\n", nbytes, entropybits, nrandombits);
	}
#endif
	while(nbytes > 0) {
		collect_byte(*bp);
		nbytes--;
		bp++;
	}
}

void
collect_finish(byte *hash)
/*
 * Halt the hashing engine
 * Extract the result into hash[]
 */
{
	int i;

	MDfinish(MDbuf, variousbytes, nhashbytes, 0);
#ifdef BIGDEALX
	if (flog)
		fprintf(flog, "collected %d random bits, from %d bytes of data\n",
			nrandombits, nhashbytes);

#endif
	for (i=0; i<RMDbytes; i+=4) {
		hash[i]   =  MDbuf[i>>2];         /* implicit cast to byte  */
		hash[i+1] = (MDbuf[i>>2] >>  8);  /*  extracts the 8 least  */
		hash[i+2] = (MDbuf[i>>2] >> 16);  /*  significant bits.     */
		hash[i+3] = (MDbuf[i>>2] >> 24);
	}
}
