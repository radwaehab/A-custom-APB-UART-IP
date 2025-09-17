
module uart_rx (
    input  wire        clk,
    input  wire        arst_n,
    input  wire        rx_en,
    input  wire [31:0] baud_div,
    input  wire        rx_serial,

    output reg  [7:0]  rx_data_out,
    output reg         rx_busy,
    output reg         rx_done_tick,
    output reg         rx_error
);

    // FSM State Definitions
    localparam [2:0] IDLE      = 3'b000;
    localparam [2:0] START     = 3'b001;
    localparam [2:0] DATA      = 3'b010;
    localparam [2:0] STOP      = 3'b011;
    localparam [2:0] DONE      = 3'b100;

    reg [2:0] current_state, next_state;
    reg [1:0] rx_sync_reg;
    
    // Input Synchronizer
    wire      rx_synced = rx_sync_reg[1];

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            rx_sync_reg <= 2'b11;
        end else begin
            rx_sync_reg <= {rx_sync_reg[0], rx_serial};
        end
    end

    // Edge Detector for Start Bit
    wire start_edge_detected = rx_sync_reg[0] & ~rx_sync_reg[1];

    // Baud rate tick generator
    reg [31:0] baud_counter;
    wire       baud_tick;
    assign baud_tick = (baud_counter == 0);

    // Data and bit counters
    reg [2:0] bit_idx;
    reg [7:0] rx_sipo_reg;

    // Baud counter logic
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            baud_counter <= 0;
        end else begin
                  if (baud_tick || (next_state != current_state)) begin
                case(next_state)
                    // Wait 1.5 bits for the middle of the start bit
                    START:      baud_counter <= baud_div + (baud_div >> 1); 
                    // Wait 1 full bit for data and stop bits
                    DATA, STOP: baud_counter <= baud_div; 
                    default:    baud_counter <= 0;
                endcase
            end 
            // If we are in an active state, count down.
            else if (current_state != IDLE && current_state != DONE) begin
                baud_counter <= baud_counter - 1;
            end
        end
    end

    // FSM State Register
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // FSM Next State Logic
    always @(*) begin
        next_state = current_state; 
        case (current_state)
            IDLE: begin
                if (rx_en && start_edge_detected) begin
                    next_state = START;
                end
            end
            START: begin
                if (baud_tick) begin
                    if (rx_synced == 1'b0) begin
                        next_state = DATA;
                    end else begin
                        next_state = IDLE; // Glitch, go to idle
                    end
                end
            end
            DATA: begin
                if (baud_tick) begin
                    if (bit_idx == 7) begin
                        next_state = STOP;
                    end
                end
            end
            STOP: begin
                if (baud_tick) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output and internal register logic (clocked)
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            rx_busy      <= 1'b0;
            rx_done_tick <= 1'b0;
            rx_error     <= 1'b0;
            bit_idx      <= 0;
            rx_data_out  <= 8'd0;
        end else begin
            
            rx_done_tick <= 1'b0;

            case (current_state)
                IDLE: begin
                    rx_busy <= 1'b0;
                    if (next_state == START) begin
                        rx_busy <= 1'b1;
                        bit_idx <= 0; // Reset bit counter for new frame
                    end
                end
                DATA: begin
                    if (baud_tick) begin
                        rx_sipo_reg[bit_idx] <= rx_synced;
                        bit_idx <= bit_idx + 1;
                    end
                end
                STOP: begin
                    if (baud_tick) begin
                        // Check for framing error (stop bit must be high)
                        if (rx_synced == 1'b0) begin
                            rx_error <= 1'b1;
                        end else begin
                            rx_error <= 1'b0;
                        end
                    end
                end
                DONE: begin
                    rx_done_tick <= 1'b1;
                    rx_busy      <= 1'b0;
                    // Only update data output if there was no error
                    if (rx_error == 1'b0) begin
                        rx_data_out  <= rx_sipo_reg;
                    end
                end
            endcase
        end
    end

endmodule
