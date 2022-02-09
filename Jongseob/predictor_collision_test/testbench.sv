`include "uvm_macros.svh"
`include "test_uvcs.sv"
`include "apb_if.sv"

import uvm_pkg::*;

module tb;
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);
    end

    // generate 10ns period clock
    bit pclk;
    always #5 pclk = ~pclk;

    design dut(
        .pclk    ( pclk                ),
        .presetn ( apb_if_inst.presetn ),
        .paddr   ( apb_if_inst.paddr   ),
        .pwdata  ( apb_if_inst.pwdata  ),
        .psel    ( apb_if_inst.psel    ),
        .pwrite  ( apb_if_inst.pwrite  ),
        .penable ( apb_if_inst.penable ),
        .prdata  ( apb_if_inst.prdata  )
    );
  
    apb_if apb_if_inst (
        .pclk (pclk)
    );
  
    initial begin
        // send virtual interface to apb_monitor
        uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.*", "apb_if", apb_if_inst);
        //run_test("reg_rw_test");
        run_test("predictor_collision_test");
    end
endmodule