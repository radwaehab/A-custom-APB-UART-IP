module uart_tx
(
    input  wire        clk,
    input  wire        arst_n, // active low

    // signals APB
    input  wire        tx_en,
    input  wire [7:0]  tx_data_in,
    input  wire [31:0] baud_div,

    // Outputs
    output reg         tx_serial,
    output reg         tx_busy,
    output reg         tx_done
);

    // FSM States
    localparam [2:0] IDLE      = 3'b000;
    localparam [2:0] START     = 3'b001;
    localparam [2:0] DATA      = 3'b010;
    localparam [2:0] STOP      = 3'b011;
    localparam [2:0] DONE      = 3'b100;

    reg [2:0] current_state, next_state;
    reg [9:0] tx_frame_reg; 
    reg [3:0] bit_idx;

    // Baud rate tick 
    reg [31:0] baud_counter;
    wire       baud_tick;

    assign baud_tick = (baud_counter == 0);

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            baud_counter <= 0;
        end else if (current_state == IDLE) begin
            baud_counter <= baud_div; 
        end else if (baud_tick) begin
            baud_counter <= baud_div; 
        end else begin
            baud_counter <= baud_counter - 1;
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

    // FSM Next State and Output Logic
    always @(*) begin
        next_state  = current_state;
        tx_serial   = 1'b1;
        tx_busy     = 1'b1;
        tx_done     = 1'b0;

        case (current_state)
            IDLE: begin
                tx_busy = 1'b0;
                if (tx_en) begin

                    tx_frame_reg <= {1'b1, tx_data_in, 1'b0};
                    bit_idx      <= 0;
                    next_state   <= START;
                end
            end

            START: begin
                tx_serial = tx_frame_reg[0];
                if (baud_tick) begin
                    bit_idx    <= bit_idx + 1;
                    next_state <= DATA;
                end
            end

            DATA: begin
                tx_serial = tx_frame_reg[bit_idx];
                if (baud_tick) begin
                    if (bit_idx < 9) begin 
                        bit_idx <= bit_idx + 1;
                    end else begin
                        next_state <= STOP;
                    end
                end
            end
            
            STOP: begin
                tx_serial = tx_frame_reg[9]; 
                if (baud_tick) begin
                    next_state <= DONE;
                end
            end
            
            DONE: begin
                tx_done  = 1'b1;
                tx_busy  = 1'b0;
                next_state <= IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
