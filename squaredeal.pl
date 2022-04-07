#!/usr/bin/perl -w
use Digest::SHA::PurePerl qw(sha256_hex );
use Bytes::Random::Secure qw( random_string_from );
use File::Copy qw( copy );

$suf = "sqd";
$sufkey = "sqk";
$bigdeal = "./bigdealx";

$PrePublishMenu =<<'MENU';
set tournament name
%
Setting name of tournament.
Just for identification purposes, it has no effect on crypto
%
$TrnName = promptfor("Name");
%%
set delayed information description
%
This describes which delayed information will be used after publishing and before dealing
For example: Dow Jones Industrial Average on Friday April 13
%
$TrnDelayedInfo = promptfor("Delayed info description");
%%
add phase of tournament
%
Will add phase, consisting of one or more sessions
includes names of files and decsription of sessions
%
addphase();
%%
publish
%
Marks end of preparation, tournament data can be published now
%
publish();
MENU

$PostPublishMenu =<<'MENU';
set delayed information value
%
This enters the actual delayed information, as described at publication time
%
$TrnDelayedInfo = promptfor("Delayed info value");
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
makesession(promptfor("which reserve? Usually 1"));
MENU


sub publish {

    $TrnPublished = 1;
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
    print "To exit type 0\n\n";
    do {
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
	print "Hashed key values  : $result\n";
	die;
    }
    print "Found keys for sessions: $hashlist\n";
    return 1;
}

sub readtourn {
    my($fname) = @_;

    open(TRNFILE, "<", $fname) || return 0;
    while(<TRNFILE>) {
	chomp;
	if(s/^TN *//) {
	    $TrnName = $_;
	}
	if(s/^KH *//) {
	    $TrnKeyHash = $_;
	}
	if(s/^DI *//) {
	    $TrnDelayedInfo = $_;
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
    print TRNFILE "TN $TrnName\n";
    print TRNFILE "KH $TrnKeyHash\n";
    print TRNFILE "DI $TrnDelayedInfo\n";
    for my $s (1..$TrnNPhases) {
	print TRNFILE "SN $TrnPhaseName[$s]\n";
    }
    if ($TrnPublished) {
	print TRNFILE "PU\n";
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
    print "Current tournaments:";
    for (@x) {
	s/\.$suf//;
	print " $_";
    }

    print "\n";

    print "Which tournament? + for new:";
    $TFile = <>;
    chomp $TFile;
    if ($TFile =~ /^\+$/) {
	print "Name of tournament: ";
	$TFile = <>;
	chomp $TFile;
	if (readtourn($TFile)) {
	    die "Tournament already exists";
	}
	$TrnDelayedInfo = "Tbd";
    } else {
	print "Will use tournament $TFile\n";
	readtourn("$TFile.$suf") || die;
	readkeys("$TFile.$sufkey") || die "No keyfile found, normal if you are not the organiser";
    }
}

sub makesession {
    my ($reserve_session) = @_;

    # print "res $_ $reserve_session\n";
    my $sf = promptfor("Session phase");
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
	# print "sk=$seskey\nl=$seskeyleft, r=$seskeyright\n";
	print "About to make file $sesfnamereal, session $sesdescrreal\n";
	system $bigdeal, "-W", $seskeyleft,
	    "-e", $seskeyright,
	    "-e", $TrnDelayedInfo,
	    "-e", $reserve_session,
	    "-p", $sesfnamereal,
	    "-n", $real_seslen ;
    }
}

sub addphase {

    promptfor("nsessions");
    my $nsessions = $_;
    promptfor("nboards");
    my $seslen = $_;
    promptfor("file-prefix");
    my $sesfname = $_;
    promptfor("description");
    my $sesdescr = $_;
    $TrnPhaseName[++$TrnNPhases] = "$nsessions:$seslen:$sesfname:$sesdescr";
    for my $s (1..$nsessions) {
	$skey{"$TrnNPhases,$s"} = make_secret();
    }
}

@x = <*.$suf>;

print "Welcome to the tournament board manager\n";
selecttourn();

if (defined($TrnName)) {
    print "Tournament $TFile\n";
    print "Delayed Info $TrnDelayedInfo\n";
    for my $s (1..$TrnNPhases) {
	print "Session phase $s -> $TrnPhaseName[$s]\n";
    }
}
do_menu($TrnPublished ? $PostPublishMenu : $PrePublishMenu);
$TrnKeyHash = writekeys("$TFile.$sufkey");
writetourn("$TFile.$suf");

promptfor("Type enter to quit ");
