module spi_bridge (
    // semnale de ceas ale perifericului (intern)
    input clk,
    input rst_n,
    // semnale SPI orientate catre master
    input sclk,
    input cs_n,
    input mosi,
    output miso,
    // interfata interna (catre restul logicii)
    output reg byte_sync, // puls de un ciclu (clk) când un octet a fost primit
    output reg[7:0] data_in, // octetul primit de la master
    input[7:0] data_out // octetul de trimis catre master
);

// Mod SPI: CPOL=0 (Ceas Inactiv Jos), CPHA=0 (Esantionare la Prima Margine)
// - Esantionarea MOSI (intrare) se face pe marginea ascendenta a SCLK. (Masterul plaseaza datele pe marginea descendenta).
// - Schimbarea MISO (iesire) se face pe marginea descendenta a SCLK.
// Implementarea foloseste logica sensibila la muchii în domeniul SCLK pentru a colecta bitii,
// apoi o sincronizare (handshake) în domeniul CLK.
// De asemenea, registrul de shift MISO (shiftr_out_s) este preîncarcat cu data_out
// atunci când cs_n (Chip Select Not) devine activ (low).

reg [2:0] bit_cnt_s;            // contor de biti 0..7 în domeniul SCLK
reg [7:0] shiftr_in_s;          // registrul de shift pentru MOSI (intra MSB primul)
reg [7:0] shiftr_out_s;         // registrul de shift pentru MISO (iese MSB primul)
reg byte_ready_s;               // flag (steag) în domeniul SCLK care indica primirea unui octet complet

// Logica Domeniului SCLK (colectare biti MOSI)
always @(posedge sclk or posedge cs_n) begin
    if (cs_n) begin
        // Resetare la dezactivarea selectarii cipului (cs_n high)
        bit_cnt_s <= 3'd0;
        shiftr_in_s <= 8'h00;
        byte_ready_s <= 1'b0;
    end else begin
        // Esantioneaza MOSI pe marginea ascendenta a SCLK (MSB primul)
        shiftr_in_s <= {shiftr_in_s[6:0], mosi};
        if (bit_cnt_s == 3'd7) begin
            // Ultimul bit a fost esantionat
            bit_cnt_s <= 3'd0;
            byte_ready_s <= 1'b1; // un octet complet este gata (disponibil la urmatoarea marginea ascendenta)
        end else begin
            // Continua sa numere bitii
            bit_cnt_s <= bit_cnt_s + 3'd1;
            byte_ready_s <= 1'b0;
        end
    end
end

// Logica Domeniului SCLK (transmitere biti MISO)
// Schimba MISO pe marginea descendenta a SCLK (datele se schimba pentru ca masterul sa le esantioneze pe marginea ascendenta)
reg miso_r;
assign miso = miso_r; // MISO este o simpla iesire de registru

always @(negedge sclk or posedge cs_n) begin
    if (cs_n) begin
        // Resetare la dezactivarea selectarii cipului (cs_n high)
        miso_r <= 1'b0;
        shiftr_out_s <= 8'h00;
    end else begin
        // Schimba în afara (shift out) MSB primul
        miso_r <= shiftr_out_s[7];
        shiftr_out_s <= {shiftr_out_s[6:0], 1'b0};
    end
end

// Preîncarcare MISO shift register (shiftr_out_s) la începutul tranzactiei
reg cs_n_d;
// Sincronizeaza cs_n în domeniul clk pentru detectarea frontului
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cs_n_d <= 1'b1;
    else cs_n_d <= cs_n;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // nimic la reset
    end else begin
        // Detecteaza marginea descendenta a cs_n (începutul tranzactiei) în domeniul clk
        if (cs_n_d == 1'b1 && cs_n == 1'b0) begin
            // Începutul tranzactiei (cs_n a cazut)
            // Preîncarca registrul de shift MISO cu data_out.
            // Deoarece clk si sclk sunt sincrone, scrierea directa în registrul din domeniul sclk (shiftr_out_s)
            // este acceptabila aici, desi un mecanism de sincronizare mai formal ar fi ideal într-un caz general.
            // Acest lucru seteaza datele pentru a fi scoase la prima negedge SCLK.
            shiftr_out_s <= data_out;
            // Seteaza imediat primul bit de iesire MISO (MSB), care va fi valabil pâna la prima negedge sclk
            miso_r <= data_out[7]; 
        end
    end
end

// Handshake de la domeniul SCLK (byte_ready_s) la domeniul CLK pentru a produce byte_sync si data_in
// Sincronizator simplu: detecteaza frontul lui byte_ready_s esantionându-l de doua ori în domeniul clk. 
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
        // Sincronizeaza flag-ul din domeniul sclk în domeniul clk
        byte_ready_s_sync1 <= byte_ready_s;
        byte_ready_s_sync2 <= byte_ready_s_sync1;

        // Detectarea marginii ascendente a semnalului sincronizat (indicatie de byte_ready primit)
        if (byte_ready_s_sync2 & ~byte_ready_s_clkprev) begin
            // Latch (memoreaza) octetul primit din registrul de shift din domeniul sclk.
            // Aici, shiftr_in_s este citit direct, ceea ce este acceptabil datorita
            // presupunerii de ceasuri sincrone (conform descrierii).
            data_in <= shiftr_in_s;
            byte_sync <= 1'b1; // Activam pulsul de sincronizare
        end else begin
            byte_sync <= 1'b0;
        end

        byte_ready_s_clkprev <= byte_ready_s_sync2;
    end
end

endmodule