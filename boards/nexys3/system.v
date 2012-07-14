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

wire        vga_clk;
wire        vga_active;
wire [10:0] CounterX;
wire [ 9:0] CounterY;

vga_sync sync (
    .clk(clk),
    .rst_n(rst_n),

    .pixelclock(vga_clk),
    .hsync(Hsync),
    .vsync(Vsync),
    .displayactive(vga_active),
    .counterX(CounterX),
    .counterY(CounterY)
);

wire [10:0] xx = CounterX;
wire        comp_read = CounterY[1];
wire [ 8:0] comp_scanout = xx[9:1];
wire [ 9:0] ram_read_address = {!comp_read, comp_scanout};

wire [7:0] comp_out;
bram_tdp #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(10),
    .MEM_FILE_NAME("../../data/data.ram")
) line_ram (
    .a_clk(0),
    .a_wr(0),
    .a_addr(10'b0),
    .a_din(8'h00),
    .a_dout(),

    .b_clk(vga_clk),
    .b_wr(0),
    .b_addr(ram_read_address),
    .b_din(8'h00),
    .b_dout(comp_out)
);

assign vgaRed = vga_active ? comp_out[7:5] : 3'b0;
assign vgaGreen = vga_active ? comp_out[4:2] : 3'b0;
assign vgaBlue = vga_active ? comp_out[1:0] : 2'b0;

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
