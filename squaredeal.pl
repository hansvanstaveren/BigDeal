#!/usr/bin/perl -w
use Digest::SHA::PurePerl qw(sha256_hex );
use Bytes::Random::Secure qw( random_string_from );
use File::Copy qw( copy );

$suf = "sqd";
$sufkey = "sqk";
$bigdeal = "./bigdealx";

$undefDI = "Tbd";
$TrnName = "Not yet defined";
$TrnNPhases = 0;

$PrePublishMenu =<<'MENU';
set tournament name
%
Setting name of tournament.
Just for identification purposes, it has no effect on crypto
%
$TrnName = promptfor("Name");
$modified = 1;
%%
set delayed information description
%
This describes which delayed information will be used after publishing and before dealing
For example: Dow Jones Industrial Average on Friday April 13
%
$TrnDelayedInfo = promptfor("Delayed info description");
$modified = 1;
%%
add phase of tournament
%
Will add phase, consisting of one or more sessions
includes names of files and decsription of sessions
%
addphase();
$modified = 1;
%%
publish
%
Marks end of preparation, tournament data can be published now
%
publish();
$modified = 1;
MENU

$PostPublishMenu =<<'MENU';
set delayed information value
%
This enters the actual delayed information, as described at publication time
%
$TrnDelayedValue = promptfor("Delayed info value");
$modified = 1;
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

$modified = 0;

sub isnumber {
    my ($arg) = @_;

    if ($arg =~ /^\d+$/) {
	return 1;
    }
    return 0;
}

sub publish {

    if ($TrnDelayedInfo eq $undefDI) {
	print "Tournament Delayed Information has not been set, publishing not allowed\n";
	return;
    }
    for my $ph (1..$TrnNPhases) {
	my ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$ph];
	for my $s (1..$nses) {
	    $skey{"$ph,$s"} = make_secret();
	    # print "PU made key", $ph, $s, $skey{"$ph,$s"}, "\n";
	}
    }
    $TrnPublished = 1;
    # Write keys and compute hash
    $TrnKeyHash = writekeys("$TFile.$sufkey");
    $runon = 0;
    print "The tournament can now no longer be changed\n";
    print "You should publish the file $TFile.$suf\n";
    print "Keep the file $TFile.$sufkey very, very secret!!\n";
}

sub do_menu {
    my ($menu) = @_;
    my (@descr_ar, @explanation_ar, @command_ar);

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
    $runon = 1;
    print "For help on menu item 2 type ?2, etc\n";
    do {
	print "0)\texit program\n";
	for my $i (0..$#descr_ar) {
	    print $i+1, ")\t$descr_ar[$i]\n";
	}
	print "Item? ";
	my $ans = <>;
	chomp $ans;
	if ($ans =~ /^\?([0-9]*)$/) {
	    print $explanation_ar[$1-1], "\n";
	} elsif ($ans =~ /^[0-9]*$/) {
	    my $ino = $ans -1;
	    if ($ino >= 0) {
		if (!defined($command_ar[$ino])) {
		    print "Command unknown\n";
		} else {
		    eval $command_ar[$ino];
		}
	    } else {
		$runon = 0;
	    }
	}
	if ($modified) {
	    print "Modified, writing ...\n";
	    writetourn("$TFile.$suf");
	    $modified = 0;
	}
    } while ($runon);
}

sub promptfor {
    my ($prompt) = @_;
    
    print "$prompt> ";
    $_ = <>;
    chomp;
    return $_;
}

sub sharpfill {
    my ($str, $n) = @_;
    my ($prf, $suf, $fmt, $repl);

    $str =~ /([^#]*)(#+)(.*)/ || return $str;
    $prf = $1;
    $l = length $2;
    $suf = $3;
    # return $str if ($l==0);
    $fmt = "%0${l}d";
    $repl = sprintf($fmt, $n);
    return $prf.$repl.$suf;
}

sub make_secret {

    my $x = join('', ('a' .. 'z'), ('A'..'Z'), ('0'..'9'));
    my $bytes = random_string_from( $x, 60 );
    return $bytes;
}

sub readkeys {
    my ($fname) = @_;
    my ($hashval, $key);

    open(KEYFILE, "<:crlf", $fname) || return 0;
    my $wholefile = "";
    my $hashlist = "";
    while (<KEYFILE>) {
	chomp;
	$wholefile .= "$_\r\n";
	($hashval, $key) = split /:/;
	# print "hv=$hashval, k=$key\n";
	$hashlist .= "$hashval ";
	$skey{$hashval} = $key;
    }
    $result = sha256_hex($wholefile);
    # print "Hash of keys: $result\n";
    if ($result ne $TrnKeyHash) {
	print "Found wrong keyhash\n";
	print "Hash in description: $TrnKeyHash\n";
	print "length ", length($TrnKeyHash), "\n";
	print "Hashed key values  : $result\n";
	print "length ", length($result), "\n";
	die;
    }
    # print "Found keys for sessions: $hashlist\n";
    for my $ph (1..$TrnNPhases) {
	my ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$ph];
	for my $s (1..$nses) {
	    $hashval = "$ph,$s";
	    if (!defined($skey{$hashval})) {
		print "No key found for session $hashval\nFatal error, stop using these files !!!\n";
		exit(-1);
	    }
	    # print "PU made key", $ph, $s, $skey{"$ph,$s"}, "\n";
	}
    }
    return 1;
}

sub readtourn {
    my($fname) = @_;

    open(TRNFILE, "<", $fname) || return 0;
    while(<TRNFILE>) {
	chomp;
	s/\r$//;
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
	}
	if(s/^PU$//) {
	    $TrnPublished = 1;
	}
    }
    return 1;
}

sub writetourn {
    my ($fname) = @_;

    copy $fname, "$fname.bak";
    open(TRNFILE, ">", $fname ) || die;
    print TRNFILE "# Description file of tournament for program squaredeal\n#\n";
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
	# print TRNFILE "PU\n";
    } else {
	print TRNFILE "#\n# Until published this file may be edited if so wished\n";
    }
    close(TRNFILE);
}

sub writekeys {
    my ($fname) = @_;
    $result = "";

    copy $fname, "$fname.bak";
    open(TRNFILE, ">:raw", $fname ) || die;
    my $keys = "";
    for my $sf (1..$TrnNPhases) {
	($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$sf];
	# print "wt: $sf $nses\n";
	for my $s (1..$nses) {
	    $keys .= "$sf,$s:" . $skey{"$sf,$s"} . "\r\n";
	}
    }
    # print "$keys";
    print TRNFILE $keys;
    $result = sha256_hex($keys);
    # print "hash=$result\n";
    close(TRNFILE);
    return $result;
}

sub selecttourn {


    @x = <*.$suf>;
    print "Current tournaments:";
    for (@x) {
	s/\.$suf//;
	print " $_";
    }

    print "\n";

    print "Which tournament? + for new:";
    $TFile = <>;
    chomp $TFile;
    if ($TFile eq "+") {
	print "Filename of tournament(keep under 10 chars, no spaces or other weird characters): ";
	$TFile = <>;
	chomp $TFile;
	if (readtourn($TFile)) {
	    die "Tournament already exists";
	}
	$TrnDelayedInfo = $undefDI;
    } else {
	print "Will use tournament $TFile\n";
	readtourn("$TFile.$suf") || die;
	if ($TrnPublished) {
	    if(!readkeys("$TFile.$sufkey")) {
	       print "No keyfile found, could be normal(DEVELOPMENT)\n";
	    }
	}
    }
}

sub makesession {
    my ($reserve) = @_;

    unless (defined($TrnDelayedValue)) {
	print "Delayed value not set, do that first\n";
	return;
    }
    my $reserve_session = 0;
    if ($reserve) {
	$reserve_session = promptfor("which reserve? Usually 1");
	if ($reserve_session eq "") {
	    print "Must not be empty\n";
	    return;
	}
    }
    # print "res $_ $reserve_session\n";
    my $sf = promptfor("Session phase");
    if ( !isnumber($sf) || $sf <= 0 || $sf > $TrnNPhases) {
	print "$sf not a valid phase number\n";
	return;
    }
    ($nses, $seslen, $sesfname, $sesdescr) = split /:/, $TrnPhaseName[$sf];
    # print "nses=$nses, seslen=$seslen, sesfname=$sesfname, sesdescr=$sesdescr\n";
    my $ses = promptfor("Session(s)");
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
    @len_ar = split /,/, $seslen;
    # print "len_ar[] = @len_ar, $#len_ar\n";
    for $ses ($lowses..$highses) {
	$len_index = ($ses-1) % ($#len_ar+1);
	$real_seslen = $len_ar[$len_index];
	# print "seslen $seslen len_index $len_index rseslen $real_seslen\n";
	$sesfnamereal = sharpfill($sesfname, $ses);
	# print "sesfname=$sesfname, sesfnamereal=$sesfnamereal\n";
	$sesfnamereal .= "res$reserve_session" if ($reserve_session);
	$sesdescrreal = sharpfill($sesdescr, $ses);
	$seskey = $skey{"$sf,$ses"};
	$skl = int ((length $seskey)/2);
	$seskeyleft = substr $seskey, 0, $skl;
	$seskeyright = substr $seskey, $skl;
	print "sk=$seskey\nl=$seskeyleft, r=$seskeyright\n";
	print "About to make file $sesfnamereal, session $sesdescrreal\n";
	system $bigdeal, "-W", $seskeyleft,
	    "-e", $seskeyright,
	    "-e", $TrnDelayedValue,
	    "-e", $reserve_session,
	    "-p", $sesfnamereal,
	    "-n", $real_seslen ;
    }
}

sub addphase {
    my $sesdigits;

    promptfor("Number of sessions");
    my $nsessions = $_;
    if (!isnumber($nsessions)) {
	print "Should be a number\n";
	return;
    }
    $sesdigits = length;
    promptfor("Number of boards per session");
    my $seslen = $_;
    if (!isnumber($seslen)) {
	print "Should be a number\n";
	return;
    }
    print "For following two questions a row of # signs in your answer will be replaced by the session number\n";
    print "So rr# will become rr9, rr10, rr11 or rr## will become rr09, rr10, rr11\n";
    print "If you do not specify the number it will be added if needed\n\n";
    promptfor("file-prefix");
    my $sesfname = $_;
# Check for :  or other weirdness
    if ($nsessions != 1 && $sesfname !~ /#/) {
	$hashes = "#" x $sesdigits;
	# print "No hashes in name, will append $hashes\n";
	$sesfname .= $hashes;
	print "file-prefix changed to $sesfname\n";
    }
    promptfor("description");
    my $sesdescr = $_;
    if ($nsessions != 1 && $sesdescr !~ /#/) {
	$hashes = " #/$nsessions";
	# print "No hashes in description, will append $hashes\n";
	$sesdescr .= $hashes;
	print "session description changed to $sesdescr\n";
    }
# Check for :  or other weirdness
    $TrnPhaseName[++$TrnNPhases] = "$nsessions:$seslen:$sesfname:$sesdescr";
}

print "Welcome to the tournament board manager\n";
selecttourn();

if (defined($TrnName)) {
    print "Tournament from file $TFile\n";
    print "Tournament name: $TrnName\n";
    print "Delayed Info $TrnDelayedInfo\n";
    print "Delayed Value $TrnDelayedValue\n" if (defined($TrnDelayedValue));
    for my $s (1..$TrnNPhases) {
	print "Session phase $s -> $TrnPhaseName[$s]\n";
    }
}
do_menu($TrnPublished ? $PostPublishMenu : $PrePublishMenu);
# writetourn("$TFile.$suf");

promptfor("Type enter to quit ");
