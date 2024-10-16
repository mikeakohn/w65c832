// W65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

// This creates 1024 bytes of ROM on the FPGA itself which begins at 0x0000.

module rom
(
  input [11:0] address,
  output reg [7:0] data_out,
  input clk
);

reg [7:0] memory [4095:0];

initial begin
  $readmemh("rom.txt", memory);
end

always @(posedge clk) begin
  data_out <= memory[address[9:0]];
end

endmodule

