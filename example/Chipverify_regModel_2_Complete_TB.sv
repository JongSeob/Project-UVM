`include "uvm_macros.svh"
`include "traffic_uvc.sv"
`include "bus_if.sv"
`include "traffic.sv"

import uvm_pkg::*;

module tb;
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);
    end

    bit pclk;
    always #5 pclk = ~pclk;

    wire         w_presetn;
    wire [31:0]  w_paddr;
    wire [31:0]  w_pwdata;
    wire         w_psel;
    wire         w_pwrite;
    wire         w_penable;
    wire [31:0]  w_prdata;

    traffic dut(
        .pclk    ( pclk                ),
        .presetn ( bus_if_inst.presetn ),
        .paddr   ( bus_if_inst.paddr   ),
        .pwdata  ( bus_if_inst.pwdata  ),
        .psel    ( bus_if_inst.psel    ),
        .pwrite  ( bus_if_inst.pwrite  ),
        .penable ( bus_if_inst.penable ),
        .prdata  ( bus_if_inst.prdata  )
    );
  
    bus_if bus_if_inst (
        .pclk (pclk)
    );
  
    initial begin
        uvm_config_db #(virtual bus_if)::set(null, "uvm_test_top.*", "bus_if", bus_if_inst);
        run_test("reg_rw_test");
    end
endmodule
