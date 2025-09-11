// dv/tb_uart_tx.v
`timescale 1ns / 1ps

module tb_uart_tx;


    reg        clk;
    reg        arst_n;
    reg        tx_en;
    reg [7:0]  tx_data_in;
    reg [31:0] baud_div;


    wire       tx_serial;
    wire       tx_busy;
    wire       tx_done;


    uart_tx dut (
        .clk(clk),
        .arst_n(arst_n),
        .tx_en(tx_en),
        .tx_data_in(tx_data_in),
        .baud_div(baud_div),
        .tx_serial(tx_serial),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );


    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 ns
    end

    initial begin
        $display("Starting UART TX Testbench...");
        arst_n = 0;
        tx_en = 0;
        tx_data_in = 8'd0;
        baud_div = 10416; // 100,000,000 / 9600

        #20;
        arst_n = 1;
        #20;

        $display("Sending byte 0xA5...");
        tx_data_in = 8'hA5; // 10100101
        tx_en = 1;
        #10; // Pulse for one clock cycle
        tx_en = 0;

        wait (tx_done == 1);
        $display("Byte 0xA5 sent. tx_done asserted.");
        #20;

        $display("Sending byte 0x5A...");
        tx_data_in = 8'h5A; // 01011010
        tx_en = 1;
        #10;
        tx_en = 0;

        wait (tx_done == 1);
        $display("Byte 0x5A sent. tx_done asserted.");
        #20;
        
        
        $display("Test Finished.");
        $STOP;
    end

endmodule