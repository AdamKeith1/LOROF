/*
  Module        : alu_pipeline
  UMV Component : reset sequence
  Author        : Adam Keith
*/

`ifndef ALU_PIPELINE_RST_SEQ_SV
`define ALU_PIPELINE_RST_SEQ_SV

// --- UVM --- //
`include "uvm_macros.svh"
import uvm_pkg::*;

// --- Packages --- //
`include "core_types_pkg.svh"
import core_types_pkg::*;
    
// --- Reset Sequence --- //
class reset_sequence extends uvm_sequence;
  `uvm_object_utils(reset_sequence)
  
  alu_pipeline_sequence_item reset_pkt;
  
  // --- Constructor --- //
  function new(string name= "reset_sequence");
    super.new(name);
    `uvm_info("RESET_SEQ", "Inside Constructor", UVM_HIGH)
  endfunction
  
  // --- Body Task --- //
  task body();
    `uvm_info("RESET_SEQ", "Inside body task", UVM_HIGH)
    
    // --- Randomize With Reset --- //
    reset_pkt = garbage_sequence_item::type_id::create("reset_pkt");
    start_item(reset_pkt);
    reset_pkt.randomize() with {nRST==0;};
    finish_item(reset_pkt);
        
  endtask : body
  
endclass : reset_sequence

// --- Garbage Sequence - to prime reset --- //
class garbage_sequence extends uvm_sequence;
  `uvm_object_utils(garbage_sequence)
  
  alu_pipeline_sequence_item garbage_pkt;
  
  // --- Constructor --- //
  function new(string name= "garbage_sequence");
    super.new(name);
    `uvm_info("GARBAGE_SEQ", "Inside Constructor", UVM_HIGH)
  endfunction
  
  // --- Body Task --- //
  task body();
    `uvm_info("GARBAGE_SEQ", "Inside body task", UVM_HIGH)
    
    // --- Randomize With Reset --- //
    garbage_pkt = garbage_sequence_item::type_id::create("garbage_pkt");
    start_item(garbage_pkt);
    garbage_pkt.randomize() with {nRST==1;};
    finish_item(garbage_pkt);
        
  endtask : body
  
endclass : garbage_sequence

`endif