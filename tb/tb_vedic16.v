`timescale 1ns / 1ps
// =============================================================================
// tb_vedic16.v -- self-checking testbench for the 16-bit Vedic multiplier
//                 with MUX-based RCA and MUX-based CSA (both checked vs a*b)
//
//  Phase 0  (0-200 ns)  20 directed vectors held 10 ns each  -> waveform view
//  Phase 1  MUX half / full adder           : exhaustive
//  Phase 2  vedic 2x2, 4x4, 8x8 (RCA & CSA)  : exhaustive (8x8 = 65,536 pairs)
//  Phase 3  vedic 16x16 (RCA & CSA)          : corners, walking ones,
//                                              200,000 random vectors
//  Phase 4  registered top (vedic16_top)     : 2-cycle pipeline, 500 vectors
// =============================================================================
module tb_vedic16;

    // ---------------- DUTs -------------------------------------------------
    reg  [15:0] a, b;
    wire [31:0] p_rca, p_csa;
    wire [31:0] p_expected = a * b;

    vedic_16x16 #(.ADDER("RCA")) dut_rca (.a(a), .b(b), .p(p_rca));
    vedic_16x16 #(.ADDER("CSA")) dut_csa (.a(a), .b(b), .p(p_csa));

    // sub-blocks for exhaustive checks
    reg  [7:0] a8, b8;
    wire [15:0] p8_rca, p8_csa;
    vedic_8x8 #(.ADDER("RCA")) dut8_rca (.a(a8), .b(b8), .p(p8_rca));
    vedic_8x8 #(.ADDER("CSA")) dut8_csa (.a(a8), .b(b8), .p(p8_csa));

    reg  [3:0] a4, b4;
    wire [7:0] p4_rca, p4_csa;
    vedic_4x4 #(.ADDER("RCA")) dut4_rca (.a(a4), .b(b4), .p(p4_rca));
    vedic_4x4 #(.ADDER("CSA")) dut4_csa (.a(a4), .b(b4), .p(p4_csa));

    reg  [1:0] a2, b2;
    wire [3:0] p2;
    vedic_2x2 dut2 (.a(a2), .b(b2), .p(p2));

    reg  fa_a, fa_b, fa_c;
    wire fa_s, fa_co, ha_s, ha_co;
    mux_full_adder dut_fa (.a(fa_a), .b(fa_b), .cin(fa_c), .sum(fa_s), .cout(fa_co));
    mux_half_adder dut_ha (.a(fa_a), .b(fa_b), .sum(ha_s), .cout(ha_co));

    // registered top-level wrappers
    reg         clk = 1'b0;
    reg  [15:0] ta, tb;
    wire [31:0] tp_rca, tp_csa;
    vedic16_top #(.ADDER("RCA")) top_rca (.clk(clk), .a(ta), .b(tb), .p(tp_rca));
    vedic16_top #(.ADDER("CSA")) top_csa (.clk(clk), .a(ta), .b(tb), .p(tp_csa));

    // ---------------- bookkeeping -----------------------------------------
    integer errors = 0;
    integer checks = 0;
    integer i, j, k, seed;
    reg [31:0] exp32;
    reg [15:0] pipe_a [0:1];
    reg [15:0] pipe_b [0:1];

    task check16;   // compare both 16x16 variants against a*b
        begin
            #1;
            checks = checks + 1;
            exp32 = a * b;
            if (p_rca !== exp32 || p_csa !== exp32) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  FAIL 16x16 a=%h b=%h  rca=%h csa=%h  exp=%h",
                             a, b, p_rca, p_csa, exp32);
            end
        end
    endtask

    // ---------------- stimulus ----------------------------------------------
    reg [15:0] demo_a [0:19];
    reg [15:0] demo_b [0:19];

    initial begin
        seed = 32'h1EEE_2026;
        $display("==============================================================");
        $display(" 16-bit Vedic multiplier (Urdhva Tiryagbhyam) - MUX RCA & CSA");
        $display("==============================================================");

        // ---- Phase 0: demo vectors for the waveform -----------------------
        demo_a[0]=16'd0;     demo_b[0]=16'd0;
        demo_a[1]=16'd1;     demo_b[1]=16'd1;
        demo_a[2]=16'd12;    demo_b[2]=16'd13;
        demo_a[3]=16'd255;   demo_b[3]=16'd255;
        demo_a[4]=16'd1000;  demo_b[4]=16'd2000;
        demo_a[5]=16'd1234;  demo_b[5]=16'd5678;
        demo_a[6]=16'hFFFF;  demo_b[6]=16'h0001;
        demo_a[7]=16'hFFFF;  demo_b[7]=16'hFFFF;
        demo_a[8]=16'h8000;  demo_b[8]=16'h8000;
        demo_a[9]=16'hAAAA;  demo_b[9]=16'h5555;
        demo_a[10]=16'd300;  demo_b[10]=16'd400;
        demo_a[11]=16'd65000;demo_b[11]=16'd3;
        demo_a[12]=16'h00FF; demo_b[12]=16'hFF00;
        demo_a[13]=16'd4096; demo_b[13]=16'd16;
        demo_a[14]=16'd9999; demo_b[14]=16'd9999;
        demo_a[15]=16'h1234; demo_b[15]=16'h5678;
        demo_a[16]=16'd777;  demo_b[16]=16'd0;
        demo_a[17]=16'd32767;demo_b[17]=16'd2;
        demo_a[18]=16'd50000;demo_b[18]=16'd50000;
        demo_a[19]=16'hC3A5; demo_b[19]=16'h7E81;

        $display("\nPhase 0 : directed vectors");
        $display("      a       b    |   MUX-RCA      MUX-CSA      expected  ");
        for (i = 0; i < 20; i = i + 1) begin
            a = demo_a[i]; b = demo_b[i];
            #5;
            $display("  %6d  %6d  | %10d   %10d   %10d  %s", a, b, p_rca, p_csa, p_expected,
                     (p_rca === p_expected && p_csa === p_expected) ? "PASS" : "FAIL");
            checks = checks + 1;
            if (p_rca !== p_expected || p_csa !== p_expected) errors = errors + 1;
            #5;
        end

        // ---- Phase 1: MUX adders exhaustive ------------------------------
        for (i = 0; i < 8; i = i + 1) begin
            {fa_a, fa_b, fa_c} = i[2:0];
            #1; checks = checks + 2;
            if ({fa_co, fa_s} !== fa_a + fa_b + fa_c) begin
                errors = errors + 1; $display("  FAIL full adder %b", i[2:0]);
            end
            if ({ha_co, ha_s} !== fa_a + fa_b) begin
                errors = errors + 1; $display("  FAIL half adder %b", i[1:0]);
            end
        end
        $display("\nPhase 1 : MUX half/full adder exhaustive  -> errors so far %0d", errors);

        // ---- Phase 2: 2x2, 4x4, 8x8 exhaustive ---------------------------
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a2 = i; b2 = j; #1; checks = checks + 1;
                if (p2 !== i * j) begin errors = errors + 1; $display("  FAIL 2x2 %0d*%0d=%0d", i, j, p2); end
            end
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a4 = i; b4 = j; #1; checks = checks + 1;
                if (p4_rca !== i * j || p4_csa !== i * j) begin
                    errors = errors + 1;
                    $display("  FAIL 4x4 %0d*%0d rca=%0d csa=%0d", i, j, p4_rca, p4_csa);
                end
            end
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 256; j = j + 1) begin
                a8 = i; b8 = j; #1; checks = checks + 1;
                if (p8_rca !== i * j || p8_csa !== i * j) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("  FAIL 8x8 %0d*%0d rca=%0d csa=%0d", i, j, p8_rca, p8_csa);
                end
            end
        $display("Phase 2 : 2x2 / 4x4 / 8x8 exhaustive       -> errors so far %0d", errors);

        // ---- Phase 3: 16x16 ----------------------------------------------
        // corners
        for (i = 0; i < 8; i = i + 1)
            for (j = 0; j < 8; j = j + 1) begin
                case (i)
                    0: a = 16'h0000; 1: a = 16'h0001; 2: a = 16'h00FF; 3: a = 16'hFF00;
                    4: a = 16'h7FFF; 5: a = 16'h8000; 6: a = 16'hAAAA; default: a = 16'hFFFF;
                endcase
                case (j)
                    0: b = 16'h0000; 1: b = 16'h0001; 2: b = 16'h00FF; 3: b = 16'hFF00;
                    4: b = 16'h7FFF; 5: b = 16'h8000; 6: b = 16'h5555; default: b = 16'hFFFF;
                endcase
                check16;
            end
        // walking ones / all-ones partner
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = 16'h1 << i; b = 16'h1 << j; check16;
                a = 16'hFFFF;   b = 16'h1 << j; check16;
            end
        // random
        for (k = 0; k < 200000; k = k + 1) begin
            a = $random(seed); b = $random(seed); check16;
        end
        $display("Phase 3 : 16x16 corners + walking-1 + 200k random -> errors so far %0d", errors);

        // ---- Phase 4: registered top, 2-cycle latency ---------------------
        ta = 0; tb = 0;
        repeat (3) begin #5 clk = 1; #5 clk = 0; end
        for (k = 0; k < 500; k = k + 1) begin
            pipe_a[1] = pipe_a[0]; pipe_b[1] = pipe_b[0];
            pipe_a[0] = ta;        pipe_b[0] = tb;
            #5 clk = 1; #1;
            if (k >= 2) begin
                checks = checks + 1;
                if (tp_rca !== pipe_a[1] * pipe_b[1] || tp_csa !== pipe_a[1] * pipe_b[1]) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("  FAIL top %h*%h rca=%h csa=%h", pipe_a[1], pipe_b[1], tp_rca, tp_csa);
                end
            end
            #4 clk = 0;
            ta = $random(seed); tb = $random(seed);
        end
        $display("Phase 4 : registered top (2-cycle latency)  -> errors so far %0d", errors);

        $display("\n==============================================================");
        $display(" checks : %0d", checks);
        if (errors == 0) $display(" ALL TESTS PASSED  (MUX-RCA and MUX-CSA match a*b)");
        else             $display(" TESTS FAILED : %0d errors", errors);
        $display("==============================================================");
        #10;   // short pause so a GUI run can stop with the summary on screen
        $finish;
    end

endmodule
