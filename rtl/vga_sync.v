module vga_sync (
   input         clk,
   input         rst_n,

   output        pixelclock,
   output        hsync,
   output        vsync,
   output        displayactive,
   output [10:0] counterX,
   output [ 9:0] counterY,
   output        lineStart,
   output        frameStart
);

//generate 50MHz pixelclock
reg vga_clk;
always @(posedge clk)
    vga_clk <= ~rst_n ? 1'b0 : ~vga_clk;
assign pixelclock = vga_clk;

/*  800x600@72Hz

        General timing
Screen refresh rate     72 Hz
Vertical refresh        48.076923076923 kHz
Pixel freq.             50.0 MHz

        Horizontal timing (line)
Scanline part   Pixels  Time [µs]
Visible area    800     16
Front porch     56      1.12
Sync pulse      120     2.4
Back porch      64      1.28
Whole line      1040    20.8

        Vertical timing (frame)
Frame part      Lines   Time [ms]
Visible area    600     12.48
Front porch     37      0.7696
Sync pulse      6       0.1248
Back porch      23      0.4784
Whole frame     666     13.8528*/

`define H_DISPLAY       800
`define H_BACKPORCH     64
`define H_SYNC          120
`define H_FRONTPORCH    56
`define H_TOTALPERIOD   `H_DISPLAY + `H_BACKPORCH + `H_SYNC + `H_FRONTPORCH

`define V_DISPLAY       600
`define V_BACKPORCH     23
`define V_SYNC          6
`define V_FRONTPORCH    37
`define V_TOTALPERIOD   `V_DISPLAY + `V_BACKPORCH + `V_SYNC + `V_FRONTPORCH

reg [10:0]  CounterX;
reg [ 9:0]  CounterY;
reg         hsyncpulse;
reg         vga_HS, vga_VS, vga_active;

//horizontal counter
always @(posedge pixelclock or negedge rst_n) begin
    if(~rst_n) begin
        CounterX <= 0;
    end else begin
        if(CounterX < `H_TOTALPERIOD)
            CounterX <= CounterX + 1;
        else
            CounterX <= 0;
    end
end
assign counterX = CounterX;

//vertical counter
always @(posedge pixelclock or negedge rst_n) begin
    if(~rst_n) begin
        CounterY <= 0;
    end else begin
        if(CounterY < `V_TOTALPERIOD && CounterX == `H_TOTALPERIOD)
            CounterY <= CounterY + 1;
        else if(CounterX == `H_TOTALPERIOD)
            CounterY <= 0;
    end
end
assign counterY = CounterY;

//hsync generation
always @(posedge pixelclock or negedge rst_n) begin
    if(~rst_n) begin
        vga_HS <= 0;
    end else begin
        if(CounterX == `H_DISPLAY + `H_BACKPORCH)
            vga_HS <= 0;
        else if(CounterX == `H_TOTALPERIOD - `H_FRONTPORCH)
            vga_HS <= 1;
    end
end
assign hsync = ~vga_HS;

//vsync generation
always @(posedge pixelclock or negedge rst_n) begin
    if(~rst_n) begin
        vga_VS <= 0;
    end else begin
        if(CounterY == `V_DISPLAY + `V_BACKPORCH)
            vga_VS <= 0;
        else if(CounterY == `V_TOTALPERIOD - `V_FRONTPORCH)
            vga_VS <= 1;
    end
end
assign vsync = ~vga_VS;

//display active signal generation
always @(posedge pixelclock or negedge rst_n) begin
    if(~rst_n) begin
        vga_active <= 0;
    end else begin
        if(!(CounterX < `H_DISPLAY && CounterY < `V_DISPLAY))
            vga_active <= 0;
        else
            vga_active <= 1;
    end
end
assign displayactive = vga_active;

//create two 1-pixelclock-cycle sync signals for frame and line start
assign lineStart = CounterX == 0;
assign frameStart = CounterY == 0 && CounterX == 0;

endmodule
