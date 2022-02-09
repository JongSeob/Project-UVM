`ifndef TEST_UVCS_SV
`define TEST_UVCS_SV

`include "uvm_macros.svh"
`include "apb_if.sv"
`include "apb_uvcs.sv"

import uvm_pkg::*;

typedef class bus_pkt;
typedef class ral_cfg_temp;
typedef class ral_sys_traffic;
typedef class reg2apb_adapter;
typedef class reg_env;
typedef class my_env;
typedef class reset_seq;
typedef class apb_write_seq;
typedef class base_test;
typedef class predictor_collision_test;

class ral_cfg_temp extends uvm_reg;
    uvm_reg_field data_32;
    uvm_reg_field data_16;

    `uvm_object_utils(ral_cfg_temp)
    function new(string name = "ral_cfg_temp");
        super.new(name, 48, build_coverage(UVM_NO_COVERAGE));
    endfunction

    virtual function void build();
        this.data_32 = uvm_reg_field::type_id::create("data_32", ,get_full_name());
        this.data_16 = uvm_reg_field::type_id::create("data_16", ,get_full_name());

        // configure(parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible); 
        this.data_32.configure(this, 32,  0, "RW", 0, 32'hCAFE1234, 1, 0, 1);

        this.data_16.configure(this, 16, 32, "RW", 0, 16'hFFFF    , 1, 0, 1);
    endfunction
endclass

// The register block is placed in the top level model class definition
class ral_sys_traffic extends uvm_reg_block;
    `uvm_object_utils(ral_sys_traffic)

    rand ral_cfg_temp   temp;// RW

    function new(string name = "ral_sys_traffic");
        super.new(name);
    endfunction

    function void build();
        this.default_map = create_map(
            .name            ("default_map"    ),
            .base_addr       ('h0              ),
            .n_bytes         (4                ), // connected bus data width
            .endian          (UVM_LITTLE_ENDIAN),
            .byte_addressing (1                )
        );

        this.temp = ral_cfg_temp::type_id::create("temp", ,get_full_name());
        //                 parent, regfile_parent, hdl_path
        this.temp.configure(this, null, "temp_reg");
        this.temp.build();

        //                        rg,                offset,        rights
        this.default_map.add_reg(this.temp, `UVM_REG_ADDR_WIDTH'h0, "RW");

        add_hdl_path("tb.dut");
    endfunction
endclass

  
class reg2apb_adapter extends uvm_reg_adapter;
    `uvm_object_utils (reg2apb_adapter)

    function new (string name = "reg2apb_adapter");
        super.new (name);
    endfunction

    virtual function uvm_sequence_item reg2bus (const ref uvm_reg_bus_op rw);
        bus_pkt pkt = bus_pkt::type_id::create ("pkt");
        pkt.write = (rw.kind == UVM_WRITE) ? 1: 0;
        pkt.addr  = rw.addr;
        pkt.data  = rw.data;
      `uvm_info (get_type_name(), $sformatf ("reg2bus addr=0x%0h data=0x%0h kind=%s", pkt.addr, pkt.data, rw.kind.name), UVM_DEBUG) 
        return pkt; 
    endfunction

    virtual function void bus2reg (uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        bus_pkt pkt;
        if (! $cast (pkt, bus_item)) begin
            `uvm_fatal ("reg2apb_adapter", "Failed to cast bus_item to pkt")
        end
    
        rw.kind = pkt.write ? UVM_WRITE : UVM_READ;
        rw.addr = pkt.addr;
        rw.data = pkt.data;
        `uvm_info (get_type_name(), $sformatf("bus2reg : addr=0x%0h data=0x%0h kind=%s status=%s", rw.addr, rw.data, rw.kind.name(), rw.status.name()), UVM_DEBUG)
    endfunction
endclass

// Register environment class puts together the model, adapter and the predictor
class reg_env extends uvm_env;
    `uvm_component_utils (reg_env)
    function new (string name="reg_env", uvm_component parent);
        super.new (name, parent);
    endfunction

    ral_sys_traffic                 m_ral_model;         // Register Model
    reg2apb_adapter                 m_reg2apb;           // Convert Reg Tx <-> Bus-type packets
    uvm_reg_predictor #(bus_pkt)    m_apb2reg_predictor; // Map APB tx to register in model

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        m_ral_model         = ral_sys_traffic::type_id::create ("m_ral_model", this);
        m_reg2apb           = reg2apb_adapter::type_id::create ("m_reg2apb");
        m_apb2reg_predictor = uvm_reg_predictor #(bus_pkt)::type_id::create ("m_apb2reg_predictor", this);

        m_ral_model.build ();
        m_ral_model.lock_model ();
        uvm_config_db #(ral_sys_traffic)::set (null, "uvm_test_top", "m_ral_model", m_ral_model);
    endfunction

    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase (phase);
        m_apb2reg_predictor.map     = m_ral_model.default_map;
        m_apb2reg_predictor.adapter = m_reg2apb;
    endfunction    
endclass

  
// Declare a sequence_item for the APB transaction 
class bus_pkt extends uvm_sequence_item;
    rand bit [31:0]  addr;
    rand bit [31:0]  data;
    rand bit         write;

    `uvm_object_utils_begin (bus_pkt)
        `uvm_field_int (addr, UVM_ALL_ON)
        `uvm_field_int (data, UVM_ALL_ON)
        `uvm_field_int (write, UVM_ALL_ON)
    `uvm_object_utils_end

    function new (string name = "bus_pkt");
        super.new (name);
    endfunction
    
    //constraint c_addr { addr inside {0, 4, 8};}
    constraint c_addr { 
        addr[1:0] == 2'b00;
    }
endclass

class my_env extends uvm_env;
    `uvm_component_utils (my_env)
    
    my_agent         m_agent;
    my_agent         m_agent2;
    reg_env          m_reg_env;
    
    function new (string name = "my_env", uvm_component parent);
        super.new (name, parent);
    endfunction
    
    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        m_agent   = my_agent::type_id::create ("m_agent", this);
        m_agent2  = my_agent::type_id::create ("m_agent2", this);
        m_reg_env = reg_env::type_id::create ("m_reg_env", this);
        uvm_reg::include_coverage ("*", UVM_CVR_ALL);

        uvm_config_db#(my_agent)::set(null, "uvm_test_top", "m_agent2", m_agent2);
    endfunction

    // Connect analysis port of monitor with predictor, assign agent to register env
    // and set default map of the register env
    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase (phase);
        m_agent.m_mon.mon_ap.connect (m_reg_env.m_apb2reg_predictor.bus_in);
        m_reg_env.m_ral_model.default_map.set_sequencer(m_agent.m_seqr, m_reg_env.m_reg2apb);
    endfunction
    
endclass
  
class reset_seq extends uvm_sequence;
    `uvm_object_utils (reset_seq)
    function new (string name = "reset_seq");
        super.new (name);
    endfunction

    virtual bus_if vif; 

    task body ();
        if (!uvm_config_db #(virtual bus_if) :: get (null, "uvm_test_top.*", "bus_if", vif)) 
            `uvm_fatal ("VIF", "No vif")

        `uvm_info (get_type_name(), "Running reset ...", UVM_MEDIUM);
        vif.presetn <= 0;
        @(posedge vif.pclk) vif.presetn <= 1;
        @ (posedge vif.pclk);
    endtask
endclass

class apb_write_seq extends uvm_sequence;
    `uvm_object_utils (apb_write_seq)
    bus_pkt pkt;
    int     addr;
    int     data;

    function new (string name = "apb_write_seq");
        super.new (name);
    endfunction

    task body ();
        pkt = bus_pkt::type_id::create("pkt");
        pkt.addr  = this.addr;
        pkt.data  = this.data;
        pkt.write = 1;

        start_item(pkt);
        finish_item(pkt);
    endtask

endclass
  
class base_test extends uvm_test;
    `uvm_component_utils (base_test)

    my_env          m_env;
    reset_seq       m_reset_seq;
    uvm_status_e    status;

    function new (string name = "base_test", uvm_component parent);
        super.new (name, parent);
    endfunction

    // Build the testbench environment, and reset sequence
    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        m_env       = my_env::type_id::create ("m_env", this);
        m_reset_seq = reset_seq::type_id::create ("m_reset_seq", this);
    endfunction
 
    // In the reset phase, apply reset
    virtual task reset_phase (uvm_phase phase);
        super.reset_phase (phase);
        phase.raise_objection (this);
        m_reset_seq.start (m_env.m_agent.m_seqr);
        phase.drop_objection (this);
    endtask
endclass

class predictor_collision_test extends base_test;
    `uvm_component_utils (predictor_collision_test)

    my_agent      m_agent2;
    apb_write_seq m_apb_wr_seq;

    function new (string name="predictor_collision_test", uvm_component parent);
        super.new (name, parent);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        if(!uvm_config_db#(my_agent)::get(this, "", "m_agent2", m_agent2))
            `uvm_fatal(get_type_name(), "m_agent2 obj is necessary for predictor collision test")
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_root::get().print_topology();
    endfunction

    // Note that main_phase comes after reset_phase, and is performed when
    // DUT is out of reset. "reset_phase" is already defined in base_test
    // and is always called when this test is started
    virtual task main_phase(uvm_phase phase);
        ral_sys_traffic    m_ral_model;
        uvm_status_e       status;
        int                rdata;

        phase.raise_objection(this);

        m_env.m_reg_env.set_report_verbosity_level (UVM_HIGH);

        m_apb_wr_seq = apb_write_seq::type_id::create("m_apb_wr_seq");
        

        // Get register model from config_db
        uvm_config_db#(ral_sys_traffic)::get(null, "uvm_test_top", "m_ral_model", m_ral_model);
      
        `uvm_info(get_type_name(), $sformatf("default_map's n_bytes = %0d", m_ral_model.default_map.get_n_bytes()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("default_map's address unit bytes = %0d", m_ral_model.default_map.get_addr_unit_bytes()), UVM_LOW)

        // m_apb_wr_seq.addr = 32'h10;
        // m_apb_wr_seq.data = 32'hAAAA_BBBB;
        // m_apb_wr_seq.start(m_agent2.m_seqr);

        // m_ral_model.cfg.temp.write (status, 48'h1234_5678_9abc);
      m_ral_model.cfg.temp.data_16.write (status, 16'hABCD);
      
        phase.drop_objection(this);
    endtask

    // Before end of simulation, allow some time for unfinished transactions to
    // be over
    virtual task shutdown_phase(uvm_phase phase);
        super.shutdown_phase(phase);
        phase.raise_objection(this);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass

`endif // TEST_UVCS_SV