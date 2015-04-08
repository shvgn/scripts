#!/usr/bin/env perl6
#
# This script is written in order to to have some practice in Perl 6.  
# Optimized calculations algorithms thus not assumed.  
# 
# The input arguments are interpreted as query for calculating an AlGaN alloy
# properties among compound $x, alloy energy gap $eg or egde absorption
# wavelength $wl
#
# Evgeny Shevchenko, 2013

use v6;
my $CALC_TOLERANCE = 1e-6;

my $eg_AlN = 6.08;
my $eg_GaN = 3.42;
# my $bowing = 1.1;
my $bowing = 1;

my ($x, $wl, $eg);


sub energy_gap($x) { 
    $eg_AlN * $x + $eg_GaN * (1 - $x) - $bowing * $x * (1 - $x) ; 
} 


# Convert electronvolts to nanometers and in reverse
sub ev_nm_convert($p) { 1239.84193 / $p; }


sub calc_compound($eg) {
    # Solving square equation
    my $p = ($eg_AlN - $eg_GaN - $bowing) / $bowing;
    my $q = ($eg_GaN - $eg) / $bowing;

    my $s1 = - $p / 2;
    my $s2 = sqrt($p**2 / 4 - $q);

    max($s1 - $s2, $s1 + $s2);
}


sub calc-compound-w-bisection($eg) {
    my $x-min = 0;
    my $x-max = 1;
    my $x-mid = 0.5;
    
    sub f($x) {
        energy_gap($x) - $eg;
    }

    my $f = f($x-mid);

    until abs($f) < $CALC_TOLERANCE {

        if $f * f($x-max) > 0 {
            $x-max = $x-mid;            
        
        } elsif $f * f($x-min) > 0 {
            $x-min = $x-mid;
        
        } else {
            return $x-mid;
        
        }
        $x-mid = ($x-max + $x-min) / 2;
        $f = f($x-mid);
    }

    return $x-mid;
}





sub investigate_param($p) {

    if 0 <= $p <= 1 {

        # The parameter is compound
        $x = $p;
        $eg = energy_gap($x);
        $wl = ev_nm_convert($eg);

    } elsif min($eg_AlN, $eg_GaN) <= $p <= max($eg_AlN, $eg_GaN) {

        # The parameter is energy gap
        $eg = $p;
        $wl = ev_nm_convert($eg);
        $x = calc_compound($eg);
        # $x = calc-compound-w-bisection($eg);

    } elsif min(ev_nm_convert($eg_AlN), ev_nm_convert($eg_GaN)) <= $p
            <= max(ev_nm_convert($eg_AlN), ev_nm_convert($eg_GaN)) {

        # The parameter is wavelength
        $wl = $p;
        $eg = ev_nm_convert($wl);
        $x = calc_compound($eg);
        # $x = calc-compound-w-bisection($eg);

    } else {
        say "Input '$p' cannot be recognized.";
        next;
    }

    printf "%.2f%10s%.3f %-8s%.2f %-7s\n", $x, "", $eg, "eV", $wl, "nm";
}


printf("%-14s%-14s%-14s\n", "Compound", "Energy gap", "Wavelength");

for @*ARGS -> $p { 
    if $p ~~ m/^\d+\.?\d*$/ {
        investigate_param($p);
    } elsif $p ~~ m/^(\d+.?\d*)\:(\d+.?\d*)\:(\d+.?\d*)$/ {
        my $min = min($0, $2);
        my $max = max($0, $2);
        my $step = $1;
        my $size = abs($max - $min) / $step;
        for 0..$size -> $z { investigate_param($min + $z*$step) }
    }
}

