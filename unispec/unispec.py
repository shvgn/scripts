#!/usr/bin/env python
# coding: utf-8
# 
# Unispec spectra processing
# version 0.3
# 22.10.2012
#
#
# Evgeny Shevchenko
# shevchenko@beam.ioffe.ru
#


# TODO make manageble plots: optional plotting and saving a plot with matplotlib
# --plot-filters: show filters with plot (works only with --plot)

# --plot=1,3,4,5,8,9,7,9 or 345,346,349,353 (current numbers or global data
# numbers) for plotting, otherwise everything is plotted maybe it will be
# resonable to check if processed data files already exist

# --filters=bs7,zhs10,... : apply optical filters if there is missing or
# misspelled filter: abort or warn?  maybe it's reasonable to add --strict flag

# --show-known-filters: print known filters info

# shows names of known filters and their spectra wavelength ranges (and
# electron-volts, too)

# write in new data files the noise level, date, applied filters like: type -
# total number - noise - filters - date in YYYYMMDD e.g.
# ev-345-n500-bs7_bs8-20131231.dat


import sys
import re
import os.path


# Constant to transform nanometers to electron-volts and vice versa
evnm_c = 1239.84193

# Default values
noise = 0  # The spectra noise
shift = 0  # Wavelength shift
sourcefile = None
start = 1  # Number to start indexing output spectra
work_in_curdir = False
nm_output = False
ev_output = True
out_ext = 'dat'  # Someone may want to use --txt flag

# FIXME: Not implemented yet
filters_names = []  # strings, names of applied filters
second_order = False  # To suppress second order of peaks
plot_wanted = False
plot_filters = False
txt_wanted = False

parseIntParam = lambda line: int(line.split('=')[1])
parseFloatParam = lambda line: float(line.split('=')[1].replace(',', '.'))
parseStringParam = lambda line: line.split('=')[1].split(',')


def print_usage():
    jw = 20  # Justifying width
    opts = [("--usage, --help, -h", "Show this help"),
            ("--noise=F", "Noise level in the spectra (takes float)"),
            ("--shift=F", "Wavelength shift in the spectra (takes float)"),
            ("--start=I",
             "Starting number for counter for generating output filenames \
             (takes integer)"),
            ("--current-dir", "Place output files in the current directory"),
            ("--nm", "Produce output files with nanometers on axis"),
            ("--nm-only", "Produce ONLY output files with nanometers on axis")]
    print "\n".join(["%s    %s" % (k.rjust(jw), v) for k, v in opts])
    sys.exit(0)


def show_known_filters():
    """Print info about known optical filters"""
    for flr in filters_names:
        pass


def build_filename(xtype, num):
    """
    Builds filename type-totalnumber-noise-filters e.g. ev-345-n500-bs7_bs8.dat
    build_filename(xtype, num)
    xtype -- 'ev' or 'nm'
    num   -- number of spectrum
    noise and filters set are taken from __main__
    """
    return '-'.join(
        [xtype, str(num), 'n' + str(noise), '_'.join(filters_names)])


# Checking passed command line options
for arg in sys.argv[1:]:
    if re.match('--(usage|help)|-h', arg):
        print_usage()
    elif re.match('--filters=.*', arg):
        filters_names = arg.split('=')[-1].split(',')
        # TODO apply filters! Think on the interface. Filters script should be
        # separate thing in order to be used to apply filter(s) data to certain
        # spectra. Its function based on scipy 1-dimensional interpolation
        # should be imported. The function ought to be constructor for filters
        # composition. This script must have an ability to apply filters
        # selectively that to be specified in the script's arguments. Amen.
    elif re.match('--noise=.*', arg):
        noise = parseFloatParam(arg)
    elif re.match("--shift=.*", arg):
        shift = parseFloatParam(arg)
    elif re.match('--start=\d{1,4}', arg):
        start = parseIntParam(arg)
    elif re.match('--current-dir', arg):
        work_in_curdir = True
    elif re.match('--nm', arg):
        nm_output = True
    elif re.match('--nm-only', arg):
        nm_output = True
        ev_output = False
    elif re.match('--txt', arg):
        out_ext = 'txt'
    else:
        if os.path.exists(arg) and os.path.isfile(arg):
            sourcefile = arg
            continue
        else:
            print "Unrecognized argument:", arg
            print_usage()

if sourcefile == None:
    sys.exit('No input file was specified. Exiting.')

# Info output
print "Source file:", sourcefile
print "Signal noise:", noise
print "Wavelength shift:", shift, "nm"
if not filters == []:
    import unispec_filters

    print "Filters:",
    for f in filters:
        print " %s" % f,
print

if work_in_curdir:
    working_dir = os.path.curdir
else:
    working_dir = os.path.dirname(sourcefile)
process_dir = os.path.join(working_dir,
    os.path.basename(sourcefile).split('.')[0])

if not os.path.isdir(process_dir):
    os.mkdir(process_dir, 0755)

source = open(sourcefile, 'r')
experiment_data = source.readlines()
source.close()

spec_dict = {}  # Dictionary for all of the data

for line in experiment_data:
    if re.match('=' * 10, line):
        # The first line will match thus curnum, totalnum and datanum are to
        # be defined here
        curnum, totalnum = [
            int(k) for k in line.replace('=', '')
                                .replace('[', '')
                                .replace(']', '')
                                .strip().split('/')]
        datanum = start + curnum - 1
        print "Processing %d/%d #%d" % (curnum, totalnum, datanum)
        spec_dict[datanum] = []
    elif line.strip() == '':
        continue
    else:
        spec_dict[datanum].append([float(s) for s in line.strip().split()])

# Printing data to output files
for datanum in spec_dict.keys():
    # TODO here is the place to apply filters. Maybe.
    spectrum = [(wl + shift, insty - noise) for wl, insty in spec_dict[datanum]]
    if nm_output:
        with open(
                os.path.join(process_dir, 'nm-' + str(datanum) + '.' + out_ext),
                'w') as nm_file:
            nm_file.writelines("\n".join(
                ["\t".join([str(datanum) for datanum in s]) for s in spectrum]))
    if ev_output:
        with open(
                os.path.join(process_dir, 'ev-' + str(datanum) + '.' + out_ext),
                'w') as ev_file:
            ev_file.writelines(
                "\n".join(["\t".join([str(datanum) for datanum in s])
                           for s in sorted(
                        [(evnm_c / wl, ity) for wl, ity in spectrum])]))
