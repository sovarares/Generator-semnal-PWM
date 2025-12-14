module pwm_gen (
    // semnale de ceas ale perifericului
    input clk,
    input rst_n,
    // configuratia registrelor de semnal PWM
    input pwm_en,            
    input[15:0] period,      
    input[7:0] functions,    
    input[15:0] compare1,    
    input[15:0] compare2,    
    input[15:0] count_val,   
    // semnalul PWM de iesire
    output reg pwm_out       
);

// Decodificarea modurilor
wire aligned_mode = (functions[1] == 1'b0); // 1 = Unaligned, 0 = Aligned
wire left_align   = (functions[0] == 1'b0); // 0 = Left, 1 = Right

// Detectare wrap (cand contorul ajunge la valoarea maxima)
wire is_wrap = (count_val == period); 

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pwm_out <= 1'b0;
    end else if (pwm_en) begin
        if (aligned_mode) begin

            if (left_align) begin
                // Left Align: High la start, Low dupa Compare1
                
                // Fix Test 5: Daca Compare1 e 0, duty cycle e 0%
                if (compare1 == 16'h0000) begin
                    pwm_out <= 1'b0;
                end else begin
                    // La wrap fortam 1 pentru a prinde primul ciclu
                    if (is_wrap) 
                        pwm_out <= 1'b1;
                    // Mentinem 1 cat timp suntem sub prag
                    else if (count_val < compare1) 
                        pwm_out <= 1'b1;
                    else 
                        pwm_out <= 1'b0;
                end
            end else begin
                // Right Align: Low la start, High dupa Compare1
                // Folosim >= pentru a include ultimul ciclu
                if (count_val >= compare1)
                    pwm_out <= 1'b1;
                else
                    pwm_out <= 1'b0;
            end
        end else begin


            if (compare1 >= compare2) begin
                pwm_out <= 1'b0;
            end else begin
                // Configuratie valida:
                
                // 1. Resetam la wrap (inceput de perioada curat)
                if (is_wrap) 
                    pwm_out <= 1'b0;

                // 2. Setam 1 cand atingem Compare1
                if (count_val == compare1) 
                    pwm_out <= 1'b1;
                
                // 3. Setam 0 cand atingem Compare2
                if (count_val == compare2) 
                    pwm_out <= 1'b0;
            end
        end
    end
end

endmodule