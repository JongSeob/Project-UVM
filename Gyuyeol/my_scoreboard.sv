

class my_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(my_scoreboard)

    // new - constructor
    function new (string name = "my_scoreboard", uvm_component parent = null);
        super.new(name,parent);
    endfunction:new

  bus_pkt item[10];

    // Declaring port
    uvm_analysis_imp#(bus_pkt,my_scoreboard) m_analysis_imp;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_analysis_imp = new("m_analysis_imp",this);
    endfunction: build_phase

    virtual function write(bus_pkt pkt);
        if(pkt.write) begin
            item[pkt.addr] = pkt;
            `uvm_info(get_type_name(), $sformatf("Store addr=0x%0h wr=0x%0h data=0x%0h", pkt.addr, pkt.write, pkt.wdata), UVM_LOW)
        end
        if(!pkt.write) begin
           if(pkt.rdata != item[pkt.addr].wdata) begin 
              `uvm_error(get_type_name(), $sformatf("addr=0x%0h exp=0x%0h act=0x%0h", pkt.addr, item[pkt.addr].wdata, pkt.rdata))
           end
           else begin
              `uvm_info(get_type_name(), $sformatf("PASS! addr=0x%0h exp=0x%0h act=0x%0h", pkt.addr, item[pkt.addr].wdata, pkt.rdata), UVM_LOW)
           end
        end
    endfunction
endclass