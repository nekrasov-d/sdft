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
# A script to generate twiddle ROM memory image (Verilog .mem format). The
# parameters (UPPERCASE variables) are self-describing.
#
# XXX: This is not the optimal way to store twiddles, because one quarter of
# sine wave in memory + some trivial arithmetics to select proper quadrant and
# turn sine into cosine if needed would be enough. Anyway, the work in this
# repo doesn't focus on optimal twiddle generation, only gives a basic solution.
# I would suggest to use my coric-based sine/cosine generator to produce
# twiddles:
#
# -- Dmitry Nekrasov <bluebag@yandex.ru>   Fri, 10 May 2024 14:39:59 +0300

import numpy as np
from python_model.utility_functions import twiddle_generator_int
from python_model.utility_functions import twiddles_to_mem

RADIX    = 2**16
BITWIDTH = 16
ORDER    = ("forward", "inverse")[1]
FNAME    = f"twiddles_{BITWIDTH}b_{RADIX}.mem"

w = twiddle_generator_int( RADIX, ORDER, BITWIDTH )
twiddles_to_mem( FNAME, w, BITWIDTH )
