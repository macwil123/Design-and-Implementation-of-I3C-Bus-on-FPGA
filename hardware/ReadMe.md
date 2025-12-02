# Hardware Testing Results

This folder contains results and observations from testing the I²C and I3C implementations on the FPGA hardware platform. The signals were monitored and analyzed using internal probes to verify the behavior of the design during real operation.

## Summary

* Hardware testing was performed after validating the design through simulation.
* I²C appeared to operate correctly during write operations when implemented on the FPGA.
* During I3C testing, the slave failed to detect START and STOP conditions reliably, preventing correct execution of the Dynamic Address Assignment (DAA) sequence and further transactions.

## Observations

The results were observed using Integrated Logic Analyzer (ILA) probes connected to internal signals during FPGA testing.

* I²C write transactions generated expected transitions and ACK responses on the bus.
* In I3C, the master broadcast and command sequences were initiated, but the slave did not respond due to missed detection of START or STOP.
* The issue is likely related to synchronization or timing differences between simulation and real hardware.


---

