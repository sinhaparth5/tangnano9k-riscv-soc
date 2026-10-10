// Phase 4: Phase 3 + xorshift accelerator @0x2000_0000
//   0x1000_0000 DATA   : write = send byte, read = received byte (clears RX_FULL)
//   0x1000_0004 STATUS : bit0 = TX busy, bit1 = RX full
module top #(parameter HEX = "build/fw.hex") (
    input clk, input btn_s1, input uart_rx, output uart_tx, output [5:0] led
);
    // reset: power-on, or while S1 is held (active-low button); 16 clocks after release
    reg [1:0] btn_s = 2'b11;
    reg [3:0] rst_n_cnt = 0;
    wire resetn = &rst_n_cnt;
    always @(posedge clk) begin
        btn_s <= {btn_s[0], btn_s1};
        if (!btn_s[1]) rst_n_cnt <= 0;
        else if (!resetn) rst_n_cnt <= rst_n_cnt + 1;
    end

    wire        mem_valid;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;
    wire        mem_ready;

    picorv32 #(
        .ENABLE_MUL(1), .ENABLE_DIV(1), .COMPRESSED_ISA(1),
        .PROGADDR_RESET(32'h0), .STACKADDR(32'h0000_4000)
    ) cpu (
        .clk(clk), .resetn(resetn),
        .mem_valid(mem_valid), .mem_ready(mem_ready), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata)
    );

    reg ready = 0, uart_sel_r = 0, acc_sel_r = 0;
    wire sel_ram  = mem_addr[31:28] == 4'h0;
    wire sel_uart = mem_addr[31:28] == 4'h1;
    wire sel_acc  = mem_addr[31:28] == 4'h2;

    // ---- RAM: 32-bit words with per-byte write enables ----
    reg [31:0] mem [0:4095];
    initial $readmemh(HEX, mem);
    wire [11:0] wa = mem_addr[13:2];
    wire ram_go = mem_valid && sel_ram && !ready;
    reg [31:0] ram_rdata;
    always @(posedge clk) if (ram_go) begin
        if (mem_wstrb[0]) mem[wa][7:0]   <= mem_wdata[7:0];
        if (mem_wstrb[1]) mem[wa][15:8]  <= mem_wdata[15:8];
        if (mem_wstrb[2]) mem[wa][23:16] <= mem_wdata[23:16];
        if (mem_wstrb[3]) mem[wa][31:24] <= mem_wdata[31:24];
        ram_rdata <= mem[wa];
    end

    // ---- UART ----
    wire rx_v; wire [7:0] rx_d; wire tx_busy;
    // 64-byte RX FIFO so pasted text isn't lost while the CPU is busy
    reg [7:0] fifo [0:63]; reg [5:0] wp = 0, rp = 0;
    wire rx_full = wp != rp;
    wire uart_go = mem_valid && sel_uart && !ready;
    wire tx_start = uart_go && mem_addr[2] == 0 && |mem_wstrb;
    wire rx_pop   = uart_go && mem_addr[2] == 0 && !mem_wstrb && rx_full;
    uart_rx rx(.clk(clk), .rx(uart_rx), .valid(rx_v), .data(rx_d));
    uart_tx tx(.clk(clk), .start(tx_start), .data(mem_wdata[7:0]), .tx(uart_tx), .busy(tx_busy));
    // ponytail: overflow drops newest byte silently; 64 B covers a pasted line
    always @(posedge clk) begin
        if (rx_v && (wp + 6'd1 != rp)) begin fifo[wp] <= rx_d; wp <= wp + 1; end
        if (rx_pop) rp <= rp + 1;
    end
    // latched on the request cycle: rp advances right after it
    reg [31:0] uart_rdata;
    always @(posedge clk) if (uart_go)
        uart_rdata <= mem_addr[2] ? {30'b0, rx_full, tx_busy} : {24'b0, fifo[rp]};

    // ---- accelerator ----
    wire [31:0] acc_rdata;
    accel acc(.clk(clk), .go(mem_valid && sel_acc && !ready), .we(|mem_wstrb),
              .reg_i(mem_addr[4:2]), .wdata(mem_wdata), .rdata(acc_rdata));

    // ---- bus response: one wait state, data latched at the same edge ----
    always @(posedge clk) begin
        ready <= mem_valid && !ready;
        uart_sel_r <= sel_uart;
        acc_sel_r <= sel_acc;
    end
    assign mem_ready = ready;
    assign mem_rdata = uart_sel_r ? uart_rdata : acc_sel_r ? acc_rdata : ram_rdata;

    // LEDs: heartbeat of CPU activity -> last byte written to UART
    reg [5:0] last = 0;
    always @(posedge clk) if (tx_start) last <= mem_wdata[5:0];
    assign led = ~last;
endmodule
