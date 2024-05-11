/*
 * MIT License
 *
 * Copyright (c) 2024 Dmitriy Nekrasov
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * ---------------------------------------------------------------------------------
 *
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Sat, 13 Apr 2024 13:44:32 +0300
 */

`include "defines.vh"

module rotator #(
  parameter N  = 2**12,
  parameter DW = 16,
  parameter CW = 16
) (
  // The rotated value
  input signed        [DW-1:0] x_re,
  input signed        [DW-1:0] x_im,
  // The rotator ( |c| = 1 )
  input signed        [CW-1:0] c_re,
  input signed        [CW-1:0] c_im,

  output logic signed [DW-1:0] y_re,
  output logic signed [DW-1:0] y_im
);

//(a + bj)(c + dj) = ac + adj + bcj - bd
logic signed [DW+CW-1:0] ac, bd, ad, bc;

logic signed [DW+CW:0] re_mult, im_mult;
// Scaling back because the second arg is actually 0.something scaled to the
// whole range [ -2**(CW-1) : 2**(CW-1)-1 ]
logic signed [DW+1:0] re_scaled_back, im_scaled_back;
// Discard extra bit next to the sign bit appeared after addition/subtraction
logic signed [DW-1:0] re_discard_msb, im_discard_msb;

assign ac = x_re * c_re;
assign bd = x_im * c_im;
assign ad = x_re * c_im;
assign bc = x_im * c_re;

assign re_mult = ac - bd;
assign im_mult = ad + bc;

assign re_scaled_back = `s(re_mult[ DW+CW : (CW-1) ]) + `u(re_mult[CW-2]);
assign im_scaled_back = `s(im_mult[ DW+CW : (CW-1) ]) + `u(im_mult[CW-2]);

assign y_re = `s({re_scaled_back[DW+1], re_scaled_back[DW-2:0]});
assign y_im = `s({im_scaled_back[DW+1], im_scaled_back[DW-2:0]});

endmodule


