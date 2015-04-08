#!/usr/bin/env perl
#
# Optimized calculation algorithms not assumed.  
# 
# The input arguments are interpreted as query for calculating an AlGaN alloy properties among compound $x, alloy energy gap $eg
# or egde absorption wavelength $wl depending on passed values. For example 4:0.1:5 will be treated as energy gap ($eg)
#
# Evgeny Shevchenko, 2013-2014

# TODO --help|-h option
# TODO POD usage

use Modern::Perl;
use Getopt::Long;


my $CALC_TOLERANCE = 1e-6;

# my $eg_AlN = 6.20;
# my $eg_GaN = 3.42; #RT
# my $bowing = 1;


# I. Vurtgaftman and J. R. Meyer,  J. Appl. Phys., Vol. 94, No. 6
# Sept 15, 2003
my $eg_AlN = 6.25;
my $eg_GaN = 3.51; # 0K
my $bowing = 0.7;



# --------------------------------------------------
my $temperature = 0;
GetOptions('T|t|temperature=f' => \$temperature);

sub varshni {
	my ($e0, $a, $b, $t) = @_;
	return $e0 - $a*$t*$t / ($t + $b);
}

if ($temperature > 0) {
	$eg_AlN = varshni($eg_AlN, 1.799e-3, 1462, $temperature);
	$eg_GaN = varshni($eg_GaN, 0.909e-3,  830, $temperature);
}


# --------------------------------------------------
my ($x, $wl, $eg);

sub min {
	my $a = shift;
	my $b = shift;
	return $a < $b ? $a : $b;
}

sub max {
	my $a = shift;
	my $b = shift;
	return $a > $b ? $a : $b;
}

sub energy_gap { 
	my $x = shift;
	$eg_AlN * $x + $eg_GaN * (1 - $x) - $bowing * $x * (1 - $x) ; 
} 


# Convert electronvolts to nanometers and in reverse
sub ev_nm_convert { 
	my $p = shift;
	1239.84193 / $p; 
}


sub calc_compound {
	my $eg = shift;
	
	# Solving square equation
	my $p = ($eg_AlN - $eg_GaN - $bowing) / $bowing;
	my $q = ($eg_GaN - $eg) / $bowing;

	my $s1 = - $p / 2;
	my $s2 = sqrt($p**2 / 4 - $q);

	max($s1 - $s2, $s1 + $s2);
}





sub investigate_param {
	
	my $p = shift;

	if (0 <= $p and $p <= 1 ) {

		# The parameter is compound
		$x = $p;
		$eg = energy_gap($x);
		$wl = ev_nm_convert($eg);

	} elsif (min($eg_AlN, $eg_GaN) <= $p and $p <= max($eg_AlN, $eg_GaN)) {

		# The parameter is energy gap
		$eg = $p;
		$wl = ev_nm_convert($eg);
		$x = calc_compound($eg);

	} elsif (   min(ev_nm_convert($eg_AlN), ev_nm_convert($eg_GaN)) <= $p and
		    $p <= max(ev_nm_convert($eg_AlN), ev_nm_convert($eg_GaN))) {

		# The parameter is wavelength
		$wl = $p;
		$eg = ev_nm_convert($wl);
		$x = calc_compound($eg);

	} else {
		say "Input '$p' cannot be recognized.";
		next;
	}

	printf "%.2f%10s%.3f %-8s%.2f %-7s\n", $x, "", $eg, "eV", $wl, "nm";
}


printf("%-14s%-14s%-14s\n", "Compound", "Energy gap", "Wavelength");

foreach my $p (@ARGV) { 
	if ($p =~ m/^\d+\.?\d*$/) {

		investigate_param($p);

	} elsif ($p =~ m/^(\d+.?\d*)\:(\d+.?\d*)\:(\d+.?\d*)$/ ) {
		my ($min, $step, $max) = split(':', $p);
		# FIXME my ($min, $step, $max) = ($1, $2, $3);
		($min, $max) = ($max, $min) if $min > $max;

		# my $min = min($0, $2);
		# my $max = max($0, $2);
		# my $step = $1;

		my $size = abs($max - $min) / $step;
		# FIXME my $size = int(abs($max - $min) / $step) + 1;
		investigate_param($min + $_*$step) for 0..$size;
	}
	say '';
}

