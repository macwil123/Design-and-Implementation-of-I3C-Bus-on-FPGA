# Design and Implementation of the I3C Protocol on FPGA

## Overview

This project focuses on implementing the MIPI-I3C serial communication protocol on an FPGA platform, beginning with a complete and synthesizable I²C master–slave system. After establishing I²C, the design was extended to support selected I3C features such as Dynamic Address Assignment (DAA) and private data transfers. The project demonstrates the practical migration from legacy I²C to I3C while exposing real hardware design challenges using Verilog and FPGA debugging tools.

## Key Features

* Fully synthesizable I²C master and slave architecture
* I3C Dynamic Address Assignment (DAA) implemented using the ENTDAA command
* Private read and write operations using dynamically assigned addresses
* FPGA hardware testing on Nexys4 DDR (Artix-7)
* Bidirectional SDA control using IOBUF
* Simulation and hardware waveform verification using Xilinx ILA
* Structured FSM-based design for master and slave modules

## Current Limitations and Known Issues

* The implementation is not error-free and is still under development
* Some I3C transactions behave differently on hardware compared to simulation
* Incomplete implementation of full MIPI-I3C specification
* Advanced features currently not supported:

  * 48-bit Provisional ID exchange (PID / BCR / DCR)
  * HDR modes
  * In-Band Interrupts (IBI) and Hot-Join
  * Multi-target arbitration and clock stretching
* Timing and synchronization issues observed during real ILA captures
* Certain FSM transitions require refinement to avoid incorrect state behaviour

## Development Summary

* Developed baseline I²C master–slave communication system
* Debugged synthesis failures caused by:

  * Multi-driven nets
  * Asynchronous SDA/SCL edge detection
  * Tri-state conflicts on SDA
* Redesigned the I²C slave as a fully synchronous architecture
* Added I3C broadcast address handling (0x7E) and ENTDAA sequence
* Implemented repeated START and T-bit handling
* Executed private read/write operations after successful DAA
* Analysed hardware results via ILA to identify functional issues

## Project Structure

```
/src
    i2c_controller.v
    i2c_slave_controller.v
    i2c_fpga.v //top level module


    i3c_controller.v
    i3c_slave_controller.v
    i3c_fpga.v

/simulation
    i2c_read_write_waveforms
    i3c_daa_private_rw_waveforms

/hardware
   i2c_fpga.xdc 
   i3c_fpga.xdc
    ILA_captures
```

## Tools and Platform

* Verilog HDL
* Xilinx Vivado
* Nexys4 DDR (Artix-7 FPGA)
* Integrated Logic Analyzer (ILA)

## Future Work

* Complete PID/BCR/DCR sequence in DAA
* Add HDR-DDR and HDR-TSP support
* Implement IBI and Hot-Join
* Multi-device arbitration
* Robust error-handling and timing optimization
* UVM-based verification environment

