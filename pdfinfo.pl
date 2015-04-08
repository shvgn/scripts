#!/usr/bin/env perl

use Modern::Perl;
use PDF;

for my $filename (@ARGV) {
	chomp($filename);
	
	# my $pdf = PDF->new($filename); # filename and PDF descriptor are linked here, no need for TargetFile
	
	my $pdf = PDF->new;
	say "TargetFile result: "   .  $pdf->TargetFile( $filename ); # XXX Premature end of file and bad object reference

	say "LoadPageInfo result: " .  $pdf->LoadPageInfo; # XXX Bad object reference

	if ( $pdf->IsaPDF ) {
		say "PDF Version:\t",	$pdf->Version ;

		my $pages = $pdf->Pages;
		say "Total pages:\t",	$pages if defined($pages);

		say "This PDF is crypted" if ( $pdf->IscryptPDF) ;

		say "Title:\t\t".		$pdf->GetInfo("Title") 	      if $pdf->GetInfo("Title");
		say "Subject:\t".  		$pdf->GetInfo("Subject")      if $pdf->GetInfo("Subject");
		say "Authors:\t".  		$pdf->GetInfo("Author")       if $pdf->GetInfo("Author");
		say "Date:\t\t".  		$pdf->GetInfo("CreationDate") if $pdf->GetInfo("CreationDate");
		say "Changed on\t".		$pdf->GetInfo("ModDate")      if $pdf->GetInfo("ModDate");
		say "Created with\t".	$pdf->GetInfo("Creator")      if $pdf->GetInfo("Creator");
		say "Converted with\t". $pdf->GetInfo("Producer")     if $pdf->GetInfo("Producer");

		print "Keywords:\t"; 
		if ($pdf->GetInfo("Keywords")) {
			foreach (sort split(/;\s+/, $pdf->GetInfo("Keywords"))) {
				say "\t\t" . ucfirst(lc $_);
			}	
		} else {
			say;
		}
		
		if (defined($pages)) {
			foreach my $n (1..$pages) {
				my ($startx, $starty, $endx, $endy) = $pdf->PageSize($n) ;
				say "Page #" . $n . " size " . ($endx - $startx) . "x" . ($endy - $starty);  
			}	
		}

	} else {
	  say "This file cannot be processed or is not pdf: $filename";
	}


}
