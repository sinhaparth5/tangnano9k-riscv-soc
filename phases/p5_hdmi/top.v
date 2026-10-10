// Phase 5 board top: PLL (27 -> 135 MHz), /5 divider -> 27 MHz pixel clock, TMDS serializers.
// ponytail: board-only primitives, not simulated; check on hardware.
module top(
    input clk, input btn_s1, input uart_rx, output uart_tx, output [5:0] led,
    output tmds_clk_p, output tmds_clk_n, output [2:0] tmds_d_p, output [2:0] tmds_d_n
);
    wire clk_ser, lock, clk_pix;
    // 27 MHz * (4+1) / (0+1) = 135 MHz; VCO = 135 * ODIV(4) = 540 MHz
    rPLL #(
        .FCLKIN("27"), .DEVICE("GW1NR-9C"),
        .IDIV_SEL(0), .FBDIV_SEL(4), .ODIV_SEL(4),
        .DYN_IDIV_SEL("false"), .DYN_FBDIV_SEL("false"), .DYN_ODIV_SEL("false"),
        .PSDA_SEL("0000"), .DYN_DA_EN("false"), .DUTYDA_SEL("1000"),
        .CLKOUT_FT_DIR(1'b1), .CLKOUTP_FT_DIR(1'b1), .CLKOUT_DLY_STEP(0), .CLKOUTP_DLY_STEP(0),
        .CLKFB_SEL("internal"), .CLKOUT_BYPASS("false"), .CLKOUTP_BYPASS("false"), .CLKOUTD_BYPASS("false"),
        .DYN_SDIV_SEL(2), .CLKOUTD_SRC("CLKOUT"), .CLKOUTD3_SRC("CLKOUT")
    ) pll (
        .CLKIN(clk), .CLKFB(1'b0), .RESET(1'b0), .RESET_P(1'b0),
        .FBDSEL(6'b0), .IDSEL(6'b0), .ODSEL(6'b0), .PSDA(4'b0), .DUTYDA(4'b0), .FDLY(4'b0),
        .CLKOUT(clk_ser), .LOCK(lock), .CLKOUTP(), .CLKOUTD(), .CLKOUTD3()
    );
    CLKDIV #(.DIV_MODE("5"), .GSREN("false")) div5 (.CLKOUT(clk_pix), .HCLKIN(clk_ser), .RESETN(lock), .CALIB(1'b0));

    wire vde, vhs, vvs, vpix;
    soc cpu_soc(.clk(clk_pix), .pll_lock(lock), .btn_s1(btn_s1), .uart_rx(uart_rx), .uart_tx(uart_tx),
                .led(led), .vid_de(vde), .vid_hs(vhs), .vid_vs(vvs), .vid_pix(vpix));

    // white text on black; control bits (hsync/vsync) ride on channel 0 (blue)
    wire [7:0] v = {8{vpix}};
    wire [9:0] t0, t1, t2;
    tmds_enc e0(.clk(clk_pix), .d(v), .c({vvs, vhs}), .de(vde), .q(t0));
    tmds_enc e1(.clk(clk_pix), .d(v), .c(2'b00),      .de(vde), .q(t1));
    tmds_enc e2(.clk(clk_pix), .d(v), .c(2'b00),      .de(vde), .q(t2));

    wire [3:0] ser;                               // serial outputs: ch0, ch1, ch2, clock
    OSER10 o0(.Q(ser[0]), .D0(t0[0]), .D1(t0[1]), .D2(t0[2]), .D3(t0[3]), .D4(t0[4]), .D5(t0[5]), .D6(t0[6]), .D7(t0[7]), .D8(t0[8]), .D9(t0[9]), .PCLK(clk_pix), .FCLK(clk_ser), .RESET(~lock));
    OSER10 o1(.Q(ser[1]), .D0(t1[0]), .D1(t1[1]), .D2(t1[2]), .D3(t1[3]), .D4(t1[4]), .D5(t1[5]), .D6(t1[6]), .D7(t1[7]), .D8(t1[8]), .D9(t1[9]), .PCLK(clk_pix), .FCLK(clk_ser), .RESET(~lock));
    OSER10 o2(.Q(ser[2]), .D0(t2[0]), .D1(t2[1]), .D2(t2[2]), .D3(t2[3]), .D4(t2[4]), .D5(t2[5]), .D6(t2[6]), .D7(t2[7]), .D8(t2[8]), .D9(t2[9]), .PCLK(clk_pix), .FCLK(clk_ser), .RESET(~lock));
    OSER10 oc(.Q(ser[3]), .D0(1'b1), .D1(1'b1), .D2(1'b1), .D3(1'b1), .D4(1'b1), .D5(1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0), .D9(1'b0), .PCLK(clk_pix), .FCLK(clk_ser), .RESET(~lock));

    ELVDS_OBUF b0(.I(ser[0]), .O(tmds_d_p[0]), .OB(tmds_d_n[0]));
    ELVDS_OBUF b1(.I(ser[1]), .O(tmds_d_p[1]), .OB(tmds_d_n[1]));
    ELVDS_OBUF b2(.I(ser[2]), .O(tmds_d_p[2]), .OB(tmds_d_n[2]));
    ELVDS_OBUF bc(.I(ser[3]), .O(tmds_clk_p), .OB(tmds_clk_n));
endmodule
