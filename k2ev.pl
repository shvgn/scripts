#!/usr/bin/env perl
# Convert wave vector in (1e3 cm^-1) file to electron-volts file

use strict;
use warnings;

my $KRCM2EV = 0.123984193;

my $line;
my %data;
# my $re_num = /\d\s+\d/;

foreach my $file (@ARGV) {

	open FILE, "<", $file or die "Cannot open the file: $!";

	my ($file_ev, $file_ext) = (split(/\./, $file))[0, -1];
	
	open WRITEFILE, ">", $file_ev . "-ev.$file_ext";

	print WRITEFILE "Energy\t$file_ev\n";
	print WRITEFILE "eV\tarb. units\n";
	print WRITEFILE "\n";

	$line = '';

	until ($line =~ /\d\s+\d/) {
		$line = <FILE>;
	}

	$line =~ s/,/\./g;

	my ($x_start, $y_start) = (split(/\s+/, $line))[0, -1];


	while($line = <FILE>) {

		next unless $line =~ /\d\s+\d/;
		my ($x, $y) = split(/\s+/, $line);

		$x =~ s/,/\./;
		$y =~ s/,/\./;

		$data{$x} = $y;

		# printf WRITEFILE "%.4f\t%.4f\n", 1239.842/$x, $y - $y_start;

	}
	
	# Better use {$b <=> $a} instead of 'reverse'?
	for my $key (reverse sort (keys %data)) { 
		# printf "%.4f\t%.4f\n", $key, $data{$key} - $y_start;
		printf WRITEFILE "%.6f\t%.6f\n", $KRCM2EV*$key, $data{$key} - $y_start;
	}

	%data = ();

	close FILE;
	close WRITEFILE;
}
