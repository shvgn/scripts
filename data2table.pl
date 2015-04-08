#!/usr/bin/env perl
# Looks ok with 8-spaces-long tabs 

use strict;
use warnings;
use feature qw(say);
use Getopt::Long;
use File::Slurp qw(read_file write_file);
# use Data::Dumper;

# data2table file1 file2 file3 --runouts


# ------------------------------------------------------------------------
my $runouts = '';   # options variables with default values (false)
my $verbose = '';   
my $mean    = '';      
my $sample  = '';    
my $mul     = '';    

GetOptions (	'verbose' 	=> \$verbose, 
		'runouts' 	=> \$runouts, 
		'mean' 		=> \$mean,
		'mul=f'        	=> \$mul,
		'sample=s' 	=> \$sample, 
);


# ------------------------------------------------------------------------ #
# This sub takes reference to a data hash and sring containig a data file,
# consisting of two columns of numbers. The sub checks # for lines with two
# numbers, creates an entry in hash tied with $x and adds $y's from processed
# files to an array, pointed by # the $x. Control of tabular form is implemented
# with $empty entries and 'records' key of the original data hash.

my $empty = '-';

sub add_data {

	my ($dref, $fstr) = @_;
	my ($x, $y);
	my $current_records;

	for my $line (split("\n", $fstr)) {
		
		next unless ( $line =~ /^\s*(\d+\.?\d*)\s+(\d+\.?\d*)/ );
		($x, $y) = ($1, $2);
		$dref->{data}{$x} = [] if (! $dref->{data}{$x});

		$current_records = scalar @{$dref->{data}{$x}};
		say "Current records: $current_records, ";
		$dref->{data}{$x} = [	@{$dref->{data}{$x}}, 
					($empty) x ($dref->{records}-$current_records) ] 
						if ( $current_records < $dref->{records}-1 ) ;
		$dref->{data}{$x} = [@{$dref->{data}{$x}}, $y];
		$dref->{records}++ if (scalar @{$dref->{data}{$x}}) > $dref->{records};
		# FIXME bug with multiple files : creates additional columns
		# Debug
		# say $x . "\t". join("\t", @{$dref->{data}{$x}}) . "\t\t" . $dref->{'records'};
	}
}




# ------------------------------------------------------------------------
# Arithmetic mean. 
# FIXME doesn't exlude runouts
sub mean {
	my $arref = shift;
	my $sum = 0;
	my $faults = 0;
	foreach (@$arref) {
		if ($_ eq $empty) {
			$faults++;
			next;
		}
		$sum += $_;
	}
	return $sum / (scalar (@$arref) - $faults);
}



# ------------------------------------------------------------------------

$sample = "data2table_output" if !$sample;
my $extension = "dat";
say "Ouput file is $sample.$extension" if $verbose;

say "Runouts will run out when implemented" if $verbose and $runouts ;
say "Mean is gonna be calculated"	    if $verbose and $mean ;

# ------------------------------------------------------------------------


my %wholedata = (
	records => 0,
	data	=> {} ,
);

my $file_unavailable = '';

foreach my $file (@ARGV) {
	
	$file_unavailable =  !(-e $file and -r $file);
	say "Skipping file $file: not readable or doesn't exist" if ($file_unavailable);
	next if $file_unavailable ;
	
	my $filedata = read_file($file);
	add_data(\%wholedata, $filedata);
	
}

my %data = %{$wholedata{'data'}};
# say Dumper %data;
foreach my $x (sort keys %data) {
	say $x ."\t". join("\t", @{$data{$x}}) . "\t" . mean($data{$x});
}
__END__
