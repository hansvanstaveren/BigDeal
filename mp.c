#include "types.h"
#include "bigdeal.h"
#include <memory.h>

static char rcsid[] = "$Header: /home/sater/bridge/bigdeal/RCS/mp.c,v 1.10 2000/08/16 15:06:05 sater Exp $";

/*
 * Multiple precision arithmetic
 * Format is 12 byte number( 96 bits), with lowest byte most significant
 * (socalled bigendian format)
 */

void
mp96_zero(byte *b)
/*
 * Sets b to zero
 */
{

	memset(b, 0, L);
}

void
mp96_one(byte *b)
/*
 * Sets b to one
 */
{

	memset(b, 0, L-1);
	b[L-1] = 1;
}

void
mp96_assign(byte *b, byte *b1)
/*
 * Assign b1 to b
 */
{

	memcpy(b, b1, L);
}

int
mp96_add(byte *b,byte *b1,byte *b2)
/*
 * Computes b=b1+b2
 * returns carry bit signifying overflow
 */
{
	int i;
	unsigned int h,carry;

	carry = 0;
	for (i=L-1; i>=0; i--) {
		h = b1[i]+b2[i]+carry;
		carry = h>=256 ? 1 : 0;
		b[i] = h;		/* Truncates to 8 bits automatically */
	}
	return carry;
}

int
mp96_sub(byte *b,byte *b1,byte *b2)
/*
 * Computes b=b1-b2
 * returns borrow bit signifying overflow
 */
{
	int i,h;
	unsigned int borrow;

	borrow = 0;
	for (i=L-1; i>=0; i--) {
		h = b1[i]-b2[i]-borrow;
		borrow = h<0 ? 1 : 0;
		b[i] = h;
	}
	return borrow;
}

int
mp96_cmp(byte *b1, byte *b2)
/*
 * Compares b1 with b2
 * returns >0 when b1>b2, <0 when b1<b2, 0 when b1==b2
 */
 {
	int i;
	int diff;

	for (i=0; i<L; i++) {
		diff = b1[i] - b2[i];
		if (diff)
			return diff;
	}
	return 0;
}

void
mp96_mul(byte *b,byte *b1,byte *b2)
/*
 * Computes b=b1*b2
 * overflow goes undetected
 */
{
	int i,j;
	unsigned int h,carry;
	byte b1copy[L],b2copy[L],bpart[L];

	/*
	 * Make copies of input in case one of the inputs is also output
	 */
	mp96_assign(b1copy, b1);
	mp96_assign(b2copy, b2);

	/*
	 * Here if an input is also output the input gets overwritten
	 */
	mp96_zero(b);

	for (i=L-1; i>=0; i--) {
		for (j=L-1; j>i; j--)
			bpart[j] = 0;
		carry=0;
		for (j=i; j>=0; j--) {
			h = b1copy[i]*b2copy[L-1+j-i]+carry;
			carry = h/256;
			bpart[j] = h;
		}
		(void) mp96_add(b,b,bpart);
	}
}
