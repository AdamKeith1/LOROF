/*
    Module   : alu_pipeline
    Filename : sequence_item.sv
    Author   : Adam Keith
*/

`ifndef ALU_PIPELINE_TX_SV
`define ALU_PIPELINE_TX_SV

// --- UVM --- //
`include "uvm_macros.svh"
import uvm_pkg::*;

// --- Dependencies --- //
`include "core_types_pkg.vh"
import core_types_pkg::*;

// --- ALU Pipeline Sequence Item --- //
class alu_pipeline_seq_item extends uvm_sequence_item

    // --- Reset --- //
    logic nRST;

    // --- In : Control Signals --- //
    randc logic valid_in; // TODO: constraints
    randc logic A_unneeded_in;
    randc logic A_forward_in;
    randc logic B_forward_in;
    randc logic A_reg_read_valid_in;
    randc logic B_reg_read_valid_in;

    randc logic [3:0]                    op_in;
    randc logic [LOG_PRF_BANK_COUNT-1:0] A_bank_in;
    randc logic [LOG_PRF_BANK_COUNT-1:0] B_bank_in; 
    randc logic [LOG_PR_COUNT-1:0]       dest_PR_in; // unsure on rand or randc

    // --- In : Fully Rand --- //
    rand  logic                      [31:0] imm_in;
    rand  logic [PRF_BANK_COUNT-1:0] [31:0] reg_read_data_by_bank_in;
    rand  logic [PRF_BANK_COUNT-1:0] [31:0] forward_data_by_bank_in;

    // --- Outputs --- //
    logic ready_out;
    logic WB_valid_out;

    logic [31:0]             WB_data_out;
    logic [LOG_PR_COUNT-1:0] WB_PR_out;


    // --- OP Issue : Constraints --- //
    constraint op_in_range {
        op_in inside {
            4'b0000,
            4'b0001,
            4'b0010,
            4'b0011,
            4'b0100,
            4'b0101,
            4'b0110,
            4'b0111,
            4'b1000,
            4'b1101,
            4'b1111
        };
    }

    // --- Constructor --- //
    function new(string name = "alu_pipeline_seq_item");
        super.new(name);
    endfunction : new

endclass : alu_pipeline_seq_item

`endif