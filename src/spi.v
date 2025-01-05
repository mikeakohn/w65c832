// W65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024-2025 by Michael Kohn

module spi
(
  input  raw_clk,
  input  [2:0] divisor,
  input  start,
  input  [7:0] data_tx,
  output [7:0] data_rx,
  output reg busy,
  output reg sclk,
  output reg mosi,
  input  miso
);

reg [1:0] state = 0;
reg [7:0] rx_buffer;
reg [7:0] tx_buffer;
reg [2:0] count;
reg [7:0] div_count;

parameter STATE_IDLE    = 0;
parameter STATE_CLOCK_0 = 1;
parameter STATE_CLOCK_1 = 2;
parameter STATE_LAST    = 3;

assign data_rx = rx_buffer;
//assign busy = state != STATE_IDLE;
//assign busy = state != STATE_IDLE || start == 1;

wire clk;
assign clk = divisor == 0 ? raw_clk : div_count[divisor];

always @(posedge raw_clk) begin
  div_count <= div_count + 1;
end

always @(posedge clk) begin
  case (state)
    STATE_IDLE:
      begin
        if (start) begin
          tx_buffer <= data_tx;

          state <= STATE_CLOCK_0;
          count <= 0;
          busy <= 1;
        end else begin
          mosi <= 0;
          busy <= 0;
        end
      end
    STATE_CLOCK_0:
      begin
        sclk <= 0;

        if (count != 0) rx_buffer <= { rx_buffer[6:0], miso };

        tx_buffer <= tx_buffer << 1;
        mosi <= tx_buffer[7];

        count <= count + 1;
        state <= STATE_CLOCK_1;
      end
    STATE_CLOCK_1:
      begin
        sclk <= 1;

        if (count == 0) begin
          state <= STATE_LAST;
        end else begin
          state <= STATE_CLOCK_0;
        end
      end
    STATE_LAST:
      begin
        sclk <= 0;
        rx_buffer <= { rx_buffer[6:0], miso };
        state <= STATE_IDLE;
      end
  endcase
end

endmodule

