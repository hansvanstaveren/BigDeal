# $Header: /home/sater/bridge/bigdeal/RCS/README.txt,v 1.7 2000/07/12 18:43:11 sater Exp sater $

		How to install and run Big Deal version 1.2
		September 8, 2012

Congratulations, you have acquired Big Deal, probably the best software
available for dealing hands for tournaments. This documentation
will help you to get started on using it.

But first, since the sources of the software are distributed
along with the binaries, there is always a chance that you
received Big Deal in a form modified by someone, with either good
or bad intentions. The authors of course cannot vouch for modified
software, so get your software from the Internet at
	www.xs4all.nl/~sater
if you want to be sure of having the original. Furthermore by
getting the software from the Internet you are sure to have the
latest version, so if support for output formats increases, or
bugs are fixed, you are sure to get them.

The software is distributed in a ZIP file containing:
	This file (README.txt)
	The Windows command line executable (bigdeal.exe)
	A directory with the sources
	A directory with all binaries
	A directory with documentation
For the intended use, just dealing hands for tournaments, only
the Windows executable is needed.

QUICK START:
- Copy bigdeal.exe to the directory where you want to do your dealing
- Start a command line window (Start->Programs->Command Prompt)
- Change directory to where you copied bigdeal.exe
- Type 'bigdeal'
The program will now ask you three initial questions. The first
is which output format or formats you prefer. This release
supports ten different formats. The program suggests you take DUP
and PBN formats, but the choice is yours. If you just want DGE
format type 'dge' and ENTER. If you are unsure use PBN, at least
that is a plain-text format.

Now you get the choice of respecifying this every time you run
Big Deal. Almost nobody will want that, since they use the same
format all the time. In that case just type ENTER.

The last question asks you to identify yourself. This
identification will be used to guarantee that nobody can generate
the same sets of hands as you do. Just type anything that
identifies you uniquely, for example
? Joe Blow, from Dealville, IL, installing at 9:39 AM Labour Day 2001

This ends the initial questions, you will not be asked these
again(unless you want to).

The program continues with the first question asked normally, and
that is the number of boards to deal. The maximum is 100. Just
type the number and ENTER.

The next question is the output filename(without suffix). If you
chose DGE format, and you type 'tourn11' here, the hands will be
dealt to file 'tourn11.dge'.
The program will now ask you to type random characters, until
told to stop. Just bang on your keyboard for a while, and within
ten seconds the program will ask you to stop. Stop typing. You
are done, the hands are now dealt.

No further knowledge is needed to deal hands. Read on only for
details, extensions etcetera.

The program is available in two versions, bigdeal and bigdealx.
The former is advised for common use, the latter has more
possibilities. Be warned that more can be less, extra
possibilities can be dangerous.

Both versions have support for command line options:
	-n number-of-hands	If this is specified it will not be asked
	-p file-prefix		If this is specified it will not be asked
	-f format-string	By default dup,pbn. Look in output.c for more.
	-R			Reask initial questions
	-e entropy-string	The string will be used as entropy, 4 bits per
				character will be guessed
	-E entropy-file		The file contents will be used as entropy, 4
				bits per character will be guessed
	-o			Only entropy supplied on command line will
				be used.
	-h hash			The argument must be a 40 character hash string.
				This is used as the final hash for the program.
				Overrides -e and -E, implies -o.

The latter four options are of course extremely dangerous and are only
present in bigdealx.

Bigdealx also generates a file called deallog.txt, containing debugging. This
file is never cleared, only appended to.

Bigdealx also generates a file called dealentr.txt containing the 160 bits
hashes the program starts with. This version checks for potential duplicates,
an occurrence of which would suggest a massive flaw in implementation
or assumptions. The hashes are hex-encoded.

Bigdealx can generate limited statistics as an output format(STATS).
Statistics for one session are meaningless of course.

Please send feedback to:

Hans van Staveren <sater@xs4all.nl>
