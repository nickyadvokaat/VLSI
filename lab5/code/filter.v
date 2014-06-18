`timescale 1ns / 1ps

module filter
	#(parameter DWIDTH = 16,
		parameter DDWIDTH = 2*DWIDTH,
		parameter L = 160,
		parameter L_LOG = 8,
		parameter M = 147,
		parameter M_LOG = 8,
		parameter CWIDTH = 4*L,
		parameter NR_STREAMS = 16,
		parameter NR_STREAMS_LOG = 4)
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

	// state counter. l = nM mod L (calculated efficiently using conditionals and addition/subtraction)
	reg [0:L_LOG-1] l;
	// Delayed state counter, to compensate for the fact that I/O and computation happen simultaneously now.
	reg [0:L_LOG-1] m;
	// The last 4 input samples used in the FIR (excluding the newest, which will be in data_in)
	reg signed [0:DWIDTH-1] in [0:3];

	// The FIR coefficients (lots of them)
	// Naively, we'd need [0:4L-1], but since the coefficients are
	// symmetric around h[2L], we can just reuse h[2L-1:1] for // h[2L+1:4L-1]
	reg signed [0:DWIDTH-1] h [0:2*L];
	
	// The 4 products in the sum are buffered as partial results for pipelining
	reg signed [0:DDWIDTH-1] partial1;
	reg signed [0:DDWIDTH-1] partial2;
	reg signed [0:DDWIDTH-1] partial3;
	reg signed [0:DDWIDTH-1] partial4;
	// Accumulator (lower bits assigned to output port directly)
	reg signed [0:DDWIDTH-1] sum;
	assign data_out = sum >> 15;


	initial
	begin
		// Initialize the ROM with coefficients from file
		$readmemh("coefficients.txt", h);
	end


	always @(posedge clk)
	begin
		// Reset => initialize
		if (rst)
		begin
			req_in_buf <= 0;
			req_out_buf <= 0;
			in[0] <= 0;
			in[1] <= 0;
			in[2] <= 0;
			in[3] <= 0;
			partial1 <= 0;
			partial2 <= 0;
			partial3 <= 0;
			partial4 <= 0;
			sum <= 0;
			l <= 0;
		end
		// !Reset => run
		else
		begin

			// Read handshake complete
			if (req_in && ack_in)
			begin
				// FIXME: comment on not having in[0]
				in[0] <= data_in;
				in[1] <= in[0];
				in[2] <= in[1];
				in[3] <= in[2];

				//sum <= (data_in >> 1) | (data_in & 32768);
				req_out_buf <= 1;
			end

			   //Read handshake is pending then stop producing output
			if (req_in && !ack_in)
			begin
				req_out_buf <= 0;
			end

			// Write handshake complete
			if (req_out && ack_out)
			begin
				// l <= (l + M) mod L, implemented with conditionals
				// No-overflow case
				if( l < L - M )
				begin
					l <= l + M;
					req_in_buf <= 0;
				end
				// Overflow case. Overflow also means we need a new input!
				else
				begin
					l <= l - (L - M);
					req_in_buf <= 1;
				end

				m <= l;

				// pipelined: sum <= (in[0] * h[l] + in[1] * h[l+L] + in[2] * h[l+L*2] + in[3] * h[l+L*3]);
				partial1 <= in[0] * h[m];      // h[m+L*0]
				partial2 <= in[1] * h[m+L];    // h[m+L*1]
				partial3 <= in[2] * h[L*2-m];  // h[m+L*2], mirrored
				partial4 <= in[3] * h[L-m];    // h[m+L*3], mirrored
				sum <= partial1 + partial2 + partial3 + partial4;
			end

			//Write handshake is pending then stop acquiring output.
			if (req_out && !ack_out)
			begin
				req_in_buf <= 0;
			end

			// Idle state
			if (!req_in && !ack_in && !req_out && !ack_out)
			begin
				req_in_buf <= 1;
			end

		end
	end

endmodule
