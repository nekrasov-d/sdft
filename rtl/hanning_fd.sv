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
  parameter DW = 0
) (
  input                   clk_i,
  input        [DW*2-1:0] data_i,
  input                   sob_i,
  input                   eob_i,
  input                   valid_i,
  output logic [DW*2-1:0] data_o,
  output logic            sob_o,
  output logic            eob_o,
  output logic            valid_o
);

localparam RE = 0;
localparam IM = 1;

logic sob_d, eob_d, valid_d;
logic signed [1:0][DW-1:0] z0     ;
logic signed [1:0][DW-1:0] z1     ;
logic signed [1:0][DW-1:0] z2     ;
logic signed [1:0][DW-3:0] z0_025 ;
logic signed [1:0][DW-2:0] z1_05  ;
logic signed [1:0][DW-3:0] z2_025 ;
logic signed [1:0][DW-2:0] z0_z2  ;
logic signed [1:0][DW-1:0] h      ;

//*****************************************************************

always_ff @( posedge clk_i )
  begin
    sob_d   <= sob_i;
    eob_d   <= eob_i;
    valid_d <= valid_i;
  end

assign { z0[IM], z0[RE] } = data_i;

always_ff @( posedge clk_i )
  begin
    { z1[IM], z1[RE] } = { z0[IM], z0[RE] };
    { z2[IM], z2[RE] } = { z1[IM], z1[RE] };
  end

assign z0_025[RE] = `s(z0[RE] >> 2);
assign z0_025[IM] = `s(z0[IM] >> 2);
assign z1_05 [RE] = `s(z1[RE] >> 1);
assign z1_05 [IM] = `s(z1[IM] >> 1);
assign z2_025[RE] = `s(z2[RE] >> 2);
assign z2_025[IM] = `s(z2[IM] >> 2);

assign z0_z2[RE] = `s(z0_025[RE]) + `s(z2_025[RE]);
assign z0_z2[IM] = `s(z0_025[IM]) + `s(z2_025[IM]);

assign h[RE] = `s(z1_05[RE]) - `s(z0_z2[RE]);
assign h[IM] = `s(z1_05[IM]) - `s(z0_z2[IM]);

assign data_o = {h[IM], h[RE]};

assign sob_o   = sob_d;
assign eob_o   = eob_d;
assign valid_o = valid_d;

endmodule
