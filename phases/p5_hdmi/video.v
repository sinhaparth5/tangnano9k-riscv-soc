// 720x480p60 (CEA-861 VIC 2/3, 27 MHz pixel clock) 90x30 text display, 8x16 font.
// Char RAM is write-only for the CPU: byte at index row*90+col. `voff` rotates the
// displayed rows, so scrolling = bump voff and blank the new bottom row.
module video #(parameter FONT = "phases/p5_hdmi/font.hex") (
    input clk,
    input we, input [11:0] waddr, input [7:0] wdata, input [4:0] voff,
    output reg de = 0, output reg hs = 1, output reg vs = 1, output reg pix = 0
);
    localparam HA = 720, HFP = 16, HSW = 62, HT = 858;
    localparam VA = 480, VFP = 9,  VSW = 6,  VT = 525;

    reg [9:0] x = 0, y = 0;
    always @(posedge clk) begin
        x <= (x == HT-1) ? 0 : x + 1;
        if (x == HT-1) y <= (y == VT-1) ? 0 : y + 1;
    end

    // stage 0: counters -> char address
    wire [4:0] ty = y[8:4];
    wire [5:0] sum = ty + voff;                          // 0..58
    wire [4:0] row = sum >= 30 ? sum - 30 : sum;         // physical row
    wire [11:0] addr = (row << 6) + (row << 4) + (row << 3) + (row << 1) + x[9:3];   // row*90 + col

    reg [2:0] xl1 = 0, xl2 = 0; reg [3:0] yl1 = 0;
    reg [7:0] cram [0:4095];
    reg [7:0] ch = 0;
    reg [7:0] font [0:2047];
    initial $readmemh(FONT, font);
    reg [7:0] fb = 0;

    always @(posedge clk) if (we) cram[waddr] <= wdata;
    always @(posedge clk) ch <= cram[addr];              // stage 1
    always @(posedge clk) fb <= font[{ch[6:0], yl1}];    // stage 2

    // control signals travel with the pixel through the 3 stages
    wire de0 = x < HA && y < VA;
    wire hs0 = !(x >= HA + HFP && x < HA + HFP + HSW);
    wire vs0 = !(y >= VA + VFP && y < VA + VFP + VSW);
    reg [2:0] de_p = 0, hs_p = 3'b111, vs_p = 3'b111;
    always @(posedge clk) begin
        xl1 <= x[2:0]; xl2 <= xl1; yl1 <= y[3:0];
        de_p <= {de_p[1:0], de0}; hs_p <= {hs_p[1:0], hs0}; vs_p <= {vs_p[1:0], vs0};
        pix <= de_p[1] & fb[~xl2];                        // stage 3
        de <= de_p[1]; hs <= hs_p[1]; vs <= vs_p[1];
    end
endmodule
