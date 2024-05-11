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
from sdft import *
from utility_functions import *

# Data width and bit with goes as synonymous
DW = 18
R  = 256 # RADIX
N  = 2**12 # Amount of test samples

min_val = -2**(DW-1)
max_val =  2**(DW-1)-1

x = np.random.randint( min_val//32, max_val//32, N )
sdft = SdftInt( R, bitwidth=DW, hanning_en=False )

# rectangle window (default)
wx = np.array( [ np.append([0.]*(R-1),x)[i:i+R] for i in range(N) ] )

#wx = hanning_td( wx, R )

ref = np.array( [ np.fft.fft( wx[i] ) for i in range(N) ] )
f   = np.array( [ sdft(x[i])          for i in range(N) ] )

#ref = hanning_fd( ref, N, R )
#f   = hanning_fd( f, N, R )

#ref = complex_to_real( ref )
#f   = complex_to_real( f  )

#f = smoothing_fd( f, R, N, a=0.01, b=0.99 )

print( "NMSE: re: %3f dB im: %3f dB"         % nmse_fd       ( f, ref, N, R ) )
print( "Peak error : re: %3f %% im: %3f %% " % peak_error_fd ( f, ref, N, R, DW) )
a = abs(f[:,112])
b = abs(ref[:,112])
plt.plot( a, color='red', label='sdft')
plt.plot( b, color='blue', label='fft', linestyle='--')
plt.legend()
plt.show()

