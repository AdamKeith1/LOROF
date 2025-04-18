# prf
- Physical Register File
- see [memory_array_basics.md](../../basics/memory_array_basics.md) for information on memory arrays
- see [reg_rename_basics.md](../../basics/reg_rename_basics.md) for the reasoning behind having a physical register file
- 128x 32-bit physical registers
    - physical registers themselves are implemented as Distributed RAM
- 4x banks
    - 32x physical registers each
    - 2x fully-independent read ports each
    - 1x write port each
- registers are assigned to banks based on the lower 2 bits of the PR number
    - PR[1:0]
- registers are indexed within a bank based on the upper 5 bits of the PR number
    - PR[6:2]
- 11x read requestors
- 7x write requestors
- module internally arbitrates the read requests and write requests among the banks
- memory arrays are instantiated as 4x dual-read-port, single-write-port Distributed RAM arrays

# RTL Diagram
![prf RTL Diagram](prf_rtl.png)


# Parameters

## Variable Parameters
The module can be customized with different values for these

Verification should be performed for the default values as given here

- PR_COUNT = 128
    - physical register count
    - design should be functional for >= 2*PRF_BANK_COUNT and power of 2
- LOG_PR_COUNT = 7
    - number of bits needed to represent a physical register
    - log2(PR_COUNT)
- PRF_BANK_COUNT = 4
    - number of banks in the physical register file
    - design should be functional for >= 1 and power of 2
- LOG_PRF_BANK_COUNT = 2
    - number of bits needed to represent a bank
    - log2(PRF_BANK_COUNT)
- PRF_RR_COUNT = 11
    - number of read requestors
    - design should be functional for >= 2
- PRF_WR_COUNT = 7
    - number of write requestors
    - design should be functional for >= 2
- USE_BRAM = 0
    - select to use BRAM instead of Distributed RAM for the memory arrays
    - design should be functional for 0 or 1

## Constant Parameters
All of these are constants from core_types_pkg.vh
- LOG_ROB_ENTRIES = 7


# Interfaces
Input interfaces blue. Output interfaces green.
These signals are interdependent on functionality described in [Read Arbitration](#read-arbitration) and [Write Arbitration](#write-arbitration)

<span style="color:orange">

## seq

</span>

This is a sequential module utilizing posedge flip flops

- CLK
    - input logic
    - clock signal
- nRST
    - input logic
    - active-low asynchronous reset
    - FF state for the module can be reset after a single asynchronous assertion
        - this includes all saved read and write requests and the buffered forward_data_by_bank signal
    - the Distributed RAM making up the physical registers cannot be reset. it is initialized as all 0's in simulation, and after this point, it will be unaffected by assertion of nRST

<span style="color:deepskyblue">

## read req info by read requestor

</span>

input interface

- read_req_valid_by_rr
    - input logic [10:0]
        - design uses: input logic [PRF_RR_COUNT-1:0]
    - "Read Request Valid by Read Requestor"
    - bit vector signaling that a given read requestor is performing a read request
    - constraints:
        - utilize as control signal to indicate an active read request per read requestor
        - for every cycle that this signal is set for a given read requestor, the next cycle it should be set to initiate a new read request is at earliest the first cycle when the associated read_resp_ack_by_rr bit for the same read requestor is set
            - essentially, there should be only 1 active unacked read request per read requestor at a time
            - external modules guarantee this as the read requestors correspond to pipelines, and the pipelines will stall if their requests are still unacked, thus preventing issuing into the pipeline, thus preventing a new read request for this read requestor
            - else, behavior is undefined
                - in the design, the younger request will be lost. this behavior does not have to be verified
        - also see [Write to Read Forwarding](#write-to-read-forwarding)
- read_req_PR_by_rr
    - input logic [10:0][6:0]
        - design uses: input logic [PRF_RR_COUNT-1:0][LOG_PR_COUNT-1:0]
    - "Read Request Physical Register by Read Requestor"
    - vector of physical registers indicating which PR to read from for each read requestor
    - constraints:
        - none
            - any requestor can target any physical register at a given time, regardless of bank or index within a bank

<span style="color:chartreuse">

## read resp info by read requestor

</span>

output interface

- read_resp_ack_by_rr
    - output logic [10:0]
        - design uses: output logic [PRF_RR_COUNT-1:0]
    - "Read Response Acknowledgement by Read Requestor"
    - bit vector signaling that the previous read request by this read requestor is being serviced on this cycle
        - on this cycle, the read requestor is expected to sample the read_data_by_bank_by_port signal for the bank of interest (known by the read requestor) for the port of interest (indicated by read_resp_port_by_rr)
    - see [Read Arbitration](#read-arbitration) for more info
    - reset value:
        - {11{1'h0}}
- read_resp_port_by_rr
    - output logic [10:0]
        - design uses: output logic [PRF_RR_COUNT-1:0]
    - "Read Response Port by Read Requestor"
    - vector of ports corresponding to the read requestors
    - port can be 0 or 1
    - don't care at a given bit when read_resp_ack_by_rr = 1'b0 at the associated bit
    - see [Read Arbitration](#read-arbitration) for more info
    - reset value:
        - {11{1'h0}}

<span style="color:chartreuse">

## read data by bank

</span>

output interface

- read_data_by_bank_by_port
    - output logic [3:0][1:0][31:0]
        - design uses: output logic [PRF_BANK_COUNT-1:0][1:0][31:0]
    - read data for the 2 ports of each of the 4 PRF banks
    - 3D array
        - first dim: bank
        - second dim: port
        - third dim: 32'bit register data value
    - reset value:
        - {4{2{32'h0}}}

<span style="color:deepskyblue">

## writeback info by write requestor

</span>

input interface

- WB_valid_by_wr
    - input logic [6:0]
        - design uses: input logic [PRF_WR_COUNT-1:0]
    - "Writeback Valid by Write Requestor"
    - bit vector signaling that a given write requestor is attempting a writeback this cycle
    - a valid writeback is ignored if WB_ready_by_wr = 1'b0 for the given write requestor
    - constraints:
        - utilize as control signal to indicate a WB attempt for each write requestor
        - also see [Write to Read Forwarding](#write-to-read-forwarding)
- WB_data_by_wr
    - input logic [6:0][31:0]
        - design uses: input logic [PRF_WR_COUNT-1:0][31:0]
    - "Writeback data by Write Requestor"
    - vector of 32-bit data to be written back for each write requestor
    - constraints:
        - none
- WB_PR_by_wr
    - input logic [6:0][6:0]
        - design uses: input logic [PRF_WR_COUNT-1:0][LOG_PR_COUNT-1:0]
    - "Writeback Physical Registor by Write Requestor"
    - vector of physical registers indicating which PR to write back to for each write requestor
    - constraints:
        - none
- WB_ROB_index_by_wr
    - input logic [6:0][6:0]
        - design uses: input logic [PRF_WR_COUNT-1:0][LOG_ROB_ENTRIES-1:0]
    - "Writeback Reorder Buffer Index by Write Requestor"
    - vector of ROB indexes indicating which ROB index to mark as complete for each write requestor
    - essentially acts as a pass-through value to be assigned to complete_bus_ROB_index_by_bank when the write request is eventually completed
    - constraints:
        - none

<span style="color:chartreuse">

## writeback feedback by write requestor

</span>

output interface

- WB_ready_by_wr
    - output logic [6:0]
        - design uses: output logic [PRF_WR_COUNT-1:0]
    - "Writeback Ready by Write Requestor"
    - bit vector indicating that a new writeback request cannot be accepted this cycle for each write requestor
    - this flag directly corresponds to whether there exists an unacked/saved write request for this write requestor
    - reset value:
        - {7{1'b1}}

<span style="color:chartreuse">

## writeback bus by bank

</span>

output interface

- WB_bus_valid_by_bank
    - output logic [3:0]
        - design uses: output logic [PRF_BANK_COUNT-1:0]
    - bit vector indicating whether there is a writeback this cycle for each bank
    - this is the exact cycle when the register array write occurs
        - the value will be readable from the register array on the next cycle
    - a writeback this cycle for a given bank also implies that on the next cycle, the data on forward_data_bus_by_bank will correspond to this cycle's writeback
    - issue queues can use this signal to check if an operand is ready and that forward data will be available next cycle
    - see [Write Arbitration](#write-arbitration) for more info
    - reset value:
        - {4{1'h0}}
- WB_bus_upper_PR_by_bank
    - output logic [3:0][4:0]
        - design uses: output logic [PRF_BANK_COUNT-1:0][LOG_PR_COUNT-LOG_PRF_BANK_COUNT-1:0]
    - "Writeback Bus Upper Physical Register by Bank"
    - vector of upper 5 physical register bits for each bank
    - this is a passthrough of the upper 5 bits of the relevant write requestor of WB_PR_by_wr which was selected for this WB/complete for each bank this cycle
    - this directly translates to the memory array index that this bank is writing to
    - issue queues can check this signal to see if a writeback to a PR of interest is occurring this cycle
    - reset value:
        - {4{5'h0}}

<span style="color:chartreuse">

## forward data by bank

</span>

output interface

- forward_data_bus_by_bank
    - output logic [3:0][31:0]
        - design uses: output logic [PRF_BANK_COUNT-1:0][31:0]
    - vector of 32-bit writeback data for each bank, delayed by 1 cycle
    - this signal is 1 cycle delayed behind the associated WB_bus_valid_by_bank and WB_bus_upper_PR_by_bank for this writeback
    - FU's can grab forward values from this signal if their ops were issued on the cycle before, when the FU's would have seen a WB_bus_valid_by_bank matching an operand the op was waiting for in the IQ
    - reset value:
        {4{32'h0}}

<span style="color:chartreuse">

## complete bus by bank

</span>

output interface

- complete_bus_valid_by_bank
    - output logic [3:0]
        - design uses: output logic [PRF_BANK_COUNT-1:0]
    - bit vector indicating whether there is a complete notification this cycle for each bank
    - this signal coincides exactly with WB_bus_valid_by_bank and always corresponds to the same write request EXCEPT WHEN THERE IS A WRITE TO PR 0
        - in the write to PR 0 case, there will be a complete_bus_valid_by_bank = 1'b1, but WB_bus_valid_by_bank = 1'b0 as PR 0 should never be written to, but the ROB, which sees the [complete bus by bank](#complete-bus-by-bank) interface, still needs to see the completion notification for the instruction which tried to write to PR 0
    - reset value:
        - {4{1'h0}}
- complete_bus_ROB_index_by_bank
    - output logic [3:0][6:0]
        - design uses: output logic [PRF_BANK_COUNT-1:0][LOG_ROB_ENTRIES-1:0]
    - vector of ROB indexes for each bank
    - this is essentially a pass-through of the value previously given on WB_ROB_index_by_wr
    - this is a passthrough of value given from the relevant write requestor of WB_ROB_index_by_wr which was selected for this WB/complete for each bank this cycle
    - reset value:
        - {4{7'h0}}


# Read Arbitration

Read arbitration is necessary to deal with the unideal cases where there are too many read requests with bank conflicts than can be handled by the 4x bank, 2x port read channels.

Read requests follow a blocking valid-ack paradigm, where the [read req info by read requester](#read-req-info-by-read-requestor) interface is asserted for a read requestor of interest, and then on the next cycle or until as late as the upper bound response time (6 cycles as determined below), the [read resp info by read requestor](#read-resp-info-by-read-requestor) interface is asserted. 

Subsequent read requests will be ignored during this time between a read request and a read resp ack. In the best case, fully back-to-back cycles of read requests are allowed if back-to-back 1-cycle delayed read resp acks are maintained. 

The read arbitration mechanism solves the problem of only 2 independent read ports per bank but up to 11 read requestors. Each bank follows these arbitration rules:
- 11 read requests. a read request is made up of either a current [read req info by read requester](#read-req-info-by-read-requestor) interface assertion by read requestor or a saved/unacked read request from a previous cycle when the [read req info by read requester](#read-req-info-by-read-requestor) interface was asserted by read requestor
    - following the valid-ack paradigm, a given read requestor should never try to initiate a new read request before the last one has been ack'd
        - external modules guarantee this behavior
- unacked read requests are internally saved in the prf. read response ack's are given at the beginning of the next cycle, but whether or not an unacked response needs to be saved is determined on the same cycle that [read req info by read requester](#read-req-info-by-read-requestor) interface signals arrive. 
- the age of an unacked request has no bearing on the priority of a read request. new vs. saved/previously unacked read requests are treated the same. round-robin ordering is used to guarantee older read requests eventually finish. 
- out of the set of 11 read requests at each bank:
    - port 0 follows round-robin, increasing-lsb order to select a read request if there were at least 2 read requests acked in the previous cycle, else it follows the absolute lsb-first priority
        - least significant bits in bit vectors first -> lower indexes in first
    - port 1 continues in round-robin, increasing-lsb order after port 0
        - the round-robin order for the next cycle is continued after the read request index selected by port 1
        - if there is no port 1 read request, then the round-robin is reset and absolute lsb-first priority will be used next cycle. hence the condition above where 2 read requests must be fulfilled this cycle to continue round-robin ordering next cycle (2 read requests means port 0 and port 1 were both used)
    - for either port, if there are no remaining read requests, there is no read response for the port i.e. there is no subsequent activity on the [read resp info by read requestor](#read-resp-info-by-read-requestor) and [read data by bank](#read-data-by-bank) interfaces. otherwise, the activity on these interfaces follows the selected read requests by bank by port 
- properties of read arbitration given the above rules:
    - if there is only one active read request at a bank, only port 0 will be used
    - if there are 2 or fewer read requests to a bank per cycle, there will be no stalls or unacked requests for the bank, and all read response ack's will always come on the cycle after the read requests

#### Upper Bound Response Time: 6 cycles
- 11x read requests, all to the same bank
- 10x read requests in round robin before the last request
- 2x read requests completed per cycle
- 5 cycles + 1 latched cycle


# Example Read Operation

see [prf_example.md](prf_example.md)


# Write Arbitration

Write arbitration is necessary to deal with the unideal cases where there are bank conflicts to the 4x bank 1x port write channels. 

Write requests follow a ready-valid paradigm, where the [writeback info by write requestor](#writeback-info-by-write-requestor) interface is asserted for a write requestor of interest, and then on the next cycle and until as late as the upper bound response time (7 cycles as determined below), the [writeback feedback by write requestor](#writeback-feedback-by-write-requestor) interface can signal that the PRF is not ready for a new write request. 

Subsequent write requests will be ignored during this time while the [writeback feedback by write requestor](#writeback-feedback-by-write-requestor) interface is signaling not ready. In the best case, fully back-to-back cycles of write requests are allowed if the ready signal remains asserted.

The write arbitration mechanism solves the problem of only 1 write port per bank but up to 7 write requestors. Each bank follows these arbitration rules:
- 7 write requests. a write request consists of either a current [writeback info by write requestor](#writeback-info-by-write-requestor) interface assertion by write requestor or a saved/unacked write request from the last time [writeback info by write requestor](#writeback-info-by-write-requestor) was asserted and the ready signal was asserted.
    - following the ready-valid paradigm, if there is a saved/unacked write request, that is the request used for the write requestor, and the current-cycle [writeback info by write requestor](#writeback-info-by-write-requestor) interface write request is ignored, EVEN IF THIS CURRENT-CYCLE REQUEST IS TO A DIFFERENT BANK
- unacked write requests are internally saved in the prf. the ready signal is given at the beginning of the next cycle, but whether or not an unacked response needs to be saved is determined on the same cycle that [writeback info by write requestor](#writeback-info-by-write-requestor) interface signals arrive
- the age of an unacked request has no bearing on the priority of a write request. new vs. saved/previously unacked write requests are treated the same. round-robin ordering is used to guarantee older write requests eventually finish. 
- out of the set of 7 write requests at each bank:
    - follow round-robin increasing-lsb order to select a read request if there was a write request accepted in the previous cycle, else follow the absolute lsb-first priority
        - least signifciant bits in bit vector first -> lower indexes first
    - the round-robin order for the next cycle is continued after the write request index used in this cycle with a valid write request
    - if there is no write request this cycle, then the round-robin is reset and absolute lsb-first priority will be used next cycle
    - if there is no write request, there will be no subsequent activity on the [writeback bus by bank](#writeback-bus-by-bank), [forward data by bank](#forward-data-by-bank), and [complete bus by bank](#complete-bus-by-bank) interfaces. otherwise, the activity in these interfaces follows the selected write requests by bank
- properties of write arbitration given the above rules:
    - if there is only a single write request to a bank per cycle, there will be no stalls/ready deassertions or unacked requests for the bank, and all write activity will always come on the cycle after the write request

#### Upper Bound Response Time: 7 cycles
- 7x write requests, all to the same bank
- 6x write requests in round robin before the last request
- 1x write request completed per cycle
- 6 cycles + 1 latched cycle


# Write to Read Forwarding

<ins>There is no form of write to read forwarding internal to the PRF design.</ins> The properties of the LOROF core imply that a PRF read request will only be interested in the last value in the PR since the last cycle when WB_bus_valid_by_bank was high for the PR of interest, so no hardware PRF forwarding mechanism is needed. There will never be a case where there is e.g. a WB_valid_by_wr and read_req_valid_by_rr for the same PR on the same cycle or within close succession. See [reg_rename_basics.md](reg_rename_basics.md) for why.

This internal forwarding I'm referring to which the PRF does not have is separate from the forwarding that occurs externally in the core. This forwarding is when WB_bus_valid_by_bank broadcasts a write to the issue queues, and the issue queue launches an instruction to a functional unit pipeline which can read the data on forward_data_bus_by_bank on the following cycle. This forwarding is externally managed by the issue queues and functional unit pipelines, and is enabled by the PRF offering the [writeback bus by bank](#writeback-bus-by-bank) and [forward data by bank](#forward-data-by-bank) interfaces.

On the cycle that WB_bus_valid_by_bank is eventually high for the PR of interest, the internal PRF memory bank of interest will have been updated with the value written by the next posedge. There is technically at least a 1-cycle delay in receiving a reg read request and performing the memory array read, so the earliest a read attempt can try to read this register is on the same cycle WB_bus_valid_by_bank is high. 

The PR values for every PR are reset to 32'h0. This is the expected value to read until the first time the [writeback bus by bank](#writeback-bus-by-bank) interface. After this point, the expected value to read from a PR follows the last value written to the PR as indicated by the [writeback bus by bank](#writeback-bus-by-bank) interface.

As far as verification is concerned, read requests and write requests should follow these rules:
- active <ins>read</ins> request definition:
    - first cycle: cycle when read_req_valid_by_rr is high for the PR of interest
    - last cycle: cycle when read_resp_ack_by_rr is high for the read requestor for the PR of interest
- active <ins>write</ins> request definition:
    - first cycle: cycle when WB_valid_by_wr & WB_ready_by_wr is high for the PR of interest
    - last cycle: cycle when WB_bus_valid_by_bank is high w/ WB_bus_upper_PR_by_bank matching the PR of interest for the bank of interest
- active <ins>write</ins> requests to the same PR <ins>**CANNOT**</ins> overlap
- active <ins>read</ins> requests to a given PR <ins>**CANNOT**</ins> overlap with an active <ins>write</ins> request to the same PR
- active <ins>read</ins> requests to the same PR <ins>**CAN**</ins> overlap


# Example Write Operation

see [prf_example.md](prf_example.md)


# Behavioral Model Ideas
- RR: Read Requestor
- WR: Write Requestor

### Read Arbitration
- model per bank
- start with RR left off at -> "continue RR"
    - 0 on reset
    - cleared back to 0 if second read port was not used last cycle
- read port 0: select next valid RR in order starting at the continue RR, allowing wrap around back to 0 after 10
    - prioritize saved read request by RR if present
    - eliminate this RR from contention
    - can be non-existent if 0 RR's are active this cycle
- read port 1: select next valid read requestor in order starting at the RR after the RR selected by read port 0
    - prioritize saved read request by RR if present
    - eliminate this requestor from contention
    - set the continue RR to the RR after this selected RR
    - can be non-existent if 0 or 1 RR's are active this cycle
        - if this is the case, clear the continue RR back to 0
- any non-eliminated RR's have their read requests saved for the next cycle

### Write Arbitration
- model per bank
- start with write requestor left off at -> "continue WR"
    - 0 on reset
    - cleared back to 0 if write port was not used last cycle
- select next valid WR in order starting at the continue WR, allowing wrap around back to 0 after 6
    - prioritize saved write request by WR if present
    - eliminate this write requestor from contention
    - set the continue WR to the WR after this selected WR
    - can be non-existent if 0 WR's are active this cycle
        - if this is the case, clear the continue WR back to 0
- any non-eliminated WR's have their write requests saved for the next cycle


# Assertions
- no output x's after reset
- read response ack before upper bound response time after read request for all read requests
- write request ready only low for the upper bound response time cycles
- read value for given PR follows reset value of 32'h0 if the PR has never been written to, else it follows the value written to the PR the last time the PR appeared on the [writeback bus by bank](#writeback-bus-by-bank) interface


# Test Ideas and Coverpoints
- read arbitration and write arbitration are independent operations (except for the fact that write values propagate to be seen by reads), but they should be rigorously tested simultaneously
- this module is pretty tough due to the specific bank conflict arbitration rules. if it is a significant pain, specific round-robin rules don't have to be precisely tested, but instead that all bank conflicts are handled (i.e. no requests to a bank are lost) and the upper bound on response time is not surpassed
    - this could be like initiating a set of requests per bank, and expecting for one request per bank to finish per cycle, but the order in which the requests in the set are completed doesn't matter, as long as all requests are complete before the upper bound
    - read request upper bound: 6 cycles
        - 11x read requests, all to the same bank
        - 10x read requests in round robin before the last request
        - 2x read requests completed per cycle
        - 5 cycles + 1 latched cycle
    - write request upper bound: 7 cycles
        - 7x write requests, all to the same bank
        - 6x write requests in round robin before the last request
        - 1x write request completed per cycle
        - 6 cycles + 1 latched cycle
- essentially, I see 2 approaches to verifying the prf. I think both ought to be used:
    - low-level approach
        - meticulously test cycle-accurate arbitration functionalities for a small, tractable number of cases
    - high-level approach
        - hammer the heck out of the prf with all kinds of scenarios. only test that upper bound response times are never violated
            - and of course test expected values are retrieved when the responses come
