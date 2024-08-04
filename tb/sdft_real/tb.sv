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
 * DSP Python-Verilog testbench template. Fits cases when DSP module is
 * systematically simple and have regular interface of input data, output data
 * with same bit width, input sample valid signal and output sample valid
 * signal. All it does is just translate parameters from higher level test
 * program and applies Python-generated data to input wires, monitors output
 * and collect some metrics (NMSE, peak error in %). It could be developed to do
 * some more complicated things, but this template is already pretty capable.
 * See more details in main README.md
 *
 *-- Dmitry Nekrasov <bluebag@yandex.ru> Thu, 21 Mar 2024 21:05:25 +0300
 */

`timescale 1ns/1ns

`define abs(X)   ( (X) >  0  ? (X) : -(X) )
`define max(X,Y) ( (X) > (Y) ? (X) :  (Y) )

module tb;

// If you see a parameter and it is not declared here, then it is declated
`include "parameters.v" // <------ THERE (automatically generated)

string score; // This one is going to be sourced in an outer script

bit clk;
bit srst;
bit stop_flag;

parameter IDW          = DATA_WIDTH*2;
parameter OUTPUT_WIDTH = IDW;

logic signed [DATA_WIDTH-1:0]     data_i;
logic signed [OUTPUT_WIDTH-1:0]   data_o;
logic signed [OUTPUT_WIDTH-1:0]   reference_data;
logic                             input_valid;
logic                             output_valid;

initial forever #1 clk = ~clk;

initial
  begin
    @( posedge clk ) srst = 1'b1;
    @( posedge clk ) srst = 1'b0;
  end

//***************************************************************************

task automatic init_input( );
  input_valid <= 0;
  data_i      <= 'x;
endtask


function automatic check_for_x_states();
  for( int i = 0; i < OUTPUT_WIDTH; i++ )
    if( data_o[i] === 1'bx )
      return 1;
  return 0;
endfunction


task automatic driver ();
  int f;
  string data_str;
  f = $fopen( TEST_DATA_FNAME, "r" );
  if( !f )
    $fatal( "can't open file with test data" );
  while( !$feof( f ) )
    begin
      $fgets( data_str, f );
      if( data_str=="" )
        begin
          init_input();
          break;
        end
      data_i      <= $signed(data_str.atoi());
      input_valid <= 1;
      @( posedge clk );
      if( CLK_PER_SAMPLE > 1 )
        begin
          input_valid <= 0;
          repeat (CLK_PER_SAMPLE) @( posedge clk );
        end
    end
  init_input();
  $fclose(f);
  repeat (CLK_PER_SAMPLE) @( posedge clk );
  stop_flag = 1;
endtask


event ev;

task automatic monitor();
  int f;
  string str;
  f = $fopen( REF_DATA_FNAME, "r" );
  if( !f )
    $fatal( "can't open file with reference data" );
  // Put first sample on wires before entering the loop
  $fgets( str, f );
  reference_data = $signed(str.atoi());
  while( !( $feof( f ) | stop_flag ) )
    begin
      if( output_valid === 1'b1 )
        begin
          if( check_for_x_states() )
             begin
               @( posedge clk );
               $fatal( "\n\n\nX-states were found at the output, exiting\n\n\n" );
             end
          $fgets( str, f );
          if( str=="" )
            break;
          reference_data = $signed(str.atoi());
        end
      @( posedge clk );
    end
  $fclose(f);
endtask


function automatic string nmse_str( real err, reference );
  if( err==0 )
    nmse_str = "? (empty error accumulator)";
  else if( reference==0 )
    nmse_str = "? (empty reference accumulator)";
  else
    $sformat( nmse_str, "%f", 10.0*$log10( err / reference ) );
endfunction

// Updates "score" string each cycle. Waits "done" signal terminate and let
// main process quit fork-join block
int error, max_error;
task automatic scoreboard( );
  int cnt;
  longint error2_acc, ref2_acc;
  string nmse;
  real peak_error;
  while( !stop_flag  )
    begin
      if( output_valid === 1'b1 )
        begin
          cnt++;
          error       = int'(reference_data) - int'(data_o);
          error2_acc += error*error;
          ref2_acc   += int'(reference_data)*int'(reference_data);
          nmse        = nmse_str( error2_acc, ref2_acc );
          max_error   = `max( max_error, `abs( error ) );
//          peak_error  = ( real'(max_error) / real'(2**OUTPUT_WIDTH)  ) * 100;
          $sformat( score, "%d samples processed, nmse : %s dB, peak error : %f %%",
            cnt, nmse, peak_error );
        end
      @( negedge clk );
    end
endtask


initial
  begin : main
    init_input();
    repeat ( CLK_PER_SAMPLE ) @( posedge clk );
    fork
      driver();
      monitor();
      scoreboard();
    join
    repeat( CLK_PER_SAMPLE ) @( posedge clk );
    if( TESTBENCH_MODE=="manual" )
      $display( "\n\n\n%s\n\n\n", score );
    $stop;
  end // main

//***************************************************************************

sdft #(
  .N                    ( RADIX                       ),
  .DW                   ( DATA_WIDTH                  ),
  .CW                   ( COEFFICIENT_WIDTH           ),
  .IDW                  ( IDW                         ),
  .IMAG_EN              ( 0                           ),
  .HANNING_EN           ( HANNING_EN                  ),
  .FIX_EN               ( 1                           ),
  .FIX                  ( 2**(DATA_WIDTH-1)-1         ),
  .SPECTRUM             ( "half"                      ),
  .TWIDDLE_ROM_FILE     ( "sdft_twiddles.mem"         )
) DUT (
  .clk_i                ( clk                         ),
  .srst_i               ( srst                        ),
  .sample_tick_i        ( input_valid                 ),
  .data_i               ( data_i                      ),
  .twiddle_idx_o        (                             ),
  .twiddle_i            (                             ),
  .data_o               ( data_o                      ),
  .sob_o                (                             ),
  .eob_o                (                             ),
  .valid_o              ( output_valid                ),
  .sat_alarm_o          (                             )
);

endmodule


