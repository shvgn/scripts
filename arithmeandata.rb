#!/usr/bin/env ruby
# coding: utf-8
# E. Shevchenko
# shevchenko@beam.ioffe.ru
# v 0.2
# 22/11/2012


# This monkey patching is made to have easy sum of an array
class Array
  def inject(n)
     each { |value| n = yield(n, value) }
     n
  end
  def sum
    inject(0) { |n, value| n + value }
  end
  def product
    inject(1) { |n, value| n * value }
  end
end


# ---------------- constant ---------------------
# Convert electron-volts to nm and vice versa
EVNM = 1239.84193 

# ------------ default arguments ----------------
exclude_zero_y = false
exclude_zero_x = false
multiplier = 1
shift = 0

# -------------- filename suffix ----------------
extension = "dat"
suffix_nm = "-nm" + "." + extension;  
suffix_ev = "-ev" + "." + extension;


# ------------------ options --------------------
opts_help = [ '-h', '--help', '--usage' ]
opts_zero = [ '--exclude-zero-x', '--exclude-zero-y', '--exclude-zero' ]
opts_math = [ '--mul', '--shift']




# ------------------ show help -------------------

usage = Proc.new {
  puts "USAGE:"
  puts "\tarithmeandata.rb [new_file_sample] file1 file2 ..."
  puts "\t" + opts_help.join("\n\t") + "\t\tshow this message"
  puts
  puts "\t" + opts_math.join("\n\t") + "\t\tpass a number to shift x and/or multiply y"
  puts
  puts "\t" + opts_zero.join("\n\t") + "\texclude data with zero in x, y or in either of them"
}


if not (ARGV & opts_help).empty? or ARGV.empty?
    usage.call
    exit
end



# ------------- process arguments --------------

ARGV.each do |arg|
  if arg == '--exclude-zero-x' 
    exclude_zero_x = true
  elsif arg == '--exclude-zero-y'
    exclude_zero_y = true
  elsif arg == '--exclude-zero'
    exclude_zero_x = true
    exclude_zero_y = true
  elsif arg.match('--mul=')
    multiplier = arg.split('=').last.to_f
  elsif arg.match('--shift=')
    shift = arg.split('=').last.to_f
  end
end


if ARGV.include? '--exclude-zero-x' 
  exclude_zero_x = true
elsif ARGV.include? '--exclude-zero-y' 
  exclude_zero_y = true
elsif ARGV.include? '--exclude-zero' 
  exclude_zero_x = true
  exclude_zero_y = true
else 
  exclude_zero_x = false
  exclude_zero_y = false
end




# ------------------ process data --------------------

src = {}
newfile_sample = 'arithmeandata'

ARGV.each do |file|
  # this is considered to be a script option key
  next if file.strip.match(/\A--?\w+(-\w+)*\z/) 
  
  unless File.file?(file)
    # FIXME newfile_sample don't assigns when it comes first
    newfile_sample = file
    puts "New file name: ", newfile_sample
    next
  end
  
  print "Processing #{file}"
  counter = 0

  File.open(file, 'r').readlines.each do |line|
    data = line.split.collect!{|x| x.to_f}
    # print data
    next if exclude_zero_x and data.first == 0
    next if exclude_zero_y and data.last == 0
    
    if src.has_key? data.first
      src[data.first].push(data.last)
    else
      src[data.first] = [data.last]
    end
    # print data.first, ' --- ', src[data.first], "\n"
    counter += 1
  end
  print " - #{counter} points\n"
end 




arr_nm = src.keys.compact.sort.collect {|wl| [wl + shift, src[wl].sum / src[wl].length]}.sort
arr_ev = arr_nm.collect {|x,y| [EVNM/(x + shift), y]}.sort



# ------------------ output ----------------------

File.new(newfile_sample + suffix_ev, 'w').puts arr_ev.collect { |x,y| 
  "%.6f\t%.6f" % [x, y * multiplier] }

File.new(newfile_sample + suffix_nm, 'w').puts arr_nm.collect { |x,y| 
  "%.6f\t%.6f" % [x, y * multiplier] }


puts "File #{newfile_sample}#{suffix_nm} saved."
puts "File #{newfile_sample}#{suffix_ev} saved."

