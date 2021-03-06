// A parameterized, inferable, true dual-port, dual-clock block RAM in Verilog.

module bram_tdp #(
    parameter DATA_WIDTH = 72,
    parameter ADDR_WIDTH = 10,
    parameter MEM_FILE_NAME = "none"
) (
    // Port A
    input   wire                  a_clk,
    input   wire                  a_ena,
    input   wire                  a_wr,
    input   wire [ADDR_WIDTH-1:0] a_addr,
    input   wire [DATA_WIDTH-1:0] a_din,
    output  reg  [DATA_WIDTH-1:0] a_dout,

    // Port B
    input   wire                  b_clk,
    input   wire                  b_ena,
    input   wire                  b_wr,
    input   wire [ADDR_WIDTH-1:0] b_addr,
    input   wire [DATA_WIDTH-1:0] b_din,
    output  reg  [DATA_WIDTH-1:0] b_dout
);

// Shared memory
reg [DATA_WIDTH-1:0] mem [(2**ADDR_WIDTH)-1:0];

// Port A
always @(posedge a_clk) begin
    if(a_ena) begin
        a_dout      <= mem[a_addr];
        if(a_wr) begin
            a_dout      <= a_din;
            mem[a_addr] <= a_din;
        end
    end
end

// Port B
always @(posedge b_clk) begin
    if(b_ena) begin
        b_dout      <= mem[b_addr];
        if(b_wr) begin
            b_dout      <= b_din;
            mem[b_addr] <= b_din;
        end
    end
end

initial
begin
    if (MEM_FILE_NAME != "none")
    begin
        $readmemh(MEM_FILE_NAME, mem);
    end
end

endmodule
