#!/usr/bin/perl -w
#
# Unispec
# version 0.1.6
#
# Создает из текстового файла с несколькими спектрами, разделенными строками с
# символом равенства (=) -- файлы УНИСПЕК -- соответствующее число раздельных
# dat-файлов с аргументами в нанометрах и электронвольтах с последующим
# построением графиков с помощью gnuplot.
#
# Evgeny Shevchenko
# Shevchenko@beam.ioffe.ru
# 2012
#

# TODO web interface?

# TODO copy python implementation functionality with adding optical filters
# interpolation

print "Каждый исходный файл с несколькими спектрами будет разбит на файлы с
именами типа \n[префикс]-[единицы аргумнта]-[номер].dat (без квадратных
скобок)\nВ качестве префикса лучше всего использовать имя образца с дефисом (или
еще каким-то допустимым символом), например, c123\nВ качестве номера можно
задать 1, если нет для этого более удобной нумерации\nЕдиницы аргумента будут
заданы автоматически: nm и ev (нанометры и электровольты соответственно)\n";

foreach $sourcefile ( @ARGV ) {
	
	print "Processing $sourcefile\n";	

	if ( ! -f $sourcefile ) {
		print "It's not file! Skipping.\n";
		next;
	}

	print "\nFile prefix:: ";
	chomp ($prefix = <STDIN>);

	print "Number to begin files enumeration: ";
	chomp ($firstnum = <STDIN>);

	print "Noise level: ";
	chomp ($noise = <STDIN>);

	print "Wavelength shift (consider sign!): ";
	chomp ($shift = <STDIN>);
	print "\n";


	# 3,14 -> 3.14
	$noise =~ s/\,/\./;
	$shift =~ s/\,/\./;

	$noise = 0 if (! $noise =~ /^\d+\.?\d*/    );
	$shift = 0 if (! $shift =~ /^\-?\d+\.?\d*/ );

	$dir = $prefix; # TODO source file basename instead of prefix
	$currentnum = ($num = $firstnum);

	mkdir("$dir", 0755) if (! -e "$dir" && ! -d "$dir" );
	chdir("$dir") || die "There is something wrong with $dir: $!\n";

	# Distributing data
	open(SOURCE, "../$sourcefile") || die "There is something wrong with $sourcefile: $!\n" ;

	$i = 0;
	while (<SOURCE>) {
		chomp;
		if ( /^\d+\.?\d*\s+\d+\.?\d*/ ) {

			if ($currentnum == $num) {
				open (SPECTRUMNM, ">$prefix-nm-$num.dat") || die "Cannot create file: $!\n";
				open (SPECTRUMEV, ">$prefix-ev-$num.dat") || die "Cannot create file: $!\n";
				$currentnum++;
			}
		
			($wavelength, $intence) = split(/\s+/);
			$wavelength += $shift ;
			$intence -= $noise ;
			$energy = $wavelength && 1239.842/$wavelength;
		
			print SPECTRUMNM "$wavelength\t$intence\n" ;
			print SPECTRUMEV "$energy\t$intence\n" ;
		
		} elsif (/=+/) {
		
			if ( $num > $firstnum ) {
				close (SPECTRUMNM);
				close (SPECTRUMEV);
			}
		
			$i = 0;
			$num++ if $currentnum > $num;
		}
	}
	close (SOURCE);
	close (SPECTRUMNM);
	close (SPECTRUMEV);
	
    # Creating simple black-n-white plots
	while ( defined($file=<*nm*.dat *ev*.dat>) ) {
		if (-f $file) {
			($fname) = split(/\.dat/, $file) ;
		} else {
			print "$file is not file. Skipping.\n";
			next;
		}
		
		open(GNUPLOTFILE, ">$fname.gpl") || die "Cannot create gnuplot file: $!\n";
		$oldhandle = select GNUPLOTFILE ;
		
		print "#!/usr/bin/gnuplot -persist\n" ;
		print "set encoding utf8\n";
		print "set terminal postscript 'DejaVuSans' eps enhanced\n";
		print "set bmargin 4\n";
		print "set output \"$fname.ps\"\n";
		print "set xlabel \"Energy, eV\"\n" if ($fname =~ /ev/) ;
		print "set xlabel \"Wavelength, nm\"\n" if ($fname =~ /nm/) ;
		print "set ylabel \"Intensity, arb. units\" \n";
		print "set style line 1 lt 1 pt 0\n";
		print "plot \"$fname.dat\" title \"$fname\" with linespoints linestyle 1\n";
		
		close (GNUPLOTFILE) || die "Cannot close gnuplot file: $!\n";
		select $oldhandle ;

		# TODO generate PDF with the merged spectra
		
        # Looking for gnuplot

        if ( -x "/usr/bin/gnuplot" && -r "/usr/bin/gnuplot") {
            system "gnuplot $fname.gpl";
        } else {
            print "Cannot find gnuplot. Plots are not created for $prefix.\n";
            #exit 0;
        }
	}
	chdir ("../");
}
