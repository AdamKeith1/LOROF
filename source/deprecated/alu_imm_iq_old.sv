/*
    Filename: alu_imm_iq.sv
    Author: zlagpacan
    Description: RTL for Issue Queue for ALU Register-Immediate Pipeline
    Spec: LOROF/spec/design/alu_imm_iq.md
*/

`include "core_types_pkg.vh"
import core_types_pkg::*;

module alu_imm_iq #(
    parameter ALU_IMM_IQ_ENTRIES = 8
) (
    // seq
    input logic CLK,
    input logic nRST,

    // op dispatch by way
    input logic [3:0]                       dispatch_attempt_by_way,
    input logic [3:0]                       dispatch_valid_alu_imm_by_way,
    input logic [3:0][3:0]                  dispatch_op_by_way,
    input logic [3:0][11:0]                 dispatch_imm12_by_way,
    input logic [3:0][LOG_PR_COUNT-1:0]     dispatch_A_PR_by_way,
    input logic [3:0]                       dispatch_A_ready_by_way,
    input logic [3:0]                       dispatch_A_is_zero_by_way,
    input logic [3:0][LOG_PR_COUNT-1:0]     dispatch_dest_PR_by_way,
    input logic [3:0][LOG_ROB_ENTRIES-1:0]  dispatch_ROB_index_by_way,

    // op dispatch feedback
    output logic [3:0] dispatch_ack_by_way,

    // pipeline feedback
    input logic alu_imm_pipeline_ready,

    // writeback bus by bank
    input logic [PRF_BANK_COUNT-1:0]                                        WB_bus_valid_by_bank,
    input logic [PRF_BANK_COUNT-1:0][LOG_PR_COUNT-LOG_PRF_BANK_COUNT-1:0]   WB_bus_upper_PR_by_bank,

    // op issue to ALU Reg-Imm Pipeline
    output logic                            issue_alu_imm_valid,
    output logic [3:0]                      issue_alu_imm_op,
    output logic [11:0]                     issue_alu_imm_imm12,
    output logic                            issue_alu_imm_A_forward,
    output logic                            issue_alu_imm_A_is_zero,
    output logic [LOG_PRF_BANK_COUNT-1:0]   issue_alu_imm_A_bank,
    output logic [LOG_PR_COUNT-1:0]         issue_alu_imm_dest_PR,
    output logic [LOG_ROB_ENTRIES-1:0]      issue_alu_imm_ROB_index,

    // ALU Reg-Imm Pipeline reg read req to PRF
    output logic                        PRF_alu_imm_req_A_valid,
    output logic [LOG_PR_COUNT-1:0]     PRF_alu_imm_req_A_PR
);

    // ----------------------------------------------------------------
    // Signals:

    // IQ entries
    logic [ALU_IMM_IQ_ENTRIES-1:0]                      valid_alu_imm_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0][3:0]                 op_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0][11:0]                imm12_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0][LOG_PR_COUNT-1:0]    A_PR_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0]                      A_ready_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0]                      A_is_zero_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0][LOG_PR_COUNT-1:0]    dest_PR_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0][LOG_ROB_ENTRIES-1:0] ROB_index_by_entry;

    // issue logic helper signals
    logic [ALU_IMM_IQ_ENTRIES-1:0]  A_forward_by_entry;

    logic [ALU_IMM_IQ_ENTRIES-1:0]  issue_alu_imm_ready_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0]  issue_alu_imm_one_hot_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0]  issue_alu_imm_mask;

    // incoming dispatch crossbar by entry
    logic [ALU_IMM_IQ_ENTRIES-1:0]                          dispatch_valid_alu_imm_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0][3:0]                     dispatch_op_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0][11:0]                    dispatch_imm12_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0][LOG_PR_COUNT-1:0]        dispatch_A_PR_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0]                          dispatch_A_ready_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0]                          dispatch_A_is_zero_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0][LOG_PR_COUNT-1:0]        dispatch_dest_PR_by_entry;
    logic [ALU_IMM_IQ_ENTRIES-1:0][LOG_ROB_ENTRIES-1:0]     dispatch_ROB_index_by_entry;

    // incoming dispatch req masks for each of 4 possible dispatch ways
    logic [3:0][ALU_IMM_IQ_ENTRIES-1:0]     dispatch_open_mask_by_way;
    logic [3:0][ALU_IMM_IQ_ENTRIES-1:0]     dispatch_pe_one_hot_by_way;
    logic [3:0][ALU_IMM_IQ_ENTRIES-1:0]     dispatch_one_hot_by_way;

    // ----------------------------------------------------------------
    // Issue Logic:

    // forwarding check
    always_comb begin
        for (int i = 0; i < ALU_IMM_IQ_ENTRIES; i++) begin
            A_forward_by_entry[i] = (A_PR_by_entry[i][LOG_PR_COUNT-1:LOG_PRF_BANK_COUNT] == WB_bus_upper_PR_by_bank[A_PR_by_entry[i][LOG_PRF_BANK_COUNT-1:0]]) & WB_bus_valid_by_bank[A_PR_by_entry[i][LOG_PRF_BANK_COUNT-1:0]];
        end
    end

    // ALU Reg-Imm issue:

    // ready check
    assign issue_alu_imm_ready_by_entry = 
        {ALU_IMM_IQ_ENTRIES{alu_imm_pipeline_ready}}
        &
        valid_alu_imm_by_entry
        &
        (A_ready_by_entry | A_forward_by_entry | A_is_zero_by_entry)
    ;

    // pe
    pe_lsb #(.WIDTH(ALU_IMM_IQ_ENTRIES)) ISSUE_ALU_IMM_PE_LSB (
        .req_vec(issue_alu_imm_ready_by_entry),
        .ack_one_hot(issue_alu_imm_one_hot_by_entry),
        .ack_mask(issue_alu_imm_mask)
    );

    // mux
    always_comb begin

        // issue automatically valid if any entry ready
        issue_alu_imm_valid = |issue_alu_imm_ready_by_entry;

        // one-hot mux over entries for final issue:
        issue_alu_imm_op = '0;
        issue_alu_imm_imm12 = '0;
        issue_alu_imm_A_forward = '0;
        issue_alu_imm_A_is_zero = '0;
        issue_alu_imm_A_bank = '0;
        issue_alu_imm_dest_PR = '0;
        issue_alu_imm_ROB_index = '0;

        PRF_alu_imm_req_A_valid = '0;
        PRF_alu_imm_req_A_PR = '0;

        for (int entry = 0; entry < ALU_IMM_IQ_ENTRIES; entry++) begin

            if (issue_alu_imm_one_hot_by_entry[entry]) begin

                issue_alu_imm_op |= op_by_entry[entry];
                issue_alu_imm_imm12 |= imm12_by_entry[entry];
                issue_alu_imm_A_forward |= A_forward_by_entry[entry];
                issue_alu_imm_A_is_zero |= A_is_zero_by_entry[entry];
                issue_alu_imm_A_bank |= A_PR_by_entry[entry][LOG_PRF_BANK_COUNT-1:0];
                issue_alu_imm_dest_PR |= dest_PR_by_entry[entry];
                issue_alu_imm_ROB_index |= ROB_index_by_entry[entry];

                PRF_alu_imm_req_A_valid |= ~A_forward_by_entry[entry] & ~A_is_zero_by_entry[entry];
                PRF_alu_imm_req_A_PR |= A_PR_by_entry[entry];
            end
        end
    end

    // ----------------------------------------------------------------
    // Dispatch Logic:

    // cascaded dispatch mask PE's by way:

    // way 0
    assign dispatch_open_mask_by_way[0] = ~valid_alu_imm_by_entry;
    pe_lsb #(.WIDTH(ALU_IMM_IQ_ENTRIES)) DISPATCH_WAY0_PE_LSB (
        .req_vec(dispatch_open_mask_by_way[0]),
        .ack_one_hot(dispatch_pe_one_hot_by_way[0]),
        .ack_mask() // unused
    );
    assign dispatch_one_hot_by_way[0] = dispatch_pe_one_hot_by_way[0] & {ALU_IMM_IQ_ENTRIES{dispatch_attempt_by_way[0]}};

    // way 1
    assign dispatch_open_mask_by_way[1] = dispatch_open_mask_by_way[0] & ~dispatch_one_hot_by_way[0];
    pe_lsb #(.WIDTH(ALU_IMM_IQ_ENTRIES)) DISPATCH_WAY1_PE_LSB (
        .req_vec(dispatch_open_mask_by_way[1]),
        .ack_one_hot(dispatch_pe_one_hot_by_way[1]),
        .ack_mask() // unused
    );
    assign dispatch_one_hot_by_way[1] = dispatch_pe_one_hot_by_way[1] & {ALU_IMM_IQ_ENTRIES{dispatch_attempt_by_way[1]}};
    
    assign dispatch_open_mask_by_way[2] = dispatch_open_mask_by_way[1] & ~dispatch_one_hot_by_way[1];
    pe_lsb #(.WIDTH(ALU_IMM_IQ_ENTRIES)) DISPATCH_WAY2_PE_LSB (
        .req_vec(dispatch_open_mask_by_way[2]),
        .ack_one_hot(dispatch_pe_one_hot_by_way[2]),
        .ack_mask() // unused
    );
    assign dispatch_one_hot_by_way[2] = dispatch_pe_one_hot_by_way[2] & {ALU_IMM_IQ_ENTRIES{dispatch_attempt_by_way[2]}};
    
    assign dispatch_open_mask_by_way[3] = dispatch_open_mask_by_way[2] & ~dispatch_one_hot_by_way[2];
    pe_lsb #(.WIDTH(ALU_IMM_IQ_ENTRIES)) DISPATCH_WAY3_PE_LSB (
        .req_vec(dispatch_open_mask_by_way[3]),
        .ack_one_hot(dispatch_pe_one_hot_by_way[3]),
        .ack_mask() // unused
    );
    assign dispatch_one_hot_by_way[3] = dispatch_pe_one_hot_by_way[3] & {ALU_IMM_IQ_ENTRIES{dispatch_attempt_by_way[3]}};

    // give dispatch feedback
    always_comb begin
        for (int way = 0; way < 4; way++) begin
            dispatch_ack_by_way[way] = |dispatch_one_hot_by_way[way];
            dispatch_ack_by_way[way] = |(dispatch_open_mask_by_way[way] & {ALU_IMM_IQ_ENTRIES{dispatch_attempt_by_way[way]}});
        end
    end

    // route PE'd dispatch to entries
    always_comb begin
    
        dispatch_valid_alu_imm_by_entry = '0;
        dispatch_op_by_entry = '0;
        dispatch_imm12_by_entry = '0;
        dispatch_A_PR_by_entry = '0;
        dispatch_A_ready_by_entry = '0;
        dispatch_A_is_zero_by_entry = '0;
        dispatch_dest_PR_by_entry = '0;
        dispatch_ROB_index_by_entry = '0;

        // one-hot mux selecting among ways at each entry
        for (int entry = 0; entry < ALU_IMM_IQ_ENTRIES; entry++) begin

            for (int way = 0; way < 4; way++) begin

                if (dispatch_one_hot_by_way[way][entry]) begin

                    dispatch_valid_alu_imm_by_entry[entry] |= dispatch_valid_alu_imm_by_way[way];
                    dispatch_op_by_entry[entry] |= dispatch_op_by_way[way];
                    dispatch_imm12_by_entry[entry] |= dispatch_imm12_by_way[way];
                    dispatch_A_PR_by_entry[entry] |= dispatch_A_PR_by_way[way];
                    dispatch_A_ready_by_entry[entry] |= dispatch_A_ready_by_way[way];
                    dispatch_A_is_zero_by_entry[entry] |= dispatch_A_is_zero_by_way[way];
                    dispatch_dest_PR_by_entry[entry] |= dispatch_dest_PR_by_way[way];
                    dispatch_ROB_index_by_entry[entry] |= dispatch_ROB_index_by_way[way];
                end
            end
        end
    end

    always_ff @ (posedge CLK, negedge nRST) begin
        if (~nRST) begin
            valid_alu_imm_by_entry <= '0;
            op_by_entry <= '0;
            imm12_by_entry <= '0;
            A_PR_by_entry <= '0;
            A_ready_by_entry <= '0;
            A_is_zero_by_entry <= '0;
            dest_PR_by_entry <= '0;
            ROB_index_by_entry <= '0;
        end
        else begin

            // --------------------------------------------------------
            // highest entry only takes self:
                // self: [ALU_IMM_IQ_ENTRIES-1]

            // check take above -> clear entry
            if (issue_alu_imm_mask[ALU_IMM_IQ_ENTRIES-1]) begin
                valid_alu_imm_by_entry[ALU_IMM_IQ_ENTRIES-1] <= 1'b0;
            end

            // otherwise take self
            else begin

                // take self valid entry
                if (valid_alu_imm_by_entry[ALU_IMM_IQ_ENTRIES-1]) begin
                    valid_alu_imm_by_entry[ALU_IMM_IQ_ENTRIES-1] <= valid_alu_imm_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    op_by_entry[ALU_IMM_IQ_ENTRIES-1] <= op_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    imm12_by_entry[ALU_IMM_IQ_ENTRIES-1] <= imm12_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    A_PR_by_entry[ALU_IMM_IQ_ENTRIES-1] <= A_PR_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    A_ready_by_entry[ALU_IMM_IQ_ENTRIES-1] <= A_ready_by_entry[ALU_IMM_IQ_ENTRIES-1] | A_forward_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    A_is_zero_by_entry[ALU_IMM_IQ_ENTRIES-1] <= A_is_zero_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    dest_PR_by_entry[ALU_IMM_IQ_ENTRIES-1] <= dest_PR_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    ROB_index_by_entry[ALU_IMM_IQ_ENTRIES-1] <= ROB_index_by_entry[ALU_IMM_IQ_ENTRIES-1];
                end

                // take self dispatch
                else begin
                    valid_alu_imm_by_entry[ALU_IMM_IQ_ENTRIES-1] <= dispatch_valid_alu_imm_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    op_by_entry[ALU_IMM_IQ_ENTRIES-1] <= dispatch_op_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    imm12_by_entry[ALU_IMM_IQ_ENTRIES-1] <= dispatch_imm12_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    A_PR_by_entry[ALU_IMM_IQ_ENTRIES-1] <= dispatch_A_PR_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    A_ready_by_entry[ALU_IMM_IQ_ENTRIES-1] <= dispatch_A_ready_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    A_is_zero_by_entry[ALU_IMM_IQ_ENTRIES-1] <= dispatch_A_is_zero_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    dest_PR_by_entry[ALU_IMM_IQ_ENTRIES-1] <= dispatch_dest_PR_by_entry[ALU_IMM_IQ_ENTRIES-1];
                    ROB_index_by_entry[ALU_IMM_IQ_ENTRIES-1] <= dispatch_ROB_index_by_entry[ALU_IMM_IQ_ENTRIES-1];
                end
            end

            // --------------------------------------------------------
            // remaining lower entries can take self or above
                // [ALU_IMM_IQ_ENTRIES-1] can only take self
            for (int i = 0; i <= ALU_IMM_IQ_ENTRIES-2; i++) begin

                // check take above
                if (issue_alu_imm_mask[i]) begin

                    // take valid entry above
                    if (valid_alu_imm_by_entry[i+1]) begin
                        valid_alu_imm_by_entry[i] <= valid_alu_imm_by_entry[i+1];
                        op_by_entry[i] <= op_by_entry[i+1];
                        imm12_by_entry[i] <= imm12_by_entry[i+1];
                        A_PR_by_entry[i] <= A_PR_by_entry[i+1];
                        A_ready_by_entry[i] <= A_ready_by_entry[i+1] | A_forward_by_entry[i+1];
                        A_is_zero_by_entry[i] <= A_is_zero_by_entry[i+1];
                        dest_PR_by_entry[i] <= dest_PR_by_entry[i+1];
                        ROB_index_by_entry[i] <= ROB_index_by_entry[i+1];
                    end

                    // take dispatch above
                    else begin
                        valid_alu_imm_by_entry[i] <= dispatch_valid_alu_imm_by_entry[i+1];
                        op_by_entry[i] <= dispatch_op_by_entry[i+1];
                        imm12_by_entry[i] <= dispatch_imm12_by_entry[i+1];
                        A_PR_by_entry[i] <= dispatch_A_PR_by_entry[i+1];
                        A_ready_by_entry[i] <= dispatch_A_ready_by_entry[i+1];
                        A_is_zero_by_entry[i] <= dispatch_A_is_zero_by_entry[i+1];
                        dest_PR_by_entry[i] <= dispatch_dest_PR_by_entry[i+1];
                        ROB_index_by_entry[i] <= dispatch_ROB_index_by_entry[i+1];
                    end
                end

                // otherwise take self
                else begin

                    // take self valid entry
                    if (valid_alu_imm_by_entry[i]) begin
                        valid_alu_imm_by_entry[i] <= valid_alu_imm_by_entry[i];
                        op_by_entry[i] <= op_by_entry[i];
                        imm12_by_entry[i] <= imm12_by_entry[i];
                        A_PR_by_entry[i] <= A_PR_by_entry[i];
                        A_ready_by_entry[i] <= A_ready_by_entry[i] | A_forward_by_entry[i];
                        A_is_zero_by_entry[i] <= A_is_zero_by_entry[i];
                        dest_PR_by_entry[i] <= dest_PR_by_entry[i];
                        ROB_index_by_entry[i] <= ROB_index_by_entry[i];
                    end

                    // take self dispatch
                    else begin
                        valid_alu_imm_by_entry[i] <= dispatch_valid_alu_imm_by_entry[i];
                        op_by_entry[i] <= dispatch_op_by_entry[i];
                        imm12_by_entry[i] <= dispatch_imm12_by_entry[i];
                        A_PR_by_entry[i] <= dispatch_A_PR_by_entry[i];
                        A_ready_by_entry[i] <= dispatch_A_ready_by_entry[i];
                        A_is_zero_by_entry[i] <= dispatch_A_is_zero_by_entry[i];
                        dest_PR_by_entry[i] <= dispatch_dest_PR_by_entry[i];
                        ROB_index_by_entry[i] <= dispatch_ROB_index_by_entry[i];
                    end
                end
            end
        end
    end

endmodule