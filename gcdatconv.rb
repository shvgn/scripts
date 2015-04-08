#!/usr/bin/ruby -w
# Evgeny Shevchenko


EVNM = 1239.84193
EVK = EVNM * 1e-4

# Aligning to the required end of wave number
def kprop(k, first, last, must)
	(k - first) / (last - first) * (must - first) + first
end

filename = ARGV[0]
x_end = ARGV[1]

if File.file? filename
	outputfileext = File.extname(filename)
	outputfilename = File.basename( filename, outputfileext)
else
	puts "File #{filename} is not a file"
	exit(1)
end

data = File.readlines(filename).collect { |line|
	line.gsub(/,/,'.').split.collect! {|x| x.to_f }
	}.sort!{|a,b| a.last <=> b.last }.
	  select {|x| (x.first != 0.0) and !x.first.nil? and (x.last !=0.0) and !x.last.nil?}

y_min = data.first.last

# puts data.first
# puts data.last
# puts "min", y_min
# puts data.first.first != 0
suffix = "-corrected"

if x_end.nil?
	data.collect! do |x,y| 
		[ EVK * x, y - y_min]
	end
else
	
	x_end = x_end.to_f
	# make it wavenumber if it's given in nanometers
	x_end = 1e4 / x_end if x_end >= 100 

	data.collect! do |x,y| 
		[ EVK * kprop(x, data.first.first, data.last.first, x_end), y - y_min]
	end
	suffix += "-#{1e4/x_end}nm"
end

outfile = File.new(outputfilename + suffix + outputfileext, 'w')
outfile.puts "energy\t#{outputfilename}"
outfile.puts 
outfile.puts data.
	sort {|a,b| a.first <=> b.first }.
	collect { |x,y| "%f\t%f" % [x, y] }
	# collect { |x,y| "%.6f\t%.6f" % [x, y] }

