`timescale 1ns / 1ps

module i3c_controller(
    input  clk,
    input  rst,
    input  [6:0] dynamic_addr,
    input  enable,
    input  rw,
    output ready,
    inout  i3c_sda,
    output i3c_scl
);
reg [7:0] data_in = 8'b11100111;
reg [7:0] state;
reg [7:0] saved_addr   = {7'h7E, 1'b0};
reg [7:0] saved_addr_2 = {7'h7E, 1'b1};

reg [10:0] counter;
reg [10:0] counter2 = 0;
reg write_enable;
reg sda_out;
reg i3c_scl_enable = 0;
reg i3c_clk = 0;
reg [7:0] entdaa = 8'h07;
reg [7:0] addr_byte;
reg [7:0] data_out;
reg read_ack_read;

// ============================
// IOBUF SDA Signals
// ============================
wire sda_i;          // input from pad ? master logic
wire sda_o;          // output from master logic ? pad
wire sda_t;          // T=1: high-Z(input), T=0: output

assign sda_o = sda_out;
assign sda_t = ~write_enable;   // write_enable=1 ? drive SDA

// ============================
// Xilinx IOBUF Instance
// ============================
IOBUF #(
    .DRIVE(12),
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD("DEFAULT"),
    .SLEW("SLOW")
) IOBUF_sda (
    .O(sda_i),     // from pad ? master
    .IO(i3c_sda),  // actual physical pin
    .I(sda_o),     // from master ? pad
    .T(sda_t)      // tristate control
);

// =============================================================
// ORIGINAL SIGNALS
// =============================================================
localparam IDLE                = 0;
localparam START               = 1;
localparam BROADCAST_BYTE      = 2;
localparam READ_ACK_RB         = 3;
localparam CCC_DAA_ENTDAA      = 4;
localparam T_BIT               = 5;
localparam STOP_T              = 6;
localparam R_START             = 7;
localparam BROADCAST_BYTE_2    = 8;
localparam READ_ACK_RB_2       = 9;
localparam DAA                 = 10;
localparam T_BIT_2             = 11;
localparam READ_ACK_DAA        = 12;
localparam STOP_DAA            = 13;

localparam START_DATA_TRANSFER = 14;
localparam ADDRESS             = 15;
localparam READ_ACK            = 16;
localparam WRITE_DATA          = 17;
localparam READ_DATA           = 18;
localparam READ_ACK2           = 19;
localparam READ_ACK2_DELAY     = 20;
localparam READ_ACK_READ       = 21;

localparam STOP                = 100;
localparam DIVIDE_BY = 4;



assign ready   = ((rst == 0) && (state == IDLE)) ? 1 : 0;
assign i3c_scl = (i3c_scl_enable == 0) ? 1 : i3c_clk;


// =============================================================
// CLOCK DIVIDER
// =============================================================
always @(posedge clk) begin
    if (counter2 == (DIVIDE_BY/2) - 1) begin
        i3c_clk  <= ~i3c_clk;
        counter2 <= 0;
    end else begin
        counter2 <= counter2 + 1;
    end
end

// =============================================================
// CONTROL SCL DRIVE
// =============================================================
always @(negedge i3c_clk, posedge rst) begin
    if (rst) begin
        i3c_scl_enable <= 0;
    end else begin
        if ((state == IDLE) || (state == START) || (state == STOP) ||
            (state == STOP_T) || (state == R_START) || (state == STOP_DAA) ||
            (state == START_DATA_TRANSFER)) begin
            i3c_scl_enable <= 0;
        end else begin
            i3c_scl_enable <= 1;
        end
    end
end

// =============================================================
// FSM – POSEDGE
// =============================================================
always @(posedge i3c_clk, posedge rst) begin
    if (rst) begin
        state <= IDLE;
    end else begin
        case (state)

            IDLE: begin
                if (enable) state <= START;
            end

            START: begin
                counter <= 7;
                state   <= BROADCAST_BYTE;
            end

            BROADCAST_BYTE: begin
                if (counter == 0)
                    state <= READ_ACK_RB;
                else
                    counter <= counter - 1;
            end

            READ_ACK_RB: begin
                if (sda_i == 0) begin
                    counter <= 7;
                    state   <= CCC_DAA_ENTDAA;
                end else begin
                    state <= STOP;
                end
            end

            CCC_DAA_ENTDAA: begin
                if (counter == 0)
                    state <= T_BIT;
                else
                    counter <= counter - 1;
            end

            T_BIT:       state <= STOP_T;
            
            STOP_T:      state <= R_START;

            R_START: begin
                counter <= 7;
                state   <= BROADCAST_BYTE_2;
            end

            BROADCAST_BYTE_2: begin
                if (counter == 0)
                    state <= READ_ACK_RB_2;
                else
                    counter <= counter - 1;
            end

            READ_ACK_RB_2: begin
                if (sda_i == 0) begin
                    counter <= 6;
                    state   <= DAA;
                end else begin
                    state <= STOP;
                end
            end

            DAA: begin
                if (counter == 0)
                    state <= T_BIT_2;
                else
                    counter <= counter - 1;
            end

            T_BIT_2:       state <= READ_ACK_DAA;
            READ_ACK_DAA:  state <= (sda_i == 0) ? STOP_DAA : STOP;
            STOP_DAA:      state <= START_DATA_TRANSFER;

            START_DATA_TRANSFER: begin
                counter   <= 7;
                addr_byte <= {dynamic_addr, rw};
                state     <= ADDRESS;
            end

            ADDRESS: begin
                if (counter == 0)
                    state <= READ_ACK;
                else
                    counter <= counter - 1;
            end

            READ_ACK: begin
                if (sda_i == 0) begin
                    counter <= 7;
                    state   <= (addr_byte[0] == 0) ? WRITE_DATA : READ_DATA;
                end else begin
                    state <= STOP;
                end
            end

            WRITE_DATA: begin
                if (counter == 0) state <= READ_ACK2;
                else counter <= counter - 1;
            end

            READ_ACK2:        state <= READ_ACK2_DELAY;
            READ_ACK2_DELAY:  state <= STOP;

            READ_DATA: begin
                data_out[counter] <= sda_i;
                if (counter == 0) state <= READ_ACK_READ;
                else counter <= counter - 1;
            end

            READ_ACK_READ: begin
                read_ack_read <= sda_i;
                state <= STOP;
            end

            STOP: begin
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

// =============================================================
// FSM – NEGEDGE
// =============================================================
always @(negedge i3c_clk, posedge rst) begin
    if (rst) begin
        write_enable <= 1;
        sda_out      <= 1;
    end else begin
        case (state)

            IDLE: begin write_enable <= 1; sda_out <= 1; end
            START: begin write_enable <= 1; sda_out <= 0; end

            BROADCAST_BYTE: begin write_enable <= 1; sda_out <= saved_addr[counter]; end
            READ_ACK_RB:    write_enable <= 0;

            CCC_DAA_ENTDAA: begin write_enable <= 1; sda_out <= entdaa[counter]; end

            T_BIT: begin write_enable <= 1; sda_out <= ~(^(entdaa)); end
            STOP_T: begin write_enable <= 1; sda_out <= 1; end

            R_START: begin write_enable <= 1; sda_out <= 0; end

            BROADCAST_BYTE_2: begin write_enable <= 1; sda_out <= saved_addr_2[counter]; end
            READ_ACK_RB_2:    write_enable <= 0;

            DAA: begin write_enable <= 1; sda_out <= dynamic_addr[counter]; end
            T_BIT_2: begin write_enable <= 1; sda_out <= ~(^(dynamic_addr)); end

            READ_ACK_DAA: write_enable <= 0;
            STOP_DAA: begin write_enable <= 1; sda_out <= 1; end

            START_DATA_TRANSFER: begin write_enable <= 1; sda_out <= 0; end

            ADDRESS: begin write_enable <= 1; sda_out <= addr_byte[counter]; end
            READ_ACK: write_enable <= 0;

            WRITE_DATA: begin write_enable <= 1; sda_out <= data_in[counter]; end
            READ_ACK2: write_enable <= 0;

            READ_DATA: write_enable <= 0;

            READ_ACK_READ: write_enable <= 0;

            STOP: begin write_enable <= 1; sda_out <= 1; end

            default: begin write_enable <= 1; sda_out <= 1; end
        endcase
    end
end

endmodule
