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

module ssidft #(
  parameter DW = 16,
  parameter OW = 16,
  parameter N  = 2**12,
  parameter AW = $clog2(N)
) (
  input                 clk_i,
  input                 srst_i,
  input                 sob_i,
  input                 eob_i,
  input signed [DW-1:0] freq_re_i,
  output logic [OW-1:0] sample_o,
  output logic          sample_en_o
);

logic signed [DW+AW-1:0] acc;
logic           [AW-1:0] counter;
logic                    active;
logic                    eob_d;

assign active = sob_i | ( counter != '0 );

always_ff @( posedge clk_i )
  if( srst_i )
    counter <= '0;
  else
    if( active )
      counter <= counter + 1'b1;


always_ff @( posedge clk_i )
  if( sob_i )
    acc <= freq_re_i;
  else
    if( counter[0] )
      acc <= acc - freq_re_i;
    else
      acc <= acc + freq_re_i;

//********************************************************************


always_ff @( posedge clk_i )
  eob_d <= eob_i;

localparam M = 5;

logic [OW-1:0] acc_sat;
logic sat_alarm;

sat #( .IW(DW+AW-5), .OW(OW) ) sat ( acc[DW+AW-1:5], acc_sat, sat_alarm );

always_ff @( posedge clk_i )
  if( eob_d )
    //sample_o <= `s({ `sign(acc), acc[20:6] });
    sample_o <= acc_sat;

always_ff @( posedge clk_i )
  sample_en_o <= eob_d;

endmodule
