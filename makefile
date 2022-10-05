#
# Makefile for the shuffle program Big Deal
#
# $Header: /home/sater/bridge/bigdeal/RCS/Makefile,v 1.4 2000/08/16 15:18:56 sater Exp $
#
# Change OS to either unix or dos or mingw
OS=mingw

CC=gcc
PFLAGS=
CFLAGS=-O $(PFLAGS) -Wall -pedantic -I/mingw/include
LDFLAGS=$(PFLAGS)

COMMONOBJS=rmd160.o mp.o binomial.o
SAFEOBJS=main.o collect.o output.o
EXTNOBJS=mainx.o collectx.o outputx.o


all:	bigdeal bigdealx

bigdeal:	$(COMMONOBJS) $(SAFEOBJS) $(OS).o
	$(CC) $(LDFLAGS) -o bigdeal $(COMMONOBJS) $(SAFEOBJS) $(OS).o

bigdealx:	$(COMMONOBJS) $(EXTNOBJS) $(OS).o
	$(CC) $(LDFLAGS) -o bigdealx $(COMMONOBJS) $(EXTNOBJS) $(OS).o

clean:
	-rm $(COMMONOBJS) $(SAFEOBJS) $(EXTNOBJS) $(OS).o

mainx.o:	main.c
	$(CC) $(CFLAGS) -c -DBIGDEALX main.c -o mainx.o 

collectx.o:	collect.c
	$(CC) $(CFLAGS) -c -DBIGDEALX  collect.c -o collectx.o 

outputx.o:	output.c mp.h
	$(CC) $(CFLAGS) -c -DBIGDEALX output.c -o outputx.o 

main.o: main.c types.h rmd160.h bigdeal.h mp.h binomial.h output.h os.h collect.h
output.o: output.c types.h bigdeal.h binomial.h
binomial.o: binomial.c types.h bigdeal.h mp.h
collect.o: collect.c types.h rmd160.h bigdeal.h
dos.o: dos.c types.h bigdeal.h
mp.o: mp.c types.h bigdeal.h
rmd160.o: rmd160.c types.h rmd160.h
unix.o: unix.c types.h bigdeal.h
