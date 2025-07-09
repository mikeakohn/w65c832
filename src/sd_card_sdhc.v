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

module sd_card_sdhc
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
parameter STATE_SEND_CSD     = 2;
parameter STATE_SEND_CMD55   = 3;
parameter STATE_SEND_ACMD41  = 4;
parameter STATE_IDLE         = 5;
parameter STATE_SD_COMMAND   = 6;
parameter STATE_START_SECTOR = 7;
parameter STATE_READ_SECTOR  = 8;
parameter STATE_FINISH       = 9;
parameter STATE_CLOCK_0      = 10;
parameter STATE_CLOCK_0A     = 11;
parameter STATE_CLOCK_1      = 12;
parameter STATE_CLOCK_1A     = 13;

parameter STATE_HALT = 15;

reg [7:0] memory [511:0];
reg [3:0] state = STATE_INIT;
reg [3:0] spi_return_state;
reg [3:0] cmd_return_state;
reg [8:0] mem_count;

reg [5:0] command_ptr;
reg [4:0] command_len;

reg [4:0] cmd_count;

//reg [7:0] command [7:0];

reg [3:0] init_count;

reg [7:0] rx_buffer;
reg [7:0] tx_buffer;
reg [2:0] bit_count;

reg [5:0] bit_delay;
reg [5:0] bit_delay_max;

reg [15:0] current_page;
wire [15:0] page = address[23:9];

reg [7:0] sd_commands [43:0];

initial begin
  $readmemh("sd_commands.txt", sd_commands);
end

/*
sd_command_reset_cmd1:
  .db 0x40, 0x00, 0x00, 0x00, 0x00, 0x95, xx, xx  // 0
sd_command_csd_cmd8:
  .db 0x48, 0x00, 0x00, 0x01, 0xaa, 0x87, xx, xx, xx, xx, xx, xx  // 8
sd_command_app_spec_cmd55:
  .db 0x77, 0x00, 0x00, 0x00, 0x00, 0x00, xx, xx  // 20
sd_command_cond_acmd41:
  .db 0x69, 0x40, 0x00, 0x00, 0x00, 0x00, xx, xx  // 28
sd_command_read_0:
  .db 0x51, 0x00, 0x00, 0x00, 0x00, 0x00, xx, xx  // 36
*/

//reg [4:0] last_state;

//assign debug[15:8] = cmd_return_state;
//assign debug[7:0] = { spi_cs, state };

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
            spi_return_state <= STATE_INIT;

            busy <= 1;

            if (init_count == 0) begin
              cmd_count <= 0;
              state     <= STATE_SEND_RESET;
            end else begin
              tx_buffer <= 8'hff;
              bit_count <= 0;
              state     <= STATE_CLOCK_0;
            end
          end
        STATE_SEND_RESET:
          begin
            command_ptr <= 0;
            command_len <= 8;

            cmd_return_state <= STATE_SEND_RESET;

            if (cmd_count[3] == 1) begin
              if (rx_buffer == 8'h01)
                state <= STATE_SEND_CSD;

              cmd_count <= 0;
              spi_cs    <= 1;
            end else begin
              spi_cs <= 0;
              state  <= STATE_SD_COMMAND;
            end
          end
        STATE_SEND_CSD:
          begin
            command_ptr <= 8;
            command_len <= 12;

            cmd_return_state <= STATE_SEND_CSD;

            if (cmd_count != 0) begin
              state <= STATE_SEND_CMD55;

              spi_cs    <= 1;
              cmd_count <= 0;
            end else begin
              spi_cs <= 0;
              state  <= STATE_SD_COMMAND;
            end
          end
        STATE_SEND_CMD55:
          begin
            command_ptr <= 20;
            command_len <= 8;

            cmd_return_state <= STATE_SEND_CMD55;

            if (cmd_count != 0) begin
              state <= STATE_SEND_ACMD41;

              cmd_count <= 0;
              spi_cs    <= 1;
            end else begin
              spi_cs <= 0;
              state  <= STATE_SD_COMMAND;
            end
          end
        STATE_SEND_ACMD41:
          begin
            command_ptr <= 28;
            command_len <= 8;

            cmd_return_state <= STATE_SEND_ACMD41;

            if (cmd_count != 0) begin
              state <= rx_buffer[0] == 1'b0 ? STATE_IDLE : STATE_SEND_CMD55;

              spi_cs    <= 1;
              cmd_count <= 0;
              spi_do    <= 0;
            end else begin
              spi_cs <= 0;
              state  <= STATE_SD_COMMAND;
            end
          end
        STATE_IDLE:
          begin
            if (enable) begin
              busy      <= 1;
              spi_cs    <= 0;

              bit_delay_max <= 0;

              // Start of command is 36.
              //sd_commands[39] <= { 1'b0, address[23:17] };
              //sd_commands[40] <= address[16:9];

              command_ptr <= 36;
              command_len <= 8;

              load_count <= load_count + 1;

              cmd_count        <= 0;
              cmd_return_state <= STATE_START_SECTOR;
              spi_return_state <= STATE_SD_COMMAND;

              state <= STATE_SD_COMMAND;
            end
          end
        STATE_SD_COMMAND:
          begin
            spi_return_state <= STATE_SD_COMMAND;

            if (cmd_count == command_len) begin
              state  <= cmd_return_state;
            end else begin
              case (command_ptr)
                39: tx_buffer <= page[15:8];
                40: tx_buffer <= page[7:0];
                default: tx_buffer <= sd_commands[command_ptr];
              endcase

              state <= STATE_CLOCK_0;
            end

            command_ptr <= command_ptr + 1;
            cmd_count   <= cmd_count   + 1;
          end
        STATE_START_SECTOR:
          begin
            // FIXME: Should another byte be read in first before
            // checking 0xfe? rx_buffer should have a status byte now
            // which shouldn't be 0xfe.
            if (rx_buffer == 8'hfe) begin
              mem_count  <= 0;
              spi_return_state <= STATE_READ_SECTOR;
            end else begin
              spi_return_state <= STATE_START_SECTOR;
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
        STATE_FINISH:
          begin
            current_page <= { 1'b0, page };
            spi_cs <= 1;
            spi_do <= 0;
            state  <= STATE_IDLE;
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
                spi_clk <= 0;
                state <= spi_return_state;
              end else begin
                state <= STATE_CLOCK_0;
              end
            end
          end
      endcase
    end
  end
end

endmodule

