#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>

#include "types.h"
#include "rmd160.h"
#include "bigdeal.h"
#include "mp.h"
#include "binomial.h"
#include "output.h"
#include "os.h"
#include "collect.h"

#define MESSLEN		100			/* Length of input buffer(s) */
#define ENTROPY_TO_COLLECT	RMDsize*4/3	/* 33% extra safety/paranoia */

progparams_t parameters;	/* Program parameters go in here */
FILE *flog;			/* Not used in safe version */

static int
readline(FILE *ifile, char *buf, int len)
/*
 * Read line into buf
 * Check for length, discard trailing \n
 */
{
	char *eol;

	if(fgets(buf, len, ifile) == NULL)
		return 0;
	eol = strchr(buf, '\n');
	if (eol)
		*eol = 0;
	return 1;
}

/*
 * Section that handles initialization file
 * Currently in use for hand format(s)
 *
 * File contains keyword=value lines
 * The init_file[] array contains default values, overwritten by file
 */

static char init_header[] =	"[BigDeal]";

char default_formats[MESSLEN] = "dup,pbn";
char default_askformats[MESSLEN] = "no";
char default_owner[MESSLEN] = "Identification of owner or tournament";

#define LONGESTKEYWORD		20	/* Extra bytes to read for keyword and = */
struct ifrecord {
	char *if_keyword;
	char *if_value;
} init_file[] = {
	{ "formats", default_formats },
	{ "askformats", default_askformats },
	{ "owner", default_owner },
	{ 0 }
};

void
write_init_file(char *ifname)
/*
 * Prompt for defaults, and write init_file
 */
{
	FILE *ifile;
	char buf1[MESSLEN], buf2[MESSLEN];
	struct ifrecord *ifrp;

	printf("This program can generate various hand formats, one or more per run:\n\n");
	output_help();
	do {
		printf("Give comma separated list of formats usually desired: [%s] ",
			default_formats);
		readline(stdin, buf1, MESSLEN);
		if (buf1[0] == 0)
			strcpy(buf1, default_formats);
		strcpy(buf2, buf1);
	} while (output_specify_formats(buf2, 0)==0);
	strcpy(default_formats, buf1);

	printf("\nNormally you will always use the format(s) just specified,\n");
	printf("but maybe you would like to change it for some runs.\n");
	printf("Do you want the program to reconfirm the format every run? [%s] ", default_askformats);
	readline(stdin, buf1, MESSLEN);
	if (buf1[0])
		strcpy(default_askformats, buf1[0] == 'y' ? "yes" : "no");

	printf("\nIf you give an identification string the program will ensure\n");
	printf("that nobody with a different identification can generate the\n");
	printf("same sets of deals as you\n");
	printf("identication? [%s]\n? ", default_owner);
	readline(stdin, buf1, MESSLEN);
	if (buf1[0])
		strcpy(default_owner, buf1);

	ifile = fopen(ifname, "w");
	fprintf(ifile, "%s\n", init_header);
	for (ifrp=init_file; ifrp->if_keyword; ifrp++) {
		fprintf(ifile, "%s=%s\n", ifrp->if_keyword, ifrp->if_value);
	}
	fclose(ifile);
}

void
read_init_file(char *ifname, int write_when_absent)
/*
 * Read init file
 */
{
	FILE *ifile;
	char buf[MESSLEN+LONGESTKEYWORD];
	char *eqptr;
	struct ifrecord *ifrp;

	ifile = fopen(ifname, "r");
	if (ifile == NULL) {
		if (write_when_absent)
			write_init_file(ifname);
		return;
	}
	while (readline(ifile, buf, MESSLEN+LONGESTKEYWORD)) {
		if (buf[0] == 0)
			continue;		/* empty line */
		if (strcmp(buf, init_header)==0)
			continue;		/* header for Windows routines */
		if (buf[0] == '[')
			break;			/* end of our stuff */
		eqptr = strchr(buf, '=');
		if (eqptr == 0) {
			fprintf(stderr, "Line '%s' does not contain =\n", buf);
			fprintf(stderr, "Suggest rerun program with -R flag\n");
			continue;
		}
		*eqptr++ = 0;
		for (ifrp=init_file; ifrp->if_keyword; ifrp++) {
			if (strcmp(ifrp->if_keyword, buf)==0) {
				strcpy(ifrp->if_value, eqptr);
				break;
			}
		}
		if (!ifrp->if_keyword) {
			fprintf(stderr, "Keyword %s in init_file unknown\n", buf);
			fprintf(stderr, "Suggest rerun program with -R flag\n");
		}
	}
	fclose(ifile);
}

#ifndef BIGDEALX
/*
 * All parameters for the program when it is running in binary or safe mode
 * In this mode the program should be as idiot proof as possible
 */
#define OPTION_STRING	"f:n:p:R"
#define USAGE_STRING	"[-n number-of-deals] [-p outputfile-prefix] [-f output-format-list] [-R(re-init)]"
#define MAXDEALS	100	/* No more than 100 deals in standard prog */
#define VERSION_COMMENT	""

#else /* BIGDEALX */
/*
 * Parameters for the other mode. This is the hacker mode where the user
 * can tinkle with entropy and other operations that increase the likelyhood
 * of the program generating something else than a random, never occurred
 * before set of deals.
 */
#define OPTION_STRING	"e:E:f:h:n:op:RW:"
#define USAGE_STRING	"[-n nr-of-deals] [-p ofile-prefx] [-f o-format-list] [-e entropy-str] [-E entropy-file] [-o(only entropy from command line)] [-W string] [-h hash] [-R(re-init)]"
#define MAXDEALS	1000000000
#define VERSION_COMMENT "(Extended version, not recommended for tournament use)"

#define HISTNAME "dealentr.txt"
#define LOGNAME "deallog.txt"

/*
 ****************************************************************************
 * Begin section of code for other mode only
 ****************************************************************************
 */

static void
checkduphash(char *hash)
/*
 * Paranoia function: if in test we ever run into the same 160 bit number again
 * it is time to reevaluate our assumptions
 */
{
	FILE *fhist;
	char oldhash[MESSLEN];
	int hashlen;
	int counter, badentry;

	hashlen = strlen(hash);
	fhist = fopen(HISTNAME, "a+");
	if (fhist == NULL) {
		fprintf(stderr, "Couldn't open %s\n", HISTNAME);
		return;
	}
	counter = 0;
	badentry = 0;
	fseek(fhist, 0L, 0);
	while (readline(fhist, oldhash, MESSLEN)) {
		if (strlen(oldhash) != hashlen) {
			badentry++;
			continue;
		}
		if (strcmp(oldhash, hash) == 0) {
			fprintf(flog, "Panic: same hash, index %d\n", counter);
			fprintf(stderr, "Panic: same hash, index %d\n", counter);
			exit(-1);
		}
		counter++;
	}
	fprintf(fhist, "%s\n", hash);
	fclose(fhist);
	fprintf(flog, "Checked hash against %d previous hashes\n", counter);
	if (badentry) {
		fprintf(flog, "The file %s contained %d bad entries\n",
			HISTNAME, badentry);
	}
}

static void
read_entropy_from_file(char *fname)
/*
 * A frontend has generated entropy for us.
 * Let us hope it did the right thing.
 * We give it credit for 4 bits entropy per byte.
 */
{
	FILE *fentr;
	int c;

	if (fname == 0) {
		fprintf(stderr, "No entropy file supplied\n");
		return;
	}
	fentr = fopen(fname, "r");
	if (fentr == NULL) {
		fprintf(stderr, "Cannot open %s\n", fname);
		return;
	}
	while ((c = getc(fentr)) >= 0) {
		collect_more((byte *) &c, sizeof(c), 4);
	}
	fclose(fentr);
}

static int
hexval(char c)
/*
 * Convert characters '0'..'9', 'A'..'F' and 'a'..'f' to 0..15
 */
{

	if (c >= '0' && c <= '9')
		return c - '0';
	if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	fprintf(stderr, "Character %c is not a hexchar\n", c);
	exit(-1);
}

static void
random_set(char *hashstr, byte *sr)
/*
 * hashstr is a 40 byte string of hex characters
 * we convert it into a 20 byte(160 bit) binary value
 */
{
	int i;

	if (strlen(hashstr) != 2*RMDbytes) {
		fprintf(stderr, "Argument %s should be %d characters long\n",
			hashstr, 2*RMDbytes);
		exit(-1);
	}
	for (i=0; i<RMDbytes; i++)
		sr[i] = hexval(hashstr[2*i+1]) | (hexval(hashstr[2*i])<<4);
}

/*
 ****************************************************************************
 * End section of code for other mode only
 ****************************************************************************
 */

#endif /* BIGDEALX */

static byte *
RMDhash(byte *value, int length)
/*
 * Hashes value of length bytes using RIPEMD160
 *
 * Returns pointer to 20 bytes hashcode
 */
{
	dword         MDbuf[RMDdwords];		/* contains (A, B, C, D(, E)) */
	dword	      X[16];			/* current 16 word chunk      */
	static byte   hashcode[RMDbytes];	/* for final hash-value       */
	unsigned int  i;			/* counter                    */
	int	      nbytes;			/* bytes not yet processed    */

	/* initialize */
	MDinit(MDbuf);

	/* Process value in 16-word chunks */
	for (nbytes=length; nbytes>=64; nbytes-=64) {
		for (i=0; i<16; i++) {
			X[i] = BYTES_TO_DWORD(value);
			value += 4;
		}
		compress(MDbuf, X);
	}
		
	/* finish: */
	MDfinish(MDbuf, value, length, 0);

	for (i=0; i<RMDbytes; i+=4) {
		hashcode[i]   =  MDbuf[i>>2];        /* implicit cast to byte */
		hashcode[i+1] = (MDbuf[i>>2] >>  8); /*  extracts the 8 least */
		hashcode[i+2] = (MDbuf[i>>2] >> 16); /*  significant bits.    */
		hashcode[i+3] = (MDbuf[i>>2] >> 24);
	}

	return (byte *)hashcode;
}

static int
goedel(dl_num *dnp)
/*
 * Checks whether the contents of dnp is a number less than the number
 * of bridge deals.
 */
{
	/*
	 * This number is precomputed
	 */
	static byte nr_bridge_deals[L] =
		{ 173,85,227,21,99,77,218,101,139,244,146,0};

#ifdef BIGDEALX
	byte a[L], b[L];

	n_over_k(52,13,a);
	n_over_k(39,13,b);
	mp96_mul(a,a,b);
	n_over_k(26,13,b);
	mp96_mul(a,a,b);

	/*
	 * This gives a the value of the number of bridge deals
	 * =( (52 over 13) times (39 over 13) times (26 over 13) )
	 * Now let us check our internal calculations
	 *
	 * If it is wrong we miscalculated somewhere
	 */

	if (mp96_cmp(a, nr_bridge_deals) != 0) {
		fprintf(stderr, "Miscalculation\n");
		/*
		 * print_goedel(stderr, (dl_num*) a);
		 * print_goedel(stderr, (dl_num*) nr_bridge_deals);
		 */
		exit(-1);
	}
#endif

	if (mp96_cmp(dnp->dn_num, nr_bridge_deals) >= 0)
		return 0; /* too big, not a hand number */
	return 1;
}

extern int nrandombits;

static void
get_entropy_from_keyboard() {
	int c, oldc;
	int nbits;

	cbreak();
	printf("Type random characters until you are told to stop ");
	oldc = 0;
	do {
		c = getchtm(&nbits);
		if (c != oldc) {
			/*
			 * Collect the character, assume 2 bits entropy
			 * plus what the timing supplied.
			 */
			collect_more( (byte*)&c, sizeof(c), 2+nbits);
			oldc = c;
		}
	} while (nrandombits < ENTROPY_TO_COLLECT);
	printf("\nThat is enough\007\n");
	cooked();
}

void
setboards(char *a) {
	char *chptr;

	chptr =strchr(a,'-');
	if (chptr) {
		*chptr++ = 0;
		parameters.pp_lowboard = atoi(a);
		parameters.pp_highboard = atoi(chptr);
	} else {
		parameters.pp_lowboard = 1;
		parameters.pp_highboard = atoi(a);
	}
	parameters.pp_nboards =
	    parameters.pp_highboard - parameters.pp_lowboard + 1;
}

/*
 * Structure with all values that get hashed for random generation
 * This includes hash of owner identication making it impossible for
 * another owner to generate the same series of deals
 * Reduces 2**-160 chance to zero
 */
static struct {
	byte	seed_sequence[4];	/* sequence number in PRNG sequence */
	byte	seed_random[RMDbytes];	/* 160 bits collected at start */
	byte	seed_owner[RMDbytes];	/* 160 bit hash of owner ident */
} seed;

int
main (int argc, char *argv[])
{
	int i;
	char message[MESSLEN];
	byte *hashcode;
	unsigned long seqno;
	dl_num dnumber;
	char filename[MESSLEN] = "";
	int c;
	char *formats = 0;
	char *ownerp;
#ifdef BIGDEALX
	int only_arg_entropy = 0;
	char *hashstr = 0;
	char *wizard = 0;
	int dangerous_code_used = 0;
#else
#define only_arg_entropy 0
#define wizard 0
#endif

	/*
	 * Some systems (looking at you MinGW) suck at unbuffering stdout
	 */

	setbuf(stdout, NULL);

	/*
	 * Say hi to operator
	 */
	printf("Big Deal version %d.%d%s%s\n\n",
		VERSION_MAJOR, VERSION_MINOR, VERSION_PAREN, VERSION_COMMENT);

#ifdef BIGDEALX
	flog = fopen(LOGNAME, "a");
#endif
	os_start();
	collect_start();

	while ((c = getopt(argc, argv, OPTION_STRING)) != -1) {
		switch(c) {
#ifdef BIGDEALX
		case 'E':
			read_entropy_from_file(optarg);
			dangerous_code_used = 1;
			break;
		case 'e':
			collect_more((byte *) optarg, strlen(optarg), 4*strlen(optarg));
			dangerous_code_used = 1;
			break;
		case 'h':
			hashstr = optarg;
			/* fall through */
		case 'o':
			only_arg_entropy = 1;
			dangerous_code_used = 1;
			break;
		case 'W': /* Wizard mode */
			only_arg_entropy = 1;
			wizard = optarg;
			break;
#endif
		case 'p':
			strncpy(filename, optarg, MESSLEN-1);
			break;
		case 'f':
			formats = optarg;
			break;
		case 'n':
			setboards(optarg);
			break;
		case 'R':
			read_init_file(os_init_file_name(), 0);
			write_init_file(os_init_file_name());
			exit(0);
		case '?':
			fprintf(stderr, "Usage: %s %s\n", argv[0], USAGE_STRING);
			exit(-1);
		}
	}

	if (!only_arg_entropy)
		os_collect();

	read_init_file(os_init_file_name(), 1);
	binomial_start();
	/*
	 * Read number of boards to generate
	 */
	while(parameters.pp_nboards <= 0 || parameters.pp_nboards > MAXDEALS) {
		/*
		 * If we are asked to generate more than 100 boards refuse
		 * We only have 160 bits entropy, and no one plays sessions
		 * of more than 100 boards anyhow
		 */
		if (parameters.pp_nboards > MAXDEALS) {
			parameters.pp_nboards = 0;
			printf("The maximum is %d, run program again for more\n",
				MAXDEALS);
		}
		printf("Number of boards to deal(1-%d): ", MAXDEALS);
		(void) readline(stdin, message, MESSLEN);
		setboards(message);
		/*
		 * Collect the string, no entropy assumed
		 */
		if (!only_arg_entropy)
			collect_more( (byte*)message, strlen(message), 0);
	}

	/*
	 * Read part of filename before the .
	 */
	while(!legal_filename_prefix(filename)) { 
		printf("Output filename(without suffix): ");
		(void) readline(stdin, message, MESSLEN);
		/*
		 * Collect the string, 5 bits entropy assumed
		 */
		if (!only_arg_entropy)
			collect_more( (byte*)message, strlen(message), 5);
		strcpy(filename,message);
	}

	/*
	 * Get output formats
	 */
	if (formats == 0) {
		/*
		 * Not specified on command line
		 */
		if (!wizard && strcmp(default_askformats, "yes")==0) {
			printf("Hand format(s) to generate: [%s] ",
				default_formats);
			(void) readline(stdin, message, MESSLEN);
			if (message[0]) {
				strcpy(default_formats, message);
			}
		}
		formats = default_formats;
	}

	/*
	 * If we do not have enough entropy collected (very likely)
	 * let the user supply it by rattling his keyboard
	 */
	if (!only_arg_entropy && nrandombits < ENTROPY_TO_COLLECT) {
		get_entropy_from_keyboard();
	}


	/*
	 * Extract the entropy into the random part of the seed
	 */
	collect_finish(seed.seed_random);
#ifdef BIGDEALX
	if (!wizard && nrandombits < ENTROPY_TO_COLLECT) {
		/*
		 * Can only happen when only_arg_entropy is set
		 */
		printf("WARNING: entropy supplied is dangerously low!!!\n");
	}
	if (!wizard && dangerous_code_used) {
		printf("You used features in this extended version of Big Deal\n");
		printf("that might defeat the purpose(generating unique sequences).\n");
		printf("Use hands for actual play only with permission from your national authority.\n\n");
	}

	/*
	 * Did someone use the -h flag ?
	 */
	if (hashstr)
		random_set(hashstr, seed.seed_random);

	/*
	 * Start checking for duplicate hashes, and log current hash
	 */
	for (i=0; i<RMDbytes; i++) {
		message[2*i  ] = "0123456789ABCDEF"[seed.seed_random[i]/16];
		message[2*i+1] = "0123456789ABCDEF"[seed.seed_random[i]%16];
	}
	message[2*RMDbytes] = 0;
	if (!hashstr && !wizard)
		checkduphash(message);		/* If this fails .... */

	fprintf(flog, "Deal %d boards to file %s, hash = %s\n",
		parameters.pp_nboards, filename, message);
#endif
	(void) output_specify_formats(formats, 1);
	output_createfiles(filename, &parameters);

	/*
	 * Generate a sequence of 160 bit pseudo random numbers
	 * by running the random bits with an increasing
	 * counter through the cryptographical hash.
	 * This according to Carl Ellison's recommendation for P1363
	 *
	 * But first put hash of owner ident into seed
	 *
	 * In Wizard mode use wizard string iso owner
	 */
	ownerp = wizard ? wizard : default_owner;
	hashcode = RMDhash((byte *) ownerp, strlen(ownerp));
	memcpy(seed.seed_owner, hashcode, RMDbytes);

	seqno = 0;
	for(i = parameters.pp_lowboard; i <= parameters.pp_highboard; i++) { 
		/*
		 * Next do loop executed as long as we have the misfortune
		 * to make 96 bit numbers above the number of hands
		 */
		do {
			seqno++;
			/*
			 * The next code guarantees the same sequence on
			 * litle endian and big endian machines, which
			 * makes it possible to reproduce sequences on each
			 */
			seed.seed_sequence[0] = seqno & 0xFF;
			seed.seed_sequence[1] = (seqno>>8) & 0xFF;
			seed.seed_sequence[2] = (seqno>>16) & 0xFF;
			seed.seed_sequence[3] = (seqno>>24) & 0xFF;
			/*
			 * Run all the bits through the hash
			 */
			hashcode = RMDhash((byte *) &seed, sizeof(seed));
			/*
			 * Take the first L bytes(96 bits) as a candidate
			 * hand number
			 */
			memcpy(dnumber.dn_num, hashcode, L);
		} while(!goedel(&dnumber));
		/*
		 * Ok, got one
		 * Print it in all desired formats
		 */
		output_hand(i, &dnumber);
	}

	/*
	 * Finished, close output files
	 */
	output_closefiles();
#ifdef BIGDEALX
	fclose(flog);
#endif

	/*
	 * Do whatever our OS wants us to do at the end, and then exit
	 */
	os_finish();
	return 0;
}
