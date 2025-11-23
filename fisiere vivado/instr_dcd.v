module instr_dcd (
    // semnale de ceas ale perifericului (intern)
    input clk,
    input rst_n,
    // semnale dinspre interfata SPI slave (de la spi_bridge)
    input byte_sync,   // puls de un ciclu CLK care indica primirea unui octet nou
    input[7:0] data_in, // octetul primit de la SPI master
    output reg[7:0] data_out, // octetul de trimis înapoi catre SPI master (pentru citire)
    // semnale de acces la registru intern
    output reg read,     // puls de un ciclu CLK pentru citire
    output reg write,    // puls de un ciclu CLK pentru scriere
    output reg[5:0] addr, // adresa pe 6 biti (0-63)
    input[7:0] data_read,  // date citite de la adresa addr (din registrul intern)
    output reg[7:0] data_write // date de scris la adresa addr
);

// Automat de Stari Finite (FSM) de decodare a instructiunilor:
// - Operatie în Doua Faze:
//   1) Faza de Setup (primul octet): [7]=R/W, [6]=High/Low (selectare octet), [5:0]=Adresa
//   2) Faza de Date (al doilea octet): fie payload-ul de scriere, fie octetul de citire este transmis de spi_bridge.
//
// Comportament:
// - La receptia unui octet de setup, memoram R/W, HL ?si Adresa.
// - Dac? este o Citire (R/W=0), trebuie sa plasam data_read (pentru adresa respectivs) pe data_out
//   pentru ca spi_bridge sa poata scoate (shift out) în ciclul urmator.
// - Daca este o Scriere (R/W=1), asteptam octetul de date, iar la urmatorul byte_sync (al doilea octet)
//   assertam write pentru un ciclu clk împreuna cu data_write si addr.

reg state_setup;    // 0 = asteapta octetul de setup (comanda), 1 = asteapta octetul de date (payload)
reg rw;             // 1 = Scriere, 0 = Citire
reg hl;             // 1 = octetul superior ([15:8]), 0 = octetul inferior ([7:0])
reg [5:0] addr_latched; // Adresa memorata din octetul de setup

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset asincron
        state_setup <= 1'b0;      // Începem în starea Setup
        rw <= 1'b0;
        hl <= 1'b0;
        addr_latched <= 6'b0;
        read <= 1'b0;
        write <= 1'b0;
        addr <= 6'b0;
        data_write <= 8'h00;
        data_out <= 8'h00; // Valoare implicita de iesire
    end else begin
        // Seteaza pulsul de citire/scriere la '0' implicit (impuls de un ciclu)
        read <= 1'b0;
        write <= 1'b0;

        if (byte_sync) begin
            // Un octet nou a sosit de la interfata SPI
            if (state_setup == 1'b0) begin
                // --- FAZA 1: SETUP (Comanda) ---
                // Memoram biti de control
                rw <= data_in[7];
                hl <= data_in[6];
                addr_latched <= data_in[5:0];
                addr <= data_in[5:0]; // Seteaza adresa pentru a preselecta datele
                
                if (data_in[7] == 1'b0) begin
                    // --- Operatie de Citire (R/W = 0) ---
                    // Trebuie sa furnizam octetul pe data_out imediat pentru a fi scos (shift out)
                    // în timpul ciclului SPI al octetului de date.
                    // data_read este deja valabil de la adresa setata.
                    data_out <= data_read;
                    // Assertam read pentru un ciclu (optional, dar util pentru sincronizarea registrelor)
                    read <= 1'b1;
                    // Trecem la starea de date (pentru octetul dummy de la master si scosul datelor)
                    state_setup <= 1'b1;
                end else begin
                    // --- Operatie de Scriere (R/W = 1) ---
                    // Aateptam octetul urmator care va contine payload-ul de scriere
                    state_setup <= 1'b1;
                    // Nu assertam scrierea înca.
                    // Seteaza data_out la 0 (sau o valoare sigura)
                    data_out <= 8'h00;
                end
            end else begin
                // --- FAZA 2: DATE (Payload) ---
                if (rw == 1'b1) begin
                    // --- Operatie de Scriere (R/W = 1) ---
                    // Assertam write pentru un ciclu cu adresa si datele de payload
                    addr <= addr_latched;
                    data_write <= data_in; // Acesta este octetul payload sosit
                    write <= 1'b1;
                end else begin
                    // --- Operatie de Citire (R/W = 0) ---
                    // Masterul a transferat octetul data_out în ciclul SPI anterior.
                    // data_in în acest ciclu este doar un octet dummy de la master. Nicio actiune necesara.
                end
                // Revenim la asteptarea unui nou octet de setup (finalul tranzactiei)
                state_setup <= 1'b0;
            end
        end
    end
end

endmodule