/*
bridge.c

Goedel number for bridge card distributions

Created:	Dec 13, 1993 by Philip Homburg <philip@cs.vu.nl>
*/


#include <mp.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#if __STDC__
#define ARGS(a) a
#else
#define ARGS(a) ()
#endif

MINT *table[64][16][64];

MINT *c ARGS(( int n, int k, int m ));
MINT *goedel ARGS(( int hand[4][13] ));
void goedel_rev ARGS(( MINT *g_nr, int hand[4][13] ));
int main ARGS(( void ));
int rev_cmp ARGS(( const void *e1, const void *e2 ));
void print_hand ARGS(( int hand[4][13] ));

/*
 * n aantal kaarten dat nog moet worden verdeeld, waarde 0 .. n-1
 * k = n%13
 * m is bovengrens waarde uit te delen kaart aan deze speler, niet inclusief
 *
 * resultaat is aantal mogelijke manieren
 */

MINT *c(n, k, m)
int n;
int k;
int m;
{
	int i;
	MINT *sum, *newsum, **tp;

	assert(n >= 0);
	assert(k >= 0);
	assert(m >= 0);

	tp= &table[n][k][m];
	if (*tp != NULL)
		return *tp;

	assert(m<=n);
	assert(k<=n);
	assert(k<=13);
	if (k == 0)
	{
		if (n == 0)
		{
			*tp= itom(1);
			return *tp;
		}
		k= 13;
		m= n;
	}
	sum= itom(0);
	for (i= 0; i<m; i++)
	{
		/* newsum= itom(0); */
		madd(sum, c(n-1, k-1, i), sum);
		/* mfree(sum); 
		sum= newsum; */
	}
	*tp= sum;
	return sum;
}

MINT *goedel(hand)
int hand[4][13];
{
	int list[52];
	int i, j, k, m, n;
	MINT *sum;

	qsort(&hand[0][0], 13, sizeof(hand[0][0]), rev_cmp);
	qsort(&hand[1][0], 13, sizeof(hand[1][0]), rev_cmp);
	qsort(&hand[2][0], 13, sizeof(hand[2][0]), rev_cmp);
	qsort(&hand[3][0], 13, sizeof(hand[3][0]), rev_cmp);

	sum= itom(0);
	n= 52;
	for (i= 0; i<52; i++)
		list[i]= i;
	for (i= 0; i<4; i++)
	{
		for (j= 0; j<13; j++)
		{
			m= list[hand[i][j]];
			madd(sum, c(n, 13-j, m), sum);
			for (k= hand[i][j]; k<52; k++)
				list[k]--;
			n--;
		}
	}
	return sum;
}

int rev_cmp(e1, e2)
const void *e1;
const void *e2;
{
	assert (*(int *)e1 != *(int *)e2);

	if (*(int *)e1 < *(int *)e2)
		return 1;
	else 
		return -1;
}

void goedel_rev(g_nr, hand)
MINT *g_nr;
int hand[4][13];
{
	int i, j, k;
	int n;
	int list[52];
	int index;

	for (i= 0; i<52; i++)
		list[i]= i;
	n= 52;
	
	for (i= 0; i<4; i++)
	{
		for (j= 0; j<13; j++)
		{
			for (k= 0; k<n; k++)
			{
				if (mcmp(c(n, 13-j, k+1), g_nr) > 0)
					break;
			}
			index= k;
			msub(g_nr, c(n, 13-j, k), g_nr);
			hand[i][j]= list[index];
			for (k= index+1; k<n; k++)
				list[k-1]= list[k];
			n--;
		}
	}
}

void print_hand(hand)
int hand[4][13];
{
	int i, j;
	printf("(");
	for (i= 0; i<4; i++)
	{
		printf(" (");
		for (j= 0; j<13; j++)
		{
			printf("%d", hand[i][j]);
			if (j != 12) printf(", ");
		}
		printf(")");
		if (i != 3)
			printf(", ");
	}
	printf(")\n");
}

int g0[4][13]=
{
	{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12},
	{13,14,15,16,17,18,19,20,21,22,23,24,25},
	{26,27,28,29,30,31,32,33,34,35,36,37,38},
	{39,40,41,42,43,44,45,46,47,48,49,50,51}
};
int g1[4][13]=
{
	{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12},
	{13,14,15,16,17,18,19,20,21,22,23,24,25},
	{26,27,28,29,30,31,32,33,34,35,36,37,39},
	{38,40,41,42,43,44,45,46,47,48,49,50,51}
};
int g_last_min1[4][13]=
{
	{51,50,49,48,47,46,45,44,43,42,41,40,39},
	{38,37,36,35,34,33,32,31,30,29,28,27,26},
	{25,24,23,22,21,20,19,18,17,16,15,14,12},
	{13,11,10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0}
};
int g_last[4][13]=
{
	{51,50,49,48,47,46,45,44,43,42,41,40,39},
	{38,37,36,35,34,33,32,31,30,29,28,27,26},
	{25,24,23,22,21,20,19,18,17,16,15,14,13},
	{12,11,10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0}
};

int main()
{
	int i, j, k;
	int hand[4][13];
	MINT *g_nr0, *g_nr1, *g_nr_last_min1, *g_nr_last, *g_nr;

	for (i= 0; i<52; i++)
	{
		k= i%13;
		for (j= 0; j<i; j++)
			c(i,k,j);
	}

	mout(c(1,1,1));
	mout(c(52,13,52));

	mout(g_nr0= goedel(g0));
	mout(g_nr1= goedel(g1));
	mout(g_nr_last_min1= goedel(g_last_min1));
	mout(g_nr_last= goedel(g_last));

	goedel_rev(g_nr0, hand);
	print_hand(hand);
	goedel_rev(g_nr1, hand);
	print_hand(hand);
	goedel_rev(g_nr_last_min1, hand);
	print_hand(hand);
	goedel_rev(g_nr_last, hand);
	print_hand(hand);

	g_nr= itom(0);
	for (;;)
	{
		printf("enter goedel number: ");
		fflush(stdout);
		min(g_nr);
		goedel_rev(g_nr, hand);
		print_hand(hand);
	}
}
