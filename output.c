#include "types.h"
#include "bigdeal.h"
#include "binomial.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Next type is a tagged union to prevent compilers complaining
 * Should check on tag
 */
typedef
struct hand_rep {
	int	hr_baseform;	/* Which baseform is this in */
	union {
		dl_num	*hv_dnp;
		dl_int	*hv_dip;
		dl_byh	*hv_dbhp;
		dl_byc	*hv_dbcp;
	}	hr_value;
} hr_t, *hr_p;

static progparams_p	prparp;		/* All parameters */

/*
 * Information per output type is collected here
 */
typedef
struct output_format {
	char *	of_name;	/* Name of format */
	int	of_flags;	/* Various flags */
	FILE *	of_file;	/* Output file to write it to */
	char *	of_suffix;	/* File suffix/type */
	int	of_baseform;	/* Which internal format it is printed from */
	int	of_high_board;	/* Highest possible boardnumber */
	char *	of_help;	/* Help description */
	void	(*of_init)(FILE *f);	/* Routine to init */
	void	(*of_printit)(FILE *f, int boardno, hr_p arg);	/* Routine to print it */
	void	(*of_finish)(FILE *f);	/* Routine to finish */
} of_t, *of_p;

/*
 * Values for the of_flags struct member
 */
#define OFF_USEIT	0x1	/* Use the format this run */
#define OFF_BINARY	0x2	/* Output is binary, not text */

static void
cnv_int_byh(dl_int *dip, dl_byh *dbhp)
/*
 * Converts the internal handrepresentation from
 * *dip to a "bri" like coding in *dbhp.
 * This representation is as follows:
 * The 52 cards are numbered 1: AS, 2 KS, .... , 52 2C
 * and all thirteen slots for all four hands are filled in with one of
 * the 52 cards.
 *
 * Given the way this program works the order of cards per hand will
 * be strictly increasing.
 */
{
    int nextcard[NCARDSPERDECK+1];
    int i;
    int card,prevcard;
    int skip, skipcnt;
    int compass;

    /*
     * Setup a chain of 52 cards with a linked list type structure
     */
    for (i=0; i<NCARDSPERDECK; i++)
	nextcard[i] = i+1;
    nextcard[NCARDSPERDECK] = 0;

    /*
     * Run through the hand converting skip numbers to cards
     */
    for (compass=COMPASS_NORTH; compass<=COMPASS_WEST; compass++) {
	/*
	 * Get to the beginning of all leftover cards
	 */
	prevcard = 0;
	card = nextcard[prevcard];
	/*
	 * Go select the thirteen cards for this hand
	 */
	for (i=0; i<NCARDSPERHAND; i++) {
	    /*
	     * For the first card use number of skips directly
	     * for all other cards the extra skip compared to
	     * the previous card
	     */
	    if (i==0)
		skip=dip->di_hand[compass][0];
	    else
		skip=dip->di_hand[compass][i] - dip->di_hand[compass][i-1];
	    for (skipcnt=0; skipcnt<skip; skipcnt++) {
		prevcard = card;
		card = nextcard[card];
	    }
	    dbhp->dh_hand[compass][i] = card;
	    /*
	     * Take card just selected out of the linked list
	     */
	    card = nextcard[card];
	    nextcard[prevcard] = card;
	}
    }
}

static void
cnv_byh_byc(dl_byh *dbhp, dl_byc *dbcp)
/*
 * Convert from a "bri" like coding to a cardposition type coding.
 * Representation is an array of 52 cards, from AS to 2C,
 * with as a value the compass position, 0 for N, 3 for W
 *
 * Note the -1 to convert from 1..52 cardnotation to 0..51 array index
 */
{
	int compass, card;

	for (compass = COMPASS_NORTH; compass <= COMPASS_WEST; compass++)
		for (card = 0; card < NCARDSPERHAND; card++)
			dbcp->dc_card[dbhp->dh_hand[compass][card] - 1] =
				compass;
}

static void
out_fill(FILE *out, char filler, int count)
/*
 * Write filler character, count times
 */
{
	int i;

	for(i=0; i<count; i++)
		putc(filler, out);
}

static void
out_bri(FILE *out, dl_byh *dbhp)
/*
 * Write out the "bri" record, no filler
 */
{
	int compass, i;

	/*
	 * Note the <COMPASS_WEST
	 * In this format only the hands of North, East and South are given
	 * West is left as an exercise for the Duplimate
	 * (West just gets what is left over)
	 */
	for (compass=COMPASS_NORTH; compass<COMPASS_WEST; compass++)
		for (i=0; i<NCARDSPERHAND; i++)
			fprintf(out,"%02d",dbhp->dh_hand[compass][i]);
}

/*ARGSUSED*/
static void
print_bri(FILE *out, int boardno, hr_p hrp)
/*
 * Writes out "bri" format, including filler
 *
 * It is unknown whether the strange half space, half zero fill
 * is actually necessary. This is just the way I saw my first BRI file
 */
{
	dl_byh *dbhp = hrp->hr_value.hv_dbhp;

	out_bri(out, dbhp);
	out_fill(out, ' ', 32);
	out_fill(out, 0, 18);
}

static void
out_cardrep(FILE *out, dl_byh *dbhp, char *suitstr[NCOMPASS][NSUIT], char *cardrep)
/*
 * Write out a "dge" or "pbn" record, no filler
 */
{
	int compass;
	int suit;
	int i;
	int card, card_in_suit;

	for (compass=COMPASS_NORTH; compass<=COMPASS_WEST; compass++) {
		for (suit=SUIT_SPADES; suit<=SUIT_CLUBS; suit++) {
			fputs(suitstr[compass][suit], out);
			for (i=0; i<NCARDSPERHAND; i++) {
				/*
				 * Get card in this position for player
				 * If it is part of the suit we are working on
				 * (1..13 for spades, upto 40..52 for clubs)
				 * print it.
				 */
				card = dbhp->dh_hand[compass][i];
				card_in_suit = card - 13*suit;
				if (card_in_suit > 0 && card_in_suit <= 13)
					putc(cardrep[card_in_suit-1], out);
			}
		}
	}
}

/*
 * International card representation
 *
 * Maybe this will need to be changed for local formats
 */
static char cardrep_int[] = "AKQJT98765432";

/*
 * The suit symbols in the DOS character set
 */
#define DOSCHAR_SPADE	6
#define DOSCHAR_HEART	3
#define DOSCHAR_DIAMOND	4
#define DOSCHAR_CLUB	5

static char dosstr_spade[]	= { DOSCHAR_SPADE, 0 };
static char dosstr_heart[]	= { DOSCHAR_HEART, 0 };
static char dosstr_diamond[]	= { DOSCHAR_DIAMOND, 0 };
static char dosstr_club[]	= { DOSCHAR_CLUB, 0 };
static char *dge_suitstr[NCOMPASS][NSUIT] = {
	{ dosstr_spade, dosstr_heart, dosstr_diamond, dosstr_club },
	{ dosstr_spade, dosstr_heart, dosstr_diamond, dosstr_club },
	{ dosstr_spade, dosstr_heart, dosstr_diamond, dosstr_club },
	{ dosstr_spade, dosstr_heart, dosstr_diamond, dosstr_club },
};

static void
out_dge(FILE *out, dl_byh *dbhp)
/*
 * Write out the "dge" record, no filler
 */
{

	out_cardrep(out, dbhp, dge_suitstr, cardrep_int);
}

/*ARGSUSED*/
static void
print_dge(FILE *out, int boardno, hr_p hrp)
/*
 * Writes out "dge" format, including filler
 */
{
	dl_byh *dbhp = hrp->hr_value.hv_dbhp;

	out_dge(out, dbhp);
	out_fill(out, 0, 60);
}

/*
 * Portable Bridge Notation
 *
 * We generate PBN "Import" format, according to the instructions
 * from KGB
 */
static char pbn_colon[]	= ":";
static char pbn_space[]	= " ";
static char pbn_dot[]	= ".";
static char *pbn_suitstr[NCOMPASS][NSUIT] = {
	{ pbn_colon, pbn_dot, pbn_dot, pbn_dot },
	{ pbn_space, pbn_dot, pbn_dot, pbn_dot },
	{ pbn_space, pbn_dot, pbn_dot, pbn_dot },
	{ pbn_space, pbn_dot, pbn_dot, pbn_dot },
};

static void
out_pbn(FILE *out, dl_byh *dbhp)
/*
 * Write out the "pbn" record, just the hand itself
 */
{

	out_cardrep(out, dbhp, pbn_suitstr, cardrep_int);
}

static void
out_pbn_rec(FILE *out, char *keyw, char *value)
{

	fprintf(out, "[%s \"%s\"]\n", keyw, value ? value : "?");
}

static char *dealerstr[] = { "W", "N", "E", "S" };
static char *pbn_vulnrep[] = { "None", "NS", "EW", "All" };
static int vuln_index[16] = {
	2,	0,	1,	2,
	3,	1,	2,	3,
	0,	2,	3,	0,
	1,	3,	0,	1
};

static void init_pbn(FILE *out) {

	fprintf(out, "%% PBN 2.1\n%% EXPORT\n%%\n");
	fprintf(out, "[Generator \"Big Deal version %d.%d%s\"]\n",
		VERSION_MAJOR, VERSION_MINOR, VERSION_PAREN);
}

static void
print_pbn(FILE *out, int boardno, hr_p hrp) {
	dl_byh *dbhp = hrp->hr_value.hv_dbhp;

	out_pbn_rec(out,"Event", 0);
	out_pbn_rec(out,"Site", 0);
	out_pbn_rec(out,"Date", 0);
	fprintf(out, "[Board \"%d\"]\n", boardno);
	out_pbn_rec(out,"West", 0);
	out_pbn_rec(out,"North", 0);
	out_pbn_rec(out,"East", 0);
	out_pbn_rec(out,"South", 0);
	out_pbn_rec(out,"Dealer", dealerstr[boardno%4]);
	out_pbn_rec(out,"Vulnerable", pbn_vulnrep[vuln_index[boardno%16]]);
	fprintf(out, "[Deal \"N");
	out_pbn(out, dbhp);
	fprintf(out, "\"]\n");
	out_pbn_rec(out,"Scoring", 0);
	out_pbn_rec(out,"Declarer", 0);
	out_pbn_rec(out,"Contract", 0);
	out_pbn_rec(out,"Result", 0);
	fprintf(out, "\n");
}

/*
 * CSV format, for database import
 */

static char csv_begin[]	= "\"";
static char csv_intra[]	= "\",\"";
static char *csv_suitstr[NCOMPASS][NSUIT] = {
	{ csv_begin, csv_intra, csv_intra, csv_intra },
	{ csv_intra, csv_intra, csv_intra, csv_intra },
	{ csv_intra, csv_intra, csv_intra, csv_intra },
	{ csv_intra, csv_intra, csv_intra, csv_intra },
};
static char *csv_vulnrep[] = { "-", "NS", "EW", "All" };

static void
print_csv(FILE *out, int boardno, hr_p hrp)
/*
 * Write out a CSV record
 */
{
	dl_byh *dbhp = hrp->hr_value.hv_dbhp;

	out_cardrep(out, dbhp, csv_suitstr, cardrep_int);
	fprintf(out, "\",\"%d\",\"%s/%s\"\n",
		boardno,
		dealerstr[boardno%4],
		csv_vulnrep[vuln_index[boardno%16]]);
}

/*
 * DUP and DLM formats, for Jannersten Duplimate machine
 */

static void
print_dup_common(FILE *out, int boardno, dl_byh *dbhp, int not_on_screen)
/*
 * Write out a "dup" record
 * This is actually a BRI, followed by a DGE, and some padding
 */
{

	/*
	 * Horribly convoluted hack upon hack format
	 *
	 * Duplimate, generation X
	 */
	out_bri(out, dbhp);
	if (boardno == 1 && not_on_screen) {
		out_fill(out, ' ', 68);
	} else {
		out_dge(out, dbhp);
	}
	putc('Y', out);		/* Y to Random Hands */
	putc('N', out);		/* N to reverse order */
	putc('1', out);		/* Start at board 1 */
	putc(' ', out);
	putc(' ', out);
	putc('0', out);		/* No copies immediate */
	putc(' ', out);
	putc('0' + (prparp->pp_nboards/10)%10, out);/* tens of number */
	putc('0' + prparp->pp_nboards%10, out);	/* units of number */
	putc(' ', out);
}

/*ARGSUSED*/
static void
print_dup(FILE *out, int boardno, hr_p hrp)
{
	dl_byh *dbhp = hrp->hr_value.hv_dbhp;

	print_dup_common(out, boardno, dbhp, 0);
}

/*ARGSUSED*/
static void
print_dupblind(FILE *out, int boardno, hr_p hrp)
{
	dl_byh *dbhp = hrp->hr_value.hv_dbhp;

	print_dup_common(out, boardno, dbhp, 1);
}

static void
fill_dlm(FILE *out, int lowbrd, int highbrd)
{
	int i;
	int checksum;

	for (i=lowbrd+1; i<highbrd; i++) {
		checksum = i^14;	/* KGB calculated */
		fprintf(out, "Duplicates %02d=0\n", i);
		fprintf(out, "Board %02d=aaaaaabffffffkkkkkklpppppp%03d\n",
			i, checksum);
	}
}

static void
init_dlmcommon(FILE *out, int dups, int show)
{
	int checksum;

	/*
	 * Very badly documented, sorry(not my fault)
	 */
	fprintf(out, "[Document]\n");
	fprintf(out, "Headline=Generated by Big Deal version %d.%d%s\n",
		VERSION_MAJOR, VERSION_MINOR, VERSION_PAREN);
	fprintf(out, "Status=%s\n", show ? "Show" : "Sealed");
	fprintf(out, "Duplicates=%d\n", dups);
	fprintf(out, "From board=%d\n",
		prparp->pp_lowboard<=99 ? prparp->pp_lowboard : 99);
	fprintf(out, "To board=%d\n",
		prparp->pp_highboard<=99 ? prparp->pp_highboard : 99);
	fprintf(out, "Next board to duplimate=0\n");
	fprintf(out, "PrintOuts=0\n");
	fprintf(out, "Crypto key=0\n");
	checksum = dups ^ prparp->pp_lowboard ^ prparp->pp_highboard;
	if (show)
		checksum ^= 1;	/* XOR with 1 if show */
	fprintf(out, "Checksum=%d\n", checksum);
	fill_dlm(out, 0, prparp->pp_lowboard);
}

static void
init_dlm(FILE *out)
{

	init_dlmcommon(out, 0, 1);
}

static void
init_dlmblind(FILE *out)
{

	init_dlmcommon(out, 0, 0);
}

static void
print_dlm(FILE *out, int boardno, hr_p hrp)
/*
 * Writes out one DLM record, including "checksum"
 * Record is mainly one lower case character per two cards
 */
{
	dl_byc *dbcp = hrp->hr_value.hv_dbcp;
	int i;
	int c;
	int checksum;

	if (boardno>99)	/* Format cannot do more than 99 */
		return;
	fprintf(out, "Duplicates %02d=0\n", boardno);
	fprintf(out, "Board %02d=", boardno);
	checksum = boardno;
	for(i=0; i<NCARDSPERDECK/2; i++) {
		c = 'a';
		c += dbcp->dc_card[2*i+0]<<2;
		c += dbcp->dc_card[2*i+1]<<0;
		putc(c, out);
		checksum ^= c;
	}
	fprintf(out, "%03d\n", checksum);
}

static void
finish_dlm(FILE *out)
/*
 * For some reason a DLM file always contains exactly 99 hands
 * fill it up with bogus hands here
 */
{

	fill_dlm(out, prparp->pp_highboard, 100);
}

/*ARGSUSED*/
static void
print_ber(FILE *out, int boardno, hr_p hrp)
/*
 * Writes out "ber" format, no filler or separators
 */
{
	dl_byc *dbcp = hrp->hr_value.hv_dbcp;
	int i;

	for(i=0; i<NCARDSPERDECK; i++)
		putc('1' + dbcp->dc_card[i], out);
}

/*
 * Borel files contain lines of 52 characters [A-Za-z]
 * A is AS to z is 2c
 * For some reason the line does not start with the cards of North
 * but the cards of the dealer.
 */
static void
init_borel(FILE *out)
{

	fprintf(out, "\n");
}

static void
print_borel(FILE *out, int boardno, hr_p hrp)
/*
 * Write out a "bhg" record
 */
{
	dl_byh *dbhp = hrp->hr_value.hv_dbhp;
	int i, j, compass, card;

	for (i=0; i<NCOMPASS; i++) {
		/*
		 * Start at dealer of this hand
		 */
		compass = (boardno - 1 + i) % NCOMPASS;
		for (j=0; j<NCARDSPERHAND; j++) {
			card = dbhp->dh_hand[compass][j];
			putc(card <= 2*NCARDSPERHAND ?
				'A'+card-1 : 'a'+card-2*NCARDSPERHAND-1,
				out);
		}
	}
	fprintf(out, "\n");
}

void
init_kops(FILE *out) {
    int nb = prparp->pp_nboards;

    putc(nb&0xff, out);
    putc((nb>>8)&0xff, out);
    out_fill(out, ' ', 11);
}

static void
print_kops_cds(FILE *out, dl_byc *dbcp, int rotoffset) {
    int card, byte, suit, cardno, cardpos;

    for (card=0; card<NCARDSPERHAND; card++) {
	byte = 0;
	for (suit=0; suit<NSUIT; suit++) {
	    cardno = NCARDSPERHAND*suit+card;
	    cardpos = dbcp->dc_card[cardno];
	    cardpos = (cardpos+rotoffset)%NSUIT;
	    byte |= cardpos << 2*(NSUIT-1-suit);
	}
	putc(byte, out);
    }
}

static void
print_kops(FILE *out, int boardno, hr_p hrp) {
    dl_byc *dbcp = hrp->hr_value.hv_dbcp;

    print_kops_cds(out, dbcp, 0);
}

static void
print_cds(FILE *out, int boardno, hr_p hrp) {
    dl_byc *dbcp = hrp->hr_value.hv_dbcp;

    putc(boardno, out);
    print_kops_cds(out, dbcp, 1);
}

#ifdef BIGDEALX

#include "mp.h"

/*
 * A decimal number corresponding to a deal has maximum 29 digits
 */
#define MAXDECIMALS 29
static byte powers_of_ten[MAXDECIMALS][L];

static void
init_goedel(FILE *out)
{
	int i;
	byte ten[L];

	/*
	 * Initialize the array with powers of ten
	 * We need them in the next function
	 */
	mp96_zero(ten);
	ten[L-1] = 10;
	mp96_one(powers_of_ten[0]);
	for (i=1; i<MAXDECIMALS; i++) {
		mp96_mul(powers_of_ten[i], powers_of_ten[i-1], ten);
	}
}

/*ARGSUSED*/
static void
print_goedel(FILE *out, int boardno, hr_p hrp)
/*
 * Write out the internal 96 bit numbers as a decimal number
 *
 * Unlikely that anyone would ever want this in real life
 */
{
	dl_num *dnp = hrp->hr_value.hv_dnp;
	byte value[L];
	int i;
	int decimal;
	int zero_suppress;
	char outchar;

	mp96_assign(value, dnp->dn_num);
	zero_suppress = 1;
	for (i=MAXDECIMALS-1; i>=0; i--) {
		/*
		 * Since we do not have division we do repeated subtraction
		 */
		decimal = 0;
		while (mp96_cmp(value, powers_of_ten[i])>=0) {
			mp96_sub(value, value, powers_of_ten[i]);
			decimal++;
		}
		if (decimal) {
			outchar = decimal + '0';
			zero_suppress = 0;
		} else {
			/*
			 * Suppress leading zeroes
			 * Special case all zeroes also handled
			 * That will be the day....
			 */
			outchar = zero_suppress && i ? ' ' : '0';
		}
		putc(outchar, out);
		/*
		 * Intersperse with commas for readability
		 */
		if (i%3 == 0) {
			putc(i==0 ? '\n' : zero_suppress ? ' ' : ',', out);
		}
	}
}

/*
 * Statistics computation:
 * There is a strong argument *not* to print statistics of a set of deals
 * since it leads itself to abuse only too easily.
 * Therefore this is only included in the non-safe version.
 */

static struct {
	int	st_sumsquare;
	int	st_hcp[NCOMPASS];
	int	st_hcpfreq[38];		/* 0..37, maximum points per hand */
	int	st_lsuitfreq[NCOMPASS][14];	/* 4..13, longest suit per compass */
	int	st_longestsuit;		/* longest suit in whole set */
} stats;

/*
 * Theoretical values taken from Encyclopedia, fourth edition, page 278
 */
static int theory_hcpfreq[38] = {	/* times 10000 */
	3639,		/* 0 */
	7884,		/* 1 */
	13561,		/* 2 */
	24624,		/* 3 */
	38454,		/* 4 */
	51862,		/* 5 */
	65541,		/* 6 */
	80281,		/* 7 */
	88922,		/* 8 */
	93562,		/* 9 */
	94051,		/* 10 */
	89447,		/* 11 */
	80269,		/* 12 */
	69143,		/* 13 */
	56933,		/* 14 */
	44237,		/* 15 */
	33109,		/* 16 */
	23617,		/* 17 */
	16051,		/* 18 */
	10362,		/* 19 */
	6435,		/* 20 */
	3779,		/* 21 */
	2100,		/* 22 */
	1119,		/* 23 */
	559,		/* 24 */
	264,		/* 25 */
	117,		/* 26 */
	49,		/* 27 */
	19,		/* 28 */
	7,		/* 29 */
	2,		/* 30 */
	1, 1, 1, 1, 1, 1, 1	/* 31..37 */
};

static int theory_lsuitfreq[14] = {	/* probability * 1000000 */
	0, 0, 0, 0,	/* cannot be 0 1 2 3 */
	350805,		/* 4 */
	443596,		/* 5 */
	165477,		/* 6 */
	35265,		/* 7 */
	4668,		/* 8 */
	370,		/* 9 */
	16,		/* 10 */
	0, 0, 0		/* 11 .. 13 */
};


static int high_card_points[13] = { 4, 3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

/*ARGSUSED*/
static void
init_stat(FILE *out)
{

	/*
	 * Warn of consequences of looking at statistics
	 */
	printf("\nStatistics will be produced in an accompanying file.\n");
	printf("Usage of these statistics for a decision on whether or when\n");
	printf("to play this set of deals is a violation of the spirit of the\n");
	printf("Laws of Duplicate Contract Bridge.\n\n");
	printf("STATISTICS ARE FOR DISPLAY PURPOSES ONLY!!\n\n");
	/*
	 * At this point initialize counters if non-zero
	 */
}

/*ARGSUSED*/
static void
compute_stat(FILE *out, int boardno, hr_p hrp)
/*
 * Compute statistics on this hand
 */
{
	dl_byh *dbhp = hrp->hr_value.hv_dbhp;
	int i, compass, card;
	int length, maxlength, suitlength[NCOMPASS][NSUIT];
	int hcp;

	for (compass=0; compass<NCOMPASS; compass++) {
		for (i=0; i<NSUIT; i++)
			suitlength[compass][i] = 0;
		hcp = 0;
		for (i=0; i<NCARDSPERHAND; i++) {
			/*
			 * Note the -1 to convert from 1..52 to 0..51
			 */
			card = dbhp->dh_hand[compass][i]-1;
			/*
			 * card/13 should be suit
			 */
			suitlength[compass][card/13]++;
			/*
			 * card%13 should be pip
			 */
			hcp += high_card_points[card%13];
		}
		stats.st_hcp[compass] += hcp;
		stats.st_hcpfreq[hcp]++;
		maxlength = 0;
		for (i=0; i<NSUIT; i++) {
			length = suitlength[compass][i];
			if (length > maxlength)
				maxlength = length;
			stats.st_sumsquare += length*length;
		}
		if (maxlength > stats.st_longestsuit)
			stats.st_longestsuit = maxlength;
		stats.st_lsuitfreq[compass][maxlength]++;
	}
	/*
	 * Now suitlength[][] contains all suit lengths for all hands
	 * 16 numbers in all.
	 * Statistics about distribution to be added here.
	 */
}

static void
print_avg(FILE *out, int sum, int divisor, int decimals, char *termstr)
/*
 * Prevent use of floating point
 */
{
	int power_of_ten;
	int i;
	int result;

	power_of_ten = 1;
	for (i=0; i<decimals; i++)
		power_of_ten *= 10;

	sum *= power_of_ten;
	/*
	 * Make sure of proper rounding
	 */
	sum += divisor/2;
	result = sum/divisor;

	fprintf(out, "%d", result/power_of_ten);
	if (decimals) {
		fprintf(out, ".");
		for (i=0; i<decimals; i++) {
			result -= result/power_of_ten*power_of_ten;
			power_of_ten /= 10;
			fprintf(out, "%d", result/power_of_ten);
		}
	}
	fprintf(out, "%s", termstr);
}

static void
print_stat(FILE *out)
{
	int i, length;

	fprintf(out, "Number of deals: %d\n", prparp->pp_nboards);

	fprintf(out, "Average sum of squares: ");
	print_avg(out, stats.st_sumsquare, prparp->pp_nboards, 0, "\n");

	fprintf(out, "Average points NESW: ");
	print_avg(out, stats.st_hcp[0], prparp->pp_nboards, 2, " ");
	print_avg(out, stats.st_hcp[1], prparp->pp_nboards, 2, " ");
	print_avg(out, stats.st_hcp[2], prparp->pp_nboards, 2, " ");
	print_avg(out, stats.st_hcp[3], prparp->pp_nboards, 2, "\n");

	fprintf(out, "Frequency of high card points per hand:\n");
	for (i=0; i<38; i++) {
		if (stats.st_hcpfreq[i] == 0)
			continue;
		fprintf(out, "%2d points: ", i);
		print_avg(out, stats.st_hcpfreq[i]*100, prparp->pp_nboards*4, 4, "% (");
		print_avg(out, theory_hcpfreq[i], 10000, 4, "%)\n");
	}

	fprintf(out, "Frequency of longest suitlength per compass:\n");
	fprintf(out, "%8s%8s%8s%8s%8s Theory\n", "Length",
		"North", "East", "South", "West");
	for(length = 4; length <= stats.st_longestsuit; length++) {
		fprintf(out, "%8d%8d%8d%8d%8d ", length,
			stats.st_lsuitfreq[COMPASS_NORTH][length],
			stats.st_lsuitfreq[COMPASS_EAST][length],
			stats.st_lsuitfreq[COMPASS_SOUTH][length],
			stats.st_lsuitfreq[COMPASS_WEST][length]);
		print_avg(out, 100*theory_lsuitfreq[length],
			100000000/prparp->pp_nboards, 1, "\n");
	}
}
#endif

/*
 * All formats are set to not in use.
 * The output_specify_formats routine will set the wanted formats
 */
static
of_t output_formats[] = {
	{ "dup",	OFF_BINARY,	NULL,	".dup",	BF_BYHAND,
		99,	"Duplimate format",
		0,		print_dup,	0 },
	{ "dupblind",	OFF_BINARY,	NULL,	".dup",	BF_BYHAND,
		99,	"Duplimate format, no cards on screen",
		0,		print_dupblind,	0 },
	{ "dlm",		0,	NULL,	".dlm",	BF_BYCARD,
		99,	"New Duplimate format",
		init_dlm,	print_dlm,	finish_dlm },
	{ "dlmblind",		0,	NULL,	".dlm",	BF_BYCARD,
		99,	"New Duplimate format, no cards on screen",
		init_dlmblind,	print_dlm,	finish_dlm },
	{ "bri",	OFF_BINARY,	NULL,	".bri",	BF_BYHAND,
		0,	"BRI format",
		0,		print_bri,	0 },
	{ "dge",	OFF_BINARY,	NULL,	".dge",	BF_BYHAND,
		0,	"DGE format",
		0,		print_dge,	0 },
	{ "pbn",		0,	NULL,	".pbn",	BF_BYHAND,
		0,	"Portable Bridge Notation",
		init_pbn,	print_pbn,	0 },
	{ "csv",		0,	NULL,	".csv",	BF_BYHAND,
		0,	"Comma Separated Values",
		0,		print_csv,	0 },
	{ "ber",	OFF_BINARY,	NULL,	".ber",	BF_BYCARD,
		0,	"Bernasconi format",
		0,		print_ber,	0 },
	{ "borel",		0,	NULL,	".bhg",	BF_BYHAND,
		0,	"Borel Hand Generator format",
		init_borel,	print_borel,	0 },
	{ "kops",	OFF_BINARY,	NULL,	".rzd", BF_BYCARD,
		0,	"Kops format",
		init_kops,	print_kops,	0 },
	{ "cds",	OFF_BINARY,	NULL,	".cds", BF_BYCARD,
		0,	"Cds format",
		0,		print_cds,	0 },
#ifdef BIGDEALX
	{ "goedel",		0,	NULL,	".goe",	BF_GOEDEL,
		0,	"Internal goedel number format(development only)",
		init_goedel,	print_goedel,	0 },
	{ "stats",		0,	NULL,	".txt",	BF_BYHAND,
		0,	"Statistics on set",
		init_stat,	compute_stat,	print_stat },
	{ "stdout",		0,	NULL,	0,	BF_BYHAND,
		0,	"Portable Bridge Notation on standard output",
		init_pbn,	print_pbn,	0 },
#endif
	{ 0 }
};

void
output_help() {
	of_p ofp;

	printf("%-8s%8s    Explanation\n\n", "Name", "Suffix");
	/* For all formats: */
	for (ofp=output_formats; ofp->of_name; ofp++) {
		printf("%-8s%8s    %s\n",
			ofp->of_name,
			ofp->of_suffix? ofp->of_suffix : "",
			ofp->of_help);
	}
	printf("\n");
}

#define NTOKENS 10
static char **
tokenize(char *tokenstring, char separator)
{
	static char *tokenvec[NTOKENS+1];
	char *tsp, *sepp;
	int tokencount;

	tsp = tokenstring;
	tokencount = 0;
	do {
		tokenvec[tokencount++] = tsp;
		if ((sepp = strchr(tsp, separator)) != 0) {
			*sepp++ = 0;
			tsp = sepp;
		}
	} while (sepp && tokencount < NTOKENS);
	if (sepp)
		fprintf(stderr, "too many words, \"%s\" ignored\n", sepp);
	tokenvec[tokencount] = 0;
	return tokenvec;
}

static int
suf_in_use(char *name, char *suffix)
{
	of_p ofp;

	/*
	 * Check for potential duplicate suffix use
	 */
	for (ofp=output_formats; ofp->of_name; ofp++) {
		if (!(ofp->of_flags&OFF_USEIT)) {
			/*
			 * Format not in use, no problem
			 */
			continue;
		}
		if (ofp->of_suffix != 0) {
			if (suffix == 0 || strcmp(ofp->of_suffix, suffix) != 0) {
				/*
				 * Not same suffix, no problem
				 */
				 continue;
			}
		} else {
			/*
			 * To check suffix is 0 (stdout)
			 */
			if (suffix != 0) {
				/*
				 * One 0, other not, no problem
				 */
				continue;
			}
		}
		/*
		 * Ok, we have a problem
		 */
		fprintf(stderr, "Cannot use %s, because %s shares suffix %s\n",
			name, ofp->of_name, suffix ? suffix : "NONE");
		return 1;
	}
	return 0;
}

int
output_specify_formats(char *format_string, int for_real)
/*
 * Comma separated list of output formats to use
 *
 * Return value is used to check validity of string
 */
{
	char **ofvector;
	of_p ofp;
	int found;
	int retval;

	retval = 1;	/* While all OK */
	for(ofvector = tokenize(format_string, ','); *ofvector; ofvector++) {
		found = 0;
		for (ofp=output_formats; ofp->of_name; ofp++) {
			if (strcmp(ofp->of_name, *ofvector) == 0) {
				if (suf_in_use(ofp->of_name, ofp->of_suffix)) {
					retval = 0;
				} else {
					ofp->of_flags |= OFF_USEIT;
				}
				found++;
				break;
			}
		}
		if (!found) {
			fprintf(stderr, "Format %s unknown\n", *ofvector);
			retval = 0;
		}
	}

	if (!for_real) {
		/*
		 * This was just a test, clean up
		 */
		for (ofp=output_formats; ofp->of_name; ofp++) {
			ofp->of_flags &= ~OFF_USEIT;
		}
	}

	return retval;
}

/*
 * This next section is to support multiple internal formats,
 * where there is a limited number of possible transformations
 * and we try to minimize the internal formats generated
 * Just generate what we need
 */
#define bit(x)	(1<<(x))
static int formatset;		/* Bitmap of internal formats to support */
static int formatclosure[NBASEFORM] = {
	bit(BF_GOEDEL),
	bit(BF_GOEDEL) | bit(BF_INTERNAL),
	bit(BF_GOEDEL) | bit(BF_INTERNAL) | bit(BF_BYHAND),
	bit(BF_GOEDEL) | bit(BF_INTERNAL) | bit(BF_BYHAND) | bit(BF_BYCARD),
};

void
output_createfiles(char *fileprefix, progparams_p ppp)
/*
 * Create a file for every wanted output format
 * Set the formatset variable
 */
{
	char filename[100];
	of_p ofp;
	FILE *f;

	prparp = ppp;
	/* For all formats: */
	for (ofp=output_formats; ofp->of_name; ofp++) {
		/* If not in use forget it */
		if (!(ofp->of_flags&OFF_USEIT))
			continue;

		if (ofp->of_high_board &&
		    ppp->pp_highboard > ofp->of_high_board) {
			fprintf(stderr, "Format %s supports %d as high board, skipping\n", ofp->of_name, ofp->of_high_board);
			continue;
		}
		/* Make note of internal formats we have to make */
		formatset |= formatclosure[ofp->of_baseform];

		/* If no suffix use Standard Output */
		if (ofp->of_suffix) {
			if (strlen(fileprefix)+strlen(ofp->of_suffix)+1 >
					sizeof(filename)) {
				fprintf(stderr, "File name %s%s too long(cannot happen)\n", fileprefix, ofp->of_suffix);
				exit(-1);
			}
			strcpy(filename, fileprefix);
			strcat(filename, ofp->of_suffix);
			f = fopen(filename, ofp->of_flags&OFF_BINARY ? "wb" : "w");
			if (f == NULL) {
				fprintf(stderr, "Cannot create %s\n", filename);
				exit(-1);
			}
			ofp->of_file = f;
		} else {
			ofp->of_file = stdout;
		}
		/*
		 * If there is an init routine call it now
		 */
		if (ofp->of_init)
			(*ofp->of_init)(ofp->of_file);
	}
}

void
output_closefiles()
/*
 * Close all output files
 */
{
	of_p ofp;

	/* For all formats: */
	for (ofp=output_formats; ofp->of_name; ofp++) {
		/* If not in use forget it */
		if (ofp->of_file != NULL) {
			/*
			 * If there is a finish routine call it first
			 */
			if (ofp->of_finish)
				(*ofp->of_finish)(ofp->of_file);
			if (ofp->of_suffix)	/* So not STDOUT */
				fclose(ofp->of_file);
		}
	}
}

void
output_hand(int boardno, dl_num *dnp)
/*
 * Convert goedel number to various internal forms as necessary
 * Output all desired formats
 */
{
	dl_int	dinternal;
	dl_byh	dbyhand;
	dl_byc	dbycard;
	of_p	ofp;
	hr_t	handrep;

	/*
	 * First create all necessary internal forms
	 * Bits in formatset have been inited in output_createfiles
	 */
	if (formatset&bit(BF_INTERNAL))
		code_to_hand(dnp, &dinternal);
	if (formatset&bit(BF_BYHAND))
		cnv_int_byh(&dinternal, &dbyhand);
	if (formatset&bit(BF_BYCARD))
		cnv_byh_byc(&dbyhand, &dbycard);

	/*
	 * Now call output routines
	 */
	for(ofp = output_formats; ofp->of_name; ofp++) {
		if (ofp->of_file == NULL)
			continue;
		handrep.hr_baseform = ofp->of_baseform;
		switch (ofp->of_baseform) {
		case BF_GOEDEL:
			handrep.hr_value.hv_dnp = dnp;
			break;
		case BF_INTERNAL:
			handrep.hr_value.hv_dip = &dinternal;
			break;
		case BF_BYHAND:
			handrep.hr_value.hv_dbhp = &dbyhand;
			break;
		case BF_BYCARD:
			handrep.hr_value.hv_dbcp = &dbycard;
			break;
		}
		(*ofp->of_printit)(ofp->of_file, boardno, &handrep);
	}
}
