// Phase 3: PicoRV32 + 16 KB RAM @0x0000_0000 + UART @0x1000_0000
//   0x1000_0000 DATA   : write = send byte, read = received byte (clears RX_FULL)
//   0x1000_0004 STATUS : bit0 = TX busy, bit1 = RX full
module top #(parameter HEX = "build/fw.hex") (
    input clk, input uart_rx, output uart_tx, output [5:0] led
);
    // power-on reset, 16 clocks
    reg [3:0] rst_n_cnt = 0;
    wire resetn = &rst_n_cnt;
    always @(posedge clk) if (!resetn) rst_n_cnt <= rst_n_cnt + 1;

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

    reg ready = 0, uart_sel_r = 0;
    wire sel_ram  = mem_addr[31:28] == 4'h0;
    wire sel_uart = mem_addr[31:28] == 4'h1;

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
    reg [7:0] rx_hold; reg rx_full = 0;
    wire uart_go = mem_valid && sel_uart && !ready;
    wire tx_start = uart_go && mem_addr[2] == 0 && |mem_wstrb;
    wire rx_pop   = uart_go && mem_addr[2] == 0 && !mem_wstrb;
    uart_rx rx(.clk(clk), .rx(uart_rx), .valid(rx_v), .data(rx_d));
    uart_tx tx(.clk(clk), .start(tx_start), .data(mem_wdata[7:0]), .tx(uart_tx), .busy(tx_busy));
    always @(posedge clk) begin
        if (rx_v) begin rx_hold <= rx_d; rx_full <= 1; end
        else if (rx_pop) rx_full <= 0;
    end
    wire [31:0] uart_rdata = mem_addr[2] ? {30'b0, rx_full, tx_busy} : {24'b0, rx_hold};

    // ---- bus response: one wait state, data latched at the same edge ----
    always @(posedge clk) begin
        ready <= mem_valid && !ready;
        uart_sel_r <= sel_uart;
    end
    assign mem_ready = ready;
    assign mem_rdata = uart_sel_r ? uart_rdata : ram_rdata;

    // LEDs: heartbeat of CPU activity -> last byte written to UART
    reg [5:0] last = 0;
    always @(posedge clk) if (tx_start) last <= mem_wdata[5:0];
    assign led = ~last;
endmodule
