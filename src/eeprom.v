// 65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

// This module reads from an AT93C86A EEPROM chip.
// Data format: 110 AAAAAAAAAA DDDDDDDD where:
// Binary 110 is 3 bits telling the EEPROM to go into "read" mode.
// AAAAAAAAAA is 10 bits of the memory address being requested.
// DDDDDDDD is 8 bits clocked out of the EEPROM being the data at that address.

module eeprom
(
  input [10:0] address,
  input  strobe,
  input  raw_clk,
  output reg eeprom_cs,
  output reg eeprom_clk,
  output reg eeprom_di,
  input  eeprom_do,
  output reg ready,
  output reg [7:0] data_out
);

reg [2:0] state = 0;
reg [2:0] clock_div;
wire clk;
assign clk = clock_div[2];

reg [13:0] command;
reg [3:0] count;

parameter STATE_IDLE           = 0;
parameter STATE_SEND_ADDRESS_0 = 1;
parameter STATE_SEND_ADDRESS_1 = 2;
parameter STATE_READ_START     = 3;
parameter STATE_READ_DATA_0    = 4;
parameter STATE_READ_DATA_1    = 5;
parameter STATE_FINISH         = 6;

// To run the AT93C86A at a speed slower than 2MHz, divide the clock down.
always @(posedge raw_clk) begin
  clock_div <= clock_div + 1;
end

// State machine for reading the SPI-like EEPROM.
always @(posedge clk) begin
  case (state)
    STATE_IDLE:
      begin
        // Wait for the CPU to strobe to start a read.
        if (strobe) begin
          command[13:11] <= 3'b110;
          command[10:0] <= address;
          count <= 14;
          ready <= 0;
          eeprom_cs <= 1;
          state <= STATE_SEND_ADDRESS_0;
        end else begin
          eeprom_cs <= 0;
          eeprom_di <= 0;
          eeprom_clk <= 0;
          ready <= 1;
        end
      end
    STATE_SEND_ADDRESS_0:
      begin
        // Clock out 3 bits of command and 10 bytes of
        // address to the EEPROM.
        count <= count - 1;
        eeprom_di <= command[13];
        eeprom_clk <= 0;
        state <= STATE_SEND_ADDRESS_1;
      end
    STATE_SEND_ADDRESS_1:
      begin
        eeprom_clk <= 1;

        if (count == 0) begin
          state <= STATE_READ_START;
        end else begin
          command[13:1] <= command[12:0];
          state <= STATE_SEND_ADDRESS_0;
        end
      end
    STATE_READ_START:
      begin
        eeprom_clk <= 0;
        eeprom_di <= 0;
        count <= 8;
        state <= STATE_READ_DATA_0;
      end
    STATE_READ_DATA_0:
      begin
        // Clock in 8 bits of data from the EEPROM.
        count <= count - 1;
        data_out[7:1] <= data_out[6:0];
        eeprom_clk <= 1;
        state <= STATE_READ_DATA_1;
      end
    STATE_READ_DATA_1:
      begin
        data_out[0] <= eeprom_do;
        eeprom_clk <= 0;

        if (count == 0) begin
          state <= STATE_FINISH;
        end else begin
          state <= STATE_READ_DATA_0;
        end
      end
    STATE_FINISH:
      begin
        // Go back to IDLE state where the ready signal will tell the
        // the CPU that data is available.
        eeprom_cs <= 0;
        eeprom_di <= 0;
        state <= STATE_IDLE;
      end
  endcase
end

endmodule

