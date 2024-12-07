#!/usr/bin/perl

@dealerstr = ( "W", "N", "E", "S" );
@vulnstr = ( "None", "NS", "EW", "All" );
@vuln_index = (
	2,	0,	1,	2,
	3,	1,	2,	3,
	0,	2,	3,	0,
	1,	3,	0,	1
);

sub output_hand {
    my ($dealnum, $deal) = @_;

    my $di = $dealnum%4;
    my $vi = $dealnum%16;
    my $d = $dealerstr[$di];
    my $v = $vulnstr[$vuln_index[$vi]];

    # print OUTF "dealer $di $d vuln $vi $v\n";
    print OUTF "[Event \"?\"]\n";
    print OUTF "[Site \"?\"]\n";
    print OUTF "[Date \"?\"]\n";
    print OUTF "[Board \"$dealnum\"]\n";
    print OUTF "[West \"?\"]\n";
    print OUTF "[North \"?\"]\n";
    print OUTF "[East \"?\"]\n";
    print OUTF "[South \"?\"]\n";
    print OUTF "[Dealer \"$d\"]\n";
    print OUTF "[Vulnerable \"$v\"]\n";
    print OUTF "$deal";
    print OUTF "[Scoring \"?\"]\n";
    print OUTF "[Declarer \"?\"]\n";
    print OUTF "[Contract \"?\"]\n";
    print OUTF "[Result \"?\"]\n";
    print OUTF "\n";
}

sub output_header {

    print OUTF "% PBN 2.1\n% EXPORT\n%\n[Generator \"Renumberpbn\"]\n";
}

my %compass_shift = (
  "N" => 0,
  "E" => 1,
  "S" => 2,
  "W" => 3,
);

sub northmalize {
    my ($deal) = @_;

    $deal =~ /^\[Deal "([NESW]):([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) *"]/;
    my @hands = ($2, $3, $4, $5);
    # print "$deal\nDealer $1 hands @hands\n";
    $shift = $compass_shift{$1};
    # print "Shift = $shift\n";
    $hand_north = $hands[(0+$shift)%4];
    $hand_east = $hands[(1+$shift)%4];
    $hand_south = $hands[(2+$shift)%4];
    $hand_west = $hands[(3+$shift)%4];
    # print "N:$hand_north, E:$hand_east\n";
    return "[Deal \"N:$hand_north $hand_east $hand_south $hand_west\"]";
}

sub handle_flag {
    my ($flag) = @_;

    print "flag $flag\n";
}

foreach (@ARGV) {
    if (/=/) {
	handle_flag($_);
    } else {
	push (@files, $_);
    }
}

$ranges = "1-7,8-14,15-21";
# $ranges = shift @ARGV;

for my $f (@files) {
    open ( PBNFILE, $f) || die $f;

    while (<PBNFILE>) {
	next unless /^\[Deal /;
	$orig_deal = $_;
	$trlat_deal = northmalize($_);
	# print "Deal before and after\n$orig_deal\n$trlat_deal\n";
	push (@deals, $trlat_deal);
    }

    close ( PBNFILE );
}

print "Number of deals ", $#deals+1, "\n";

@range_arg = split /,/, $ranges;
print "Ranges given: @range_arg\n";

#
# Output files are numbered
#
$outfnum = 0;

$cur_range = 0;
print "Files made: ";
while ($#deals >= 0) {
    $outfnum++;

    $range = $range_arg[$cur_range%($#range_arg + 1)];
    # print "Now $range\n";
    ($lowbrd, $highbrd) = split /\-/, $range;
    die "Wrong range $range" unless $lowbrd>0 && $highbrd>$lowbrd;
    # print "$lowbrd, $highbrd\n";
    $outfile = "out$outfnum.pbn";
    open OUTF, ">", $outfile || die;
    output_header();
    for $dnum ($lowbrd..$highbrd) {
	$deal = shift(@deals);
	last unless($deal);
	output_hand($dnum, $deal);
    }
    close OUTF;
    print "$outfile ";
    
    $cur_range++;
}

print "\n";
