/*
 * $Header: /home/sater/bridge/bigdeal/RCS/bigdeal.h,v 1.7 2000/08/27 14:13:20 sater Exp $
 */

/*
 * Program wide defines for Big Deal
 */

#define VERSION_MAJOR	1
#define VERSION_MINOR	3
#define VERSION_PAREN	"(beta)"

#define COMPASS_NORTH	0
#define COMPASS_EAST	1
#define COMPASS_SOUTH	2
#define COMPASS_WEST	3
#define NCOMPASS	4

#define SUIT_SPADES	0
#define SUIT_HEARTS	1
#define SUIT_DIAMONDS	2
#define SUIT_CLUBS	3
#define NSUIT		4

#define NCARDSPERHAND	13
#define NCARDSPERDECK	52

#define L	(96/8)		/* Bytes needed for 96 bit arithmetic */

/* Baseforms and typedefs for various internal forms of hand */

#define BF_GOEDEL	0
typedef
struct deal_num {
	byte	dn_num[L];
} dl_num;

#define BF_INTERNAL	1
typedef
struct deal_internal {
	byte	di_hand[NCOMPASS][NCARDSPERHAND];
} dl_int;

#define BF_BYHAND	2
typedef
struct deal_byhand {
	byte	dh_hand[NCOMPASS][NCARDSPERHAND];
} dl_byh;

#define BF_BYCARD	3
typedef
struct deal_bycard {
	byte	dc_card[NCARDSPERDECK];
} dl_byc;

#define NBASEFORM	4

/* End of baseforms and typedefs */

/*
 * Various parameters for the program go in here
 * to be able to be passed to routines more easily
 */
typedef
struct prog_params {
	int	pp_lowboard;
	int	pp_highboard;
	int	pp_nboards;
} progparams_t, *progparams_p;
