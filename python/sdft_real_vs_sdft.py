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
# Some SDFT design testing routine mentioned in ../README.md
#
#  -- Dmitry Nekrasov <bluebag@yandex.ru>   Sat, 13 Apr 2024 10:36:39 +0300

import numpy as np
import matplotlib.pyplot as plt
from models import *
from utility_functions import *

# Data width and bit with goes as synonymous
DW = 18
R  = 256 # RADIX
N  = 2**9 # Amount of test samples

min_val = -2**(DW-1)
max_val =  2**(DW-1)-1

x = np.random.randint( min_val//32, max_val//32, N )
sdft      = SdftInt    ( R, bitwidth=DW, hanning_en=False )
sdft_real = SdftIntReal( R, bitwidth=DW, hanning_en=False )

ref    = np.array( [ sdft(x[i])        for i in range(N) ] )
f_half = np.array( [ sdft_real( x[i] ) for i in range(N) ] )

f = np.zeros( ( f_half.shape[0], f_half.shape[1]*2 ), dtype=float )

for i in range( len( f_half ) ):
    # We lose N/2 bin because we want to calculate N/2 bins, not N/2+1
    # to reduce complexity. One additional bin would cost non-proportional
    # recource utilization increasing. It is reasonable tradeoff.
    #
    # tmp = np.append( f_half[i].real, 0 )
    #
    # But, because we aware of that, we don't take this as an error. We need to
    # find some real (unexpected) errors, so we loan this bin value from
    # reference.
    tmp = np.append( f_half[i], ref[i].real[R//2] )
    f[i] = np.append( tmp, f_half[i][:0:-1] )


#ref = hanning_fd     ( ref, N, R )
#f   = hanning_fd     ( f,   N, R )
ref = complex_to_real( ref, N, R )

plt.plot( ref[-1], color='blue' )
plt.plot( f[-1],   color='red', linestyle='dashed' )
plt.show()
exit()

print( "NMSE: re: %3f dB im: %3f dB"         % nmse_fd       ( f, ref, N, R ) )
print( "Peak error : re: %3f %% im: %3f %% " % peak_error_fd ( f, ref, N, R, DW) )
