# Simulation Waveforms

This directory contains waveform results generated through testbench-based simulation for both the I²C and I3C protocol implementations. The waveforms were obtained by running Verilog testbenches to verify functional correctness before deploying the design onto FPGA hardware.

## Contents

* Waveforms demonstrating I²C write and read operations
* Waveforms demonstrating I3C Dynamic Address Assignment (DAA) using ENTDAA
* Waveforms showing I3C private read and write transfers after dynamic address assignment

## Purpose

These simulation outputs serve as reference results to:

* Verify protocol sequence correctness
* Validate state machine transitions
* Confirm timing and control signal behavior
* Debug logic prior to hardware testing

## Notes

* All waveform results were generated using testbenches at the RTL simulation stage.
* These waveforms represent simulation behavior; hardware responses may differ due to timing and synchronization constraints.

