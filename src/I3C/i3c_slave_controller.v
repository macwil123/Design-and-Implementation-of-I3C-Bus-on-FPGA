// ============================================================================
// NOTE: START/STOP detection problem in hardware
// The START and STOP detection logic currently samples SDA using the system
// clock (clk), which runs at a much higher frequency than the I3C SCL line.
// Because clk is much faster, SDA is sampled many times within a single SCL
// period, which can capture unstable transitions or noise around SDA edges.
// As a result, the falling/rising edges used to detect START and STOP may be
// triggered incorrectly or missed entirely on real hardware, even though they
// appear correct in simulation. This causes the FSM to fail to detect the
// correct bus conditions. Edge detection must be aligned to SCL rather than
// the fast clk to ensure reliable START/STOP recognition.
// ============================================================================


`timescale 1ns / 1ps

module i3c_slave_controller (
    inout sda,
    input scl,
    input clk
);

// =====================================================
// IOBUF signals for SDA
// =====================================================
wire sda_i;      // from pad ? slave logic
wire sda_o;      // from slave logic ? pad
wire sda_t;      // 1 = input (Hi-Z), 0 = driving

reg  sda_out = 0;
reg  write_enable = 0;

assign sda_o = sda_out;
assign sda_t = ~write_enable; // write_enable=1 ? drive SDA

// Xilinx IOBUF instance
IOBUF #(
    .DRIVE(12),
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD("DEFAULT"),
    .SLEW("SLOW")
) IOBUF_sda (
    .O(sda_i),   // from pin to logic
    .IO(sda),    // physical pin
    .I(sda_o),   // from logic to pin
    .T(sda_t)    // tristate control
);

// =====================================================
// Original design below (with sda ? sda_i changes)
// =====================================================

//localparam ADDRESS = 7'b0101010;
localparam BROADCAST_ADDR    = {7'h7E,1'b0};
localparam ENTDAA            = 8'h07;
localparam BROADCAST_ADDR_2  = {7'h7E,1'b1};

// State Definitions
localparam READ_BROADCAST_ADDR   = 0;
localparam SEND_ACK_BROADCAST    = 1;
localparam READ_CCC_DAA_ENTDAA   = 2;
localparam T_BIT                 = 3;
localparam STOP_AFTER_CCC        = 4;
localparam READ_BROADCAST_ADDR_2 = 5;
localparam SEND_ACK_BROADCAST_2  = 6;
localparam READ_DA               = 7;
localparam T_BIT_DA              = 8;
localparam SEND_ACK_DA           = 9;
localparam STOP_DAA              = 10;

// Private read/write
//localparam IDLE           = 11;
localparam READ_ADDR        = 12;
localparam SEND_ACK         = 13;
localparam READ_DATA        = 14; 
localparam WRITE_DATA       = 15;
localparam CHECK_PARITY     = 16;
localparam SEND_ACK_WRITE   = 17; 

localparam STOP             = 100;

// Internal Registers and Wires
reg [7:0] broadcast_addr;
reg [7:0] broadcast_addr_2;
reg [2:0] counter       = 3'd7;
reg [7:0] data_in_ccc   = 0;
reg [7:0] data_out      = 8'b10001110;
reg bus_active          = 0;
reg t_bit               = 0;
reg odd_parity_flag     = 0;
reg [6:0] RECIEVED_DA;
reg t_bit_da            = 0;
reg [7:0] addr_private; 
reg [7:0] recieved_data;
reg check_parity;

reg [7:0] state_slave = READ_BROADCAST_ADDR;

reg sda_d1, scl_d1;

// Edge detection now based on sda_i
wire sda_falling_edge = sda_d1 & ~sda_i;
wire sda_rising_edge  = ~sda_d1 & sda_i;
wire start_condition  = sda_falling_edge & scl; // SDA falling while SCL is high
wire stop_condition   = sda_rising_edge  & scl; // SDA rising while SCL is high

// Detect START/STOP
always @(posedge clk) begin
    // Sample the bus data at clk speed for edge detection
    sda_d1 <= sda_i;
    scl_d1 <= scl;

    // Detect STOP (SDA rising while SCL is high)
    if (stop_condition) begin
        bus_active <= 0;
        // $display("[%t] STOP condition detected. Bus inactive.", $time);
    // Detect START (SDA falling while SCL is high)
    end else if (start_condition) begin
        bus_active <= 1;
        $display("[%t] START condition detected. Bus active.", $time);
    end
end

// ========================
//  SLAVE FSM (posedge SCL)
// ========================
always @(posedge scl) begin
    if (bus_active) begin
        if (start_condition) begin
            state_slave <= READ_BROADCAST_ADDR;
            counter     <= 3'd7;
            $display("[%0t] SLAVE: Posedge SCL, START -> STATE=READ_BROADCAST_ADDR, counter=7", $time);
        end else begin
            case (state_slave)

                READ_BROADCAST_ADDR: begin
                    broadcast_addr[counter] <= sda_i;
                    $display("[%0t] SLAVE: STATE=READ_BROADCAST_ADDR bit[%0d]=%b, addr=%b", 
                             $time, counter, sda_i, broadcast_addr);
                    if (counter == 0) begin
                        state_slave <= SEND_ACK_BROADCAST;
                        $display("[%0t] SLAVE: STATE=READ_BROADCAST_ADDR done -> SEND_ACK_BROADCAST", $time);
                    end else begin
                        counter <= counter - 1;
                    end
                end

                SEND_ACK_BROADCAST: begin
                    if (broadcast_addr == BROADCAST_ADDR) begin
                        counter     <= 3'd7;
                        state_slave <= READ_CCC_DAA_ENTDAA;
                        $display("[%0t] SLAVE: STATE=SEND_ACK_BROADCAST MATCH (0x%0h) -> READ_CCC_DAA_ENTDAA, counter=7", 
                                 $time, BROADCAST_ADDR);
                    end else begin
                        state_slave <= STOP;
                        $display("[%0t] SLAVE: STATE=SEND_ACK_BROADCAST ADDR MISMATCH (addr=%b). -> STOP", 
                                 $time, broadcast_addr);
                    end
                end

                READ_CCC_DAA_ENTDAA: begin
                    data_in_ccc[counter] <= sda_i;
                    $display("[%0t] SLAVE: STATE=READ_CCC_DAA_ENTDAA bit[%0d]=%b, CCC=%b", 
                             $time, counter, sda_i, data_in_ccc);
                    if (counter == 0) begin
                        state_slave <= T_BIT;
                        $display("[%0t] SLAVE: STATE=READ_CCC_DAA_ENTDAA done (CCC=0x%0h) -> T_BIT", 
                                 $time, data_in_ccc);
                    end else begin
                        counter <= counter - 1;
                    end
                end

                T_BIT: begin
                    t_bit           <= sda_i;
                    odd_parity_flag = ^({data_in_ccc, t_bit});
                    $display("[%0t] SLAVE: STATE=T_BIT Tbit=%b, parity_check=%b (1=correct)", 
                             $time, sda_i, odd_parity_flag);

                    if (~odd_parity_flag) begin
                        state_slave <= STOP;
                        $display("[%0t] SLAVE: STATE=T_BIT parity ERROR -> STOP", $time);
                    end else begin
                        state_slave <= STOP_AFTER_CCC;
                        $display("[%0t] SLAVE: STATE=T_BIT parity OK -> STOP_AFTER_CCC", $time);
                    end
                end

                STOP_AFTER_CCC: begin
                    state_slave <= READ_BROADCAST_ADDR_2;
                    counter     <= 3'd7;
                    $display("[%0t] SLAVE: STATE=STOP_AFTER_CCC -> READ_BROADCAST_ADDR_2, counter=7", $time);
                end

                READ_BROADCAST_ADDR_2: begin
                    broadcast_addr_2[counter] <= sda_i;
                    $display("[%0t] SLAVE: STATE=READ_BROADCAST_ADDR_2 bit[%0d]=%b, addr2=%b",
                             $time, counter, sda_i, broadcast_addr_2);
                    if (counter == 0) begin
                        state_slave <= SEND_ACK_BROADCAST_2;
                        $display("[%0t] SLAVE: STATE=READ_BROADCAST_ADDR_2 done -> SEND_ACK_BROADCAST_2", $time);
                    end else begin
                        counter <= counter - 1;
                    end
                end

                SEND_ACK_BROADCAST_2: begin
                    if (broadcast_addr_2 == BROADCAST_ADDR_2) begin
                        counter     <= 6; // 7 bits DA
                        state_slave <= READ_DA;
                        $display("[%0t] SLAVE: STATE=SEND_ACK_BROADCAST_2 MATCH (0x%0h) -> READ_DA, counter=6", 
                                 $time, BROADCAST_ADDR_2);
                    end else begin
                        state_slave <= STOP;
                        $display("[%0t] SLAVE: STATE=SEND_ACK_BROADCAST_2 ADDR MISMATCH (addr2=%b) -> STOP", 
                                 $time, broadcast_addr_2);
                    end
                end

                READ_DA: begin
                    RECIEVED_DA[counter] <= sda_i;
                    $display("[%0t] SLAVE: STATE=READ_DA bit[%0d]=%b, DA=%b", 
                             $time, counter, sda_i, RECIEVED_DA);
                    if (counter == 0) begin
                        state_slave <= T_BIT_DA;
                        $display("[%0t] SLAVE: STATE=READ_DA done -> T_BIT_DA", $time);
                    end else begin
                        counter <= counter - 1;
                    end
                end

                T_BIT_DA: begin
                    counter  = counter - 1;
                    t_bit_da <= sda_i;
                    $display("[%0t] SLAVE: STATE=T_BIT_DA Tbit_DA=%b, parity_check=%b (1=odd)", 
                             $time, sda_i, ^({RECIEVED_DA, t_bit_da}));

                    if (^({RECIEVED_DA, sda_i})) begin
                        state_slave <= SEND_ACK_DA;
                        $display("[%0t] SLAVE: STATE=T_BIT_DA parity OK -> SEND_ACK_DA", $time);
                    end else begin
                        state_slave <= STOP;
                        $display("[%0t] SLAVE: STATE=T_BIT_DA parity ERROR -> STOP", $time);
                    end
                end

                SEND_ACK_DA: begin
                    state_slave <= STOP_DAA;
                    $display("[%0t] SLAVE: STATE=SEND_ACK_DA (ACK DA) -> STOP_DAA", $time);
                end

                STOP_DAA: begin
                    state_slave <= READ_ADDR;
                    $display("[%0t] SLAVE: STATE=STOP_DAA -> READ_ADDR (DAA complete)", $time);
                end

                READ_ADDR: begin
                    addr_private[counter] <= sda_i;
                    $display("[%0t] SLAVE: STATE=READ_ADDR bit[%0d]=%b, addr_private=%b",
                             $time, counter, sda_i, addr_private);
                    if (counter == 0) begin
                        state_slave <= SEND_ACK;
                        $display("[%0t] SLAVE: STATE=READ_ADDR done -> SEND_ACK", $time);
                    end else begin
                        counter = counter - 1;
                    end
                end

                SEND_ACK: begin
                    if (addr_private[7:1] == RECIEVED_DA) begin
                        counter <= 3'd7;
                        if (addr_private[0] == 0) begin
                            state_slave <= READ_DATA;
                            $display("[%0t] SLAVE: STATE=SEND_ACK ADDR MATCH, R/W=0 -> READ_DATA, counter=7", $time);
                        end else begin
                            state_slave <= WRITE_DATA;
                            $display("[%0t] SLAVE: STATE=SEND_ACK ADDR MATCH, R/W=1 -> WRITE_DATA, counter=7", $time);
                        end
                    end else begin
                        state_slave <= STOP;
                        $display("[%0t] SLAVE: STATE=SEND_ACK ADDR MISMATCH (addr_private=%b, DA=%b) -> STOP", 
                                 $time, addr_private, RECIEVED_DA);
                    end
                end

                READ_DATA: begin
                    recieved_data[counter] <= sda_i;
                    $display("[%0t] SLAVE: STATE=READ_DATA bit[%0d]=%b, data=%b", 
                             $time, counter, sda_i, recieved_data);
                    if (counter == 0) begin
                        state_slave <= CHECK_PARITY;
                        $display("[%0t] SLAVE: STATE=READ_DATA done -> CHECK_PARITY", $time);
                    end else begin
                        counter = counter - 1;
                    end
                end

                CHECK_PARITY : begin
                    check_parity <= sda_i;
                    $display("[%0t] SLAVE: STATE=CHECK_PARITY Tbit=%b, parity_check=%b", 
                             $time, sda_i, ^({recieved_data, check_parity}));
                    state_slave <= STOP;
                end  
                
                WRITE_DATA: begin
                    if (counter == 0) begin
                        $display("[%t] WRITE_DATA: Done writing data. Moving to STOP logic.", $time);
                        state_slave <= SEND_ACK_WRITE;
                    end else begin
                        counter <= counter - 1;
                        $display("[%t] WRITE_DATA: Decrementing counter to %0d.", $time, counter - 1);
                    end
                end
                                   
                SEND_ACK_WRITE : begin
                    state_slave <= STOP;
                end
             
                STOP: begin
                    $display("[%0t] SLAVE: STATE=STOP (waiting for bus to become inactive)", $time);
                end

                default: begin
                    $display("[%0t] SLAVE: STATE=UNKNOWN (default)", $time);
                end
            endcase
        end
    end
end

// ===========================
//  SLAVE SDA drive (negedge)
// ===========================
always @(negedge scl) begin
    case (state_slave)

        READ_BROADCAST_ADDR: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=READ_BROADCAST_ADDR (listening)", $time);
        end

        SEND_ACK_BROADCAST: begin
            write_enable <= 1;
            if (broadcast_addr === BROADCAST_ADDR)
                sda_out <= 0;
            else
                sda_out <= 1;
            $display("[%0t] SLAVE: NEGEDGE STATE=SEND_ACK_BROADCAST Driving ACK=%b", $time, sda_out);
        end

        READ_CCC_DAA_ENTDAA: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=READ_CCC_DAA_ENTDAA (listening)", $time);
        end

        T_BIT: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=T_BIT (listening parity bit)", $time);
        end

        STOP_AFTER_CCC: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=STOP_AFTER_CCC (waiting repeated START)", $time);
        end

        READ_BROADCAST_ADDR_2: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=READ_BROADCAST_ADDR_2 (listening)", $time);
        end

        SEND_ACK_BROADCAST_2: begin
            write_enable <= 1;
            if (broadcast_addr_2 === BROADCAST_ADDR_2)
                sda_out <= 0;
            else
                sda_out <= 1;
            $display("[%0t] SLAVE: NEGEDGE STATE=SEND_ACK_BROADCAST_2 Driving ACK=%b", $time, sda_out);
        end

        READ_DA: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=READ_DA (listening DA bits)", $time);
        end

        T_BIT_DA: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=T_BIT_DA (listening parity bit)", $time);
        end

        SEND_ACK_DA: begin
            write_enable <= 1;
            sda_out <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=SEND_ACK_DA Driving ACK=0", $time);
        end

        STOP_DAA: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=STOP_DAA (DAA STOP, releasing bus)", $time);
        end

        READ_ADDR: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=READ_ADDR (listening private addr)", $time);
        end

        SEND_ACK: begin
            write_enable <= 1;
            if (addr_private[7:1] == RECIEVED_DA)
                sda_out <= 0;
            else
                sda_out <= 1;
            $display("[%0t] SLAVE: NEGEDGE STATE=SEND_ACK Driving ACK=%b", $time, sda_out);
        end

        READ_DATA: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=READ_DATA (listening data bits)", $time);
        end

        CHECK_PARITY: begin
            write_enable <= 1;
            $display("[%0t] SLAVE: NEGEDGE STATE=CHECK_PARITY (listening parity)", $time);
            sda_out <= 0;
        end
        
        WRITE_DATA : begin
            sda_out <= data_out[counter];
            write_enable <= 1; // Enable output driver
            $display("[%t] negedge scl: WRITE_DATA. Driving sda with data_out[%0d] = %b",
                     $time, counter, data_out[counter]);
        end

        SEND_ACK_WRITE : begin
            write_enable <= 1;
            sda_out <= 0;
        end

        STOP: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=STOP (waiting STOP condition)", $time);
        end

        default: begin
            write_enable <= 0;
            $display("[%0t] SLAVE: NEGEDGE STATE=UNKNOWN", $time);
        end

    endcase
end

endmodule
