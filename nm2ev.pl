#!/usr/bin/env perl
# Convert nanometres file to electron-volts file
# 

use strict;
use warnings;
use Getopt::Long;

# ------------------------------------
# Constant to convert nm to eV and in reverse nm*eV = 1239.84193
my $ev2nm = 1239.84193; 
# ------------------------------------
my $line;
my %data;

# TODO in fact the data must be multiplied on sign of the data maximum. It
# improves sign of the data for signal and doesn't make sence for just noisy
# record. Posign is here for the purpose. 

# TODO collectdata is to collect specra statistics such as filename vs max
# value and max photon energy

# TODO remove noise is to calculate noise added to the signal and exract it
my $use_abs = '';
my $improve_sign = ''; # ignores use_abs
my $collect_data = '';
my $remove_noise = '';
GetOptions (	
	'abs' 	 => \$use_abs,
	'stat|s' => \$collect_data,
	'posign' => \$improve_sign,
	'noise'  => \$remove_noise
	);


sub correct_line {
	my $line = shift;
	$line =~ s/,/\./g;
	
	$line =~ s/^\s+//; # Trimming
	$line =~ s/\s+$//; 

	return $line;
}

foreach my $file (@ARGV) {

	open FILE, "<", $file or die "Cannot open the file: $!";

	my ($file_ev, $file_ext) = (split(/\./, $file))[0, -1];
	
	# data.dat will become ev-data.dat
	open WRITEFILE, ">", "ev-" . $file_ev . '.' . $file_ext;
	print WRITEFILE "Energy\t$file_ev\n";
	print WRITEFILE "eV\tarb. units\n";
	print WRITEFILE "\n";

	$line = '';


	until ($line =~ /\d\s+\d/) {
		$line = <FILE>;
	}

	if ($line =~ /^["#]/) {
		print $line . "\n";
		next;
	}

	$line = correct_line $line;

	my ($x_start, $y_start) = (split(/\s+/, $line))[0, -1];
	# print "X start: " . $x_start . "\t";
	# print "Y start: " . $y_start . "\n";


	while($line = <FILE>) {
		next unless $line =~ /\d\s+[-+]?\d/; 
		$line = correct_line $line;

		my ($x, $y) = (split(/\s+/, $line))[0, -1];

		$y = abs($y) if $use_abs;

		$data{$x} = $y;

		# printf WRITEFILE "%.4f\t%.4f\n", 1239.842/$x, $y - $y_start;

	}
	
	# for my $key (reverse sort (keys %data)) {
	for my $key (sort  {$b <=> $a} (keys %data)) {
		# printf "%.4f\t%.4f\n", $key, $data{$key} - $y_start;
		# printf WRITEFILE "%.6f\t%.6f\n", $ev2nm/$key, $data{$key} - $y_start;
		printf WRITEFILE "%.6f\t%.6f\n", $ev2nm/$key, $data{$key};
	}

	%data = ();

	close FILE;
	close WRITEFILE;
}
