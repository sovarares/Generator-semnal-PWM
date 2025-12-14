module spi_bridge (
    // semnale de ceas ale perifericului (intern)
    input clk,
    input rst_n,
    // semnale SPI orientate catre master
    input sclk,
    input cs_n,
    input mosi,
    output miso,
    // interfata interna
    output reg byte_sync,   // Semnal de sincronizare
    output reg[7:0] data_in, // Date primite de la master (MOSI -> Bridge -> Decoder)
    input[7:0] data_out      // Date de trimis la master (Decoder -> Bridge -> MISO)
);

// Registre interne pentru domeniul SCLK
reg [2:0] bit_cnt_s;
reg [7:0] shiftr_in_s;
reg [7:0] shiftr_out_s;
reg byte_ready_s;

// --- Colectare date MOSI (Domeniul SCLK) ---
always @(posedge sclk or posedge cs_n) begin
    if (cs_n) begin
        bit_cnt_s <= 3'd0;
        shiftr_in_s <= 8'h00;
        byte_ready_s <= 1'b0;
    end else begin
        shiftr_in_s <= {shiftr_in_s[6:0], mosi};
        if (bit_cnt_s == 3'd7) begin
            bit_cnt_s <= 3'd0;
            byte_ready_s <= 1'b1; 
        end else begin
            bit_cnt_s <= bit_cnt_s + 3'd1;
            byte_ready_s <= 1'b0;
        end
    end
end

// --- Transmitere date MISO (Domeniul SCLK) ---
reg miso_r;
assign miso = miso_r;

always @(negedge sclk or posedge cs_n) begin
    if (cs_n) begin
        miso_r <= 1'b0;
        shiftr_out_s <= 8'h00;
    end else begin
        miso_r <= shiftr_out_s[7];
        shiftr_out_s <= {shiftr_out_s[6:0], 1'b0};
    end
end

// --- Preincarcare MISO la inceputul tranzactiei (Domeniul CLK -> SCLK) ---
reg cs_n_d;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cs_n_d <= 1'b1;
    else cs_n_d <= cs_n;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset
    end else begin
        // Detectare falling edge CS_N
        if (cs_n_d == 1'b1 && cs_n == 1'b0) begin
            shiftr_out_s <= data_out; // Incarcacarea datelor de la decoder
            miso_r <= data_out[7];    // Setarea primului bit
        end
    end
end

// --- Sincronizare si Byte Sync (Domeniul SCLK -> CLK) ---
reg byte_ready_s_sync1, byte_ready_s_sync2;
reg byte_ready_s_clkprev;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        byte_ready_s_sync1 <= 1'b0;
        byte_ready_s_sync2 <= 1'b0;
        byte_ready_s_clkprev <= 1'b0;
        byte_sync <= 1'b0;
        data_in <= 8'h00;
    end else begin
        byte_ready_s_sync1 <= byte_ready_s;
        byte_ready_s_sync2 <= byte_ready_s_sync1;

        if (byte_ready_s_sync2 & ~byte_ready_s_clkprev) begin
            data_in <= shiftr_in_s; // Transferul datele primite catre decoder
            byte_sync <= 1'b1;
        end else begin
            byte_sync <= 1'b0;
        end
        byte_ready_s_clkprev <= byte_ready_s_sync2;
    end
end

endmodule