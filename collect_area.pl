#!/usr/bin/env perl

use Modern::Perl;
use Data::Table;


#-------------------------------------------------------------------------------
# Extract temperature value from a filename
sub extract_temp {
    my $fname = shift;
    my $t;
    if ($fname =~ /(\d{1,3}([,_\.]\d+)?)K/) {
        $t = $1;
        $t =~ s/[,_]/\./;
        return $t;
    }
    return undef;
}


# -----------------------------------------------------------------------------
# This sub takes X and Y data in form of ref to array of arrays 
# [ [X1, Y1], [X2, Y2],.. ] and calculates area under the curve. The X data is
# assumed to be sorted X1 < X2 < X3 ...
sub calculate_area {
    my $data = shift; 
    my $area = 0;
    
    for my $idx ( 0 .. scalar( @$data ) - 2 ) {
        my $dx = $data->[ $idx + 1 ][0] - $data->[ $idx ][0];
        $area += 0.5 * ($data->[ $idx + 1 ][1] + $data->[ $idx ][1]) * $dx;
    }
    return $area;
}

# -----------------------------------------------------------------------------
# Main loop

my @temps = ();
my @areas = ();

for my $file (@ARGV) {
    unless (-r $file and -f $file) {
        say "Cannot read $file";
        next;
    }

    my $spectrum = Data::Table::fromFile( $file );
    push @areas, calculate_area( $spectrum->{data} );
    push @temps, extract_temp( $file );

}

my $result_tsv = new Data::Table( [ \@temps, \@areas ], ['Temperature', 'Area'],
    Data::Table::COL_BASED );

$result_tsv->tsv(1, { file => 'area.dat' });  # 1 is to write headers line into the file
