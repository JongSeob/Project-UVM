`include "uvm_macros.svh"
`include "reg_rw_access_test.sv"
`include "bus_if.sv"

module tb;
    import uvm_pkg::*;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0,tb);
    end
  
    bit clk;

    always #10 clk = ~clk;

    apb_uart_sv dut(
    .CLK     (clk        ), // input  logic                      
    .RSTN    (vif.rstn   ), // input  logic                      
    .PADDR   (vif.paddr  ), // input  logic [APB_ADDR_WIDTH-1:0] 
    .PWDATA  (vif.pwdata ), // input  logic [31:0] 
    .PWRITE  (vif.pwrite ), // input  logic        
    .PSEL    (vif.psel   ), // input  logic        
    .PENABLE (vif.penable), // input  logic        
    .PRDATA  (vif.prdata ), // output logic [31:0] 
    .PREADY  (vif.pready ), // output logic                      
    .PSLVERR (vif.pslverr), // output logic                      
              
    .rx_i    (vif.rx),      // input  logic - Receiver input
    .tx_o    (vif.tx),      // output logic - Transmitter output
            
    .event_o (vif.event_o)  // output logic - interrupt/event output
    );

    bus_if vif (clk);

    initial begin
        uvm_config_db #(virtual bus_if)::set(null, "uvm_test_top.*","bus_if",vif);
        run_test("reg_rw_access_test");
    end
endmodule