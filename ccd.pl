#!/usr/bin/perl
#
# Evgeny Shevchenko
# version 0.2
# 20.03.2012
# shevchenko@beam.ioffe.ru
#

=pod

This script is written to process spectra data obtained on CCD camera. It takes txt
files from the specified directory and combines normilized spectra.

Usage:

    perl ccd.pl [DIRECTORY]

The directory must contain txt files named like

    "Someprefix NNNnm some NNNNsec NNNum NNmw thing else.txt"
    
that contain several columns of numeric data.  Only the fisrt and the last columns
are used as wavelength and intesity correspondingly.  Output file contains two
columns of quant energy in electronvolts and normalized intensity by time and slits
gap taken from file name.

This properties order is not strict.  Every part of the name divided by white spaces
from others that can't be interpreted as one of parameters (listed below) is used in
prefix.  The prefix from the example above will look like
"Someprefix_some_thing_else" and will be used as name of new .dat file with
normalized spectrum. Several parts of one spectrum sould have the same prefix in
order to be processed together in one output .dat file.

Note that prefix part "_1" in files "*_1.txt" is ignored as it's always used by
ASCII convertor of the program that is used for CCD camera control.

Note that spectrum parts joining is not ideal, and it's implemented not as good as
it should be.  Maybe some day...

Parameters:

    NNNnm   100-2000
            Middle dot of the wavelength range of current file (not used)

    NNNsec  1-99 or 0.00001-9.99999 
    NNNse   Time of spectrum registration, in seconds
    NNNsc
    NNNs

    NNNum   1-999
            Input monochromator slits gap, in microns

    NNmw    1-999
            Power of excitaion light (not used)

=cut


use warnings;
use strict;

# Going to input directory
chdir $ARGV[0] if (@ARGV && -d $ARGV[0]) ;

# Makin logfile in new directory
open LOG, ">ccd.log" or die "Cannot create logfile: $!\n";

# Selecting logfile desctriptor as default
my $oldoutput = select LOG;
print "Entered the directory ".`pwd`." succesfully\n" or die "Cannot write to logfile: $!\n";

# Properties
my @properties;
my $wavelength;
my $power;
my $slits;
my $time;
my $prefix = "";
my $oldprefix;

# Data holder
my @filelist;

# Counters
my $i = 0;
my $j = 0;


while ( defined(my $file = <*.txt>) ) 
{ 
    print "Processing file $file\n";
    # Cutting file extension and getting properties from the file name
    @properties = split( /\s+/, substr($file,0,-4) ); 

    # If some essential normalization parameters are not specified
    $time  = 1;
    $slits = 1;
    
    # Dividing spectra properties taken from the file name
    $oldprefix = $prefix;
    $prefix = "";
    
    foreach (@properties) 
    {
        if ( /\d{3,4}nm/i ) 
        {
            $_ =~ s/nm//i;
            $wavelength = $_ if ($_ <= 2000);
            print " | Wavelength is $wavelength nm\n";
        } 
        elsif ( /\d{1,3}mw/i ) 
        {
            $_ =~ s/mw//i;
            $power = $_;
            print " | Power is $power mW\n";
        }
        elsif ( /\d{1,3}um/i ) 
        {
            $_ =~ s/um//i;
            $slits = $_;
            print " | Slits gap $slits um\n";
        }
        elsif ( /((\d{1,2})|(\d(\.|_)\d{1,5}))se?c?/i ) 
        {
            $_ =~ s/se?c?//i;
            $_ =~ s/_/\./;
            $time = $_;
            print " | Time is $time sec\n";
        }
        else 
        {
            # Collecting garbage in file name to combine it as a unique prefix
            if ($prefix eq "")
            {
                $prefix = $_;
            }
            else
            {
                $prefix .= "_$_" if ($_ ne "_1");
            }
        }
    }
    # There can be different time and slit jaws width for differenct spectrum
    # parts. That's why the following string is commented
	# $prefix = join("_", ($prefix, $power.'mW', $slits.'um', $time.'sec'));
    print " | Prefix is $prefix \n";

    # Organizing data storage
    $i++   if ($prefix ne $oldprefix && $oldprefix ne "");
    $j = 0 if ($prefix ne $oldprefix);
    $filelist[$i]->[$j++] = {
        "prefix"    => $prefix, 
        "wavelength"=> $wavelength, 
        "power"     => $power, 
        "slits"     => $slits, 
        "time"      => $time,
        "file"      => $file,
        "data"      => [[],[]],
        "factor"    => 1
        }; 
}

# Making standard output default
select $oldoutput;

# Counters gonna be used again. That is weird coding style, I know.
$i = $j = 0;

# Variables for normalization of different spectrum parts
my $factor = 0;
my $sum = 0;

# Final string array for easy sorting and printing it to the .dat file
my @finalarr = ();

# For each spectrum...
foreach my $harr (@filelist)
{
    # ...and for each part of the spectrum...
    foreach my $hlink (@$harr)
    {
        # ...open the spectrum part file...
        open DATAFILE, $$hlink{"file"} || die "Cannot open data file: $!\n";
        while (<DATAFILE>) 
        {
            chomp;
            # ...read it to fill data array...
            ($$hlink{"data"}[0][$j], $$hlink{"data"}[1][$j]) = (split(/\s+/))[0,-1];
            # ...and normalize it!
            $$hlink{"data"}[1][$j] /= $$hlink{"slits"} * $$hlink{"time"};
            $j++;
        }
        $j = 0;
        close DATAFILE;
        # This counter is to control spectrum parts number
        $i++;
    }
    # If there are more than one part of spectrum...
    if ($i > 0)
    {
        # ...for every part of it (except the first one)...
        for (my $h = 1; $h < @$harr; $h++)
        {
            # ..for every data string of the previous part of spectrum...
            for (my $k = 0; $k < @{$$harr[$h-1]{"data"}[0]}; $k++)
            {
                # ...and for every data string of the other spectrum...
                for (my $m = 0; $m < @{$$harr[$h]{"data"}[0]}; $m++)
                {
                    # ...if there are equal wavelength dots...
                    if ($$harr[$h-1]{"data"}[0][$k] == $$harr[$h]{"data"}[0][$m])
                    {
                        # ...calculate their attitude that will become factor...
                        $factor += $$harr[$h-1]{"data"}[1][$k] / $$harr[$h]{"data"}[1][$m];
                        # ...and number of factors for further spectrum parts join coefficient...
                        $sum++;
                        print "Equal dots in " . $$harr[$h]{"prefix"} . "\tnum: " . $h .
                              "\tsum: "     . $sum . "\tfactor: " . $factor  . "\n";
                        print "\tdot number :" . $m .
                              "\twavelength: " . $$harr[$h-1]{"data"}[0][$k] .
                              "\tenergy: "     . 1239.842/$$harr[$h-1]{"data"}[0][$k] . "\n";
                        # ...and delete the same spectrum dots.
                        splice @{$$harr[$h]{"data"}[0]}, $m, 1;
                        splice @{$$harr[$h]{"data"}[1]}, $m, 1;
                    }
                }
            }
            # Recording the factor to current spectrum part
            $$harr[$h]{"factor"} = $factor / $sum if ($sum > 0);
            # Setting them to zero for further spectrum part usage
            $factor = $sum = 0;
        }
    }
    # Setting this counter to zero for next spectrum usage
    $i = 0;
    # Creating final .dat file descriptor for writing
    open OUTFILE, '>', $$harr[0]{"prefix"} . ".dat" or die "Cannot create data file: $!\n";
    # For each hash of the current spectrum
    foreach my $hlink (@$harr)
    {
        # ...and for each dot of that data...
        for (my $s=0; $s < @{$$hlink{"data"}[0]}; $s++)
        {
            # ...combine strings of electronvolts and normalize intence for writing.
            $finalarr[$s+$i] = 1239.5/$$hlink{"data"}[0][$s] .
                               "\t" . $$hlink{"data"}[1][$s] * $$hlink{"factor"} . "\n";
        }
        # This counter ensures that spectrum parts do not impose and rewrite each other
        $i += @{$$hlink{"data"}[0]};
    }
    print OUTFILE sort @finalarr;
    close OUTFILE;
    $i = 0;
    @finalarr = ();
}
