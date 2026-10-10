// DVI/TMDS 8b/10b encoder, one pixel per clock, registered output.
// c = {C1,C0} control bits sent while de=0 (blue channel: {vsync,hsync}).
module tmds_enc(input clk, input [7:0] d, input [1:0] c, input de, output reg [9:0] q = 0);
    function [3:0] ones8(input [7:0] v); integer i; begin
        ones8 = 0; for (i = 0; i < 8; i = i + 1) ones8 = ones8 + v[i];
    end endfunction

    wire [3:0] n1d = ones8(d);
    wire use_xnor = (n1d > 4) || (n1d == 4 && !d[0]);
    reg [8:0] qm;
    integer i;
    always @* begin
        qm[0] = d[0];
        for (i = 1; i < 8; i = i + 1) qm[i] = use_xnor ? ~(qm[i-1] ^ d[i]) : (qm[i-1] ^ d[i]);
        qm[8] = ~use_xnor;
    end

    wire signed [4:0] n1q = ones8(qm[7:0]);
    wire signed [4:0] n0q = 5'sd8 - n1q;
    reg signed [5:0] cnt = 0;                  // running disparity

    always @(posedge clk)
        if (!de) begin
            cnt <= 0;
            case (c)
                2'b00: q <= 10'b1101010100;
                2'b01: q <= 10'b0010101011;
                2'b10: q <= 10'b0101010100;
                2'b11: q <= 10'b1010101011;
            endcase
        end else if (cnt == 0 || n1q == n0q) begin
            q <= {~qm[8], qm[8], qm[8] ? qm[7:0] : ~qm[7:0]};
            cnt <= qm[8] ? cnt + n1q - n0q : cnt + n0q - n1q;
        end else if ((cnt > 0 && n1q > n0q) || (cnt < 0 && n0q > n1q)) begin
            q <= {1'b1, qm[8], ~qm[7:0]};
            cnt <= cnt + (qm[8] ? 6'sd2 : 6'sd0) + n0q - n1q;
        end else begin
            q <= {1'b0, qm[8], qm[7:0]};
            cnt <= cnt - (qm[8] ? 6'sd0 : 6'sd2) + n1q - n0q;
        end
endmodule
