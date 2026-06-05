`timescale 1ns / 1ps

package config_pkg;
    // --- Immediate ALU Opcodes ---
    localparam IALU_ADD     = 15;
    localparam IALU_SUB     = 16;
    localparam IALU_RSHI    = 17;
    localparam IALU_LSHI    = 18;
    localparam IALU_AND     = 19;
    localparam IALU_OR      = 20;
    localparam IALU_EQ      = 21;
    localparam IALU_GTE     = 22;
    localparam IALU_LTE     = 23;
    localparam IALU_GT      = 24;
    localparam IALU_LT      = 25;

    // --- ALU Parameters ---
    localparam ALU_ADD      = 1;
    localparam ALU_SUB      = 2;
    localparam ALU_LSHIFT   = 3;
    localparam ALU_RSHIFT   = 4;

    localparam ALU_EQ       = 5;
    localparam ALU_GTE      = 6;
    localparam ALU_LTE      = 7;
    localparam ALU_GT       = 8;
    localparam ALU_LT       = 9;

    localparam ALU_AND      = 10;
    localparam ALU_OR       = 11;
    localparam ALU_NOR      = 12;
    localparam ALU_NAND     = 13;
    localparam ALU_XOR      = 14;

    // --- Processor Parameters ---
    localparam INSTR_WIDTH      = 32;
    localparam ARCH_REGS_BITS   = 4;
    localparam NUM_ARCH_REGS    = (1 << ARCH_REGS_BITS);
    localparam PHYS_REGS_BITS   = 5;
    localparam NUM_PHYS_REGS    = (1 << PHYS_REGS_BITS);
    localparam DATABUS_WIDTH    = 36;
    localparam ADDRBUS_SIZE     = 32;
    localparam DATA_MEM_SIZE    = 4096;
    localparam CDB_SIZE         = 6;
    localparam ALU_RS_SIZE      = 16;
    localparam MEM_RS_SIZE      = 8;
    localparam RS_SIZE          = 8;

    // --- Types ---
    // opcode, reg_d, reg_s, reg_t, imm, pad
    typedef struct packed {
        logic [5:0] opcode;
        logic [3:0] reg_d;
        logic [3:0] reg_s;
        logic [3:0] reg_t;
        logic [11:0] imm;
        logic [1:0]  pad;
    } instruction;

    typedef struct packed {
        logic valid;
        logic [0:DATABUS_WIDTH-1] data;
    } phys_reg;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [5:0] opcode;
        logic [4:0] reg_s;
        logic [31:0] value_s;
        logic check_s;
        logic [4:0] reg_t;
        logic [31:0] value_t;
        logic check_t;
        logic [4:0] dest;
        logic [7:0] padding;
    } int_rs_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [5:0] opcode;
        logic [4:0] reg_s;
        logic [31:0] value_s;
        logic check_s;
        logic [11:0] imm;
        logic [4:0] dest;
        logic [33:0] padding;
    } imm_rs_entry;

    // lw: $dest <= data_mem[($reg_s) + offset]
    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [5:0] opcode;
        logic [4:0] reg_s;      // This is the base register 
        logic [31:0] value_s;   // base value to combine with offset for address
        logic check_s;
        logic [11:0] offset;
        logic [4:0] dest;
        logic [3:0] count; // Represents previous stores before this instruction
        logic dispatched;
        logic pending_addr;
        logic [27:0] padding;
    } load_rs_entry;

    // sw: data_mem[($reg_d) + offset] <= ($reg_s)
    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [5:0] opcode;
        logic [4:0] reg_s;
        logic [31:0] value_s;
        logic check_s;
        logic [4:0] reg_d;
        logic [31:0] value_d;
        logic check_d;
        logic [11:0] offset;
        logic dispatched;
    } store_rs_entry;

    typedef union packed {
        int_rs_entry int_rs;
        imm_rs_entry imm_rs;
        load_rs_entry load_rs;
        store_rs_entry store_rs;
        logic [100:0] raw;
    } rs_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic done;
        logic [31:0] result;
        logic [4:0] new_prf; // Phys reg to write result into
        logic [4:0] old_prf; // Phys reg to free
        logic [3:0] arch; // Do something with RRT
        logic [11:0] mem_dest; // store instruction target address
        logic is_store;
    } rob_entry;

    // base_val, offset, & idx used for forwarding mem_dest back into entry
    // mem_dest, id, & value used for ROB
    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [2:0] idx;
        logic [11:0] base_val;
        logic [11:0] offset;
        logic [11:0] mem_dest;
        logic [31:0] value;
    } str_disp_entry;

    typedef struct packed {
        logic valid;
        logic [4:0] id;
        logic [4:0] prf;
        logic [31:0] result;
    } cdb_entry;

    typedef struct packed {
        logic [0:DATABUS_WIDTH-1] write_data;
        logic [0:ADDRBUS_SIZE-1] write_addr;
        logic is_valid;
    } mem_write_entry;

    typedef struct packed {
        logic valid;
        logic [2:0] idx;
        logic [11:0] offset;
        logic [11:0] base_val;
        logic [11:0] eff_addr;
    } load_fwd_addr;
endpackage
