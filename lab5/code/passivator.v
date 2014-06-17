`timescale 1ns / 1ps
module passivator
  #(parameter DWIDTH = 8)
   (input req1,
    output ack1,
    input [0:DWIDTH-1] data1,
    input req2,
    output ack2,
    output [0:DWIDTH-1] data2);

    // Passivator behaviour
    assign ack1 = (req1 & req2);
    assign ack2 = ack1;
   
    // Data passthrough
    assign data2 = data1;
endmodule
