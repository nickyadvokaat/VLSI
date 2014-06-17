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
	 
    // Accumulator (assigned to output directly)
    reg signed [0:DWIDTH-1] sum;
    assign data_out = sum;
	 
  
    always @(posedge clk) begin
        // Reset => initialize
        if (rst) begin
            req_in_buf <= 0;
            req_out_buf <= 0;
            sum <= 0;				
        end
        // !Reset => run
        else begin
		  
            // Read handshake complete
            if (req_in && ack_in) begin
                sum <= data_in;					              					 
				req_out_buf <= 1;                					  
            end			   				
				
			   //Read handshake is pending then stop producing output
			if (req_in && !ack_in) begin              
               req_out_buf <= 0;
            end 
								
            // Write handshake complete
            if (req_out && ack_out) begin                				   
				   req_in_buf <= 1; 
            end 

            //Write handshake is pending then stop acquiring output.
            if (req_out && !ack_out) begin                			                  
				   req_in_buf <= 0;
            end 			            			  
				
            // Idle state
            if (!req_in && !ack_in && !req_out && !ack_out) begin                		
              req_in_buf <= 1;					
            end
				
        end
    end

endmodule
