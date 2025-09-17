// src/apb_uart_wrapper.v
// APB Slave Wrapper for the UART Core

module apb_uart_wrapper (
    // APB Slave Interface
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire [31:0] PADDR,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output wire        PREADY,

    // UART Serial Interface
    output wire        uart_tx_out,
    input  wire        uart_rx_in
);

    // Register Address Map (using word offsets)
    localparam ADDR_CTRL   = 2'b00; // 0x0000
    localparam ADDR_STATS  = 2'b01; // 0x0004
    localparam ADDR_TXDATA = 2'b10; // 0x0008
    localparam ADDR_RXDATA = 2'b11; // 0x000C
    localparam ADDR_BAUDIV = 3'b100; // 0x0010 (BONUS)

    // Internal Registers
    reg [31:0] ctrl_reg;
    reg [31:0] tx_data_reg;
    reg [31:0] rx_data_reg;
    reg [31:0] baudiv_reg;

    // Status bits and wires
    wire tx_busy_w, tx_done_w;
    wire rx_busy_w, rx_done_tick_w, rx_error_w;
    reg  rx_done_status; // Latched version of rx_done

    // --- APB Logic ---
    wire psel_and_penable = PSEL & PENABLE;

    // Write Logic
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            ctrl_reg    <= 32'h0;
            tx_data_reg <= 32'h0;
            baudiv_reg  <= 10416; // Default to 9600 baud @ 100MHz
        end else if (psel_and_penable && PWRITE) begin
            case (PADDR[3:2]) // Use lower address bits to decode
                ADDR_CTRL:   ctrl_reg    <= PWDATA;
                ADDR_TXDATA: tx_data_reg <= PWDATA;
                ADDR_BAUDIV: baudiv_reg  <= PWDATA;
            endcase
        end
    end

    // Read Logic
    always @(*) begin
        PRDATA = 32'h0; // Default
        case (PADDR[3:2])
            ADDR_CTRL:   PRDATA = ctrl_reg;
            ADDR_STATS:  PRDATA = {27'b0, rx_error_w, rx_done_status, tx_done_w, rx_busy_w, tx_busy_w};
            ADDR_RXDATA: PRDATA = rx_data_reg;
            ADDR_BAUDIV: PRDATA = baudiv_reg;
        endcase
    end
    
    // PREADY is high during the access phase for a zero-wait-state peripheral
    assign PREADY = psel_and_penable;

    // --- UART Core Integration ---

    // Control signals extracted from ctrl_reg
    wire tx_en_bit  = ctrl_reg[0];
    wire rx_en_bit  = ctrl_reg[1];
    wire tx_rst_bit = ctrl_reg[2];
    wire rx_rst_bit = ctrl_reg[3];

    // tx_en needs to be a pulse. Detect rising edge of the register bit.
    reg  tx_en_bit_d1;
    wire tx_en_pulse;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) tx_en_bit_d1 <= 1'b0;
        else          tx_en_bit_d1 <= tx_en_bit;
    end
    assign tx_en_pulse = ~tx_en_bit_d1 & tx_en_bit;

    // rx_done status bit logic
    // Set on tick, clear on RX_DATA read
    wire rx_data_read = psel_and_penable && !PWRITE && (PADDR[3:2] == ADDR_RXDATA);
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            rx_done_status <= 1'b0;
        end else if (rx_done_tick_w) begin
            rx_done_status <= 1'b1;
        end else if (rx_data_read) begin
            rx_done_status <= 1'b0;
        end
    end
    
    // Latch RX data when done tick is high
    always @(posedge PCLK or negedge PRESETn) begin
        if(!PRESETn) begin
            rx_data_reg <= 32'h0;
        end else if (rx_done_tick_w) begin
            rx_data_reg <= {24'b0, rx_data_out_w};
        end
    end

    // Instantiate UART TX Core
    uart_tx tx_inst (
        .clk(PCLK),
        .arst_n(PRESETn & ~tx_rst_bit),
        .tx_en(tx_en_pulse),
        .tx_data_in(tx_data_reg[7:0]),
        .baud_div(baudiv_reg),
        .tx_serial(uart_tx_out),
        .tx_busy(tx_busy_w),
        .tx_done(tx_done_w)
    );

    // Instantiate UART RX Core
    wire [7:0] rx_data_out_w;
    uart_rx rx_inst (
        .clk(PCLK),
        .arst_n(PRESETn & ~rx_rst_bit),
        .rx_en(rx_en_bit),
        .baud_div(baudiv_reg),
        .rx_serial(uart_rx_in),
        .rx_data_out(rx_data_out_w),
        .rx_busy(rx_busy_w),
        .rx_done_tick(rx_done_tick_w),
        .rx_error(rx_error_w)
    );

endmodule