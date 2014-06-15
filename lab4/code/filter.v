`timescale 1ns / 1ps

module filter
	#(parameter DWIDTH = 16,
		parameter DDWIDTH = 2*DWIDTH,
		parameter L = 160,
		parameter L_LOG = 8,
		parameter M = 147,
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

	// state counter. l = nM mod L (calculated efficiently using conditionals and addition/subtraction)
	reg [0:L_LOG-1] l;
	// The last 4 input samples used in the FIR
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
			sum <= 0;
			l <= 0;
		end
		// !Reset => run
		else
		begin
			// Input
			if (req_in && ack_in)
			begin
				// Read new input sample, and shift older samples
				in[0] <= data_in;
				in[1] <= in[0];
				in[2] <= in[1];
				in[3] <= in[2];
				// Input is done
				req_in_buf <= 0;
			end

			// Output
			if (req_out && ack_out)
			begin
				// Output is done
				req_out_buf <= 0;
			end

			// No I/O, computation cycle
			if (!req_in && !req_out && !ack_in && !ack_out)
			begin
				// l <= (l + M) mod L, implemented with conditionals
				// No-overflow case
				if( l < L - M )
				begin
					l <= l + M;
				end
				// Overflow case. Overflow also means we need a new input!
				else
				begin
					l <= l - (L - M);
					req_in_buf <= 1;
				end

				// We output after every computation cycle
				req_out_buf <= 1;

				// pipelined: sum <= (in[0] * h[l] + in[1] * h[l+L] + in[2] * h[l+L*2] + in[3] * h[l+L*3]);
				partial1 <= in[0] * h[l];      // h[l+L*0]
				partial2 <= in[1] * h[l+L];    // h[l+L*1]
				partial3 <= in[2] * h[L*2-l];  // h[l+L*2], mirrored
				partial4 <= in[3] * h[L-l];    // h[l+L*3], mirrored
				sum <= partial1 + partial2 + partial3 + partial4;
			end
		end
	end

endmodule
