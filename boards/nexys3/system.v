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


reg  [ 9:0] workcnt;
reg         work_en;
always @(posedge vga_clk or negedge rst_n) begin
    if(~rst_n) begin
        workcnt <= 0;
        work_en <= 0;
    end else begin
        if (CounterX == 1040 & (CounterY[1] == 0)) begin
            workcnt <= 0;
            work_en <= 1;
        end else if(workcnt < 10'h1ff) begin
            workcnt <= workcnt + 1;
            work_en <= 1;
        end else begin
            work_en <= 0;
        end
    end
end


//wire [ 8:0] workX = CounterX[9:1];
wire [ 9:0] workY = CounterY[9:1];
wire        workBank = CounterY[1];

//wire        work_en = workcnt < 10'h200 && CounterY[0] == 1;
wire [ 9:0] work_write_address = {workBank, workcnt[8:0]};


//Get glyph
wire [ 5:0]  glyphX = workcnt[8:3];
wire [ 5:0]  glyphY = workY[8:3];
wire [11:0]  glyphAddr = {glyphY, glyphX};
wire [ 7:0]  currentGlyph;


bram_tdp #( //4K RAM which holds pointer into chardata_ram for 64x64 grid of characters to be displayed
    .DATA_WIDTH(8),
    .ADDR_WIDTH(12),
    .MEM_FILE_NAME("../../data/chars.ram")
) char_ram (
    .a_clk(1'b0),
    .a_ena(1'b0),
    .a_wr(1'b0),
    .a_addr(12'b0),
    .a_din(8'h00),
    .a_dout(),

    .b_clk(vga_clk),
    .b_ena(1'b1),
    .b_wr(1'b0),
    .b_addr(glyphAddr),
    .b_din(8'h00),
    .b_dout(currentGlyph)
);

reg [2:0] _column;
always @(posedge vga_clk)
    _column <= workcnt;

reg [7:0] _glyph;
always @(posedge vga_clk)
    _glyph <= currentGlyph;


wire [11:0] glyphdataaddr =  {currentGlyph, workY[2:0], _column[2]};
wire [ 7:0] charout4;
wire [ 1:0] charout;
//wire [ 7:0] chardataX = workX[8:2];
//wire [11:0] charaddr = workY[9:4] + chardataX;
//wire [1:0]  chardataY = workX[5:4];
//wire [4:0]  charblockDataAddress = {chardataY, chardataY};
bram_tdp #( //4K RAM with pixeldata of glyps, 1 byte holds 4 pixel (index into char color table)
    .DATA_WIDTH(8),
    .ADDR_WIDTH(12),
    .MEM_FILE_NAME("../../data/chardata.ram")
) chardata_ram (
    .a_clk(1'b0),
    .a_ena(1'b0),
    .a_wr(1'b0),
    .a_addr(12'b0),
    .a_din(8'h00),
    .a_dout(),

    .b_clk(vga_clk),
    .b_ena(1'b1),
    .b_wr(1'b0),
    .b_addr(glyphdataaddr),
    .b_din(8'h00),
    .b_dout(charout4)
);

reg [2:0] __column;
always @(posedge vga_clk)
    __column <= _column;

assign charout = __column[1:0] == 2'b00 ? charout4[7:6] :
                 __column[1:0] == 2'b01 ? charout4[5:4] :
                 __column[1:0] == 2'b10 ? charout4[3:2] :
                                          charout4[1:0] ;

/*always @(charout4) begin
    case (charout4)
        2'b00: assign charout = charout4[7:6];
        2'b01: assign charout = charout4[5:4];
        2'b10: assign charout = charout4[3:2];
        2'b11: assign charout = charout4[1:0];
    endcase
end*/



/*bram_tdp #( //2K RAM which holds 4 colors for each possible character (16bit color * 4 colors * 256 chars)
    .DATA_WIDTH(8),
    .ADDR_WIDTH(11),
    .MEM_FILE_NAME("../../data/charpal.ram")
) charpal_ram (
    .a_clk(1'b0),
    .a_ena(1'b1),
    .a_wr(1'b0),
    .a_addr(11'b0),
    .a_din(8'h00),
    .a_dout(),

    .b_clk(vga_clk),
    .b_ena(1'b1),
    .b_wr(1'b0),
    .b_addr(),
    .b_din(8'h00),
    .b_dout()
);*/

wire        scanBank = CounterY[1];
wire [ 8:0] scanX = CounterX[9:1];
wire [ 9:0] scan_read_address = {~scanBank, scanX};

wire [7:0] comp_out;
bram_tdp #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(10),
    .MEM_FILE_NAME("../../data/data.ram")
) line_ram (
    /*.a_clk(vga_clk),
    .a_ena(work_en),
    .a_wr(1'b1),
    .a_addr(work_write_address),
    .a_din({charout, charout, charout, charout}),                  //just for testing
    .a_dout(),*/
    .a_clk(1'b0),
    .a_ena(1'b0),
    .a_wr(1'b0),
    .a_addr(10'b0),
    .a_din(8'b0),
    .a_dout(),

    .b_clk(vga_clk),
    .b_ena(1'b1),
    .b_wr(1'b0),
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
