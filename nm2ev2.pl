#!/usr/bin/env perl
# Convert nanometres file to electron-volts file
# version 0.4.2 20141122
# Evgeny Shevchenko
# shevchenko@beam.ioffe.ru
# 2014

use Modern::Perl;
use Getopt::Long;
use File::Slurp;
use Math::Round::Var;
use List::Util      qw( max sum );
use List::MoreUtils qw( first_index );
# use Data::Dumper;


#-------------------------------------------------------------------------------
# Constant to convert nm to eV and in reverse production of Planck constant and
# speed of light divided by electron charge equals 1239.84193 nm*eV
use constant EVNM_FACTOR => 1239.84193; 

# Anything less that this is considered as electron-volt, anythin bigger is in
# nanometers
use constant EVNM_BORDER => 100; 

# Convert a number or an array of electron-volts to nanometers and vice versa
sub ev2nm {
  return (wantarray  ?  map { EVNM_FACTOR / $_ } @_  :  EVNM_FACTOR / $_[0]); 
}



#-------------------------------------------------------------------------------
# Comand line options

my $verbose      = '';
my $help         = '';

my $x_start		 = 0;
my $x_end		 = 0;

my $accuracy     = 6 ;
my $use_abs      = '';
my $improve_sign = ''; # ignores use_abs
my $remove_noise = '';
my $noise_data   = '';
my $collect_data = '';
my @extract_ple  = ();
my $noheaders    = '';
my $divider_file = '';
my $nm2ev        = '';
   
GetOptions (    
    'verbose|v'   => \$verbose,
    'abs'         => \$use_abs,
    'stat|s'      => \$collect_data,
    'posign'      => \$improve_sign,
    'noise'       => \$remove_noise,
    'noise-data=s'=> \$noise_data,
    'divby=s'     => \$divider_file,
    'acc=i'       => \$accuracy,
    'start=f'     => \$x_start,
    'end=f'       => \$x_end,
    'help|h'      => \$help,
    'no-headers'  => \$noheaders,
    'ple=f{1,}'   => \@extract_ple,
    'nm2ev'       => \$nm2ev,
) or die "Error in command line arguments\n";




#-------------------------------------------------------------------------------

sub usage {
    print "\n
\t-h, --help    show this message
\t-v, --verbose verbose command line output
\t--abs     take abs(Y) from data file
\t-s, --stat    generate additional file with some statistics
\t--posign      positive sign of the maximum value
\t--noise   calculate and extract noise
\t--noise-data  NOT IMPLEMENTED
\t--nm2ev   generate file with converted X from nanometers to elevtron-volts
\t
\t--acc=integer accuracy N in terms of degree of 10^-N
\t--start=float start from X
\t--end=ffloat  end with X
\t
\t--ple     if current data is PL at various excitation, 
\t      a PLE spectra can be ectracted according to 
\t      excitation in the files names. The detection 
    lines must be divided by spaces
\t--no-headers  do not add headers into output data files
";
}

if ($help) {
    usage();
    exit(0);
}


#-------------------------------------------------------------------------------
# Numbers rounder
my $rnd = Math::Round::Var->new(10**(-$accuracy));



#-------------------------------------------------------------------------------
# Correct floats or say shats not appropriate numeric data point
sub correct_line {
    my $oldline = shift;
    my $status = '';
    my $line = $oldline;

    if ($line =~ /[a-df-zA-DF-Z:]/) {
      $status = 1;
      return ($oldline, $status);
    }

    $line =~ s#,#\.#g;  # Replace decimal comma with decimal point
    $line =~ s#^\s+##;  # Trimming (useless, I guess)
    $line =~ s#\s+$##;  # Trimming (...)

    return ($line, $status);
}






#-------------------------------------------------------------------------------
# Y(X) => -Y(X)
sub reverse_sign {
    my $href = shift;
    # FIXME map rather than foreach?
    foreach my $k (keys %$href) { $href->{$k} *= -1; }
    
}



#-------------------------------------------------------------------------------
# Extract temperature value from a filename
sub extract_temp {
    my $fname = shift;
    my $temp;
    if ($fname =~ /(\d{1,3}([,_]\d+)?)K/) {
        $temp = $1;
        $temp =~ s/[,_]/\./;
        return $temp;
    }
    return 0;
}


#-------------------------------------------------------------------------------
# Functions to ensure correct value unit — eV or nm
sub ensure_ev {
  return map { EVNM_FACTOR / $_ if $_ > EVNM_BORDER } @_ if wantarray;
  my $nrg = shift;
  return EVNM_FACTOR / $nrg if $nrg > EVNM_BORDER;
  return $nrg;
}

sub ensure_nm {
  return map { EVNM_FACTOR / $_ if $_ < EVNM_BORDER } @_ if wantarray;
  my $wl = shift;
  return EVNM_FACTOR / $wl if $wl < EVNM_BORDER;
  return $wl;
}

#-------------------------------------------------------------------------------
# Calculate noise level by counting maximum in points distribution
sub calc_noise {
    my $href = shift;

    my %counts;
    foreach my $key (keys %$href) {
        # Count values with desired accuracy
        $counts{ $rnd->round($href->{$key}) }++ ;
    }

    my @val_range   = sort {$a <=> $b} keys %counts;
    my $count_max   = max( values %counts );          # This is near noise
    my $val_min     = $val_range[0];                  # Bottom
    my $noise_width = $val_range[-1] - $val_range[0]; # Maximum guarantee
    my $noise_center;
    my @noise_range;

    foreach my $v (@val_range) {
        if ( $counts{$v} == $count_max ) {
            $noise_center = $v; 
            $noise_width = 2 * ($noise_center - $val_min);
        }
        last if ($v > $noise_width + $val_min);
        push @noise_range, $v;
    }

    # Arithmetic mean 
    my $noise = 0;
    $noise = eval { sum (map {$_ * $counts{$_}}  @noise_range) / 
                    sum (map {     $counts{$_}}  @noise_range) };
    if ( $@ ){
        say "Cannot calculate noise due to error: \n\t$@";
        $noise = 0;
    } 
    
    return $noise;
}








#-------------------------------------------------------------------------------
# 
# TODO rename to max_min
# TODO merge the sign improvement code with the main loop in the code
sub improve_peak_sign {
    my $href  = shift; # hash ref
    my $fname = shift; # file name

    my @sorted = sort { $$a[1] <=> $$b[1] } 
                 map  { [$_, $href->{$_}] } 
                 keys %$href;

    my ( $minval, $maxval ) = ( $sorted[0]->[1], $sorted[-1]->[1] );
    my $maxvalpos = $sorted[-1]->[0];

    my $should_improve_sign = ( abs($maxval) < abs($minval) );

    if ($improve_sign and $should_improve_sign) {
      # The spectrum is reversed
      reverse_sign( $href );
      ($maxval, $minval) = (-$minval, -$maxval);
      $maxvalpos = $sorted[0]->[0];

    } elsif ( !$improve_sign and $should_improve_sign ) {
      say "$fname: Inverted spectrum detected. You may want to use --posign option.";
    }

    

    if ( $use_abs ) { # The abs option is called 
      if ($improve_sign) { # The abs option is ignored
        say "$fname: warning: --posign option overrides --abs";
      } else {
        $href->{$_} =  abs $href->{$_} foreach  (keys %$href) ;
      }
    }
    return ($maxval, $maxvalpos);
}


#-------------------------------------------------------------------------------
# Integrate a function Y(X), X and Y being taken from hash keys and their
# corresponding values respectively

sub integ_trapz {
    my $data_href = shift; 
    my @x = sort (keys %$data_href);
    my $area = 0;

    for (my $i = 0; $i < (scalar @x) - 1; ++$i) {
        
        my $x1 = $x[ $i ];
        my $x2 = $x[$i+1];
        my $y1 = $data_href->{ $x[ $i ] };
        my $y2 = $data_href->{ $x[$i+1] };

        my $dx = $x2 - $x1; # $dx > 0 always
        my $dy = $y2 - $y1;

        if    ($y1 == 0) { $area += $y2 * $dx * 0.5; } 
        elsif ($y2 == 0) { $area += $y1 * $dx * 0.5; } 
        elsif ($y1 * $y2 < 0) {

            # $y1 and $y2 are both non-zero
            my $dx1 = $dx / (1 + abs ($y2 / $y1)); 
            my $dx2 = $dx - $dx1;
            $area += 0.5 * ($dx1 * $y1 + $dx2 * $y2);

        } else  { 
            # $y1 * $y2 > 0
            $area += ($y1 + 0.5 * $dy) * $dx; 
        }
    }
    return $area;
}





#-------------------------------------------------------------------------------
# Calculate full width at half maximum (FWHM), its position and area of the
# spectrum
sub peak_info {
    my $href      = shift;
    my $maxvalpos = shift;
    my $maxval    = $href->{$maxvalpos};
    my $fwhm;
    my $fwhmpos;

    my $area = integ_trapz $href;
    
    my @x_sorted = sort { $a <=> $b } keys %$href;
    my $i = 0;
    while ($x_sorted[$i] != $maxvalpos) { $i++; }
    # my $halfsize = (scalar @x_sorted) / 2;
    
    my ($y_left, $left_pos, $y_right, $right_pos) = ($maxval, $i, $maxval, $i);
    my ($x_left, $x_right);

    while ( $y_left > $maxval / 2) {
        if ( $left_pos == 0 ) {
            $x_left = $x_sorted[ 0 ];
            last;
        }
        $x_left = $x_sorted[--$left_pos];
        $y_left = $href->{$x_left};
    }
    while ( $y_right > $maxval / 2) {
        if ( $right_pos == scalar( @x_sorted ) - 1 ) {
            $x_left = $x_sorted[ $right_pos ];
            last;
        }
        $x_right = $x_sorted[++$right_pos];
        $y_right = $href->{$x_right};
    }

    $fwhm = $x_right - $x_left;
    $fwhmpos = 0.5 * ($x_right + $x_left);


    return ($fwhm, $fwhmpos, $area);
}



#-------------------------------------------------------------------------------
# Divide one array by another

sub arr_div {
  my $data_aref = shift;
  my $divider_aref = shift;
  
}



#-------------------------------------------------------------------------------
# Fill detecting lines position for the PLE extraction

my %ple_data;
my @ple_detect_line_x;

if ( @extract_ple ) {
  # Decide whether it's eV or nm. 
  # If it's nm, convert it to eV, because now X in the processed spectra 
  # is already in eV
  for my $ple_detect_line_x ( @extract_ple ) {
    $ple_detect_line_x = ev2nm( $ple_detect_line_x ) if $ple_detect_line_x > EVNM_BORDER;
    $ple_data{ $rnd->round( $ple_detect_line_x ) } = { 'x' => [], 'y' => [] };
  }
  # say Dumper %ple_data;
}


#-------------------------------------------------------------------------------
# Exit if no input files passed
if (scalar @ARGV == 0) {
    say "No input files. Exiting." if $verbose;
    exit(0);
}



#-------------------------------------------------------------------------------
# Main loop

my %stats       = ();
my %outdata     = ();
my %filestats   = ();


foreach my $file (@ARGV) {

    print "Processing file $file\n" if $verbose;

    %outdata   = ();
    %filestats = ();

    my $data = read_file($file, array_ref => 1);
    # FIXME WTF?? Just a dot anywhere in a filename??
    # my ($file_ev, $file_ext) = (split(/\./, $file))[0, -1];
    my ($file_ev, $file_ext) = ( $file, '' );
    
    
    # data.dat will become ev-data.dat ???
    # FIXME BUG assume file path passed (/path/to/files/*txt) than we'll have 
    # ev-/path/to/files/*txt 
    # my $outfile = "ev-" . $file_ev . '.' . $file_ext;
    my $outfile = "ev-" . $file_ev ;

    # local $/ = "\n";
    write_file( $outfile, 
      join( "\n", ("Energy\t$file_ev", "eV\tarb. units", "")) ) 
        unless $noheaders;
    
    # Populating %outdata
    foreach my $line (@$data) {
    
        next unless $line =~ /\d\s+[-+]?\d/;
        my ($line, $not_xy) = correct_line $line;
        next if $not_xy; # Make sure it's numeric data

        my ($x, $y) = (split(/\s+/, $line))[0, -1];
        
        # Make sure we are in the desired range of X
        next if ( $x_start and ensure_nm( $x ) < ensure_nm( $x_start )); 
        next if ( $x_end   and ensure_nm( $x ) > ensure_nm( $x_end   ));
        # say "Passed x is $x";

        # ARBITRARY FUNCTION
        # here nm's to eV's are converted (X1 -> X2)
        $x = ev2nm( $x ) if $nm2ev;

        # FIXME show exact data if the warning appears
        warn "$file: Replacing existing value in data: FIXME" if defined $outdata{ $x };
        $outdata{ $x } = $y;
    }

    # TODO rename improve_peak_sign to max_min, bring the sign improvment code here
    my ( $maxval, $maxvalpos ) = improve_peak_sign( \%outdata, $file );

    my $noise;
    if ( $remove_noise ) {
        $noise = calc_noise( \%outdata );
        $outdata{$_} -= $noise for ( keys %outdata );
        # foreach my $k ( keys %outdata ) {
        #       $outdata{$k} -= $noise; 
        # }
        write_file( $outfile, { append => 1 }, "Noise: $noise\n" ) unless $noheaders;
        say "Noise: $noise" if $verbose;
    }




    # TODO collect area
    # ( $maxval, $maxvalpos, $fwhm, $fwhmpos, $area );
    my ( $fwhm, $fwhmpos, $area );
    if ( $collect_data ) {
        my %filestats = ();

        # The noise could already be calculated due to --noise flag
        $noise = calc_noise( \%outdata ) unless $noise; 
        
        ( $fwhm, $fwhmpos, $area ) = peak_info( \%outdata, $maxvalpos );

        $filestats{noise}   = $noise             ;
        $filestats{fwhm}    = $fwhm              ;
        $filestats{fwhmpos} = $fwhmpos           ;
        $filestats{max}     = $maxval            ;
        $filestats{maxpos}  = $maxvalpos         ;
        $filestats{area}    = $area              ;
        $filestats{temp}    = extract_temp $file ;

        # print "Noise: "     . $rnd->round($filestats{noise}  )    .     "\n";
        # print "FWHM: "      . $rnd->round($filestats{fwhm}   )    . " eV \n";
        # print "FWHM position: " . $rnd->round($filestats{fwhmpos})    . " eV \n";
        # print "$filestats{area}      \n";

        if ( $nm2ev and !$noheaders) {
          write_file( $outfile, {append => 1}, 
              ("Noise: "              . $rnd->round($filestats{noise})  .     "\n",
               "FWHM: "               . $rnd->round($filestats{fwhm})   . " eV \n",
               "FWHM position: "      . $rnd->round($filestats{fwhmpos}). " eV \n" ,
               "Maximum: "            . $rnd->round($filestats{max}   ) .     "\n" ,
               "Maximum position: "   . $rnd->round($filestats{maxpos}) . " eV \n" ,
               "Area: "               . $rnd->round($filestats{area}  ) .     "\n" ,
               "Temperature: "        . $rnd->round($filestats{temp}  ) .  " K \n" ,
              )
          );
        }

        # Store the file statistics
        $stats{$file} = \%filestats;
    }



    # Output
    write_file( $outfile, { append => 1 }, 
          map  { sprintf("%.". $accuracy ."f\t%.". $accuracy ."f\n",   $_,   $outdata{$_}) } 
          sort { $a <=> $b } keys %outdata ) if $nm2ev;


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if ( @extract_ple ) {

      my $cntr = 1;

      for my $ple_detect_line_x ( keys %ple_data ) {

        my $ple_exc_line_x = $cntr;

        # PLE excitation line in filename is wavelength in nm
        # say "FILE NAME TO PARSE: " . $file_ev;
        if ( $file_ev =~ /(\d*([_,\.]\d{1,2})?)nm/ ) {
          $ple_exc_line_x = $1;
          $ple_exc_line_x =~ s/[_,]/\./;
        } else { 
          warn 'No PLE excitation value detected, using a counter.'; 
        }
        # 
        next if (ensure_ev($ple_exc_line_x) < ensure_ev($ple_detect_line_x));
        $cntr++;

        my @sorted_x = sort { $a <=> $b } ( keys %outdata );
        my $ple_pos  = first_index { $_ > $ple_detect_line_x } @sorted_x;
        my $ple_y    = $outdata{ $sorted_x[$ple_pos] };

        push @{ $ple_data{ $ple_detect_line_x }{ x } }, ev2nm( $ple_exc_line_x );
        push @{ $ple_data{ $ple_detect_line_x }{ y } }, $ple_y;

        # say '-' x 50;
        # say Dumper %ple_data;

      }
    }
}


#-------------------------------------------------------------------------------
# Write PLE to files
if ( @extract_ple ) {
# if ( $extract_ple ) {
  
  # say '-' x 80;
  # say Dumper %ple_data;

  # For detection line position in electron-volts
  for my $det_ev ( keys %ple_data ) {

    my $href   = $ple_data{ $det_ev };
    my $det_nm = ev2nm( $det_ev );

    # my $samplename = (split( '_', $file_ev ))[0];
    # my $ple_fname = sprintf( $samplename . "_PLE__%.2feV_%.2fnm.txt", $det_ev, $det_nm );
    my $ple_fname = sprintf( "PLE__%.3feV_%.1fnm.txt", $det_ev, $det_nm );

    # PLE headers
    write_file( $ple_fname, 
      join( "\n", ("Energy\t".$ple_fname, "eV\tarb. units", "")) ) 
        unless $noheaders;
    # PLE data
    write_file( $ple_fname, {append => 1},
      sort { 
        my @a = split(/\s/, $a); 
        my @b = split(/\s/, $b); 
        $a[0] <=> $b[0] } 
      map  { 
        sprintf("%.". $accuracy ."f\t%.". $accuracy ."f\n",  
          $$href{x}[$_], $$href{y}[$_]) } 
      reverse 0...@{$$href{x}}-1 );
      
      
  }
}


#-------------------------------------------------------------------------------

if ( $collect_data ) {

  # FIXME UNIX-like OS only. We need a date module here
  chomp(my $date = `date +%Y%m%d_%H%M%S`); 

  my $stats_file = 'stats_' . $date . '.txt';

  # Filling headers 
  write_file( $stats_file, {append => 1},
     "Filename\t" .
     "Temperature\t" .
     "Noise\t" .
     "FWHM\t" .
     "FWHM position\t" .
     "Area\t" .
     "Max\t" .
     "Max position\n" 
  );

  foreach my $fname ( sort { extract_temp($a) <=> extract_temp($b) } keys %stats ) {

    write_file( $stats_file, {append => 1},
      # FIXME Y U NO ITERATING OVER THE STATS?
      sprintf( "%s\t%s\t%"
      . $accuracy . "f\t%" 
      . $accuracy . "f\t%"
      . $accuracy . "f\t%" 
      . $accuracy . "f\t%"
      . $accuracy . "f\t%" 
      . $accuracy . "f\n",

      $fname                   ,
      $stats{$fname}->{temp}   , 
      $stats{$fname}->{noise}  , 
      $stats{$fname}->{fwhm}   ,
      $stats{$fname}->{fwhmpos}, 
      $stats{$fname}->{area}   ,
      $stats{$fname}->{max}    , 
      $stats{$fname}->{maxpos} ) 
    );

          
  }
}


