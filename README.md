# I2C-bus-on-FPGA

This project explores the design and implementation of the MIPI-I3C protocol on FPGA, starting from a fully custom I²C master–slave bus. We first implemented and verified a complete synthesizable I²C controller on a Nexys4 DDR FPGA, which took considerable time due to practical hardware issues such as multi-driven nets, asynchronous edge detection, and tri-state handling on SDA/SCL. 

Building on this baseline, we extended the design to I3C and implemented a simplified Dynamic Address Assignment (DAA) flow using the ENTDAA CCC, followed by private read and write transfers using the dynamically assigned address. To keep the design manageable on FPGA, we omitted some advanced parts of the full spec (e.g., full 48-bit Provisional ID exchange, HDR modes, IBI, etc.) and focused on demonstrating the end-to-end DAA + private transfer sequence in hardware.
