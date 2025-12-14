module counter (
    // semnale de ceas ale perifericului
    input clk,
    input rst_n,
    // semnale dinspre registrele de control
    output reg[15:0] count_val, // Valoarea curenta a contorului (citita de registru)
    input[15:0] period,        // Valoarea maxima/finala de numarare (limita de wrap)
    input en,                  // Semnal de activare a contorului (enable)
    input count_reset,         // Puls de resetare a contorului (sincron)
    input upnotdown,           // Directia de numarare (1=Sus, 0=Jos)
    input[7:0] prescale        // Valoarea de prescalare (exponentiala)
);

//
// Comportament:
// - Cand en==0, contorul isi mentine valoarea.
// - Pulsul count_reset reseteaza contorul la 0 imediat.
// - prescale codifica scalarea putere-a-doi: incrementarea are loc la fiecare 2^prescale cicluri CLK.
//   Exemplu: prescale=0 rightarrow incrementare la fiecare CLK, prescale=1 rightarrow la fiecare 2 CLK, prescale=2 rightarrow la fiecare 4 CLK.
//
// - Wrap-around (Intoarcere):
//   * Daca numara in sus ($upnotdown=1): cand count_val == period si este timpul sa avanseze rightarrow revine la 0.
//   * Daca numara in jos ($upnotdown=0): cand count_val == 0 si este timpul sa avanseze rightarrow revine la period.
//

// Contor mic de prescalare
reg [31:0] presc_cnt; // Suficient de lat pentru a tine 2^prescale (max 2^255 teoretic, dar prescale este pe 8 biti)
reg presc_tick;       // Puls de un ciclu CLK care semnaleaza ca este timpul pentru o avansare a contorului

// Logica Prescaler-ului
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        presc_cnt <= 32'd0;
        presc_tick <= 1'b0;
    end else begin
        presc_tick <= 1'b0; // Reseteaza pulsul implicit la 0
        if (!en) begin
            // Nu avanseaza prescaler-ul cand este dezactivat; il tine resetat la 0
            presc_cnt <= 32'd0;
        end else begin
            // Calculeaza perioada de prescalare: 2^prescale
            // Verifica daca contorul a atins limita (2^prescale - 1)
            // Nota: (32'd1 << prescale) este echivalent cu 2^prescale
            if (presc_cnt >= (32'd1 << prescale) - 1) begin
                presc_cnt <= 32'd0;        // Resetarea prescaler-ului
                presc_tick <= 1'b1;        // E timpul sa avanseze contorul principal cu 1
            end else begin
                presc_cnt <= presc_cnt + 32'd1; // Incrementarea prescaler-ului
            end
        end
    end
end

// Logica Contorului Principal (16 biti)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count_val <= 16'h0000; // Resetare la 0
    end else begin
        if (count_reset) begin
            // Reset de urgenta (pulsat)
            count_val <= 16'h0000;
        end else if (en && presc_tick) begin
            // Avansam contorul doar daca este activat (en=1) SI s-a generat un tick de la prescaler
            if (upnotdown) begin
                // --- Numarare in Sus (upnotdown = 1) ---
                if (count_val >= period) begin
                    // Wrap: daca valoarea a atins sau depasit PERIOD
                    count_val <= 16'h0000; // Revine la 0
                end else begin
                    count_val <= count_val + 16'h0001; // Incrementare normala
                end
            end else begin
                // --- Numarare in Jos (upnotdown = 0) ---
                if (count_val == 16'h0000) begin
                    // Underflow: daca valoarea a atins 0
                    count_val <= period; // Revine la PERIOD
                end else begin
                    count_val <= count_val - 16'h0001; // Decrementare normala
                end
            end
        end else begin
            // Daca nu este reset, nu este activat, sau nu a sosit tick-ul prescaler-ului
            count_val <= count_val; // Mentine valoarea curenta
        end
    end
end

endmodule