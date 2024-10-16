// W65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

`include "reg_mode.vinc"

module reg_mode
(
  input e16,
  input e8,
  input m,
  input x,
  output reg [2:0] size_m,
  output reg [2:0] size_x
);

// E16  E8   M   X    A    X,Y    Mode
//  0    0   0   0   16    32     W65C832 Native
//  0    0   0   1   16     8     W65C832 Native
//  0    0   1   0    8    32     W65C832 Native
//  0    0   1   1    8     8     W65C832 Native
//  0    1   0   0   32    32     W65C832 Native
//  0    1   0   1   32     8     W65C832 Native
//  0    1   1   0    8    32     W65C832 Native
//  0    1   1   1    8     8     W65C832 Native
//  1    0   0   0   16    16     W65C816 Emulation
//  1    0   0   1   16     8     W65C816 Emulation
//  1    0   1   0    8    16     W65C816 Emulation
//  1    0   1   1    8     8     W65C816 Emulation
//  1    1   1  BRK   8     8     W65C02  Emulation

always @ * begin
  if (e16 == 1) begin
    if (e8 == 1) begin
      size_m <= SIZE_8;
      size_x <= SIZE_8;
    end else begin
      size_m <= m == 0 ? SIZE_16 : SIZE_8;
      size_x <= x == 0 ? SIZE_16 : SIZE_8;
    end
  end else begin
    if (e8 == 1) begin
      size_m <= m == 0 ? SIZE_32 : SIZE_8;
    end else begin
      size_m <= m == 0 ? SIZE_16 : SIZE_8;
    end

    size_x <= x == 0 ? SIZE_32 : SIZE_8;
  end
end

endmodule

