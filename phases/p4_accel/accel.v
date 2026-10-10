// xorshift32 accelerator. Runs N steps at one step per clock.
//   0x00 X      rw  state / result
//   0x04 N      w   step count
//   0x08 CTRL   w   bit0 = start
//   0x0C STATUS r   bit0 = busy
module accel(
    input clk, input go, input we, input [2:0] reg_i, input [31:0] wdata,
    output [31:0] rdata
);
    reg [31:0] x = 1, n = 0; reg busy = 0;
    wire [31:0] a = x ^ (x << 13), b = a ^ (a >> 17), c = b ^ (b << 5);
    assign rdata = reg_i[1] ? {31'b0, busy} : x;      // 0x0C status, else X
    always @(posedge clk)
        if (busy) begin
            if (n == 0) busy <= 0;
            else begin x <= c; n <= n - 1; end
        end else if (go && we) case (reg_i)
            3'd0: x <= wdata;
            3'd1: n <= wdata;
            3'd2: busy <= wdata[0];
        endcase
endmodule
