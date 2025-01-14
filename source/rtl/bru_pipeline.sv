/*
    Filename: bru_pipeline.sv
    Author: zlagpacan
    Description: RTL for Branch Resolution Unit Pipeline
    Spec: LOROF/spec/design/bru_pipeline.md
*/

`include "core_types_pkg.vh"
import core_types_pkg::*;

module bru_pipeline (

    // seq
    input logic CLK,
    input logic nRST,

    // BRU op issue to BRU IQ
    input logic                            issue_valid,
    input logic [3:0]                      issue_op,
    input logic [31:0]                     issue_PC,
    input logic [31:0]                     issue_speculated_next_PC,
    input logic [31:0]                     issue_imm,
    input logic                            issue_A_unneeded,
    input logic                            issue_A_forward,
    input logic [LOG_PRF_BANK_COUNT-1:0]   issue_A_bank,
    input logic                            issue_B_unneeded,
    input logic                            issue_B_forward,
    input logic [LOG_PRF_BANK_COUNT-1:0]   issue_B_bank,
    input logic [LOG_PR_COUNT-1:0]         issue_dest_PR,
    input logic [LOG_ROB_ENTRIES-1:0]      issue_ROB_index,

    // output feedback to BRU IQ
    output logic issue_ready,

    // reg read info and data from PRF
    input logic                                     A_reg_read_ack,
    input logic                                     A_reg_read_port,
    input logic                                     B_reg_read_ack,
    input logic                                     B_reg_read_port,
    input logic [PRF_BANK_COUNT-1:0][1:0][31:0]     reg_read_data_by_bank_by_port,

    // forward data from PRF
    input logic [PRF_BANK_COUNT-1:0][31:0] forward_data_by_bank,

    // writeback data to PRF
    output logic                        WB_valid,
    output logic [31:0]                 WB_data,
    output logic [LOG_PR_COUNT-1:0]     WB_PR,
    output logic [LOG_ROB_ENTRIES-1:0]  WB_ROB_index,

    // writeback backpressure from PRF
    input logic WB_ready,

    // restart req to ROB
        // no backpressure, ROB's job to deal with multiple identical req's
    output logic                        restart_req_valid,
    output logic                        restart_req_mispredict,
    output logic [LOG_ROB_ENTRIES-1:0]  restart_req_ROB_index,
    output logic [31:0]                 restart_req_PC,
    output logic                        restart_req_taken,

    // restart req backpressure from ROB
    input logic restart_req_ready
);

    // ----------------------------------------------------------------
    // Control Signals: 

    logic stall_WB;
    logic stall_EX;
    logic stall_OC;

    // ----------------------------------------------------------------
    // OC Stage Signals:

    logic                           valid_OC;
    logic [3:0]                     op_OC;
    logic [31:0]                    PC_OC;
    logic [31:0]                    speculated_next_PC_OC;
    logic [31:0]                    imm_OC;
    logic                           A_unneeded_OC;
    logic                           A_saved_OC;
    logic                           A_forward_OC;
    logic [LOG_PRF_BANK_COUNT-1:0]  A_bank_OC;
    logic                           B_unneeded_OC;
    logic                           B_saved_OC;
    logic                           B_forward_OC;
    logic [LOG_PRF_BANK_COUNT-1:0]  B_bank_OC;
    logic [LOG_PR_COUNT-1:0]        dest_PR_OC;
    logic [LOG_ROB_ENTRIES-1:0]     ROB_index_OC;

    logic [31:0] A_saved_data_OC;
    logic [31:0] B_saved_data_OC;

    logic launch_ready_OC;

    logic                           next_valid_EX;
    logic [3:0]                     next_op_EX;
    logic [31:0]                    next_PC_EX;
    logic [31:0]                    next_speculated_next_PC_EX;
    logic [31:0]                    next_imm_EX;
    logic [31:0]                    next_A_EX;
    logic [31:0]                    next_B_EX;
    logic [LOG_PR_COUNT-1:0]        next_dest_PR_EX;
    logic [LOG_ROB_ENTRIES-1:0]     next_ROB_index_EX;

    // ----------------------------------------------------------------
    // EX Stage Signals:

    logic                           valid_EX;
    logic [3:0]                     op_EX;
    logic [31:0]                    PC_EX;
    logic [31:0]                    speculated_next_PC_EX;
    logic [31:0]                    imm_EX;
    logic [31:0]                    A_EX;
    logic [31:0]                    B_EX;
    logic [LOG_PR_COUNT-1:0]        dest_PR_EX;
    logic [LOG_ROB_ENTRIES-1:0]     ROB_index_EX;

    logic [31:0]    PC_plus_4_EX;
    logic [31:0]    PC_plus_imm_EX;
    logic [31:0]    A_plus_imm_EX;

    logic                           next_WB_valid;
    logic [31:0]                    next_WB_data;
    logic [LOG_PR_COUNT-1:0]        next_WB_PR;
    logic [LOG_ROB_ENTRIES-1:0]     next_WB_ROB_index;

    logic                           next_restart_req_valid;
    logic                           next_restart_req_mispredict;
    logic [LOG_ROB_ENTRIES-1:0]     next_restart_req_ROB_index;
    logic [31:0]                    next_restart_req_PC;
    logic                           next_restart_req_taken;

    // ----------------------------------------------------------------
    // WB Stage Signals:

    // ----------------------------------------------------------------
    // Control Logic: 

    assign stall_WB = (WB_valid & ~WB_ready) | (restart_req_valid & ~restart_req_ready);
        // stall_WB only works for instructions with a WB (JAL, JALR, AUIPC)
    assign stall_EX = valid_EX & stall_WB;
        // stall_WB shouldn't happen with WB_valid anyway
    assign stall_OC = stall_EX & valid_OC;
        // this stall doesn't strictly "stall" OC
        // indicates that should stall values in OC if OC valid

    // ----------------------------------------------------------------
    // OC Stage Logic:

    // FF
    always_ff @ (posedge CLK, negedge nRST) begin
        if (~nRST) begin
            valid_OC <= 1'b0;
            op_OC <= 4'b0000;
            PC_OC <= 32'h0;
            speculated_next_PC_OC <= 32'h0;
            imm_OC <= 32'h0;
            A_unneeded_OC <= 1'b0;
            A_saved_OC <= 1'b0;
            A_forward_OC <= 1'b0;
            A_bank_OC <= '0;
            B_unneeded_OC <= 1'b0;
            B_saved_OC <= 1'b0;
            B_forward_OC <= 1'b0;
            B_bank_OC <= '0;
            dest_PR_OC <= '0;
            ROB_index_OC <= '0;
        end
        // stall OC stage when have valid op which can't move on: issue_ready == 1'b0
        else if (~issue_ready) begin
            valid_OC <= valid_OC;
            op_OC <= op_OC;
            PC_OC <= PC_OC;
            speculated_next_PC_OC <= speculated_next_PC_OC;
            imm_OC <= imm_OC;
            A_unneeded_OC <= A_unneeded_OC;
            A_saved_OC <= A_saved_OC | A_forward_OC | A_reg_read_ack;
            A_forward_OC <= 1'b0;
            A_bank_OC <= A_bank_OC;
            B_unneeded_OC <= B_unneeded_OC;
            B_saved_OC <= B_saved_OC | B_forward_OC | B_reg_read_ack;
            B_forward_OC <= 1'b0;
            B_bank_OC <= B_bank_OC;
            dest_PR_OC <= dest_PR_OC;
            ROB_index_OC <= ROB_index_OC;
        end
        // pass input issue to OC
        else begin
            valid_OC <= issue_valid;
            op_OC <= issue_op;
            PC_OC <= issue_PC;
            speculated_next_PC_OC <= issue_speculated_next_PC;
            imm_OC <= issue_imm;
            A_unneeded_OC <= issue_A_unneeded;
            A_saved_OC <= 1'b0;
            A_forward_OC <= issue_A_forward;
            A_bank_OC <= issue_A_bank;
            B_unneeded_OC <= issue_B_unneeded;
            B_saved_OC <= 1'b0;
            B_forward_OC <= issue_B_forward;
            B_bank_OC <= issue_B_bank;
            dest_PR_OC <= issue_dest_PR;
            ROB_index_OC <= issue_ROB_index;
        end
    end

    // FF
    always_ff @ (posedge CLK, negedge nRST) begin
        if (~nRST) begin
            A_saved_data_OC <= 32'h0;
            B_saved_data_OC <= 32'h0;
        end
        else begin
            A_saved_data_OC <= next_A_EX;
            B_saved_data_OC <= next_B_EX;
        end
    end

    assign launch_ready_OC = 
        // no backpressure
        ~stall_OC
        &
        // A operand present
        (A_unneeded_OC | A_saved_OC | A_forward_OC | A_reg_read_ack)
        &
        // B operand present
        (B_unneeded_OC | B_saved_OC | B_forward_OC | B_reg_read_ack)
    ;
    assign issue_ready = ~valid_OC | launch_ready_OC;

    assign next_valid_EX = valid_OC & launch_ready_OC;
    assign next_op_EX = op_OC;
    assign next_PC_EX = PC_OC;
    assign next_speculated_next_PC_EX = speculated_next_PC_OC;
    assign next_imm_EX = imm_OC;
    assign next_dest_PR_EX = dest_PR_OC;
    assign next_ROB_index_EX = ROB_index_OC;

    always_comb begin

        // collect A value to save OR pass to EX
        if (A_saved_OC) begin
            next_A_EX = A_saved_data_OC;
        end
        else if (A_forward_OC) begin
            next_A_EX = forward_data_by_bank[A_bank_OC];
        end
        else begin
            next_A_EX = reg_read_data_by_bank_by_port[A_bank_OC][A_reg_read_port];
        end

        // collect B value to save OR pass to EX
        if (B_saved_OC) begin
            next_B_EX = B_saved_data_OC;
        end
        else if (B_forward_OC) begin
            next_B_EX = forward_data_by_bank[B_bank_OC];
        end
        else begin
            next_B_EX = reg_read_data_by_bank_by_port[B_bank_OC][B_reg_read_port];
        end
    end

    // ----------------------------------------------------------------
    // EX Stage Logic:

    // FF
    always_ff @ (posedge CLK, negedge nRST) begin
        if (~nRST) begin
            valid_EX <= 1'b0;
            op_EX <= 4'b0000;
            PC_EX <= 32'h0;
            speculated_next_PC_EX <= 32'h0;
            imm_EX <= 32'h0;
            A_EX <= 32'h0;
            B_EX <= 32'h0;
            dest_PR_EX <= '0;
            ROB_index_EX <= '0;
        end
        else if (stall_EX) begin
            valid_EX <= valid_EX;
            op_EX <= op_EX;
            PC_EX <= PC_EX;
            speculated_next_PC_EX <= speculated_next_PC_EX;
            imm_EX <= imm_EX;
            A_EX <= A_EX;
            B_EX <= B_EX;
            dest_PR_EX <= dest_PR_EX;
            ROB_index_EX <= ROB_index_EX;
        end
        else begin
            valid_EX <= next_valid_EX;
            op_EX <= next_op_EX;
            PC_EX <= next_PC_EX;
            speculated_next_PC_EX <= next_speculated_next_PC_EX;
            imm_EX <= next_imm_EX;
            A_EX <= next_A_EX;
            B_EX <= next_B_EX;
            dest_PR_EX <= next_dest_PR_EX;
            ROB_index_EX <= next_ROB_index_EX;
        end
    end

    assign next_WB_PR = dest_PR_EX;
    assign next_WB_ROB_index = ROB_index_EX;
    
    assign next_restart_req_ROB_index = ROB_index_EX;

    assign PC_plus_4_EX = PC_EX + 32'h4;
    assign PC_plus_imm_EX = PC_EX + imm_EX;
    assign A_plus_imm_EX = A_EX + imm_EX;

    assign spec_neq_PC_plus_4_EX = speculated_next_PC_EX != PC_plus_4_EX;
    assign spec_neq_PC_plus_imm_EX = speculated_next_PC_EX != PC_plus_imm_EX;

    always_comb begin

        case (op_EX)
        
            4'b0000: // JALR: R[rd] <= PC + 4, PC <= R[rs1] + imm
            begin
                next_WB_valid = valid_EX;
                next_WB_data = PC_plus_4_EX;

                next_restart_req_valid = valid_EX;
                next_restart_req_mispredict = spec_neq_PC_plus_imm_EX;
                next_restart_req_PC = A_plus_imm_EX;
                next_restart_req_taken = 1'b1;
            end

            4'b0001: // JAL: R[rd] <= PC + 4, PC <= PC + imm
            begin
                next_WB_valid = valid_EX;
                next_WB_data = PC_plus_4_EX;
                
                next_restart_req_valid = valid_EX;
                next_restart_req_mispredict = spec_neq_PC_plus_imm_EX;
                next_restart_req_PC = PC_plus_imm_EX;
                next_restart_req_taken = 1'b1;
            end

            4'b0100: // AUIPC: R[rd] <= PC + imm
            begin
                next_WB_valid = valid_EX;
                next_WB_data = PC_plus_imm_EX;

                next_restart_req_valid = 1'b0;
                next_restart_req_mispredict = spec_neq_PC_plus_imm_EX;
                next_restart_req_PC = PC_plus_imm_EX;
                next_restart_req_taken = 1'b1;
            end

            4'b1000: // BEQ: PC <= (R[rs1] == R[rs2]) ? PC + imm : PC + 4
            begin
                next_WB_valid = 1'b0;
                next_WB_data = PC_plus_4_EX;

                next_restart_req_valid = valid_EX;
                if (A_EX == B_EX) begin
                    next_restart_req_mispredict = spec_neq_PC_plus_imm_EX;
                    next_restart_req_PC = PC_plus_imm_EX;
                    next_restart_req_taken = 1'b1;
                end
                else begin
                    next_restart_req_mispredict = spec_neq_PC_plus_4_EX;
                    next_restart_req_PC = PC_plus_4_EX;
                    next_restart_req_taken = 1'b0;
                end
            end

            4'b1001: // BNE: PC <= (R[rs1] != R[rs2]) ? PC + imm : PC + 4
            begin
                next_WB_valid = 1'b0;
                next_WB_data = PC_plus_4_EX;

                next_restart_req_valid = valid_EX;
                if (A_EX != B_EX) begin
                    next_restart_req_mispredict = spec_neq_PC_plus_imm_EX;
                    next_restart_req_PC = PC_plus_imm_EX;
                    next_restart_req_taken = 1'b1;
                end
                else begin
                    next_restart_req_mispredict = spec_neq_PC_plus_4_EX;
                    next_restart_req_PC = PC_plus_4_EX;
                    next_restart_req_taken = 1'b0;
                end
            end

            4'b1100: // BLT: PC <= (signed(R[rs1]) < signed(R[rs2])) ? PC + imm : PC + 4
            begin
                next_WB_valid = 1'b0;
                next_WB_data = PC_plus_4_EX;

                next_restart_req_valid = valid_EX;
                if ($signed(A_EX) < $signed(B_EX)) begin
                    next_restart_req_mispredict = spec_neq_PC_plus_imm_EX;
                    next_restart_req_PC = PC_plus_imm_EX;
                    next_restart_req_taken = 1'b1;
                end
                else begin
                    next_restart_req_mispredict = spec_neq_PC_plus_4_EX;
                    next_restart_req_PC = PC_plus_4_EX;
                    next_restart_req_taken = 1'b0;
                end
            end

            4'b1101: // BGE: PC <= (signed(R[rs1]) >= signed(R[rs2])) ? PC + imm : PC + 4
            begin
                next_WB_valid = 1'b0;
                next_WB_data = PC_plus_4_EX;

                next_restart_req_valid = valid_EX;
                if ($signed(A_EX) >= $signed(B_EX)) begin
                    next_restart_req_mispredict = spec_neq_PC_plus_imm_EX;
                    next_restart_req_PC = PC_plus_imm_EX;
                    next_restart_req_taken = 1'b1;
                end
                else begin
                    next_restart_req_mispredict = spec_neq_PC_plus_4_EX;
                    next_restart_req_PC = PC_plus_4_EX;
                    next_restart_req_taken = 1'b0;
                end
            end

            4'b1110: // BLTU: PC <= (R[rs1] < R[rs2]) ? PC + imm : PC + 4
            begin
                next_WB_valid = 1'b0;
                next_WB_data = PC_plus_4_EX;

                next_restart_req_valid = valid_EX;
                if (A_EX < B_EX) begin
                    next_restart_req_mispredict = spec_neq_PC_plus_imm_EX;
                    next_restart_req_PC = PC_plus_imm_EX;
                    next_restart_req_taken = 1'b1;
                end
                else begin
                    next_restart_req_mispredict = spec_neq_PC_plus_4_EX;
                    next_restart_req_PC = PC_plus_4_EX;
                    next_restart_req_taken = 1'b0;
                end
            end

            4'b1111: // BGEU: PC <= (R[rs1] >= R[rs2]) ? PC + imm : PC + 4
            begin
                next_WB_valid = 1'b0;
                next_WB_data = PC_plus_4_EX;

                next_restart_req_valid = valid_EX;
                if (A_EX >= B_EX) begin
                    next_restart_req_mispredict = spec_neq_PC_plus_imm_EX;
                    next_restart_req_PC = PC_plus_imm_EX;
                    next_restart_req_taken = 1'b1;
                end
                else begin
                    next_restart_req_mispredict = spec_neq_PC_plus_4_EX;
                    next_restart_req_PC = PC_plus_4_EX;
                    next_restart_req_taken = 1'b0;
                end
            end

            default:
            begin
                next_WB_valid = 1'b0;
                next_WB_data = PC_plus_4_EX;

                next_restart_req_valid = 1'b0;
                next_restart_req_mispredict = spec_neq_PC_plus_imm_EX;
                next_restart_req_PC = PC_plus_imm_EX;
                next_restart_req_taken = 1'b1;
            end

        endcase
    end

    // ----------------------------------------------------------------
    // WB Stage Logic:

    // FF
    always_ff @ (posedge CLK, negedge nRST) begin
        if (~nRST) begin
            WB_valid <= 1'b0;
            WB_data <= 32'h4;
            WB_PR <= '0;
            WB_ROB_index <= '0;
            restart_req_valid <= 1'b0;
            restart_req_mispredict <= 1'b0;
            restart_req_ROB_index <= '0;
            restart_req_PC <= 32'h0;
            restart_req_taken <= 1'b1;
        end
        else if (stall_WB) begin
            WB_valid <= WB_valid & ~WB_ready;
            WB_data <= WB_data;
            WB_PR <= WB_PR;
            WB_ROB_index <= WB_ROB_index;
            restart_req_valid <= restart_req_valid & ~restart_req_ready;
            restart_req_mispredict <= restart_req_mispredict;
            restart_req_ROB_index <= restart_req_ROB_index;
            restart_req_PC <= restart_req_PC;
            restart_req_taken <= restart_req_taken;
        end
        else begin
            WB_valid <= next_WB_valid;
            WB_data <= next_WB_data;
            WB_PR <= next_WB_PR;
            WB_ROB_index <= next_WB_ROB_index;
            restart_req_valid <= next_restart_req_valid;
            restart_req_mispredict <= next_restart_req_mispredict;
            restart_req_ROB_index <= next_restart_req_ROB_index;
            restart_req_PC <= next_restart_req_PC;
            restart_req_taken <= next_restart_req_taken;
        end
    end

endmodule