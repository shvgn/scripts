#!/usr/bin/env perl

use Modern::Perl;
use Data::Table qw( fromFile );
use Data::Dumper;
# use Math::Derivative qw( Derivative1 );
use List::Util qw( sum max min first);
use Math::GSL::Interp qw( :all );
use syntax qw( junction );

#------------------------------------------------------------------------------
# point_deriv( $x1, $x2, $y1, $y2 )
# Derivative between two points ($x1, $y1) and ($x2, $y2)
sub point_deriv {
    my ($x1, $x2, $y1, $y2,) = @_;
    ($y2 - $y1) / ($x2 - $x1);
}


# deriv( \@x, \@y )
# This sub calculates left-sided derivative of arrayref $y over arrayref $x. 
# It returns numeric derivative array \@dydz in points between $x->[$i] and $x->[$i+1]
sub deriv {
    my ($x, $y,) = @_;
    
    (scalar( @$x ) != scalar( @$y )) 
        and die("X and Y must have the same lengths in 'deriv' sub\n") ;
    
    my @dydz = ();
    for (my $i = 0; $i < scalar( @$x )-1; $i++ ) {
        push @dydz, point_deriv($x->[$i], $x->[$i+1], $y->[$i], $y->[$i+1]);
    }
    return \@dydz;
}

#------------------------------------------------------------------------------
# Apply ane arithmetic element-wise operation to two arrays passed by their refs
sub ary_operation {
    my $opsign = shift;
    my ( $a, $b ) = @_;
    
    (scalar( @$a ) != scalar( @$b )) 
        and die "Arrays must have the same length for element-wise operations\n";
    
    my @result = ();
    for (my $i = 0; $i < scalar( @$a ); $i++) {
        push @result, eval "$a->[$i] $opsign $b->[$i]";
    }
    
    return \@result;
}


sub ary_add {
    ary_operation( "+", $_[0], $_[1]);
}


sub ary_subtract {
    ary_operation( "-", $_[0], $_[1]);
}


sub ary_multiply {
    ary_operation( "*", $_[0], $_[1]);
}


sub ary_divide {
    ary_operation( "/", $_[0], $_[1]);
}

#------------------------------------------------------------------------------


exit(0) if (@ARGV == 0);
my $file_noise    = shift @ARGV;
my $file_spectrum = shift @ARGV;


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# my $spectrum = Data::Table::fromTSV( $file_spectrum );
# From PL spectrum file
# $VAR1 = bless( {  'colHash' => { 
#                                   '-6.05'   => 1, 
#                                   '206.535' => 0 
#                                }, 
#                   'type'    => 0, 
#                   'OK'      => [], 
#                   'MATCH'   => [], 
#                   'header'  => [ '206.535', '-6.05' ], 
#                   'data'    => [ 
#                                   [ '206.731', '-1.93' ], 
#                                   [ '206.928', '0.13' ], 
#                                   [ '207.124', '0.13' ], ...
#                                ], 
#                   'Data::Table' )



# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Collecting the data

my $spectrum = Data::Table::fromFile( $file_spectrum ); 
my $noise    = Data::Table::fromFile( $file_noise );  

my $spectrum_x = [ map { $_->[0] } @{ $spectrum->{data} } ];
my $spectrum_y = [ map { $_->[1] } @{ $spectrum->{data} } ];
my $noise_y    = [ map { $_->[1] } @{ $noise->{data}    } ];





# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# First derivatives

my $spec_dx   = deriv( $spectrum_x, $spectrum_y );
my $noise_dx  = deriv( $spectrum_x, $noise_y );

my $spec_last = pop @$spectrum_x;
my $spec_dx_t  = new Data::Table([ $spectrum_x, $spec_dx  ], ['X', 'Y'], 
    Data::Table::COL_BASED);
my $noise_dx_t = new Data::Table([ $spectrum_x, $noise_dx ], ['X', 'Y'], 
    Data::Table::COL_BASED);

my $fspec  = $file_spectrum . '-dx';
my $fnoise = $file_noise    . '-dx';

$spec_dx_t->tsv(0,  { file => $fspec  });
$noise_dx_t->tsv(0, { file => $fnoise });





# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Second derivatives

my $spec_dx2   = deriv( $spectrum_x, $spec_dx );
my $noise_dx2  = deriv( $spectrum_x, $noise_dx );

my $spec_prelast = pop @$spectrum_x;
my $spec_dx2_t  = new Data::Table([ $spectrum_x, $spec_dx2  ], ['X', 'Y'], 
    Data::Table::COL_BASED);
my $noise_dx2_t = new Data::Table([ $spectrum_x, $noise_dx2 ], ['X', 'Y'], 
    Data::Table::COL_BASED);

$fspec  = $fspec  . '-dx';
$fnoise = $fnoise . '-dx';

$spec_dx2_t->tsv(0,  { file => $fspec  });
$noise_dx2_t->tsv(0, { file => $fnoise });






# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
my @spectrum_y_improved = @$spectrum_y;
push @$spectrum_x, $spec_prelast, $spec_last;

# my $deriv2_limit = 7e6; # For signal
my $deriv2_limit = 9e6; # For noise, c821_R14 and c821_R21
my $deriv2_limit = 1e7; # For noise, c785

my ( $field_start, $field_end ) = ( undef, undef );
my $interp_half_field = 7;

# Choosing interpolation type in a separate var
# my $interp_type = $gsl_interp_linear;
# my $interp_type = $gsl_interp_polynomial;
# my $interp_type = $gsl_interp_cspline;
my $interp_type = $gsl_interp_akima;


# for my $index ( 0..(scalar( @$spec_dx2 ) - 1) ) {

my $index = 0;
while ( $index < scalar( @$spec_dx2 ) - 1 ) {

    $field_start = $index  if abs($spec_dx2->[$index]) >= $deriv2_limit and !defined( $field_start );
    # $field_start = $index  if abs($noise_dx2->[$index]) >= $deriv2_limit and !defined( $field_start );
    $index++;

    # if ( abs($spec_dx2->[$index]) < $deriv2_limit and defined( $field_start ) ) {
    if ( abs($noise_dx2->[$index]) < $deriv2_limit and defined( $field_start ) ) {
        
        # $field_end = $field_start;
        $field_end = $index;

        # say "Interpolating between " . $spectrum_x->[ $field_start ] 
        #                    . ' and ' . $spectrum_x->[ $field_end   ] ;
        


        # Choose boundareis
        my $bias_idx1 = $field_start > 0
                        ? $field_start - 1 
                        : $field_start;
        my $bias_idx2 = $field_end < scalar( @$spec_dx2 ) - 1
                        ? $field_end + 1 
                        : $field_end;
        # $bias_idx1-- if $bias_idx1 > 0;
        $bias_idx2++ if $bias_idx1 < scalar( @$spec_dx2 ) - 1;  
        $bias_idx2++ if $bias_idx1 < scalar( @$spec_dx2 ) - 1;  
        # $bias_idx2++ if $bias_idx1 < scalar( @$spec_dx2 ) - 1;  
        # $bias_idx2++ if $bias_idx1 < scalar( @$spec_dx2 ) - 1;  

        # Linear interpolation coefficient
        # my $bias = ( $spectrum_y_improved[ $bias_idx2 ] - $spectrum_y_improved[ $bias_idx1 ] )
        #          / ( $spectrum_x->[ $bias_idx2 ]        - $spectrum_x->[ $bias_idx1 ] );
        # my $y_shift = $spectrum_y_improved[ $bias_idx1 ] - $bias * $spectrum_x->[ $bias_idx1 ];
        
        
        # Interpolation field 
        $field_start = $field_start > $interp_half_field 
                        ? $field_start - $interp_half_field 
                        : 0;
        $field_end   = $field_end < scalar( @$spectrum_x ) - $interp_half_field 
                        ? $field_end + $interp_half_field 
                        : 0;



        my @interp_idx = grep {
                ( $field_start <= $_ and $_ <  $bias_idx1 )
            or  ( $bias_idx2  < $_   and $_ <= $field_end )
            } 0 .. scalar( @$spectrum_x )-1;

        my @interp_x = ();
        my @interp_y = ();

        for my $idx (@interp_idx) {
            push @interp_x, $spectrum_x->[ $idx ];
            push @interp_y, $spectrum_y->[ $idx ];
            # say $idx ."\t". $spectrum_x->[ $idx ] ."\t". $spectrum_y->[ $idx ];
        }



        # for my $k (0 .. max( scalar(@interp_x), scalar(@interp_y) ) - 1  ) {
        #     say $interp_x[ $k ] ."\t". $interp_y[ $k ];
        # }




        # Allocating memory for an interpolation object with chosen type and size and
        # accelerator object and handling it in $interp_obj and $interp_acc, respectively
        my $field_size = scalar( @interp_idx );  # interp_half_field * 2 + 1
        my $interp_obj = gsl_interp_alloc( $interp_type, $field_size ) ;
        my $interp_acc = gsl_interp_accel_alloc();

        # Initializing the interpolation object
        gsl_interp_init( $interp_obj, \@interp_x, \@interp_y, $field_size )
            and die "Interpolation failed to initialize\n";

        # Adding interpolated values instead of a noise paek
        for my $idx ( $bias_idx1 .. $bias_idx2 ) {
            $spectrum_y_improved[ $idx ] 
                = gsl_interp_eval( $interp_obj, \@interp_x, \@interp_y, $spectrum_x->[ $idx ], $interp_acc );
        }
        $index = $bias_idx2;
        $field_start = undef;
    }

}


my $spec_improved  = new Data::Table([ $spectrum_x, \@spectrum_y_improved  ], ['X', 'Y'], 
    Data::Table::COL_BASED);
$spec_improved->tsv(0, { file => $file_spectrum . '-improved'});


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Dividing quantum well and barrier
sub divide_by_min {
    my ($x, $y, $x_lo, $x_hi ) = @_;
    my %datah   = ();  # Data hash: X -> Y
    my %indexes = ();

    # Collecting data to hash
    for my $idx ( 0..scalar( @$x )-1 ) {
        $datah{ $x->[ $idx ] } = [  $y->[ $idx ], 
                                    $idx, 
                                    $x->[ $idx ] ];
    }

    # Looking for minimum
    my @field  ;
    my @values ;
    my $val_min;
    
    my $vals       ;
    my $val_min_x  ;
    my $val_min_idx;

    my $found = 0;

    while (!$found) {
        
        @field   = sort { $a <=> $b } grep { $x_lo <= $_ and $_ <= $x_hi } keys %datah;
        @values  = @datah{ @field };
        $val_min = min( map { $_->[0] } @values );
        
        $vals        = first { $_->[0] == $val_min } values %datah;
        $val_min_x   = $vals->[2]; 
        $val_min_idx = $vals->[1]; 

        # say Dumper @values;
        say " - First value in field  [X = " . $values[ 0]->[2] . "]: " . $values[0]->[0];
        say " - Chosen value in field [X = " . $val_min_x       . "]: " . $val_min;
        say " - Last value in field   [X = " . $values[-1]->[2] . "]: " . $values[-1]->[0];
        # say ' - ';

        if ( $values[0]->[0] == $val_min ) {
            my $dx = $x_hi - $x_lo;
            $x_hi = $x_lo;
            $x_lo -= $dx;
            say " <- Moving left";
        } 
        elsif ( $values[-1]->[0] == $val_min ) {
            my $dx = $x_hi - $x_lo;
            $x_lo = $x_hi;
            $x_hi += $dx;
            say " -> Moving right";
        } 
        else {
            $found = 1;
        }
    }

    # Separate QW's and Barrier's fields
    my @x_qw = grep { $_ <  $val_min_x } @$x;
    my @x_br = grep { $_ >= $val_min_x } @$x;

    my @y_qw = map { $_->[0] }  @datah{ @x_qw };
    my @y_br = map { $_->[0] }  @datah{ @x_br };

    return ( \@x_qw, \@y_qw, \@x_br, \@y_br );
}



my ( $spectrum_x_qw, $spectrum_y_qw, $spectrum_x_br, $spectrum_y_br ) 
    = divide_by_min( $spectrum_x, \@spectrum_y_improved, 4.5, 4.7 ); # c785 R03
    # = divide_by_min( $spectrum_x, \@spectrum_y_improved, 4.63, 4.85 ); # c821 R21
    # = divide_by_min( $spectrum_x, \@spectrum_y_improved, 4.65, 4.85 ); # c821 R14

my $spec_qw  = new Data::Table([ $spectrum_x_qw, $spectrum_y_qw  ], ['X', 'Y'], 
    Data::Table::COL_BASED);
$spec_qw->tsv(0, { file => 'qw-' . $file_spectrum});

my $spec_br  = new Data::Table([ $spectrum_x_br, $spectrum_y_br  ], ['X', 'Y'], 
    Data::Table::COL_BASED);
$spec_br->tsv(0, { file => 'br-' . $file_spectrum});

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
