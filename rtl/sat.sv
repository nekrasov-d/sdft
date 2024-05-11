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
 * Simple combinational saturation module. Expected to be nested:
 *  `include "sat.sv"
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Sun, 07 Apr 2024 14:10:40 +0300
 */

`include "defines.vh"

module sat #(
  parameter IW = 10,
  parameter OW = 9
) (
  input        [IW-1:0] x,
  output logic [OW-1:0] y,
  output logic          sat_alarm_o
);

localparam DISCARDED_BITS = IW-OW;

logic sat_case;

assign sat_case = x[IW-2 -: DISCARDED_BITS] != {DISCARDED_BITS{`sign(x)}};

always_comb
  case( { `sign(x), sat_case } )
     2'b01   : y = {1'b0,  `ones(OW-1)};
     2'b11   : y = {1'b1, `zeros(OW-1)};
     default : y = {`sign(x), x[OW-2:0]};
  endcase

assign sat_alarm_o = sat_case;

endmodule
