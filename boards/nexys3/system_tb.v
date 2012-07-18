//----------------------------------------------------------------------------
//
//----------------------------------------------------------------------------
`timescale 1 ns / 100 ps

module system_tb;

//----------------------------------------------------------------------------
// Parameter (may differ for physical synthesis)
//----------------------------------------------------------------------------
parameter tck              = 10;       // clock period in ns
parameter clk_freq = 1000000000 / tck; // Frequenzy in HZ
//----------------------------------------------------------------------------
//
//----------------------------------------------------------------------------
reg        clk;
reg        reset;
wire       led;

wire       Hsync;
wire       Vsync;

//------------------------------------------------------------------
// LED output (just some useless example)
//------------------------------------------------------------------
always @(posedge clk)
begin
	if (led)
		$display("LED on");
end

//------------------------------------------------------------------
// Decive Under Test
//------------------------------------------------------------------
system #(
) dut  (
	.clk(          clk    ),
	.btns(         reset  ),
	.Led(          led    ),

	.Hsync(        Hsync  ),
    .Vsync(        Vsync  )
);

/* Clocking device */
initial         clk <= 0;
always #(tck/2) clk <= ~clk;

/* Simulation setup */
initial begin
	$dumpfile("system_tb.vcd");
	$dumpvars(-1, dut);

	// reset
	#0  reset <= 0;
	#10 reset <= 1;
	#80 reset <= 0;

	#(tck*50000) $finish;
end

endmodule
