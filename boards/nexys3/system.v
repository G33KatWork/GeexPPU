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
    .counterY(CounterY),
    .lineStart(vga_lineStart),
    .frameStart(vga_frameStart)
);

wire        work_en;
reg  [ 8:0] workX;
reg  [ 8:0] workY;


parameter s_lineWorking = 0;
parameter s_waitForLineEnd = 1;
parameter s_waitOneLine = 2;
parameter s_waitForFrameStart = 3;

reg  [ 1:0] coordState;
reg  [ 1:0] coordState_next;

//Statemachine for rendering process
always @(posedge vga_clk or negedge rst_n) begin
    if(~rst_n) begin
        coordState <= s_lineWorking;
        coordState_next <= s_lineWorking;

        workX <= 0;
        workY <= 1;
    end else begin
        case(coordState)
            s_lineWorking: begin
                if(workX < 10'd400+3) begin             //Render 400 pixel (+3 for 3 pipeline stages)
                    workX <= workX + 1;
                    coordState <= s_lineWorking;
                end else begin                          //Done with 400 pixel rendering, wait for line end
                    workX <= 0;
                    coordState <= s_waitForLineEnd;
                end
            end

            s_waitForLineEnd: begin
                if(vga_lineStart == 1) begin            //New line starts, we need to wait another one
                    coordState <= s_waitOneLine;
                end else begin
                    coordState <= s_waitForLineEnd;
                end
            end

            s_waitOneLine: begin
                if(vga_lineStart == 1 && workY < 9'd299) begin  //Line finished, start rendering next line
                    workY <= workY + 1;
                    coordState <= s_lineWorking;
                end else if(vga_lineStart == 1)
                    coordState <= s_waitForFrameStart;
                else
                    coordState <= s_waitOneLine;
            end

            s_waitForFrameStart: begin                  //Wait until one line before new frame start to render line 0 into RAM
                if(CounterY == 665 && CounterX == 0) begin
                    workY <= 0;
                    coordState <= s_lineWorking;
                end else
                    coordState <= s_waitForFrameStart;
            end
        endcase
    end
end

assign work_en = coordState == s_lineWorking;

wire        workBank = workY[0];
wire [ 9:0] work_write_address = {workBank, workX[8:0]} - 3;      //-3: 3 pipeline stages for background rendering


//Registers for general control
reg  [14:0] bgColor = 15'h19DD; //light blue
reg  [ 8:0] scrollX = 9'h1;
reg  [ 8:0] scrollY = 9'h0;

wire [ 8:0] workXScrolled = workX + scrollX;
wire [ 8:0] workYScrolled = workY + scrollY;

//Get glyph
wire [ 5:0]  glyphX = workXScrolled[8:3];
wire [ 5:0]  glyphY = workYScrolled[8:3];
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
    _column <= workXScrolled[2:0];

reg [7:0] _glyph;
always @(posedge vga_clk)
    _glyph <= currentGlyph;


wire [11:0] glyphdataaddr =  {currentGlyph, workYScrolled[2:0], _column[2]};
wire [ 7:0] charout4;
wire [ 1:0] charout;
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


wire [ 9:0] palletteaddress = {_glyph, charout};
wire [15:0] coloredcharout;
bram_tdp #( //2K RAM which holds 4 colors for each possible character (16bit color * 4 colors * 256 chars)
    .DATA_WIDTH(16),
    .ADDR_WIDTH(10),
    .MEM_FILE_NAME("../../data/charpal.ram")
) charpal_ram (
    .a_clk(1'b0),
    .a_ena(1'b1),
    .a_wr(1'b0),
    .a_addr(10'b0),
    .a_din(16'h00),
    .a_dout(),

    .b_clk(vga_clk),
    .b_ena(1'b1),
    .b_wr(1'b0),
    .b_addr(palletteaddress),
    .b_din(16'h00),
    .b_dout(coloredcharout)
);




//compose the final color to be put into the compositing RAM
wire        pixelTransparent = coloredcharout[15];
wire [14:0] finalColor = pixelTransparent ? bgColor : coloredcharout[14:0];

//VGA scanner for output on lines to the VGA port
wire        scanBank = CounterY[1];
wire [ 8:0] scanX = CounterX[9:1];
wire [ 9:0] scan_read_address = {scanBank, scanX};

wire [14:0] comp_out;
bram_tdp #(
    .DATA_WIDTH(15),
    .ADDR_WIDTH(10)
) line_ram (
    .a_clk(vga_clk),
    .a_ena(work_en),
    .a_wr(1'b1),
    .a_addr(work_write_address),
    .a_din(finalColor),                  //just for testing
    .a_dout(),

    .b_clk(vga_clk),
    .b_ena(1'b1),
    .b_wr(1'b0),
    .b_addr(scan_read_address),
    .b_din(15'h00),
    .b_dout(comp_out)
);

wire [4:0] color_r = comp_out[14:10];
wire [4:0] color_g = comp_out[9:5];
wire [4:0] color_b = comp_out[4:0];

`define ENABLE_DITHERING
`ifdef ENABLE_DITHERING
    //dithering blatantly taken from the Gameduino ;)
    wire [1:0] dith;
    // 0 2
    // 3 1
    assign dith = {(CounterX[0]^CounterY[0]), CounterY[0]};
    wire [5:0] dith_r = (color_r + dith);
    wire [5:0] dith_g = (color_g + dith);
    wire [5:0] dith_b = (color_b + dith);
    wire [2:0] f_r = {3{dith_r[5]}} | dith_r[4:2];
    wire [2:0] f_g = {3{dith_g[5]}} | dith_g[4:2];
    wire [1:0] f_b = {2{dith_b[5]}} | dith_b[4:3];

    assign vgaRed = vga_active ? f_r : 3'b0;
    assign vgaGreen = vga_active ? f_g : 3'b0;
    assign vgaBlue = vga_active ? f_b : 2'b0;
`else
    assign vgaRed = vga_active ? color_r[4:2] : 3'b0;
    assign vgaGreen = vga_active ? color_g[4:2] : 3'b0;
    assign vgaBlue = vga_active ? color_b[4:3] : 2'b0;
`endif


//scroll test
reg [23:0] scrollCounter;
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        scrollCounter <= 0;
    end else begin
        scrollCounter <= scrollCounter + 1;
    end
end

always @(posedge clk) begin
    if(scrollCounter[19:0] == 0)
        scrollX <= scrollX + 1;

    if(scrollCounter[23:0] == 0)
        scrollY <= scrollY + 1;
end



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
