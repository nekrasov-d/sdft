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
 * General rom file with initializing parameter interface and implicit memory
 * type. rddata_o appers on bus on the next cycle for the address presented on
 * current cycle.
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Sun, 07 Apr 2024 14:10:40 +0300
 */

module rom #(
  parameter DWIDTH   = 16,
  parameter AWIDTH    = 9,
  parameter INIT_FILE = "some_file.mem"
) (
  input                     clk_i,
  input        [AWIDTH-1:0] rdaddr_i,
  output logic [DWIDTH-1:0] rddata_o
);

logic [DWIDTH-1:0] mem [2**AWIDTH-1:0];

initial $readmemh( INIT_FILE, mem );

always_ff @( posedge clk_i )
  rddata_o <= mem[rdaddr_i];

endmodule
