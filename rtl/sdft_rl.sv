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
 * Gauranteed stable SDFT version proposed by Rick Lyons and namend (_rl) after
 * him.
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Sat, 13 Apr 2024 13:44:32 +0300
 */

`include "defines.vh"

module sdft_rl #(
  parameter                 N          = 4096,
  parameter                 DW         = 16,
  parameter                 CW         = 16,
  parameter                 IDW        = 32,
  parameter                 IMAG_EN    = 1,
  // Output bit width OW is always equals IDW. If the system requires different
  // bit width, there is another module (adjust_bitwidth) made for this purpose
  // and comes along with this module. Just use it after this module if
  // frequency domain data bit width is supposed to be other than IDW
  parameter                 OW         = IMAG_EN ? IDW*2 : IDW,
  // Frequency domain hanning
  parameter                 HANNING_EN = 0,
  //
  parameter                 SPECTRUM   = "full", // "half"
  parameter                 AW         = SPECTRUM=="full" ? $clog2(N) : $clog2(N) - 1,
  // The default is external, because external dual port ROM with
  // twiddles can be shared with some other device
  parameter EXTERNAL_TWIDDLE_SOURCE    = "False",
  parameter TWIDDLE_ROM_FILE           = "none",
  parameter REGISTER_EN                = 0
) (
  input                   clk_i,
  input                   srst_i,
  input                   sample_tick_i,
  input                   clear_i,
  // Input time domain data
  input signed  [DW-1:0]  data_i, // should be stable until next tick
  // Twiddle ROM interface
  output logic [AW-1:0]   twiddle_idx_o, // = SPECTRUM=="full" ? [0-360) : [0-180) degrees
  input        [CW*2-1:0] twiddle_i, // { sin, cos }
  // Output frequency domain data
  output logic [OW-1:0]   data_o,
  output logic            sob_o, // start of block
  output logic            eob_o, // end of block
  output logic            valid_o,
  output logic            sat_alarm_o
);

/*
 * Code structure:
 *
 *      ***************************************
 *
 *         Control
 *
 *      ***************************************
 *
 *         Input / comb filter                   <--------- input
 *                                               --+
 *      ***************************************    |
 *                                               <-+
 *  +-->   Real resonator loop
 *  |                                            --+
 *  |   ***************************************    |
 *  |                                            <-+
 *  +-->   Feedforward stage
 *  |                                            --+
 *  |   ***************************************    |
 *  |                                            <-+
 *  |      Frequency domain output processing    ---------> output
 *  |
 *  |   ***************************************
 *  |
 *  +----- sin/cos source
 */

// XZ mem depth is always N words, whether we calculate full spectrum or only half
localparam XZ_MEM_AW = $clog2(N);
localparam LAST_FREQ = SPECTRUM=="full" ? (N-1) : (N/2-1);

// misc
logic sat_alarm_1;
logic sat_alarm_2;
assign sat_alarm_o = sat_alarm_1 | sat_alarm_2;

//***************************************************************************
// Control

logic          active,  active_d;
logic [AW-1:0] counter, counter_d;
logic          sob, eob;
logic          pre_eob;
logic          clear;

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

assign pre_eob = ( counter == LAST_FREQ );

always_ff @( posedge clk_i )
  eob <= pre_eob;


always_ff @( posedge clk_i )
  if( sample_tick_i )
    clear <= clear_i;

//***************************************************************************
// Input / comb filter

logic        [XZ_MEM_AW-1:0] xz_addr;
logic signed [DW-1 :0]       xn;
logic signed [DW-1 :0]       xz;
logic signed [DW   :0]       comb;

// If N = 2**I (I is int), we can implement a free running counter
always_ff @( posedge clk_i )
  if( srst_i )
    xz_addr <= '0;
  else
    //if( sample_tick_i )
    if( pre_eob | clear )
      xz_addr <= xz_addr + 1'b1;

// Align data_i with xz, because xz appears on the next clock cycle
always_ff @( posedge clk_i )
  if( sample_tick_i )
    xn <= clear ? '0 : data_i;

ram_sdft #(
  .DWIDTH         ( DW                          ),
  .AWIDTH         ( XZ_MEM_AW                   )
) xz_mem (
  .clk            ( clk_i                       ),
  .d              ( xn                          ),
  .wraddr         ( xz_addr                     ),
  .wren           ( pre_eob | clear             ),
  .rdaddr         ( xz_addr                     ),
  .q              ( xz                          )
);

assign comb = xn - xz;

//***************************************************************************
// Real resonator loop

logic signed [CW-1:0]   sin, cos;
logic signed [IDW+CW:0] y_z1_2cos_mult;
logic signed [IDW:0]    y_z1_2cos;
logic signed [IDW+1:0]  tmp_sum1;
logic signed [IDW+2:0]  tmp_sum2;
logic signed [IDW-1:0]  y, y_z1, y_z2;

ram_sdft #(
  .DWIDTH         ( IDW*2                       ),
  .AWIDTH         ( AW                          )
) resonators_memory (
  .clk            ( clk_i                       ),
  .d              ( clear ? '0 : { y_z1, y }    ),
  .wraddr         ( counter_d                   ),
  .wren           ( active_d                    ),
  .rdaddr         ( counter                     ),
  .q              ( { y_z2, y_z1 }              )
);

assign y_z1_2cos_mult = y_z1 * `s({ cos, 1'b0 });
assign y_z1_2cos      = y_z1_2cos_mult >> (CW-1);

assign tmp_sum1 = comb + y_z1_2cos;
assign tmp_sum2 = tmp_sum1 - y_z2;

sat_sdft #( .IW(IDW+3), .OW(IDW) ) y_sat ( tmp_sum2, y, sat_alarm_1 );

//**************************************************************************
// Feedforward stage

logic signed [IDW+CW-1:0] y_cos_mult;
logic signed [IDW+CW-1:0] y_sin_mult;
logic signed [IDW:0]      y_cos;
logic signed [IDW:0]      y_sin;
logic signed [IDW+1:0]    tmp_sum3;
logic signed [IDW-1:0]    fd_real;
logic signed [IDW-1:0]    fd_imag;

assign y_cos_mult = y * cos;
assign y_sin_mult = y * sin;
assign y_cos      = y_cos_mult >> (CW-1);
assign y_sin      = y_sin_mult >> (CW-1);
assign tmp_sum3   = y_cos - y_z1;

sat_sdft #( .IW(IDW+2), .OW(IDW) ) fd_real_sat ( tmp_sum3, fd_real, sat_alarm_2 );

assign fd_imag = y_sin;

//**************************************************************************
// Frequency domain output processing

// w is for wire
logic [OW-1:0] data_w;
logic sob_w, eob_w, valid_w;

generate
  if( HANNING_EN )
    begin : hanning
      // Hanning adds 1 sample delay on top
      logic [OW-1:0] data_to_hanning;
      assign data_to_hanning = IMAG_EN ? { fd_imag, fd_real } : fd_real;

      hanning_fd #(
        .DW               ( IDW                        ),
        .IMAG_PART_EN     ( IMAG_EN                    )
      ) hanning (
        .clk_i            ( clk_i                      ),
        .data_i           ( data_to_hanning            ),
        .sob_i            ( sob                        ),
        .eob_i            ( eob                        ),
        .valid_i          ( active_d                   ),
        .data_o           ( data_w                     ),
        .sob_o            ( sob_w                      ),
        .eob_o            ( eob_w                      ),
        .valid_o          ( valid_w                    )
      );
    end // hanning
  else
    begin : no_hanning
      // In reference python model we blast to output block calculated right
      // here and now. Instead of this in Verilog we use older block. This will
      // cause 1 sample delay, but in other aspects it's absolutely equivalent.
      // This version implies shorter combinational circuits and and could
      // provide better timings
      assign data_w  = IMAG_EN ? { fd_imag, fd_real } : fd_real;
      assign sob_w   = sob;
      assign eob_w   = eob;
      assign valid_w = active_d;
    end // no_hanning
endgenerate


generate
  if( REGISTER_EN )
    begin : reg_output
      always_ff @( posedge clk_i )
        { valid_o, sob_o, eob_o, data_o } <= { valid_w, sob_w, eob_w, data_w };
    end // reg_output
  else
    begin : comb_output
      always_comb
        { valid_o, sob_o, eob_o, data_o }  = { valid_w, sob_w, eob_w, data_w };
    end // comb_output
endgenerate

//**************************************************************************
// sin/cos source

// You can use my cordic to generate twiddles instead of wasting memory:
// ...

generate
  if( EXTERNAL_TWIDDLE_SOURCE != "True" )
    begin : internal_twiddle_rom
      rom_sdft #(
        .DWIDTH        ( CW*2                  ),
        .AWIDTH        ( AW                    ),
        .INIT_FILE     ( TWIDDLE_ROM_FILE      )
      ) twiddle_rom (
        .clk_i         ( clk_i                 ),
        .rdaddr_i      ( counter               ),
        .rddata_o      ( { sin, cos }          )
      );
    end // internal_twiddle_rom
  else
    begin : external_twiddle_rom
      assign twiddle_idx_o  = SPECTRUM=="full" ? counter : {1'b0, counter};
      assign { sin, cos } = twiddle_i;
    end // external_twiddle_rom
endgenerate


endmodule
