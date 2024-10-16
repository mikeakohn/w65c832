// 65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

// The purpose of this module is to route reads and writes to the 4
// different memory banks. Originally the idea was to have ROM and RAM
// be SPI EEPROM (this may be changed in the future) so there would also
// need a "ready" signal that would pause the CPU until the data can be
// clocked in and out of of the SPI chips.

module memory_bus
(
  input [15:0] address,
  input  [7:0] data_in,
  output [7:0] data_out,
  input bus_enable,
  input write_enable,
  input clk,
  input raw_clk,
  output speaker_p,
  output speaker_m,
  output ioport_0,
  output ioport_1,
  output ioport_2,
  output ioport_3,
  output ioport_4,
  input button_0,
  input reset,
  output spi_clk_0,
  output spi_mosi_0,
  input  spi_miso_0
);

wire [7:0] rom_data_out;
wire [7:0] ram_data_out;
wire [7:0] peripherals_data_out;
wire [7:0] block_ram_data_out;

//reg [7:0] ram_data_in;
//reg [7:0] peripherals_data_in;

wire ram_write_enable;
wire peripherals_write_enable;
wire block_ram_write_enable;

assign ram_write_enable         = (address[15:14] == 2'b00) && write_enable;
assign peripherals_write_enable = (address[15:14] == 2'b10) && write_enable;
assign block_ram_write_enable   = (address[15:14] == 2'b11) && write_enable;

// FIXME: The RAM probably need an enable also.
wire peripherals_enable;
assign peripherals_enable = (address[15:14] == 2'b10) && bus_enable;

// Based on the selected bank of memory (address[14:13]) select if
// memory should read from ram.v, rom.v, peripherals.v.
assign data_out = address[15] == 0 ?
  (address[14] == 0 ? ram_data_out         : rom_data_out) :
  (address[14] == 0 ? peripherals_data_out : block_ram_data_out);

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
  .spi_miso_0   (spi_miso_0)
);

ram ram_1(
  .address      (address[11:0]),
  .data_in      (data_in),
  .data_out     (block_ram_data_out),
  .write_enable (block_ram_write_enable),
  .clk          (raw_clk)
);

endmodule

