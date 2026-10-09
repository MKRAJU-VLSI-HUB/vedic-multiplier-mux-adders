`timescale 1ns / 1ps
// =============================================================================
// vedic16_top.v -- synthesis top: registers around the combinational multiplier
// so Vivado reports a real register-to-register delay for the multiplier.
//
//   ADDER = "RCA" | "CSA" : Vedic multiplier with MUX-based adders (the paper)
//   ADDER = "BASE"        : reference, Vivado's own a*b mapped to LUTs (no DSP)
// =============================================================================
module vedic16_top #(
    parameter ADDER = "RCA"
)(
    input  wire        clk,
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [31:0] p
);
    reg  [15:0] a_r, b_r;
    wire [31:0] p_w;

    generate
        if (ADDER == "BASE") begin : g_base
            (* use_dsp = "no" *) wire [31:0] prod = a_r * b_r;
            assign p_w = prod;
        end else begin : g_vedic
            vedic_16x16 #(.ADDER(ADDER)) u_mul (.a(a_r), .b(b_r), .p(p_w));
        end
    endgenerate

    always @(posedge clk) begin
        a_r <= a;
        b_r <= b;
        p   <= p_w;
    end
endmodule
