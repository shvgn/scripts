#!/usr/bin/env perl
#
# Evgeny Shevchenko
# 2012
# shevchenko@beam.ioffe.ru

use Modern::Perl 2011;  
use autodie;            
use utf8;
use Cwd 'abs_path';
use File::Basename;

sub processDataFile;
sub parseInfo;
sub originInfoLines;

my $EV2NM = 1239.84193;


# Main loop
foreach my $filename (@ARGV) { 
	if (not -f $filename) {
		say "Warning! $filename is not a file, skipping...";
		next;
	}
	processDataFile( $filename ) ;
	say ''; # Empty line between files information output blocks
}






sub processDataFile {
	my $filename = shift;

	my ($fileDataString, $dataref) = originInfoLines($filename);
	my %data = %$dataref;
	# say $filedatastring;

	my $outfile = $data{name} if $data{name};
	$outfile .= '_' . $data{date}               if $data{date};
	$outfile .= '_' . $data{temperature} . 'K'  if $data{temperature};
	$outfile .= '_' . $data{slits}       . 'um' if $data{slits};
	$outfile .= '_' . $data{power}       . 'mW' if $data{power};
	$outfile .= '_' . $data{delay}       . 's'  if $data{delay};
	$outfile .= '_' . $data{excitation_wavelength} . 'nm' if $data{excitation_wavelength};
	$outfile .= '_' . $data{middle_wavelength}     . 'nm' if $data{middle_wavelength};
	$outfile .= '.dat';

	say ">> Output file: " . $outfile;

	my ($infh, $outfh); # File handlers
	open $infh,  '<', $filename;   # Using autodie ;)
	open $outfh, '>', $outfile;

	my $oldhandle = select $outfh;
	say $fileDataString;
	
	while (<$infh>) {
		next if /^\s*$/;
		my ($wavelength, $intensity) = ( split )[0, -1];
		say $EV2NM/$wavelength . "\t" . $intensity;
	}
	select $oldhandle;

	close $infh;
	close $outfh;
}






# Returns three strings of variable name, units and comments for origin
sub originInfoLines {
	
	my $context = wantarray();

	my $filename = shift;
	my %data = parseInfo( $filename );
	
	if ($data{name} eq '') {
		my $dirname = basename(dirname(Cwd::abs_path($filename)));
		($data{name}) = $dirname =~ /(^[a-z]\d{3})/;
		say "!! Specimen name taken from the directory name: " . $data{name};
	}

	my $str = "Energy\tIntensity\n" .  "eV\tarb. units\n" ; 
	$str .= "Excitation " . $data{excitation_wavelength} . " nm" if $data{excitation_wavelength};
	$str .= "\t";
	$str .= $data{name} if $data{name};
	$str .= ", " . $data{temperature} . " K" if $data{temperature};
	$str .= ", " . $data{delay}  .  " sec"   if $data{delay};
	$str .= ", " . $data{slits}  .  " um"    if $data{slits};
	$str .= ", " . $data{power}  .  " mW"    if $data{power};
	$str =~ #  # #g;
	$str =~ # ,#,#g;
	return $str unless $context;
	return ($str, \%data) if $context;
}






# A sub to parse spectra info from the filename
sub parseInfo {

	my $filename = shift; # e.g. c676_5i0K_20mkm_20120608_325nm_370nm_120s_1.txt
	$filename =~ s/_1\./\./; # Cutting "_1"

	my @properties = split( /[\s_-]+/, substr($filename,0,-4) ); 

	# Initializing data hash
	my %data = (
		name                    => '',
		middle_wavelength       => 0,
		excitation_wavelength   => 0,
		temperature             => 0,
		power                   => 0,
		slits                   => 0,
		delay                   => 0,
		date                    => 0
		);

	
	my $outprefix = " * "; # Output eye-candy

	foreach (@properties) {
		if ( /\d{3,4}nm/i ) { # Wavelength, nanometers

			s/nm//i;

			if ( $data{excitation_wavelength} == 0 ) { 
				$data{excitation_wavelength} = $_; 
				
			} elsif ( $data{excitation_wavelength} > $_) {
				$data{middle_wavelength} = $data{excitation_wavelength};
				$data{excitation_wavelength} = $_;

			} else { 
				$data{middle_wavelength} = $_; 
			}

		} elsif ( /\d{1,3}mW/i ) { # Power, miliwatts
			s/mw//i;
			$data{power} = $_;

		} elsif ( /\d{1,3}(u|mk)m/i ) { # Slit gap, microns (um)
			s/(u|mk)m//i;
			$data{slits} = $_;

		} elsif ( /((\d{1,3})|(\d(\.|_)\d{1,5}))se?c?/i ) { # Delay, seconds
			s/se?c?//i;
			s/_/\./;
			$data{delay} = $_;

		} elsif ( /((\d{1,2})|(\d(\.|_)\d{1,5}))K/i ) { # Temperature, kelvins
			s/i/\./i;
			s/k//i;
			$data{temperature} = $_;

		} elsif ( /[a-z](\d-)?\d{3}/i ) { # Specimen name
			$data{name} = $_;

		} elsif ( /^\d{4,8}$/) { # Date if spectra measurements
			$data{date} = $_;
		}
	}

	say $outprefix . "Specimen name: " . $data{name};
	say $outprefix . "Temperature: " . $data{temperature} . " K";
	say $outprefix . "Slits gap: " .$data{slits} . " um";
	say $outprefix . "Delay: " . $data{delay} . " sec";
	say $outprefix . "Power: " . $data{power} . " mW";
	say $outprefix . "Excitation wavelength: " . $data{excitation_wavelength} . " nm" ;
	say $outprefix . "Middle wavelength: " . $data{middle_wavelength} . " nm" ;
	say $outprefix . "Date: " . $data{date};

	return %data;
}
