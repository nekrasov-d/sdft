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

module hanning_fd #(
  parameter DW           = 0,
  parameter IMAG_PART_EN = 0,
  parameter IODW         = IMAG_PART_EN ? DW*2 : DW
) (
  input                   clk_i,
  input        [IODW-1:0] data_i,
  input                   sob_i,
  input                   eob_i,
  input                   valid_i,
  output logic [IODW-1:0] data_o,
  output logic            sob_o,
  output logic            eob_o,
  output logic            valid_o
);

logic sob_d, eob_d, valid_d;
logic signed [DW-1:0] z0_re, z0_im;
logic signed [DW-1:0] z1_re;
logic signed [DW-1:0] z2_re;
logic signed [DW-3:0] z0_025_re;
logic signed [DW-2:0] z1_05_re;
logic signed [DW-3:0] z2_025_re;
logic signed [DW-2:0] z0_z2_re;
logic signed [DW-1:0] h_re;

//****************************************************************

always_ff @( posedge clk_i )
  begin
    sob_d   <= sob_i;
    eob_d   <= eob_i;
    valid_d <= valid_i;
  end

assign { z0_im, z0_re } = valid_i ? data_i : '0;

always_ff @( posedge clk_i )
  { z2_re, z1_re } <= { z1_re, z0_re };

assign z0_025_re = z0_re >>> 2;
assign z1_05_re  = z1_re >>> 1;
assign z2_025_re = z2_re >>> 2;
assign z0_z2_re  = z0_025_re + z2_025_re;
assign h_re      = z1_05_re  - z0_z2_re;

generate
  if( IMAG_PART_EN )
    begin : imag_part
      logic signed [DW-1:0] z1_im;
      logic signed [DW-1:0] z2_im;
      logic signed [DW-3:0] z0_025_im;
      logic signed [DW-2:0] z1_05_im;
      logic signed [DW-3:0] z2_025_im;
      logic signed [DW-2:0] z0_z2_im;
      logic signed [DW-1:0] h_im;
      always_ff @( posedge clk_i )
        { z2_im, z1_im } <= { z1_im, z0_im };
      assign z0_025_im = z0_im >>> 2;
      assign z1_05_im  = z1_im >>> 1;
      assign z2_025_im = z2_im >>> 2;
      assign z0_z2_im  = z0_025_im + z2_025_im;
      assign h_im      = z1_05_im  - z0_z2_im;
      assign data_o    = {h_im, h_re};
    end // imag_part
  else
    begin : no_imag_part
      assign data_o = h_re;
    end // no_imag_part
endgenerate

assign sob_o   = sob_d;
assign eob_o   = eob_d;
assign valid_o = valid_d;

endmodule
