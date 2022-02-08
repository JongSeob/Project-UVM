`ifndef APB_UVCS_SV
`define APB_UVCS_SV

`include "uvm_macros.svh"

import uvm_pkg::*;

typedef class apb_seq_item;
typedef class apb_driver;
typedef class apb_monitor;
typedef class apb_agent;

// Declare a sequence_item for the APB transaction 
class apb_seq_item extends uvm_sequence_item;
    rand bit [31:0]  addr;
    rand bit [31:0]  data;
    rand bit         write;

    `uvm_object_utils_begin (apb_seq_item)
        `uvm_field_int (addr,  UVM_ALL_ON)
        `uvm_field_int (data,  UVM_ALL_ON)
        `uvm_field_int (write, UVM_ALL_ON)
    `uvm_object_utils_end

    function new (string name = "apb_seq_item");
        super.new (name);
    endfunction
    
    constraint c_addr { addr[1:0] == 2'b00 }
endclass
  
// Drives a given apb transaction packet to the APB interface
class apb_driver extends uvm_driver #(apb_seq_item);
    `uvm_component_utils (apb_driver)

    apb_seq_item pkt;

    virtual apb_if vif;

    function new (string name = "apb_driver", uvm_component parent);
        super.new (name, parent);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        if (! uvm_config_db#(virtual apb_if)::get (this, "", "apb_if", vif))
            `uvm_error (get_type_name(), "Did not get bus if handle")
    endfunction

    virtual task run_phase (uvm_phase phase);
        bit [31:0] rdata;

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
                read (pkt.addr, rdata);
                pkt.data = rdata;
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
endclass: apb_driver

// Monitors the APB interface for any activity and reports out
// through an analysis port
class apb_monitor extends uvm_monitor;
    `uvm_component_utils (apb_monitor)
    function new (string name="apb_monitor", uvm_component parent);
        super.new (name, parent);
    endfunction

    uvm_analysis_port #(apb_seq_item) mon_ap;

    virtual apb_if vif;

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        mon_ap = new ("mon_ap", this);
        if (! uvm_config_db#(virtual apb_if)::get (this, "", "apb_if", vif))
            `uvm_error (get_type_name(), "Did not get bus if handle")
    endfunction
    
    virtual task run_phase (uvm_phase phase);
        fork
            forever begin
                @(posedge vif.pclk);
                if(vif.presetn == 1'b1) begin
                    if (vif.psel & vif.penable) begin
                        apb_seq_item pkt = apb_seq_item::type_id::create ("pkt");
                        pkt.addr = vif.paddr;
                        if (vif.pwrite)
                            pkt.data = vif.pwdata;
                        else
                            pkt.data = vif.prdata;
                        pkt.write = vif.pwrite;
                        mon_ap.write (pkt);
                    end 
                end
            end
        join_none
    endtask
endclass: apb_monitor

// The agent puts together the driver, sequencer and monitor
class apb_agent extends uvm_agent;
    `uvm_component_utils (apb_agent)
    function new (string name="apb_agent", uvm_component parent);
        super.new (name, parent);
    endfunction

    apb_driver  m_drv;
    apb_monitor m_mon;

    uvm_sequencer #(apb_seq_item) m_seqr; 

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        m_drv  = apb_driver::type_id::create ("m_drv", this);
        m_seqr = uvm_sequencer#(apb_seq_item)::type_id::create ("m_seqr", this);
        m_mon  = apb_monitor::type_id::create ("m_mon", this);
    endfunction

    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase (phase);
        m_drv.seq_item_port.connect (m_seqr.seq_item_export);
    endfunction
endclass: apb_agent

`endif
