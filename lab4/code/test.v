`timescale 1ns / 1ps

module multitest;

// Parameters
parameter DWIDTH = 16;

// Control ports
reg clk = 0;
reg rst = 1;

// Input port
wire req_in1;
wire ack_in1;
wire signed [0:DWIDTH-1] data_in1;

// Output port
wire req_out1;
wire ack_out1;
wire signed [0:DWIDTH-1] data_out1;

// Instantiation of the filter
filter #(.DWIDTH(DWIDTH)) filter_inst (clk, rst, req_in1, ack_in1, data_in1, req_out1, ack_out1, data_out1);

// Input buffer
reg signed [0:DWIDTH-1] data_in = 0;
assign data_in1 = data_in;

// Request buffers
reg ack_in = 0;
assign ack_in1 = ack_in;
reg ack_out = 0;
assign ack_out1 = ack_out;

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
	if (req_in1 && !ack_in1) begin
		// BIG ENDIAN
	        data_in[0:7] <= $fgetc(input_file);
	        data_in[8:15] <= $fgetc(input_file);
		io_error <= $ferror(input_file, io_error_str);
		ack_in <= 1;
	end
	if (!req_in1 && ack_in1) begin
		ack_in <= 0 | random_in;
	end
end

// Process that writes the 8 MSBs of the output to a file
always @(posedge clk) begin
	if (req_out1 && !ack_out1) begin
	   	// BIG ENDIAN FORMAT
		$fwrite(output_file, "%c", data_out1[0:7]);
		$fwrite(output_file, "%c", data_out1[8:15]);
		ack_out <= 1;
	end
   if (!req_out1 && ack_out1) begin
		ack_out <= 0 | random_out;
	end
end

initial begin
	// Wait 100 ns for global reset to finish
	#100;
	rst = 0;

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
		// We keep enabling the filter until the input file has been processed
		random_in <= $random;
		random_out <= $random;
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
