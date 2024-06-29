#!/usr/bin/perl -w
use Digest::SHA::PurePerl qw(sha256_hex );
use Bytes::Random::Secure qw( random_string_from );
use File::Copy qw( copy );
use Convert::Base64 qw( encode_base64 );;

$version = "2.2";

$suf = "sqd";
$sufkey = "sqk";
$bigdeal = "bigdealx";

$pat_end = qw/^[0.]$/;

$undef_info = "Tbd";
$TrnNPhases = 0;

$PrePublishMenu =<<'MENU';
set tournament name
%
Setting name of tournament.
Just for identification purposes, it has no effect on crypto
%
$TrnName = promptfor("Name");
$Modified = 1;
%%
set delayed information description
%
This describes which delayed information will be used after publishing and before dealing
For example: Dow Jones Industrial Average on Friday April 13
%
$TrnDelayedInfo = promptfor("Delayed info description");
$Modified = 1;
%%
add phase of tournament
%
Will add phase, consisting of one or more sessions
includes names of files and description of sessions
%
addphase();
$Modified = 1;
%%
publish
%
Marks end of preparation, tournament data can be published now
%
publish();
$Modified = 1;
MENU

$PostPublishMenu =<<'MENU';
set delayed information value
%
This enters the actual delayed information, as described at publication time
%
$TrnDelayedValue = promptfor("Delayed info value");
$Modified = 1;
%%
make session(s)
%
Actually makes the hands of the specified sessions
Session numbers can be a single number, a range as in 3-7, or * for all
%
makesession(0);
%%
make reserve session(s)
%
Actually makes the hands of the reserve sets of the specified sessions
%
makesession(1);
MENU

$Modified = 0;

sub isnumber {
    my ($arg) = @_;

    if ($arg =~ /^\d+$/) {
	return 1;
    }
    return 0;
}

sub is_board_range_list {
    my ($arg) = @_;

    #
    # Board range can be a number or a range so '16' or 15-21'
    # A comma separated list of the latter is also OK
    #
    if ($arg =~ /^$/) {
	return 0;
    }
    if (isnumber($arg)) {
	return $arg > 0;
    }
    my @len_ar = split /,/, $arg;
    my $seslen = 0;
    for my $len (@len_ar) {
	if ($len !~ /^([0-9]+)-([0-9]+)$/) {
	    return 0;
	}
	my $sublen = $2-$1+1;
	if ($seslen && $seslen != $sublen) {
	    print "\n\nnot all ranges same size ($len), probably mistake\n\n\n";
	}
	$seslen = $sublen;
    }
    return 1;
}

sub promptfor {
    my ($prompt) = @_;
    
    print "$prompt> ";
    $_ = <>;
    chomp;
    return $_;
}

sub publish {

    #
    # Tournament Name must be set
    #
    if ($TrnName eq $undef_info) {
	print "Tournament Name has not been set, publishing not allowed\n";
	return;
    }
    #
    # Delayed information description must be set
    #
    if ($TrnDelayedInfo eq $undef_info) {
	print "Tournament Delayed Information has not been set, publishing not allowed\n";
	return;
    }
    #
    # Should have at least one phase
    #
    if ($TrnNPhases <= 0) {
	print "No phases have been defined, publishing not allowed\n";
	return;
    }
    #
    # Generate keys for all sessions
    #
    for my $ph (1..$TrnNPhases) {
	my ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$ph];
	for my $s (1..$nses) {
	    $skey{"$ph,$s"} = make_secret();
	}
    }
    $TrnPublished = 1;
    #
    # Write keys and compute hash
    #
    $TrnKeyHash = writekeys("$TFile.$sufkey");
    $Runon = 0;
    print "The tournament can now no longer be changed\n";
    print "You should publish the file $TFile.$suf\n";
    print "Keep the file $TFile.$sufkey very, very secret!!\n";
}

sub do_menu {
    my ($menu) = @_;
    my (@descr_ar, @explanation_ar, @command_ar);

    #
    # Read menu, separation %% lines
    #
    my @items = split /^%%$/m, $menu;
    chomp @items;
    for my $i (0..$#items) {
	my ($descr, $explanation, $command) = split /^%$/m, $items[$i];
	chomp $descr;
	$descr =~ s/^\s*//;
	push @descr_ar, $descr;
	push @explanation_ar, $explanation;
	push @command_ar, $command;
    }
    #
    # Set Runon to 1, will stay there until end is signalled
    #
    $Runon = 1;
    #
    # Loop: print possibilities, handle ? and call commands
    #
    my $initspace = " " x 7;
    do {
	print "For help on menu choice 2 type ?2, etc\n";
	print "$initspace 0)\texit program\n";
	for my $i (0..$#descr_ar) {
	    print "$initspace ", $i+1, ")\t$descr_ar[$i]\n";
	}
	$ans = promptfor("Choice");
	if ($ans =~ /^\?([0-9]*)$/) {
	    print $explanation_ar[$1-1], "\n";
	} elsif ($ans =~ /^[0-9]+$/) {
	    my $ino = $ans -1;
	    if ($ino >= 0) {
		if (!defined($command_ar[$ino])) {
		    print "Command unknown\n";
		} else {
		    eval $command_ar[$ino];
		}
	    } else {
		#
		# Exit was chosen
		#
		$Runon = 0;
	    }
	}
	if ($Modified) {
	    # keep .sqd file up to date after each mod.
	    # This will survive crashes, interrupts, etc...
	    writetourn("$TFile.$suf");
	    $Modified = 0;
	}
    } while ($Runon);
}

#
# Take format with some ## and replace ### with value of n
# 
# Generalized to also take range, like 4-6 and replace each sharps with two numbers with dash in between
#
sub sharpfill {
    my ($str, $n) = @_;
    my ($prf, $len, $suf, $fmt, $repl);

    $str =~ /([^#]*)(#+)(.*)/ || return $str;
    # Hashes to replace, prf###suf
    $prf = $1;
    $len = length $2;
    $suf = $3;
    $fmt = "%0${len}d";

    if ($n =~ /^([0-9]+)-([0-9]+)$/) {
	my $low = $1;
	my $high = $2;
	my $rlow = sprintf($fmt, $low);
	my $rhigh = sprintf($fmt, $high);
	return "$prf$rlow-$rhigh$suf";
    }

    $repl = sprintf($fmt, $n);
    return $prf.$repl.$suf;
}

sub make_secret {

    #
    # Secrets are made as strings containing letters and digits (62 possible characters)
    # String length = 60
    # This gives 3.495436e+107 possibilities
    #
    my $x = join('', ('a' .. 'z'), ('A'..'Z'), ('0'..'9'));
    my $bytes = random_string_from( $x, 60 );
    return $bytes;
}

sub readkeys {
    my ($fname) = @_;
    my ($hashval, $key);

    open(KEYFILE, "<:crlf", $fname) || return 0;
    my $wholefile = "";
    #
    # Read all lines of keys and populate skey{}
    # Variable $wholefile will contain complete contents, for hashing
    #
    while (<KEYFILE>) {
	chomp;
	$wholefile .= "$_\r\n";
	($hashval, $key) = split /:/;
	$skey{$hashval} = $key;
    }
    #
    # Make hash and check
    #
    my $result = sha256_hex($wholefile);
    if ($result ne $TrnKeyHash) {
	print "Found wrong keyhash\n";
	print "Hash in description: $TrnKeyHash\n";
	print "length ", length($TrnKeyHash), "\n";
	print "Hashed key values  : $result\n";
	print "length ", length($result), "\n";
	die;
    }
    #
    # Check if we have keys for all sessions of all phases
    #
    for my $ph (1..$TrnNPhases) {
	my ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$ph];
	for my $s (1..$nses) {
	    $hashval = "$ph,$s";
	    if (!defined($skey{$hashval})) {
		print "No key found for session $hashval\nFatal error, stop using these files !!!\n";
		die;
	    }
	}
    }
    return 1;
}

sub readtourn {
    my($fname, $shouldnotexist) = @_;

    if (!open(TRNFILE, "<", $fname)) {
	print "Cannot open $fname\n" unless ($shouldnotexist);;
    	return 0;
    }
    while(<TRNFILE>) {
	# remove end of line crud
	chomp;
	s/\r$//;
	# ignore comment
	next if /^#/;

	if(s/^TN *//) {
	    $TrnName = $_;
	}
	if(s/^KH *//) {
	    $TrnKeyHash = $_;
	    $TrnPublished = 1;
	}
	if(s/^DI *//) {
	    $TrnDelayedInfo = $_;
	}
	if(s/^DV *//) {
	    $TrnDelayedValue = $_;
	}
	if(s/^SN *//) {
	    my ($nsessions, $sesboards, $sesfname, $sesdescr) = split(/:/);
	    $TrnPhaseName[++$TrnNPhases] = "$nsessions:$sesboards:$sesfname:$sesdescr";
	    $usedfname{$sesfname} = $TrnNPhases;
	}
    }
    return 1;
}

sub writetourn {
    my ($fname) = @_;

    copy $fname, "$fname.bak";
    open(TRNFILE, ">", $fname ) || die;
    print TRNFILE "# Description file of tournament for program squaredeal $version\n#\n";
    print TRNFILE "TN $TrnName\n";
    print TRNFILE "DI $TrnDelayedInfo\n";
    print TRNFILE "DV $TrnDelayedValue\n" if (defined($TrnDelayedValue));
    print TRNFILE "# Description of phases of tournament\n";
    print TRNFILE "# Per phase a line with SN nessions:nboards:filename:description\n";
    for my $s (1..$TrnNPhases) {
	print TRNFILE "SN $TrnPhaseName[$s]\n";
    }
    if ($TrnPublished) {
	print TRNFILE "KH $TrnKeyHash\n";
    } else {
	print TRNFILE "#\n# Until published this file may be edited if so wished\n";
    }
    close(TRNFILE);
}

sub writekeys {
    my ($fname) = @_;

    #
    # Line termination here is CR LF
    # It matters because of checksum, cannot leave it to OS
    #
    my $keys = "";
    for my $sf (1..$TrnNPhases) {
	($nses, $notused_seslen, $notused_sesfname, $notused_sesdescr) = split /:/, $TrnPhaseName[$sf];
	for my $s (1..$nses) {
	    $keys .= "$sf,$s:" . $skey{"$sf,$s"} . "\r\n";
	}
    }

    #
    # Write RAW to prevent line termination change
    #
    open (KEYFILE, ">:raw", $fname ) || die;
    print KEYFILE $keys;
    close(KEYFILE);

    my $result = sha256_hex($keys);
    return $result;
}

sub selecttourn {
    my (@x, $trnlist);

    @x = <*.$suf>;
    $trnlist="";
    for (@x) {
	s/\.$suf//;
	$trnlist .= " $_";
    }

    print "Current tournaments:$trnlist\n";

    $TFile = promptfor("Which tournament? + for new");
    if ($TFile eq "+") {
	$TFile = promptfor("Filename of tournament(keep under 10 chars, no spaces or other weird characters)");
	if (readtourn("$TFile.$suf", 1)) {
	    die "Tournament already exists";
	}
	$TrnName = $undef_info;
	$TrnDelayedInfo = $undef_info;
	$Modified = 1;
    } else {
	print "Will use tournament $TFile\n";
	readtourn("$TFile.$suf", 0) || die;
	if ($TrnPublished) {
	    if(!readkeys("$TFile.$sufkey")) {
	       print "No keyfile found, serious problem!\n";
	    }
	}
    }
}

sub testbigdeal {
    my $fname;

    #
    # create one pbn file to test bigdeal
    #
    print "Will run $bigdeal once to make sure it is installed and works\n\n";
    do {
	my $x = join('', ('a' .. 'z'), ('0'..'9'));
	my $bytes = random_string_from( $x, 6 );
	$fname = "sqd$bytes";
    } while (-e "$fname.pbn");

    my $command = join(' ', $bigdeal, "-p", $fname, "-n", "1", "-f", "pbn");
    system($command);
    -s "$fname.pbn" || die "$bigdeal failed";
    unlink "$fname.pbn";
    print "OK, it works\n\n";
}

sub comb_pbn {

    #
    # Combine PBN files
    # Make new header, and remove headers of subfiles
    # Make new Generator tag
    #
    my $outputfile = shift;
    open COMBFILE, '>', $outputfile;
    print COMBFILE "% PBN 2.1\n";
    print COMBFILE "% EXPORT\n";
    print COMBFILE "%\n";
    print COMBFILE "[Generator \"SquareDeal version $version, combining @_\"]\n";
    foreach my $infile (@_) {
	# print "read PBN file $infile\n";
	open INFILE, '<', $infile || die;
	while( my $line = <INFILE>)  {
	    next if $line =~ /^%/;
	    next if $line =~ /\[Generator/;
	    print COMBFILE $line;
	}
	close INFILE;
    }
    close COMBFILE;
}

sub comb_bin {

    #
    # Combine binary files unlike DUP
    # Just concatenate the binary files
    # Code strangish, copied from Internet source. Seems to work.
    #
    # DUP files are too wierd, refuse to handle them
    #
    my $outputfile = shift;
    open COMBFILE, '>', $outputfile;
    binmode COMBFILE;
    foreach my $infile (@_) {
	open INFILE, '<', $infile || die;
	binmode INFILE;
	my $cont = '';
	while (1) {
	    my $success = read INFILE, $cont, 100, length($cont);
	    die $! if not defined $success;
	    last if not $success;
	}
	close INFILE;
	print COMBFILE $cont;
    }
    close COMBFILE;
}

#
# Supported formats for combining
# Adding a format should only take the relevant subroutine, as above, and entry in the
# following structures
#
@formats = ( "pbn", "bri", "dge", "ber" );
$comb_routine{"pbn"} = \&comb_pbn;
$comb_routine{"bri"} = \&comb_bin;
$comb_routine{"dge"} = \&comb_bin;
$comb_routine{"ber"} = \&comb_bin;

$join_board_high = 0;
$join_number = 0;
$join_begin = 1;
@join_fname_ar = ();

sub join_files {
    my ($sesfname) = @_;

    # print "join_files where join_number = $join_number\n";
    if ($join_number > 1) {
	foreach my $format (@formats) {
	    my @comb_names;

	    # print "Combine type $format\n";
	    $join_end = $join_begin + $join_number - 1;

	    #
	    # Make name for file into which to combine
	    #
	    $dstfname = sharpfill($sesfname, "$join_begin-$join_end");

	    my @files = ();
	    for my $fno (0..$join_number -1) {
		$files[$fno] = $join_fname_ar[$fno].".$format";
	    }
	    if (-r $files[0]) {
		#print "About to combine @files to $dstfname.$format\n";
		$comb_routine{$format}->("$dstfname.$format", @files);
	    }
	}
    } else {
	$join_end = $join_begin;
    }
    $join_board_high = 0;
    @join_fname_ar = ();
    $join_begin = $join_end + 1;
    $join_number = 0;
    # print "At end of join_files, begin=$join_begin and end=$join_end\n";
}

sub makesessionfromphase {
    my ($sf, $reserve, $all) = @_;
    my ($ses, $lowses, $highses);

    ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$sf];
    #
    # Found phase and information, now which session
    # something like 3-6 allowed
    # * means all sessions
    #
    if ($all) {
	$ses = "*";
    } else {
        $ses = promptfor("Session(s), * for all");
    }
    if ($ses =~ /^([0-9]+)-([0-9]+)$/) {
	$lowses = $1;
	$highses = $2;
    } elsif ($ses =~ /^\*$/) {
    	$lowses = 1;
	$highses = $nses;
    } else {
	$lowses = $highses = $ses;
    }
    die if ($lowses < 1 || $lowses > $highses || $highses > $nses);
    #
    # Start actually making
    #
    # if session length is something like 1-16,17-32 split it
    #
    @len_ar = split /,/, $seslen;
    #
    # New combining logic
    #
    for $ses ($lowses..$highses) {
	# len_index is index into array of lenghths
	$len_index = ($ses-1) % ($#len_ar+1);
	# real_seslen is length of this session
	$real_seslen = $len_ar[$len_index];
	$real_seslen = "1-$real_seslen" if $real_seslen =~ /^[0-9]+$/;
	($ses_low_brd, $ses_high_brd) = split('-', $real_seslen);
	# print "seslen $seslen len_index $len_index rseslen $real_seslen, low $ses_low_brd, high $ses_high_brd\n";

	$sesfnamereal = sharpfill($sesfname, $ses);
	# print "sesfname=$sesfname, sesfnamereal=$sesfnamereal\n";
	$sesfnamereal .= "reserve" if ($reserve);

	$sesdescrreal = sharpfill($sesdescr, $ses);

	if ($ses_low_brd != $join_board_high+1) {
	    join_files($sesfname);
	    # print "Exited join_files\n";
	}
	# Potential continuation to join later
	$join_board_high = $ses_high_brd;
	$join_number++;
	push(@join_fname_ar, $sesfnamereal);
	# print "Now high board = $join_board_high, number=$join_number, fnames: @join_fname_ar\n";

	#
	# get session key, and split into left half and right half to put into bigdealx
	#
	$seskey = $skey{"$sf,$ses"};
	$skl = int ((length $seskey)/2);
	$seskeyleft = substr $seskey, 0, $skl;
	$seskeyright = substr $seskey, $skl;
	# print "sk=$seskey\nl=$seskeyleft, r=$seskeyright\n";

	#
	# delayed value is base64 encoded in case it contains weird characters
	#
	$DVencoding = encode_base64($TrnDelayedValue);
	# print "TDV=$TrnDelayedValue, DVE=$DVencoding\n";

	# print "About to make file $sesfnamereal, session $sesdescrreal\n";
	$command = join(' ', $bigdeal,
	    "-W", $seskeyleft,
	    "-e", $seskeyright,
	    "-e", $DVencoding,
	    "-e", $reserve == 0 ? "original" : "reserve",
	    "-p", $sesfnamereal,
	    "-n", $real_seslen
		    );
	# print "command : $command\n";
	#
	# Run bigdeal command and check if nothing weird comes out
	# This check might be made more serious
	#
	$output = `$command`;
	$nlines = ( $output =~ tr/\n// );
	if ($nlines != 2) {
	    print "An error might have occurred: output of Bigdeal:\n$output";
	}
    }
    join_files($sesfname);
}

sub makesession {
    my ($reserve) = @_;

    #
    # Making sessions only possible after setting Delayed Information Value
    #
    unless (defined($TrnDelayedValue)) {
	print "Delayed value not set, do that first\n";
	return;
    }

    showphases();
    #
    # * means all sessions from all phases
    #
    my $sf = promptfor("Session phase, * for all");
    if ($sf =~ /^\*$/) {
	# do all
	
	for my $ph (1..$TrnNPhases) {
	    makesessionfromphase($ph, $reserve, 1);
	}
	return;
    }
    if ( !isnumber($sf) || $sf <= 0 || $sf > $TrnNPhases) {
	print "$sf not a valid phase number\n";
	return;
    }

    makesessionfromphase($sf, $reserve, 0);
}

#
# accept stuff like 1-16(1-16,17-32) meaning 1-16 and then repeatedly 1-16 and 17-32 until all sessions accounted for
#
sub complex_ses_pat {
    my ($nsessions, $pat) = @_;

    unless ($pat =~ /([0-9,\-]*)\(([0-9,\-]*)\)/) {
	return "BAD";
    }

    my @first = split(',', $1);
    my @second = split(',', $2);

    my @all = @first;
    while ($#all+1 < $nsessions) {
	push (@all, @second);
    }

    my @answer = @all[0..$nsessions-1];

    return join(',', @answer);
}

sub addphase {
    my ($nsessions, $sesdigits, $sesfname, $seslen, $phaseno);

    showphases();

    $phaseno = $TrnNPhases+1;
    print "About to add phase number $phaseno\n";
    print "Enter . on a line to exit without adding phase\n";

    $nsessions = promptfor("Number of sessions");
    return if $nsessions =~ $pat_end;

    if (!isnumber($nsessions) || $nsessions <= 0) {
	print "Should be a number(greater than zero)\n";
	return;
    }
    $sesdigits = length;		# Length of number of sessions for ##

    print "Number of boards per session: like 7 or 1-7 or 1-7,8-14,15-21 which is also 3x7\n";
    $seslen = promptfor("Number of boards");
    return if $seslen =~ $pat_end;

    #
    # Special case 3x7 or so
    # Translate to board range list here
    #
    if ($seslen =~ /^([1-9][0-9]*)x([1-9][0-9]*)$/) {
	my $ns = $1;
	my $sl = $2;
	my @sesar;
	for my $s (1..$ns) {
	    my $lowbd = ($s-1)*$sl+1;
	    my $highbd = $s*$sl;
	    my $r = "$lowbd-$highbd";
	    push @sesar, $r;
	}
	$seslen = join ",", @sesar;
	print "translated to $seslen\n";
    }

    my $complex = complex_ses_pat($nsessions, $seslen);
    if ($complex ne "BAD") {
	$seslen = $complex;
	print "translated to $seslen\n";
    }

    if (!is_board_range_list($seslen)) {
	print "Should be a number or board range list\n";
	return;
    }

    print "For following two questions a row of # signs in your answer will be replaced by the session number\n";
    print "So rr# will become rr9, rr10, rr11 or rr## will become rr09, rr10, rr11\n";
    print "If you do not specify the #'es they will be added if needed\n\n";

    do {
	$sesfname = promptfor("file-prefix");
	return if $sesfname =~ $pat_end;
    } until $sesfname =~ /^[a-zA-Z][a-zA-Z0-9]*$/;

    if ($nsessions != 1 && $sesfname !~ /#/) {
	$hashes = "#" x $sesdigits;
	$sesfname .= $hashes;
	print "file-prefix changed to $sesfname\n";
    }

    # Check if this works without reading file
    if (my $uf = $usedfname{$sesfname}) {
	print "Filename already used in phase $uf\n";
	return;
    }

    my $sesdescr = promptfor("description");
    return if $sesdescr =~ $pat_end;

    #
    # In case some weirdo puts a : in description
    #
    $sesdescr =~ s/\://g;

    if ($nsessions != 1 && $sesdescr !~ /#/) {
	$hashes = " #/$nsessions";
	$sesdescr .= $hashes;
	print "session description changed to $sesdescr\n";
    }

    $TrnPhaseName[++$TrnNPhases] = "$nsessions:$seslen:$sesfname:$sesdescr";
}

sub showphases {
    #
    # Show phases again, in case user forgot
    #
    if ($TrnNPhases <= 0) {
	print "No tournament phases have been defined yet\n";
	return;
    }
    print "Tournament phases:\n";
    for my $ph (1..$TrnNPhases) {
	my ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$ph];
	print "Phase $ph: $nses sessions of $seslen boards on file $sesfname: $sesdescr\n"; 
    }
}

#
# MAIN program
#
#
# Prepend . to PATH
#
# Some better way of linking to bigdealx should be found
#

$path = $ENV{"PATH"};
$path = ".:$path";
$ENV{"PATH"} = $path;

print "Welcome to the tournament board manager version $version\n";
#
# Call bigdeal here to make one board, could be quiet if it works
#

testbigdeal();

selecttourn();

print "Tournament from file $TFile\n";
print "Tournament name: $TrnName\n";
print "Delayed Info $TrnDelayedInfo\n";
print "Delayed Value $TrnDelayedValue\n" if (defined($TrnDelayedValue));

showphases();

do_menu($TrnPublished ? $PostPublishMenu : $PrePublishMenu);

promptfor("Type enter to quit ");
