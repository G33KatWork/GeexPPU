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

wire [ 8:0] workX = CounterX[9:1];
wire [ 9:0] workY = CounterY;
wire        workBank = CounterY[0];
wire        work_en = CounterX < 11'h400 && CounterY < 11'h400;
wire [ 9:0] work_write_address = {workBank, workX};

//4K RAM which holds pointer into chardata_ram for 64x64 grid of characters to be displayed
bram_tdp #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(12),
    .MEM_FILE_NAME("../../data/chars.ram")
) char_ram (
    .a_clk(0),
    .a_ena(1),
    .a_wr(0),
    .a_addr(12'b0),
    .a_din(8'h00),
    .a_dout(),

    .b_clk(vga_clk),
    .b_ena(1),
    .b_wr(0),
    .b_addr(12'b0),
    .b_din(8'h00),
    .b_dout()
);

//4K RAM with pixeldata of glyps, 1 byte holds 4 pixel (index into char color table)
bram_tdp #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(12),
    .MEM_FILE_NAME("../../data/chardata.ram")
) chardata_ram (
    .a_clk(0),
    .a_ena(1),
    .a_wr(0),
    .a_addr(12'b0),
    .a_din(8'h00),
    .a_dout(),

    .b_clk(vga_clk),
    .b_ena(1),
    .b_wr(0),
    .b_addr(12'b0),
    .b_din(8'h00),
    .b_dout()
);

//2K RAM which holds 4 colors for each possible character (16bit color * 4 colors * 256 chars)
//only 8 bit for colors used currently, bit 9 = transparency
bram_tdp #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(11),
    .MEM_FILE_NAME("../../data/charpal.ram")
) charpal_ram (
    .a_clk(0),
    .a_ena(1),
    .a_wr(0),
    .a_addr(11'b0),
    .a_din(8'h00),
    .a_dout(),

    .b_clk(vga_clk),
    .b_ena(1),
    .b_wr(0),
    .b_addr(11'b0),
    .b_din(8'h00),
    .b_dout()
);

wire        scanBank = CounterY[0];
wire [ 8:0] scanX = CounterX[9:1];
wire [ 9:0] scan_read_address = {~scanBank, scanX};

wire [7:0] comp_out;
bram_tdp #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(10),
    .MEM_FILE_NAME("../../data/data.ram")
) line_ram (
    .a_clk(vga_clk),
    .a_ena(work_en),
    .a_wr(1),
    .a_addr(work_write_address),
    .a_din(work_write_address[7:0]),                  //just for testing
    .a_dout(),

    .b_clk(vga_clk),
    .b_ena(1),
    .b_wr(0),
    .b_addr(scan_read_address),
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
