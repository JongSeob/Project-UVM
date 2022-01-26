`ifndef TRAFFIC_UVC_SV
`define TRAFFIC_UVC_SV

`include "uvm_macros.svh"
`include "bus_if.sv"

import uvm_pkg::*;

typedef class bus_pkt;
typedef class ral_cfg_ctl;
typedef class ral_cfg_stat;
typedef class ral_cfg_timer;
typedef class ral_block_traffic_cfg;
typedef class ral_sys_traffic;
typedef class reg2apb_adapter;
typedef class my_driver;
typedef class my_monitor;
typedef class my_agent;
typedef class reg_env;
typedef class my_env;
typedef class reset_seq;
typedef class base_test;
typedef class reg_rw_test;

// Register definition for the register called "ctl"
class ral_cfg_ctl extends uvm_reg;
    rand uvm_reg_field mod_en;    // Enables the module
    rand uvm_reg_field bl_yellow; // Blinks yellow
    rand uvm_reg_field bl_red;    // Blinks red
    rand uvm_reg_field profile;   // 1 : Peak, 0 : Off-Peak

    `uvm_object_utils(ral_cfg_ctl)

    function new(string name = "traffic_cfg_ctrl");
        // Check if all of the specified coverage model must be built !! (보통 다른 class와 다름)
        //  register 이름 / register 크기 / coverage model 종류
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
        // coverage model 종류
        // UVM_NO_COVERAGE      None
        // UVM_CVR_REG_BITS     Individual register bits
        // UVM_CVR_ADDR_MAP     Individual register and memory addresses
        // UVM_CVR_FIELD_VALS	Field values
        // UVM_CVR_ALL          All coverage models
    endfunction: new

    // Build all register field objects
    virtual function void build();
        //                                              "name"      , parent, context
        this.mod_en    = uvm_reg_field::type_id::create("mod_en"    ,       , get_full_name());
        this.bl_yellow = uvm_reg_field::type_id::create("bl_yellow" ,       , get_full_name());
        this.bl_red    = uvm_reg_field::type_id::create("bl_red"    ,       , get_full_name());
        this.profile   = uvm_reg_field::type_id::create("profile"   ,       , get_full_name());
        // [Q] this.profile   = uvm_reg_field::type_id::create("profile"); 로 해도 되는데 뒤에 get_full_name은 왜 있는건지?

        // configure(parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible); 
        this.mod_en.configure    ( this, 1, 0, "RW", 0, 1'h0, 1, 0, 0 );
        this.bl_yellow.configure ( this, 1, 1, "RW", 0, 1'h0, 1, 0, 0 );
        this.bl_red.configure    ( this, 1, 2, "RW", 0, 1'h0, 1, 0, 0 );
        this.profile.configure   ( this, 1, 3, "RW", 0, 1'h0, 1, 0, 0 );
    endfunction
endclass 

// Register definition for the register called "stat"
class ral_cfg_stat extends uvm_reg;
    uvm_reg_field state;     // Current state of the design
    
    `uvm_object_utils(ral_cfg_stat)
    function new(string name = "ral_cfg_stat");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
    endfunction
    
    virtual function void build();
        this.state = uvm_reg_field::type_id::create("state",, get_full_name());
    
        // configure(parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible); 
        this.state.configure(this, 2, 0, "RO", 0, 1'h0, 0, 0, 0);
    endfunction
endclass

// Register definition for the register called "timer"
class ral_cfg_timer extends uvm_reg;
    uvm_reg_field timer;      // Time for which it blinks

    `uvm_object_utils(ral_cfg_timer)
    function new(string name = "traffic_cfg_timer");
        super.new(name, 32,build_coverage(UVM_NO_COVERAGE));
    endfunction

    virtual function void build();
        this.timer = uvm_reg_field::type_id::create("timer",,get_full_name());

        // configure(parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible); 
        this.timer.configure(this, 32, 0, "RW", 0, 32'hCAFE1234, 1, 0, 1);
        this.timer.set_reset('h0, "SOFT");
    endfunction
endclass

// These registers are grouped together to form a register block called "cfg"
class ral_block_traffic_cfg extends uvm_reg_block;
    rand ral_cfg_ctl    ctrl;     // RW
    rand ral_cfg_timer  timer[2]; // RW
         ral_cfg_stat   stat;     // RO

    `uvm_object_utils(ral_block_traffic_cfg)

    function new(string name = "traffic_cfg");
        super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction

    virtual function void build();
        this.default_map = create_map("", 0, 4, UVM_LITTLE_ENDIAN, 0);
        this.ctrl = ral_cfg_ctl::type_id::create("ctrl",,get_full_name());
        this.ctrl.configure(this, null, "");
        this.ctrl.build();
        this.default_map.add_reg(this.ctrl, `UVM_REG_ADDR_WIDTH'h0, "RW", 0);
        
         
        this.timer[0] = ral_cfg_timer::type_id::create("timer[0]",,get_full_name());
        this.timer[0].configure(this, null, "");
        this.timer[0].build();
        this.default_map.add_reg(this.timer[0], `UVM_REG_ADDR_WIDTH'h4, "RW", 0);
        
        this.timer[1] = ral_cfg_timer::type_id::create("timer[1]",,get_full_name());
        this.timer[1].configure(this, null, "");
        this.timer[1].build();
        this.default_map.add_reg(this.timer[1], `UVM_REG_ADDR_WIDTH'h8, "RW", 0);
        
        this.stat = ral_cfg_stat::type_id::create("stat",,get_full_name());
        this.stat.configure(this, null, "");
        this.stat.build();
        this.default_map.add_reg(this.stat, `UVM_REG_ADDR_WIDTH'hc, "RO", 0);
    endfunction 
endclass 

// The register block is placed in the top level model class definition
class ral_sys_traffic extends uvm_reg_block;
    rand ral_block_traffic_cfg cfg;

    `uvm_object_utils(ral_sys_traffic)
    function new(string name = "traffic");
        super.new(name);
    endfunction

    function void build();
        this.default_map = create_map("", 0, 4, UVM_LITTLE_ENDIAN, 0);
        this.cfg = ral_block_traffic_cfg::type_id::create("cfg",,get_full_name());
        this.cfg.configure(this, "tb_top.pB0");
        this.cfg.build();
        this.default_map.add_submap(this.cfg.default_map, `UVM_REG_ADDR_WIDTH'h0);
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
        `uvm_info ("adapter", $sformatf ("reg2bus addr=0x%0h data=0x%0h kind=%s", pkt.addr, pkt.data, rw.kind.name), UVM_DEBUG) 
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
        `uvm_info ("adapter", $sformatf("bus2reg : addr=0x%0h data=0x%0h kind=%s status=%s", rw.addr, rw.data, rw.kind.name(), rw.status.name()), UVM_DEBUG)
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
    my_agent                        m_agent;             // Agent to drive/monitor transactions

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
    
    constraint c_addr { addr inside {0, 4, 8};}
endclass

// Drives a given apb transaction packet to the APB interface
class my_driver extends uvm_driver #(bus_pkt);
    `uvm_component_utils (my_driver)

    bus_pkt        pkt;

    virtual bus_if vif;

    function new (string name = "my_driver", uvm_component parent);
        super.new (name, parent);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        if (! uvm_config_db#(virtual bus_if)::get (this, "*", "bus_if", vif))
            `uvm_error ("DRVR", "Did not get bus if handle")
    endfunction

    virtual task run_phase (uvm_phase phase);
        bit [31:0] data;

        vif.psel    <= 0;
        vif.penable <= 0;
        vif.pwrite  <= 0;
        vif.paddr   <= 0;
        vif.pwdata  <= 0;
        forever begin
            seq_item_port.get_next_item (pkt);
            if (pkt.write)
                write (pkt.addr, pkt.data);
            else begin
                read (pkt.addr, data);
                pkt.data = data;
            end
            seq_item_port.item_done ();
        end
    endtask

    virtual task read (  input bit    [31:0] addr, 
                         output logic [31:0] data);
        vif.paddr   <= addr;
        vif.pwrite  <= 0;
        vif.psel    <= 1;
        @(posedge vif.pclk);
        vif.penable <= 1;
        @(posedge vif.pclk);
        data         = vif.prdata;
        vif.psel    <= 0;
        vif.penable <= 0;
    endtask

    virtual task write ( input bit [31:0] addr,
                         input bit [31:0] data);
        vif.paddr   <= addr;
        vif.pwdata  <= data;
        vif.pwrite  <= 1;
        vif.psel    <= 1;
        @(posedge vif.pclk);
        vif.penable <= 1;
        @(posedge vif.pclk);
        vif.psel    <= 0;
        vif.penable <= 0;
    endtask
endclass

// Monitors the APB interface for any activity and reports out
// through an analysis port
class my_monitor extends uvm_monitor;
    `uvm_component_utils (my_monitor)
    function new (string name="my_monitor", uvm_component parent);
        super.new (name, parent);
    endfunction

    uvm_analysis_port #(bus_pkt)  mon_ap;
    virtual bus_if                vif;

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        mon_ap = new ("mon_ap", this);
        uvm_config_db #(virtual bus_if)::get (null, "uvm_test_top.*", "bus_if", vif);
    endfunction
    
    virtual task run_phase (uvm_phase phase);
        fork
            forever begin
                @(posedge vif.pclk);
                if (vif.psel & vif.penable & vif.presetn) begin
                    bus_pkt pkt = bus_pkt::type_id::create ("pkt");
                    pkt.addr = vif.paddr;
                    if (vif.pwrite)
                        pkt.data = vif.pwdata;
                    else
                        pkt.data = vif.prdata;
                    pkt.write = vif.pwrite;
                    mon_ap.write (pkt);
                end 
            end
        join_none
    endtask
endclass

// The agent puts together the driver, sequencer and monitor
class my_agent extends uvm_agent;
    `uvm_component_utils (my_agent)
    function new (string name="my_agent", uvm_component parent);
        super.new (name, parent);
    endfunction

    my_driver                   m_drvr;
    my_monitor                  m_mon;
    uvm_sequencer #(bus_pkt)    m_seqr; 

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        m_drvr = my_driver::type_id::create ("m_drvr", this);
        m_seqr = uvm_sequencer#(bus_pkt)::type_id::create ("m_seqr", this);
        m_mon  = my_monitor::type_id::create ("m_mon", this);
    endfunction

    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase (phase);
        m_drvr.seq_item_port.connect (m_seqr.seq_item_export);
    endfunction
endclass

  
class my_env extends uvm_env;
    `uvm_component_utils (my_env)
    
    my_agent         m_agent;    
    reg_env          m_reg_env;
    
    function new (string name = "my_env", uvm_component parent);
        super.new (name, parent);
    endfunction
    
    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        m_agent   = my_agent::type_id::create ("m_agent", this);
        m_reg_env = reg_env::type_id::create ("m_reg_env", this);
        uvm_reg::include_coverage ("*", UVM_CVR_ALL);
    endfunction

    // Connect analysis port of monitor with predictor, assign agent to register env
    // and set default map of the register env
    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase (phase);
        m_reg_env.m_agent = m_agent;
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

        `uvm_info ("RESET", "Running reset ...", UVM_MEDIUM);
        vif.presetn <= 0;
        @(posedge vif.pclk) vif.presetn <= 1;
        @ (posedge vif.pclk);
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

class reg_rw_test extends base_test;
    `uvm_component_utils (reg_rw_test)
    function new (string name="reg_rw_test", uvm_component parent);
        super.new (name, parent);
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
        
        // Get register model from config_db
        uvm_config_db#(ral_sys_traffic)::get(null, "uvm_test_top", "m_ral_model", m_ral_model);
        
        // Write 0xcafe_feed to the timer[1] register, and read it back
        m_ral_model.cfg.timer[1].write (status, 32'hcafe_feed);
        m_ral_model.cfg.timer[1].read (status, rdata);
        
        // Set 0xface as the desired value for timer[1] register
        m_ral_model.cfg.timer[1].set(32'hface);
        `uvm_info(get_type_name(), $sformatf("desired=0x%0h mirrored=0x%0h", m_ral_model.cfg.timer[1].get(), m_ral_model.cfg.timer[1].get_mirrored_value()), UVM_MEDIUM)
        
        // Predict that current value of timer[1] is 0xcafe_feed and check it is true
        m_ral_model.cfg.timer[1].predict(32'hcafe_feed);
        m_ral_model.cfg.timer[1].mirror(status, UVM_CHECK);
        
        // Set desired value of the field "bl_yellow" in register ctrl to 1
        // Then start bus transactions by calling "update" to update DUT with 
        // desired value
        m_ral_model.cfg.ctrl.bl_yellow.set(1);
        m_ral_model.cfg.update(status);

        // Attempt to write into a RO register "stat" with some value
        m_ral_model.cfg.stat.write(status, 32'h12345678);
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

`endif
