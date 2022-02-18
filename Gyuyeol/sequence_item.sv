// Declare a sequence_item for the APB transaction 
class bus_pkt extends uvm_sequence_item;
    rand bit [31:0]  addr;
    rand bit [31:0]  wdata;
         bit [31:0]  rdata;
    rand bit         write;

    `uvm_object_utils_begin (bus_pkt)
        `uvm_field_int (addr, UVM_ALL_ON)
  		`uvm_field_int (wdata, UVM_ALL_ON)
  		`uvm_field_int (rdata, UVM_ALL_ON)
        `uvm_field_int (write, UVM_ALL_ON)
    `uvm_object_utils_end

    function new (string name = "bus_pkt");
        super.new (name);
    endfunction
    
    constraint c_addr { addr inside {0, 1, 2};}
endclass