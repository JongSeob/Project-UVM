`include "my_env.sv"

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
        vif.rstn <= 0;
        @(posedge vif.clk) vif.rstn <= 1;
        @ (posedge vif.clk);
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