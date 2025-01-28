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

    print OUTF "% PBN 2.1\n% EXPORT\n%\n[Generator \"PbnPart\"]\n";
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
    my $h_shift = $compass_shift{$1};
    $hand_north = $hands[(0+$h_shift)%4];
    $hand_east = $hands[(1+$h_shift)%4];
    $hand_south = $hands[(2+$h_shift)%4];
    $hand_west = $hands[(3+$h_shift)%4];
    return "[Deal \"N:$hand_north $hand_east $hand_south $hand_west\"]";
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

sub handle_flag {
    my ($flag) = @_;

    print "flag $flag\n";
    if ($flag =~ /boards=(.*)/) {
	my $brdlist = translate_session_length($1);
	@range_arg = split /,/, $brdlist;
	print "Ranges given: @range_arg\n";
    }
}

foreach (@ARGV) {
    if (/=/) {
	handle_flag($_);
    } else {
	push (@files, $_);
    }
}

# $ranges = "1-7,8-14,15-21";
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

if ($#range_arg < 0) {
    print "No board range list given\nQuitting.....\n";
    die;
}
# @range_arg = split /,/, $ranges;
# print "Ranges given: @range_arg\n";

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
