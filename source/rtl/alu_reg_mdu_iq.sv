/*
    Filename: alu_reg_mdu_iq.sv
    Author: zlagpacan
    Description: RTL for Issue Queue for ALU Register-Register Pipeline and Multiplication-Division Unit Pipeline
    Spec: LOROF/spec/design/alu_reg_mdu_iq.md
*/

`include "core_types_pkg.vh"
import core_types_pkg::*;

module alu_reg_mdu_iq #(
    parameter ALU_REG_MDU_IQ_ENTRIES = 8
) (
    // seq
    input logic CLK,
    input logic nRST,

    // op dispatch by way
    input logic [3:0]                       dispatch_attempt_by_way,
    input logic [3:0]                       dispatch_valid_alu_reg_by_way,
    input logic [3:0]                       dispatch_valid_mdu_by_way,
    input logic [3:0][3:0]                  dispatch_op_by_way,
    input logic [3:0][LOG_PR_COUNT-1:0]     dispatch_A_PR_by_way,
    input logic [3:0]                       dispatch_A_ready_by_way,
    input logic [3:0]                       dispatch_A_is_zero_by_way,
    input logic [3:0][LOG_PR_COUNT-1:0]     dispatch_B_PR_by_way,
    input logic [3:0]                       dispatch_B_ready_by_way,
    input logic [3:0]                       dispatch_B_is_zero_by_way,
    input logic [3:0][LOG_PR_COUNT-1:0]     dispatch_dest_PR_by_way,
    input logic [3:0][LOG_ROB_ENTRIES-1:0]  dispatch_ROB_index_by_way,

    // op dispatch feedback
    output logic [3:0] dispatch_ack_by_way,

    // pipeline feedback
    input logic alu_reg_pipeline_ready,
    input logic mdu_pipeline_ready,

    // writeback bus by bank
    input logic [PRF_BANK_COUNT-1:0]                                        WB_bus_valid_by_bank,
    input logic [PRF_BANK_COUNT-1:0][LOG_PR_COUNT-LOG_PRF_BANK_COUNT-1:0]   WB_bus_upper_PR_by_bank,

    // op issue to ALU Reg-Reg Pipeline
    output logic                            issue_alu_reg_valid,
    output logic [3:0]                      issue_alu_reg_op,
    output logic                            issue_alu_reg_A_forward,
    output logic                            issue_alu_reg_A_is_zero,
    output logic [LOG_PRF_BANK_COUNT-1:0]   issue_alu_reg_A_bank,
    output logic                            issue_alu_reg_B_forward,
    output logic                            issue_alu_reg_B_is_zero,
    output logic [LOG_PRF_BANK_COUNT-1:0]   issue_alu_reg_B_bank,
    output logic [LOG_PR_COUNT-1:0]         issue_alu_reg_dest_PR,
    output logic [LOG_ROB_ENTRIES-1:0]      issue_alu_reg_ROB_index,

    // ALU Reg-Reg Pipeline reg read req to PRF
    output logic                        PRF_alu_reg_req_A_valid,
    output logic [LOG_PR_COUNT-1:0]     PRF_alu_reg_req_A_PR,
    output logic                        PRF_alu_reg_req_B_valid,
    output logic [LOG_PR_COUNT-1:0]     PRF_alu_reg_req_B_PR,

    // op issue to MDU Pipeline
    output logic                            issue_mdu_valid,
    output logic [3:0]                      issue_mdu_op,
    output logic                            issue_mdu_A_forward,
    output logic                            issue_mdu_A_is_zero,
    output logic [LOG_PRF_BANK_COUNT-1:0]   issue_mdu_A_bank,
    output logic                            issue_mdu_B_forward,
    output logic                            issue_mdu_B_is_zero,
    output logic [LOG_PRF_BANK_COUNT-1:0]   issue_mdu_B_bank,
    output logic [LOG_PR_COUNT-1:0]         issue_mdu_dest_PR,
    output logic [LOG_ROB_ENTRIES-1:0]      issue_mdu_ROB_index,

    // MDU Pipeline reg read req to PRF
    output logic                        PRF_mdu_req_A_valid,
    output logic [LOG_PR_COUNT-1:0]     PRF_mdu_req_A_PR,
    output logic                        PRF_mdu_req_B_valid,
    output logic [LOG_PR_COUNT-1:0]     PRF_mdu_req_B_PR
);

    // ----------------------------------------------------------------
    // Signals:

    // IQ entries
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                      valid_alu_reg_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                      valid_mdu_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0][3:0]                 op_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0][LOG_PR_COUNT-1:0]    A_PR_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                      A_ready_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                      A_is_zero_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0][LOG_PR_COUNT-1:0]    B_PR_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                      B_ready_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                      B_is_zero_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0][LOG_PR_COUNT-1:0]    dest_PR_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0][LOG_ROB_ENTRIES-1:0] ROB_index_by_entry;

    // issue logic helper signals
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]  A_forward_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]  B_forward_by_entry;

    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]  issue_alu_reg_ready_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]  issue_alu_reg_one_hot_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]  issue_alu_reg_mask;

    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]  issue_mdu_ready_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]  issue_mdu_one_hot_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]  issue_mdu_mask;

    // incoming dispatch crossbar by entry
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                          dispatch_valid_alu_reg_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                          dispatch_valid_mdu_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0][3:0]                     dispatch_op_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0][LOG_PR_COUNT-1:0]        dispatch_A_PR_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                          dispatch_A_ready_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                          dispatch_A_is_zero_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0][LOG_PR_COUNT-1:0]        dispatch_B_PR_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                          dispatch_B_ready_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0]                          dispatch_B_is_zero_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0][LOG_PR_COUNT-1:0]        dispatch_dest_PR_by_entry;
    logic [ALU_REG_MDU_IQ_ENTRIES-1:0][LOG_ROB_ENTRIES-1:0]     dispatch_ROB_index_by_entry;

    // incoming dispatch req masks for each of 4 possible dispatch ways
    logic [3:0][ALU_REG_MDU_IQ_ENTRIES-1:0]     dispatch_open_mask_by_way;
    logic [3:0][ALU_REG_MDU_IQ_ENTRIES-1:0]     dispatch_pe_one_hot_by_way;
    logic [3:0][ALU_REG_MDU_IQ_ENTRIES-1:0]     dispatch_one_hot_by_way;

    // // adder approach
    // logic [$clog2(ALU_REG_MDU_IQ_ENTRIES)+1-1:0]          lowest_invalid_entry, next_lowest_invalid_entry;
    // logic [3:0][$clog2(ALU_REG_MDU_IQ_ENTRIES)-1:0]     lowest_invalid_entry_by_way; 

    // logic [ALU_REG_MDU_IQ_ENTRIES-1:0][1:0] dispatch_way_index_by_entry;

    // ----------------------------------------------------------------
    // Issue Logic:

    // forwarding check
    always_comb begin
        for (int i = 0; i < ALU_REG_MDU_IQ_ENTRIES; i++) begin
            A_forward_by_entry[i] = (A_PR_by_entry[i][LOG_PR_COUNT-1:LOG_PRF_BANK_COUNT] == WB_bus_upper_PR_by_bank[A_PR_by_entry[i][LOG_PRF_BANK_COUNT-1:0]]) & WB_bus_valid_by_bank[A_PR_by_entry[i][LOG_PRF_BANK_COUNT-1:0]];
            B_forward_by_entry[i] = (B_PR_by_entry[i][LOG_PR_COUNT-1:LOG_PRF_BANK_COUNT] == WB_bus_upper_PR_by_bank[B_PR_by_entry[i][LOG_PRF_BANK_COUNT-1:0]]) & WB_bus_valid_by_bank[B_PR_by_entry[i][LOG_PRF_BANK_COUNT-1:0]];
        end
    end

    // ALU Reg-Reg issue:

    // ready check
    assign issue_alu_reg_ready_by_entry = 
        {ALU_REG_MDU_IQ_ENTRIES{alu_reg_pipeline_ready}}
        &
        valid_alu_reg_by_entry
        &
        (A_ready_by_entry | A_forward_by_entry | A_is_zero_by_entry)
        &
        (B_ready_by_entry | B_forward_by_entry | B_is_zero_by_entry)
    ;

    // pe
    pe_lsb #(.WIDTH(ALU_REG_MDU_IQ_ENTRIES)) ISSUE_ALU_REG_PE_LSB (
        .req_vec(issue_alu_reg_ready_by_entry),
        .ack_one_hot(issue_alu_reg_one_hot_by_entry),
        .ack_mask(issue_alu_reg_mask)
    );

    // mux
    always_comb begin

        // issue automatically valid if any entry ready
        issue_alu_reg_valid = |issue_alu_reg_ready_by_entry;

        // one-hot mux over entries for final issue:
        issue_alu_reg_op = '0;
        issue_alu_reg_A_forward = '0;
        issue_alu_reg_A_is_zero = '0;
        issue_alu_reg_A_bank = '0;
        issue_alu_reg_B_forward = '0;
        issue_alu_reg_B_is_zero = '0;
        issue_alu_reg_B_bank = '0;
        issue_alu_reg_dest_PR = '0;
        issue_alu_reg_ROB_index = '0;

        PRF_alu_reg_req_A_valid = '0;
        PRF_alu_reg_req_A_PR = '0;
        PRF_alu_reg_req_B_valid = '0;
        PRF_alu_reg_req_B_PR = '0;

        for (int entry = 0; entry < ALU_REG_MDU_IQ_ENTRIES; entry++) begin

            if (issue_alu_reg_one_hot_by_entry[entry]) begin

                issue_alu_reg_op |= op_by_entry[entry];
                issue_alu_reg_A_forward |= A_forward_by_entry[entry];
                issue_alu_reg_A_is_zero |= A_is_zero_by_entry[entry];
                issue_alu_reg_A_bank |= A_PR_by_entry[entry][LOG_PRF_BANK_COUNT-1:0];
                issue_alu_reg_B_forward |= B_forward_by_entry[entry];
                issue_alu_reg_B_is_zero |= B_is_zero_by_entry[entry];
                issue_alu_reg_B_bank |= B_PR_by_entry[entry][LOG_PRF_BANK_COUNT-1:0];
                issue_alu_reg_dest_PR |= dest_PR_by_entry[entry];
                issue_alu_reg_ROB_index |= ROB_index_by_entry[entry];

                PRF_alu_reg_req_A_valid |= ~A_forward_by_entry[entry] & ~A_is_zero_by_entry[entry];
                PRF_alu_reg_req_A_PR |= A_PR_by_entry[entry];
                PRF_alu_reg_req_B_valid |= ~B_forward_by_entry[entry] & ~B_is_zero_by_entry[entry];
                PRF_alu_reg_req_B_PR |= B_PR_by_entry[entry];
            end
        end
    end

    // Mul-Div issue:

    // ready check
    assign issue_mdu_ready_by_entry = 
        {ALU_REG_MDU_IQ_ENTRIES{mdu_pipeline_ready}}
        &
        valid_mdu_by_entry
        &
        (A_ready_by_entry | A_forward_by_entry | A_is_zero_by_entry)
        &
        (B_ready_by_entry | B_forward_by_entry | B_is_zero_by_entry)
    ;

    // pe
    pe_lsb #(.WIDTH(ALU_REG_MDU_IQ_ENTRIES)) ISSUE_MUL_DIV_PE_LSB (
        .req_vec(issue_mdu_ready_by_entry),
        .ack_one_hot(issue_mdu_one_hot_by_entry),
        .ack_mask(issue_mdu_mask)
    );

    // mux
    always_comb begin

        // issue automatically valid if any entry ready
        issue_mdu_valid = |issue_mdu_ready_by_entry;

        // one-hot mux over entries for final issue:
        issue_mdu_op = '0;
        issue_mdu_A_forward = '0;
        issue_mdu_A_is_zero = '0;
        issue_mdu_A_bank = '0;
        issue_mdu_B_forward = '0;
        issue_mdu_B_is_zero = '0;
        issue_mdu_B_bank = '0;
        issue_mdu_dest_PR = '0;
        issue_mdu_ROB_index = '0;

        PRF_mdu_req_A_valid = '0;
        PRF_mdu_req_A_PR = '0;
        PRF_mdu_req_B_valid = '0;
        PRF_mdu_req_B_PR = '0;

        for (int entry = 0; entry < ALU_REG_MDU_IQ_ENTRIES; entry++) begin

            if (issue_mdu_one_hot_by_entry[entry]) begin

                issue_mdu_op |= op_by_entry[entry];
                issue_mdu_A_forward |= A_forward_by_entry[entry];
                issue_mdu_A_is_zero |= A_is_zero_by_entry[entry];
                issue_mdu_A_bank |= A_PR_by_entry[entry][LOG_PRF_BANK_COUNT-1:0];
                issue_mdu_B_forward |= B_forward_by_entry[entry];
                issue_mdu_B_is_zero |= B_is_zero_by_entry[entry];
                issue_mdu_B_bank |= B_PR_by_entry[entry][LOG_PRF_BANK_COUNT-1:0];
                issue_mdu_dest_PR |= dest_PR_by_entry[entry];
                issue_mdu_ROB_index |= ROB_index_by_entry[entry];

                PRF_mdu_req_A_valid |= ~A_forward_by_entry[entry] & ~A_is_zero_by_entry[entry];
                PRF_mdu_req_A_PR |= A_PR_by_entry[entry];
                PRF_mdu_req_B_valid |= ~B_forward_by_entry[entry] & ~B_is_zero_by_entry[entry];
                PRF_mdu_req_B_PR |= B_PR_by_entry[entry];
            end
        end
    end

    // ----------------------------------------------------------------
    // Dispatch Logic:

    // cascaded dispatch mask PE's by way:

    // way 0
    assign dispatch_open_mask_by_way[0] = ~(valid_alu_reg_by_entry | valid_mdu_by_entry);
    pe_lsb #(.WIDTH(ALU_REG_MDU_IQ_ENTRIES)) DISPATCH_WAY0_PE_LSB (
        .req_vec(dispatch_open_mask_by_way[0]),
        .ack_one_hot(dispatch_pe_one_hot_by_way[0]),
        .ack_mask() // unused
    );
    assign dispatch_one_hot_by_way[0] = dispatch_pe_one_hot_by_way[0] & {ALU_REG_MDU_IQ_ENTRIES{dispatch_attempt_by_way[0]}};

    // way 1
    assign dispatch_open_mask_by_way[1] = dispatch_open_mask_by_way[0] & ~dispatch_one_hot_by_way[0];
    pe_lsb #(.WIDTH(ALU_REG_MDU_IQ_ENTRIES)) DISPATCH_WAY1_PE_LSB (
        .req_vec(dispatch_open_mask_by_way[1]),
        .ack_one_hot(dispatch_pe_one_hot_by_way[1]),
        .ack_mask() // unused
    );
    assign dispatch_one_hot_by_way[1] = dispatch_pe_one_hot_by_way[1] & {ALU_REG_MDU_IQ_ENTRIES{dispatch_attempt_by_way[1]}};
    
    assign dispatch_open_mask_by_way[2] = dispatch_open_mask_by_way[1] & ~dispatch_one_hot_by_way[1];
    pe_lsb #(.WIDTH(ALU_REG_MDU_IQ_ENTRIES)) DISPATCH_WAY2_PE_LSB (
        .req_vec(dispatch_open_mask_by_way[2]),
        .ack_one_hot(dispatch_pe_one_hot_by_way[2]),
        .ack_mask() // unused
    );
    assign dispatch_one_hot_by_way[2] = dispatch_pe_one_hot_by_way[2] & {ALU_REG_MDU_IQ_ENTRIES{dispatch_attempt_by_way[2]}};
    
    assign dispatch_open_mask_by_way[3] = dispatch_open_mask_by_way[2] & ~dispatch_one_hot_by_way[2];
    pe_lsb #(.WIDTH(ALU_REG_MDU_IQ_ENTRIES)) DISPATCH_WAY3_PE_LSB (
        .req_vec(dispatch_open_mask_by_way[3]),
        .ack_one_hot(dispatch_pe_one_hot_by_way[3]),
        .ack_mask() // unused
    );
    assign dispatch_one_hot_by_way[3] = dispatch_pe_one_hot_by_way[3] & {ALU_REG_MDU_IQ_ENTRIES{dispatch_attempt_by_way[3]}};

    // give dispatch feedback
    always_comb begin
        for (int way = 0; way < 4; way++) begin
            dispatch_ack_by_way[way] = |(dispatch_open_mask_by_way[way] & {ALU_REG_MDU_IQ_ENTRIES{dispatch_attempt_by_way[way]}});
        end
    end

    // route PE'd dispatch to entries
    always_comb begin
    
        dispatch_valid_alu_reg_by_entry = '0;
        dispatch_valid_mdu_by_entry = '0;
        dispatch_op_by_entry = '0;
        dispatch_A_PR_by_entry = '0;
        dispatch_A_ready_by_entry = '0;
        dispatch_A_is_zero_by_entry = '0;
        dispatch_B_PR_by_entry = '0;
        dispatch_B_ready_by_entry = '0;
        dispatch_B_is_zero_by_entry = '0;
        dispatch_dest_PR_by_entry = '0;
        dispatch_ROB_index_by_entry = '0;

        // one-hot mux selecting among ways at each entry
        for (int entry = 0; entry < ALU_REG_MDU_IQ_ENTRIES; entry++) begin

            for (int way = 0; way < 4; way++) begin

                if (dispatch_one_hot_by_way[way][entry]) begin

                    dispatch_valid_alu_reg_by_entry[entry] |= dispatch_valid_alu_reg_by_way[way];
                    dispatch_valid_mdu_by_entry[entry] |= dispatch_valid_mdu_by_way[way];
                    dispatch_op_by_entry[entry] |= dispatch_op_by_way[way];
                    dispatch_A_PR_by_entry[entry] |= dispatch_A_PR_by_way[way];
                    dispatch_A_ready_by_entry[entry] |= dispatch_A_ready_by_way[way];
                    dispatch_A_is_zero_by_entry[entry] |= dispatch_A_is_zero_by_way[way];
                    dispatch_B_PR_by_entry[entry] |= dispatch_B_PR_by_way[way];
                    dispatch_B_ready_by_entry[entry] |= dispatch_B_ready_by_way[way];
                    dispatch_B_is_zero_by_entry[entry] |= dispatch_B_is_zero_by_way[way];
                    dispatch_dest_PR_by_entry[entry] |= dispatch_dest_PR_by_way[way];
                    dispatch_ROB_index_by_entry[entry] |= dispatch_ROB_index_by_way[way];
                end
            end
        end
    end

    // pe_lsb #(
    //     .WIDTH(ALU_REG_MDU_IQ_ENTRIES + 4),
    //     .USE_ONE_HOT(0),
    //     .USE_COLD(0),
    //     .USE_INDEX(1)
    // ) LOWEST_INVALID_PE (
    //     .req_vec(~{4'b0000, {valid_alu_reg_by_entry | valid_mdu_by_entry}}),
    //     .ack_index(lowest_invalid_entry)
    // );

    // always_comb begin
    //     next_lowest_invalid_entry = lowest_invalid_entry;
    //     for (int way = 0; way < 4; way++) begin
    //         next_lowest_invalid_entry = 
    //             next_lowest_invalid_entry 
    //             + 
    //             ((dispatch_valid_alu_reg_by_way[way] | dispatch_valid_mdu_by_way[way]) & dispatch_ack_by_way[way])
    //         ;
    //     end
    //     next_lowest_invalid_entry = next_lowest_invalid_entry - issue_alu_reg_valid;
    //     next_lowest_invalid_entry = next_lowest_invalid_entry - issue_mdu_valid;
    // end

    // always_ff @ (posedge CLK, negedge nRST) begin
    //     if (~nRST) begin
    //         lowest_invalid_entry <= '0;
    //     end
    //     else begin
    //         lowest_invalid_entry <= next_lowest_invalid_entry;
    //     end
    // end

    // always_comb begin

    //     dispatch_way_index_by_entry = '0;

    //     // way 0
    //     lowest_invalid_entry_by_way[0] = lowest_invalid_entry;
    //     if (dispatch_attempt_by_way[0]) begin
    //         dispatch_way_index_by_entry[lowest_invalid_entry_by_way[0]] = 2'h0;
    //         lowest_invalid_entry_by_way[1] = lowest_invalid_entry_by_way[0] + 1;
    //     end else begin
    //         lowest_invalid_entry_by_way[1] = lowest_invalid_entry_by_way[0];
    //     end

    //     // way 1
    //     if (dispatch_attempt_by_way[1]) begin
    //         dispatch_way_index_by_entry[lowest_invalid_entry_by_way[1]] = 2'h1;
    //         lowest_invalid_entry_by_way[2] = lowest_invalid_entry_by_way[1] + 1;
    //     end else begin
    //         lowest_invalid_entry_by_way[2] = lowest_invalid_entry_by_way[1];
    //     end

    //     // way 2
    //     if (dispatch_attempt_by_way[2]) begin
    //         dispatch_way_index_by_entry[lowest_invalid_entry_by_way[2]] = 2'h2;
    //         lowest_invalid_entry_by_way[3] = lowest_invalid_entry_by_way[2] + 1;
    //     end else begin
    //         lowest_invalid_entry_by_way[3] = lowest_invalid_entry_by_way[2];
    //     end

    //     // way 3
    //     if (dispatch_attempt_by_way[3]) begin
    //         dispatch_way_index_by_entry[lowest_invalid_entry_by_way[3]] = 2'h3;
    //     end

    //     for (int way = 0; way < 4; way++) begin
    //         dispatch_ack_by_way[way] = 
    //             dispatch_attempt_by_way[way] 
    //             & 
    //             (lowest_invalid_entry_by_way[way] < ALU_REG_MDU_IQ_ENTRIES)
    //         ;
    //     end
    // end

    // always_comb begin
    //     for (int entry = 0; entry < ALU_REG_MDU_IQ_ENTRIES; entry++) begin
    //         dispatch_valid_alu_reg_by_entry[entry] = dispatch_valid_alu_reg_by_way[dispatch_way_index_by_entry[entry]]
    //             & entry == lowest_invalid_entry_by_way[dispatch_way_index_by_entry[entry]];
    //         dispatch_valid_mdu_by_entry[entry] = dispatch_valid_mdu_by_way[dispatch_way_index_by_entry[entry]]
    //             & entry == lowest_invalid_entry_by_way[dispatch_way_index_by_entry[entry]];
    //         dispatch_op_by_entry[entry] = dispatch_op_by_way[dispatch_way_index_by_entry[entry]];
    //         dispatch_A_PR_by_entry[entry] = dispatch_A_PR_by_way[dispatch_way_index_by_entry[entry]];
    //         dispatch_A_ready_by_entry[entry] = dispatch_A_ready_by_way[dispatch_way_index_by_entry[entry]];
    //         dispatch_A_is_zero_by_entry[entry] = dispatch_A_is_zero_by_way[dispatch_way_index_by_entry[entry]];
    //         dispatch_B_PR_by_entry[entry] = dispatch_B_PR_by_way[dispatch_way_index_by_entry[entry]];
    //         dispatch_B_ready_by_entry[entry] = dispatch_B_ready_by_way[dispatch_way_index_by_entry[entry]];
    //         dispatch_B_is_zero_by_entry[entry] = dispatch_B_is_zero_by_way[dispatch_way_index_by_entry[entry]];
    //         dispatch_dest_PR_by_entry[entry] = dispatch_dest_PR_by_way[dispatch_way_index_by_entry[entry]];
    //         dispatch_ROB_index_by_entry[entry] = dispatch_ROB_index_by_way[dispatch_way_index_by_entry[entry]];
    //     end
    // end

    always_ff @ (posedge CLK, negedge nRST) begin
        if (~nRST) begin
            valid_alu_reg_by_entry <= '0;
            valid_mdu_by_entry <= '0;
            op_by_entry <= '0;
            A_PR_by_entry <= '0;
            A_ready_by_entry <= '0;
            A_is_zero_by_entry <= '0;
            B_PR_by_entry <= '0;
            B_ready_by_entry <= '0;
            B_is_zero_by_entry <= '0;
            dest_PR_by_entry <= '0;
            ROB_index_by_entry <= '0;
        end
        else begin

            // --------------------------------------------------------
            // highest entry only takes self:
                // self: [ALU_REG_MDU_IQ_ENTRIES-1]

            // check take above or 2 above -> clear entry
            if (issue_alu_reg_mask[ALU_REG_MDU_IQ_ENTRIES-1] | issue_mdu_mask[ALU_REG_MDU_IQ_ENTRIES-1]) begin
                valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= 1'b0;
                valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= 1'b0;
            end

            // otherwise take self
            else begin

                // take self valid entry
                if (valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] | valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-1]) begin
                    valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    op_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= op_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] | A_forward_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] | B_forward_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                end

                // take self dispatch
                else begin
                    valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    op_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_op_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] <= dispatch_ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                end
            end

            // --------------------------------------------------------
            // second-highest entry takes self or above:
                // above: [ALU_REG_MDU_IQ_ENTRIES-1]
                // self: [ALU_REG_MDU_IQ_ENTRIES-2]

            // check take 2 above -> clear entry
            if (
                issue_alu_reg_mask[ALU_REG_MDU_IQ_ENTRIES-2] & issue_mdu_mask[ALU_REG_MDU_IQ_ENTRIES-1]
                |
                issue_alu_reg_mask[ALU_REG_MDU_IQ_ENTRIES-1] & issue_mdu_mask[ALU_REG_MDU_IQ_ENTRIES-2]
            ) begin
                valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= 1'b0;
                valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= 1'b0;
            end

            // check take above
            else if (issue_alu_reg_mask[ALU_REG_MDU_IQ_ENTRIES-2] | issue_mdu_mask[ALU_REG_MDU_IQ_ENTRIES-2]) begin

                // take valid entry above
                if (valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] | valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-1]) begin
                    valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    op_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= op_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] | A_forward_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1] | B_forward_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                end

                // take dispatch above
                else begin
                    valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    op_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_op_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                    ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-1];
                end
            end

            // otherwise take self
            else begin

                // take self valid entry
                if (valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] | valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-2]) begin
                    valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    op_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= op_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] | A_forward_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] | B_forward_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                end

                // take self dispatch
                else begin
                    valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_valid_alu_reg_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_valid_mdu_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    op_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_op_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_A_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_A_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_A_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_B_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_B_ready_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_B_is_zero_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_dest_PR_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                    ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-2] <= dispatch_ROB_index_by_entry[ALU_REG_MDU_IQ_ENTRIES-2];
                end
            end

            // --------------------------------------------------------
            // remaining lower entries can take self, above, or 2 above
                // [ALU_REG_MDU_IQ_ENTRIES-1] can only take self
                // [ALU_REG_MDU_IQ_ENTRIES-2] can take self or above
            for (int i = 0; i <= ALU_REG_MDU_IQ_ENTRIES-3; i++) begin

                // check take 2 above
                if (
                    issue_alu_reg_mask[i] & issue_mdu_mask[i+1]
                    |
                    issue_alu_reg_mask[i+1] & issue_mdu_mask[i]
                ) begin

                    // take valid entry 2 above
                    if (valid_alu_reg_by_entry[i+2] | valid_mdu_by_entry[i+2]) begin
                        valid_alu_reg_by_entry[i] <= valid_alu_reg_by_entry[i+2];
                        valid_mdu_by_entry[i] <= valid_mdu_by_entry[i+2];
                        op_by_entry[i] <= op_by_entry[i+2];
                        A_PR_by_entry[i] <= A_PR_by_entry[i+2];
                        A_ready_by_entry[i] <= A_ready_by_entry[i+2] | A_forward_by_entry[i+2];
                        A_is_zero_by_entry[i] <= A_is_zero_by_entry[i+2];
                        B_PR_by_entry[i] <= B_PR_by_entry[i+2];
                        B_ready_by_entry[i] <= B_ready_by_entry[i+2] | B_forward_by_entry[i+2];
                        B_is_zero_by_entry[i] <= B_is_zero_by_entry[i+2];
                        dest_PR_by_entry[i] <= dest_PR_by_entry[i+2];
                        ROB_index_by_entry[i] <= ROB_index_by_entry[i+2];
                    end

                    // take dispatch 2 above
                    else begin
                        valid_alu_reg_by_entry[i] <= dispatch_valid_alu_reg_by_entry[i+2];
                        valid_mdu_by_entry[i] <= dispatch_valid_mdu_by_entry[i+2];
                        op_by_entry[i] <= dispatch_op_by_entry[i+2];
                        A_PR_by_entry[i] <= dispatch_A_PR_by_entry[i+2];
                        A_ready_by_entry[i] <= dispatch_A_ready_by_entry[i+2];
                        A_is_zero_by_entry[i] <= dispatch_A_is_zero_by_entry[i+2];
                        B_PR_by_entry[i] <= dispatch_B_PR_by_entry[i+2];
                        B_ready_by_entry[i] <= dispatch_B_ready_by_entry[i+2];
                        B_is_zero_by_entry[i] <= dispatch_B_is_zero_by_entry[i+2];
                        dest_PR_by_entry[i] <= dispatch_dest_PR_by_entry[i+2];
                        ROB_index_by_entry[i] <= dispatch_ROB_index_by_entry[i+2];
                    end
                end

                // check take above
                else if (issue_alu_reg_mask[i] | issue_mdu_mask[i]) begin

                    // take valid entry above
                    if (valid_alu_reg_by_entry[i+1] | valid_mdu_by_entry[i+1]) begin
                        valid_alu_reg_by_entry[i] <= valid_alu_reg_by_entry[i+1];
                        valid_mdu_by_entry[i] <= valid_mdu_by_entry[i+1];
                        op_by_entry[i] <= op_by_entry[i+1];
                        A_PR_by_entry[i] <= A_PR_by_entry[i+1];
                        A_ready_by_entry[i] <= A_ready_by_entry[i+1] | A_forward_by_entry[i+1];
                        A_is_zero_by_entry[i] <= A_is_zero_by_entry[i+1];
                        B_PR_by_entry[i] <= B_PR_by_entry[i+1];
                        B_ready_by_entry[i] <= B_ready_by_entry[i+1] | B_forward_by_entry[i+1];
                        B_is_zero_by_entry[i] <= B_is_zero_by_entry[i+1];
                        dest_PR_by_entry[i] <= dest_PR_by_entry[i+1];
                        ROB_index_by_entry[i] <= ROB_index_by_entry[i+1];
                    end

                    // take dispatch above
                    else begin
                        valid_alu_reg_by_entry[i] <= dispatch_valid_alu_reg_by_entry[i+1];
                        valid_mdu_by_entry[i] <= dispatch_valid_mdu_by_entry[i+1];
                        op_by_entry[i] <= dispatch_op_by_entry[i+1];
                        A_PR_by_entry[i] <= dispatch_A_PR_by_entry[i+1];
                        A_ready_by_entry[i] <= dispatch_A_ready_by_entry[i+1];
                        A_is_zero_by_entry[i] <= dispatch_A_is_zero_by_entry[i+1];
                        B_PR_by_entry[i] <= dispatch_B_PR_by_entry[i+1];
                        B_ready_by_entry[i] <= dispatch_B_ready_by_entry[i+1];
                        B_is_zero_by_entry[i] <= dispatch_B_is_zero_by_entry[i+1];
                        dest_PR_by_entry[i] <= dispatch_dest_PR_by_entry[i+1];
                        ROB_index_by_entry[i] <= dispatch_ROB_index_by_entry[i+1];
                    end
                end

                // otherwise take self
                else begin

                    // take self valid entry
                    if (valid_alu_reg_by_entry[i] | valid_mdu_by_entry[i]) begin
                        valid_alu_reg_by_entry[i] <= valid_alu_reg_by_entry[i];
                        valid_mdu_by_entry[i] <= valid_mdu_by_entry[i];
                        op_by_entry[i] <= op_by_entry[i];
                        A_PR_by_entry[i] <= A_PR_by_entry[i];
                        A_ready_by_entry[i] <= A_ready_by_entry[i] | A_forward_by_entry[i];
                        A_is_zero_by_entry[i] <= A_is_zero_by_entry[i];
                        B_PR_by_entry[i] <= B_PR_by_entry[i];
                        B_ready_by_entry[i] <= B_ready_by_entry[i] | B_forward_by_entry[i];
                        B_is_zero_by_entry[i] <= B_is_zero_by_entry[i];
                        dest_PR_by_entry[i] <= dest_PR_by_entry[i];
                        ROB_index_by_entry[i] <= ROB_index_by_entry[i];
                    end

                    // take self dispatch
                    else begin
                        valid_alu_reg_by_entry[i] <= dispatch_valid_alu_reg_by_entry[i];
                        valid_mdu_by_entry[i] <= dispatch_valid_mdu_by_entry[i];
                        op_by_entry[i] <= dispatch_op_by_entry[i];
                        A_PR_by_entry[i] <= dispatch_A_PR_by_entry[i];
                        A_ready_by_entry[i] <= dispatch_A_ready_by_entry[i];
                        A_is_zero_by_entry[i] <= dispatch_A_is_zero_by_entry[i];
                        B_PR_by_entry[i] <= dispatch_B_PR_by_entry[i];
                        B_ready_by_entry[i] <= dispatch_B_ready_by_entry[i];
                        B_is_zero_by_entry[i] <= dispatch_B_is_zero_by_entry[i];
                        dest_PR_by_entry[i] <= dispatch_dest_PR_by_entry[i];
                        ROB_index_by_entry[i] <= dispatch_ROB_index_by_entry[i];
                    end
                end
            end
        end
    end

endmodule