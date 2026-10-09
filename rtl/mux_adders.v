`timescale 1ns / 1ps
// =============================================================================
// mux_adders.v -- MUX-based adder cells used by the 16-bit Vedic multiplier
//
// Paper: "Implementation of 16-Bit Vedic Multiplier using MUX-Based Adders",
//        ICICIT-2026, DOI 10.1109/ICICIT69063.2026.11634241
//
//   mux2            : 2:1 multiplexer, the only logic primitive used below
//   mux_half_adder  : half adder from 2 MUXes
//   mux_full_adder  : full adder from 3 MUXes                    (paper Fig. 3)
//   mux_rca         : N-bit ripple-carry adder of MUX full adders (paper Fig. 4)
//   mux_csa         : N-bit 3:2 carry-save stage of MUX full adders (paper Fig. 5)
// =============================================================================

module mux2 (
    input  wire d0,
    input  wire d1,
    input  wire s,
    output wire y
);
    assign y = s ? d1 : d0;
endmodule


// sum  = a ^ b  -> MUX(sel=a, d0=b, d1=~b)
// cout = a & b  -> MUX(sel=a, d0=0, d1=b)
module mux_half_adder (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire cout
);
    mux2 u_sum  (.d0(b),    .d1(~b), .s(a), .y(sum));
    mux2 u_cout (.d0(1'b0), .d1(b),  .s(a), .y(cout));
endmodule


// p    = a ^ b        -> MUX(sel=a, d0=b,  d1=~b)
// sum  = p ^ cin      -> MUX(sel=p, d0=cin, d1=~cin)
// cout = p ? cin : a  -> MUX(sel=p, d0=a,  d1=cin)
module mux_full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);
    wire p;
    mux2 u_xor  (.d0(b),   .d1(~b),   .s(a), .y(p));
    mux2 u_sum  (.d0(cin), .d1(~cin), .s(p), .y(sum));
    mux2 u_cout (.d0(a),   .d1(cin),  .s(p), .y(cout));
endmodule


// N-bit ripple-carry adder: chain of MUX full adders
module mux_rca #(
    parameter N = 16
)(
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    input  wire         cin,
    output wire [N-1:0] sum,
    output wire         cout
);
    wire [N:0] c;
    assign c[0] = cin;

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : g_fa
            mux_full_adder u_fa (.a(a[i]), .b(b[i]), .cin(c[i]),
                                 .sum(sum[i]), .cout(c[i+1]));
        end
    endgenerate

    assign cout = c[N];
endmodule


// N-bit carry-save stage: reduces three operands to sum + carry vectors
// with no carry propagation (x + y + z == s + (c << 1)).
module mux_csa #(
    parameter N = 16
)(
    input  wire [N-1:0] x,
    input  wire [N-1:0] y,
    input  wire [N-1:0] z,
    output wire [N-1:0] s,
    output wire [N-1:0] c
);
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : g_fa
            mux_full_adder u_fa (.a(x[i]), .b(y[i]), .cin(z[i]),
                                 .sum(s[i]), .cout(c[i]));
        end
    endgenerate
endmodule
