module UART_RX (

	input		wire				CLK_50,
	input		wire				nRST,
		
	input		wire				UART_RX,
	output	reg				UART_TX,
		
		
	////////Avalon Slave	////////////
	input		wire	[7:0]		addr,
	input		wire				read,
	input		wire				write,
	input		wire	[7:0]		writedata,
	output	reg	[7:0]		readdata,
	output	reg				IRQ
	////////////////////////////////
);

///////////Avalon
reg	IRQ_CLEAR;


always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		IRQ	<=	1'b0;
	else if(cur_st == STOP)
		IRQ	<=	1'b1;
	else if(IRQ_CLEAR == 1'b1)
		IRQ	<=	1'b0;
	else
		IRQ	<=	IRQ;

end

reg	[7:0]	temp_data;
always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		temp_data	<=	8'd0;
	else if(cur_st	==	STOP)
		temp_data	<=	captured_DATA;
	else
		temp_data	<=	temp_data;
end
always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		readdata	<=	8'd0;
	else begin
		if(write == 1)
		begin
			if(addr == 8'd4)
				IRQ_CLEAR	<=	writedata[0];
		end
		
		if(read == 1)
		begin
			if(addr == 8'd0)
				readdata	<=	temp_data;
		end
	end
end

////////////

wire				uart_sig;
assign			uart_sig	=	UART_RX;
reg				rx_edge0, rx_edge1;
reg				transmitting;
reg				hold;
reg				start_signal;

reg	[8:0]		sample_cnt;
reg	[3:0]		bit_cnt;
reg	[7:0]		captured_DATA;
reg	[9:0]		shift_reg;

reg				frame_end;
reg				UART_out;


reg	[3:0]		cur_st, nxt_st;
//tx
reg			tx_clk;
reg			tx_uart_sig;
reg			ruart_tx;
reg			tx_end;
reg			tx_clk_rise;
reg			tx_hold;
reg	[8:0]	tx_sample_cnt;
reg			tx_transmitting;
reg	[3:0]	tx_cur_st, tx_nxt_st;
//state machine
parameter	IDLE		= 4'd0,
				START		= 4'd1,
				DATA0		= 4'd2,
				DATA1		= 4'd3,
				DATA2		= 4'd4,
				DATA3		= 4'd5,
				DATA4		= 4'd6,
            DATA5		= 4'd7,
				DATA6		= 4'd8,
				DATA7		= 4'd9,
				DATA8		= 4'd10,
				STOP		= 4'd12;
				



//ingrediants to make start signal
always @ (posedge CLK_50, posedge nRST) begin
	if(nRST) begin
		rx_edge0		<=		1'b0;
		rx_edge1		<=		1'b0;
	end
	else begin
		rx_edge0		<=		uart_sig;
		rx_edge1		<=		rx_edge0;
	end
end

//always @(posedge CLK_50, posedge nRST)
//begin
//	if(nRST)
//		uart_sig	<=	1'b1;
//	else
//		uart_sig	<=	UART_RX;
//end
//cooking start signal
always @ (posedge CLK_50, posedge nRST) begin
	if(nRST) begin
		start_signal		<=		1'b0;
	end
	else begin
		if(rx_edge0 == 1'b0 && rx_edge1 == 1'b1)
			start_signal		<=		1'b1;
		else
			start_signal		<=		1'b0;
	end
end

//when bit count changes 9 to 0 => set frame_end 1



//frame for 
always @ (posedge CLK_50, posedge nRST) begin
	if(nRST) begin
		sample_cnt		<=		9'd0;
	end
	else begin
		if(hold == 1'b1 && sample_cnt < 9'd435)
			sample_cnt	<=	sample_cnt + 1'b1;
		else
			sample_cnt	<= 1'b1;
	end
end

always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		hold	<=	1'b0;
	else if(transmitting == 1'b1)
		hold	<=	1'b1;
	else if(frame_end == 1'b1)
		hold	<= 1'b0;
	else
		hold	<=	hold;
end

//heart beat to run state machine
reg	rx_clk;
always @ (*) begin
	if (sample_cnt < 9'd218)
		rx_clk = 1'b1;
	else if (sample_cnt >= 9'd218)
		rx_clk = 1'b0;
end

reg rx_clk_1d, rx_clk_2d;
always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST) begin
		rx_clk_1d <= 1'b0;
		rx_clk_2d <= 1'b0;
	end
	else begin
		rx_clk_1d <= rx_clk;
		rx_clk_2d <= rx_clk_1d;
	end
end


reg	rx_clk_rise;
always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		rx_clk_rise <= 1'b0;
	else if(rx_clk_1d == 1 && rx_clk_2d == 0)
		rx_clk_rise <= 1'b1;
	else
		rx_clk_rise <= 1'b0;
end


always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		cur_st <= 4'd0;
	else
		cur_st <= nxt_st;
end

always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		shift_reg <= 9'd0;
	else if (rx_clk_rise == 1'b1)
		shift_reg <= {shift_reg[8:0], uart_sig};
	else if(tx_start == 1'b1)
		shift_reg	<=	9'd0;
	else
		shift_reg <= shift_reg;
end

always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		captured_DATA <= 8'd0;
	else if(cur_st == STOP)
		captured_DATA <= shift_reg[9:2];
	else if(tx_start == 1'b1)
		captured_DATA	<=	8'd0;
	else
		captured_DATA 	<= captured_DATA;
end
reg	tx_start;
always @ (*) begin //state reset

		frame_end		<= 1'b0;
		transmitting	<= 1'b0;
		tx_start			<=	1'b0;
		case(cur_st)
		
		IDLE	:	
			if(start_signal == 1'b1) begin
				nxt_st			<= START;
				transmitting	<= 1'b1;
			end
			else
				nxt_st <= IDLE;
		START	:
			if(rx_clk_rise == 1)
				nxt_st <= DATA0;
			else
				nxt_st <= START;
		DATA0	:
			if(rx_clk_rise ==1)
				nxt_st <= DATA1;
			else
				nxt_st <= DATA0;
		DATA1	:
			if(rx_clk_rise == 1)
				nxt_st <= DATA2;
			else
				nxt_st <= DATA1;
		DATA2	:
			if(rx_clk_rise == 1)
				nxt_st <= DATA3;
			else
				nxt_st <= DATA2;
		DATA3	:
			if(rx_clk_rise == 1)
				nxt_st <= DATA4;
			else
				nxt_st <= DATA3;
		DATA4	:
			if(rx_clk_rise == 1)
				nxt_st <= DATA5;
			else
				nxt_st <= DATA4;
      DATA5	:
			if(rx_clk_rise == 1)
				nxt_st <= DATA6;
			else
				nxt_st <= DATA5;
		DATA6	:
			if(rx_clk_rise == 1)
				nxt_st <= DATA7;
			else
				nxt_st <= DATA6;
		DATA7	:
			if(rx_clk_rise == 1) begin
				nxt_st <= STOP;
				frame_end	<=	1'b1;
			end
			else
				nxt_st <= DATA7;
		STOP	:
			begin
				nxt_st 	<= IDLE;
				tx_start	<= 1'b1;
			end
				
		default:		nxt_st <= IDLE;
			
		endcase
end

/////////////////////////////////////////////////////////////////////tx
/////////////////////////////////////////////////////////////////////tx
/////////////////////////////////////////////////////////////////////tx
/////////////////////////////////////////////////////////////////////tx/////////////////////////////////////////////////////////////////////tx
/////////////////////////////////////////////////////////////////////tx
always @ (posedge CLK_50, posedge nRST) begin
	if(nRST) begin
		tx_sample_cnt		<=		9'd0;
	end
	else begin
		if(tx_hold == 1'b1 && tx_sample_cnt < 9'd435)
			tx_sample_cnt	<=	tx_sample_cnt + 1'b1;
		else
			tx_sample_cnt	<= 1'b0;
	end
end


always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		tx_hold	<=	1'b0;
	else if(tx_start == 1'b1)
		tx_hold	<=	1'b1;
	else if(tx_end == 1'b1)
		tx_hold	<= 1'b0;
	else
		tx_hold	<=	tx_hold;
end


always @ (*) begin
	if (tx_sample_cnt < 9'd218)
		tx_clk = 1'b1;
	else if (tx_sample_cnt >= 9'd218)
		tx_clk = 1'b0;
end

reg tx_clk_1d, tx_clk_2d;
always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST) begin
		tx_clk_1d <= 1'b1;
		tx_clk_2d <= 1'b1;
	end
	else begin
		tx_clk_1d <= tx_clk;
		tx_clk_2d <= tx_clk_1d;
	end
end



always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		tx_clk_rise <= 1'b0;
	else if(tx_clk_1d == 1 && tx_clk_2d == 0)
		tx_clk_rise <= 1'b1;
	else
		tx_clk_rise <= 1'b0;
end

always @ (posedge CLK_50, posedge nRST)
begin
	UART_TX	<=	tx_uart_sig;
end

always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		tx_uart_sig	<=	1'b1;
	else if(tx_clk_rise == 1'b1)
		tx_uart_sig	<=	ruart_tx;
	else
		tx_uart_sig	<=	tx_uart_sig;
end
always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		tx_cur_st	<=	4'd0;
	else
		tx_cur_st	<=	tx_nxt_st;
end

reg	[7:0]	tmp_tx;
always @ (posedge CLK_50, posedge nRST)
begin
	if(nRST)
		tmp_tx	<=	8'd0;
	else if(tx_start == 1'b1)
		tmp_tx	<=	captured_DATA;
	else if(tx_end == 1'b1)
		tmp_tx	<=	8'd0;
	else
		tmp_tx	<=	tmp_tx;
		
end

always @ (*) begin //state reset

		tx_end				<= 1'b0;
		ruart_tx				<=	1'b1;
		tx_transmitting	<= 1'b0;
		case(tx_cur_st)
		
		IDLE	:	
			if(tx_clk_rise == 1'b1) begin
				tx_nxt_st			<= START;
				tx_transmitting	<= 1'b1;
				ruart_tx				<= 1'b0;
			end
			else
				tx_nxt_st <= IDLE;
		START	:
			if(tx_clk_rise == 1) begin
				tx_nxt_st <= DATA0;
				ruart_tx		<=	tmp_tx[0];	
			end
			else
				tx_nxt_st <= START;
		DATA0	:
			if(tx_clk_rise ==1) begin
				tx_nxt_st <= DATA1;
				ruart_tx		<=	tmp_tx[1];
			end
			else
				tx_nxt_st <= DATA0;
		DATA1	:
			if(tx_clk_rise == 1) begin
				tx_nxt_st <= DATA2;
				ruart_tx		<=	tmp_tx[2];
			end
			else
				tx_nxt_st <= DATA1;
		DATA2	:
			if(tx_clk_rise == 1) begin
				ruart_tx		<=	tmp_tx[3];
				tx_nxt_st <= DATA3;
			end
			else
				tx_nxt_st <= DATA2;
		DATA3	:
			if(tx_clk_rise == 1) begin
				ruart_tx		<=	tmp_tx[4];
				tx_nxt_st <= DATA4;
			end
			else
				tx_nxt_st <= DATA3;
		DATA4	:
			if(tx_clk_rise == 1) begin
				ruart_tx		<=	tmp_tx[5];
				tx_nxt_st <= DATA5;
			end
			else
				tx_nxt_st <= DATA4;
      DATA5	:
			if(tx_clk_rise == 1) begin
				ruart_tx		<=	tmp_tx[6];
				tx_nxt_st <= DATA6;
			end
			else
				tx_nxt_st <= DATA5;
		DATA6	:
			if(tx_clk_rise == 1) begin
				ruart_tx		<=	tmp_tx[7];
				tx_nxt_st <= DATA7;
			end
			else
				tx_nxt_st <= DATA6;
		DATA7	:
			if(tx_clk_rise == 1) begin
				tx_nxt_st	<= STOP;
				tx_end		<=	1'b1;
				ruart_tx		<=	1'b1;
			end
			else
				tx_nxt_st <= DATA7;
		STOP	:
			tx_nxt_st <= IDLE;
			
		default:		tx_nxt_st <= IDLE;
			
		endcase
end

endmodule