`timescale 1ns / 1ps

module filter
	#(parameter DWIDTH = 16,
		parameter DDWIDTH = 2*DWIDTH,
		parameter L = 4,
		parameter L_LOG = 8,
		parameter M = 3,
		parameter M_LOG = 8,
		parameter CWIDTH = 4*L)
	(input clk,
		input rst,
		output req_in,
		input ack_in,
		input [0:DWIDTH-1] data_in,
		output req_out,
		input ack_out,
		output [0:DWIDTH-1] data_out);

	// Output request register
	reg req_out_buf;
	assign req_out = req_out_buf;

	// Input request register
	reg req_in_buf;
	assign req_in = req_in_buf;

	reg [0:L_LOG-1] l;
	reg signed [0:DWIDTH-1] in [0:3];
	reg signed [0:DWIDTH-1] h [0:4*L-1];
	
	// Accumulator (assigned to output directly)
	reg signed [0:DDWIDTH-1] sum;
	assign data_out = sum >> 15;
	
	initial
	begin
		//h[ 0] = 32767;
		//h[ 1] = 32767;
		//h[ 2] = 32767;
		//h[ 3] = 32767;
		//h[ 4] = 0;
		//h[ 5] = 0;
		//h[ 6] = 0;
		//h[ 7] = 0;
		//h[ 8] = 0;
		//h[ 9] = 0;
		//h[10] = 0;
		//h[11] = 0;
		//h[12] = 0;
		//h[13] = 0;
		//h[14] = 0;
		//h[15] = 0;

		h[ 0] = 16'h0000;
		h[ 1] = 16'hfdbb;
		h[ 2] = 16'hf7ed;
		h[ 3] = 16'hf543;
		h[ 4] = 16'h0000;
		h[ 5] = 16'h1dd5;
		h[ 6] = 16'h48a7;
		h[ 7] = 16'h6f36;
		h[ 8] = 16'h7ec2;
		h[ 9] = 16'h6f36;
		h[10] = 16'h48a7;
		h[11] = 16'h1dd5;
		h[12] = 16'h0000;
		h[13] = 16'hf543;
		h[14] = 16'hf7ed;
		h[15] = 16'hfdbb;
	end

	always @(posedge clk)
	begin
		// Reset => initialize
		if (rst)
		begin
			req_in_buf <= 0;
			req_out_buf <= 0;
			sum <= 0;
			l <= 0;
		end
		// !Reset => run
		else
		begin
			// Input request & acknowledge => take the input & go back to computation a.s.a.p.
			if (req_in && ack_in)
			begin
				in[0] <= data_in;
				in[1] <= in[0];
				in[2] <= in[1];
				in[3] <= in[2];
				req_in_buf <= 0;
			end
			// Output request & acknowledge => go back to computation a.s.a.p.
			if (req_out && ack_out)
			begin
				req_out_buf <= 0;
			end
			// If we need no inputs and have no outputs ready, then proceed with the computation
			if (!req_in && !req_out && !ack_in && !ack_out)
			begin
				if( l < L - M )
				begin
					l <= l + M;
				end
				else
				begin
					l <= l - (L - M);
					req_in_buf <= 1;
				end

				req_out_buf <= 1;

				sum <= (in[0] * h[l] + in[1] * h[l+L] + in[2] * h[l+L*2] + in[3] * h[l+L*3]);
				// sum <= l;
			end
		end
	end

endmodule
