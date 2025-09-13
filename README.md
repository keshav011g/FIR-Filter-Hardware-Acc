#Parameterizable Pipelined FIR Filter in Verilog
This repository contains the Verilog source code for a high-performance, parameterizable, N-tap Finite Impulse Response (FIR) filter. The design is deeply pipelined to maximize clock frequency and data throughput, making it suitable for hardware acceleration in high-speed digital signal processing (DSP) applications.

A self-checking testbench is included to verify the filter's functional correctness against a behavioral golden reference model.

Features
Parameterizable: Easily change the number of taps (TAPS), data width (DATA_WIDTH), and coefficient width (COEFF_WIDTH).

High-Throughput Architecture: A fully parallel and deeply pipelined design allows for a new output to be produced on every clock cycle after the initial latency.

Efficient Adder Tree: A structural, pipelined adder tree is used to sum the multiplier products with minimal combinational delay.

Synthesizable RTL: The filter is written in synthesizable Verilog, suitable for targeting both FPGAs and ASICs.

Self-Checking Verification: The included testbench automatically verifies the hardware's output against a known-good behavioral model, reporting any mismatches.

Architecture Overview
The filter implements the standard FIR convolution sum:
y(n) = Σ [w(k) * x(n-k)] for k = 0 to N-1

The hardware is structured into several pipeline stages to break the critical path and achieve a high clock speed.

Input Delay Line (1 Cycle Latency): A shift register captures the input data (x(n)) and creates the delayed versions required for the filter calculation (x(n-1), x(n-2), ...).

Parallel Multiplier Stage (1 Cycle Latency): N hardware multipliers operate in parallel, each calculating one w(k) * x(n-k) product simultaneously.

Pipelined Adder Tree (log2(N) Cycles Latency): A tree of adders sums the results from the multiplier stage. Each level of the tree is registered, creating a deep pipeline that avoids a single, long combinational adder chain.

The total latency of the filter is (2 + log2(TAPS)) clock cycles.

File Structure
.
├── README.md
├── rtl
│   └── fir_filter.v      // Synthesizable FIR Filter Source Code
└── sim
    └── tb_fir_filter.v   // Verilog Testbench for Simulation

Simulation and Verification
The project can be simulated using any standard Verilog simulator (e.g., ModelSim, Vivado Simulator, Icarus Verilog). The testbench (tb_fir_filter.v) will:

Instantiate the filter.

Generate a clock and reset signal.

Provide an impulse stimulus to the filter's input.

Calculate the expected output using a behavioral "golden" model.

Align the DUT's output with the golden model's output by accounting for the pipeline latency.

Compare the results on every clock cycle and report SUCCESS or ERROR.


Running with Icarus Verilog (Example)
# Compile the Verilog files

iverilog -o tb_fir rtl/fir_filter.v sim/tb_fir_filter.v

# Run the simulation
vvp tb_fir

Customization
The filter can be customized by changing the parameters at the top of the rtl/fir_filter.v file.

TAPS: The number of filter taps. Must be a power of 2 for the current adder tree implementation.

DATA_WIDTH: The bit-width of the input and output data.

COEFF_WIDTH: The bit-width of the filter coefficients.

The filter coefficients can be modified by editing the localparam signed [COEFF_WIDTH-1:0] COEFFS array within the module.
