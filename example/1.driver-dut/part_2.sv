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
//test
// First Steps with UVM - The DUT Interface
// See https://youtu.be/FkclDiK4Oco

// Author: John Aynsley, Doulos
// Date:   1-May-2012


`include "uvm_macros.svh"

package my_pkg;

  import uvm_pkg::*;


  class my_driver extends uvm_driver;
  
    `uvm_component_utils(my_driver)

    virtual dut_if dut_vi;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    
///////////////////////////////////////////////////////////////////////////////
// top에서 configuration database에 저장한 virtual interface를 driver가 get한다. 
///////////////////////////////////////////////////////////////////////////////
    
    function void build_phase(uvm_phase phase);
      // Get interface reference from config database
      if( !uvm_config_db #(virtual dut_if)::get(this, "", "dut_if", dut_vi) )
        `uvm_error("", "uvm_config_db::get failed")
    endfunction 
        
    
    task run_phase(uvm_phase phase);
      `uvm_info(get_type_name(),"aaaaaa",UVM_MEDIUM)
      forever
      begin
        // Wiggle pins of DUT
        @(posedge dut_vi.clock);
        dut_vi.cmd  <= $urandom;
        dut_vi.addr <= $urandom;
        dut_vi.data <= $urandom;    
        `uvm_info("", $sformatf("DUT received cmd=%b, addr=%d, data=%d",
         dut_vi.cmd, dut_vi.addr, dut_vi.data), UVM_MEDIUM)
      end
    endtask

  endclass: my_driver
  
  
  class my_env extends uvm_env;

    `uvm_component_utils(my_env)
    
    my_driver m_driv;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
 
    function void build_phase(uvm_phase phase);
      m_driv = my_driver::type_id::create("m_driv", this);
    endfunction
    
  endclass: my_env
  
  
  class my_test extends uvm_test;
  
    `uvm_component_utils(my_test)
    
    my_env m_env;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      m_env = my_env::type_id::create("m_env", this);
    endfunction
    
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      #80;
      phase.drop_objection(this);
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

      
//////////////////////////////////////////////////////////////////////////////////////////////////////
// top에서 dut virtual interface를 configuration database에 저장하기 위해 set한다. 
// 모든 uvm검증의 시작은 top에서 run_test를 호출하는 것으로 시작된다.
// run_test는 uvm 소스코드의 base/uvm_globals.svh에 정의되어 있다.
// run_test는 여러 복잡한 단계를 거쳐 uvm_phase 중 run_phase를 실행시키는게 주된 목적이다.
// run_phase는 실제 동작이 구현되는 부분이니 이 코드가 들어갈만한 곳은 uvm_driver, uvm_monitor 정도가 된다. 
//////////////////////////////////////////////////////////////////////////////////////////////////////
      //[태승] Test222
