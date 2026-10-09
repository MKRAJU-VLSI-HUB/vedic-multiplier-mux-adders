`timescale 1ns / 1ps
// =============================================================================
// vedic_multiplier.v -- 16x16 Urdhva Tiryagbhyam (vertical & crosswise)
// multiplier built hierarchically 2x2 -> 4x4 -> 8x8 -> 16x16 (paper Fig. 1).
//
// Every level splits a = {aH,aL}, b = {bH,bL} and forms four half-size
// products in parallel:
//     q0 = aL*bL   q1 = aH*bL   q2 = aL*bH   q3 = aH*bH
//     a*b = q0 + (q1 + q2) << H + q3 << 2H
//
// ADDER selects how the partial products are summed (paper Sec. III-B/C):
//   "RCA" : MUX-based ripple-carry adders, as in Fig. 1
//             s1 = q1 + q2                         (RCA, carry c1)
//             s2 = s1 + q0[2H-1:H]                 (RCA, carry c2)
//             {t1,t0} = c1 + c2                    (half adder)
//             hi = q3 + {t1, t0, s2[2H-1:H]}       (RCA)
//             p  = {hi, s2[H-1:0], q0[H-1:0]}
//   "CSA" : MUX-based carry-save adder + one final MUX-RCA
//             {s,c} = CSA({q3,q0}, q1<<H, q2<<H)   (no carry propagation)
//             p     = s + (c << 1)                 (RCA)
// =============================================================================

// 2x2 Vedic block: AND gates and half adders, all realised with MUXes
module vedic_2x2 (
    input  wire [1:0] a,
    input  wire [1:0] b,
    output wire [3:0] p
);
    wire a0b0, a1b0, a0b1, a1b1, c1;
    // AND(x, y) = MUX(sel=x, d0=0, d1=y)
    mux2 u_and00 (.d0(1'b0), .d1(b[0]), .s(a[0]), .y(a0b0));
    mux2 u_and10 (.d0(1'b0), .d1(b[0]), .s(a[1]), .y(a1b0));
    mux2 u_and01 (.d0(1'b0), .d1(b[1]), .s(a[0]), .y(a0b1));
    mux2 u_and11 (.d0(1'b0), .d1(b[1]), .s(a[1]), .y(a1b1));

    assign p[0] = a0b0;
    mux_half_adder u_ha1 (.a(a1b0), .b(a0b1), .sum(p[1]), .cout(c1));
    mux_half_adder u_ha2 (.a(a1b1), .b(c1),   .sum(p[2]), .cout(p[3]));
endmodule


// Combines the four (2H)-bit partial products of one level into a 4H-bit product
module vedic_combine #(
    parameter H     = 2,          // half of the operand width at this level
    parameter ADDER = "RCA"       // "RCA" or "CSA"
)(
    input  wire [2*H-1:0] q0,
    input  wire [2*H-1:0] q1,
    input  wire [2*H-1:0] q2,
    input  wire [2*H-1:0] q3,
    output wire [4*H-1:0] p
);
    generate
        if (ADDER == "CSA") begin : g_csa
            wire [4*H-1:0] w = {q3, q0};
            wire [4*H-1:0] y = {{H{1'b0}}, q1, {H{1'b0}}};
            wire [4*H-1:0] z = {{H{1'b0}}, q2, {H{1'b0}}};
            wire [4*H-1:0] s, c;
            wire           unused_cout;

            mux_csa #(.N(4*H)) u_csa (.x(w), .y(y), .z(z), .s(s), .c(c));
            mux_rca #(.N(4*H)) u_rca (.a(s), .b({c[4*H-2:0], 1'b0}), .cin(1'b0),
                                      .sum(p), .cout(unused_cout));
        end else begin : g_rca
            wire [2*H-1:0] s1, s2, hi, mid;
            wire           c1, c2, t0, t1, unused_cout;

            mux_rca #(.N(2*H)) u_rca1 (.a(q1), .b(q2), .cin(1'b0),
                                       .sum(s1), .cout(c1));
            mux_rca #(.N(2*H)) u_rca2 (.a(s1), .b({{H{1'b0}}, q0[2*H-1:H]}), .cin(1'b0),
                                       .sum(s2), .cout(c2));
            mux_half_adder     u_ha   (.a(c1), .b(c2), .sum(t0), .cout(t1));

            assign mid = {t1, t0, s2[2*H-1:H]};          // zero-extended to 2H bits
            mux_rca #(.N(2*H)) u_rca3 (.a(q3), .b(mid), .cin(1'b0),
                                       .sum(hi), .cout(unused_cout));

            assign p = {hi, s2[H-1:0], q0[H-1:0]};
        end
    endgenerate
endmodule


module vedic_4x4 #(parameter ADDER = "RCA") (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [7:0] p
);
    wire [3:0] q0, q1, q2, q3;
    vedic_2x2 u_q0 (.a(a[1:0]), .b(b[1:0]), .p(q0));
    vedic_2x2 u_q1 (.a(a[3:2]), .b(b[1:0]), .p(q1));
    vedic_2x2 u_q2 (.a(a[1:0]), .b(b[3:2]), .p(q2));
    vedic_2x2 u_q3 (.a(a[3:2]), .b(b[3:2]), .p(q3));
    vedic_combine #(.H(2), .ADDER(ADDER)) u_sum (.q0(q0), .q1(q1), .q2(q2), .q3(q3), .p(p));
endmodule


module vedic_8x8 #(parameter ADDER = "RCA") (
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    output wire [15:0] p
);
    wire [7:0] q0, q1, q2, q3;
    vedic_4x4 #(.ADDER(ADDER)) u_q0 (.a(a[3:0]), .b(b[3:0]), .p(q0));
    vedic_4x4 #(.ADDER(ADDER)) u_q1 (.a(a[7:4]), .b(b[3:0]), .p(q1));
    vedic_4x4 #(.ADDER(ADDER)) u_q2 (.a(a[3:0]), .b(b[7:4]), .p(q2));
    vedic_4x4 #(.ADDER(ADDER)) u_q3 (.a(a[7:4]), .b(b[7:4]), .p(q3));
    vedic_combine #(.H(4), .ADDER(ADDER)) u_sum (.q0(q0), .q1(q1), .q2(q2), .q3(q3), .p(p));
endmodule


module vedic_16x16 #(parameter ADDER = "RCA") (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [31:0] p
);
    wire [15:0] q0, q1, q2, q3;
    vedic_8x8 #(.ADDER(ADDER)) u_q0 (.a(a[7:0]),  .b(b[7:0]),  .p(q0));
    vedic_8x8 #(.ADDER(ADDER)) u_q1 (.a(a[15:8]), .b(b[7:0]),  .p(q1));
    vedic_8x8 #(.ADDER(ADDER)) u_q2 (.a(a[7:0]),  .b(b[15:8]), .p(q2));
    vedic_8x8 #(.ADDER(ADDER)) u_q3 (.a(a[15:8]), .b(b[15:8]), .p(q3));
    vedic_combine #(.H(8), .ADDER(ADDER)) u_sum (.q0(q0), .q1(q1), .q2(q2), .q3(q3), .p(p));
endmodule
