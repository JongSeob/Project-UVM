`include "uvm_macros.svh"

package my_pkg;

import uvm_pkg::*;

`define ADDR_WIDTH  8
`define DATA_WIDTH  16
`define DEPTH		 256
`define RESET_VAL	  16'h1234

////////////////////////////////////////////////////////////////////////
// uvm_sequence_item
////////////////////////////////////////////////////////////////////////
class Reg_item extends uvm_sequence_item;
  rand bit [`ADDR_WIDTH-1 :0]	addr;
  rand bit [`DATA_WIDTH-1 :0]	wdata;
  rand bit						wr;
  bit [`DATA_WIDTH-1 :0]		rdata;
  
  // uvm_object 또는 uvm_transaction 을 상속 받은 모든 class는 
  // uvm_object_utils를 사용하여 factory에 등록해야 한다.
  // Each `uvm_field_* macro has at least two arguments: ARG and FLAG.
  // ARG is the instance name of the variable and FLAG is used to control the field usage in core utilities operation.
  // By default, FLAG is set to UVM_ALL_ON
  //
  // UVM_ALL_ON  : Set all operation
  // UVM_DEFAULT : Use the default flag settings
  // 차이점?
  `uvm_object_utils_begin(Reg_item)
  `uvm_field_int (addr, UVM_ALL_ON)
 	 `uvm_field_int (wdata, UVM_ALL_ON)
 	 `uvm_field_int (rdata, UVM_ALL_ON)
 	 `uvm_field_int (wr, UVM_ALL_ON)
  `uvm_object_utils_end
  
  function new(string name = "Reg_item");
    super.new(name);
  endfunction
  
  virtual function string convert2string();
    return $sformatf("addr=0x%0h wr=0x%0h wdata=0x%0h rdata=0x%0h", addr, wr, wdata, rdata);
  endfunction
  
endclass

////////////////////////////////////////////////////////////////////////
// sequencer 
////////////////////////////////////////////////////////////////////////
// Reg_item이 define된 uvm_sequencer를 my_sequncer로 사용하겠다
typedef uvm_sequencer #(Reg_item) my_sequencer;

////////////////////////////////////////////////////////////////////////
// uvm_sequence
////////////////////////////////////////////////////////////////////////
class gen_item_seq extends uvm_sequence #(Reg_item);
// class를 factory에 등록
// factory란?
  `uvm_object_utils(gen_item_seq)

// class object를 생성한다
// parent class 변수를 초기화 한다
  function new(string name = "gen_item_seq");
    super.new(name);
  endfunction
  
  //rand int num;
  //constraint c1 {soft num inside {[2:5]}; }
  int num = 5;
  
  virtual task body();
    `uvm_info("SEQ", $sformatf("DBG P1"), UVM_LOW)
    for(int i=0; i< num; i++) begin
      // uvm_sequence_item를 상속받은 Reg_item을 m_item으로 사용하겠다
      Reg_item m_item = Reg_item::type_id::create("m_item");
      // m_item을 driver에 보낸다
      start_item(m_item);
      // driver에게 response를 받으면 radomize를 한다
      m_item.randomize();
      `uvm_info("SEQ", $sformatf("Generate new item: "), UVM_LOW)
      // m_item의 내용을 출력한다
      m_item.print();
      // driver의 driving 동작시키기 위해 finish_item을 수행한다
      finish_item(m_item);
      // driver로 부터 response를 받으면 finish_item은 종료된다
    end
    `uvm_info("SEQ", $sformatf("Done generation of %0d items", num), UVM_LOW)
  endtask
endclass

////////////////////////////////////////////////////////////////////////
// driver
////////////////////////////////////////////////////////////////////////
class Driver extends uvm_driver #(Reg_item);
// class를 factory에 등록한다
  `uvm_component_utils(Driver)

// class object를 생성한다
// parent class 변수를 초기화 한다
  function new(string name = "Driver", uvm_component parent=null);
    super.new(name, parent);
  endfunction

// virtual interface handling
  virtual reg_if vif;

// build phase
// configuration database에 있는 virtual interface인 reg_if 를 가져온다
// 못 가져오면 fatal error
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual reg_if)::get(this, "", "reg_vif", vif)) begin      //uvm_config_db is static. always using '::'\
      `uvm_fatal("DRV", "Could not get vif")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
  // [Q] uvm_driver 안에 run_phase가 없는데 super.run_phase를 하는 이유는?
  // 없어도 차이 없음
    //super.run_phase(phase);
    forever begin
      Reg_item m_item;
      `uvm_info("DRV", $sformatf("wait for item from sequencer"), UVM_LOW)
      // sequence로 부터 transaction을 기다림
      seq_item_port.get_next_item(m_item);
      // sequence로 부터 finish_item을 받으면 drive_item을 시작함
      drive_item(m_item);
      // driving 후 sequence에게 response를 보냄
      seq_item_port.item_done();
    end
  endtask

// driving to DUT
  virtual task drive_item(Reg_item m_item);
    vif.sel		<= 1;
    vif.addr		<= m_item.addr;
    vif.wr		<= m_item.wr;
    vif.wdata		<= m_item.wdata;
    @(posedge vif.clk);
    while (!vif.ready) begin
      `uvm_info("DRV", "Wait until ready is high", UVM_LOW)
      @(posedge vif.clk);
    end    
    vif.sel			<= 0;
  endtask

endclass

/////////////////////////////////////////////////////////////////////////////////////////////
// monitor
// Monitor is derived from uvm_monitor base class and should have the following functions:
// 1. Collect bus or signal information through a virtual interface
// 2. Collected data can be used for protocol checking and coverage
// 3. Collected data is exported via an analysis port

// Monitor functionality should be limited to basic monitoring that is always requited.
// It my have knobs to enable/disable basic protocol checking and coverage collection.
// High level fucntional checking should be done outside the monitor, in a scoreboard.
/////////////////////////////////////////////////////////////////////////////////////////////
class Monitor extends uvm_monitor;
// class를 factory에 등록함
  `uvm_component_utils(Monitor)
 
// class object를 생성한다
// parent class 변수를 초기화 한다
// This is standard code for all components
  function new(string name = "Monitor", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
// uvm_analysis_port는 uvm_analysis_imp를 수행하기 위한 모든 scoreboard에게 value를 알려줌
// Reg_item 형태로 capture함
  uvm_analysis_port #(Reg_item) mon_analysis_port;
  
 // A virtual interface handle to the actual interface that this monitor is trying to monitor
  virtual reg_if vif;
  bit  enable_check    = 1;
  bit  enable_coverage = 1;

  // Semaphore is a SystemVerilog built-in class, used for access control to shared resources, and for basic synchronization.
  // A semaphore is like a bucket with the number of keys.
  // processes using semaphores must first procure a key from the bucket before they can continue to execute, 
  // All other processes must wait until a sufficient number of keys are returned to the bucket.
  // Imagine a situation where two processes try to access a shared memory area. 
  // where one process tries to write and the other process is trying to read the same memory location. 
  // this leads to an unexpected result. A semaphore can be used to overcome this situation.
  //
  // Semaphore is a built-in class that provides the following methods,
  // new(); <- Create a semaphore with a specified number of keys
  // get(); <- Obtain one or more keys from the bucket
  // put(); <- Return one or more keys into the bucket
  // try_get(); <- Try to obtain one or more keys without blocking
  semaphore sema4;
  
  // configuration database에 저장된 virtual interface를 가져온다 
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual reg_if)::get(this, "", "reg_vif", vif)) begin
      `uvm_fatal("MON", "Could not get vif")
    end
    // the new method will create the semaphore with number_of_keys keys in a bucket; where number_of_keys is integer variable.
    // the default number of keys is ‘0’
    // the new() method will return the semaphore handle or null if the semaphore cannot be created
    sema4 = new(1);
    // Create an instance of the declared analysis port
    mon_analysis_port = new("mon_analysis_port", this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    
    // 완전한 transaction에 대한 interface를 모니터함
    // simulation 동안 모니터해야 하므로 forever 문을 사용해야 함
    forever begin
      @(posedge vif.clk);
      if(vif.sel) begin
        Reg_item item = new;
        item.addr = vif.addr;
        item.wr = vif.wr;
        item.wdata = vif.wdata;
        
        if(!vif.wr) begin
          @(posedge vif.clk);
          item.rdata = vif.rdata;
        end

        if (enable_check) begin
          check_protocol();
        end

        // Coverage group defined as cg_trans and will be sampled during run phase
        // playground에서 error 
        //if (enable_coverage) begin
        //  item.cg_trans.sample();
        //end

        `uvm_info(get_type_name(), $sformatf("Monitor found packet %s", item.convert2string()), UVM_LOW)
        mon_analysis_port.write(item);
      end
    end
  endtask
  
      virtual function void check_protocol();
      // Function to check basic protocol specs
    endfunction
  
endclass
////////////////////////////////////////////////////////////////////////
// agent
////////////////////////////////////////////////////////////////////////
class agent extends uvm_agent;
// class를 factory에 등록함
  `uvm_component_utils(agent)
  
// class object를 생성한다
// parent class 변수를 초기화 한다
// This is standard code for all components
  function new(string name = "agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  Driver	d0;
  Monitor	m0;
  //uvm_sequencer #(Reg_item) s0;
  my_sequencer s0;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    //s0 = uvm_sequencer#(Reg_item)::type_id::create("s0", this);
    s0 = my_sequencer::type_id::create("s0", this);
    d0 = Driver::type_id::create("d0", this);
    m0 = Monitor::type_id::create("m0", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    `uvm_info("AGENT", $sformatf("DBG P 0"), UVM_LOW)
    super.connect_phase(phase);
    // sequencer와 driver 사이를 TLB port로 연결
    d0.seq_item_port.connect(s0.seq_item_export);
  endfunction
  
endclass
////////////////////////////////////////////////////////////////////////
// scoreboard
////////////////////////////////////////////////////////////////////////
class scoreboard extends uvm_scoreboard;
// class를 factory에 등록
  `uvm_component_utils(scoreboard)
  // class object를 생성
  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  Reg_item refq[`DEPTH];
// uvm_analysis_imp는 (monitor에서) uvm_analysis_port로 보내진 모든 transaction을 받는다
  uvm_analysis_imp #(Reg_item, scoreboard) m_analysis_imp;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_analysis_imp = new("m_analysis_imp", this);
  endfunction

  virtual function write(Reg_item item);
    if(item.wr) begin
      if(refq[item.addr] == null) 
        refq[item.addr] = new;

      refq[item.addr] = item;
      `uvm_info(get_type_name(), $sformatf("Store addr=0x%0h wr=0x%0h data=0x%0h", item.addr, item.wr, item.wdata), UVM_LOW)

    end
    if(!item.wr) begin
      if(refq[item.addr] == null) begin
        if(item.rdata != 'h1234) begin
          `uvm_error(get_type_name(), $sformatf("First time read, addr=0x%0h, exp=1234 act=0x%0h", item.addr, item.rdata))
        end
        else begin
          `uvm_info(get_type_name(), $sformatf("PASS! First time read, addr=0x%0h, exp=1234 act=0x%0h", item.addr, item.rdata), UVM_LOW)
        end
      end
      else begin
        if(item.rdata != refq[item.addr].wdata) begin
          `uvm_error(get_type_name(), $sformatf("addr=0x%0h exp=0x%0h act=0x%0h", item.addr, refq[item.addr].wdata, item.rdata))
        end
        else begin
          `uvm_info(get_type_name(), $sformatf("PASS! addr=0x%0h exp=0x%0h act=0x%0h", item.addr, refq[item.addr].wdata, item.rdata), UVM_LOW)
        end
      end
    end

  endfunction
endclass
////////////////////////////////////////////////////////////////////////
// uvm_env
////////////////////////////////////////////////////////////////////////
class Env extends uvm_env;
  `uvm_component_utils(Env)
  function new(string name = "Env", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  agent a0;
  scoreboard sb0;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a0 = agent::type_id::create("a0", this);
    sb0 = scoreboard::type_id::create("sb0", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    a0.m0.mon_analysis_port.connect(sb0.m_analysis_imp);
  endfunction
endclass

////////////////////////////////////////////////////////////////////////
// uvm_test
////////////////////////////////////////////////////////////////////////
class test extends uvm_test;
  `uvm_component_utils(test)
  function new(string name = "test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  Env e0;
  virtual reg_if vif;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    e0 = Env::type_id::create("e0", this);
    if(!uvm_config_db#(virtual reg_if)::get(this, "", "reg_vif",vif)) 
      `uvm_fatal("TEST", "Did not get vif")
    
    uvm_config_db#(virtual reg_if)::set(this, "e0.a0.*", "reg_vif", vif);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    gen_item_seq seq = gen_item_seq::type_id::create("seq");
    phase.raise_objection(this);
    apply_reset();
    seq.randomize() with {num inside {[20:30]}; };
    seq.start(e0.a0.s0);
    #200;
    phase.drop_objection(this);
  endtask
  
  virtual task apply_reset();
    vif.rstn <= 0;
    repeat(5) @ (posedge vif.clk);
    vif.rstn <= 1;
    repeat(10) @ (posedge vif.clk);
  endtask
endclass

endpackage: my_pkg

module tb;
  import uvm_pkg::*;
  import my_pkg::*;
  
  bit clk;
  
  always #10 clk = ~clk;
  reg_if _if (clk);
  
  reg_ctrl u0 (
    .clk(clk),
    .addr(_if.addr),
    .rstn(_if.rstn),
    .sel(_if.sel),
    .wr(_if.wr),
    .wdata(_if.wdata),
    .rdata(_if.rdata),
    .ready(_if.ready)
  );
  
  initial begin
    //new_test t0;
    uvm_config_db #(virtual reg_if)::set(null, "uvm_test_top", "reg_vif", _if);
    run_test("test");
  end
  
  initial begin
    $dumpvars;
    $dumpfile("dump.vcd");
  end
endmodule

interface reg_if (input bit clk);
  logic 		rstn;
  logic [7:0] 	addr;
  logic [15:0] 	wdata;
  logic [15:0] 	rdata;
  logic			wr;
  logic			sel;
  logic			ready;
endinterface

/*
[SIMULATION RESULT]
# KERNEL: UVM_INFO @ 0: reporter [RNTST] Running test test...
# KERNEL: UVM_INFO /home/runner/testbench.sv(271) @ 0: uvm_test_top.e0.a0 [AGENT] DBG P 0
# KERNEL: UVM_INFO /home/runner/testbench.sv(123) @ 0: uvm_test_top.e0.a0.d0 [DRV] wait for item from sequencer
# RCKERNEL: Warning: RC_0024 testbench.sv(373): Randomization failed. The condition of randomize call cannot be satisfied.
# RCKERNEL: Info: RC_0103 testbench.sv(373): ... the following condition cannot be met: (20<=(seq.num=5))
# RCKERNEL: Info: RC_1007 testbench.sv(56): ... see class 'gen_item_seq' declaration.
# KERNEL: UVM_INFO /home/runner/testbench.sv(72) @ 290: uvm_test_top.e0.a0.s0@@seq [SEQ] DBG P1
# KERNEL: UVM_INFO /home/runner/testbench.sv(80) @ 290: uvm_test_top.e0.a0.s0@@seq [SEQ] Generate new item: [          0] 
# KERNEL: ------------------------------------------------------------------------
# KERNEL: Name                           Type      Size  Value                    
# KERNEL: ------------------------------------------------------------------------
# KERNEL: m_item                         Reg_item  -     @636                     
# KERNEL:   addr                         integral  8     'hba                     
# KERNEL:   wdata                        integral  16    'h64d4                   
# KERNEL:   rdata                        integral  16    'h0                      
# KERNEL:   wr                           integral  1     'h1                      
# KERNEL:   begin_time                   time      64    290                      
# KERNEL:   depth                        int       32    'd2                      
# KERNEL:   parent sequence (name)       string    3     seq                      
# KERNEL:   parent sequence (full name)  string    25    uvm_test_top.e0.a0.s0.seq
# KERNEL:   sequencer                    string    21    uvm_test_top.e0.a0.s0    
# KERNEL: ------------------------------------------------------------------------
# KERNEL: UVM_INFO /home/runner/testbench.sv(237) @ 310: uvm_test_top.e0.a0.m0 [Monitor] Monitor found packet addr=0xba wr=0x1 wdata=0x64d4 rdata=0x0
# KERNEL: UVM_INFO /home/runner/testbench.sv(300) @ 310: uvm_test_top.e0.sb0 [scoreboard] Store addr=0xba wr=0x1 data=0x64d4
# KERNEL: UVM_INFO /home/runner/testbench.sv(123) @ 310: uvm_test_top.e0.a0.d0 [DRV] wait for item from sequencer
# KERNEL: UVM_INFO /home/runner/testbench.sv(80) @ 310: uvm_test_top.e0.a0.s0@@seq [SEQ] Generate new item: [          1] 
# KERNEL: ------------------------------------------------------------------------
# KERNEL: Name                           Type      Size  Value                    
# KERNEL: ------------------------------------------------------------------------
# KERNEL: m_item                         Reg_item  -     @648                     
# KERNEL:   addr                         integral  8     'h27                     
# KERNEL:   wdata                        integral  16    'h6f3d                   
# KERNEL:   rdata                        integral  16    'h0                      
# KERNEL:   wr                           integral  1     'h0                      
# KERNEL:   begin_time                   time      64    310                      
# KERNEL:   depth                        int       32    'd2                      
# KERNEL:   parent sequence (name)       string    3     seq                      
# KERNEL:   parent sequence (full name)  string    25    uvm_test_top.e0.a0.s0.seq
# KERNEL:   sequencer                    string    21    uvm_test_top.e0.a0.s0    
# KERNEL: ------------------------------------------------------------------------
# KERNEL: UVM_INFO /home/runner/testbench.sv(123) @ 330: uvm_test_top.e0.a0.d0 [DRV] wait for item from sequencer
# KERNEL: UVM_INFO /home/runner/testbench.sv(80) @ 330: uvm_test_top.e0.a0.s0@@seq [SEQ] Generate new item: [          2] 
# KERNEL: ------------------------------------------------------------------------
# KERNEL: Name                           Type      Size  Value                    
# KERNEL: ------------------------------------------------------------------------
# KERNEL: m_item                         Reg_item  -     @654                     
# KERNEL:   addr                         integral  8     'h1                      
# KERNEL:   wdata                        integral  16    'h840f                   
# KERNEL:   rdata                        integral  16    'h0                      
# KERNEL:   wr                           integral  1     'h0                      
# KERNEL:   begin_time                   time      64    330                      
# KERNEL:   depth                        int       32    'd2                      
# KERNEL:   parent sequence (name)       string    3     seq                      
# KERNEL:   parent sequence (full name)  string    25    uvm_test_top.e0.a0.s0.seq
# KERNEL:   sequencer                    string    21    uvm_test_top.e0.a0.s0    
# KERNEL: ------------------------------------------------------------------------
# KERNEL: UVM_INFO /home/runner/testbench.sv(237) @ 350: uvm_test_top.e0.a0.m0 [Monitor] Monitor found packet addr=0x27 wr=0x0 wdata=0x6f3d rdata=0x1234
# KERNEL: UVM_INFO /home/runner/testbench.sv(309) @ 350: uvm_test_top.e0.sb0 [scoreboard] PASS! First time read, addr=0x27, exp=1234 act=0x1234
# KERNEL: UVM_INFO /home/runner/testbench.sv(141) @ 350: uvm_test_top.e0.a0.d0 [DRV] Wait until ready is high
# KERNEL: UVM_INFO /home/runner/testbench.sv(123) @ 370: uvm_test_top.e0.a0.d0 [DRV] wait for item from sequencer
# KERNEL: UVM_INFO /home/runner/testbench.sv(80) @ 370: uvm_test_top.e0.a0.s0@@seq [SEQ] Generate new item: [          3] 
# KERNEL: ------------------------------------------------------------------------
# KERNEL: Name                           Type      Size  Value                    
# KERNEL: ------------------------------------------------------------------------
# KERNEL: m_item                         Reg_item  -     @666                     
# KERNEL:   addr                         integral  8     'h48                     
# KERNEL:   wdata                        integral  16    'ha34a                   
# KERNEL:   rdata                        integral  16    'h0                      
# KERNEL:   wr                           integral  1     'h1                      
# KERNEL:   begin_time                   time      64    370                      
# KERNEL:   depth                        int       32    'd2                      
# KERNEL:   parent sequence (name)       string    3     seq                      
# KERNEL:   parent sequence (full name)  string    25    uvm_test_top.e0.a0.s0.seq
# KERNEL:   sequencer                    string    21    uvm_test_top.e0.a0.s0    
# KERNEL: ------------------------------------------------------------------------
# KERNEL: UVM_INFO /home/runner/testbench.sv(237) @ 390: uvm_test_top.e0.a0.m0 [Monitor] Monitor found packet addr=0x1 wr=0x0 wdata=0x840f rdata=0x1234
# KERNEL: UVM_INFO /home/runner/testbench.sv(309) @ 390: uvm_test_top.e0.sb0 [scoreboard] PASS! First time read, addr=0x1, exp=1234 act=0x1234
# KERNEL: UVM_INFO /home/runner/testbench.sv(141) @ 390: uvm_test_top.e0.a0.d0 [DRV] Wait until ready is high
# KERNEL: UVM_INFO /home/runner/testbench.sv(237) @ 410: uvm_test_top.e0.a0.m0 [Monitor] Monitor found packet addr=0x48 wr=0x1 wdata=0xa34a rdata=0x0
# KERNEL: UVM_INFO /home/runner/testbench.sv(300) @ 410: uvm_test_top.e0.sb0 [scoreboard] Store addr=0x48 wr=0x1 data=0xa34a
# KERNEL: UVM_INFO /home/runner/testbench.sv(123) @ 410: uvm_test_top.e0.a0.d0 [DRV] wait for item from sequencer
# KERNEL: UVM_INFO /home/runner/testbench.sv(80) @ 410: uvm_test_top.e0.a0.s0@@seq [SEQ] Generate new item: [          4] 
# KERNEL: ------------------------------------------------------------------------
# KERNEL: Name                           Type      Size  Value                    
# KERNEL: ------------------------------------------------------------------------
# KERNEL: m_item                         Reg_item  -     @683                     
# KERNEL:   addr                         integral  8     'hfc                     
# KERNEL:   wdata                        integral  16    'hccee                   
# KERNEL:   rdata                        integral  16    'h0                      
# KERNEL:   wr                           integral  1     'h1                      
# KERNEL:   begin_time                   time      64    410                      
# KERNEL:   depth                        int       32    'd2                      
# KERNEL:   parent sequence (name)       string    3     seq                      
# KERNEL:   parent sequence (full name)  string    25    uvm_test_top.e0.a0.s0.seq
# KERNEL:   sequencer                    string    21    uvm_test_top.e0.a0.s0    
# KERNEL: ------------------------------------------------------------------------
# KERNEL: UVM_INFO /home/runner/testbench.sv(237) @ 430: uvm_test_top.e0.a0.m0 [Monitor] Monitor found packet addr=0xfc wr=0x1 wdata=0xccee rdata=0x0
# KERNEL: UVM_INFO /home/runner/testbench.sv(300) @ 430: uvm_test_top.e0.sb0 [scoreboard] Store addr=0xfc wr=0x1 data=0xccee
# KERNEL: UVM_INFO /home/runner/testbench.sv(123) @ 430: uvm_test_top.e0.a0.d0 [DRV] wait for item from sequencer
# KERNEL: UVM_INFO /home/runner/testbench.sv(87) @ 430: uvm_test_top.e0.a0.s0@@seq [SEQ] Done generation of 5 items
# KERNEL: UVM_INFO /home/build/vlib1/vlib/uvm-1.2/src/base/uvm_objection.svh(1271) @ 630: reporter [TEST_DONE] 'run' phase is ready to proceed to the 'extract' phase
# KERNEL: UVM_INFO /home/build/vlib1/vlib/uvm-1.2/src/base/uvm_report_server.svh(869) @ 630: reporter [UVM/REPORT/SERVER] 
# KERNEL: --- UVM Report Summary ---
# KERNEL: 
# KERNEL: ** Report counts by severity
# KERNEL: UVM_INFO :   29
# KERNEL: UVM_WARNING :    0
# KERNEL: UVM_ERROR :    0
# KERNEL: UVM_FATAL :    0
# KERNEL: ** Report counts by id
# KERNEL: [AGENT]     1
# KERNEL: [DRV]     8
# KERNEL: [Monitor]     5
# KERNEL: [RNTST]     1
# KERNEL: [SEQ]     7
# KERNEL: [TEST_DONE]     1
# KERNEL: [UVM/RELNOTES]     1
# KERNEL: [scoreboard]     5
# KERNEL: 
# RUNTIME: Info: RUNTIME_0068 uvm_root.svh (521): $finish called.
# KERNEL: Time: 630 ns,  Iteration: 57,  Instance: /tb,  Process: @INITIAL#409_1@.
# KERNEL: stopped at time: 630 ns
# VSIM: Simulation has finished. There are no more test vectors to simulate.
# VSIM: Simulation has finished.
Done
*/
