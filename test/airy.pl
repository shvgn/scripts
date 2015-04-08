#!/usr/bin/env perl

use Modern::Perl 2010;  # Bunch of pragmas and features fo Perl 5.12
use autodie;            # No need to check for opened descriptors and so on,
                        # scalar filehandlers are recommended because of known
                        # bugs with 'FILE's
use utf8;
use Tk;
use Tk::PlotDataset;
use Tk::LineGraphDataset;
use Math::GSL::SF qw/:all/;

my $window = MainWindow->new( -title => 'Math::GSL Plot',);

my @region = map { $_/10 } (-50 .. 50);
my @data1  = map { gsl_sf_airy_Ai($_, $Math::GSL::SF::GSL_PREC_DOUBLE) } (@region);
my $dataset1 = LineGraphDataset -> new( -name => 'gsl_sf_airy_Ai',
                                        -xData => \@region,
                                        -yData => \@data1,
                                        -yAxis => 'Y',
                                        -color => 'red'
                                    );

my @data2 = map { gsl_sf_airy_Bi($_, $Math::GSL::SF::GSL_PREC_DOUBLE) } (@region);
my $dataset2 = LineGraphDataset -> new (-name => 'gsl_sf_airy_Bi',
                                        `-xData => \@region,
                                        `-yData => \@data2,
                                        `-yAxis => 'Y1',
                                        `-color => 'blue'
                                     );

my $graph = $window->PlotDataset( -width => 500,
                                  -height => 500,
                                  -background => 'snow'
                              ) -> pack(-fill => 'both', -expand => 1);

$graph -> addDatasets($dataset1, $dataset2);
$graph -> plot;
MainLoop;
exit(1);
