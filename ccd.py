#!/usr/bin/env python
#
# Evgeny Shevchenko, 2011
# shevchenko@beam.ioffe.ru
#

'''This script is written to process spectra data obtained on CCD camera. It
takes txt files from the specified directory and combines normalized spectra.

Usage:

    python ccd.py [DIRECTORY]

The directory must contain txt files named like

    "Someprefix NNNnm some NNNNsec NNNum NNmw thing else.txt"
    
that contain several columns of numeric data.  Only the fisrt and the last
columns are used as wavelength and intesity correspondingly.  Output file
contains two columns of quant energy in electronvolts and normalized intensity
by time and slits gap taken from file name.

This properties order is not strict.  Every part of the name divided by white
spaces from others that can't be interpreted as one of parameters (listed below)
is used in prefix.  The prefix from the example above will look like
"Someprefix_some_thing_else" and will be used as name of new .dat file with
normalized spectrum. Several parts of one spectrum sould have the same prefix in
order to be processed together in one output .dat file.

Note that prefix part "_1" in files "*_1.txt" is ignored as it's always used by
ASCII convertor of the program that is used for CCD camera control.

Note that spectrum parts joining is not ideal, and it's implemented not as good
as it should be.  Maybe some day...

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
            Power of excitaion light (not used)'''


class SpectrumData():
    '''Class to store and parse spectrum data from its file(s) name'''
    def __init__(self, FileList):
        self.data = {}
        self.data['filelist'] = FileList
        self.data['prefix']
        self.data['power']
        self.data['slitgap']
        self.data['delay']
        self.data['wavelength']
        self.data['intensity']
    def __parse(self):
        pass
        
        
    
if __name__ == '__main__':
    print "To be implemented."

