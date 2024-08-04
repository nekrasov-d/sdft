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
#
#  -- Dmitry Nekrasov <bluebag@yandex.ru>   Sat, 13 Apr 2024 10:36:39 +0300

# _td = time domain functions, _fd = frequency domain functions

import numpy as np

def twiddle_generator( N, order='forward' ):
    w = np.zeros( N, dtype=complex )
    for n in range(N):
        fi = -2 * np.pi * n / N if( order=='forward' ) else 2 * np.pi * n / N
        w[n] = complex( np.cos(fi), np.sin(fi) )
    return w


def twiddle_generator_int( N, order='forward', bitwidth=32 ):
    w = np.zeros( N, dtype=complex )
    min_val = -2**(bitwidth-1)
    max_val =  2**(bitwidth-1)-1
    for n in range(N):
        fi = -2 * np.pi * n / N if( order=='forward') else 2 * np.pi * n / N
        re = np.clip( round( np.cos(fi) * 2**(bitwidth-1)), min_val, max_val )
        im = np.clip( round( np.sin(fi) * 2**(bitwidth-1)), min_val, max_val )
        w[n] = complex( re, im )
        #w[n] = complex( re, im )
    return w


def sat( x, target_bitwidth ):
    lowerbound, upperbound = -2**(target_bitwidth-1), 2**(target_bitwidth-1)-1
    if( x < lowerbound ):
        return lowerbound
    if( x > upperbound ):
        return upperbound
    return x


def nmse_fd( x, ref, N, R ):
    if( len( x.shape ) != 2 ):
        print( "nmse_fd : wrong data shape" )
        exit()
    if( type( x[0,0] ) not in { np.float64, np.complex128 } ):
        print( "nmse_fd : wrong data type" )
        exit()
    nmse = lambda a,b : 0. if any( [a==0, b==0] ) else 10 * np.log10( a / b )
    if( type( x[0,0] ) == np.float64 ):
        error_acc = 0
        ref_acc   = 0
        for t in range(N):
            for k in range(R):
                error_acc += ( x[t,k]- ref[t,k] )**2
                ref_acc   += ref[t,k]**2
        return nmse( error_acc, ref_acc), 0.
    error_re_acc = 0
    error_im_acc = 0
    ref_re_acc   = 0
    ref_im_acc   = 0
    for t in range(N):
        for k in range(R):
            error_re_acc += ( x[t,k].real - ref[t,k].real )**2
            error_im_acc += ( x[t,k].imag - ref[t,k].imag )**2
            ref_re_acc   += ref[t,k].real**2
            ref_im_acc   += ref[t,k].imag**2
    nmse_re = nmse( error_re_acc, ref_re_acc )
    nmse_im = nmse( error_im_acc, ref_im_acc )
    return nmse_re, nmse_im


def peak_error_fd( x, ref, N, R, DW ):
    peak_error_re = 0
    peak_error_im = 0
    for t in range(N):
        for k in range(R):
            error_re = abs(x[t,k].real - ref[t,k].real)
            error_im = abs(x[t,k].imag - ref[t,k].imag)
            if( error_re > peak_error_re ):
                peak_error_re = error_re
            if( error_im > peak_error_im ):
                peak_error_im = error_im
    return 100*peak_error_re/2**(DW-1), 100*peak_error_im/2**(DW-1)


def hanning_td( x, R ):
    window = np.hanning(R)
    x      = x * window
    return x


def hanning_fd( x, N, R ):
    y = np.zeros_like( x )
    for t in range(N):
        y[t,0] = 0.5 * x[t,0] - 0.25 * x[t,1]
        for n in range(1,R-1):
            y[t,n] = 0.5 * x[t,n] - 0.25 * ( x[t,n-1] + x[t,n+1] )
        y[t,R-1] = 0.5 * x[t,R-1] - 0.25 * x[t,R-2]
    return y


def smoothing_fd( x, R, N, a=0.1, b=0.9):
    w = twiddle_generator( R, 'forward' )
    y = np.zeros_like( x, dtype=complex )
    for n in range(R):
        y[0,n] = a * x[0,n]
        for t in range(N-1):
            y[t,n] = a * x[t,n] + b * y[t-1,n] * w[n]
    return y


def complex_to_real( x, N, R  ):
    y = np.zeros_like( x, dtype=float )
    for t in range(N):
        for n in range(R):
            y[t,n] = x[t,n].real
    return y


# Twiddels are complex-valued
def twiddles_to_mem( mem_file_name, twiddles, cw, open_flag="w" ):
    fmt = lambda x : ("0"*int(np.ceil(cw*2/4) - len("%x"%x)) ) + "%x"%x
    radix = len(twiddles)
    # Firstly, get 2's complement format
    re_2sc = np.array([ int(twiddles.real[i]) for i in range(radix) ])
    im_2sc = np.array([ int(twiddles.imag[i]) for i in range(radix) ])
    for i in range( radix ):
        if( re_2sc[i] < 0 ):
            re_2sc[i] = abs( ( (2**cw-1) ^ re_2sc[i] ) + 1 )
        if( im_2sc[i] < 0 ):
            im_2sc[i] = abs( ( (2**cw-1) ^ im_2sc[i] ) + 1 )
    mem = np.array([ re_2sc[i] + (im_2sc[i] << cw) for i in range( radix ) ])
    f  = open( mem_file_name, open_flag )
    f.write( f"//WIDTH={cw*2};\n")
    f.write( f"//DEPTH={len(mem)};\n")
    f.write( f"//DATA_RADIX=HEX;\n\n")
    for i in range( len(mem) ):
        f.write( f"{fmt(mem[i])}\n" )
    f.close()

