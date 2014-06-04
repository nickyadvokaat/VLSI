`timescale 1ns / 1ps

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
  
    // Accumulator (assigned to output directly)
    reg signed [0:DWIDTH-1] sum;
    assign data_out = sum;
  
	 //new
	 reg signed counter;
	 reg signed value;
	 reg signed [DWIDTH:0] inputs[0:NR_STAGES-1];
	 
    always @(posedge clk) begin
        // Reset => initialize
        if (rst) begin
            req_in_buf <= 0;
            req_out_buf <= 0;
            sum <= 0;
        end
        // !Reset => run
        else begin
            // Input request & acknowledge => take the input & go back to computation a.s.a.p.
            if (req_in && ack_in) begin
                sum <= data_in;
                req_in_buf <= 0;
                req_out_buf <= 1;
					 
					 //
					 counter = 0;
            end
            // Output request & acknowledge => go back to computation a.s.a.p.
            if (req_out && ack_out) begin
                req_out_buf <= 0;
            end
            // If we need no inputs and have no outputs ready, then proceed with the computation
            if (!req_in && !req_out && !ack_in && !ack_out) begin   
                req_in_buf <= 1;
            end
				
				// new
				
				// input 
				if(ack_in) begin
					inputs[0] = data_in;
					for (int i=1; i<=NR_STAGES-1; i = i + 1) begin
						inputs[i] = inputs[i - 1];
					end
					ack_in <= 0;
				end
	
				// output
				if( counter < NR_STAGES ) begin
					if(counter == 0) begin
						value <= 0;
					end
					value <= value + ( h_in[counter] * data_in[counter] );
					counter <= counter + 1;
				end else begin
					data_out <= value;
					req_out <= 1;
				end
        end
    end

endmodule
