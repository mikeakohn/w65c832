// W65C832 FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

`include "addressing_mode.vinc"
`include "reg_mode.vinc"

module w65c832
(
  output [7:0] leds,
  output [3:0] column,
  input raw_clk,
  //output eeprom_cs,
  //output eeprom_clk,
  //output eeprom_di,
  //input  eeprom_do,
  output windbond_reset,
  output windbond_wp,
  output windbond_di,
  input  windbond_do,
  output windbond_clk,
  output windbond_cs,
  output speaker_p,
  output speaker_m,
  output ioport_0,
  output ioport_1,
  output ioport_2,
  output ioport_3,
  output ioport_4,
  input  button_reset,
  input  button_halt,
  input  button_program_select,
  input  button_0,
  output spi_clk_0,
  output spi_mosi_0,
  input  spi_miso_0
);

// iceFUN 8x4 LEDs used for debugging.
reg [7:0] leds_value;
reg [3:0] column_value;

assign leds = leds_value;
assign column = column_value;

// Memory bus (ROM, RAM, peripherals).
reg [23:0] mem_address = 0;
reg [7:0]  mem_write = 0;
wire [7:0] mem_read;
reg mem_write_enable = 0;
reg mem_bus_enable = 0;
reg mem_bus_reset = 1;
wire mem_bus_halted;

// FIXME: Can remove this later.
//reg was_ever_halted = 0;

// Clock.
reg [21:0] count = 0;
reg [5:0]  state = 0;
reg [5:0]  next_state = 0;
reg [5:0]  wb_state = 0;
reg [19:0] clock_div;
reg [14:0] delay_loop;
wire clk;

// Lower this (down to one) to increase speed.
assign clk = clock_div[1];

// Registers and stack.
// A, X, Y.
// Stack Pointer.
// Direct Register.
// Data Bank.
reg [31:0] reg_a;
reg [31:0] reg_x;
reg [31:0] reg_y;
reg [15:0] sp;
reg [15:0] dr;
reg [7:0] pbr;
reg [7:0] dbr;

wire [2:0] size_m;
wire [2:0] size_x;
wire is_emulation_8;
wire is_emulation_16;

reg [2:0] size_imm;
//reg [2:0] size_wb;

//assign size_m = flag_m == 1 ? SIZE_8 : (flag_e8  == 0 ? SIZE_16 : SIZE_32);
//assign size_x = flag_x == 1 ? SIZE_8 : (flag_e16 == 0 ? SIZE_32 : SIZE_16);

assign is_emulation_8  = flag_e8 == 1 && flag_e16 == 1;
assign is_emulation_16 = flag_e8 == 0 && flag_e16 == 1;

wire [3:0] size_setting;
assign size_setting = { flag_e16, flag_e8, flag_m, flag_x };

// Program counter, instruction, effective address.
reg [7:0]  instruction;
reg [7:0]  bank = 0;
reg [15:0] pc = 0;
reg [23:0] ea = 0;
reg [15:0] ea_indirect;

wire [1:0] cc;
wire [2:0] bbb;
wire [2:0] aaa;
assign cc  = instruction[1:0];
assign bbb = instruction[4:2];
assign aaa = instruction[7:5];

// reg_x or reg_y for indexed.
reg [31:0] offset;

// Used for ALU.
reg [31:0] source;
reg [31:0] temp;
reg [32:0] result;
reg wb;
reg is_sub;

// Used for MVP, MVN.
reg [7:0] block_source;
//reg [23:0] block_source;
//reg [15:0] block_destination;

// Addressing mode.
wire [2:0] addressing_mode;
wire [2:0] ea_size;
reg        indirect_count;
reg  [2:0] absolute_count;
reg  [2:0] immediate_count;
reg  [2:0] push_count;
reg  [2:0] pop_count;
reg  [2:0] wb_count;

// Branches.
reg do_branch;
reg long_branch;
reg [7:0] branch_offset;

// Flags.
parameter FLAG_PENDING_INTERRUPT = 10;
parameter FLAG_E16 = 9;
parameter FLAG_E8  = 8;
parameter FLAG_N   = 7;
parameter FLAG_V   = 6;
parameter FLAG_M   = 5;
parameter FLAG_X   = 4;
parameter FLAG_D   = 3;
parameter FLAG_I   = 2;
parameter FLAG_Z   = 1;
parameter FLAG_C   = 0;

parameter FLAG_B   = 4;

reg [10:0] flags;

wire flag_pending_interrupt;
wire flag_e16;
wire flag_e8;
wire flag_n;
wire flag_v;
wire flag_m;
wire flag_x; // flag_b in 8 bit emulation mode.
wire flag_d;
wire flag_i;
wire flag_z;
wire flag_c;

assign flag_pending_interrupt = flags[FLAG_PENDING_INTERRUPT];
assign flag_e16 = flags[FLAG_E16];
assign flag_e8  = flags[FLAG_E8];
assign flag_n   = flags[FLAG_N];
assign flag_v   = flags[FLAG_V];
assign flag_m   = flags[FLAG_M];
assign flag_x   = flags[FLAG_X];
assign flag_d   = flags[FLAG_D];
assign flag_i   = flags[FLAG_I];
assign flag_z   = flags[FLAG_Z];
assign flag_c   = flags[FLAG_C];

// Eeprom.
reg  [8:0] eeprom_count;
wire [7:0] eeprom_data_out;
reg [10:0] eeprom_address;
reg eeprom_strobe = 0;
wire eeprom_ready;

// Debug.
//reg [7:0] debug_0 = 0;
//reg [7:0] debug_1 = 0;
//reg [7:0] debug_2 = 0;
//reg [7:0] debug_3;

parameter STATE_RESET             = 0;
parameter STATE_DELAY_LOOP        = 1;
parameter STATE_FETCH_OP_0        = 2;
parameter STATE_FETCH_OP_1        = 3;
parameter STATE_DECODE            = 4;

parameter STATE_FETCH_INDIRECT_0  = 5;
parameter STATE_FETCH_INDIRECT_1  = 6;
parameter STATE_FETCH_INDIRECT_2  = 7;
parameter STATE_FETCH_INDIRECT_3  = 8;
parameter STATE_FETCH_INDIRECT_Y  = 9;
parameter STATE_FETCH_ABSOLUTE_0  = 10;
parameter STATE_FETCH_ABSOLUTE_1  = 11;
parameter STATE_FETCH_DIRECT_PAGE = 12;
parameter STATE_FETCH_INDEXED     = 13;
parameter STATE_FETCH_IMMEDIATE_0 = 14;
parameter STATE_FETCH_IMMEDIATE_1 = 15;

parameter STATE_EXECUTE_00_0      = 16;
parameter STATE_EXECUTE_00_1      = 17;

parameter STATE_EXECUTE_01_0      = 18;
parameter STATE_EXECUTE_01_1      = 19;

parameter STATE_EXECUTE_10_0      = 20;
parameter STATE_EXECUTE_10_1      = 21;

parameter STATE_WRITEBACK_A       = 22;
parameter STATE_WRITEBACK_X       = 23;
parameter STATE_WRITEBACK_Y       = 24;

parameter STATE_WRITEBACK_MEM_P   = 25;
parameter STATE_WRITEBACK_MEM_0   = 26;
parameter STATE_WRITEBACK_MEM_1   = 27;

parameter STATE_BRANCH_0          = 28;
parameter STATE_BRANCH_1          = 29;

parameter STATE_SET_FLAGS_0       = 30;
parameter STATE_SET_FLAGS_1       = 31;

parameter STATE_PUSH_0            = 32;
parameter STATE_PUSH_1            = 33;
parameter STATE_PUSH_2            = 34;

parameter STATE_POP_0             = 35;
parameter STATE_POP_1             = 36;
parameter STATE_POP_WB            = 37;

parameter STATE_JUMP_LONG         = 38;
parameter STATE_CALC_PER          = 39;
parameter STATE_CALC_PEI_0        = 40;
parameter STATE_CALC_PEI_1        = 41;

parameter STATE_RTI_0             = 42;
parameter STATE_RTI_1             = 43;

parameter STATE_STZ               = 44;

parameter STATE_MOVE_BLOCK_0      = 45;
parameter STATE_MOVE_BLOCK_1      = 46;
parameter STATE_MOVE_BLOCK_2      = 47;
parameter STATE_MOVE_BLOCK_3      = 48;
parameter STATE_MOVE_BLOCK_4      = 49;
parameter STATE_MOVE_BLOCK_5      = 50;

parameter STATE_TEST_BITS         = 51;

parameter STATE_JMP_ABS_0         = 52;
parameter STATE_JMP_ABS_1         = 53;
parameter STATE_JMP_ABS_2         = 54;
parameter STATE_JMP_ABS_3         = 55;

parameter STATE_EEPROM_START      = 57;
parameter STATE_EEPROM_READ       = 58;
parameter STATE_EEPROM_WAIT       = 59;
parameter STATE_EEPROM_WRITE      = 60;
parameter STATE_EEPROM_DONE       = 61;
parameter STATE_ERROR             = 62;
parameter STATE_HALTED            = 63;

// Instruction format: aaabbbcc

// c = 00 aaa = op, bbb = mode
parameter OP_TSB     = 3'b000;
parameter OP_TRB     = 3'b000;

// c = 00 aaa = op, bbb = mode
parameter OP_BIT     = 3'b001;
parameter OP_JMP     = 3'b010; // jmp ADDRESS
parameter OP_JMP_IND = 3'b011; // jmp (ADDRESS)
parameter OP_STY     = 3'b100;
parameter OP_LDY     = 3'b101;
parameter OP_CPY     = 3'b110;
parameter OP_CPX     = 3'b111;

parameter OP_BPL     = 3'b000;
parameter OP_BMI     = 3'b001;
parameter OP_BVC     = 3'b010;
parameter OP_BVS     = 3'b011;
parameter OP_BCC     = 3'b100;
parameter OP_BCS     = 3'b101;
parameter OP_BNE     = 3'b110;
parameter OP_BEQ     = 3'b111;

// cc = 00, bbb = 000.
parameter OP_BRK = 3'b000; // _000_00;
parameter OP_JSR = 3'b001; // _000_00;
parameter OP_RTI = 3'b010; // _000_00;
parameter OP_RTS = 3'b011; // _000_00;
parameter OP_BRA = 3'b100; // _000_00;

// cc = 00, b = 001.
parameter OP_MVP = 3'b010; // _001_00;

// cc = 00, bbb = 010.
parameter OP_PHP = 3'b000; // _010_00;
parameter OP_PLP = 3'b001; // _010_00;
parameter OP_PHA = 3'b010; // _010_00;
parameter OP_PLA = 3'b011; // _010_00;
parameter OP_DEY = 3'b100; // _010_00;
parameter OP_TAY = 3'b101; // _010_00;
parameter OP_INY = 3'b110; // _010_00;
parameter OP_INX = 3'b111; // _010_00;

// cc = 00, b = 101.
parameter OP_MVN = 3'b010; // _101_00;
parameter OP_STZ = 3'b011; // _101_00;
parameter OP_PEI = 3'b110; // _101_00;
parameter OP_PEA = 3'b111; // _101_00;

// cc = 00, b = 110.
parameter OP_CLC = 3'b000; // _110_00;
parameter OP_SEC = 3'b001; // _110_00;
parameter OP_CLI = 3'b010; // _110_00;
parameter OP_SEI = 3'b011; // _110_00;
parameter OP_TYA = 3'b100; // _110_00;
parameter OP_CLV = 3'b101; // _110_00;
parameter OP_CLD = 3'b110; // _110_00;
parameter OP_SED = 3'b111; // _110_00;

// cc = 00, b = 011.
parameter OP_JMP_ABS   = 3'b011; // _111_00;

// cc = 00, b = 111.
parameter OP_JMPL      = 3'b010; // _111_00;
parameter OP_JMP_ABS_X = 3'b011; // _111_00;
parameter OP_JSR_ABS_X = 3'b111; // _111_00;

// cc = 01 aaa = op, bbb = mode
parameter OP_ORA = 3'b000;
parameter OP_AND = 3'b001;
parameter OP_EOR = 3'b010;
parameter OP_ADC = 3'b011;
parameter OP_STA = 3'b100;
parameter OP_LDA = 3'b101;
parameter OP_CMP = 3'b110;
parameter OP_SBC = 3'b111;

parameter OP_BIT_IMM = 3'b100; // _010_01

// cc = 10, b = 000. (65C816)
parameter OP_COP = 3'b000; // _000_10;
parameter OP_JSL = 3'b001; // _000_10;
parameter OP_WDM = 3'b010; // _000_10;
parameter OP_PER = 3'b011; // _000_10;
parameter OP_BRL = 3'b100; // _000_10;
parameter OP_REP = 3'b110; // _000_10;
parameter OP_SEP = 3'b111; // _000_10;

// cc = 10 aaa = op, bbb = mode
parameter OP_ASL = 3'b000;
parameter OP_ROL = 3'b001;
parameter OP_LSR = 3'b010;
parameter OP_ROR = 3'b011;
parameter OP_STX = 3'b100;
parameter OP_LDX = 3'b101;
parameter OP_DEC = 3'b110;
parameter OP_INC = 3'b111;

parameter OP_DEC_A = 3'b001; // _110_10
parameter OP_INC_A = 3'b000; // _110_10

// cc = 10, b = 010.
parameter OP_TXA = 3'b100; // _010_10;
parameter OP_TAX = 3'b101; // _010_10;
parameter OP_DEX = 3'b110; // _010_10;
parameter OP_NOP = 3'b111; // _010_10;

// cc = 10, b = 110.
parameter OP_PHY = 3'b010; // _110_10;
parameter OP_PLY = 3'b011; // _110_10;
parameter OP_TXS = 3'b100; // _110_10;
parameter OP_TSX = 3'b101; // _110_10;
parameter OP_PHX = 3'b110; // _110_10;
parameter OP_PLX = 3'b111; // _110_10;

// cc = 10, b = 111.
parameter OP_STZ_2 = 3'b100; // _111_10;

// cc = 11, b = 010.
parameter OP_PHD = 3'b000; // _010_11;
parameter OP_PLD = 3'b001; // _010_11;
parameter OP_PHK = 3'b010; // _010_11;
parameter OP_RTL = 3'b011; // _010_11;
parameter OP_PHB = 3'b100; // _010_11;
parameter OP_PLB = 3'b101; // _010_11;
parameter OP_WAI = 3'b110; // _010_11;
parameter OP_XBA = 3'b111; // _010_11;

// cc = 11, b = 110.
parameter OP_TCS = 3'b000; // _110_11;
parameter OP_TSC = 3'b001; // _110_11;
parameter OP_TCD = 3'b010; // _110_11;
parameter OP_TDC = 3'b011; // _110_11;
parameter OP_TXY = 3'b100; // _110_11;
parameter OP_TYX = 3'b101; // _110_11;
parameter OP_STP = 3'b110; // _110_11;
parameter OP_XCE = 3'b111; // _110_11;

// This block is simply a clock divider for the raw_clk.
always @(posedge raw_clk) begin
  count <= count + 1;
  clock_div <= clock_div + 1;
end

// Debug: This block simply drives the 8x4 LEDs.
always @(posedge raw_clk) begin
  case (count[9:7])
    3'b000:  begin column_value <= 4'b0111; leds_value <= ~reg_a[7:0]; end
    //3'b000:  begin column_value <= 4'b0111; leds_value <= ~reg_a[23:16]; end
    //3'b000:  begin column_value <= 4'b0111; leds_value <= ~reg_x[7:0]; end
    //3'b000:  begin column_value <= 4'b0111; leds_value <= ~result[23:16]; end
    //3'b000:  begin column_value <= 4'b0111; leds_value <= ~sp[7:0];   end
    //3'b010:  begin column_value <= 4'b1011; leds_value <= ~reg_a[15:8]; end
    //3'b010:  begin column_value <= 4'b1011; leds_value <= ~reg_a[31:24]; end
    //3'b000:  begin column_value <= 4'b0111; leds_value <= ~reg_x[7:0];   end
    //3'b010:  begin column_value <= 4'b1011; leds_value <= ~reg_x[15:8]; end
    //3'b010:  begin column_value <= 4'b1011; leds_value <= ~result[31:24]; end
    //3'b010:  begin column_value <= 4'b1011; leds_value <= ~sp[15:8];   end
    //3'b010:  begin column_value <= 4'b1011; leds_value <= ~reg_x[7:0];   end
    //3'b010:  begin column_value <= 4'b1011; leds_value <= ~flags[7:0];   end
    //3'b010:  begin column_value <= 4'b1011; leds_value <= ~pc[15:8];   end
    //3'b010:  begin column_value <= 4'b1011; leds_value <= ~{ flag_e16, flag_e8, size_x };   end
    //3'b010:  begin column_value <= 4'b1011; leds_value <= ~{ was_ever_halted };   end
    3'b100:  begin column_value <= 4'b1101; leds_value <= ~pc[7:0]; end
    3'b110:  begin column_value <= 4'b1110; leds_value <= ~state;   end
    default: begin column_value <= 4'b1111; leds_value <= 8'hff;    end
  endcase
end

// This block is the main CPU instruction execute state machine.
always @(posedge clk) begin
  //if (mem_bus_halted) was_ever_halted <= 1;

  if (!button_reset)
    state <= STATE_RESET;
  else if (!button_halt)
    state <= STATE_HALTED;
  else if (mem_bus_halted == 0)
    case (state)
      STATE_RESET:
        begin
          flags[FLAG_PENDING_INTERRUPT] <= 0;
          flags[FLAG_E16] <= 1;
          flags[FLAG_E8]  <= 1;
          flags[FLAG_V]   <= 0;
          flags[FLAG_M]   <= 1;
          flags[FLAG_X]   <= 1;
          flags[FLAG_D]   <= 0;
          flags[FLAG_I]   <= 0;
          flags[FLAG_C]   <= 0;
          flags[FLAG_Z]   <= 0;
          mem_address <= 0;
          mem_write_enable <= 0;
          mem_bus_enable <= 0;
          mem_bus_reset <= 1;
          delay_loop <= 12000;
          eeprom_strobe <= 0;
          reg_a <= 0;
          reg_x <= 0;
          reg_y <= 0;
          dr <= 0;
          dbr <= 0;
          pbr <= 0;
          sp <= 16'h1ff;
          bank <= 0;
          state <= STATE_DELAY_LOOP;
          //was_ever_halted <= 0;
        end
      STATE_DELAY_LOOP:
        begin
          // This is probably not needed. The chip starts up fine without it.
          if (delay_loop == 0) begin
            mem_bus_reset <= 0;

            // If button is not pushed, start rom.v code otherwise use EEPROM.
            if (button_program_select) begin
              pc <= 16'h4000;
            end else begin
              pc <= 16'hc000;
              //state <= STATE_EEPROM_START;
            end

            state <= STATE_FETCH_OP_0;
          end

          delay_loop <= delay_loop - 1;
        end
      STATE_FETCH_OP_0:
        begin
          source <= 0;
          indirect_count <= 0;
          absolute_count <= 0;
          immediate_count <= 0;
          push_count <= 0;
          pop_count <= 0;
          wb_count <= 0;
          ea <= 0;
          ea_indirect <= 0;
          size_imm <= size_m;
          is_sub <= 0;
          wb <= 1;
          wb_state <= STATE_WRITEBACK_A;
          long_branch <= 0;
          branch_offset <= 0;
          mem_address <= { pbr, pc };
          mem_bus_enable <= 1;
          state <= STATE_FETCH_OP_1;
        end
      STATE_FETCH_OP_1:
        begin
          mem_bus_enable <= 0;
          instruction <= mem_read;
          state <= STATE_DECODE;
          pc <= pc + 1;
        end
      STATE_DECODE:
        begin
          case (instruction[1:0])
            2'b00:
              if (aaa == OP_TSB && bbb[0] == 1) begin
                next_state <= STATE_TEST_BITS;
                state <= STATE_FETCH_ABSOLUTE_0;
              end else if (bbb == 3'b000 && aaa != OP_LDY && aaa != OP_CPY && aaa != OP_CPX) begin
                case (aaa)
                  OP_BRK: state <= STATE_HALTED;
                  OP_JSR:
                    begin
                      ea <= { pbr, pc };
                      pc <= pc + 2;
                      size_imm <= 2;
                      state <= STATE_FETCH_IMMEDIATE_0;
                      next_state <= STATE_EXECUTE_00_0;
                    end
                  OP_RTI:
                    begin
                      size_imm <= is_emulation_8 ? 3 : 4;
                      state <= STATE_RTI_0;
                    end
                  OP_RTS: begin size_imm <= 2; state <= STATE_POP_0; end
                  OP_BRA: state <= STATE_BRANCH_0;
                endcase
              end else if (bbb == 3'b010) begin
                if (aaa[2] == 0) begin
                  // PHP, PLP, PHA, PLA.
                  result   <= aaa[1] == 1 ? reg_a  : flags[7:0];
                  size_imm <= aaa[1] == 1 ? size_m : SIZE_8;
                  state    <= aaa[0] == 0 ? STATE_PUSH_0 : STATE_POP_0;
                end else begin
                  case (aaa[1:0])
                    // DEY, TAY, INY, INX.
                    2'b00: result <= reg_y - 1;
                    2'b01: result <= reg_a;
                    2'b10: result <= reg_y + 1;
                    2'b11: result <= reg_x + 1;
                  endcase
                  state <= aaa[1:0] == 2'b11 ?
                    STATE_WRITEBACK_X : STATE_WRITEBACK_Y;
                end
              end else if (bbb == 3'b100) begin
                state <= STATE_BRANCH_0;
              end else if (bbb == 3'b001 && aaa == OP_STZ) begin
                // stz ZP
                size_imm <= size_m;
                next_state <= STATE_STZ;
                state <= STATE_FETCH_ABSOLUTE_0;
              end else if (bbb == 3'b001 && aaa == OP_MVP) begin
                state <= STATE_MOVE_BLOCK_0;
              end else if (bbb == 3'b011 && aaa == OP_JMP_ABS) begin
                state <= STATE_JMP_ABS_0;
              end else if (bbb == 3'b101) begin
                case (aaa)
                  OP_MVN: state <= STATE_MOVE_BLOCK_0;
                  OP_STZ:
                    begin
                      // stz ZP, x
                      size_imm <= size_m;
                      next_state <= STATE_STZ;
                      state <= STATE_FETCH_ABSOLUTE_0;
                    end
                  OP_PEI:
                    begin
                      size_imm <= 2;
                      next_state <= STATE_CALC_PER;
                      state <= STATE_CALC_PEI_0;
                    end
                  OP_PEA:
                    begin
                      ea <= { pbr, pc };
                      pc <= pc + 2;
                      size_imm <= 2;
                      next_state <= STATE_CALC_PER;
                      state <= STATE_FETCH_IMMEDIATE_0;
                    end
                endcase
              end else if (bbb == 3'b110) begin
                // CLC, SEC, CLI, SEI, TYA, CLV, CLD, SED.
                case (aaa[2:1])
                  2'b00: flags[FLAG_C] <= aaa[0];
                  2'b01: flags[FLAG_I] <= aaa[0];
                  2'b10:
                    if (aaa[0] == 0)
                      result <= reg_y;
                    else
                      flags[FLAG_V] <= 0;
                  2'b11: flags[FLAG_D] <= aaa[0];
                endcase

                state <= aaa == 3'b100 ? STATE_WRITEBACK_Y : STATE_FETCH_OP_0;
              end else if (bbb == 3'b111) begin
                if (aaa == OP_JMPL) begin
                  ea <= { pbr, pc };
                  pc <= pc + 3;
                  size_imm <= 3;
                  next_state <= STATE_JUMP_LONG;
                  state <= STATE_FETCH_IMMEDIATE_0;
                end else if (aaa == OP_JMP_ABS_X) begin
                  state <= STATE_JMP_ABS_0;
                end else if (aaa == OP_JSR_ABS_X) begin
                  state <= STATE_JMP_ABS_0;
                end else if (aaa == OP_STZ_2) begin
                  // stz absolute;
                  size_imm <= size_m;
                  next_state <= STATE_STZ;
                  state <= STATE_FETCH_ABSOLUTE_0;
                end
              end else begin
                if (aaa == OP_JMP && bbb == 3'b011) begin
                  ea <= { pbr, pc };
                  pc <= pc + 2;
                  size_imm <= 2;
                  next_state <= STATE_EXECUTE_00_0;
                  state <= STATE_FETCH_IMMEDIATE_0;
                end else if (aaa == OP_JMP_IND && bbb == 3'b011) begin
                  size_imm <= 2;
                  next_state <= STATE_EXECUTE_00_0;
                  state <= STATE_FETCH_ABSOLUTE_0;
                end else begin
                  case (addressing_mode)
                    MODE_IMMEDIATE:
                      begin
                        ea <= { pbr, pc };

                        if (aaa == OP_BIT) begin
                          pc <= pc + size_m;
                        end else begin
                          pc <= pc + size_x;
                          size_imm <= size_x;
                        end

                        state <= STATE_FETCH_IMMEDIATE_0;
                      end
                    MODE_ABSOLUTE:   state <= STATE_FETCH_ABSOLUTE_0;
                    MODE_INDIRECT_X: state <= STATE_FETCH_INDIRECT_0;
                    MODE_INDIRECT_Y: state <= STATE_FETCH_INDIRECT_0;
                    MODE_ABSOLUTE_X: state <= STATE_FETCH_ABSOLUTE_0;
                    MODE_ABSOLUTE_Y: state <= STATE_FETCH_ABSOLUTE_0;
                    default:         state <= STATE_HALTED;
                  endcase

                  next_state <= STATE_EXECUTE_00_0;
                end
              end
            2'b01:
              begin
                case (addressing_mode)
                  MODE_IMMEDIATE:
                    begin
                      ea <= { pbr, pc };
                      pc <= pc + size_m;
                      state <= STATE_FETCH_IMMEDIATE_0;
                    end
                  MODE_ABSOLUTE:   state <= STATE_FETCH_ABSOLUTE_0;
                  MODE_INDIRECT_X: state <= STATE_FETCH_INDIRECT_0;
                  MODE_INDIRECT_Y: state <= STATE_FETCH_INDIRECT_0;
                  MODE_ABSOLUTE_X: state <= STATE_FETCH_ABSOLUTE_0;
                  MODE_ABSOLUTE_Y: state <= STATE_FETCH_ABSOLUTE_0;
                  default:         state <= STATE_ERROR;
                endcase

                next_state <= STATE_EXECUTE_01_0;
              end
            2'b10:
              begin
                if (bbb == 3'b000 && aaa != 3'b101 || instruction[7:2] == 6'b100_000) begin
                  // stx 100_000_10
                  // ldx 101_000_10
                  // stx 0x100  8e  100 011 10
                  // ldx #5     a2  101 000 10
                  case (aaa)
                    OP_COP: state <= STATE_ERROR;
                    OP_JSL:
                      begin
                        ea <= { pbr, pc };
                        pc <= pc + 3;
                        size_imm <= 3;
                        next_state <= STATE_JUMP_LONG;
                        state <= STATE_FETCH_IMMEDIATE_0;
                      end
                    OP_WDM: state <= STATE_ERROR;
                    OP_PER:
                      begin
                        ea <= { pbr, pc };
                        pc <= pc + 2;
                        size_imm <= 2;
                        next_state <= STATE_CALC_PER;
                        state <= STATE_FETCH_IMMEDIATE_0;
                      end
                    OP_BRL: begin state <= STATE_BRANCH_0; long_branch = 1; end
                    OP_REP: state <= STATE_SET_FLAGS_0;
                    OP_SEP: state <= STATE_SET_FLAGS_0;
                  endcase
                end else if (bbb == 3'b010 && aaa[2] == 1) begin
                  case (aaa)
                    OP_TXA: begin result <= reg_x; state <= STATE_WRITEBACK_A; end
                    OP_TAX: begin result <= reg_a; state <= STATE_WRITEBACK_X; end
                    OP_DEX: begin result <= reg_x - 1; state <= STATE_WRITEBACK_X; end
                    OP_NOP: state <= STATE_FETCH_OP_0;
                  endcase
                end else if (bbb == 3'b110) begin
                  case (aaa)
                    OP_INC_A:
                      begin
                        result <= reg_a + 1;
                        state  <= STATE_WRITEBACK_A;
                      end
                    OP_DEC_A:
                      begin
                        result <= reg_a - 1;
                        state  <= STATE_WRITEBACK_A;
                      end
                    OP_TXS:
                      begin
                        // FIXME: Are the sizes here correct?
                        if (size_x == SIZE_8)
                          sp[7:0] <= reg_x[7:0];
                        else
                          sp <= reg_x;

                        state <= STATE_FETCH_OP_0;
                      end
                    OP_TSX: begin result <= sp; state <= STATE_WRITEBACK_X; end
                    OP_PHY: state <= STATE_PUSH_0;
                    OP_PLY: state <= STATE_POP_0;
                    OP_PHX: state <= STATE_PUSH_0;
                    OP_PLX: state <= STATE_POP_0;
                    default: state <= STATE_ERROR;
                  endcase

                  if (aaa[2:1] != 2'b00)
                    result <= aaa[2] == 0 ? reg_y : reg_x;

                  size_imm <= size_x;
                end else if (bbb == 3'b111) begin
                  if (aaa == OP_STZ_2) begin
                    // stz absolute, x
                    size_imm <= size_m;
                    next_state <= STATE_STZ;
                    state <= STATE_FETCH_ABSOLUTE_0;
                  end else begin
                    state <= STATE_ERROR;
                  end
                end else begin
                  case (addressing_mode)
                    MODE_IMMEDIATE:
                      begin
                        ea <= { pbr, pc };

                        // Only LDX or STX should be able to end up in
                        // here.
                        //if (aaa == OP_LDX || aaa == OP_STX) begin
                          pc <= pc + size_x;
                          size_imm <= size_x;
                        //end else begin
                        //  pc <= pc + size_m;
                        //end

                        state <= STATE_FETCH_IMMEDIATE_0;
                      end
                    MODE_ABSOLUTE:   state <= STATE_FETCH_ABSOLUTE_0;
                    MODE_ABSOLUTE_X: state <= STATE_FETCH_ABSOLUTE_0;
                    MODE_A:
                      begin
                        source <= reg_a;
                        state <= STATE_EXECUTE_10_0;
                      end
                    default:         state <= STATE_ERROR;
                  endcase

                  next_state <= STATE_EXECUTE_10_0;
                end
              end
            2'b11:
              case (bbb)
                3'b010:
                  begin
                    case (aaa)
                      OP_PHD: begin state <= STATE_PUSH_0; result <= dr; end
                      OP_PLD: state <= STATE_POP_0;
                      OP_PHK: begin state <= STATE_PUSH_0; result <= dbr; end
                      OP_RTL: state <= STATE_POP_0;
                      OP_PHB:
                        begin state <= STATE_PUSH_0; result <= reg_a[15:7]; end
                      OP_PLB: state <= STATE_POP_0;
                      OP_WAI:
                        if (flag_pending_interrupt == 1) state <= STATE_FETCH_OP_0;
                      OP_XBA:
                        begin
                          reg_a[7:0]  <= reg_a[15:8];
                          reg_a[15:8] <= reg_a[7:0];
                          state <= STATE_FETCH_OP_0;
                        end
                    endcase

                    if (aaa == OP_RTL)
                      size_imm <= 3;
                    else
                      size_imm <= aaa == OP_PHD ? SIZE_8 : SIZE_16;
                  end
                3'b110:
                  begin
                    case (aaa)
                      OP_TCS:
                        if (size_m == SIZE_8)
                          sp[7:0] <= reg_a[7:0];
                        else
                          sp[15:0] <= reg_a[15:0];
                      OP_TSC:
                        if (size_m == SIZE_8)
                          reg_a[7:0] <= sp[7:0];
                        else
                          reg_a[15:0] <= sp[15:0];
                      OP_TCD:
                        if (size_m == SIZE_8)
                          dr[7:0] <= reg_a[7:0];
                        else
                          dr[15:0] <= reg_a[15:0];
                      OP_TDC:
                        if (size_m == SIZE_8)
                          reg_a[7:0] <= dr[7:0];
                        else
                          reg_a[15:0] <= dr[15:0];
                      OP_TXY:
                        case (size_x)
                          SIZE_8:  reg_y[7:0]  <= reg_x[7:0];
                          SIZE_16: reg_y[15:0] <= reg_x[15:0];
                          SIZE_32: reg_y[31:0] <= reg_x[31:0];
                        endcase
                      OP_TYX:
                        case (size_x)
                          SIZE_8:  reg_x[7:0]  <= reg_y[7:0];
                          SIZE_16: reg_x[15:0] <= reg_y[15:0];
                          SIZE_32: reg_x[31:0] <= reg_y[31:0];
                        endcase
                      OP_STP:
                        // FIXME: Stop clock?
                        state <= STATE_HALTED;
                      OP_XCE:
                        begin
                          flags[FLAG_C]  <= flag_e8;
                          flags[FLAG_E8] <= flag_c;

                          // FIXME: This is XFE in 32 bit mode?
                          if (! is_emulation_8) begin
                            flags[FLAG_V]   <= flag_e16;
                            flags[FLAG_E16] <= flag_v;
                          end
                        end
                    endcase

                    state <= STATE_FETCH_OP_0;
                  end
                default:
                  state <= STATE_ERROR;
            endcase
          endcase
        end
      STATE_FETCH_INDIRECT_0:
        begin
          mem_address <= { pbr, pc };
          mem_bus_enable <= 1;
          pc <= pc + 1;
          state <= STATE_FETCH_INDIRECT_1;
        end
      STATE_FETCH_INDIRECT_1:
        begin
          mem_bus_enable <= 0;

          if (addressing_mode == MODE_INDIRECT_X)
            case (size_x)
              SIZE_8:  ea_indirect <= mem_read + dr + reg_x[7:0];
              SIZE_16: ea_indirect <= mem_read + dr + reg_x[15:0];
              SIZE_32: ea_indirect <= mem_read + dr + reg_x[31:0];
            endcase
          else
            ea_indirect[15:0] <= mem_read + dr;

          state <= STATE_FETCH_INDIRECT_2;
        end
      STATE_FETCH_INDIRECT_2:
        begin
          if (is_emulation_8 == 0) ea[23:16] <= dbr;

          // FIXME: Is dbr correct here?
          mem_address <= { dbr, ea_indirect };
          ea_indirect <= ea_indirect + 1;
          mem_bus_enable <= 1;
          state <= STATE_FETCH_INDIRECT_3;
        end
      STATE_FETCH_INDIRECT_3:
        begin
          mem_bus_enable <= 0;
          indirect_count <= indirect_count + 1;

          case (indirect_count)
            0: ea[7:0]   <= mem_read;
            1: ea[15:8]  <= mem_read;
          endcase

          if (indirect_count == 1) begin
            if (addressing_mode == MODE_INDIRECT_X)
              state <= STATE_FETCH_IMMEDIATE_0;
            else
              state <= STATE_FETCH_INDIRECT_Y;
          end else begin
            state <= STATE_FETCH_INDIRECT_2;
          end
        end
      STATE_FETCH_INDIRECT_Y:
        begin
          case (size_x)
            SIZE_8:  ea <= ea + reg_y[7:0];
            SIZE_16: ea <= ea + reg_y[15:0];
            SIZE_32: ea <= ea + reg_y[31:0];
          endcase

          state <= STATE_FETCH_IMMEDIATE_0;
        end
      STATE_FETCH_ABSOLUTE_0:
        begin
          if (addressing_mode != MODE_ZP &&
              size_m != 1 &&
              is_emulation_8 == 0)
            ea[23:16] <= dbr;

          mem_address <= { pbr, pc };
          mem_bus_enable <= 1;
          pc <= pc + 1;
          absolute_count <= absolute_count + 1;

          state <= STATE_FETCH_ABSOLUTE_1;
        end
      STATE_FETCH_ABSOLUTE_1:
        begin
          mem_bus_enable <= 0;

          case (absolute_count)
            1: ea[7:0]  <= mem_read;
            2: ea[15:8] <= mem_read;
          endcase

          if (absolute_count == ea_size)
            if (addressing_mode == MODE_ZP && ea_size == 1) begin
              state <= STATE_FETCH_DIRECT_PAGE;
            end else if (addressing_mode == MODE_ABSOLUTE) begin
              state <= STATE_FETCH_IMMEDIATE_0;
            end else begin
              offset <= addressing_mode == MODE_ABSOLUTE_X ? reg_x : reg_y;
              state <= STATE_FETCH_INDEXED;
            end
          else
            state <= STATE_FETCH_ABSOLUTE_0;
        end
      STATE_FETCH_DIRECT_PAGE:
        begin
          if (! is_emulation_8) ea <= ea + dr;
          state <= STATE_FETCH_IMMEDIATE_0;
        end
      STATE_FETCH_INDEXED:
        begin
          case (size_x)
            SIZE_8:  ea <= ea + offset[7:0];
            SIZE_16: ea <= ea + offset[15:0];
            SIZE_32: ea <= ea + offset[31:0];
          endcase

          state <= STATE_FETCH_IMMEDIATE_0;
        end
      STATE_FETCH_IMMEDIATE_0:
        begin
          mem_address <= ea + immediate_count;
          mem_bus_enable <= 1;
          immediate_count <= immediate_count + 1;
          state <= STATE_FETCH_IMMEDIATE_1;
        end
      STATE_FETCH_IMMEDIATE_1:
        begin
          mem_bus_enable <= 0;

          case (immediate_count[1:0])
            1: source[7:0]   <= mem_read;
            2: source[15:8]  <= mem_read;
            3: source[23:16] <= mem_read;
            0: source[31:24] <= mem_read;
          endcase

          if (immediate_count == size_imm)
            state <= next_state;
          else
            state <= STATE_FETCH_IMMEDIATE_0;
        end
      STATE_EXECUTE_00_0:
        begin
          if (aaa == OP_JMP || aaa == OP_JMP_IND || (aaa == OP_JSR && bbb == 3'b000)) begin
            pc[15:0] <= source;
          end else if (aaa == OP_BIT) begin
            case (size_m)
              SIZE_8:  temp <= { 24'b0, reg_a[7:0]  };
              SIZE_16: temp <= { 16'b0, reg_a[15:0] };
              SIZE_32: temp <= {        reg_a[31:0] };
            endcase

            wb <= 0;
          end else if (aaa == OP_CPY || aaa == OP_LDY || aaa == OP_STY) begin
            case (size_x)
              SIZE_8:  temp <= { 24'b0, reg_y[7:0]  };
              SIZE_16: temp <= { 16'b0, reg_y[15:0] };
              SIZE_32: temp <= {        reg_y[31:0] };
            endcase

            wb_state <= STATE_WRITEBACK_Y;
          end else if (aaa == OP_CPX) begin
            case (size_x)
              SIZE_8:  temp <= { 24'b0, reg_x[7:0]  };
              SIZE_16: temp <= { 16'b0, reg_x[15:0] };
              SIZE_32: temp <= {        reg_x[31:0] };
            endcase

            wb_state <= STATE_WRITEBACK_X;
          end

          if (aaa == OP_JMP || aaa == OP_JMP_IND) begin
            state <= STATE_FETCH_OP_0;
          end else if (aaa == OP_JSR && bbb == 3'b000) begin
            result <= pc[15:0];
            state <= STATE_PUSH_0;
          end else begin
            state <= STATE_EXECUTE_00_1;
          end
        end
      STATE_EXECUTE_00_1:
        begin
          case (aaa)
            OP_BIT: begin result <= temp & source; wb <= 0; end
            //OP_JMP: result <= temp & source;
            //OP_JMP_IND: result <= temp ^ source;
            OP_STY: result <= temp;
            OP_LDY: result <= source;
            OP_CPY: begin result <= temp - source; wb <= 0; end
            OP_CPX: begin result <= temp - source; wb <= 0; end
          endcase

          if (aaa == OP_STY) begin
            size_imm <= size_x;
            state <= STATE_WRITEBACK_MEM_0;
          end else begin
            state <= wb_state;
          end
        end
      STATE_EXECUTE_01_0:
        begin
          case (size_m)
            SIZE_8:  temp <= { 24'b0, reg_a[7:0]  };
            SIZE_16: temp <= { 16'b0, reg_a[15:0] };
            SIZE_32: temp <= {        reg_a[31:0] };
          endcase

          state <= STATE_EXECUTE_01_1;
        end
      STATE_EXECUTE_01_1:
        begin
          case (aaa)
            OP_ORA: result <= temp | source;
            OP_AND: result <= temp & source;
            OP_EOR: result <= temp ^ source;
            OP_ADC: result <= temp + source + flag_c;
            OP_STA:
              if (bbb == 3'b010) begin
                // OP_BIT_IMM: bit #imm
                wb <= 0;
                result <= temp & source;
              end else begin
                result <= temp;
              end
            OP_LDA: result <= source;
            OP_CMP: begin result <= temp - source; wb <= 0; is_sub <= 1; end
            OP_SBC: begin result <= temp - source - 1 + flag_c; is_sub <= 1; end
          endcase

          // wb_state should always be STATE_WRITEBACK_A.
          if (aaa == OP_STA && bbb != 3'b010)
            state <= STATE_WRITEBACK_MEM_0;
          else
            state <= wb_state;
        end
      STATE_EXECUTE_10_0:
        begin
          if (aaa == OP_STX || aaa == OP_LDX) begin
            case (size_x)
              SIZE_8:  temp <= { 24'b0, reg_x[7:0]  };
              SIZE_16: temp <= { 16'b0, reg_x[15:0] };
              SIZE_32: temp <= {        reg_x[31:0] };
            endcase

            wb_state <= STATE_WRITEBACK_X;
          end else begin
            case (size_m)
              SIZE_8:  temp <= { 24'b0, reg_a[7:0]  };
              SIZE_16: temp <= { 16'b0, reg_a[15:0] };
              SIZE_32: temp <= {        reg_a[31:0] };
            endcase
          end

          state <= STATE_EXECUTE_10_1;
        end
      STATE_EXECUTE_10_1:
        begin
          case (aaa)
            OP_ASL:
              case (size_m)
                SIZE_8:  result[8:0]  <= { source[7],  source[6:0],  1'b0 };
                SIZE_16: result[16:0] <= { source[15], source[14:0], 1'b0 };
                SIZE_32: result[32:0] <= { source[31], source[30:0], 1'b0 };
              endcase
            OP_ROL:
              case (size_m)
                SIZE_8:  result[8:0]  <= { source[7],  source[6:0],  flag_c };
                SIZE_16: result[16:0] <= { source[15], source[14:0], flag_c };
                SIZE_32: result[32:0] <= { source[31], source[30:0], flag_c };
              endcase
            OP_LSR:
              case (size_m)
                SIZE_8:  result[8:0]  <= { source[0], 1'b0, source[7:1]  };
                SIZE_16: result[16:0] <= { source[0], 1'b0, source[15:1] };
                SIZE_32: result[32:0] <= { source[0], 1'b0, source[31:1] };
              endcase
            OP_ROR:
              case (size_m)
                SIZE_8:  result[8:0]  <= { source[0], flag_c, source[7:1]  };
                SIZE_16: result[16:0] <= { source[0], flag_c, source[15:1] };
                SIZE_32: result[32:0] <= { source[0], flag_c, source[31:1] };
              endcase
            OP_STX: result <= temp;
            OP_LDX: result <= source;
            OP_DEC: result <= source - 1;
            OP_INC: result <= source + 1;
          endcase

          if (aaa == OP_STX) begin
            size_imm <= size_x;
            state <= STATE_WRITEBACK_MEM_0;
          end else if (aaa == OP_LDX) begin
            state <= STATE_WRITEBACK_X;
          end else begin
            state <= addressing_mode == MODE_A ?
              STATE_WRITEBACK_A : STATE_WRITEBACK_MEM_P;
          end
        end
      STATE_WRITEBACK_A:
        begin
          case (size_m)
            SIZE_8:
              begin
                if (wb == 1) reg_a[7:0] <= result[7:0];
                flags[FLAG_C] <= result[8];
                flags[FLAG_Z] <= result[7:0] == 0;
                flags[FLAG_N] <= result[7];
                flags[FLAG_V] <= temp[7] == (source[7] ^ is_sub) && result[7] != temp[7];
              end
            SIZE_16:
              begin
                if (wb == 1) reg_a[15:0] <= result[15:0];
                flags[FLAG_C] <= result[16];
                flags[FLAG_Z] <= result[15:0] == 0;
                flags[FLAG_N] <= result[15];
                flags[FLAG_V] <= temp[15] == (source[15] ^ is_sub) && result[15] != temp[15];
              end
            SIZE_32:
              begin
                if (wb == 1) reg_a[31:0] <= result[31:0];
                flags[FLAG_C] <= result[32];
                flags[FLAG_Z] <= result[31:0] == 0;
                flags[FLAG_N] <= result[31];
                flags[FLAG_V] <= temp[31] == (source[31] ^ is_sub) && result[31] != temp[31];
              end
          endcase

          state <= STATE_FETCH_OP_0;
        end
      STATE_WRITEBACK_X:
        begin
          case (size_x)
            SIZE_8:
              begin
                if (wb == 1) reg_x[7:0] <= result[7:0];
                flags[FLAG_Z] <= result[7:0] == 0;
                flags[FLAG_N] <= result[7];
              end
            SIZE_16:
              begin
                if (wb == 1) reg_x[15:0] <= result[15:0];
                flags[FLAG_Z] <= result[15:0] == 0;
                flags[FLAG_N] <= result[15];
              end
            SIZE_32:
              begin
                if (wb == 1) reg_x[31:0] <= result[31:0];
                flags[FLAG_Z] <= result[31:0] == 0;
                flags[FLAG_N] <= result[31];
              end
          endcase

          state <= STATE_FETCH_OP_0;
        end
      STATE_WRITEBACK_Y:
        begin
          case (size_x)
            SIZE_8:
              begin
                if (wb == 1) reg_y[7:0] <= result[7:0];
                flags[FLAG_Z] <= result[7:0] == 0;
                flags[FLAG_N] <= result[7];
              end
            SIZE_16:
              begin
                if (wb == 1) reg_y[15:0] <= result[15:0];
                flags[FLAG_Z] <= result[15:0] == 0;
                flags[FLAG_N] <= result[15];
              end
            SIZE_32:
              begin
                if (wb == 1) reg_y[31:0] <= result[31:0];
                flags[FLAG_Z] <= result[31:0] == 0;
                flags[FLAG_N] <= result[31];
              end
          endcase

          state <= STATE_FETCH_OP_0;
        end
      STATE_WRITEBACK_MEM_P:
        begin
          case (size_m)
            SIZE_8:
              begin
                flags[FLAG_C] <= result[8];
                flags[FLAG_Z] <= result[7:0] == 0;
                flags[FLAG_N] <= result[7];
                flags[FLAG_V] <= temp[7] == (source[7] ^ is_sub) && result[7] != temp[7];
              end
            SIZE_16:
              begin
                flags[FLAG_C] <= result[16];
                flags[FLAG_Z] <= result[15:0] == 0;
                flags[FLAG_N] <= result[15];
                flags[FLAG_V] <= temp[15] == (source[15] ^ is_sub) && result[15] != temp[15];
              end
            SIZE_32:
              begin
                flags[FLAG_C] <= result[32];
                flags[FLAG_Z] <= result[31:0] == 0;
                flags[FLAG_N] <= result[31];
                flags[FLAG_V] <= temp[31] == (source[31] ^ is_sub) && result[31] != temp[31];
              end
          endcase

          state <= STATE_WRITEBACK_MEM_0;
        end
      STATE_WRITEBACK_MEM_0:
        begin
          mem_bus_enable <= 1;
          mem_write_enable <= 1;
          mem_address <= ea + wb_count;

          case (wb_count)
            0: mem_write <= result[7:0];
            1: mem_write <= result[15:8];
            2: mem_write <= result[23:16];
            3: mem_write <= result[31:24];
          endcase

          wb_count <= wb_count + 1;

          state <= STATE_WRITEBACK_MEM_1;
        end
      STATE_WRITEBACK_MEM_1:
        begin
          mem_bus_enable <= 0;
          mem_write_enable <= 0;

          if (wb_count == size_imm)
            state <= STATE_FETCH_OP_0;
          else
            state <= STATE_WRITEBACK_MEM_0;
        end
      STATE_BRANCH_0:
        begin
          if (bbb == 3'b000)
            // OP_BRA, OP_BRL.
            do_branch <= 1;
          else
            // BPL, BMI, BVC, BVS, BCC, BCS, BNE, BEQ.
            case (aaa[2:1])
              2'b00: do_branch <= flag_n == aaa[0];
              2'b01: do_branch <= flag_v == aaa[0];
              2'b10: do_branch <= flag_c == aaa[0];
              2'b11: do_branch <= flag_z == aaa[0];
            endcase

          pc <= pc + 1;
          mem_address <= { pbr, pc };
          mem_bus_enable <= 1;
          state <= STATE_BRANCH_1;
        end
      STATE_BRANCH_1:
        begin
          mem_bus_enable <= 0;
          immediate_count <= immediate_count + 1;

          if (long_branch == 0) begin
            if (do_branch) pc[15:0] <= $signed(pc[15:0]) + $signed(mem_read);
            state <= STATE_FETCH_OP_0;
          end else begin
            if (immediate_count == 0) begin
              branch_offset <= mem_read;
              state <= STATE_BRANCH_0;
            end else begin
              if (do_branch) pc[15:0] <= pc[15:0] + { mem_read, branch_offset };
              state <= STATE_FETCH_OP_0;
            end
          end
        end
      STATE_SET_FLAGS_0:
        begin
          mem_address <= { pbr, pc };
          mem_bus_enable <= 1;
          pc <= pc + 1;
          state <= STATE_SET_FLAGS_1;
        end
      STATE_SET_FLAGS_1:
        begin
          case (aaa)
            OP_REP: flags[7:0] <= flags[7:0] & ~mem_read;
            OP_SEP: flags[7:0] <= flags[7:0] | mem_read;
          endcase

          mem_bus_enable <= 0;
          state <= STATE_FETCH_OP_0;
        end
      STATE_PUSH_0:
        begin
          push_count <= size_imm;
          state <= STATE_PUSH_1;
        end
      STATE_PUSH_1:
        begin
          mem_bus_enable <= 1;
          mem_write_enable <= 1;
          mem_address <= sp;

          case (push_count)
            1: mem_write <= result[7:0];
            2: mem_write <= result[15:8];
            3: mem_write <= result[23:16];
            4: mem_write <= result[31:24];
          endcase

          push_count <= push_count - 1;
          sp <= sp - 1;
          state <= STATE_PUSH_2;
        end
      STATE_PUSH_2:
        begin
          mem_bus_enable <= 0;
          mem_write_enable <= 0;

          if (push_count == 0)
            state <= STATE_FETCH_OP_0;
          else
            state <= STATE_PUSH_1;
        end
      STATE_POP_0:
        begin
          mem_address <= sp + 1;
          mem_bus_enable <= 1;
          pop_count <= pop_count + 1;
          sp <= sp + 1;
          state <= STATE_POP_1;
        end
      STATE_POP_1:
        begin
          mem_bus_enable <= 0;

          case (pop_count)
            1: source[7:0]   <= mem_read;
            2: source[15:8]  <= mem_read;
            3: source[23:16] <= mem_read;
            4: source[31:24] <= mem_read;
          endcase

          if (pop_count == size_imm)
            state <= STATE_POP_WB;
          else
            state <= STATE_POP_0;
        end
      STATE_POP_WB:
        begin
          case (cc)
            2'b00:
              case (bbb)
                3'b000:
                  case (aaa)
                    OP_RTS: pc[15:0] <= source[15:0];
                  endcase
                3'b010:
                  case (aaa)
                    OP_PLP: flags[7:0] <= source[7:0];
                    OP_PLA:
                      case (size_m)
                        SIZE_8:  reg_a[7:0]  <= source[7:0];
                        SIZE_16: reg_a[15:0] <= source[15:0];
                        SIZE_32: reg_a[31:0] <= source[31:0];
                      endcase
                    OP_PLD: dr <= source;
                    OP_PLB: dbr <= source;
                  endcase
                3'b110:
                  case (aaa)
                    OP_PLX:
                      case (size_x)
                        SIZE_8:  reg_x[7:0]  <= source[7:0];
                        SIZE_16: reg_x[15:0] <= source[15:0];
                        SIZE_32: reg_x[31:0] <= source[31:0];
                      endcase
                    OP_PLY:
                      case (size_x)
                        SIZE_8:  reg_y[7:0]  <= source[7:0];
                        SIZE_16: reg_y[15:0] <= source[15:0];
                        SIZE_32: reg_y[31:0] <= source[31:0];
                      endcase
                  endcase
              endcase
            2'b11:
              case (bbb)
                3'b010:
                  case (aaa)
                    OP_RTL: { pbr, pc } <= source[23:0];
                  endcase
              endcase
          endcase

          state <= STATE_FETCH_OP_0;
        end
      STATE_JUMP_LONG:
        begin
          pbr <= source[23:16];
          pc[15:0] <= source[15:0];
          result <= { pbr, pc[15:0] };
          size_imm <= 3;

          if (aaa == OP_JSL)
            state <= STATE_PUSH_0;
          else
            state <= STATE_FETCH_OP_0;
        end
      STATE_CALC_PER:
        begin
          //result <= pc[15:0] + source[15:0];
          result <= source[15:0];
          state <= STATE_PUSH_0;
        end
      STATE_CALC_PEI_0:
        begin
          mem_address <= { pbr, pc };
          mem_bus_enable <= 1;
          pc <= pc + 1;
          state <= STATE_CALC_PEI_1;
        end
      STATE_CALC_PEI_1:
        begin
          ea <= mem_read;
          mem_bus_enable <= 0;
          state <= STATE_FETCH_IMMEDIATE_0;
        end
      STATE_RTI_0:
        begin
          mem_address <= sp + 1;
          mem_bus_enable <= 1;
          immediate_count <= immediate_count + 1;
          sp <= sp + 1;
          state <= STATE_RTI_1;
        end
      STATE_RTI_1:
        begin
          mem_bus_enable <= 0;

          case (immediate_count)
            1: flags    <= mem_read;
            2: pc[7:0]  <= mem_read;
            3: pc[15:0] <= mem_read;
            4: pbr[7:0] <= mem_read;
          endcase

          if (immediate_count == size_imm)
            state <= STATE_FETCH_OP_0;
          else
            state <= STATE_RTI_0;
        end
      STATE_STZ:
        begin
          result <= 0;
          state <= STATE_WRITEBACK_MEM_0;
        end
      STATE_MOVE_BLOCK_0:
        begin
          mem_bus_enable <= 1;
          mem_address <= { pbr, pc };
          pc <= pc + 1;
          state <= STATE_MOVE_BLOCK_1;
        end
      STATE_MOVE_BLOCK_1:
        begin
          case (immediate_count)
            0:
              begin
                block_source <= mem_read;
                state <= STATE_MOVE_BLOCK_0;
              end
            1:
              begin
                dbr <= mem_read;
                state <= STATE_MOVE_BLOCK_2;
              end
          endcase

          immediate_count <= immediate_count + 1;
          mem_bus_enable <= 0;
        end
      STATE_MOVE_BLOCK_2:
        begin
          mem_address <= { block_source, reg_x[15:0] };
          mem_bus_enable <= 1;
          state <= STATE_MOVE_BLOCK_3;
        end
      STATE_MOVE_BLOCK_3:
        begin
          mem_bus_enable <= 0;
          mem_write <= mem_read;
          state <= STATE_MOVE_BLOCK_4;
        end
      STATE_MOVE_BLOCK_4:
        begin
          mem_address <= { dbr, reg_y[15:0] };
          mem_bus_enable <= 1;
          mem_write_enable <= 1;
          state <= STATE_MOVE_BLOCK_5;
        end
      STATE_MOVE_BLOCK_5:
        begin
          mem_bus_enable <= 0;
          mem_write_enable <= 0;

          if (aaa == OP_MVN) begin
            reg_x[15:0] <= reg_x[15:0] + 1;
            reg_y[15:0] <= reg_y[15:0] + 1;
          end else begin
            reg_x[15:0] <= reg_x[15:0] - 1;
            reg_y[15:0] <= reg_y[15:0] - 1;
          end

          reg_a[15:0] <= reg_a[15:0] - 1;

          if (reg_a[15:0] == 0)
            state <= STATE_FETCH_OP_0;
          else
            state <= STATE_MOVE_BLOCK_2;
        end
      STATE_TEST_BITS:
        begin
          case (size_m)
            SIZE_8:
              begin
                flags[FLAG_Z] <= source[7:0]  & reg_a[7:0]  == 0;

                if (bbb[2] == 0)
                  result[7:0] <= source[7:0] |  reg_a[7:0];
                else
                  result[7:0] <= source[7:0] & ~reg_a[7:0];
              end
            SIZE_16:
              begin
                flags[FLAG_Z] <= source[15:0] & reg_a[15:0] == 0;

                if (bbb[2] == 0)
                  result[15:0] <= source[15:0] |  reg_a[15:0];
                else
                  result[15:0] <= source[15:0] & ~reg_a[15:0];
              end
            SIZE_32:
              begin
                flags[FLAG_Z] <= source[31:0] & reg_a[31:0] == 0;

                if (bbb[2] == 0)
                  result[31:0] <= source[31:0] |  reg_a[31:0];
                else
                  result[31:0] <= source[31:0] & ~reg_a[31:0];
              end
          endcase

          state <= STATE_WRITEBACK_MEM_0;
        end
      STATE_JMP_ABS_0:
        begin
          mem_address <= { pbr, pc };
          mem_bus_enable <= 1;
          pc <= pc + 1;
          state <= STATE_JMP_ABS_1;
        end
      STATE_JMP_ABS_1:
        begin
          if (indirect_count == 0) begin
            ea_indirect[7:0] <= mem_read;
            state <= STATE_JMP_ABS_0;
          end else begin
            if (bbb == 3'b011) begin
              ea_indirect[15:8] <= mem_read;
              state <= STATE_JMP_ABS_2;
            end else begin
              if (size_x == SIZE_8)
                ea_indirect <= { mem_read, ea_indirect[7:0] } + reg_x[7:0];
              else
                ea_indirect <= { mem_read, ea_indirect[7:0] } + reg_x[15:0];

              state <= STATE_JMP_ABS_2;
            end
          end

          indirect_count <= indirect_count + 1;

          mem_bus_enable <= 0;
        end
      STATE_JMP_ABS_2:
        begin
          // FIXME: Is "pbr" correct here?
          mem_address <= { pbr, ea_indirect };
          mem_bus_enable <= 1;
          ea_indirect <= ea_indirect + 1;
          state <= STATE_JMP_ABS_3;
        end
      STATE_JMP_ABS_3:
        begin
          if (immediate_count == 0) begin
            source[7:0] <= mem_read;
            state <= STATE_JMP_ABS_2;
          end else begin
            pc <= { mem_read, source[7:0] };

            if (aaa[2] == 1) begin
              // JSR.
              size_imm <= 2;
              result <= pc[15:0];
              state <= STATE_PUSH_0;
            end else begin
              state <= STATE_FETCH_OP_0;
            end
          end

          immediate_count <= immediate_count + 1;

          mem_bus_enable <= 0;
        end
/*
      STATE_EEPROM_START:
        begin
          // Initialize values for reading from SPI-like EEPROM.
          if (eeprom_ready) begin
            eeprom_count <= 0;
            state <= STATE_EEPROM_READ;
          end
        end
      STATE_EEPROM_READ:
        begin
          // Set the next EEPROM address to read from and strobe.
          eeprom_address <= eeprom_count;
          mem_address <= eeprom_count;
          eeprom_strobe <= 1;
          state <= STATE_EEPROM_WAIT;
        end
      STATE_EEPROM_WAIT:
        begin
          // Wait until 8 bits are clocked in.
          eeprom_strobe <= 0;

          if (eeprom_ready) begin
            mem_write <= eeprom_data_out;
            eeprom_count <= eeprom_count + 1;
            state <= STATE_EEPROM_WRITE;
          end
        end
      STATE_EEPROM_WRITE:
        begin
          // Write value read from EEPROM into memory.
          mem_write_enable <= 1;
          state <= STATE_EEPROM_DONE;
        end
      STATE_EEPROM_DONE:
        begin
          // Finish writing and read next byte if needed.
          mem_write_enable <= 0;

          if (eeprom_count == 256)
            state <= STATE_FETCH_OP_0;
          else
            state <= STATE_EEPROM_READ;
        end
*/
      STATE_ERROR:
        begin
          state <= STATE_ERROR;
          mem_bus_enable <= 0;
          mem_write_enable <= 0;
        end
      STATE_HALTED:
        begin
          if (!button_halt) begin
            state <= STATE_FETCH_OP_0;
            if (is_emulation_8) flags[FLAG_B] <= 0;
          end else begin
            if (is_emulation_8) flags[FLAG_B] <= 1;
          end

          mem_bus_enable <= 0;
          mem_write_enable <= 0;
        end
    endcase
end

memory_bus memory_bus_0(
  .address        (mem_address),
  .data_in        (mem_write),
  .data_out       (mem_read),
  .bus_enable     (mem_bus_enable),
  .write_enable   (mem_write_enable),
  .bus_halt       (mem_bus_halted),
  .clk            (clk),
  .raw_clk        (raw_clk),
  .speaker_p      (speaker_p),
  .speaker_m      (speaker_m),
  .ioport_0       (ioport_0),
  .ioport_0       (ioport_0),
  .ioport_1       (ioport_1),
  .ioport_2       (ioport_2),
  .ioport_3       (ioport_3),
  .ioport_4       (ioport_4),
  .button_0       (button_0),
  .spi_clk_0      (spi_clk_0),
  .spi_mosi_0     (spi_mosi_0),
  .spi_miso_0     (spi_miso_0),
  .windbond_reset (windbond_reset),
  .windbond_wp    (windbond_wp),
  .windbond_do    (windbond_do),
  .windbond_di    (windbond_di),
  .windbond_clk   (windbond_clk),
  .windbond_cs    (windbond_cs),
  .reset          (mem_bus_reset)
);

addressing_mode addressing_mode_0
(
  .cc        (cc),
  .bbb       (bbb),
  .aaa       (aaa),
  .mode      (addressing_mode),
  .ea_size   (ea_size)
);

reg_mode reg_mode_0
(
  .e16    (flag_e16),
  .e8     (flag_e8),
  .m      (flag_m),
  .x      (flag_x),
  .size_m (size_m),
  .size_x (size_x)
);

/*
eeprom eeprom_0
(
  .address    (eeprom_address),
  .strobe     (eeprom_strobe),
  .raw_clk    (raw_clk),
  .eeprom_cs  (eeprom_cs),
  .eeprom_clk (eeprom_clk),
  .eeprom_di  (eeprom_di),
  .eeprom_do  (eeprom_do),
  .ready      (eeprom_ready),
  .data_out   (eeprom_data_out)
);
*/

endmodule

