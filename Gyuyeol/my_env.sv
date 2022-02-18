`include "my_agent.sv"
`include "reg_env.sv"
`include "my_scoreboard.sv"

class my_env extends uvm_env;
    `uvm_component_utils (my_env)
    
    my_agent         m_agent;    
  	my_scoreboard    m_scb;
    reg_env          m_reg_env;
    

    function new (string name = "my_env", uvm_component parent);
        super.new (name, parent);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase (phase);
        m_agent   = my_agent::type_id::create ("m_agent", this);
        m_reg_env = reg_env::type_id::create ("m_reg_env", this);
        m_scb     = my_scoreboard::type_id::create("m_scb", this);
        uvm_reg::include_coverage ("*", UVM_CVR_ALL);
    endfunction

    // m_agent.m_mon       -> m_reg_env.m_predictor
    // m_agent.m_mon       -> m_reg_env.m_scb
    // m_reg_env.m_adapter -> m_agent.m_seqr
    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase (phase);
        m_agent.m_mon.mon_ap.connect(m_reg_env.m_predictor.bus_in);
        m_agent.m_mon.mon_ap.connect(m_scb.m_analysis_imp);
        m_reg_env.m_reg_model.default_map.set_sequencer(m_agent.m_seqr, m_reg_env.m_adapter);
    endfunction
endclass