// dv/tb_uart_rx.v
`timescale 1ns / 1ps

module tb_uart_rx;

    // Inputs
    reg        clk;
    reg        arst_n;
    reg        rx_en;
    reg [31:0] baud_div;
    reg        rx_serial;

    // Outputs
    wire [7:0] rx_data_out;
    wire       rx_busy;
    wire       rx_done_tick;
    wire       rx_error;
    
    // Testbench helper variables
    integer i;
    // **FIX:** Declare a register to hold data for bit-wise access.
    reg [7:0] temp_data; 
    
    // Baud period for testbench
    localparam BIT_PERIOD = 104167; // 1/9600 in ns

    // Instantiate the DUT
    uart_rx dut (
        .clk(clk),
        .arst_n(arst_n),
        .rx_en(rx_en),
        .baud_div(baud_div),
        .rx_serial(rx_serial),
        .rx_data_out(rx_data_out),
        .rx_busy(rx_busy),
        .rx_done_tick(rx_done_tick),
        .rx_error(rx_error)
    );

    // Clock Generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Task to send a byte (This was already correct)
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            rx_serial = 0;
            #(BIT_PERIOD);

            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx_serial = data[i];
                #(BIT_PERIOD);
            end

            // Stop bit
            rx_serial = 1;
            #(BIT_PERIOD);
        end
    endtask

    // Test Sequence
    initial begin
        $display("Starting UART RX Testbench...");
        arst_n = 0;
        rx_en = 0;
        rx_serial = 1; // Idle
        baud_div = 10416; // 100,000,000 / 9600

        #20;
        arst_n = 1;
        #20;

        rx_en = 1; // Enable receiver
        $display("Receiver enabled.");

        // Send byte 0xA5
        send_byte(8'hA5);

        wait (rx_done_tick == 1);
        $display("Received data: 0x%h, Error: %b", rx_data_out, rx_error);
        if (rx_data_out == 8'hA5) $display("SUCCESS: Data matches.");
        else $display("FAILURE: Data does not match.");
        
        #1000; // Wait a bit

        // Send byte 0x5A with a framing error
        $display("Sending byte 0x5A with framing error...");
        
        // **FIX:** First, load the literal value into our temp register.
        temp_data = 8'h5A;
        
        // Start bit
        rx_serial = 0;
        #(BIT_PERIOD);
        
        // Data bits
        for (i = 0; i < 8; i = i + 1) begin
            // **FIX:** Now, index the register variable, not the literal.
            rx_serial = temp_data[i];
            #(BIT_PERIOD);
        end
        
        // Stop bit (incorrectly set to 0)
        rx_serial = 0;
        #(BIT_PERIOD);
        rx_serial = 1; // Return to idle
        
        wait (rx_done_tick == 1);
        $display("Received data: 0x%h, Error: %b", rx_data_out, rx_error);
        if (rx_error) $display("SUCCESS: Framing error detected.");
        else $display("FAILURE: Framing error not detected.");

        $display("Test Finished.");
        $finish;
    end

endmodule