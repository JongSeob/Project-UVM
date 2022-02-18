`include "adapter.sv"
//`include "reg_model.sv"

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
        m_adapter        = reg2apb_adapter::type_id::create ("m_adapter");
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