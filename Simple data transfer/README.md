## Project Goal: Simulating a Physical I2C Bus
The goal was to simulate an I2C-like data transfer between a master and slave module. The master generates a clock signal, which is routed out of the FPGA, looped back in with a physical jumper wire, and used to drive the slave module. This external loopback was intended to mimic a real-world physical bus between two devices.

## The Error: [Place 30-574] - Invalid Clock Pin
During implementation in Vivado, this design produced a critical placement error.

What it means: The tool tried to connect an external input pin to the FPGA's internal global clock network (BUFG), but it failed.

Why it happens: The chosen pin was not a dedicated Clock Capable (CC) pin. FPGAs have a specialized, high-speed hardware network built exclusively for distributing clocks. Only designated CC pins have a direct "on-ramp" to this network. When a standard I/O pin is used, the tool cannot find this required dedicated path and fails the process.

## The Workaround: Forcing an Undesirable Route
To bypass this critical error, the following command was added to the .xdc constraints file:

Tcl

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_recieve_IBUF]
This command forces the tool to ignore the design rule violation and use a standard, non-dedicated path for the clock, which can lead to unreliable timing.
