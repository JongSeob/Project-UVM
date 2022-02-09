module design (  
    input          pclk,
    input          presetn,
    input [31:0]   paddr,
    input [31:0]   pwdata,
    input          psel,
    input          pwrite,
    input          penable,

    // Outputs
    output [31:0]  prdata
);

    reg [31:0]      rdata_tmp;

    reg [47:0]      temp_reg;


    // Set all registers to default values
    always @ (posedge pclk) begin
        if (!presetn) begin
            temp_reg <= 48'h0000_0000_0000;
        end
    end

    // Capture write data
    always @ (posedge pclk) begin
        if (presetn & psel & penable) 
            if (pwrite) 
                case (paddr)
                    'h0 : temp_reg[31:0]  <= pwdata;
                    'h4 : temp_reg[47:32] <= pwdata[15:0];
                endcase
    end

    // Provide read data
    always @ (penable) begin
        if (psel & !pwrite) 
            case (paddr)
                'h0 : rdata_tmp <= temp_reg[31:0];
                'h4 : rdata_tmp <= temp_reg[47:32];
            endcase
    end

    assign prdata = (psel & penable & !pwrite) ? rdata_tmp : 'hz;

endmodule