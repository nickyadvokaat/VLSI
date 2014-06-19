`timescale 1ns / 1ps

module multitest;

// Parameters
parameter DWIDTH = 16;

//Vary these parameters for testing the scalability
parameter NR_STREAMS = 1;
parameter NR_STREAMS_LOG = 0;
parameter STR_IND = 0;


// Control ports
reg clk = 0;
reg rst = 1;

//Stream counter (change the width if needed.)
reg [0:NR_STREAMS_LOG-1] stream_in = 0;
reg [0:NR_STREAMS_LOG-1] stream_out = 0;


// Test to passivator1 ports
wire send_input;
wire ack_in;
wire signed [0:DWIDTH-1] data_in_pas1;

// Filter input and output signals
wire filter_in_req;
wire filter_in_ack;
wire [0:DWIDTH-1] filter_in_data;
wire filter_out_req;
wire filter_out_ack;
wire [0:DWIDTH-1] filter_out_data;

// Passivator2 to test ports
wire receive_output;
wire ack_out;
wire signed [0:DWIDTH-1] data_out_pas2;


// Instantiation of Passivator1
passivator #(.DWIDTH(DWIDTH) ) pas1 (send_input, ack_in, data_in_pas1, filter_in_req, filter_in_ack, filter_in_data);

// Instantiation of the filter
filter #(.DWIDTH(DWIDTH), .NR_STREAMS(NR_STREAMS), .NR_STREAMS_LOG(NR_STREAMS_LOG) ) 
filter_inst (clk, rst, filter_in_req, filter_in_ack, filter_in_data, filter_out_req, filter_out_ack, filter_out_data);

// Instantiation of Passivator2
passivator #(.DWIDTH(DWIDTH)) pas2 (filter_out_req, filter_out_ack, filter_out_data, receive_output, ack_out, data_out_pas2);

// Input buffer
reg signed [0:DWIDTH-1] data_in = 0;
reg send_input_buf, receive_output_buf;
assign data_in_pas1 = data_in;
assign send_input = send_input_buf;
assign receive_output = receive_output_buf;


// Variables for handling the file I/O
integer input_file;
integer output_file;
integer io_error;
reg [0:639] io_error_str;

// The clock (100Mhz)
always #5 clk = ~clk;

// Registers that store random numbers for request randomization
reg random_in = 0;
reg random_out = 0;

// Process that reads the input samples from a file
always @(posedge clk) begin
	if ( (send_input && ack_in) || !send_input) begin
	
	     //If it matches with STR_IND
		  if (stream_in == STR_IND) begin
		  
			 // BIG ENDIAN
			 data_in[0:7] <= $fgetc(input_file);
			 data_in[8:15] <= $fgetc(input_file);
			 io_error <= $ferror(input_file, io_error_str);		

		  end else begin
		  
			 // BIG ENDIAN
				  data_in[0:7] <= 0;
				  data_in[8:15] <= 0;			  
		  end
		  
				 
			  //If reaches max stream then reset it		
			  if (stream_in == (NR_STREAMS-1)) begin
				 stream_in <= 0;
			  end else begin
				 stream_in <= stream_in + 1;
			  end
			  
		  send_input_buf <= 1;
	  	  receive_output_buf <= 1;
	end 
						
end



// Process that writes the 8 MSBs of the output to a file
always @(posedge clk) begin
	if (ack_out) begin
	
	  if (stream_out == STR_IND) begin
	   	// BIG ENDIAN FORMAT
			$fwrite(output_file, "%c", data_out_pas2[0:7]);
			$fwrite(output_file, "%c", data_out_pas2[8:15]);					

	  end
	  	
		  //If reaches max stream then reset it
		  if (stream_out == (NR_STREAMS-1)) begin
			  stream_out <= 0;
		  end else begin		
				stream_out <= stream_out + 1;		
		  end		
	
	end  
	
	
end

initial begin
	// Wait 100 ns for global reset to finish
	#100;
	rst = 0;
	send_input_buf <= 0;
	receive_output_buf <= 0;

	// Open the files
	input_file = $fopen("input.bin", "rb");
	if (input_file == 0) begin
		$display("Error: Failed to open input file, input.bin\nExiting Simulation.");
		$finish;
	end
	output_file = $fopen("output.bin", "wb");
	if (output_file == 0) begin
		$display("Error: Failed to open output file, output.bin\nExiting Simulation.");
		$finish;
	end

	// Wait 100 ns
	#100;

	// While there is data available, send it to the filter
	io_error = 0;
	while (io_error == 0) @(posedge clk) begin
		// We keep signalling the filter until the input file has been processed
		send_input_buf <= 1;
	end

	// Close the files
	$fclose(input_file);
	$fclose(output_file);
		
	// Stop the simulation
	#100;
	$fdisplay("Simulation ended\n");
	$stop;

end
      
endmodule
