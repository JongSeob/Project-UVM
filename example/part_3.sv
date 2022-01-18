//----------------------------------------------------------------------
//  Copyright (c) 2011-2012 by Doulos Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//----------------------------------------------------------------------

// First Steps with UVM - Sequencer-Driver Communication
// See https://youtu.be/aXhHW000IeI

// Author: John Aynsley, Doulos
// Date:   1-May-2012


`include "uvm_macros.svh"

package my_pkg;

  import uvm_pkg::*;

  class my_transaction extends uvm_sequence_item;
  
    `uvm_object_utils(my_transaction)
  
    rand bit cmd;
    rand int addr;
    rand int data;

    // addr, data에게 constraint를 줌 
    constraint c_addr { addr >= 0; addr < 256; }
    constraint c_data { data >= 0; data < 256; }
    
    // uvm_sequence_item 변수 초기화
    function new (string name = "");
      super.new(name);
    endfunction
    
  endclass: my_transaction

  // 보통 sequencer는 매우 간단한 형태를 갖는다.
  // sequencer에서 특별한 작을을 해야 하는 경우가 아니라면 아래처럼 한 줄로 표현 가능하다.
  // uvm_sequence_item 을 my_transaction 으로 define 한 uvm_sequncer 를 my_sequencer 로 사용하겠다
  typedef uvm_sequencer #(my_transaction) my_sequencer;

  // uvm_sequence_item 을 my_transaction 으로 define
  class my_sequence extends uvm_sequence #(my_transaction);
  
    `uvm_object_utils(my_sequence)
    
    function new (string name = "");
      super.new(name);
    endfunction

    task body;
      if (starting_phase != null)
        starting_phase.raise_objection(this);

  // sequence에서 sequence item을 driver로 보내기 위해 start_item 이라는 method를 사용한다.
      repeat(8)
      begin
        req = my_transaction::type_id::create("req");
        start_item(req);
        //(uvm_sequence_base.svh) virtual task start_item (uvm_sequence_item item,

        if( !req.randomize() )
          `uvm_error("", "Randomize failed")

        // finish_item을 통해 driver와의 communication을 끝낸다.
        finish_item(req);
        //(uvm_sequence_base.svh) virtual task finish_item (uvm_sequence_item item,
      end
      
      if (starting_phase != null)
        starting_phase.drop_objection(this);
    endtask: body
   
  endclass: my_sequence
  

  class my_driver extends uvm_driver #(my_transaction);
  
    `uvm_component_utils(my_driver)

    virtual dut_if dut_vi;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      // Get interface reference from config database
      if( !uvm_config_db #(virtual dut_if)::get(this, "", "dut_if", dut_vi) )
        `uvm_error("", "uvm_config_db::get failed")
    endfunction 
   
    task run_phase(uvm_phase phase);
      forever
      begin
        // sequencer가 보내주는 transaction이 있는지 기다린다.
        seq_item_port.get_next_item(req);
        //(uvm_sequencer.svh )

        // Wiggle pins of DUT
        @(posedge dut_vi.clock);
        dut_vi.cmd  = req.cmd;
        dut_vi.addr = req.addr;
        dut_vi.data = req.data;
        
        // DUT에 driving이 끝나면 item_done을 sequencer에 보낸다.
        seq_item_port.item_done();
      end
    endtask

  endclass: my_driver
  
  
  class my_env extends uvm_env;

    `uvm_component_utils(my_env)
    
    my_sequencer m_seqr;
    my_driver    m_driv;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
 
    function void build_phase(uvm_phase phase);
      m_seqr = my_sequencer::type_id::create("m_seqr", this);
      m_driv = my_driver   ::type_id::create("m_driv", this);
    endfunction
    
    // sequencer와 driver를 연결한다.
    function void connect_phase(uvm_phase phase);
      m_driv.seq_item_port.connect( m_seqr.seq_item_export );
    endfunction
    
  endclass: my_env
  
  
  class my_test extends uvm_test;
  
    `uvm_component_utils(my_test)
    
    my_env m_env;
    my_sequence seq;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      m_env = my_env::type_id::create("m_env", this);
      seq = my_sequence::type_id::create("seq");
    endfunction
    
    task run_phase(uvm_phase phase);
      if( !seq.randomize() ) 
        `uvm_error("", "Randomize failed")
      seq.starting_phase = phase;
      // sequencer에 원하는 sequence를 start 시킨다.
      seq.start( m_env.m_seqr );
      //(uvm_sequence_base.svh) virtual task start (uvm_sequencer_base sequencer,
    endtask
     
  endclass: my_test
  
  
endpackage: my_pkg


module top;

  import uvm_pkg::*;
  import my_pkg::*;
  
  dut_if dut_if1 ();
  
  dut    dut1 ( .dif(dut_if1) );

  // Clock generator
  initial
  begin
    dut_if1.clock = 0;
    forever #5 dut_if1.clock = ~dut_if1.clock;
  end

  initial
  begin
    uvm_config_db #(virtual dut_if)::set(null, "*", "dut_if", dut_if1);
    
    uvm_top.finish_on_completion = 1;
    
    run_test("my_test");
  end

endmodule: top

`include "uvm_macros.svh"

interface dut_if;

  logic clock, reset;
  logic cmd=0;
  logic [7:0] addr=0;
  logic [7:0] data=0;

endinterface


module dut(dut_if dif);

  import uvm_pkg::*;

  always @(posedge dif.clock)
  begin
    `uvm_info("", $sformatf("DUT received cmd=%b, addr=%d, data=%d",
                            dif.cmd, dif.addr, dif.data), UVM_MEDIUM)
  end
  
endmodule      
      
/*
simulation result
# KERNEL: UVM_INFO @ 0: reporter [RNTST] Running test my_test...
# KERNEL: UVM_INFO /home/runner/testbench.sv(214) @ 5: reporter [] DUT received cmd=0, addr=  0, data=  0
# KERNEL: UVM_INFO /home/runner/testbench.sv(214) @ 15: reporter [] DUT received cmd=1, addr=119, data= 62
# KERNEL: UVM_INFO /home/runner/testbench.sv(214) @ 25: reporter [] DUT received cmd=0, addr=174, data=114
# KERNEL: UVM_INFO /home/runner/testbench.sv(214) @ 35: reporter [] DUT received cmd=0, addr= 27, data=219
# KERNEL: UVM_INFO /home/runner/testbench.sv(214) @ 45: reporter [] DUT received cmd=1, addr=190, data=121
# KERNEL: UVM_INFO /home/runner/testbench.sv(214) @ 55: reporter [] DUT received cmd=1, addr=152, data= 75
# KERNEL: UVM_INFO /home/runner/testbench.sv(214) @ 65: reporter [] DUT received cmd=0, addr=169, data= 81
# KERNEL: UVM_INFO /home/runner/testbench.sv(214) @ 75: reporter [] DUT received cmd=0, addr=240, data=140
# KERNEL: UVM_INFO /home/build/vlib1/vlib/uvm-1.2/src/base/uvm_objection.svh(1271) @ 75: reporter [TEST_DONE] 'run' phase is ready to proceed to the 'extract' phase
# KERNEL: UVM_INFO /home/build/vlib1/vlib/uvm-1.2/src/base/uvm_report_server.svh(869) @ 75: reporter [UVM/REPORT/SERVER] 
# KERNEL: --- UVM Report Summary ---
# KERNEL: 
# KERNEL: ** Report counts by severity
# KERNEL: UVM_INFO :   11
# KERNEL: UVM_WARNING :    0
# KERNEL: UVM_ERROR :    0
*/
