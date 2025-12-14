module regs (
    // semnale de ceas ale perifericului (intern)
    input clk,
    input rst_n,
    // semnale dinspre decodorul de instructiuni (instr_dcd)
    input read,        // puls de un ciclu CLK pentru operatie de citire
    input write,       // puls de un ciclu CLK pentru operatie de scriere
    input[5:0] addr,     // adresa registrului pe 6 biti (0-63)
    output reg[7:0] data_read, // date citite din registru (furnizate catre decodor)
    input[7:0] data_write, // date de scris in registru (primite de la decodor)
    // semnale de programare a contorului/timerului (iesiri catre logica perifericului)
    input[15:0] counter_val, // Valoarea curenta a contorului (intrare, deoarece este citita)
    output reg[15:0] period, // Valoarea PERIOD (16 biti)
    output reg en,           // Semnal de Activare (Enable) contor
    output reg count_reset,  // Semnal de Reset al contorului (puls de un ciclu)
    output reg upnotdown,    // Directia de numarare (1=Sus, 0=Jos)
    output reg[7:0] prescale, // Valoarea de prescalare (8 biti)
    // valori de programare a semnalului PWM (iesiri catre logica perifericului)
    output reg pwm_en,       // Semnal de Activare (Enable) PWM
    output reg[7:0] functions, // Functiile PWM (bits [1:0] utilizate)
    output reg[15:0] compare1, // Valoarea de comparatie 1 (16 biti)
    output reg[15:0] compare2 // Valoarea de comparatie 2 (16 biti)
);

/*
 Harta de Registre (adresare pe octeti):
 0x00 - PERIOD [15:0] (LSB @0x00, MSB @0x01)
 0x02 - COUNTER_EN (bit0)
 0x03 - COMPARE1 [15:0] (LSB @0x03, MSB @0x04)
 0x05 - COMPARE2 [15:0] (LSB @0x05, MSB @0x06)
 0x07 - COUNTER_RESET (scriere-doar: orice scriere da un puls de reset)
 0x08 - COUNTER_VAL [15:0] (LSB @0x08, MSB @0x09) (citire-doar)
 0x0A - PRESCALE [7:0]
 0x0B - UPNOTDOWN (bit0)
 0x0C - PWM_EN (bit0)
 0x0D - FUNCTIONS [1:0] (bitii [1:0] ai registrului)
*/

reg count_reset_pulse; // Flag intern pentru gestionarea pulsului de reset

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset asincron: initializeaza toate registrele la valori implicite (zero)
        period <= 16'h0000;
        en <= 1'b0;
        compare1 <= 16'h0000;
        compare2 <= 16'h0000;
        prescale <= 8'h00;
        upnotdown <= 1'b1; // Valoare implicita: numarare in sus
        pwm_en <= 1'b0;
        functions <= 8'h00;
        count_reset <= 1'b0;
        count_reset_pulse <= 1'b0;
        data_read <= 8'h00;
    end else begin
        // Seteaza la '0' semnalele puls (impulsuri de un ciclu CLK)
        count_reset <= 1'b0;
        count_reset_pulse <= 1'b0; // Reseteaza flag-ul intern de puls

        // --- GESTIONARE OPERATII DE SCRIERE ---
        if (write) begin
            case (addr)
                6'h00: begin // PERIOD LSB @ 0x00
                    period[7:0] <= data_write;
                end
                6'h01: begin // PERIOD MSB @ 0x01
                    period[15:8] <= data_write;
                end
                6'h02: begin // COUNTER_EN @ 0x02
                    en <= data_write[0]; // Foloseste doar bitul 0
                end
                6'h03: begin // COMPARE1 LSB @ 0x03
                    compare1[7:0] <= data_write;
                end
                6'h04: begin // COMPARE1 MSB @ 0x04
                    compare1[15:8] <= data_write;
                end
                6'h05: begin // COMPARE2 LSB @ 0x05
                    compare2[7:0] <= data_write;
                end
                6'h06: begin // COMPARE2 MSB @ 0x06
                    compare2[15:8] <= data_write;
                end
                6'h07: begin // COUNTER_RESET (Scriere-Doar) @ 0x07
                    // Da un puls de un ciclu CLK catre logica contorului
                    count_reset <= 1'b1;
                    count_reset_pulse <= 1'b1; // Seteaza flag-ul intern (necesar doar pentru debug/test)
                    // Nu se stocheaza nicio valoare (registru scriere-doar)
                end
                // 0x08 si 0x09 sunt citire-doar (ignorat la scriere)
                6'h0A: begin // PRESCALE @ 0x0A
                    prescale <= data_write;
                end
                6'h0B: begin // UPNOTDOWN @ 0x0B
                    upnotdown <= data_write[0]; // Foloseste doar bitul 0
                end
                6'h0C: begin // PWM_EN @ 0x0C
                    pwm_en <= data_write[0]; // Foloseste doar bitul 0
                end
                6'h0D: begin // FUNCTIONS @ 0x0D
                    functions[1:0] <= data_write[1:0]; // Foloseste doar bitii [1:0]
                    functions[7:2] <= 6'b0; // Curata bitii superiori
                end
                default: begin
                    // Scrierile catre adrese neimplementate sunt ignorate
                end
            endcase
        end

        // --- GESTIONARE OPERATII DE CITIRE ---
        // Plaseaza octetul corespunzator adresei pe data_read
        if (read) begin
            case (addr)
                6'h00: data_read <= period[7:0];         // PERIOD LSB
                6'h01: data_read <= period[15:8];        // PERIOD MSB
                6'h02: data_read <= {7'b0, en};          // COUNTER_EN (returneaza bitul 0, restul 0)
                6'h03: data_read <= compare1[7:0];       // COMPARE1 LSB
                6'h04: data_read <= compare1[15:8];      // COMPARE1 MSB
                6'h05: data_read <= compare2[7:0];       // COMPARE2 LSB
                6'h06: data_read <= compare2[15:8];      // COMPARE2 MSB
                6'h07: data_read <= 8'h00;               // COUNTER_RESET (scriere-doar, returneaza 0 la citire)
                6'h08: data_read <= counter_val[7:0];    // COUNTER_VAL LSB (citire-doar)
                6'h09: data_read <= counter_val[15:8];   // COUNTER_VAL MSB (citire-doar)
                6'h0A: data_read <= prescale;            // PRESCALE
                6'h0B: data_read <= {7'b0, upnotdown};   // UPNOTDOWN
                6'h0C: data_read <= {7'b0, pwm_en};      // PWM_EN
                6'h0D: data_read <= {6'b0, functions[1:0]}; // FUNCTIONS (returneaza doar bitii [1:0])
                default: data_read <= 8'h00;             // Adresele neimplementate returneaza 0
            endcase
        end
    end
end

endmodule