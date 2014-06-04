`timescale 1ns / 1ps

// XXX: Idea is to copy h_in to an NR_STAGES array of DWIDTH-bit values, which
// we can then cycle each clock tick and use h[0] in the computations.
// This synthesizes, but the simulator craps out with "This statement is not
// supported". See also the other XXX comments.

module filter #(parameter NR_STAGES = 32,
				parameter DWIDTH = 16,
				parameter DDWIDTH = 2*DWIDTH,
				parameter CWIDTH = NR_STAGES * DWIDTH)
			   (input  clk,
				input  rst,
				output req_in,
				input  ack_in,
				input  [0:DWIDTH-1] data_in,
				output req_out,
				input  ack_out,
				output [0:DWIDTH-1] data_out,
				input  [0:CWIDTH-1] h_in);

	// Output request register
	reg req_out_buf;
	assign req_out = req_out_buf;

	// Input request register
	reg req_in_buf;
	assign req_in = req_in_buf;
  
	reg running;
	reg [0:4] ctr;

	// Accumulator (assigned to output directly)
	reg signed [0:DWIDTH-1] in;
	reg signed [0:DDWIDTH-1] out;
	assign data_out = out;

	// XXX: h in memory
	reg signed [0:DWIDTH-1] h [0:NR_STAGES-1];
  
	always @(posedge clk) begin
		// Reset => initialize
		if (rst) begin
			req_in_buf <= 0;
			req_out_buf <= 0;
			in <= 16;
			out <= 0;
			ctr <= 0;
			running <= 0;

			// XXX: copy h_in to memory register h
			for (integer i = 0; i < NR_STAGES; i = i + 1 ) begin: test
				h[i] = h_in >> i * DWIDTH;
			end
		end
		// !Reset => run
		else begin
			// Input request & acknowledge => read input and signal input done
			if (req_in && ack_in) begin
				in <= data_in;
				req_in_buf <= 0;
			end
			// Output request & acknowledge => signal output done
			if (req_out && ack_out) begin
				req_out_buf <= 0;
			end
			// If we need no inputs and have no outputs ready, and are out of startup phase
			// then proceed with the computation
			if (running && !req_in && !req_out && !ack_in && !ack_out) begin   
				if (ctr == 1) begin
					req_in_buf <= 1;
					req_out_buf <= 1;
					ctr <= 0;
				end
				else begin
					// XXX: actually use h
					out <= in * h[0];
					ctr <= ctr + 1;
				end
			end
			// Startup phase: Signal input request to get everything started
			if (!running) begin
				req_in_buf <= 1;
				running <= 1;
			end
		end
	end

endmodule
