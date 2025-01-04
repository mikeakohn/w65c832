// W65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024-2025 by Michael Kohn

// The purpose of this module is to route reads and writes to the 4
// different memory banks. Originally the idea was to have ROM and RAM
// be SPI EEPROM (this may be changed in the future) so there would also
// need a "ready" signal that would pause the CPU until the data can be
// clocked in and out of of the SPI chips.

module memory_bus
(
  input [23:0] address,
  input  [7:0] data_in,
  output reg [7:0] data_out,
  input  bus_enable,
  input  write_enable,
  output bus_halt,
  input  clk,
  input  raw_clk,
  output speaker_p,
  output speaker_m,
  output ioport_0,
  output ioport_1,
  output ioport_2,
  output ioport_3,
  output ioport_4,
  input  button_0,
  output spi_clk_0,
  output spi_mosi_0,
  input  spi_miso_0,
  output spi_cs_1,
  output spi_clk_1,
  output spi_mosi_1,
  input  spi_miso_1,
  output uart_tx_0,
  input  uart_rx_0,
  output windbond_reset,
  output windbond_wp,
  output windbond_di,
  input  windbond_do,
  output windbond_clk,
  output windbond_cs,
  input  reset
);

wire [7:0] rom_data_out;
wire [7:0] ram_data_out;
wire [7:0] peripherals_data_out;
//wire [7:0] block_ram_data_out;
wire [7:0] flash_rom_data_out;

//reg [7:0] ram_data_in;
//reg [7:0] peripherals_data_in;

wire [1:0] bank;
wire [7:0] upper_page;
assign bank = address[15:14];
assign upper_page = address[23:16];

wire ram_write_enable;
wire peripherals_write_enable;
//wire block_ram_write_enable;
wire flash_rom_enable;

assign ram_write_enable         = (bank == 0 && upper_page == 0) && write_enable;
assign peripherals_write_enable = (bank == 2 && upper_page == 0) && write_enable;
//assign block_ram_write_enable   = (bank == 3) && write_enable;

// FIXME: bus_enable really should be true here.
assign flash_rom_enable = (bank == 3 || upper_page != 0) && bus_enable;
//assign flash_rom_enable = (bank == 3 || upper_page != 0);

// FIXME: The RAM probably need an enable also.
wire peripherals_enable;
assign peripherals_enable = (bank == 2 && upper_page == 0) && bus_enable;

// FIXME: This probably shouldn't depend on flash_rom being enabled.
wire flash_rom_busy;
assign bus_halt = flash_rom_enable && flash_rom_busy;

// Based on the selected bank of memory (address[14:13]) select if
// memory should read from ram.v, rom.v, peripherals.v.
//assign data_out = address[15] == 0 ?
//  (address[14] == 0 ? ram_data_out         : rom_data_out) :
//  (address[14] == 0 ? peripherals_data_out : flash_rom_data_out);

always @ * begin
  if (bank == 3 || upper_page != 0) begin
    data_out = flash_rom_data_out;
  end else if (bank == 0) begin
    data_out = ram_data_out;
  end else if (bank == 1) begin
    data_out = rom_data_out;
  end else if (bank == 2) begin
    data_out = peripherals_data_out;
  end
end

ram ram_0(
  .address      (address[11:0]),
  .data_in      (data_in),
  .data_out     (ram_data_out),
  .write_enable (ram_write_enable),
  .clk          (raw_clk)
);

rom rom_0(
  .address   (address[11:0]),
  .data_out  (rom_data_out),
  .clk   (raw_clk)
);

peripherals peripherals_0(
  .enable       (peripherals_enable),
  .address      (address[5:0]),
  .data_in      (data_in),
  .data_out     (peripherals_data_out),
  .write_enable (peripherals_write_enable),
  .clk          (clk),
  .raw_clk      (raw_clk),
  .speaker_p    (speaker_p),
  .speaker_m    (speaker_m),
  .ioport_0     (ioport_0),
  .ioport_1     (ioport_1),
  .ioport_2     (ioport_2),
  .ioport_3     (ioport_3),
  .ioport_4     (ioport_4),
  .button_0     (button_0),
  .reset        (reset),
  .spi_clk_0    (spi_clk_0),
  .spi_mosi_0   (spi_mosi_0),
  .spi_miso_0   (spi_miso_0),
  .spi_cs_1     (spi_cs_1),
  .spi_clk_1    (spi_clk_1),
  .spi_mosi_1   (spi_mosi_1),
  .spi_miso_1   (spi_miso_1),
  .uart_tx_0    (uart_tx_0),
  .uart_rx_0    (uart_rx_0)
);

/*
ram ram_1(
  .address      (address[11:0]),
  .data_in      (data_in),
  .data_out     (block_ram_data_out),
  .write_enable (block_ram_write_enable),
  .clk          (raw_clk)
);
*/

flash_rom flash_rom_0(
  //.page        (address[23:12]),
  //.address     (address[11:0]),
  .address     (address[23:0]),
  .data_out    (flash_rom_data_out),
  .busy        (flash_rom_busy), 
  .spi_cs      (windbond_cs),
  .spi_clk     (windbond_clk),
  .spi_do      (windbond_di),
  .spi_di      (windbond_do),
  .enable      (flash_rom_enable),
  .flash_reset (windbond_reset),
  .flash_wp    (windbond_wp),
  .clk         (raw_clk),
  .reset       (reset)
);

endmodule

