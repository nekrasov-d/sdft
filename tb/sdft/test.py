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
# Top-level program template. Altough it is also could be wrapped up to run
# automatically in a cycle through variating set of parameters. It requires some
# modifications anyway to fit your project.
#
# -- Dmitry Nekrasov <bluebag@yandex.ru> Thu, 21 Mar 2024 21:05:25 +0300
#

import numpy as np
import sys
import os
import subprocess
cwd = os.getcwd()
sys.path.append( cwd + "/../../python/")
from models import SdftInt
from models import SdftIntRL
from utility_functions import twiddle_generator_int
from utility_functions import twiddles_to_mem

############################################################################
# Test parameters (example)

# Mandatory parameters
RADIX                    = 256
DATA_WIDTH               = 16
COEFFICIENT_WIDTH        = 16
HANNING_EN               = 0
ARCHITECTURE             = ( "default", "rl" )[1]
CLK_PER_SAMPLE           = RADIX+1
TESTBENCH_MODE           = ( "manual", "automatic" )[1]
TWIDDLE_ROM_FILE         = "sdft_twiddles.mem"

# Could be static if project has fixed RTL files set
RTL_SOURCES = [
  '../../rtl/sat.sv',
  '../../rtl/ram.sv',
  '../../rtl/rom.sv',
  '../../rtl/rotator.sv',
  '../../rtl/hanning_fd.sv',
  '../../rtl/sdft_default.sv',
  '../../rtl/sdft_rl.sv',
  '../../rtl/sdft.sv'
]

############################################################################
# Translate config to verilog

f = open( "parameters.v", "w" )
f.write(f"parameter DATA_WIDTH        = {DATA_WIDTH};\n")
f.write(f"parameter COEFFICIENT_WIDTH = {COEFFICIENT_WIDTH};\n")
f.write(f"parameter RADIX             = {RADIX};\n")
f.write(f"parameter HANNING_EN        = {HANNING_EN};\n")
f.write(f'parameter ARCHITECTURE      = "{ARCHITECTURE}";\n')
f.write(f'parameter CLK_PER_SAMPLE    = {CLK_PER_SAMPLE};\n')
f.write(f'parameter TEST_DATA_FNAME   = "input.txt";\n')
f.write(f'parameter REF_DATA_RE_FNAME = "ref_data_re.txt";\n')
f.write(f'parameter REF_DATA_IM_FNAME = "ref_data_im.txt";\n')
f.write(f'parameter TESTBENCH_MODE    = "{TESTBENCH_MODE}";\n')
f.close()

f = open( "files", "w" )
for i in range(len(RTL_SOURCES)):
    f.write(f"{RTL_SOURCES[i]}\n")
f.close()

############################################################################
# Prepare twiddles rom

w = twiddle_generator_int( RADIX, order='inverse', bitwidth=COEFFICIENT_WIDTH )
twiddles_to_mem( TWIDDLE_ROM_FILE, w, COEFFICIENT_WIDTH )

############################################################################
# Prepare test data

N = RADIX * 30

min_val = -2**(DATA_WIDTH-1)
max_val =  2**(DATA_WIDTH-1)-1
sigma   = max_val / 8

rng = np.random.default_rng()
test_data = np.clip( rng.normal( 0.0, sigma, N ), min_val, max_val )

if( ARCHITECTURE=="default" ):
    sdft = SdftInt( RADIX, bitwidth=DATA_WIDTH, hanning_en=(HANNING_EN==1) )
else:
    sdft = SdftIntRL( RADIX, bitwidth=DATA_WIDTH, hanning_en=(HANNING_EN==1) )

reference_data = np.array( [sdft(test_data[i]) for i in range(N) ] )

if( ARCHITECTURE=="default" ):
    # The first block is empty because of 1 block cycle delay. Insert this empty
    # output into reference data to emulate dut behaviour
    reference_data = np.insert( reference_data, 0, np.zeros(RADIX), axis=0 )[:-1]

td  = open( "input.txt", "w" )
for i in range(N):
    td.write( "%d\n" % test_data[i] )
td.close()

rd_re = open( "ref_data_re.txt", "w" )
rd_im = open( "ref_data_im.txt", "w" )
for i in range(N):
    for j in range(RADIX):
        rd_re.write( "%d\n" % reference_data[i,j].real )
        rd_im.write( "%d\n" % reference_data[i,j].imag )
rd_re.close()
rd_im.close()

if( TESTBENCH_MODE == "automatic" ):
    run_vsim = "vsim -c -do make.tcl"
    vsim = subprocess.Popen( run_vsim.split(), stdout=subprocess.PIPE )
    res = vsim.communicate()
    print(res)
    try:
        f = open( "score.txt", "r" )
        score = f.readlines()[0][1:-2] # cut side { }
        f.close()
    except FileNotFoundError:
        score = "No score.txt were generated by make.tcl routine"
    f = open( "log", "a" )
    f.write("------------------------------------------------------------\n")
    f.write( f"Paramters: .... ")
    f.write( f"Results: {score}\n")
    f.close()
    # clean
    try:
        os.remove(TWIDDLE_ROM_FILE)
        os.remove("parameters.v")
        os.remove("files")
        os.remove("input.txt")
        os.remove("ref_data_re.txt")
        os.remove("ref_data_im.txt")
        os.remove("score.txt")
        os.remove("transcript")
        os.remove("vsim.wlf")
        import shutil
        shutil.rmtree( "work", ignore_errors=True )
    except FileNotFoundError:
        pass






