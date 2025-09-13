/*
 * Copyright (c) 2025 Your Name
 *
 * Module: fir_filter
 * Description: A parameterizable N-tap pipelined FIR filter based on a
 * high-performance parallel architecture. This structural implementation
 * is designed for high throughput in DSP applications.
 *
 * Parameters:
 * TAPS        - Number of filter taps (N). Must be a power of 2.
 * DATA_WIDTH  - Width of input data.
 * COEFF_WIDTH - Width of filter coefficients.
 */

module fir_filter #(
    parameter TAPS        = 8,   // Number of filter taps (N) - Must be a power of 2
    parameter DATA_WIDTH  = 16,  // Width of input/output data
    parameter COEFF_WIDTH = 16   // Width of filter coefficients
) (
    input clk,
    input rst_n,
    input signed [DATA_WIDTH-1:0] data_in,
    output signed [DATA_WIDTH + COEFF_WIDTH + $clog2(TAPS) - 1:0] data_out
);

    // --- Sanity Checks for Parameters ---
    initial begin
        if ((TAPS & (TAPS - 1)) != 0 || TAPS == 0) begin
             $display("ERROR: TAPS parameter must be a power of 2 for this architecture.");
             $finish;
        end
    end

    // Calculate intermediate and final widths
    localparam PRODUCT_WIDTH = DATA_WIDTH + COEFF_WIDTH;
    localparam ACCUM_WIDTH   = PRODUCT_WIDTH + $clog2(TAPS);

    // Filter coefficients (can be made inputs for reconfigurability)
    // Example: 8-tap Low-Pass Filter Coefficients
    localparam signed [COEFF_WIDTH-1:0] COEFFS [0:TAPS-1] = '{
        16'h000A, 16'h0019, 16'h0032, 16'h004B, 16'h004B, 16'h0032, 16'h0019, 16'h000A
    };

    // --- Pipeline Stage 0: Input Delay Line ---
    // This stage creates the delayed versions of the input signal x[n-k]
    reg signed [DATA_WIDTH-1:0] delay_line [0:TAPS-1];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < TAPS; i = i + 1) begin
                delay_line[i] <= 0;
            end
        end else begin
            delay_line[0] <= data_in;
            for (i = 1; i < TAPS; i = i + 1) begin
                delay_line[i] <= delay_line[i-1];
            end
        end
    end

    // --- Pipeline Stage 1: Parallel Multiplication ---
    // Synthesis tools infer efficient multiplier architectures (like Booth) from '*'.
    reg signed [PRODUCT_WIDTH-1:0] mul_products [0:TAPS-1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < TAPS; i = i + 1) begin
                mul_products[i] <= 0;
            end
        end else begin
            for (i = 0; i < TAPS; i = i + 1) begin
                mul_products[i] <= delay_line[i] * COEFFS[i];
            end
        end
    end

    // --- Pipeline Stages 2 & beyond: Hierarchical Adder Tree ---
    // This structurally implements the adder tree to sum the products from all taps.
    genvar stage, adder_idx;
    generate
        // Multi-dimensional array to hold intermediate results of the adder tree.
        // Dimension 1: pipeline stage
        // Dimension 2: value within that stage
        reg signed [ACCUM_WIDTH-1:0] adder_tree [0:$clog2(TAPS)][0:TAPS-1];

        // Connect multiplier outputs to the input of the adder tree
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for(i=0; i<TAPS; i=i+1)
                    adder_tree[0][i] <= 0;
            end else begin
                for(i=0; i<TAPS; i=i+1)
                    adder_tree[0][i] <= mul_products[i];
            end
        end

        // Build the pipelined adder tree
        for (stage = 0; stage < $clog2(TAPS); stage = stage + 1) begin : tree_stages
            localparam num_adders_in_stage = TAPS >> (stage + 1);
            localparam num_inputs_to_stage = TAPS >> stage;

            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    // Reset the outputs of this stage
                    for(adder_idx=0; adder_idx < (TAPS >> (stage+1)); adder_idx=adder_idx+1)
                        adder_tree[stage+1][adder_idx] <= 0;
                end else begin
                    // Perform additions for the current stage
                    for (adder_idx = 0; adder_idx < num_adders_in_stage; adder_idx = adder_idx + 1) begin
                        adder_tree[stage+1][adder_idx] <= adder_tree[stage][2*adder_idx] + adder_tree[stage][2*adder_idx+1];
                    end
                end
            end
        end
    endgenerate

    // Final result is at the output of the last stage of the adder tree
    assign data_out = adder_tree[$clog2(TAPS)][0];

endmodule
