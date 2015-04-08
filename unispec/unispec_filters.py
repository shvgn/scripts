#!/usr/bin/env python
# coding: utf-8
# 
# Optical filters processing for unispec.py
# version 0.1
#
#
# Evgeny Shevchenko
# shevchenko@beam.ioffe.ru
# 2012

import os.path
import numpy as np
import re
from scipy.interpolate import interp1d

parseFloatParam = lambda line: float(line.strip().replace(',','.').split()[-1])
parsePoint = lambda line: tuple(float(s) for s in line.strip().replace(',','.').split())

# def prodFunc(hash):
#     resultFunc = 1
#     for f in hash.values():
#         resultFunc *= f
#     return resultFunc

class GlassFilter:
    '''
    Class describes optical glass filter taking its name, width, reflection coefficient
    and data array
    '''
    def __init__(self, name, width=2, refl_coef=0.2, data=None):
        self.name = name
        self.width = width
        self.refl_coef = refl_coef
        self.data = data or __parse_spec()
        self.trans_spec = spectrum()

    def __parse_spec(self):
        '''
        This function tries to read filter datafile with absorption spectrum, 
        width and reflection coefficient data. The file is stored in ./storage/spectools
        If the file reading fails the function tries to take from the inner storage. 
        I don't know which way is more convenient
        '''
        data = []
        filename = os.path.join('storage', 'spectools', self.name, '.dat')
        try:
            with open(filename, 'r') as datasheet:
            for line in datasheet:
                if re.match('refl_coef',line):
                    self.refl_coef = parseFloatParam(line)
                elif re.match('width',line):
                    self.width = parseFloatParam(line)
                elif re.match('^#',line) or line.strip() == '':
                    continue    # Ignoring comments and empty lines
                elif re.match('\d+\.?\d*\s+\d+\.?\d*', line):
                    data.append(parseFloatPoint(line))
                else:
                    print "Warning: Unrecognized string in the filter datasheet of", name, "in line:", line
                    continue
        except IOError as e:
            print "Error: file", filename, "couldn't be opened"
        else:
            data = filtersStorage[self.name]
        finally:
            pass
        
        return data

    def spectrum(self):
        absorb_spec = np.array([[wl, (1 - self.refl_coef)**2 * 10**(-k * self.width)] for wl,k in self.data])
        absorb_spec.sort(axis=0)
        fltr_func[glassfilter] = interpolate.interp1d(absorb_spec[:,0], absorb_spec[:,1], kind='cubic')




def filters_spec(filters):
    '''The function takes filters spectra from corresponding data files and
    calculates filters transmission spectra for each of them. Dict with
    interpolation functions (transmission vs wavelength) is returned'''
    
    if not (filters.__class__.__name__ == 'list' or filters.__class__.__name__ == 'tuple'):
        filters = list(filters) # If there is only one input string argument
    elif filters.__class__.__name__ == 'str':
        filters = [filters]

    fltr_func = {}.fromkeys(filters)

    for glassfilter in filters:
        tmp_spectrum = [] 
        refl_coef = 1       # percentage/100
        width = 2           # mm

        with open(os.path.join('storage', 'spectools', glassfilter, '.dat'), 'r') as datasheet:
            for line in datasheet:
                if re.match('refl_coef',line):
                    refl_coef = parseFloatParam(line)
                elif re.match('width',line):
                    width = parseFloatParam(line)
                elif re.match('^#',line) or line.strip() == '':
                    continue    # Ignoring comments and empty lines
                elif re.match('\d+\.?\d*\s+\d+\.?\d*', line):
                    tmp_spectrum.append(parseFloatPoint(line))
                else:
                    print "Warning: Unrecognized string in the filter datasheet:", line
                    continue

        absorb_spec = np.array([ [wl, (1-refl_coef)**2 * 10**(-k*width)] for wl,k in tmp_spectrum ])
        absorb_spec.sort(axis=0)
        fltr_func[glassfilter] = interpolate.interp1d(absorb_spec[:,0], absorb_spec[:,1], kind='cubic')
    return fltr_func

 

if __name__ == '__main__':
    pass
