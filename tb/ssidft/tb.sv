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

module tb;

// If you see a parameter and it is not declared here, then it is declated
`include "testbench_parameters.v" // <------ THERE (automatically generated)

string score; // This one is going to be sourced in an outer script

bit clk;
bit srst;
bit stop_flag;

logic signed [DATA_WIDTH-1:0] data_i;
logic signed [DATA_WIDTH-1:0] data_o;
logic signed [DATA_WIDTH-1:0] reference_data;
logic                         input_valid;
logic                         output_valid;

bit sob;
bit eob;
bit [$clog2(RADIX)-1:0] bin_counter;

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
  for( int i = 0; i < DATA_WIDTH; i++ )
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
  while( !$feof( f ) && !stop_flag )
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
      if( eob )
        begin
          input_valid <= 0;
          @( posedge clk );
        end
//      if( CLK_PER_SAMPLE > 1 )
//        begin
//          input_valid <= 0;
//          repeat (CLK_PER_SAMPLE) @( posedge clk );
//        end
    end
  init_input();
  $fclose(f);
  repeat (CLK_PER_SAMPLE) @( posedge clk );
  //stop_flag = 1;
endtask


task automatic monitor();
  int f;
  string data_str;
  f = $fopen( REF_DATA_FNAME, "r" );
  if( !f )
    $fatal( "can't open file with reference data" );
  while( !$feof( f ) )
    begin
      @( posedge clk );
      if( input_valid === 1'b1 )
        begin
          $fgets( data_str, f );
          if( data_str=="" )
            break;
          reference_data = $signed(data_str.atoi());
        end
      if( output_valid===1'b1 && check_for_x_states() )
        $fatal( "\n\n\nX-states were found at the output, exiting\n\n\n" );
    end
  $fclose(f);
  stop_flag = 1;
endtask


// Updates "score" string each cycle. Waits "done" signal terminate and let
// main process quit fork-join block
task automatic scoreboard( );
  int cnt, error, error_abs, max_error;
  longint error2_acc, ref2_acc;
  real nmse, peak_error;
  while( !stop_flag  )
    begin
      if( output_valid === 1'b1 )
        begin
          cnt++;
          error       = int'(reference_data) - int'(data_o);
          error2_acc += error*error;
          ref2_acc   += int'(reference_data)*int'(reference_data);
          nmse = 10.0*$log10( real'(error2_acc) / real'(ref2_acc) );
          error_abs = error > 0 ? error : -error;
          if( error_abs > max_error )
            max_error = error_abs;
          peak_error = ( real'(max_error) / real'(2**DATA_WIDTH)  ) * 100;
          $sformat( score, "%d samples processed, nmse: %f dB, peak error: %f %%", cnt, nmse, peak_error );
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

always_ff @( posedge clk )
  if( input_valid )
    bin_counter <= bin_counter + 1;

bit input_valid_d;
always_ff @( posedge clk )
  input_valid_d <= input_valid;

assign sob = ( { input_valid_d, input_valid } == 2'b01 );
assign eob = input_valid && bin_counter==(RADIX-1);

ssidft #(
  .DW                 ( DATA_WIDTH                  ),
  .N                  ( RADIX                       )
) DUT (
  .clk_i              ( clk                         ),
  .srst_i             ( srst                        ),
  .sob_i              ( sob                         ),
  .eob_i              ( eob                         ),
  .freq_re_i          ( data_i                      ),
  .freq_im_i          (                             ),
  .sample_o           ( data_o                      ),
  .sample_en_o        ( output_valid                )
);

endmodule


