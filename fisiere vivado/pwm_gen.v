module pwm_gen (
    // semnale de ceas ale perifericului
    input clk,
    input rst_n,
    // configuratia registrelor de semnal PWM
    input pwm_en,            // Activare PWM (enable)
    input[15:0] period,      // Valoarea limita a contorului (pentru detectarea wrap-ului)
    input[7:0] functions,    // Biti de control pentru mod (Aligned/Unaligned, Left/Right Align)
    input[15:0] compare1,    // Valoare de Comparatie 1 (Edge de schimbare)
    input[15:0] compare2,    // Valoare de Comparatie 2 (Edge de schimbare, folosita in Unaligned)
    input[15:0] count_val,   // Valoarea curenta a contorului (din modulul counter)
    // semnalul PWM de iesire
    output reg pwm_out       // Iesirea PWM
);

// Semnificatia bitilor functions (conform documentatiei):
// functions[0] -> aliniere stanga (0) / aliniere dreapta (1)
// functions[1] -> aliniat (0) / nealiniat (1)

// Abordarea implementarii:
// - Urmarim valoarea anterioara a contorului (prev_count) pentru a detecta evenimentul de wrap (overflow/underflow).

reg [15:0] prev_count; // Valoarea contorului din ciclul anterior
wire is_wrap;          // Semnal de wrap (contorul a trecut de la limita la 0, sau invers)

// Detectarea wrap-ului:
// Se intampla cand (prev_count == period SI current_count == 0) (cazul numararii in sus)
// SAU cand (prev_count == 0 SI current_count == period) (cazul numararii in jos)
assign is_wrap = (prev_count == period && count_val == 16'h0000) ||
                 (prev_count == 16'h0000 && count_val == period);

wire aligned_mode = (functions[1] == 1'b0); // Mod Aligned (functions[1] = 0)
wire left_align = (functions[0] == 1'b0);   // Aliniere Stanga (functions[0] = 0)

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pwm_out <= 1'b0;
        prev_count <= 16'h0000;
    end else begin
        // Stocheaza valoarea curenta a contorului pentru a o folosi in ciclul urmator pentru detectia wrap-ului
        prev_count <= count_val;

        if (!pwm_en) begin
            // Daca PWM este dezactivat, iesirea ramane in starea sa curenta (linia "blocata")
            pwm_out <= pwm_out; 
        end else begin
            if (aligned_mode) begin
                // --- MODUL ALIGNED (functions[1] = 0) ---
                // Foloseste un singur registru de comparatie (compare1) si genereaza un semnal centrat sau aliniat la stanga/dreapta.
                
                if (is_wrap) begin
                    // Reinitializarea la marginea perioadei (wrap)
                    if (left_align) 
                        // Aliniere Stanga (Left Align): porneste HIGH la inceputul perioadei
                        pwm_out <= 1'b1; 
                    else 
                        // Aliniere Dreapta (Right Align): porneste LOW la inceputul perioadei
                        pwm_out <= 1'b0; 
                end else begin
                    // Toggle cand se atinge compare1
                    if (count_val == compare1) begin
                        pwm_out <= ~pwm_out; // Inversarea starii
                    end
                end
            end else begin
                // --- MODUL UNALIGNED (functions[1] = 1) ---
                // Foloseste compare1 pentru a seta iesirea HIGH si compare2 pentru a o seta LOW.
                // Se presupune ca PWM-ul porneste de la 0.
                
                // Ne asiguram ca compare1 < compare2 pentru o operatie logica (pulsul HIGH trebuie sa inceapa inainte de a se termina)
                if (compare1 < compare2) begin
                    if (count_val == compare1) begin
                        // La atingerea compare1: Setare HIGH
                        pwm_out <= 1'b1;
                    end
                    if (count_val == compare2) begin
                        // La atingerea compare2: Setare LOW
                        pwm_out <= 1'b0;
                    end
                    // Daca are loc un wrap, nu este necesara nicio actiune speciala de reinitializare,
                    // deoarece PWM-ul este controlat de potrivirile de comparatie.
                end else begin
                    // Ordine de comparatie invalida: iesirea isi mentine starea curenta (comportament neprecizat)
                    pwm_out <= pwm_out;
                end
            end
        end
    end
end

endmodule