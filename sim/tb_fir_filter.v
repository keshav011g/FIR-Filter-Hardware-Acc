/*
 * Module: tb_fir_filter
 * Description: A self-checking testbench for the parameterizable pipelined
 * FIR filter. It verifies the DUT's output against a behavioral golden
 * reference model.
 */

`timescale 1ns/1ps

module tb_fir_filter;

    // --- Parameters (Must match the DUT) ---
    localparam TAPS        = 8;
    localparam DATA_WIDTH  = 16;
    localparam COEFF_WIDTH = 16;
    localparam CLK_PERIOD  = 10; // 100 MHz clock

    // Calculate total pipeline latency
    localparam LATENCY = 2 + $clog2(TAPS);

    // Calculate output width
    localparam OUTPUT_WIDTH = DATA_WIDTH + COEFF_WIDTH + $clog2(TAPS);

    // --- Testbench Signals ---
    reg clk;
    reg rst_n;
    reg signed [DATA_WIDTH-1:0] dut_data_in;
    wire signed [OUTPUT_WIDTH-1:0] dut_data_out;

    // --- Golden Reference Model Signals ---
    reg signed [DATA_WIDTH-1:0]  golden_delay_line [0:TAPS-1];
    reg signed [OUTPUT_WIDTH-1:0] golden_data_out;
    reg signed [OUTPUT_WIDTH-1:0] delayed_golden_out [0:LATENCY-1];
    integer i;

    // --- Instantiate the Design Under Test (DUT) ---
    fir_filter #(
        .TAPS(TAPS),
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(dut_data_in),
        .data_out(dut_data_out)
    );

    // --- Clock and Reset Generation ---
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        $display("Starting simulation...");
        rst_n = 1'b0; // Assert reset
        dut_data_in = 0;
        #(CLK_PERIOD * 2);
        rst_n = 1'b1; // De-assert reset
    end

    // --- Golden Reference Model (Behavioral, Non-Pipelined) ---
    // This model calculates the mathematically correct output on every cycle.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            golden_data_out <= 0;
            for (i = 0; i < TAPS; i = i + 1) begin
                golden_delay_line[i] <= 0;
            end
        end else begin
            // Shift data into the golden delay line
            golden_delay_line[0] <= dut_data_in;
            for (i = 1; i < TAPS; i = i + 1) begin
                golden_delay_line[i] <= golden_delay_line[i-1];
            end

            // Calculate the sum of products in a single step
            golden_data_out <= (golden_delay_line[0] * dut.COEFFS[0]) +
                               (golden_delay_line[1] * dut.COEFFS[1]) +
                               (golden_delay_line[2] * dut.COEFFS[2]) +
                               (golden_delay_line[3] * dut.COEFFS[3]) +
                               (golden_delay_line[4] * dut.COEFFS[4]) +
                               (golden_delay_line[5] * dut.COEFFS[5]) +
                               (golden_delay_line[6] * dut.COEFFS[6]) +
                               (golden_delay_line[7] * dut.COEFFS[7]);
        end
    end

    // --- Latency Alignment for Golden Output ---
    // This shift register delays the golden output to match the DUT's latency.
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(i=0; i<LATENCY; i=i+1)
                delayed_golden_out[i] <= 0;
        end else begin
            delayed_golden_out[0] <= golden_data_out;
            for (i=1; i < LATENCY; i=i+1)
                delayed_golden_out[i] <= delayed_golden_out[i-1];
        end
    end

    // --- Stimulus and Verification ---
    initial begin
        // Wait for reset to complete
        wait (rst_n === 1'b1);
        #(CLK_PERIOD);

        // 1. Impulse Stimulus
        $display("Applying Impulse Stimulus...");
        dut_data_in = 100;
        #(CLK_PERIOD);
        dut_data_in = 0;

        // Run for enough cycles to see the full impulse response
        #(CLK_PERIOD * (TAPS + LATENCY + 5));

        // 2. Add more stimulus here (e.g., step, random)

        $display("Simulation Finished Successfully!");
        $stop;
    end

    // Verification Logic: Compare DUT output with delayed golden output
    reg [31:0] cycle_count = 0;
    always @(posedge clk) begin
        if(rst_n) begin
            cycle_count <= cycle_count + 1;
            // Start checking only after the first valid data emerges from the pipeline
            if (cycle_count > LATENCY) begin
                if (dut_data_out !== delayed_golden_out[LATENCY-1]) begin
                    $display("ERROR: Mismatch at time %0t", $time);
                    $display("DUT Output: %d, Expected (Golden): %d", dut_data_out, delayed_golden_out[LATENCY-1]);
                    $stop;
                end
            end
        end else begin
             cycle_count <= 0;
        end
    end

endmodule
