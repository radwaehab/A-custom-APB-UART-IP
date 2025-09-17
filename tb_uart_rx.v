`timescale 1ns / 1ps

module tb_uart_rx;

    reg        clk;
    reg        arst_n;
    reg        rx_en;
    reg [31:0] baud_div;
    reg        rx_serial;

   
    wire [7:0] rx_data_out;
    wire       rx_busy;
    wire       rx_done_tick;
    wire       rx_error;
    
    //helper variables
    integer i =0;
    integer error_count = 0;
    integer correct_count = 0;
    //Declare a register to hold data for bit-wise access.
    reg [7:0] temp_data =0; 
    
    // Baud period for testbench
    localparam BIT_PERIOD = 104167; // 1/9600  ns

    //the DUT
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

    // Clock Generation 100 MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Task to send a byte 
    task send_byte;
        input [7:0] data;
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
        assert_reset();
        rx_en = 1; 
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
        
        // load the literal value into our temp register.
        temp_data = 8'h5A;
        
        // Start bit
        rx_serial = 0;
        #(BIT_PERIOD);
        
        // Data bits
        for (i = 0; i < 8; i = i + 1) begin
            //index the register variable
            rx_serial = temp_data[i];
            #(BIT_PERIOD);
        end
        
        // Stop bit
        rx_serial = 0;
        #(BIT_PERIOD);
        rx_serial = 1; // Return to idle
        
        wait (rx_done_tick == 1);
        $display("Received data: 0x%h, Error: %b", rx_data_out, rx_error);
        if (rx_error) $display("SUCCESS: Framing error detected.");
        else $display("FAILURE: Framing error not detected.");
        check_result(1'b1, 1'b0, 1'b1);

        $display("Test Finished.");
        $stop;
    end

//assert reset task
task assert_reset;
    begin 
        arst_n = 0;
        @(negedge clk);
        if (rx_serial !== 1'b1 || rx_busy !== 1'b0 || rx_done_tick !== 1'b0) begin
            $display("Reset failed: rx_serial=%b, rx_busy=%b, rx_done_tick=%b", rx_serial, rx_busy, rx_done_tick);
            error_count = error_count + 1;
        end else begin
            $display("Reset successful.");
            correct_count = correct_count + 1;
        end
        arst_n = 1;
    end
endtask

//check result task
task check_result(input expected_serial, input expected_busy, input expected_done);
    begin
        if (rx_serial !== expected_serial || rx_busy !== expected_busy || rx_done_tick !== expected_done) begin
            $display("Check failed: rx_serial=%b (expected %b), rx_busy=%b (expected %b), rx_done_tick=%b (expected %b)", 
                     rx_serial, expected_serial, rx_busy, expected_busy, rx_done_tick, expected_done);
            error_count = error_count + 1;
        end else begin
            $display("Check successful: rx_serial=%b, rx_busy=%b, rx_done_tick=%b", rx_serial, rx_busy, rx_done_tick);
            correct_count = correct_count + 1;
        end
    end
endtask
endmodule

