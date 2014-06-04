`timescale 1ns / 1ps

// XXX: Working communication and synchronization with clearly defined
// X-stage computation area. No startup noise. Program does NR_STAGES
// computations on every input, where each computation simply increases the
// input value by one. Effectively, this adds 32 to every value.
// Seems to work fine. See also the other XXX comments.

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
	reg [0:5] ctr;

	// Accumulator (assigned to output directly)
	reg signed [0:DWIDTH-1] sum;
	assign data_out = sum;

	always @(posedge clk) begin
		// Reset => initialize
		if (rst) begin
			req_in_buf <= 0;
			req_out_buf <= 0;
			sum <= 0;
			ctr <= 0;
			running <= 0;
		end
		// !Reset => run
		else begin
			// Input request & acknowledge => read input and signal input done
			if (req_in && ack_in) begin
				sum <= data_in;
				req_in_buf <= 0;
			end
			// Output request & acknowledge => signal output done
			if (req_out && ack_out) begin
				req_out_buf <= 0;
			end
			// If we need no inputs and have no outputs ready, and are out of startup phase
			// then proceed with the computation
			if (running && !req_in && !req_out && !ack_in && !ack_out) begin   
				// XXX: After NR_STAGES computations, output and restart computations.
				if (ctr == NR_STAGES) begin
					req_in_buf <= 1;
					req_out_buf <= 1;
					ctr <= 0;
				end
				else begin
					// XXX: computations happen here.
					sum <= sum + 1;
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
