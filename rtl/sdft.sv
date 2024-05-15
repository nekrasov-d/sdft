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
 * Oh, where to start....
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Sat, 13 Apr 2024 13:44:32 +0300
 */

`include "defines.vh"

module sdft #(
  parameter                 N          = 4048,
  parameter                 DW         = 16,
  parameter                 CW         = 16,
  parameter                 IDW        = 32,
  // Output bit width OW is always equals IDW. If the system requires different
  // bit width, there is another module (adjust_bitwidth) made for this purpose
  // and comes along with this module. Just use it after this module if
  // frequency domain data bit width is supposed to be other than IDW
  parameter                 OW         = IDW,
  parameter                 HANNING_EN = 0,
  // see ../README.md --> Stability / noise section
  parameter                 FIX_EN     = 1,
  parameter signed [DW-1:0] FIX        = {1'b0, `ones(DW-1)},
  parameter                 AW         = $clog2(N),
  // The default is external, because external dual port ROM with
  // twiddles can be shared with some other device
  parameter EXTERNAL_TWIDDLE_SOURCE    = "False",
  parameter TWIDDLE_ROM_FILE           = "none"
) (
  input                   clk_i,
  input                   srst_i,
  input                   sample_tick_i,
  // Input time domain data
  input signed  [DW-1:0]   data_i, // should be stable until next tick
  // Twiddle ROM interface
  output logic [AW-1:0]   twiddle_idx_o,
  input        [CW*2-1:0] twiddle_i,
  // Output frequency domain data
  output logic [OW*2-1:0] data_o,
  output logic            sob_o, // start of block
  output logic            eob_o, // end of block
  output logic            valid_o,
  output logic            sat_alarm_o
);

localparam RE = 0;
localparam IM = 1;

// Control
logic          active,  active_d;
logic [AW-1:0] counter, counter_d;
logic          sob, eob;
logic          pre_eob;
// Input / comb filter
logic        [AW-1:0]  xz_addr;
logic        [DW-1:0] data_d;
logic signed [DW-1 :0] xn;
logic signed [DW-1 :0] xz;
logic signed [DW   :0] comb;
// Resonator loop
logic signed [IDW  :0] y_comb_re_unsat;
logic signed [IDW-1:0] y_comb_re, y_comb_im;
logic signed [IDW-1:0] y_prev_re, y_prev_im ;
logic signed [IDW-1:0] y_re     , y_im      ;
logic signed [IDW-1:0] y_out_re , y_out_im  ;
logic signed [CW-1 :0] w_re     , w_im      ;
logic signed [CW-1 :0] w_re_fix,  w_im_fix;

//***************************************************************************
// Control

// Master counter. Controls the whole cycle
always_ff @( posedge clk_i )
  if( srst_i )
    counter <= '0;
  else
    if( active )
      counter <= counter + 1'b1;

always_ff @( posedge clk_i )
  counter_d <= counter;

assign active = sample_tick_i | ( counter != 0 );

always_ff @( posedge clk_i )
  active_d <= active;


always_ff @( posedge clk_i )
  sob <= sample_tick_i;

assign pre_eob = ( counter == N-1 );

always_ff @( posedge clk_i )
  eob <= pre_eob;

//***************************************************************************
// Input / comb filter

// If N = 2**I (I is int), we can implement a free running counter
always_ff @( posedge clk_i )
  if( srst_i )
    xz_addr <= '0;
  else
    //if( sample_tick_i )
    if( pre_eob )
      xz_addr <= xz_addr + 1'b1;


always_ff @( posedge clk_i )
  if( sample_tick_i )
    data_d <= data_i;

ram #(
  .DWIDTH         ( DW                          ),
  .AWIDTH         ( AW                          )
) xz_mem (
  .clk            ( clk_i                       ),
  .d              ( data_d                      ),
  .wraddr         ( xz_addr                     ),
  .wren           ( pre_eob                     ),
  .rdaddr         ( xz_addr                     ),
  .q              ( xz                          )
);

// Align data_i with xz, because xz appears on the next clock cycle
always_ff @( posedge clk_i )
  xn <= data_i;

generate
  if( FIX_EN )
    begin : comb_fix
      logic signed [DW*2-1:0] xz_mult;
      logic signed [DW  -1:0] xz_fix;
      assign xz_mult = xz * FIX;
      assign xz_fix  = xz_mult >>> (DW-1);
      assign comb    = xn - xz_fix;
    end // comb_fix
  else
    begin : no_comb_fix
      assign comb = xn - xz;
    end // no_comb_fix
endgenerate

//***************************************************************************
// Resonator loop

ram #(
  .DWIDTH         ( IDW*2                       ),
  .AWIDTH         ( AW                          )
) product_mem (
  .clk            ( clk_i                       ),
  .d              ( {y_im, y_re}                ),
  .wraddr         ( counter_d                   ),
  .wren           ( active_d                    ),
  .rdaddr         ( counter                     ),
  .q              ( {y_prev_im, y_prev_re}      )
);

// Because inside the rotator total twiddle power is less than 1, it can't
// increase values to make them overflow. The only place it could happen is
// here. We can't allow this to be anything but a really rare case because
// computation results are used recursively, and one saturation case brings much
// worse data corruption then just by itself. But anyway, it is better than
// overflow. Let's make an alarm for this case to adjust input level during the
// debug stage.
assign y_comb_re_unsat = y_prev_re + comb;
assign y_comb_im       = y_prev_im;

sat #( .IW(IDW+1), .OW(IDW) ) comb_sat ( y_comb_re_unsat, y_comb_re, sat_alarm_o );

generate
  if( FIX_EN )
    begin : twiddle_fix
      logic signed [CW+DW-1:0] w_re_mult, w_im_mult;
      assign w_re_mult = w_re * FIX;
      assign w_im_mult = w_im * FIX;
      assign w_re_fix  = w_re_mult >>> (DW-1);
      assign w_im_fix  = w_im_mult >>> (DW-1);
    end // twiddle_fix
  else
    begin : no_twiddle_fix
      assign w_re_fix = w_re;
      assign w_im_fix = w_im;
    end // no_twiddle_fix
endgenerate

rotator #(
  .N             ( N                    ),
  .DW            ( IDW                  ),
  .CW            ( CW                   )
) rotator (
  .x_re          ( y_comb_re            ),
  .x_im          ( y_comb_im            ),
  .c_re          ( w_re_fix             ),
  .c_im          ( w_im_fix             ),
  .y_re          ( y_re                 ),
  .y_im          ( y_im                 )
);

//**************************************************************************

generate
  if( HANNING_EN )
    begin : hanning
      // Hanning adds 1 sample delay on top
      hanning_fd #(
        .DW               ( IDW                        )
      ) hanning (
        .clk_i            ( clk_i                      ),
        .data_i           ( { y_prev_im, y_prev_re }   ),
        .sob_i            ( sob                        ),
        .eob_i            ( eob                        ),
        .valid_i          ( active_d                   ),
        .data_o           ( { y_out_im, y_out_re }     ),
        .sob_o            ( sob_o                      ),
        .eob_o            ( eob_o                      ),
        .valid_o          ( valid_o                    )
      );
    end // hanning
  else
    begin : no_hanning
      // In reference python model we blast to output block calculated right
      // here and now. Instead of this in Verilog we use older block. This will
      // cause 1 sample delay, but in other aspects it's absolutely equivalent.
      // This version implies shorter combinational circuits and and could
      // provide better timings
      assign { y_out_im, y_out_re } = { y_prev_im, y_prev_re };
      assign sob_o   = sob;
      assign eob_o   = eob;
      assign valid_o = active_d;
    end // no_hanning
endgenerate

assign data_o = { y_out_im, y_out_re };

//**************************************************************************

// You can use my cordic to generate twiddles instead of wasting memory:
// https://github.com/nekrasov-d/cordic-based-math#sine--cosine-generator

generate
  if( EXTERNAL_TWIDDLE_SOURCE != "True" )
    begin : internal_twiddle_rom
      rom #(
        .DWIDTH        ( CW*2                  ),
        .AWIDTH        ( AW                    ),
        .INIT_FILE     ( TWIDDLE_ROM_FILE      )
      ) twiddle_rom (
        .clk_i         ( clk_i                 ),
        .rdaddr_i      ( counter               ),
        .rddata_o      ( { w_im, w_re }        )
      );
    end // internal_twiddle_rom
  else
    begin : external_twiddle_rom
      assign twiddle_idx_o  = counter;
      assign { w_im, w_re } = twiddle_i;
    end // external_twiddle_rom
endgenerate

endmodule
