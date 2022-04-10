/*
 * $Header: /home/sater/bridge/bigdeal/RCS/mp.h,v 1.5 2000/02/28 14:00:21 sater Exp $
 */

void mp96_zero(byte *b);
void mp96_one(byte *b);
void mp96_assign(byte *b, byte *b1);

int mp96_add(byte *b,byte *b1,byte *b2);
int mp96_sub(byte *b,byte *b1,byte *b2);
int mp96_cmp(byte *b1, byte *b2);
void mp96_mul(byte *b,byte *b1,byte *b2);
