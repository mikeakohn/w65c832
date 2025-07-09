// W65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024-2025 by Michael Kohn

// This creates 512 bytes of ROM on the FPGA itself and pages in the
// memory from an SD card. There is a maxiumum of 16MB in the first
// sectors that can be used starting at location 0xc000 on the card.

// @12MHz, this divides down by 120 to run the SPI bus at 100kHz.
// It might be possible later to remove the clock divide when reading
// sectors.

// This assumes the block size of the SD card is 512 bytes.
// It is also very minimal: Only sends commands for RESET and INIT
// on the card. When reading a block it doesn't bother reading the
// CRC.

module sd_card
(
  input [23:0] address,
  output reg [7:0] data_out,
  output reg busy,
  output reg spi_cs,
  output reg spi_clk,
  output reg spi_do,
  //output [15:0] debug,
  output reg [7:0] load_count,
  input  spi_di,
  input  enable,
  input  clk,
  input  reset
);

parameter STATE_INIT         = 0;
parameter STATE_SEND_RESET   = 1;
parameter STATE_SEND_INIT    = 2;
parameter STATE_CLOCK_0      = 3;
parameter STATE_CLOCK_0A     = 4;
parameter STATE_CLOCK_1      = 5;
parameter STATE_CLOCK_1A     = 6;
parameter STATE_IDLE         = 7;
parameter STATE_SD_COMMAND   = 8;
parameter STATE_START_SECTOR = 9;
parameter STATE_READ_SECTOR  = 10;
parameter STATE_FINISH       = 11;

reg [7:0] memory [511:0];
reg [3:0] state = STATE_INIT;
reg [3:0] next_state;
reg [3:0] cmd_return_state;
reg [3:0] cmd_count;
reg [8:0] mem_count;

reg [7:0] command [7:0];

reg [3:0] init_count;

reg [7:0] rx_buffer;
reg [7:0] tx_buffer;
reg [2:0] bit_count;
reg [5:0] bit_delay;

reg [5:0] bit_delay_max;

reg [15:0] current_page;
wire [14:0] page;
assign page = address[23:9];

//assign debug[15:8] = tx_buffer;
//assign debug[7:0] = { spi_cs, cmd_return_state };

always @(posedge clk) begin
  if (reset == 1) begin
    busy       <= 0;
    spi_cs     <= 1;
    init_count <= 10;
    load_count <= 0;
    current_page <= 16'h8000;
    bit_delay_max <= 60;
    state <= STATE_INIT;
  end else if (enable == 1) begin
    if (current_page == { 1'b0, page }) begin
      busy <= 0;
      data_out <= memory[address[8:0]];
    end else begin
      case (state)
        STATE_INIT:
          begin
            init_count <= init_count - 1;
            next_state <= STATE_INIT;

            busy <= 1;

            if (init_count == 0) begin
              cmd_count  <= 0;
              state      <= STATE_SEND_RESET;
            end else begin
              tx_buffer  <= 8'hff;
              bit_count  <= 0;
              state      <= STATE_CLOCK_0;
            end
          end
        STATE_SEND_RESET:
          begin
            command[0] <= 8'h40;
            command[1] <= 8'h00;
            command[2] <= 8'h00;
            command[3] <= 8'h00;
            command[4] <= 8'h00;
            command[5] <= 8'h95;
            command[6] <= 8'hff;
            command[7] <= 8'hff;

            cmd_return_state <= STATE_SEND_RESET;

            if (cmd_count[3] == 1) begin
              if (rx_buffer == 8'h01)
                state <= STATE_SEND_INIT;

              cmd_count <= 0;
              spi_cs    <= 1;
            end else begin
              spi_cs <= 0;
              state  <= STATE_SD_COMMAND;
            end
          end
        STATE_SEND_INIT:
          begin
            command[0] <= 8'h41;
            command[1] <= 8'h00;
            command[2] <= 8'h00;
            command[3] <= 8'h00;
            command[4] <= 8'h00;
            command[5] <= 8'h00;

            cmd_return_state <= STATE_SEND_INIT;

            if (cmd_count[3] == 1) begin
              if (rx_buffer[0] == 1'b0) begin
                state <= STATE_IDLE;
                //busy  <= 0;
              end

              cmd_count <= 0;
              spi_cs    <= 1;
              spi_do    <= 0;
            end else begin
              spi_cs <= 0;
              state  <= STATE_SD_COMMAND;
            end
          end
        STATE_CLOCK_0:
          begin
            spi_clk <= 0;

            tx_buffer <= tx_buffer << 1;
            spi_do <= tx_buffer[7];

            bit_count <= bit_count + 1;
            bit_delay <= 0;

            state <= STATE_CLOCK_0A;
          end
        STATE_CLOCK_0A:
          begin
            bit_delay <= bit_delay + 1;

            if (bit_delay == bit_delay_max)
              state <= STATE_CLOCK_1;
          end
        STATE_CLOCK_1:
          begin
            spi_clk <= 1;

            rx_buffer <= { rx_buffer[6:0], spi_di };
            bit_delay <= 0;

            state <= STATE_CLOCK_1A;
          end
        STATE_CLOCK_1A:
          begin
            bit_delay <= bit_delay + 1;

            if (bit_delay == bit_delay_max) begin
              if (bit_count == 0) begin
                state <= next_state;
                spi_clk <= 0;
              end else begin
                state <= STATE_CLOCK_0;
              end
            end
          end
        STATE_IDLE:
          begin
            if (enable) begin
              busy      <= 1;
              spi_cs    <= 0;

              bit_delay_max <= 0;

              command[0] <= 8'h51;
              command[1] <= 8'h00;
              command[2] <= address[23:16];
              command[3] <= { address[15:9], 1'b0 };
              command[4] <= 8'h00;
              command[5] <= 8'h00;

              load_count <= load_count + 1;

              cmd_count        <= 0;
              cmd_return_state <= STATE_START_SECTOR;
              next_state       <= STATE_SD_COMMAND;

              state <= STATE_SD_COMMAND;
            end
          end
        STATE_SD_COMMAND:
          begin
            next_state <= STATE_SD_COMMAND;

            if (cmd_count[3] == 1) begin
              tx_buffer <= 8'hff;
              state <= cmd_return_state;
            end else begin
              tx_buffer <= command[cmd_count];
              state <= STATE_CLOCK_0;
            end

            cmd_count <= cmd_count + 1;
          end
        STATE_START_SECTOR:
          begin
            // FIXME: Should another byte be read in first before
            // checking 0xfe? rx_buffer should have a status byte now
            // which shouldn't be 0xfe.
            if (rx_buffer == 8'hfe) begin
              mem_count  <= 0;
              next_state <= STATE_READ_SECTOR;
            end else begin
              next_state <= STATE_START_SECTOR;
            end

            tx_buffer <= 8'hff;
            state <= STATE_CLOCK_0;
          end
        STATE_READ_SECTOR:
          begin
            memory[mem_count] <= rx_buffer;

            // NOTE: Without setting tx_buffer on SPI, the card will error
            // out reading any more blocks.
            tx_buffer <= 8'hff;

            if (mem_count == 511)
              state <= STATE_FINISH;
            else
              state <= STATE_CLOCK_0;

            mem_count <= mem_count + 1;
          end
/*
        STATE_READ_CRC:
          begin
            next_state <= STATE_READ_CRC;

            tx_buffer <= 8'hff;

            if (mem_count == 2)
              state <= STATE_FINISH;
            else
              state <= STATE_CLOCK_0;

            mem_count <= mem_count + 1;
          end
*/
        STATE_FINISH:
          begin
            current_page <= { 1'b0, page };
            spi_cs <= 1;
            spi_do <= 0;
            state  <= STATE_IDLE;
          end
      endcase
    end
  end
end

endmodule

