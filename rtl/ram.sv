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
 * Generic single port RAM. Data is presentet on the next clock cycle for the
 * address presented on the q on current clock cycle.
 *
 * Special feature is the ability to explicitly tell synthesizer which memory type
 * to use. For expamle, if you work with Intel chips with M10K memory blocks
 * and want to make sure it utilizes them, you need to edit this file and add block
 * with M10K explicit ramstyle attribute alike M9K block here.
 * Same for other vendors.
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Sun, 07 Apr 2024 14:10:40 +0300
 */

module ram #(
  parameter DWIDTH   = 16,
  parameter NWORDS   = 0, // <--+----one of these two must be set
  parameter AWIDTH   = 0, // <--+
  parameter RAMSTYLE = "M9K", // "logic", "default", etc
  // Internal parameters aligned NWORDS and AWIDTH wo you
  // may set only one of these
  parameter AWIDTH_  = AWIDTH == 0 ? $clog2(NWORDS) : AWIDTH,
  parameter NWORDS_  = NWORDS == 0 ? 2**AWIDTH      : NWORDS
) (
  input                     clk,
  input [AWIDTH_-1:0]       wraddr,
  input [AWIDTH_-1:0]       rdaddr,
  input                     wren,
  input [DWIDTH-1:0]        d,
  output logic [DWIDTH-1:0] q
);

generate
  if( RAMSTYLE=="default" )

    begin : default_memory
      logic [DWIDTH-1:0] mem [NWORDS_-1:0];
      // if it's a simulation, init memory with zeros
      // synopsys translate_off
        initial for( int i = 0; i < NWORDS_; i++ ) mem[i] = {DWIDTH{1'b0}};
      // synopsys translate_on
      always_ff @( posedge clk )
        if( wren )
          mem[wraddr] <= d;
      always_ff @( posedge clk )
        q <= mem[rdaddr];
    end // default_memory

  else if( RAMSTYLE=="logic" )
    begin : registers

      logic [DWIDTH-1:0] mem [NWORDS_-1:0] /* synthesis ramstyle = "logic" */;
      // synopsys translate_off
        initial for( int i = 0; i < NWORDS_; i++ ) mem[i] = {DWIDTH{1'b0}};
      // synopsys translate_on
      always_ff @( posedge clk )
        if( wren )
          mem[wraddr] <= d;
      always_ff @( posedge clk )
        q <= mem[rdaddr];
    end // registers

  else if( RAMSTYLE=="M9K" )
    begin : m9k_memory

      logic [DWIDTH-1:0] mem [NWORDS_-1:0] /* synthesis ramstyle = "M9K" */;
      // synopsys translate_off
        initial for( int i = 0; i < NWORDS_; i++ ) mem[i] = {DWIDTH{1'b0}};
      // synopsys translate_on
      always_ff @( posedge clk )
        if( wren )
          mem[wraddr] <= d;
      always_ff @( posedge clk )
        q <= mem[rdaddr];
    end // m9k_memory

  else
    begin
      // synopsys translate_off
        initial $fatal( "%m: Unknown ramstyle %s", RAMSTYLE );
      // synopsys translate_on
      assign q = 'z;
    end
endgenerate

endmodule

