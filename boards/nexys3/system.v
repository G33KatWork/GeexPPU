module system (
   input clk,
   input btns,
   output Led,

   output Hsync,
   output Vsync,

   output [2:0] vgaRed,
   output [2:0] vgaGreen,
   output [1:0] vgaBlue
);

wire rst_n;
assign rst_n = ~btns;

//50MHz pixelclock
reg vga_clk;
always @(posedge clk)
    vga_clk <= ~rst_n ? 0 : ~vga_clk;

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
`define HSTART 0

reg [10:0] CounterX;
reg [9:0] CounterY;
reg vga_HS, vga_VS, vga_active;

wire CounterXmaxed = (CounterX==1040);
wire lastline = (CounterY == 665);
wire [9:0] _CounterY = lastline ? 0 : (CounterY + 1);

always @(posedge vga_clk or negedge rst_n)
    if(~rst_n)
        CounterX <= 0;
    else
        if(CounterXmaxed)
            CounterX <= 0;
        else
            CounterX <= CounterX + 1;

always @(posedge vga_clk or negedge rst_n)
    if(~rst_n)
        CounterY <= 0;
    else
        if (CounterXmaxed)
            CounterY <= _CounterY;

always @(posedge vga_clk) begin
    vga_HS <= ((800 + 61) <= CounterX) & (CounterX < (800 + 61 + 120));
    vga_VS <= (35 <= CounterY) & (CounterY < (35 + 6));
    vga_active <= ((`HSTART + 1) <= CounterX) & (CounterX < (`HSTART + 1 + 800)) & ((35 + 6 + 21) < CounterY) & (CounterY <= (35 + 6 + 21 + 600));
end

assign Hsync = vga_HS;
assign Vsync = vga_VS;

reg [8:0] colors;
always @(posedge vga_clk or negedge rst_n) begin
    if(~rst_n) begin
        colors <= 8'h00;
    end else begin
        if(vga_active) begin
            colors <= colors + 1;
        end
    end
end

assign vgaRed = (vga_active) ? colors[7:5] : 3'b0;
assign vgaGreen = (vga_active) ? colors[4:2] : 3'b0;
assign vgaBlue = (vga_active) ? colors[1:0] : 2'b0;


//Fancy LED blinky stuff
reg [25:0] counter;

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        counter <= 0;
    end else begin
        counter <= counter + 1;
    end
end

assign Led = counter[25];

endmodule
