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
 * Align bitwidth for blocks in frequency domain.
 *
 * There are three cases:
 *   1. INPUT_WIDTH < OUTPUT_WIDTH
 *      In this case we just do signed extention of both parts
 *   2. INPUT_WIDTH = OUTPUT_WIDTH.
 *      Do nothing, just pass data through
 *   3. INPUT_WIDTH > OUTPUT_WIDTH
 *      Discard some bits, either from bottom (floor) or from top.
 *      This top/bottom balance is controlled by SEL parameter, and this
 *      parameter works only in this 3th case. This parameter also control gain
 *      and overflow risk. Overflow can be smoothed by saturation if SAT_EN==1
 *      Example ( IW = 10, OW = 7 ):
 *
 *      SEL = 0 ( gain = 0, overflow risk: high (depends on data of course...))
 *      s 9 8 7 6 5 4 3 2 1 0   input
 *     | |   |<------------->|
 *      |            |
 *      +---+        v
 *          v|<------------->|
 *          8 7 6 5 4 3 2 1 0
 *
 *      SEL = 1 ( gain = 2 times, overflow risk: medium )
 *      s 9 8 7 6 5 4 3 2 1 0   input
 *     | | |<------------->|
 *      |           ++
 *      +---+        v
 *          v|<------------->|
 *          8 7 6 5 4 3 2 1 0
 *
 *      SEL = 1 ( gain = 4 times, overflow risk: no )
 *      s 9 8 7 6 5 4 3 2 1 0   input
 *     |<--------------->|
 *               +--+
 *                  v
 *         |<--------------->|
 *          8 7 6 5 4 3 2 1 0
 *
 * alias IW = INPUT_WIDTH
 * alias OW = OUTPUT_WIDTH
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Sat, 13 Apr 2024 13:44:32 +0300
 */

`include "defines.vh"

module adjust_bitwidth #(
  parameter IW     = 10,
  parameter OW     = 8,
  parameter SEL    = 0,
  parameter SAT_EN = 0
) (
  input [IW*2-1:0]        data_i,
  output logic [OW*2-1:0] data_o,
  output logic            sat_alarm_o
);

// synopsys translate_off
initial if( IW>OW && SEL>(IW-OW)) $fatal( "%m wrong SEL" );
// synopsys translate_on

logic signed [IW-1:0] x_re;
logic signed [IW-1:0] x_im;
logic signed [OW-1:0] y_re;
logic signed [OW-1:0] y_im;
logic sa_re, sa_im;

assign x_re = data_i[IW-1:0];
assign x_im = data_i[IW*2-1:IW];

generate
  case( { ( IW == OW ), ( OW < IW ) } )
    2'b1? :
      begin
        assign { y_im, y_re } = { x_im, x_re };
      end
    2'b01 :
      if( SEL < (IW-OW) && SAT_EN )
        begin
          sat_sdft #( .IW(IW-SEL), .OW(OW) ) sat_re ( x_re[IW-1:SEL], y_re, sa_re );
          sat_sdft #( .IW(IW-SEL), .OW(OW) ) sat_im ( x_im[IW-1:SEL], y_im, sa_im );
        end
      else
        begin
          assign y_re = { `sign(x_re), x_re[OW+SEL-1:SEL] };
          assign y_im = { `sign(x_im), x_im[OW+SEL-1:SEL] };
        end
    2'b00 : // weird but possible
      begin
        assign y_re = `s( x_re ); // I know I don't need $signed() here, I just
        assign y_im = `s( x_im ); // want to keep it explicit as much as possible
      end
    default :; // impossible
  endcase
endgenerate

assign data_o      = { y_im, y_re };
assign sat_alarm_o = sa_re | sa_im;

endmodule
