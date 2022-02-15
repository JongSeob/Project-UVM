interface bus_if (input bit clk);
    logic        rstn;
    logic [11:0] paddr;
    logic [31:0] pwdata;
    logic        pwrite;
    logic        psel;
    logic        penable;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    logic        rx;
    logic        tx;

    logic        event_o;
endinterface