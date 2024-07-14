#include "types.h"
#include "bigdeal.h"
#include "mp.h"

/*
 * functions implementing or using the (n over k) mathematical construct
 */

static byte pascal_triangle[NCARDSPERDECK+1][NCARDSPERHAND+1][L];

void
binomial_start(void)
/*
 * Precomputes all numbers (n over k) with k<=NCARDSPERHAND and
 * n<=NCARDSPERDECK.
 * Numbers are stored in pascal_triangle[][] with L bytes precision (96 bits)
 *
 * Calculation method is the addition from the top of the triangle
 * with the equation:
 * 	n_over_k(n,k) = n_over_k(n-1, k-1) + n_over_k(n-1, k)
 * except for some boundary condition situations
 */
{
	int i,j,min;

	for (i=0; i<=NCARDSPERDECK; i++) {
		if (i<NCARDSPERHAND)
			min = i;
		else
			min = NCARDSPERHAND;
		for (j=0; j<=min; j++) {
			if (i==j || j==0)
				mp96_one(pascal_triangle[i][j]);
			else
				mp96_add(pascal_triangle[i][j],
					   pascal_triangle[i-1][j],
					   pascal_triangle[i-1][j-1]);
		}
	}
}

void
n_over_k(int n, int k, byte *b)
/*
 * "Compute" (n over k) in L bytes(96 bits) precision
 * Actually just read from pascal_triangle
 *
 * Result stored into b[]
 */
{ 
	if (n<=NCARDSPERDECK && k<=NCARDSPERHAND && k<=n)
		mp96_assign(b, pascal_triangle[n][k]);
	else
		mp96_zero(b);
}

void
code_to_hand(dl_num *dnp, dl_int *dip)
/*
 * This function converts a given number to its associated bridge-deal.
 * Read the file Godel.pdf for an explanation of the code. The
 * variable-names used in the comments refer to the variable-names
 * that were used in the pseudo-code in Godel.pdf.
 */
{
	int i,j,a,b;
	byte c[L];
	byte g[L];
	byte tmp1[L],tmp2[L],tmp3[L];
	int compass;

	/*
	 * set g_{-1} = g
	 */
	mp96_assign(g, dnp->dn_num);

	for (compass=COMPASS_NORTH; compass<NCOMPASS; compass++) {
		/*
		 * Computation of an appropriate constant for the given
		 * compass direction. The constant is equal to:
		 * 39_over_13 x 26_over_13   for North,
		 * 26_over_13                for East,
		 * 1                         for South.
		 *
		 * Code continues for West who automatically gets 13 zeroes
		 */
		mp96_one(c);
		for (i=2; i<=COMPASS_WEST-compass; i++) {
			n_over_k(i*13, 13, tmp1);
			mp96_mul(c, tmp1, c);
		}

		/*
		 * set a_{-1} = 0
		 */
		a = 0;
		for (j=0; j<NCARDSPERHAND; j++) {
			/* 
			 * Computation of a_j, x_j and g_j.
			 * a_j is computed by setting variable b to a_{j-1} and
			 * incrementing it until it reaches the value a_j.
			 */
			n_over_k(13*(NCOMPASS-compass)-a-j, 13-j, tmp1);

			/*
			 * b is set to a_{j-1} and up
			 */
			for(b=a; ; b++) {
				n_over_k(13*(NCOMPASS-compass)-b-1-j, 13-j, tmp2);
				mp96_sub(tmp2, tmp1, tmp2);
				mp96_mul(tmp2, tmp2, c);
				/*
				 * Check if b < a_j, i.e. if tmp2 > g
				 */
				if (mp96_cmp(tmp2, g) > 0)
					break;
			}
			n_over_k(13*(NCOMPASS-compass)-a-j, 13-j, tmp1);
			n_over_k(13*(NCOMPASS-compass)-b-j, 13-j, tmp2);
			mp96_sub(tmp3, tmp1, tmp2);
			/*
			 * tmp1 is assigned the value x_j
			 */
			mp96_mul(tmp1, tmp3, c);
			/*
			 * g_j = g_{j-1} - x_j
			 */
			mp96_sub(g, g, tmp1);
			dip->di_hand[compass][j] = b;
			/*
			 * a is set to a_j
			 */
			a = b;
		}
	}
}
