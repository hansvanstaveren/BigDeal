#!/usr/bin/perl -w

#
# TODO
#
# There is a minor weakness left, the DI info is not protected, which could lead to the
# following minor trouble:
# ORG publishes SQD file, for example stating he will use DJI of June 1 as Delayed Information
# external party copies this file, but changes his copy to say DJI June 2
# At the end of the tournament the external party accuses the ORG of having modified his promise
# because he wanted to make different hands
#
# Highly unlikely, and will fail immediately if another copy is made
# Anyhow, this can be fixed by including the DI info in the keyhash
#

#
# external routines from Packages
#
use Digest::SHA::PurePerl qw( sha256_hex );
use Bytes::Random::Secure qw( random_string_from );
use File::Copy qw( copy );
use Convert::Base64 qw( encode_base64 );

#
# Version of program
#
$version_major = 2;
$version_minor = 6;
$version = "$version_major.$version_minor";

#
# Version of program that made description file
#
$dsc_major = 0;
$dsc_minor = 0;

#
# BigDeal parameters
#
$bigdeal_prog = "bigdealx";
$bigdeal_seedbits = 320;

$sufdsc = "sqd";
$sufkey = "sqk";

$pat_end = qw/^[0.]$/;

$undef_info = "Tbd";

$Modified = 0;

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
getDI();
$Modified = 1;
%%
add phase of tournament
%
Will add phase, consisting of one or more sessions
includes names of files and description of sessions
also number of sessions and boardnumbers per session
%
if(addphase()) {
    $Modified = 1;
}
%%
publish
%
Marks end of preparation, tournament data can be published now
No changes to phases after this
%
if(publish()) {
    $Modified = 1;
}
MENU

$PostPublishMenu =<<'MENU';
set delayed information value
%
This enters the actual delayed information, as described at publication time
%
getDV();
$Modified = 1;
%%
make session(s)
%
Actually makes the hands of the specified sessions in the specified phases
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

sub warning {
    my ($mes) = @_;

    print "## $mes\n";
}

$nerrors = 0;
sub error {
    my ($mes) = @_;

    print "\n####\n#### $mes\n####\n\n";
    $nerrors++;
}

sub fatal {
    my ($mes) = @_;

    print "\n\n\n######\n###### $mes\n######\n\n\n";
    die "Fatal Error";
}

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
    if ($arg eq "") {
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
	if ($sublen <= 0) {
	    error("$len decreasing range");
	    return 0;
	}
	if ($seslen && $seslen != $sublen) {
	    warning("not all ranges same size ($seslen vs $sublen), probably mistake");
	}
	$seslen = $sublen;
    }
    return 1;
}

#
# Implement more complex session lengths
# Currently only the 3x7 type
#
sub translate_session_length {
    my ($ses_string) = @_;

    #
    # Special case 2x16 or 3x7 or so
    # Translate to board range list here
    #
    if ($ses_string =~ /^([1-9][0-9]*)x([1-9][0-9]*)$/) {
	my $number_ses = $1;
	my $ses_len = $2;
	my @sesar;
	for my $ses (1..$number_ses) {
	    my $lowbd = ($ses-1)*$ses_len+1;
	    my $highbd = $ses*$ses_len;
	    push @sesar, "$lowbd-$highbd";
	}
	$ses_string = join ",", @sesar;
	print "translated to $ses_string\n";
    }
    return $ses_string;
}

sub promptfor_once {
    my ($prompt) = @_;
    
    print "$prompt> ";
    $_ = <>;
    chomp;
    return $_;
}

sub promptfor {
    my ($prompt)= @_;
    my ($answer);

    #
    # Prompt, and ignore empty responses
    #
    do {
	$answer = promptfor_once($prompt);
    } while ($answer eq "");
    return $answer;
}

sub publish {
    my (%keys_used);

    #
    # Tournament Name must be set
    #
    if ($TrnName eq $undef_info) {
	print "Tournament Name has not been set, publishing not allowed\n";
	return 0;
    }
    #
    # Delayed information description must be set
    #
    if ($TrnDelayedInfo eq $undef_info) {
	print "Tournament Delayed Information has not been set, publishing not allowed\n";
	return 0;
    }
    #
    # Should have at least one phase
    #
    if ($TrnNPhases <= 0) {
	print "No phases have been defined, publishing not allowed\n";
	return 0;
    }
    #
    # Test for lingering files or name clashes with other tournament
    #
    for my $fname (keys %usedfname) {
	my $firstses = sharpfill($fname, 1);
	my @files = <$firstses.*>;
	if ($#files >= 0) {
	    warning("Existing files @files may be overwritten, check it please");
	}
    }
    #
    # Generate keys for all sessions
    # Paranoia, but check for duplicate keys
    #
    for my $phase (1..$TrnNPhases) {
	my ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$phase];
	for my $session (1..$nses) {
	    my $this_key = make_secret();
	    die "Duplicate key!!" if ($keys_used{$this_key});
	    $keys_used{$this_key} = 1;
	    $session_key{"$phase,$session"} = $this_key;
	}
    }
    #
    # Write keys and compute hash
    #
    $TrnKeyHash = writekeys("$TFile.$sufkey");

    $TrnPublished = 1;
    $RunOn = 0;
    print "The tournament can now no longer be changed\n";
    print "You should publish the file $TFile.$sufdsc\n";
    print "Keep the file $TFile.$sufkey very, very secret!!\n";

    return 1;
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
    # Set RunOn to 1, will stay there until end is signalled
    #
    $RunOn = 1;
    #
    # Loop: print possibilities, handle ? and call commands
    #
    my $prompt = "Choice";
    my $initspace = " " x ( length($prompt)+2 );
    do {
	print "\n";
	print "For help on menu choice 2 type ?2, etc\n";
	print "--------------------------------------\n";
	print "\n";
	#
	# Show menu, incleading 0 option
	#
	print $initspace, "0)\texit program\n";
	for my $i (0..$#descr_ar) {
	    print $initspace, $i+1, ")\t$descr_ar[$i]\n";
	}
	#
	# Get wanted action
	#
	$ans = promptfor($prompt);
	if ($ans =~ /^(\??)([0-9])$/) {	# regexp second ? is 0 or 1, looks confusing
	    if ($1 && $2>0) {
		my $expl = $explanation_ar[$2-1];
		print "$expl\n" if ($expl);
	    } elsif ($2 == 0) {
		$RunOn = 0;
	    } else {
		my $cmd = $command_ar[$2-1];
		eval $cmd if ($cmd);
	    }
	}

	if ($Modified) {
	    # keep .sqd file up to date after each mod.
	    # This will survive crashes, interrupts, etc...
	    writetourn("$TFile.$sufdsc");
	    $Modified = 0;
	}
    } while ($RunOn);
}

#
# Take format with some ## and replace ### with value of n
# 
# Generalized to also take range, like 4-6 and replace each sharps with two numbers with dash in between
#
sub sharpfill {
    my ($str, $n) = @_;
    my ($prf, $len, $suf, $fmt, $repl);

    # Split format into before ## and the ## and the rest
    $str =~ /([^#]*)(#+)(.*)/ || return $str;
    # Hashes to replace, prf###suf
    $prf = $1;
    $len = length $2;
    $suf = $3;
    $fmt = "%0${len}d";

    if ($n =~ /^([0-9]+)-([0-9]+)$/) {
	# Do range of sessions
	my $low = $1;
	my $high = $2;
	my $range_low = sprintf($fmt, $low);
	my $range_high = sprintf($fmt, $high);
	$repl = "$range_low-$range_high";
    } else {
	# Single session
	$repl = sprintf($fmt, $n);
    }
    return "$prf$repl$suf";
}

sub make_secret {
    my($bitsperchar, $keylen);

    #
    # Calculate how long a string to make for correct number of bigdeal_seedbits
    # Strange factor is just to get at answer 60 for 320 bits, historical
    # Future expansion possible here
    #
    $bitsperchar=log(62)/log(2);
    $keylen = $bigdeal_seedbits / $bitsperchar;
    $keylen *= 1.1166;		# Strategic reserve
    $keylen = int($keylen);
    #
    # Secrets are made as strings containing letters and digits (62 possible characters)
    # When string length = 60
    # This gives 3.495436e+107 possibilities
    # Which is about 357 bits, plenty to fill the 2x160 bits in BigDeal
    #
    # uses:
    # https://metacpan.org/pod/Bytes::Random::Secure
    #
    my $x = join('', ('a'..'z'), ('A'..'Z'), ('0'..'9'));
    return random_string_from( $x, $keylen );
}

sub warnDV {

    print "White space at beginning or end will not be used, inside only single space allowed\n";
    print "When Delayed Info contains a number periods and commas will be deleted from it\n";
    print "\n";
    print "The Delayed Info is always just a string, so 123.0 and 123.00 are different!\n";
    print "\n";
}

sub getDI {
    my ($input_di, $di);

    print "Delayed Info description should be without uncertainty\n";
    warnDV();
    do {
	$di = $input_di = promptfor("Delayed info description");
	$di =~ s/^\s+//;
	$di =~ s/\s+$//;
	$di =~ s/\s+/ /g;
    } until ($di);
    if ($input_di ne $di) {
	warning("Whitespace changed, Delayed Info is now '$di'");
    }
    $TrnDelayedInfo = $di;
}

sub getDV {
    my ($dv);

    warnDV();
    $dv = promptfor("Delayed info value($TrnDelayedInfo)");
    $TrnDelayedValue = $dv;
    #
    # Canonize:
    #  change all strings of whitespace to one space
    #  delete leading and trailing spaces
    #  delete . and , from numbers
    #
    $TrnDelayedValue =~ s/^\s+//;
    $TrnDelayedValue =~ s/\s+$//;
    $TrnDelayedValue =~ s/\s+/ /g;
    $TrnDelayedValue =~ s/([0-9])[\,\.]([0-9])/$1$2/g;
    if ($TrnDelayedValue ne $dv) {
	warning("Input changed, Delayed Value is now '$TrnDelayedValue'");
    }
}

sub readkeys {
    my ($fname) = @_;
    my ($ses_ident, $key);
    my ($nkeys, $keylen, $totalkeylen);

    unless (open(KEYFILE, "<:crlf", $fname)) {
	error("Cannot open the file that should contain the keys ($fname)");
	return 0;
    }
    my $wholefile = "";
    #
    # Read all lines of keys and populate session_key{}
    # Variable $wholefile will contain complete contents, for hashing
    #
    $nkeys = 0;
    $totalkeylen = 0;
    while (<KEYFILE>) {
	chomp;
	#
	# Make sure $wholefile will contain \r\n separators
	# otherwise keyhash will be wrong
	#
	$wholefile .= "$_\r\n";
	($ses_ident, $key) = split /:/;
	$session_key{$ses_ident} = $key;
	$nkeys++;
	$keylen = length($key);
	$totalkeylen += $keylen;
	if ($keylen < 40) {
	    warning("Short key for session $ses_ident");
	}
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
	return 0;
    }
    #
    # Check if we have keys for all sessions of all phases
    #
    for my $phase (1..$TrnNPhases) {
	my ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$phase];
	for my $session (1..$nses) {
	    $ses_ident = "$phase,$session";
	    defined($session_key{$ses_ident}) || fatal("Session $ses_ident has no key, do not use these files");
	}
    }
    #
    # Some statistics
    #
    $KeyStats = sprintf("Read keys for %d sessions, average length %.1f characters\n", $nkeys, $totalkeylen/$nkeys);
    return 1;
}

sub readtourn {
    my($fname, $shouldnotexist) = @_;

    unless (open(TRNFILE, "<", $fname)) {
	print "Cannot open $fname\n" unless ($shouldnotexist);;
    	return 0;
    }
    $TrnNPhases = 0;
    while(<TRNFILE>) {
	# remove end of line crud
	chomp;
	s/\r$//;
	s/\s*$//;

	# Version of writing program

	if (/^#.*[Ss]quare[Dd]eal ([0-9]+)\.([0-9]+).*$/) {
	    $dsc_major = $1;
	    $dsc_minor = $2;
	}

	# ignore all other comments
	next if /^#/;

	if(s/^TN *//) {
	    $TrnName = $_;
	}
	elsif(s/^KH *//) {
	    $TrnKeyHash = $_;
	    $TrnPublished = 1;
	}
	elsif(s/^DI *//) {
	    $TrnDelayedInfo = $_;
	}
	elsif(s/^DV *//) {
	    $TrnDelayedValue = $_;
	}
	elsif(s/^SN *//) {
	    my ($nsessions, $sesboards, $sesfname, $sesdescr) = split(/:/);
	    $TrnPhaseName[++$TrnNPhases] = "$nsessions:$sesboards:$sesfname:$sesdescr";
	    $usedfname{$sesfname} = $TrnNPhases;
	}
    }
    if ($dsc_major == 0 && $dsc_minor == 0) {
	warning("Description file not made by known SquareDeal version");
    }
    unless ($dsc_major < $version_major  || $dsc_major == $version_major && $dsc_minor <= $version_minor) {
	warning("SQD file written by version $dsc_major.$dsc_minor");
	warning("This software is older version ($version_major.$version_minor)");
	warning("Installing new version recommended!!");
    }
    return 1;
}

sub writetourn {
    my ($fname) = @_;

    copy $fname, "$fname.bak";
    open(TRNFILE, ">", $fname ) || fatal("Cannot open $fname");
    print TRNFILE "# Description file of tournament for program SquareDeal $version\n#\n";
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

#
# Write session keys to key-file
# Returns hash to store in description file
#

sub writekeys {
    my ($fname) = @_;

    #
    # Line termination here is CR LF
    # It matters because of checksum, cannot leave it to OS
    #
    my $keys = "";
    for my $phase (1..$TrnNPhases) {
	my @flds = split /:/, $TrnPhaseName[$phase];
	my $nses = $flds[0];
	for my $session (1..$nses) {
	    $keys .= "$phase,$session:" . $session_key{"$phase,$session"} . "\r\n";
	}
    }

    #
    # Write RAW to prevent line termination change
    #
    open (KEYFILE, ">:raw", $fname ) || fatal("cannot open $fname");
    print KEYFILE $keys;
    close(KEYFILE);

    #
    # Compute hash to store in .sqd file
    #
    my $result = sha256_hex($keys);
    return $result;
}

sub selecttourn {
    my (@trnlist);

    @trnlist = <*.$sufdsc>;

    if (!@trnlist) {
	$TFile = "+";
	$myfirsttourn = " your first";
	#
	# First tournament, at least in this folder
	# be gentle on user
	#
    } else {
	print "\nCurrent tournaments:\n";
	foreach my $trnfile (@trnlist) {
	    my $trnprefix = $trnfile;
	    $trnprefix =~ s/\.$sufdsc//;

	    open SQDFILE, '<', "$trnfile" || fatal("Cannot open $trnfile");
	    while(<SQDFILE>) {
		if (/^TN (.*)/) {
		    printf "%-10s: %s\n", $trnprefix, $1;
		}
	    }
	    close SQDFILE;
	}
	$myfirsttourn = "";
	$TFile = promptfor("Which tournament? Use + for new");
    }
    if ($TFile eq "+") {
	#
	# First tournament, or user has typed +
	#
	until ($TFile =~ /^[A-Za-z][A-Za-z0-9]*$/) {
	    $TFile = promptfor("Filename of$myfirsttourn tournament(keep shortish, alphanumerics only)");
	}

	#
	# Should not exist already
	#
	readtourn("$TFile.$sufdsc", 1) && fatal("Tournament $TFile already exists");

	#
	# Set values for empty tournament
	#
	$TrnName = $undef_info;
	$TrnDelayedInfo = $undef_info;
	$TrnNPhases = 0;
	$Modified = 1;
    } else {
	#
	# Read tournament file and set values
	#
	readtourn("$TFile.$sufdsc", 0) || fatal("Cannot open tournament $TFile");
	$TrnKeysAvailable = 0;
	if ($TrnPublished) {
	    #
	    # This tournament was already published, so keys must be there
	    #
	    if (readkeys("$TFile.$sufkey")) {
		$TrnKeysAvailable = 1;
	    }
	}
    }
}

sub testbigdeal {
    my $fname;

    #
    # create one pbn file to test bigdeal
    #
    warning("Will run $bigdeal_prog once to make sure it is installed and works");
    warning("If this is a first time you have to set formats(first question), other questions are irrelevant");
    #
    # Generate a filename that does not exist yet
    #
    do {
	my $x = join('', ('a' .. 'z'), ('0'..'9'));
	my $bytes = random_string_from( $x, 6 );
	$fname = "sqd$bytes";
    } while (-e "$fname.pbn");

    #
    # Run bigdeal to make a PBN file of one board
    # The PBN file now is not there
    #
    my $command = join(' ', $bigdeal_prog, "-p", $fname, "-n", "1", "-f", "pbn");
    system($command);

    #
    # Did it work?
    # The PBN file should now be there
    #
    -s "$fname.pbn" || fatal("$bigdeal_prog failed");

    #
    # It worked, remove PBN file now and all OK
    #
    unlink "$fname.pbn";
    warning("OK, it works");
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
	open INFILE, '<', $infile || fatal("Cannot open $infile");
	while( my $line = <INFILE>)  {
	    # delete headers from subfiles
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
	open INFILE, '<', $infile || fatal("Cannot open $infile");
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

#
# New concatenation logic
#
my $ConcatLastboard;
my @ConcatSessions;
my $ConcatFilename;
my $ConcatLastSession;

sub concat_filename {
    my ($fname) = @_;

    $ConcatFilename = $fname;
}

sub concat_add_file {
    my ($fname, $highboard, $ses) = @_;

    $ConcatLastboard = $highboard;
    push (@ConcatSessions, $fname);
    $ConcatLastSession = $ses;
}

sub concat_files {
    my ($concat_begin, $concat_end) = @_;

    #
    # Make name for file into which to combine
    #
    my $dstfname = sharpfill("$ConcatFilename", "$concat_begin-$concat_end");

    foreach my $format (@formats) {
	my @files = ();

	#
	# List of filenames for this format (might not exist)
	#
	for my $fno ($concat_begin..$concat_end) {
	    $files[$fno - $concat_begin] = $ConcatSessions[$fno - $concat_begin].".$format";
	}
	if (-r $files[0]) {
	    # The first file exists, guess the rest too. Combine them
	    print "Will combine @files to $dstfname.$format\n";
	    $comb_routine{$format}->("$dstfname.$format", @files);
	}
    }
}

sub concat_flush {
    my ($concatlength);

    $concatlength = $#ConcatSessions + 1;
    if ($concatlength > 1) {
	$concat_low_ses = $ConcatLastSession - $concatlength + 1;
	$concat_high_ses = $ConcatLastSession;
	concat_files($concat_low_ses, $concat_high_ses);
    }
    $ConcatLastboard = 0;
    $ConcatLastSession = 0;
    @ConcatSessions = ();
}

# End of concatenation logic

sub makesessionfromphase {
    my ($phase, $reserve, $all) = @_;
    my ($ses, $lowses, $highses);

    $ConcatLastboard = 0;
    @ConcatSessions = ();

    ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$phase];
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
    } elsif ($ses eq "*") {
    	$lowses = 1;
	$highses = $nses;
    } elsif (isnumber($ses)) {
	$lowses = $highses = $ses;
    } else {
	error("$ses not session number or range");
	return;
    }
    if ($lowses < 1 || $lowses > $highses || $highses > $nses) {
	error("Sessions $lowses-$highses with $nses total sessions not possible");
	return;
    }
    #
    # Start actually making
    #
    # First if session length = ? first prompt for real length
    #
    while ($seslen eq "?") {

	my $len = promptfor("Number of boards for $sesdescr");
	$len = translate_session_length($len);
	if (is_board_range_list($len)) {
	    $seslen = $len;
	    $seslen = "1-$seslen" if $seslen =~ /^[0-9]+$/;
	}
    }
    #
    # if session length is something like 1-16,17-32 split it
    #
    @len_ar = split /,/, $seslen;
    $len_size = $#len_ar+1;

    concat_filename($sesfname);
    for $ses ($lowses..$highses) {
	# len_index is index into array of lenghths
	$len_index = ($ses-1) % $len_size;
	# real_seslen is length of this session
	$real_seslen = $len_ar[$len_index];
	# convert single number, like 16, to range, so 1-16
	$real_seslen = "1-$real_seslen" if $real_seslen =~ /^[0-9]+$/;

	my ($concat_low, $concat_high) = split /\-/, $real_seslen;

	#
	# If this file cannot continue a concatenation list, flush current list
	#
	if ($concat_low != $ConcatLastboard + 1) {
	    #
	    # This will reset concatenation stuff
	    # $ConcatLastboard will become 0 again
	    #
	    concat_flush();
	}

	$sesfnamereal = sharpfill($sesfname, $ses);
	$sesfnamereal .= "reserve" if ($reserve);

	$sesdescrreal = sharpfill($sesdescr, $ses);

	#
	# get session key, and split into left half and right half to put into bigdealx
	#
	my $this_seskey = $session_key{"$phase,$ses"};
	my $skl = int ((length $this_seskey)/2);
	my $seskeyleft = substr $this_seskey, 0, $skl;
	my $seskeyright = substr $this_seskey, $skl;

	#
	# delayed value is base64 encoded in case it contains weird characters
	#
	my $DVencoding = encode_base64($TrnDelayedValue);

	print "Making file $sesfnamereal, session $sesdescrreal, brds $concat_low to $concat_high\n";
	$command = join(' ', $bigdeal_prog,
	    "-W", $seskeyleft,
	    "-e", $seskeyright,
	    "-e", $DVencoding,
	    "-e", $reserve == 0 ? "original" : "reserve",
	    "-p", $sesfnamereal,
	    "-n", $real_seslen
		    );
	#
	# Run bigdeal command and check if nothing weird comes out
	# Just counting for two lines now
	# This check might be made more serious
	#
	$output = `$command`;
	$nlines = ( $output =~ tr/\n// );
	if ($nlines != 2) {
	    print "An error might have occurred: output of Bigdeal:\n$output";
	}

	# Can this file later be concatenated?
	# It might if boardnumbers are sequential to it

	if ($concat_low == $ConcatLastboard + 1) {
	    concat_add_file($sesfnamereal, $concat_high, $ses);
	}
    }
    #
    # Concatenate final files if needed
    #
    concat_flush();
}

sub makesession {
    my ($reserve) = @_;

    #
    # Making sessions only possible after setting Delayed Information Value
    #
    unless (defined($TrnDelayedValue)) {
	warning("Delayed value not set, do that first");
	return;
    }

    #
    # We should have read the keys to continue
    #
    unless ($TrnKeysAvailable) {
	warning("No keys available");
	return;
    }

    showphases();
    #
    # * means all sessions from all phases
    #
    my $phase = promptfor("Session phase, * for all");
    if ($phase eq "*") {
	# do all
	
	for my $ph (1..$TrnNPhases) {
	    makesessionfromphase($ph, $reserve, 1);
	}
	return;
    }
    if ( !isnumber($phase) || $phase <= 0 || $phase > $TrnNPhases) {
	print "$phase not a valid phase number\n";
	return;
    }

    makesessionfromphase($phase, $reserve, 0);
}

sub addphase {
    my ($nsessions, $sesdigits, $sesfname, $sesdescr, $seslen, $phaseno);

    showphases();

    $phaseno = $TrnNPhases+1;
    print "About to add phase number $phaseno\n";
    print "Enter . on a line to exit without adding phase\n";

    $nsessions = promptfor("Number of sessions");
    return 0 if $nsessions =~ $pat_end;

    if (!isnumber($nsessions) || $nsessions <= 0) {
	warning("Should be a number(greater than zero)");
	return 0;
    }
    $sesdigits = length $nsessions;	# Length of number of sessions for ##

    print "Number of boards per session: like 7 or 1-7 or 1-7,8-14,15-21 which is also 3x7\n";
    $seslen = promptfor("Number of boards");
    return 0 if $seslen =~ $pat_end;

    $seslen = translate_session_length($seslen);

    unless ($seslen eq "?" || is_board_range_list($seslen)) {
	warning("Should be a number or board range list, or ? if unknown");
	return 0;
    }

    print "For following two questions a row of # signs in your answer will be replaced by the session number\n";
    print "So rr# will become rr9, rr10, rr11 or rr## will become rr09, rr10, rr11\n";
    print "If you do not specify the #'es they will be added automatically by program\n\n";

    do {
	$sesfname = promptfor("file-prefix");
	return 0 if $sesfname =~ $pat_end;
	if ($sesfname =~ /#+.*[^#].*#/) {
	    warning("$sesfname contains two or more strings of #, not allowed");
	    $sesfname = "@";	# Will not be allowed
	}
    } until $sesfname =~ /^[a-zA-Z][a-zA-Z0-9#_\-]*$/;

    if ($nsessions != 1 && $sesfname !~ /#/) {
	$sesfname .= "#" x $sesdigits;
	print "file-prefix changed to $sesfname\n";
    }

    # Check if this works without reading file
    if (my $uf = $usedfname{$sesfname}) {
	error("Filename already used in phase $uf");
	return 0;
    }

    do {
	$sesdescr = promptfor("description");
	return 0 if $sesdescr =~ $pat_end;
    } until $sesdescr =~ /./;

    #
    # In case some weirdo puts a : in description
    #
    $sesdescr =~ s/\://g;

    if ($nsessions != 1 && $sesdescr !~ /#/) {
	$sesdescr .= " #/$nsessions";
	print "session description changed to $sesdescr\n";
    }

    $TrnPhaseName[++$TrnNPhases] = "$nsessions:$seslen:$sesfname:$sesdescr";
    $usedfname{$sesfname} = $TrnNPhases;
    return 1
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
    for my $phase (1..$TrnNPhases) {
	my ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$phase];
	print "Phase $phase: $nses sessions of $seslen boards on file $sesfname: $sesdescr\n"; 
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

print "Welcome to the SquareDeal tournament board manager version $version\n";

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

print $KeyStats if ($KeyStats);

do_menu($TrnPublished ? $PostPublishMenu : $PrePublishMenu);

if ($nerrors) {
    print "#### There were $nerrors errors, check it\n";
}

# In case it is ran from Windows in temporary window
promptfor_once("Type enter to quit ");
