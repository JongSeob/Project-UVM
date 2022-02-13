`ifndef UART_UVC_SV
`define UART_UVC_SV

`include "uvm_macro.svh"

import uvm_pkg::*;

typedef class scr;

// register address
// RBR = 3'h0, THR = 3'h0, DLL = 3'h0, IER = 3'h1, DLM = 3'h1, IIR = 3'h2,
// FCR = 3'h2, LCR = 3'h3, MCR = 3'h4, LSR = 3'h5, MSR = 3'h6, SCR = 3'h7;

//// addr : 0 , RW
//class rbr_thr_dll extends uvm_reg; 
//// addr : 1 , RW
//class ier_dlm extends uvm_reg; 
//// addr : 2 , RW
//class iir_fcr extends uvm_reg; 
//// addr : 3 , RW
//class lcr extends uvm_reg; 
//// addr : 4 , RW
//class mcr extends uvm_reg; 
//// addr : 5 , RO
//class lsr extends uvm_reg; 
//// addr : 6 , RW
//class msr extends uvm_reg; 
//// addr : 7 , RW
//class scr extends uvm_reg; 

// addr : 3 , RW
class cfg_lcr extends uvm_reg;
    rand uvm_reg_field bits;
    rand uvm_reg_field stop_bits;
    rand uvm_reg_field parity_en;
    rand uvm_reg_field dll; // Divisor Latch Access Bit (DLAB)

    `uvm_object_utils(cfg_lcr)

    function new(string name="cfg_lcr");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
    endfunction: new

    // Build all register field objects
    virtual function void build();
        this.bits = uvm_reg_field::type_id::create("bits", , get_full_name());
        this.stop_bits = uvm_reg_field::type_id::create("stop_bits", , get_full_name());
        this.parity_en = uvm_reg_field::type_id::create("parity_en", , get_full_name());
        this.dll = uvm_reg_field::type_id::create("dll", , get_full_name());

        //        configure (parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible); 
        this.bits.configure      (this, 2, 0, "RW", 0, 2'h0, 1, 0, 1);
        this.stop_bits.configure (this, 1, 2, "RW", 0, 2'h0, 1, 0, 1);
        this.parity_en.configure (this, 1, 3, "RW", 0, 2'h0, 1, 0, 1);
        this.dll.configure       (this, 1, 7, "RW", 0, 2'h0, 1, 0, 1);
    endfunction
endclass

// These registers are grouped together to form a register block called "cfg"
class block_cfg extends uvm_reg_block;
    rand cfg_lcr lcr; // RW
    // ... TODO

    `uvm_object_utils(block_cfg)

    function new(string name = "block_cfg");
        super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction

    virtual function void build();
        //create_map(string name, uvm_reg_addr_t base_addr, int unsigned n_bytes, uvm_endianness_e endian, bit byte_addressing = 1)
        this.default_map = create_map("",0,4,UVM_LITTLE_ENDIAN,0);

        // lcr
        this.lcr = cfg_lcr::type_id::create("lcr",,get_full_name());
        this.lcr.configure(this , null , "regs_q[3]");
        this.lcr.build();
        this.default_map.add_reg(this.lcr, `UVM_REG_ADDR_WIDTH'h0, "RW", 0);

        // .... TODO

    endfunction
endclass

// The register block is placed in the top level model class definition
class reg_model extends uvm_reg_block;
    rand block_cfg cfg;

    `uvm_object_utils(reg_model)
    function new(string name = "reg_model");
        super.new(name);
    endfunction

    function void build();
        this.default_map = create_map("", 0, 4, UVM_LITTLE_ENDIAN, 0);
        this.cfg = block_cfg::type_id::create("cfg",,get_full_name());
        //                 parent , hdl_path
        this.cfg.configure(this   , "tb.dut");
        this.cfg.build();
        this.default_map.add_submap(this.cfg.default_map, `UVM_REG_ADDR_WIDTH'h0);

        add_hdl_path(""); // <- ??
    endfunction
endclass


class reg2apb_adapter extends uvm_reg_adapter;
    `uvm_object_utils (reg2apb_adapter)

    function new (string name = "reg2apb_adapter");
        super.new(name);
    endfunction

    virtual function uvm_sequence_item reg2bus (const ref uvm_reg_bus_op rw);
        bus_pkt pkt = bus_pkt::type_id::create("pkt");
        pkt.write = (rw.kind == UVM_WRITE) ? 1 : 0;
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

    reg_model                    m_reg_model; // Register model
    reg2apb_adapter              m_adapter;   // Convert reg tx <-> bus-type packets
    uvm_reg_predictor #(bus_pkt) m_predictor; // Map APB tx to register in model

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        m_reg_model      = reg_model::type_id::create ("m_reg_model", this);
        m_adapter        = reg2apb_adapter::type_id::create ("m_adapter"); // <- ??
        m_predictor      = uvm_reg_predictor #(bus_pkt)::type_id::create ("m_predictor", this);

        m_reg_model.build();
        m_reg_model.lock_model();
        uvm_config_db #(reg_model)::set (null, "uvm_test_top", "m_reg_model", m_reg_model);
    endfunction

    // defulat_map ->  predictor.map
    // adapter     ->  predictor.adapter
    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase (phase);
        m_predictor.map     = m_reg_model.default_map;
        m_predictor.adapter = m_adapter;
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
    
    constraint c_addr { addr inside {0, 1, 2};}
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
        if(!uvm_config_db #(virtual bus_if)::get (null, "uvm_test_top.*", "bus_if", vif))
         `uvm_fatal("virtual interface must be set for: ",get_full_name(),".bus_if"});
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
        // Connect: sequencer -> driver (TLM port)
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

    // m_agent.m_mon       <-> m_reg_env.m_predictor
    // m_reg_env.m_adapter  -> m_agent.m_seqr
    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase (phase);
        m_agent.m_mon.mon_ap.connect (m_reg_env.m_predictor.bus_in);
        m_reg_env.m_reg_model.default_map.set_sequencer(m_agent.m_seqr, m_reg_env.m_adapter);
    endfunction
    
endclass

