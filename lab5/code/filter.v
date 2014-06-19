`timescale 1ns / 1ps

module filter
	#(parameter DWIDTH = 16,
		parameter DDWIDTH = 2*DWIDTH,
		parameter L = 160,
		parameter L_LOG = 8,
		parameter M = 147,
		parameter M_LOG = 8,
		parameter CWIDTH = 4*L,
		parameter NR_STREAMS = 1024,
		parameter NR_STREAMS_LOG = 10)
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

	reg [0:NR_STREAMS_LOG-1] stream;

	// state counter. l = nM mod L (calculated efficiently using conditionals and addition/subtraction)
	reg [0:L_LOG-1] l;
	// Delayed state counter, to compensate for the fact that I/O and computation happen simultaneously now.
	reg [0:L_LOG-1] m0;
	reg [0:L_LOG-1] m1;
	reg [0:L_LOG-1] m2;
	reg [0:L_LOG-1] m3;
	// The last 4 input samples used in the FIR (excluding the newest, which will be in data_in)
	reg signed [0:DWIDTH-1] in0 [0:NR_STREAMS-1];
	reg signed [0:DWIDTH-1] in1 [0:NR_STREAMS-1];
	reg signed [0:DWIDTH-1] in2 [0:NR_STREAMS-1];
	reg signed [0:DWIDTH-1] in3 [0:NR_STREAMS-1];

	// The FIR coefficients (lots of them)
	// Naively, we'd need [0:4L-1], but since the coefficients are
	// symmetric around h[2L], we can just reuse h[2L-1:1] for // h[2L+1:4L-1]
	reg signed [0:DWIDTH-1] h0 [0:L-1];
	reg signed [0:DWIDTH-1] h1 [0:L-1];
	reg signed [0:DWIDTH-1] h2 [0:L-1];
	reg signed [0:DWIDTH-1] h3 [0:L-1];
	
	// The 4 products in the sum are buffered as partial results for pipelining
	reg signed [0:DDWIDTH-1] partial0 [0:NR_STREAMS-1];
	reg signed [0:DDWIDTH-1] partial1 [0:NR_STREAMS-1];
	reg signed [0:DDWIDTH-1] partial2 [0:NR_STREAMS-1];
	reg signed [0:DDWIDTH-1] partial3 [0:NR_STREAMS-1];
	// Accumulator (lower bits assigned to output port directly)
	reg signed [0:DDWIDTH-1] sum;
	assign data_out = sum >> 15;


	initial
	begin
		// Initialize the ROM with coefficients from file
		$readmemh("coefficients0.txt", h0);
		$readmemh("coefficients1.txt", h1);
		$readmemh("coefficients2.txt", h2);
		$readmemh("coefficients3.txt", h3);
	end


	always @(posedge clk)
	begin
		// Reset => initialize
		if (rst)
		begin
			req_in_buf <= 0;
			req_out_buf <= 0;
			stream <= 0;
			l <= 0;
		end
		// !Reset => run
		else
		begin

			// Read handshake complete
			if (req_in && ack_in)
			begin
				in0[stream] <= data_in;
				in1[stream] <= in0[stream];
				in2[stream] <= in1[stream];
				in3[stream] <= in2[stream];

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
				if( stream == 0 )
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

					// m <= l;
					m0 <= l;
					m1 <= l;
					m2 <= l;
					m3 <= l;
				end

				// pipelined: sum <= (in0 * h[l] + in1 * h[l+L] + in2 * h[l+L*2] + in3 * h[l+L*3]);
				partial0[stream] <= in0[stream] * h0[m0];      // h[m+L*0]
				partial1[stream] <= in1[stream] * h1[m1];    // h[m+L*1]
				partial2[stream] <= in2[stream] * h2[m2];  // h[m+L*2], mirrored
				partial3[stream] <= in3[stream] * h3[m3];    // h[m+L*3], mirrored
				sum <= partial0[stream] + partial1[stream] + partial2[stream] + partial3[stream];
				// sum <= in0[stream] * h[m] + in1[stream] * h[m+L] + in2[stream] * h[L*2-m] + in3[stream] * h[L-m];

				stream <= (stream + 1) & (NR_STREAMS-1);
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
