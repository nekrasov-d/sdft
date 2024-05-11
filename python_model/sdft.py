#!bin/pythion3
#
# MIT License
#
# Copyright (c) 2024 Dmitriy Nekrasov
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# ---------------------------------------------------------------------------------
#
# SDFT / SIDFT / SSIDFT models to use in RTL simulation or compare against FFT, etc.
#
#  -- Dmitry Nekrasov <bluebag@yandex.ru>   Sat, 13 Apr 2024 10:36:39 +0300

import numpy as np
from copy import copy
from utility_functions import twiddle_generator
from utility_functions import twiddle_generator_int
from utility_functions import sat

############################################################################
# Models

# Real input complex output
# "unlimited" precision point. Actually, it was used only once to verify the concept
class Sdft:
    def __init__( self, N ):
        self.N      = N
        self.x      = np.zeros( N, dtype=float   )
        self.y_prev = np.zeros( N, dtype=complex )
        self.w      = twiddle_generator( N, 'inverse' )

    def __call__( self, xn ):
        xz = self.x[-1]
        self.x = np.append( xn, self.x[:-1] )
        comb = complex( xn-xz, 0. )
        print( self.N )
        y = np.zeros( self.N, dtype=complex )
        print( y.shape )
        for n in range( self.N ):
            y[n] = ( comb + self.y_prev[n] ) * self.w[n]
        self.y_prev = y
        return y


# Real input complex output
# Limited precision model. Maybe it sould be merged with Sdft. Now it doesn't
# seem desirable. Names are kept close to same signals in Verilog (../rtl/sdft.sv)
class SdftInt:
    def __init__( self, N, bitwidth=32, hanning_en=False ):
        self.bitwidth    = bitwidth
        self.scale       = 2**(bitwidth-1)
        self.N           = N
        self.hanning_en  = hanning_en
        self.x           = np.zeros( N, dtype=int   )
        self.y_prev      = np.zeros( N, dtype=complex )
        self.w           = twiddle_generator_int( N, 'inverse', bitwidth )

    def hann_in_freq( self, y ):
        y[0] = 0.5 * y[0] - 0.25 * y[1]
        for n in range( 1, self.N-1 ):
            y[n] = 0.5 * y[n] - 0.25 * ( y[n-1] + y[n+1])
        y[self.N-1] = 0.5 * y[self.N-1] - 0.25 * y[self.N-2]
        return y

    def __call__( self, xn ):
        xz     = self.x[-1]
        self.x = np.append( xn, self.x[:-1] )
        comb   = complex( xn-xz, 0. ) # bitwidth + 1
        print( int(round(comb.real)) )
        y = np.zeros( self.N, dtype=complex )
        for n in range( self.N ):
            y_comb  = comb + self.y_prev[n] # bitwidth + 2
            y[n] = round( y_comb * self.w[n] / self.scale ) # bitwidth + 2
            #y[n] = sat( y[n], self.bitwidth )
        self.y_prev = copy(y)
        if( self.hanning_en ):
            y = self.hann_in_freq( y )
        return y


# It is not reasonable to use anything but 'midpoint' mode, but I left the
# option to choose different block to reconstruct window with in sake of
# an experiment.
class Ssidft:
    def __init__( self, N, mode='midpoint', window_idx=None ):
        self.N = N
        if( mode not in {'midpoint', 'other'} ):
            print( "Error, mode could be either 'midpoint' or 'other'" )
            exit()
        if( mode != 'midpoint'):
            if( window_idx is None ):
                print( "Error, if 'other' mode is choosen, window_idx must be specified" )
                exit()
            if( window_idx==0 ):
                print( "Error, window_idx can't be 0, it just won't work in this case" )
                exit()
            self.w = twiddle_generator( N, 'inverse' )

    def __call__( self, Fn ):
        f = np.zeros(self.N)
        if( mode=='midpoint' ):
            for k in range(self.N):
                f += -Fn if k%2 else Fn
        else:
            for k in range(self.N):
                f += Fn[k] * self.w[k]
        return f/N


class SsidftInt:
    def __init__( self, N ):
        self.N = N

    def __call__( self, Fn ):
        f = 0.0
        for k in range(self.N):
            f += -Fn[k].real if k%2 else Fn[k].real
        return int(np.fix(f/self.N))

# Complete Sidft calculating precise inverse transform. Could be used to compare
# pefrormance or computation speed. No low-precision integer version for this
# one because I am not going to impement it in hardware anyway.
class Sidft:
    def __init__( self, N ):
        self.N = N
        self.F = np.zeros((N,N), dtype=complex )
        # y here is the sum of contributions from the same bin over all stroed windows
        self.y_prev = complex( 0., 0. )
        self.w = twiddle_generator( N, 'inverse' )

    def __call__( self, Fn ):
        Fz = self.F[-1]
        self.F = np.append( Fn, self.N[:-2] )
        y = np.zeros( self.N, dtype=complex )
        for k in range(self.N):
            y[k] = (Fn[k] - Fz[k])/self.N + self.y_prev[k] * self.w[k]
        return sum(y) / self.N



