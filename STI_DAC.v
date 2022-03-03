module STI_DAC(clk ,reset, load, pi_data, pi_length, pi_fill, pi_msb, pi_low, pi_end,
	       so_data, so_valid,
	       oem_finish, oem_dataout, oem_addr,
	       odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr);

input clk, reset;
input load, pi_msb, pi_low, pi_end; 
input [15:0] pi_data;
input [1:0] pi_length;
input pi_fill;

output reg so_data, so_valid;
output reg oem_finish, odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr;
output reg [4:0] oem_addr;
output reg [7:0] oem_dataout;

reg [2:0] state_cs, state_ns; //STI
parameter ST_IDLE = 3'd0;
parameter ST_STI = 3'd1;
parameter ST_8B = 3'd2;
parameter ST_16B = 3'd3;
parameter ST_24B = 3'd4;
parameter ST_32B = 3'd5;
parameter ST_DONE = 3'd6;

reg [4:0] count_pi; 
reg [7:0] count_so; //count so_data address
reg [2:0] count_sonum;

reg [1:0] state2_cs, state2_ns; //DAC
parameter ST2_IDLE = 2'd0;
parameter ST2_OUTPUT = 2'd1;
parameter ST2_ZERO = 2'd2;
parameter ST2_DONE = 2'd3;

reg [7:0] data;
reg [4:0] count_out;
reg odd; //1:odd 0:even

always @(posedge clk or posedge reset) begin //state2_cs
	if(reset)
		state2_cs = ST2_IDLE;
	else
		state2_cs = state2_ns;
end

always @(*) begin //state2_ns
	case (state2_cs)
		ST2_IDLE:
			if(so_valid)
				state2_ns = ST2_OUTPUT;
			else if(state_ns == ST_DONE)
				state2_ns = ST2_ZERO;
			else
				state2_ns = ST2_IDLE;
		ST2_OUTPUT:
			if(~so_valid)
				state2_ns = ST2_IDLE;
			else
				state2_ns = ST2_OUTPUT;
		ST2_ZERO:
			if(count_so == 255)
				state2_ns = ST2_DONE;
			else
				state2_ns = ST2_ZERO;
		ST2_DONE:
			state2_ns = ST2_DONE;
		default: 
			state2_ns = ST2_IDLE; 
	endcase
end
 
always @(posedge clk or posedge reset) begin //oem_finish
	if(reset)
		oem_finish <= 0;
	else if(state2_ns == ST2_DONE)
		oem_finish <= 1;
	else
		oem_finish <= 0;
end

always @(posedge clk or posedge reset) begin //data
	if(reset)
		data <= 8'd0;
	else if(state2_ns == ST2_OUTPUT)begin
		data[0] <= so_data;
		data[1] <= data[0];
		data[2] <= data[1];
		data[3] <= data[2];
		data[4] <= data[3];
		data[5] <= data[4];
		data[6] <= data[5];
		data[7] <= data[6];
	end
	else
		data <= 8'd0;
end

always @(posedge clk or posedge reset) begin //oem_dataout
	if(reset)
		oem_dataout <= 8'd0;
	else if(count_sonum == 3'd0)
		oem_dataout <= data;
	else
		oem_dataout <= 8'd0;
end

always @(posedge clk or posedge reset) begin //oem_addr
	if(reset)
		oem_addr <= 5'd0;	
	else if(state2_cs == ST2_OUTPUT && count_sonum == 7)
		if(count_so == 255 || count_so == 0)
			oem_addr <= 5'd0;
		else if(count_so[0])
			oem_addr <= oem_addr + 1'b1;
		else
			oem_addr <= oem_addr;
	else if(state2_cs == ST2_ZERO && ~odd)
		oem_addr <= oem_addr + 1'b1;
	else	
		oem_addr <= oem_addr;
	end

always @(posedge clk) begin //odd
	if(state2_cs == ST2_OUTPUT)
		if((count_so[3:0] == 15 || 
			count_so[3:0] == 1 || 
			count_so[3:0] == 3 || 
			count_so[3:0] == 5 || 
			count_so[3:0] == 8 || 
			count_so[3:0] == 10 || 
			count_so[3:0] == 12 || 
			count_so[3:0] == 14) && count_sonum == 7)
			odd <= 1;
		else
			odd <= 0;
	else if(state2_cs == ST2_ZERO)
		odd <= odd + 1'b1;
	else
		odd <= 0;
end

always @(posedge clk or posedge reset) begin //odd1_wr
	if(reset)
		odd1_wr <= 0;
	else if(state2_cs == ST2_OUTPUT && odd && count_sonum == 0)
		if(count_so <= 63)
			odd1_wr <= 1;
		else
			odd1_wr <= 0;
	else if(state2_cs == ST2_ZERO && odd)
		if(count_so <= 63)
			odd1_wr <= 1;
		else
			odd1_wr <= 0;
	else
		odd1_wr <= 0;
end

always @(posedge clk or posedge reset) begin //odd2_wr
	if(reset)
		odd2_wr <= 0;
	else if(state2_cs == ST2_OUTPUT && odd && count_sonum == 0)
		if(count_so >= 64 && count_so <= 127)
			odd2_wr <= 1;
		else
			odd2_wr <= 0;
	else if(state2_cs == ST2_ZERO && odd)
		if(count_so >= 64 && count_so <= 127)
			odd2_wr <= 1;
		else
			odd2_wr	<= 0;
	else
		odd2_wr <= 0;
end

always @(posedge clk or posedge reset) begin //odd3_wr
	if(reset)
		odd3_wr <= 0;
	else if(state2_cs == ST2_OUTPUT && odd && count_sonum == 0)
		if(count_so >= 128 && count_so <= 191)
			odd3_wr <= 1;
		else
			odd3_wr <= 0;
	else if(state2_cs == ST2_ZERO && odd)
		if(count_so >= 128 && count_so <= 191)
			odd3_wr <= 1;
		else
			odd3_wr <= 0;
	else
		odd3_wr <= 0;
end

always @(posedge clk or posedge reset) begin //odd4_wr
	if(reset)
		odd4_wr <= 0;
	else if(state2_cs == ST2_OUTPUT && odd && count_sonum == 0)
		if(count_so >= 191 && count_so <= 254)
			odd4_wr <= 1;
		else
			odd4_wr <= 0;
	else if(state2_cs == ST2_ZERO && odd)
		if(count_so >= 191 && count_so <= 254)
			odd4_wr <= 1;
		else
			odd4_wr <= 0;
	else
		odd4_wr <= 0;
end

always @(posedge clk or posedge reset) begin //even1_wr
	if(reset)
		even1_wr <= 0;
	else if(state2_cs == ST2_OUTPUT && ~odd && count_sonum == 0)
		if(count_so + 1 <= 63)
			even1_wr <= 1;
		else
			even1_wr <= 0;
	else if(state2_cs == ST2_ZERO && ~odd && count_so != 0)
		if(count_so + 1 <= 63)
			even1_wr <= 1;
		else
			even1_wr <= 0;
	else
		even1_wr <= 0;
end

always @(posedge clk or posedge reset) begin //even2_wr
	if(reset)
		even2_wr <= 0;
	else if(state2_cs == ST2_OUTPUT && ~odd && count_sonum == 0)
		if(count_so >= 63 && count_so <= 126)
			even2_wr <= 1;
		else
			even2_wr <= 0;
	else if(state2_cs == ST2_ZERO && ~odd)
		if(count_so >= 63 && count_so <= 126)
			even2_wr <= 1;
		else
			even2_wr <= 0;
	else
		even2_wr <= 0;
end

always @(posedge clk or posedge reset) begin //even3_wr
	if(reset)
		even3_wr <= 0;
	else if(state2_cs == ST2_OUTPUT && ~odd && count_sonum == 0)
		if(count_so >= 127 && count_so <= 190)
			even3_wr <= 1;
		else
			even3_wr <= 0;
	else if(state2_cs == ST2_ZERO && ~odd)
		if(count_so >= 127 && count_so <= 190)
			even3_wr <= 1;
		else
			even3_wr <= 0;
	else
		even3_wr <= 0;
end

always @(posedge clk or posedge reset) begin //even4_wr
	if(reset)
		even4_wr <= 0;
	else if(state2_cs == ST2_OUTPUT && ~odd && count_sonum == 0)
		if(count_so >= 191 && count_so <= 254)
			even4_wr <= 1;
		else
			even4_wr <= 0;
	else if(state2_cs == ST2_ZERO && ~odd)
		if(count_so >= 191 && count_so <= 254)
			even4_wr <= 1;
		else
			even4_wr <= 0;
	else
		even4_wr <= 0;
end

always @(posedge clk or posedge reset) begin //state_cs
	if(reset)
		state_cs <= ST_IDLE;
	else
		state_cs <= state_ns;	
end

always @(*) begin //state_ns
	case (state_cs)
		ST_IDLE: 
			if(load)
				state_ns = ST_STI;
			else if(pi_end)
				state_ns = ST_DONE;
			else
				state_ns = ST_IDLE;
		ST_STI:
			if(pi_length == 2'b00)
				state_ns = ST_8B;
			else if(pi_length == 2'b01)
				state_ns = ST_16B;
			else if(pi_length == 2'b10)
				state_ns = ST_24B;
			else if(pi_length == 2'b11)
				state_ns = ST_32B;
			else
				state_ns = ST_STI;
		ST_8B:
			if(pi_msb)
				if(count_pi == 5'd8 || count_pi == 5'd0)
					state_ns = ST_IDLE;
				else
					state_ns = ST_8B;
			else
				if(count_pi == 5'd15 || count_pi == 5'd7)
					state_ns = ST_IDLE;
				else
					state_ns = ST_8B;
		ST_16B:
			if(pi_msb)
				if(count_pi == 5'd0)
					state_ns = ST_IDLE;
				else
					state_ns = ST_16B;
			else
				if(count_pi == 5'd15)
					state_ns = ST_IDLE;
				else
					state_ns = ST_16B;
		ST_24B:
			if(pi_fill)	
				if(pi_msb)
					if(count_pi == 5'd24)
						state_ns = ST_IDLE;
					else
						state_ns = ST_24B;
				else
					if(count_pi == 5'd15)
						state_ns = ST_IDLE;
					else
						state_ns = ST_24B;
			else
				if(pi_msb)
					if(count_pi == 5'd0)
						state_ns = ST_IDLE;
					else
						state_ns = ST_24B;
				else
					if(count_pi == 5'd23)
						state_ns = ST_IDLE;
					else
						state_ns = ST_24B;
		ST_32B:
			if(pi_fill)	
				if(pi_msb)
					if(count_pi == 5'd16)
						state_ns = ST_IDLE;
					else
						state_ns = ST_32B;
				else
					if(count_pi == 5'd15)
						state_ns = ST_IDLE;
					else
						state_ns = ST_32B;
			else
				if(pi_msb)
					if(count_pi == 5'd0)
						state_ns = ST_IDLE;
					else
						state_ns = ST_32B;
				else
					if(count_pi == 5'd31)
						state_ns = ST_IDLE;
					else
						state_ns = ST_32B;
		ST_DONE:
			state_ns = ST_DONE;
		default:
			state_ns = ST_IDLE; 
	endcase
end

always @(posedge clk or posedge reset) begin //count_so
	if(reset)
		count_so <=8'd255;
	else if(count_sonum == 3'd7)
		count_so <= count_so + 1'b1;
	else if(state2_cs == ST2_ZERO)
		count_so <= count_so + 1'b1;
	else
		count_so <= count_so;
end

always @(posedge clk or posedge reset) begin //count_sonum
	if(reset)
		count_sonum <= 3'd0;
	else
		case (state_cs)
			ST_IDLE:
				count_sonum <= 3'd0;
			ST_STI:
				count_sonum <= 3'd0;
			default: 
				if(so_valid)
					count_sonum <= count_sonum + 1'b1;
				else
					count_sonum <= count_sonum; 
		endcase
end

always @(posedge clk or posedge reset) begin //so_data
	if(reset)
		so_data <= 0;
	else
		case (state_cs)
			ST_IDLE:
				so_data <= 0;
			ST_8B:
				so_data <= pi_data[count_pi];
			ST_16B:
				so_data <= pi_data[count_pi];
			ST_24B:
				if(pi_fill)	
					if(count_pi >= 24 && count_pi <= 31)
						so_data <= 0;
					else
						so_data <= pi_data[count_pi];
				else
					if(count_pi >= 16 && count_pi <= 23)
						so_data <= 0;
					else
						so_data <= pi_data[count_pi];
			ST_32B:
				if(pi_fill)	
					if(count_pi >= 16 && count_pi <= 31)
						so_data <= 0;
					else
						so_data <= pi_data[count_pi];
				else
					if(count_pi >= 16 && count_pi <= 31)
						so_data <= 0;
					else
						so_data <= pi_data[count_pi];
			
			default: 
				so_data <= 0;
		endcase
end

always @(posedge clk or posedge reset) begin //so_valid
	if(reset)
		so_valid <= 0;
	else
		case (state_cs)
			ST_8B:
				so_valid <= 1;
			ST_16B:
				so_valid <= 1;
			ST_24B:
				so_valid <= 1;
			ST_32B:
				so_valid <= 1;
			default: 
				so_valid <= 0;
		endcase
end

always @(posedge clk or posedge reset) begin //count_pi	
	if(reset)
		count_pi <= 5'd0;
	else
		case (state_ns)
			ST_IDLE:
				count_pi <= 5'd0;
			ST_8B:
				if(pi_msb)
					if(pi_low && count_pi == 5'd0)
						count_pi <= 5'd15;
					else if(pi_low)
						count_pi <= count_pi - 1'b1;
					else if(~pi_low && count_pi == 0)
						count_pi <= 5'd7;
					else if(~pi_low)
						count_pi <= count_pi - 1'b1;
					else
						count_pi <= count_pi;
				else
					if(pi_low && count_pi == 5'd0)
						count_pi <= 5'd8;
					else if(pi_low)
						count_pi <= count_pi + 1'b1;
					else if(~pi_low && state_cs == ST_STI)
						count_pi <= 5'd0;
					else if(~pi_low)
						count_pi <= count_pi + 1'b1;
					else
						count_pi <= count_pi;
			ST_16B:
				if(pi_msb)
					if(count_pi == 5'd0)
						count_pi <= 5'd15;
					else
						count_pi <= count_pi - 1'b1;
				else
					if(state_cs == ST_STI)
						count_pi <= 5'd0;
					else
						count_pi <= count_pi + 1'b1;
			ST_24B:
				if(pi_fill)	
					if(pi_msb)
						if(state_cs == ST_STI && count_pi == 5'd0)
							count_pi <= 5'd15;
						else
							count_pi <= count_pi - 1'b1;
					else
						if(state_cs == ST_STI)
							count_pi <= 5'd24;
						else
							count_pi <= count_pi + 1'b1;
				else
					if(pi_msb)
						if(count_pi == 5'd0)
							count_pi <= 5'd23;
						else
							count_pi <= count_pi - 1'b1;
					else
						if(state_cs == ST_STI)
							count_pi <= 5'd0;
						else
							count_pi <= count_pi + 1'b1;
			ST_32B:
				if(pi_fill)	
					if(pi_msb)
						if(state_cs == ST_STI && count_pi == 5'd0)
							count_pi <= 5'd15;
						else
							count_pi <= count_pi - 1'b1;
					else
						if(state_cs == ST_STI)
							count_pi <= 5'd16;
						else
							count_pi <= count_pi + 1'b1;
				else
					if(pi_msb)
						if(count_pi == 5'd0)
							count_pi <= 5'd31;
						else
							count_pi <= count_pi - 1'b1;
					else
						if(state_cs == ST_STI)
							count_pi <= 5'd0;
						else
							count_pi <= count_pi + 1'b1;
			default: 
				count_pi <= 5'd0;
		endcase
end
//==============================================================================

endmodule
