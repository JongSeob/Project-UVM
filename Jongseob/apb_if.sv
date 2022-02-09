`ifndef APB_IF_SV
`define APB_IF_SV

interface apb_if (input pclk);
    logic [31:0]    paddr;
    logic [31:0]    pwdata;
    logic [31:0]    prdata;
    logic           pwrite;
    logic           psel;
    logic           penable;
    logic           presetn;

    modport MST (
        input  prdata,
        output paddr, pwdata, pwrite, psel, penable, presetn, 
    );
    modport SLV (
        input  paddr, pwdata, pwrite, psel, penable, presetn,
        output prdata
    );
endinterface

`endif // APB_IF_SV
