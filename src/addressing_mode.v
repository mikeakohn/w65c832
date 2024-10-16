// W65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

`include "addressing_mode.vinc"

module addressing_mode
(
  input [1:0] cc,
  input [2:0] bbb,
  input [2:0] aaa,
  output reg [2:0] mode,
  output reg [2:0] ea_size
);

always @ * begin
  case (cc)
    2'b00:
      begin
        case (bbb)
          3'b000:
            begin
              mode <= MODE_IMMEDIATE;
              ea_size <= 1;
            end
          3'b001:
            begin
              mode <= MODE_ZP;
              ea_size <= 1;
            end
          3'b010:
            begin
              mode <= MODE_NONE;
              ea_size <= 0;
            end
          3'b011:
            begin
              mode <= MODE_ABSOLUTE;
              ea_size <= 2;
            end
          3'b100:
            begin
              mode <= MODE_NONE;
              ea_size <= 1;
            end
          3'b101:
            begin
              if (aaa == 3'b000)
                mode <= MODE_ZP;
              else
                mode <= MODE_INDEXED_X;
              ea_size <= 1;
            end
          3'b110:
            begin
              mode <= MODE_NONE;
              ea_size <= 1;
            end
          3'b111:
            begin
              if (aaa == 3'b000 || aaa == 3'b100)
                mode <= MODE_ABSOLUTE;
              else
                mode <= MODE_ABSOLUTE_X;
              ea_size <= 2;
            end
        endcase
      end
    2'b01:
      begin
        case (bbb)
          3'b000:
            begin
              mode <= MODE_INDIRECT_X;
              ea_size <= 1;
            end
          3'b001:
            begin
              mode <= MODE_ZP;
              ea_size <= 1;
            end
          3'b010:
            begin
              mode <= MODE_IMMEDIATE;
              ea_size <= 0;
            end
          3'b011:
            begin
              mode <= MODE_ABSOLUTE;
              ea_size <= 2;
            end
          3'b100:
            begin
              mode <= MODE_INDIRECT_Y;
              ea_size <= 1;
            end
          3'b101:
            begin
              mode <= MODE_INDEXED_X;
              ea_size <= 1;
            end
          3'b110:
            begin
              mode <= MODE_ABSOLUTE_Y;
              ea_size <= 2;
            end
          3'b111:
            begin
              mode <= MODE_ABSOLUTE_X;
              ea_size <= 2;
            end
        endcase
      end
    2'b10:
      begin
        case (bbb)
          3'b000:
            begin
              mode <= MODE_IMMEDIATE;
              ea_size <= 0;
            end
          3'b001:
            begin
              mode <= MODE_ZP;
              ea_size <= 1;
            end
          3'b010:
            begin
              mode <= MODE_A;
              ea_size <= 0;
            end
          3'b011:
            begin
              mode <= MODE_ABSOLUTE;
              ea_size <= 2;
            end
          3'b101:
            begin
              mode <= MODE_INDEXED_X;
              ea_size <= 1;
            end
          3'b111:
            begin
              mode <= MODE_ABSOLUTE_Y;
              ea_size <= 2;
            end
          default:
            begin
              mode <= MODE_NONE;
              ea_size <= 0;
            end
        endcase
      end
    2'b11:
      begin
        case (bbb)
          3'b000:
            begin
              mode <= MODE_IMMEDIATE;
              ea_size <= 0;
            end
          3'b001:
            begin
              mode <= MODE_ZP;
              ea_size <= 1;
            end
          3'b011:
            begin
              mode <= MODE_ABSOLUTE;
              ea_size <= 2;
            end
          3'b101:
            begin
              mode <= MODE_INDEXED_X;
              ea_size <= 1;
            end
          3'b111:
            begin
              mode <= MODE_ABSOLUTE_X;
              ea_size <= 2;
            end
          default:
            begin
              mode <= MODE_NONE;
              ea_size <= 0;
            end
        endcase
      end
  endcase
end

endmodule

