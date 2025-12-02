`timescale 1ns / 1ps

module i2c_slave_controller (
    inout sda,
    input scl,
    input clk
);

localparam ADDRESS = 7'b0101010;

// State Definitions
localparam READ_ADDR = 0;
localparam SEND_ACK = 1;
localparam READ_DATA = 2;
localparam WRITE_DATA = 3;
localparam SEND_ACK2 = 4;
localparam STOP = 6;

// Internal Registers and Wires
reg [7:0] addr;
reg [2:0] counter = 3'd7; // Reduced counter width to 3 bits (max 7) for efficiency
reg [3:0] state_slave = 0; // Reduced state_slave width
reg [7:0] data_in = 0;
reg [7:0] data_out = 8'b10001110; // Data to send to the master
reg sda_out = 0;       // Data the slave drives
reg write_enable = 0;  // 1 when the slave is driving SDA, 0 for high-Z (listening)
reg bus_active = 0;

// Internal wire to receive buffered input data
wire sda_in_data;

// --- IOBUF Instantiation ---
// This primitive connects the external SDA pin (IO) to internal logic.
// The T input determines the direction: T='0' enables output (drive I to IO),
// T='1' enables input (read IO into O, I/O is high-Z).
// Since 'write_enable=1' means we drive the bus (output), T must be connected to '~write_enable'.
IOBUF IOBUF_inst (
    .O   (sda_in_data),   // Buffer output (Internal input data from the bus)
    .IO  (sda),           // Buffer inout port (Connects directly to top-level port)
    .I   (sda_out),       // Buffer input (Internal output data to drive onto the bus)
    .T   (~write_enable)  // 3-state enable: '0' for output (when write_enable=1)
);
// --- End IOBUF Instantiation ---


reg sda_d1, scl_d1;

// Edge detection using the buffered input data (sda_in_data)
wire sda_falling_edge = sda_d1 & ~sda_in_data;
wire sda_rising_edge = ~sda_d1 & sda_in_data;
wire start_condition = sda_falling_edge & scl; // SDA falling while SCL is high
wire stop_condition = sda_rising_edge & scl;   // SDA rising while SCL is high

// This block detects start/stop conditions and manages bus_active
always @(posedge clk) begin
    // Sample the bus data at clk speed for edge detection
    sda_d1 <= sda_in_data;
    scl_d1 <= scl;

    // Detect STOP (SDA rising while SCL is high)
    if (stop_condition) begin
        bus_active <= 0;
        $display("[%t] STOP condition detected. Bus inactive. Final received data: %h", $time, data_in);
    // Detect START (SDA falling while SCL is high)
    end else if (start_condition) begin
        bus_active <= 1;
        $display("[%t] START condition detected. Bus active.", $time);
    end
end
//always @(posedge clk or posedge sda) begin end
// --- I2C State Machine (Synchronized to SCL) ---
always @(posedge scl) begin
    if (bus_active) begin
        if (start_condition) begin
            // Reset state upon a new START condition
            state_slave <= READ_ADDR;
            counter <= 3'd7;
            $display("[%t] State changed to READ_ADDR. Counter reset.", $time);
        end else begin
            case (state_slave)
                READ_ADDR: begin
                    // Read the address (MSB first)
                    addr[counter] <= sda_in_data; // Use sda_in_data (O port of IOBUF)
                    $display("[%t] READ_ADDR: Reading bit %0d. sda_in_data = %b", $time, counter, sda_in_data);
                    if (counter == 0) begin
                        state_slave <= SEND_ACK;
                        // The last bit (bit 0) is the R/W bit, already stored in addr[0]
                        $display("[%t] READ_ADDR: Done reading. Received ADDR/RW: %h. Moving to SEND_ACK.", $time, addr);
                    end else begin
                        counter <= counter - 1;
                    end
                end

                SEND_ACK: begin
                    // This is the ACK/NACK clock cycle (9th bit of address phase)
                    // The actual ACK/NACK bit is driven on the bus at the negedge of SCL
                    if (addr[7:1] == ADDRESS) begin
                        // Address Match: Set up for ACK and transition state
                        $display("[%t] SEND_ACK: Address matched (%0h). R/W bit: %b", $time, addr[7:1], addr[0]);
                        counter <= 3'd7; // Reset counter for next 8-bit byte
                        if (addr[0] == 0) begin // R/W=0 (Write command from Master)
                            state_slave <= READ_DATA;
                            $display("[%t] -> Moving to READ_DATA.", $time);
                        end else begin // R/W=1 (Read command from Master)
                            state_slave <= WRITE_DATA;
                            $display("[%t] -> Moving to WRITE_DATA.", $time);
                        end
                    end else begin
                        // Address Mismatch (NACK): Wait for STOP
                        state_slave <= STOP; // Slave ignores the rest of the transaction
                        $display("[%t] SEND_ACK: Address mismatch. NACK implied. Moving to STOP.", $time);
                    end
                end

                READ_DATA: begin
                    // Read the data byte from the master
                    data_in[counter] <= sda_in_data; // Use sda_in_data
                    $display("[%t] READ_DATA: Reading data bit %0d. sda_in_data = %b", $time, counter, sda_in_data);
                    if (counter == 0) begin
                        // Done reading the 8 bits of data
                        $display("[%t] READ_DATA: Done reading data byte: %h. Moving to SEND_ACK2 (9th bit).", $time, data_in);
                        // Store the received data here (optional: typically store in memory model)
                        state_slave <= SEND_ACK2;
                    end else begin
                        counter <= counter - 1;
                    end
                end

                SEND_ACK2: begin
                    // 9th bit after data: Slave acknowledges receipt of data (ACK)
                    // The actual ACK bit is driven at negedge SCL.
                    // After the ACK, the master sends more data (return to READ_DATA) or STOP.
                    // For this simple example, we assume one byte and then stop.
                    state_slave <= READ_DATA; // Assume continuous reading
                    counter <= 3'd7;
                    // Note: A real slave would check the master's NACK here to decide to stop.
                    $display("[%t] SEND_ACK2: Sending ACK after data. Moving back to READ_DATA/STOP logic.", $time);
                end

                WRITE_DATA: begin
                    // Send data byte to the master
                    // The data bit is driven at negedge SCL.
                    if (counter == 0) begin
                        // Done sending 8 bits, now wait for ACK/NACK from master
                        $display("[%t] WRITE_DATA: Done writing data. Moving to STOP logic.", $time);
                        state_slave <= STOP; // Transition to wait for Master ACK/NACK (and subsequent STOP)
                    end else begin
                        counter <= counter - 1;
                        $display("[%t] WRITE_DATA: Decrementing counter to %0d.", $time, counter - 1);
                    end
                end
                
                STOP: begin
                    // Wait for the bus_active flag to be cleared by the STOP condition
                    $display("[%t] STOP: Waiting for physical STOP condition.", $time);
                end
                
                default: begin
                    state_slave <= READ_ADDR;
                    $display("[%t] DEFAULT: Resetting state machine to READ_ADDR.", $time);
                end
            endcase
        end
    end
end

// This block handles output data and enable signals, synchronized to negedge scl
// Data is set here, so it is stable when SCL rises (positive edge).
always @(negedge scl) begin
    case (state_slave)
        READ_ADDR: begin
            // Slave is still reading, so it remains in high-Z (write_enable=0)
            write_enable <= 0;
            $display("[%t] negedge scl: READ_ADDR. sda is high-Z (input).", $time);
        end

        SEND_ACK: begin
            // Slave must drive the ACK/NACK bit
            write_enable <= 1; // Enable output driver
            if (addr[7:1] == ADDRESS) begin
                // Address Match (ACK)
                sda_out <= 0;
                $display("[%t] negedge scl: SEND_ACK. Driving sda low (ACK).", $time);
            end else begin
                // Address Mismatch (NACK)
                sda_out <= 1;   //the error is here, slave is giving nack dont know why
                $display("[%t] negedge scl: SEND_ACK. Driving sda high (NACK).", $time);
            end
        end

        READ_DATA: begin
            // Master is sending data, slave must be in high-Z (write_enable=0)
            write_enable <= 0;
            $display("[%t] negedge scl: READ_DATA. sda is high-Z (input).", $time);
        end

        WRITE_DATA: begin
            // Slave drives the data bit
            sda_out <= data_out[counter];
            write_enable <= 1; // Enable output driver
            $display("[%t] negedge scl: WRITE_DATA. Driving sda with data_out[%0d] = %b", $time, counter, data_out[counter]);
        end

        SEND_ACK2: begin
            // Slave drives the ACK after reading data
            sda_out <= 0;
            write_enable <= 1; // Enable output driver
            $display("[%t] negedge scl: SEND_ACK2. Driving sda low (ACK).", $time);
        end

        STOP: begin
            // Wait for STOP condition (sda must be high-Z)
            write_enable <= 0;
            $display("[%t] negedge scl: STOP. sda is high-Z (input).", $time);
        end
        
        
    endcase
end

endmodule