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

    print OUTF "dealer $di $d vuln $vi $v\n";
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

$ranges = shift @ARGV;

while (<>) {
    next unless /^\[Deal /;
    push (@deals, $_);
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
	output_hand($dnum, $deal);
    }
    close OUTF;
    print "$outfile ";
    
    $cur_range++;
}

print "\n";
