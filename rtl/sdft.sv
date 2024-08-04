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
 * Wrapper for different architectures
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Sat, 13 Apr 2024 13:44:32 +0300
 */

`include "defines.vh"

module sdft #(
  parameter                 ARCHITECTURE = "default", // "rl"
  parameter                 N            = 4096,
  parameter                 DW           = 16,
  parameter                 CW           = 16,
  parameter                 IDW          = 32,
  parameter                 IMAG_EN      = 1,
  // Output bit width OW is always equals IDW. If the system requires different
  // bit width, there is another module (adjust_bitwidth) made for this purpose
  // and comes along with this module. Just use it after this module if
  // frequency domain data bit width is supposed to be other than IDW
  parameter                 OW           = IMAG_EN ? IDW*2 : IDW,
  // Frequency domain hanning
  parameter                 HANNING_EN   = 0,
  // see ../README.md --> Stability / noise section
  parameter                 FIX_EN       = 1,
  parameter signed [DW-1:0] FIX          = {1'b0, `ones(DW-1)},
  //
  parameter                 SPECTRUM     = "full", // "half"
  parameter                 AW           = SPECTRUM=="full" ? $clog2(N) : $clog2(N) - 1,
  // The default is external, because external dual port ROM with
  // twiddles can be shared with some other device
  parameter EXTERNAL_TWIDDLE_SOURCE      = "False",
  parameter TWIDDLE_ROM_FILE             = "none",
  parameter REGISTER_EN                  = 0
) (
  input                   clk_i,
  input                   srst_i,
  input                   sample_tick_i,
  input                   clear_i,
  // Input time domain data
  input signed  [DW-1:0]   data_i, // should be stable until next tick
  // Twiddle ROM interface
  output logic [AW-1:0]   twiddle_idx_o,
  input        [CW*2-1:0] twiddle_i,
  // Output frequency domain data
  output logic [OW-1:0]   data_o,
  output logic            sob_o, // start of block
  output logic            eob_o, // end of block
  output logic            valid_o,
  output logic            sat_alarm_o
);


generate
  if( ARCHITECTURE=="default" )
    begin : default_arch
      sdft_default #(
        .N                                      ( N                           ),
        .DW                                     ( DW                          ),
        .CW                                     ( CW                          ),
        .IDW                                    ( IDW                         ),
        .IMAG_EN                                ( IMAG_EN                     ),
        .HANNING_EN                             ( HANNING_EN                  ),
        .FIX_EN                                 ( FIX_EN                      ),
        .FIX                                    ( FIX                         ),
        .SPECTRUM                               ( SPECTRUM                    ),
        .EXTERNAL_TWIDDLE_SOURCE                ( EXTERNAL_TWIDDLE_SOURCE     ),
        .TWIDDLE_ROM_FILE                       ( TWIDDLE_ROM_FILE            ),
        .REGISTER_EN                            ( REGISTER_EN                 )
      ) sdft_default (
        .clk_i                                  ( clk_i                       ),
        .srst_i                                 ( srst_i                      ),
        .sample_tick_i                          ( sample_tick_i               ),
        .clear_i                                ( clear_i                     ),
        .data_i                                 ( data_i                      ),
        .twiddle_idx_o                          ( twiddle_idx_o               ),
        .twiddle_i                              ( twiddle_i                   ),
        .data_o                                 ( data_o                      ),
        .sob_o                                  ( sob_o                       ),
        .eob_o                                  ( eob_o                       ),
        .valid_o                                ( valid_o                     ),
        .sat_alarm_o                            ( sat_alarm_o                 )
      );
    end // default_arch
  else
    begin : rl_arch
      sdft_rl #(
        .N                                      ( N                           ),
        .DW                                     ( DW                          ),
        .CW                                     ( CW                          ),
        .IDW                                    ( IDW                         ),
        .IMAG_EN                                ( IMAG_EN                     ),
        .HANNING_EN                             ( HANNING_EN                  ),
        .SPECTRUM                               ( SPECTRUM                    ),
        .EXTERNAL_TWIDDLE_SOURCE                ( EXTERNAL_TWIDDLE_SOURCE     ),
        .TWIDDLE_ROM_FILE                       ( TWIDDLE_ROM_FILE            ),
        .REGISTER_EN                            ( REGISTER_EN                 )
      ) sdft_rl (
        .clk_i                                  ( clk_i                       ),
        .srst_i                                 ( srst_i                      ),
        .sample_tick_i                          ( sample_tick_i               ),
        .clear_i                                ( clear_i                     ),
        .data_i                                 ( data_i                      ),
        .twiddle_idx_o                          ( twiddle_idx_o               ),
        .twiddle_i                              ( twiddle_i                   ),
        .data_o                                 ( data_o                      ),
        .sob_o                                  ( sob_o                       ),
        .eob_o                                  ( eob_o                       ),
        .valid_o                                ( valid_o                     ),
        .sat_alarm_o                            ( sat_alarm_o                 )
      );
    end // rl_arch
endgenerate

endmodule
