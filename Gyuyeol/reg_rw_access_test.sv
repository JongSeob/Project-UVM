
import uvm_pkg::*;

`include "reg_model.sv"
`include "base_test.sv"

class reg_rw_access_test extends base_test;
    `uvm_component_utils (reg_rw_access_test)
    function new (string name="reg_rw_access_test", uvm_component parent);
        super.new (name, parent);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_root::get().print_topology();
    endfunction

    // Note that main_phase comes after reset_phase, and is performed when
    // DUT is out of reset. "reset_phase" is already defined in base_test
    // and is always called when this test is started
    virtual task main_phase(uvm_phase phase);
        reg_model    m_reg_model;
        uvm_status_e status;
        int          rdata;

        phase.raise_objection(this);

        m_env.m_reg_env.set_report_verbosity_level (UVM_HIGH);

        // Get register model from config_db
        uvm_config_db#(reg_model)::get(null, "uvm_test_top", "m_reg_model", m_reg_model);

        // 1. write 'h11
        m_reg_model.cfg.lcr.write (status, 32'h0000_0011);

        // 2. read 
        m_reg_model.cfg.lcr.read  (status, rdata);

        // 3. write 'h8d
        m_reg_model.cfg.lcr.bits.set(1);
        m_reg_model.cfg.lcr.stop_bits.set(1);
        m_reg_model.cfg.lcr.parity_en.set(1);
        m_reg_model.cfg.lcr.dll.set(1);
        m_reg_model.cfg.update(status);

        // 4. read
        m_reg_model.cfg.lcr.read  (status, rdata);

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