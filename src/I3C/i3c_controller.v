`timescale 1ns / 1ps

/* "data_in" port which recieves value from tb code, to be sent to the slave
is declared as reg instead of input port, as fpga has no enough switches */

/* FIRST NEG EDGE ALWAYS BLOCK IS EXECUTED , THEN THE SAME FSM STATE
POSEDGE BLOCK IS EXECUTED  */

module i2c_controller(
    input  clk,
    input  rst,
    input  [6:0] addr,
    input  enable,
    input  rw,

      //Read data from slave and store
    output  ready,  //Indicate Master is ready

    inout i2c_sda,
    output  i2c_scl
);

localparam IDLE = 0;
localparam START = 1;
localparam ADDRESS = 2;
localparam READ_ACK = 3;
localparam WRITE_DATA = 4;
localparam WRITE_ACK = 5;
localparam WRITE_ACK_DELAY =6;
localparam READ_DATA = 7;
localparam READ_ACK2 = 8;
localparam READ_ACK2_DELAY = 9;
localparam STOP = 10;

localparam DIVIDE_BY = 1000;


reg [7:0] data_in =8'b11100111;  //Master sending to slave
reg [7:0] state;
reg [7:0] saved_addr;
reg [7:0] saved_data;
reg [10:0] counter;
reg [10:0] counter2 = 0;
reg [7:0] data_out;
reg write_enable;
reg sda_out;
reg i2c_scl_enable = 0;
reg i2c_clk = 0;

// Internal wire to receive buffered input data from the bus
wire sda_in_data;

assign ready = ((rst == 0) && (state == IDLE)) ? 1 : 0;
assign i2c_scl = (i2c_scl_enable == 0 ) ? 1 : i2c_clk;
// The tri-state assignment is removed and handled by IOBUF.

// --- IOBUF Instantiation ---
// IOBUF connects the external i2c_sda pin (IO) to internal driver (I=sda_out)
// and internal receiver (O=sda_in_data).
// T is the tri-state enable: T='0' drives output; T='1' enables input (high-Z output).
// Since 'write_enable=1' means we drive the bus (output), T must be connected to '~write_enable'.
IOBUF IOBUF_inst (
    .O   (sda_in_data),   // Buffer output (Internal input data from the bus)
    .IO  (i2c_sda),       // Buffer inout port (Connects directly to top-level port)
    .I   (sda_out),       // Buffer input (Internal output data to drive onto the bus)
    .T   (~write_enable)  // 3-state enable: '0' for output (when write_enable=1)
);
// --- End IOBUF Instantiation ---


//100Mhz
//Clock divider
always @(posedge clk) begin
    if (counter2 == (DIVIDE_BY/2) - 1) begin
        i2c_clk <= ~i2c_clk;
        counter2 <= 0;
    end
    else counter2 <= counter2 + 1;
end



always @(negedge i2c_clk, posedge rst) begin
    if(rst == 1) begin
        i2c_scl_enable <= 0;
    end else begin
        if ((state == IDLE) || (state == START) || (state == STOP)) begin
            i2c_scl_enable <= 0;
        end else begin
            i2c_scl_enable <= 1;
        end
    end
end


always @(posedge i2c_clk, posedge rst) begin
    if(rst == 1) begin
        state <= IDLE;
    end
    else
    begin
        case(state)

            IDLE: begin
                if (enable) begin
                    state <= START;
                    saved_addr <= {addr, rw};
                    saved_data <= data_in;
                    $display("IDLE");
                end
                else state <= IDLE;
            end

            START: begin
                counter <= 7;
                state <= ADDRESS;
                $display("POSEDGE START");
            end

            ADDRESS: begin
                if (counter == 0) begin
                    state <= READ_ACK;
                end else counter <= counter - 1;
            end

            READ_ACK: begin
                // Check slave ACK/NACK using the internal input wire
                if (sda_in_data == 0) begin
                    counter <= 7;
                    if(saved_addr[0] == 0) state <= WRITE_DATA;     // 0 for write operation
                    else state <= READ_DATA;
                end
                else
                begin
                    state <= STOP;
                end
                $display("ACK Read");
            end

            WRITE_DATA: begin
                if(counter == 0) begin
                    state <= READ_ACK2;
                end else counter <= counter - 1;
            end

            READ_ACK2: begin
                state <= READ_ACK2_DELAY;
                $display("AC 2 is read");
            end

            READ_ACK2_DELAY :
            begin
                state <= STOP;
            end

            READ_DATA: begin
                // Read data bit from the slave using the internal input wire
                data_out[counter] <= sda_in_data;
                if (counter == 0) state <= WRITE_ACK;
                else counter <= counter - 1;
                $display("POSEDGE READ %b",counter);
            end

            WRITE_ACK: begin
                state <= WRITE_ACK_DELAY;
                $display("Write ACK posedge");
            end

            WRITE_ACK_DELAY : begin
                state <= STOP;
            end

            STOP: begin
                //state <= IDLE;
            end
        endcase
    end
end

always @(negedge i2c_clk, posedge rst) begin
    if(rst == 1) begin
        write_enable <= 1; // Master drives HIGH initially (bus idle)
        sda_out <= 1;
    end else begin
        case(state)

            IDLE: begin
                write_enable <= 1; // Master drives HIGH during IDLE
                sda_out <= 1;
            end

            START: begin
                write_enable <= 1;  
                sda_out <= 0; // SDA goes LOW
                $display("START");
            end
            
            ADDRESS: begin
                sda_out <= saved_addr[counter];
                write_enable <= 1; // Master drives address
                $display("ADRRESS[%d]",counter);
            end
           

            READ_ACK: begin
                write_enable <= 0; // Master releases SDA to read slave ACK/NACK
            end

            READ_ACK2 :
            begin
                write_enable <= 0; // Master releases SDA to read slave ACK/NACK
                $display("READ_ACK2 in negedge, master listening");
            end

            READ_ACK2_DELAY :
            begin
                write_enable <= 1; // Master drives ACK/NACK bit
                // If RW=0 (Write), master sends ACK (0) to slave
                // If RW=1 (Read), master sends NACK (1) to slave (to terminate transaction)
                if (saved_addr[0] == 0) begin
                    sda_out <= 0; // ACK for successful write
                end else begin
                    sda_out <= 1; // NACK to terminate read
                end
            end

            WRITE_DATA: begin
                write_enable <= 1; // Master drives data
                sda_out <= saved_data[counter];
                $display("Data is being written[%d] ",counter);
            end

            WRITE_ACK: begin
                write_enable <= 1; // Master drives ACK/NACK bit (for Read operation)
                sda_out <= 1; // Master NACKs (1) to end the Read transaction
                $display("NACK is being sent to slave");
            end

            READ_DATA: begin
                write_enable <= 0; // Master releases SDA to read slave data
                $display("Data is being read[%d] ",counter);
            end

            STOP: begin
                write_enable <= 1;
                sda_out <= 1; // SDA goes HIGH
                $display("STOP");
            end
            
            default: begin
                write_enable <= 1;
                sda_out <= 1;
            end

        endcase
    end
end

endmodule
