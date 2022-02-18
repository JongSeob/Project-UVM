class reg2apb_adapter extends uvm_reg_adapter;
    `uvm_object_utils (reg2apb_adapter)

    function new (string name = "reg2apb_adapter");
        super.new(name);
    endfunction

    virtual function uvm_sequence_item reg2bus (const ref uvm_reg_bus_op rw);
        bus_pkt pkt = bus_pkt::type_id::create("pkt");
        pkt.write = (rw.kind == UVM_WRITE) ? 1 : 0;
        pkt.addr  = rw.addr;
        pkt.wdata = rw.data;
      	`uvm_info ("adapter", $sformatf ("reg2bus addr=0x%0h data=0x%0h kind=%s", pkt.addr, pkt.wdata, rw.kind.name), UVM_HIGH) 
        return pkt; 
    endfunction

    virtual function void bus2reg (uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        bus_pkt pkt;
        if (! $cast (pkt, bus_item)) begin
            `uvm_fatal ("reg2apb_adapter", "Failed to cast bus_item to pkt")
        end
    
        rw.kind = pkt.write ? UVM_WRITE : UVM_READ;
        rw.addr = pkt.addr;
      	if (pkt.write) begin
        	rw.data = pkt.wdata;
        end else begin
      		rw.data = pkt.rdata;
        end
      `uvm_info ("adapter", $sformatf("bus2reg (gyu) : addr=0x%0h data=0x%0h kind=%s status=%s", rw.addr, rw.data, rw.kind.name(), rw.status.name()), UVM_HIGH)
    endfunction

endclass
