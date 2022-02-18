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
          `uvm_fatal(get_type_name(), {"Virtual interface must be set for: ", get_full_name(), ".bus_if"})
    endfunction

    virtual task run_phase (uvm_phase phase);
        fork
            forever begin
                @(posedge vif.clk);
                if (vif.psel & vif.penable & vif.rstn) begin
                    bus_pkt pkt = bus_pkt::type_id::create ("pkt");
                    pkt.addr = vif.paddr;
                    if (vif.pwrite)
                        pkt.wdata = vif.pwdata;
                    else
                        pkt.rdata = vif.prdata;
                    pkt.write = vif.pwrite;
                    mon_ap.write (pkt);
                end 
            end
        join_none
    endtask
endclass