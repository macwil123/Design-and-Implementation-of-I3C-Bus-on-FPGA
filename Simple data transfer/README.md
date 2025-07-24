𝗣𝗥𝗢𝗝𝗘𝗖𝗧 𝗚𝗢𝗔𝗟


The original intent was to simulate a basic I2C-like data transmission between a master and slave module. 
The master generates a clock signal, which is routed out of the FPGA, looped back in with a physical jumper wire, and used to drive the slave module.

This external loopback was intended to mimic a real-world physical bus between two devices

During implementation in Vivado, this design produced a critical placement error: [Place 30-574] Poor placement for routing between an IO pin and BUFG.

Description of the Error
This error occurs when the tool tries to connect an external input pin to the FPGA's internal global clock network (BUFG), but the chosen pin is not a dedicated Clock Capable (CC) pin.

FPGAs have a specialized, high-speed, low-skew hardware network built exclusively for distributing clocks reliably. Only designated CC pins have a direct, physical "on-ramp" to this network. When a standard I/O pin is used as a clock source, the tool cannot find this required dedicated path and fails the placement process, as the connection would be unreliable.

The Workaround Implemented
To bypass this critical error, the following command was added to the .xdc constraints file:

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_recieve_IBUF]

