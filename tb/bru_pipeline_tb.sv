/*
    Filename: bru_pipeline_tb.sv
    Author: zlagpacan
    Description: Testbench for bru_pipeline module. 
    Spec: LOROF/spec/design/bru_pipeline.md
*/

`timescale 1ns/100ps

`include "core_types_pkg.vh"
import core_types_pkg::*;

module bru_pipeline_tb ();

    // ----------------------------------------------------------------
    // TB setup:

    // parameters
    parameter PERIOD = 10;

    // TB signals:
    logic CLK = 1'b1, nRST;
    string test_case;
    string sub_test_case;
    int test_num = 0;
    int num_errors = 0;
    logic tb_error = 1'b0;

    // clock gen
    always begin #(PERIOD/2); CLK = ~CLK; end

    // ----------------------------------------------------------------
    // DUT signals:


    // BRU op issue to BRU IQ
	logic tb_issue_valid;
	logic [3:0] tb_issue_op;
	logic [31:0] tb_issue_PC;
	logic [31:0] tb_issue_speculated_next_PC;
	logic [31:0] tb_issue_imm;
	logic tb_issue_A_unneeded;
	logic tb_issue_A_forward;
	logic [LOG_PRF_BANK_COUNT-1:0] tb_issue_A_bank;
	logic tb_issue_B_unneeded;
	logic tb_issue_B_forward;
	logic [LOG_PRF_BANK_COUNT-1:0] tb_issue_B_bank;
	logic [LOG_PR_COUNT-1:0] tb_issue_dest_PR;
	logic [LOG_ROB_ENTRIES-1:0] tb_issue_ROB_index;

    // output feedback to BRU IQ
	logic DUT_issue_ready, expected_issue_ready;

    // reg read info and data from PRF
	logic tb_A_reg_read_ack;
	logic tb_A_reg_read_port;
	logic tb_B_reg_read_ack;
	logic tb_B_reg_read_port;
	logic [PRF_BANK_COUNT-1:0][1:0][31:0] tb_reg_read_data_by_bank_by_port;

    // forward data from PRF
	logic [PRF_BANK_COUNT-1:0][31:0] tb_forward_data_by_bank;

    // writeback data to PRF
	logic DUT_WB_valid, expected_WB_valid;
	logic [31:0] DUT_WB_data, expected_WB_data;
	logic [LOG_PR_COUNT-1:0] DUT_WB_PR, expected_WB_PR;
	logic [LOG_ROB_ENTRIES-1:0] DUT_WB_ROB_index, expected_WB_ROB_index;

    // writeback backpressure from PRF
	logic tb_WB_ready;

    // restart req to ROB
        // no backpressure, ROB's job to deal with multiple identical req's
	logic DUT_restart_req_valid, expected_restart_req_valid;
	logic DUT_restart_req_mispredict, expected_restart_req_mispredict;
	logic [LOG_ROB_ENTRIES-1:0] DUT_restart_req_ROB_index, expected_restart_req_ROB_index;
	logic [31:0] DUT_restart_req_PC, expected_restart_req_PC;
	logic DUT_restart_req_taken, expected_restart_req_taken;

    // restart req backpressure from ROB
	logic tb_restart_req_ready;

    // ----------------------------------------------------------------
    // DUT instantiation:

	bru_pipeline DUT (
		// seq
		.CLK(CLK),
		.nRST(nRST),


	    // BRU op issue to BRU IQ
		.issue_valid(tb_issue_valid),
		.issue_op(tb_issue_op),
		.issue_PC(tb_issue_PC),
		.issue_speculated_next_PC(tb_issue_speculated_next_PC),
		.issue_imm(tb_issue_imm),
		.issue_A_unneeded(tb_issue_A_unneeded),
		.issue_A_forward(tb_issue_A_forward),
		.issue_A_bank(tb_issue_A_bank),
		.issue_B_unneeded(tb_issue_B_unneeded),
		.issue_B_forward(tb_issue_B_forward),
		.issue_B_bank(tb_issue_B_bank),
		.issue_dest_PR(tb_issue_dest_PR),
		.issue_ROB_index(tb_issue_ROB_index),

	    // output feedback to BRU IQ
		.issue_ready(DUT_issue_ready),

	    // reg read info and data from PRF
		.A_reg_read_ack(tb_A_reg_read_ack),
		.A_reg_read_port(tb_A_reg_read_port),
		.B_reg_read_ack(tb_B_reg_read_ack),
		.B_reg_read_port(tb_B_reg_read_port),
		.reg_read_data_by_bank_by_port(tb_reg_read_data_by_bank_by_port),

	    // forward data from PRF
		.forward_data_by_bank(tb_forward_data_by_bank),

	    // writeback data to PRF
		.WB_valid(DUT_WB_valid),
		.WB_data(DUT_WB_data),
		.WB_PR(DUT_WB_PR),
		.WB_ROB_index(DUT_WB_ROB_index),

	    // writeback backpressure from PRF
		.WB_ready(tb_WB_ready),

	    // restart req to ROB
	        // no backpressure, ROB's job to deal with multiple identical req's
		.restart_req_valid(DUT_restart_req_valid),
		.restart_req_mispredict(DUT_restart_req_mispredict),
		.restart_req_ROB_index(DUT_restart_req_ROB_index),
		.restart_req_PC(DUT_restart_req_PC),
		.restart_req_taken(DUT_restart_req_taken),

	    // restart backpressure from ROB
		.restart_req_ready(tb_restart_req_ready)
	);

    // ----------------------------------------------------------------
    // tasks:

    task check_outputs();
    begin
		if (expected_issue_ready !== DUT_issue_ready) begin
			$display("TB ERROR: expected_issue_ready (%h) != DUT_issue_ready (%h)",
				expected_issue_ready, DUT_issue_ready);
			num_errors++;
			tb_error = 1'b1;
		end

		if (expected_WB_valid !== DUT_WB_valid) begin
			$display("TB ERROR: expected_WB_valid (%h) != DUT_WB_valid (%h)",
				expected_WB_valid, DUT_WB_valid);
			num_errors++;
			tb_error = 1'b1;
		end

		if (expected_WB_data !== DUT_WB_data) begin
			$display("TB ERROR: expected_WB_data (%h) != DUT_WB_data (%h)",
				expected_WB_data, DUT_WB_data);
			num_errors++;
			tb_error = 1'b1;
		end

		if (expected_WB_PR !== DUT_WB_PR) begin
			$display("TB ERROR: expected_WB_PR (%h) != DUT_WB_PR (%h)",
				expected_WB_PR, DUT_WB_PR);
			num_errors++;
			tb_error = 1'b1;
		end

		if (expected_WB_ROB_index !== DUT_WB_ROB_index) begin
			$display("TB ERROR: expected_WB_ROB_index (%h) != DUT_WB_ROB_index (%h)",
				expected_WB_ROB_index, DUT_WB_ROB_index);
			num_errors++;
			tb_error = 1'b1;
		end

		if (expected_restart_req_valid !== DUT_restart_req_valid) begin
			$display("TB ERROR: expected_restart_req_valid (%h) != DUT_restart_req_valid (%h)",
				expected_restart_req_valid, DUT_restart_req_valid);
			num_errors++;
			tb_error = 1'b1;
		end

		if (expected_restart_req_mispredict !== DUT_restart_req_mispredict) begin
			$display("TB ERROR: expected_restart_req_mispredict (%h) != DUT_restart_req_mispredict (%h)",
				expected_restart_req_mispredict, DUT_restart_req_mispredict);
			num_errors++;
			tb_error = 1'b1;
		end

		if (expected_restart_req_ROB_index !== DUT_restart_req_ROB_index) begin
			$display("TB ERROR: expected_restart_req_ROB_index (%h) != DUT_restart_req_ROB_index (%h)",
				expected_restart_req_ROB_index, DUT_restart_req_ROB_index);
			num_errors++;
			tb_error = 1'b1;
		end

		if (expected_restart_req_PC !== DUT_restart_req_PC) begin
			$display("TB ERROR: expected_restart_req_PC (%h) != DUT_restart_req_PC (%h)",
				expected_restart_req_PC, DUT_restart_req_PC);
			num_errors++;
			tb_error = 1'b1;
		end

		if (expected_restart_req_taken !== DUT_restart_req_taken) begin
			$display("TB ERROR: expected_restart_req_taken (%h) != DUT_restart_req_taken (%h)",
				expected_restart_req_taken, DUT_restart_req_taken);
			num_errors++;
			tb_error = 1'b1;
		end

        #(PERIOD / 10);
        tb_error = 1'b0;
    end
    endtask

    // ----------------------------------------------------------------
    // initial block:

    initial begin

        // ------------------------------------------------------------
        // reset:
        test_case = "reset";
        $display("\ntest %0d: %s", test_num, test_case);
        test_num++;

        // inputs:
        sub_test_case = "assert reset";
        $display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b0;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b0;
		tb_issue_op = 4'b0000;
		tb_issue_PC = 32'h0;
		tb_issue_speculated_next_PC = 32'h0; 
		tb_issue_imm = 32'h0;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h0;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(posedge CLK); #(PERIOD/10);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h4;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h0;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h0;
		expected_restart_req_PC = 32'h0;
		expected_restart_req_taken = 1'b1;

		check_outputs();

        // inputs:
        sub_test_case = "deassert reset";
        $display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b0;
		tb_issue_op = 4'b0000;
		tb_issue_PC = 32'h0;
		tb_issue_speculated_next_PC = 32'h0; 
		tb_issue_imm = 32'h0;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h0;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(posedge CLK); #(PERIOD/10);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h4;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h0;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h0;
		expected_restart_req_PC = 32'h0;
		expected_restart_req_taken = 1'b1;

		check_outputs();

        // ------------------------------------------------------------
        // simple chain:
        test_case = "simple chain";
        $display("\ntest %0d: %s", test_num, test_case);
        test_num++;

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: v 0: JALR p2, 0x1C(p1=AA0:r); 0x0->0xABC, mispred 0xAB8", "\n\t\t",
            "OC: i NOP", "\n\t\t",
            "EX: i NOP", "\n\t\t",
            "WB: i NOP", "\n\t\t",
			"activity: ", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b1;
		tb_issue_op = 4'b0000;
		tb_issue_PC = 32'h0;
		tb_issue_speculated_next_PC = 32'hAB8;
		tb_issue_imm = 32'h1C;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h1;
		tb_issue_B_unneeded = 1'b1;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h2;
		tb_issue_ROB_index = 7'h0;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h4;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h0;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h0;
		expected_restart_req_PC = 32'h0;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: i 1: JAL p3, 0x1234; 0xABC->0x1CF0", "\n\t\t",
            "OC: v 0: JALR p2, 0x1C(p1=AA0:r); 0x0->0xABC, mispred 0xAB8", "\n\t\t",
            "EX: i NOP", "\n\t\t",
            "WB: i NOP", "\n\t\t",
			"activity: ", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b0;
		tb_issue_op = 4'b0001;
		tb_issue_PC = 32'hABC;
		tb_issue_speculated_next_PC = 32'h1CF0;
		tb_issue_imm = 32'h1234;
		tb_issue_A_unneeded = 1'b1;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b1;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h3;
		tb_issue_ROB_index = 7'h1;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b0;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h4;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h0;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h0;
		expected_restart_req_PC = 32'h0;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: v 1: JAL p3, 0x1234; 0xABC->0x1CF0", "\n\t\t",
            "OC: v 0: JALR p2, 0x1C(p1=AA0:R); 0x0->0xABC, mispred 0xAB8", "\n\t\t",
            "EX: i NOP", "\n\t\t",
            "WB: i NOP", "\n\t\t",
			"activity: p1 read ack", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b1;
		tb_issue_op = 4'b0001;
		tb_issue_PC = 32'hABC;
		tb_issue_speculated_next_PC = 32'h1CF0;
		tb_issue_imm = 32'h1234;
		tb_issue_A_unneeded = 1'b1;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b1;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h3;
		tb_issue_ROB_index = 7'h1;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b1;
		tb_A_reg_read_port = 1'b1;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'hAA0,
            32'hdeadbeef,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h4;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h0;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h0;
		expected_restart_req_PC = 32'h0;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: v 2: BEQ p4=4:f, p5=5:f, 0x210; 0x1CF0->0x1CF4", "\n\t\t",
            "OC: v 1: JAL p3, 0x1234; 0xABC->0x1CF0", "\n\t\t",
            "EX: v 0: JALR p2, 0x1C(p1=AA0:R); 0x0->0xABC, mispred 0xAB8", "\n\t\t",
            "WB: i NOP", "\n\t\t",
			"activity: WB stall (no effect), restart req stall (no effect)", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b1;
		tb_issue_op = 4'b1000;
		tb_issue_PC = 32'h1CF0;
		tb_issue_speculated_next_PC = 32'h1CF4;
		tb_issue_imm = 32'h210;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b1;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b1;
		tb_issue_B_bank = 2'h1;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h2;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b0;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b0;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h4;
		expected_WB_PR = 7'h2;
		expected_WB_ROB_index = 7'h0;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b1;
		expected_restart_req_ROB_index = 7'h0;
		expected_restart_req_PC = 32'h1C;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: i 3: AUIPC p6, 0x5678; 0x1CF4->0x1CF8", "\n\t\t",
            "OC: v 2: BEQ p4=4:F, p5=5:F, 0x210; 0x1CF0->0x1CF4", "\n\t\t",
            "EX: v 1: JAL p3, 0x1234; 0xABC->0x1CF0", "\n\t\t",
            "WB: v 0: JALR p2, 0x1C(p1=AA0:R); 0x0->0xABC, mispred 0xAB8", "\n\t\t",
			"activity: WB stall, forward p4, p5", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b0;
		tb_issue_op = 4'b0100;
		tb_issue_PC = 32'h1CF4;
		tb_issue_speculated_next_PC = 32'h1CF8;
		tb_issue_imm = 32'h5678;
		tb_issue_A_unneeded = 1'b1;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b1;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h6;
		tb_issue_ROB_index = 7'h3;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h7,
            32'h6,
            32'h5,
            32'h4
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b0;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b0;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b1;
		expected_WB_data = 32'h4;
		expected_WB_PR = 7'h2;
		expected_WB_ROB_index = 7'h0;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b1;
		expected_restart_req_mispredict = 1'b1;
		expected_restart_req_ROB_index = 7'h0;
		expected_restart_req_PC = 32'hABC;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: v 3: AUIPC p6, 0x5678; 0x1CF4->0x1CF8", "\n\t\t",
            "OC: v 2: BEQ p4=4:F, p5=5:F, 0x210; 0x1CF0->0x1CF4", "\n\t\t",
            "EX: v 1: JAL p3, 0x1234; 0xABC->0x1CF0", "\n\t\t",
            "WB: v 0: JALR p2, 0x1C(p1=AA0:R); 0x0->0xABC, mispred 0xAB8", "\n\t\t",
			"activity: restart req stall (no effect)", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b1;
		tb_issue_op = 4'b0100;
		tb_issue_PC = 32'h1CF4;
		tb_issue_speculated_next_PC = 32'h1CF8;
		tb_issue_imm = 32'h5678;
		tb_issue_A_unneeded = 1'b1;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b1;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h6;
		tb_issue_ROB_index = 7'h3;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b0;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b1;
		expected_WB_data = 32'h4;
		expected_WB_PR = 7'h2;
		expected_WB_ROB_index = 7'h0;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b1;
		expected_restart_req_ROB_index = 7'h0;
		expected_restart_req_PC = 32'hABC;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: v 4: BNE p7=7:r, p8=8:f, 0xFFFFFF48; 0x1CF8->0x1C40, mispredict 0x1CFC", "\n\t\t",
            "OC: v 3: AUIPC p6, 0x5678; 0x1CF4->0x1CF8", "\n\t\t",
            "EX: v 2: BEQ p4=4:F, p5=5:F, 0x210; 0x1CF0->0x1CF4", "\n\t\t",
            "WB: v 1: JAL p3, 0x1234; 0xABC->0x1CF0", "\n\t\t",
			"activity: ", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b1;
		tb_issue_op = 4'b1001;
		tb_issue_PC = 32'h1CF8;
		tb_issue_speculated_next_PC = 32'h1CFC;
		tb_issue_imm = 32'hFFFFFF48;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h3;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b1;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h4;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b1;
		expected_WB_data = 32'hAC0;
		expected_WB_PR = 7'h3;
		expected_WB_ROB_index = 7'h1;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b1;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h1;
		expected_restart_req_PC = 32'h1CF0;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: v 5: BLT p9=99999999:f, pA=A:r, 0x234; 0x1C40->0x1E74", "\n\t\t",
            "OC: v 4: BNE p7=7:R, p8=8:F, 0xFFFFFF48; 0x1CF8->0x1C40, mispredict 0x1CFC", "\n\t\t",
            "EX: v 3: AUIPC p6, 0x5678; 0x1CF4->0x1CF8", "\n\t\t",
            "WB: v 2: BEQ p4=4:F, p5=5:F, 0x210; 0x1CF0->0x1CF4", "\n\t\t",
			"activity: ack p7, forward p8, WB stall (no effect)", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b1;
		tb_issue_op = 4'b1100;
		tb_issue_PC = 32'h1C40;
		tb_issue_speculated_next_PC = 32'h1E74;
		tb_issue_imm = 32'h234;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b1;
		tb_issue_A_bank = 2'h1;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h2;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h5;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b1;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h8,
            32'h7,
            32'h8,
            32'h8,
            32'h8,
            32'h8,
            32'h8,
            32'h8
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h8
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b0;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h1CF4;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h2;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b1;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h2;
		expected_restart_req_PC = 32'h1CF4;
		expected_restart_req_taken = 1'b0;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: i 6: BGE pB=B:r, pC=C:r, 0xFFFFFFFC; 0x1E74->0x1E78, mispredict 0x1E70", "\n\t\t",
            "OC: v 5: BLT p9=99999999:F, pA=A:r, 0x234; 0x1C40->0x1E74", "\n\t\t",
            "EX: v 4: BNE p7=7:R, p8=8:F, 0xFFFFFF48; 0x1CF8->0x1C40, mispredict 0x1CFC", "\n\t\t",
            "WB: v 3: AUIPC p6, 0x5678; 0x1CF4->0x1CF8", "\n\t\t",
			"activity: forward p9, restart req stall (no effect)", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b0;
		tb_issue_op = 4'b1101;
		tb_issue_PC = 32'h1E74;
		tb_issue_speculated_next_PC = 32'h1E70;
		tb_issue_imm = 32'hFFFFFFFC;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h3;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h1;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h6;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'hB,
            32'hB,
            32'h99999999,
            32'hB
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b0;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b0;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b1;
		expected_WB_data = 32'h736C;
		expected_WB_PR = 7'h6;
		expected_WB_ROB_index = 7'h3;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b1;
		expected_restart_req_ROB_index = 7'h3;
		expected_restart_req_PC = 32'h736C;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: v 6: BGE pB=B:r, pC=C:r, 0xFFFFFFFC; 0x1E74->0x1E78, mispredict 0x1E70", "\n\t\t",
            "OC: v 5: BLT p9=99999999:F, pA=A:R, 0x234; 0x1C40->0x1E74", "\n\t\t",
            "EX: i NOP", "\n\t\t",
            "WB: v 4: BNE p7=7:R, p8=8:F, 0xFFFFFF48; 0x1CF8->0x1C40, mispredict 0x1CFC", "\n\t\t",
			"activity: ack pA", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b1;
		tb_issue_op = 4'b1101;
		tb_issue_PC = 32'h1E74;
		tb_issue_speculated_next_PC = 32'h1E70;
		tb_issue_imm = 32'hFFFFFFFC;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h3;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h6;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b1;
		tb_B_reg_read_port = 1'b1;
		tb_reg_read_data_by_bank_by_port = {
            32'h8,
            32'h8,
            32'hA,
            32'h8,
            32'h8,
            32'h8,
            32'h8,
            32'h8
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'hB,
            32'hB,
            32'hB,
            32'hB
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h1CFC;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h4;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b1;
		expected_restart_req_mispredict = 1'b1;
		expected_restart_req_ROB_index = 7'h4;
		expected_restart_req_PC = 32'h1C40;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: v 7: BLTU pD=D:r, pE=8000000E:f, 0x8; 0x1E78->0x1E80", "\n\t\t",
            "OC: v 6: BGE pB=B:R, pC=C:R, 0xFFFFFFFC; 0x1E74->0x1E78, mispredict 0x1E70", "\n\t\t",
            "EX: v 5: BLT p9=99999999:F, pA=A:R, 0x234; 0x1C40->0x1E74", "\n\t\t",
            "WB: i NOP", "\n\t\t",
			"activity: ack pB, pC", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b1;
		tb_issue_op = 4'b1110;
		tb_issue_PC = 32'h1E78;
		tb_issue_speculated_next_PC = 32'h1E80;
		tb_issue_imm = 32'h8;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h1;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b1;
		tb_issue_B_bank = 2'h2;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h7;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b1;
		tb_A_reg_read_port = 1'b1;
		tb_B_reg_read_ack = 1'b1;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'hB,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'hC
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h1C44;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h5;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h5;
		expected_restart_req_PC = 32'h1E74;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: v: 8: BGEU pF:f, p0:r, 0x128CC; 0x1E80->0x1474C, mispredict 0x0474C", "\n\t\t",
            "OC: v 7: BLTU pD=D:R, pE=8000000E:F, 0x8; 0x1E78->0x1E80", "\n\t\t",
            "EX: v 6: BGE pB=B:R, pC=C:R, 0xFFFFFFFC; 0x1E74->0x1E78, mispredict 0x1E70", "\n\t\t",
            "WB: v 5: BLT p9=99999999:F, pA=A:R, 0x234; 0x1C40->0x1E74", "\n\t\t",
			"activity: ack pD, forward pE", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b1;
		tb_issue_op = 4'b1111;
		tb_issue_PC = 32'h1E80;
		tb_issue_speculated_next_PC = 32'h0474C;
		tb_issue_imm = 32'h128CC;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b1;
		tb_issue_A_bank = 2'h3;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h8;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b1;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'hFFFFFFFF,
            32'hFFFFFFFF,
            32'hFFFFFFFF,
            32'hFFFFFFFF,
            32'hFFFFFFFF,
            32'hD,
            32'hFFFFFFFF,
            32'hFFFFFFFF
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'hC,
            32'h8000000E,
            32'hC,
            32'hC
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h1C44;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h5;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b1;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h5;
		expected_restart_req_PC = 32'h1E74;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: i NOP", "\n\t\t",
            "OC: v: 8: BGEU pF=FFFFFFFF:F, p0=0:r, 0x128CC; 0x1E80->0x1474C, mispredict 0x0474C", "\n\t\t",
            "EX: v 7: BLTU pD=D:R, pE=8000000E:F, 0x8; 0x1E78->0x1E80", "\n\t\t",
            "WB: v 6: BGE pB=B:R, pC=C:R, 0xFFFFFFFC; 0x1E74->0x1E78, mispredict 0x1E70", "\n\t\t",
			"activity: forward pF", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b0;
		tb_issue_op = 4'b0000;
		tb_issue_PC = 32'h0;
		tb_issue_speculated_next_PC = 32'h0; 
		tb_issue_imm = 32'h0;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h0;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'hFFFFFFFF,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b0;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h1E78;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h6;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b1;
		expected_restart_req_mispredict = 1'b1;
		expected_restart_req_ROB_index = 7'h6;
		expected_restart_req_PC = 32'h1E78;
		expected_restart_req_taken = 1'b0;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: i NOP", "\n\t\t",
            "OC: v: 8: BGEU pF=FFFFFFFF:F, p0=0:R, 0x128CC; 0x1E80->0x1474C, mispredict 0x0474C", "\n\t\t",
            "EX: i NOP", "\n\t\t",
            "WB: v 7: BLTU pD=D:R, pE=8000000E:F, 0x8; 0x1E78->0x1E80", "\n\t\t",
			"activity: WB stall (no effect), ack p0", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b0;
		tb_issue_op = 4'b0000;
		tb_issue_PC = 32'h0;
		tb_issue_speculated_next_PC = 32'h0; 
		tb_issue_imm = 32'h0;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h0;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b1;
		tb_B_reg_read_port = 1'b1;
		tb_reg_read_data_by_bank_by_port = {
            32'hFFFFFFFF,
            32'hFFFFFFFF,
            32'hFFFFFFFF,
            32'hFFFFFFFF,
            32'hFFFFFFFF,
            32'hFFFFFFFF,
            32'h0,
            32'hFFFFFFFF
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b0;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h1E7C;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h7;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b1;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h7;
		expected_restart_req_PC = 32'h1E80;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: i NOP", "\n\t\t",
            "OC: i NOP", "\n\t\t",
            "EX: v: 8: BGEU pF=FFFFFFFF:F, p0=0:R, 0x128CC; 0x1E80->0x1474C, mispredict 0x0474C", "\n\t\t",
            "WB: i NOP", "\n\t\t",
			"activity: ", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b0;
		tb_issue_op = 4'b0000;
		tb_issue_PC = 32'h0;
		tb_issue_speculated_next_PC = 32'h0; 
		tb_issue_imm = 32'h0;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h0;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h1E84;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h8;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b1;
		expected_restart_req_ROB_index = 7'h8;
		expected_restart_req_PC = 32'h1474C;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: i NOP", "\n\t\t",
            "OC: i NOP", "\n\t\t",
            "EX: i NOP", "\n\t\t",
            "WB: v: 8: BGEU pF=FFFFFFFF:F, p0=0:R, 0x128CC; 0x1E80->0x1474C, mispredict 0x0474C", "\n\t\t",
			"activity: ", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b0;
		tb_issue_op = 4'b0000;
		tb_issue_PC = 32'h0;
		tb_issue_speculated_next_PC = 32'h0; 
		tb_issue_imm = 32'h0;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h0;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h1E84;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h8;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b1;
		expected_restart_req_mispredict = 1'b1;
		expected_restart_req_ROB_index = 7'h8;
		expected_restart_req_PC = 32'h1474C;
		expected_restart_req_taken = 1'b1;

		check_outputs();

		@(posedge CLK); #(PERIOD/10);

		// inputs
		sub_test_case = {"\n\t\t",
            "issue: i NOP", "\n\t\t",
            "OC: i NOP", "\n\t\t",
            "EX: i NOP", "\n\t\t",
            "WB: i NOP", "\n\t\t",
			"activity: ", "\n\t\t"
        };
		$display("\t- sub_test: %s", sub_test_case);

		// reset
		nRST = 1'b1;
	    // BRU op issue to BRU IQ
		tb_issue_valid = 1'b0;
		tb_issue_op = 4'b0000;
		tb_issue_PC = 32'h0;
		tb_issue_speculated_next_PC = 32'h0; 
		tb_issue_imm = 32'h0;
		tb_issue_A_unneeded = 1'b0;
		tb_issue_A_forward = 1'b0;
		tb_issue_A_bank = 2'h0;
		tb_issue_B_unneeded = 1'b0;
		tb_issue_B_forward = 1'b0;
		tb_issue_B_bank = 2'h0;
		tb_issue_dest_PR = 7'h0;
		tb_issue_ROB_index = 7'h0;
	    // output feedback to BRU IQ
	    // reg read info and data from PRF
		tb_A_reg_read_ack = 1'b0;
		tb_A_reg_read_port = 1'b0;
		tb_B_reg_read_ack = 1'b0;
		tb_B_reg_read_port = 1'b0;
		tb_reg_read_data_by_bank_by_port = {
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // forward data from PRF
		tb_forward_data_by_bank = {
            32'h0,
            32'h0,
            32'h0,
            32'h0
        };
	    // writeback data to PRF
	    // writeback backpressure from PRF
		tb_WB_ready = 1'b1;
	    // restart req to ROB
		// restart req backpressure from ROB
		tb_restart_req_ready = 1'b1;

		@(negedge CLK);

		// outputs:

	    // BRU op issue to BRU IQ
	    // output feedback to BRU IQ
		expected_issue_ready = 1'b1;
	    // reg read info and data from PRF
	    // forward data from PRF
	    // writeback data to PRF
		expected_WB_valid = 1'b0;
		expected_WB_data = 32'h4;
		expected_WB_PR = 7'h0;
		expected_WB_ROB_index = 7'h0;
	    // writeback backpressure from PRF
	    // restart req to ROB
		expected_restart_req_valid = 1'b0;
		expected_restart_req_mispredict = 1'b0;
		expected_restart_req_ROB_index = 7'h0;
		expected_restart_req_PC = 32'h0;
		expected_restart_req_taken = 1'b1;

		check_outputs();

        // ------------------------------------------------------------
        // finish:
        @(posedge CLK); #(PERIOD/10);
        
        test_case = "finish";
        $display("\ntest %0d: %s", test_num, test_case);
        test_num++;

        @(posedge CLK); #(PERIOD/10);

        $display();
        if (num_errors) begin
            $display("FAIL: %d tests fail", num_errors);
        end
        else begin
            $display("SUCCESS: all tests pass");
        end
        $display();

        $finish();
    end

endmodule