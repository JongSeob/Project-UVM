// Code your design here

module traffic (
  input			pclk,
  input			presetn,
  input [31:0]	paddr,
  input [31:0]	pwdata,
  input			psel,
  input			pwrite,
  input			penable,
  
  output [31:0]	prdata
);
  
  reg [3:0]		ctl_reg;
  reg [1:0]		stat_reg;
  reg [31:0]	timer_0;
  reg [31:0]	timer_1;
  
  reg [31:0]	data_in;
  reg [31:0]	rdata_tmp;
  
  always @ (posedge pclk) begin
    if(!presetn) begin
      data_in	<=	0;
      ctl_reg	<=	0;
      stat_reg	<=	0;
      timer_0	<=	32'hcafe_1234;
      timer_1	<=	32'hcafe_5678;
    end
  end
  
  always @ (posedge pclk) begin
    if(presetn & psel & penable) begin
      if(pwrite) begin
        case (paddr)
          'h0	: ctl_reg	<=	pwdata;
          'h4	: timer_0	<=	pwdata;
          'h8	: timer_1	<=	pwdata;
          'hc	: stat_reg	<=	pwdata;
        endcase
      end
    end
  end
  
  always @ (penable) begin
    if(psel & !pwrite) begin
      case (paddr)
        'h0	:	rdata_tmp	<=	ctl_reg;
        'h4 :	rdata_tmp	<=	timer_0;
        'h8 :	rdata_tmp	<=	timer_1;
        'hc :	rdata_tmp	<=	stat_reg;
      endcase
    end
  end
  
  assign prdata = (psel & penable & !pwrite) ? rdata_tmp : 'hz;
  
endmodule
