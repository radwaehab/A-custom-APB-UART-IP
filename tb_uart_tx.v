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

integer error_count = 0;
integer correct_count = 0;

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
        arst_n = 0;
        tx_en = 0;
        tx_data_in = 8'd0;
        baud_div = 10416; // 100,000,000 / 9600

        assert_reset();
    
       @(negedge clk);
        tx_data_in = 8'hA5; // 10100101
        tx_en = 1;
        @(posedge clk);
        tx_en = 0;

       // ---- First byte transmit ----
        @(negedge clk);
        $display("\nSending byte 0xA5...");
        tx_data_in = 8'hA5;
        tx_en = 1;
        @(posedge clk);
        tx_en = 0;  // Pulse only one cycle

        wait (tx_done == 1);
        $display("Byte 0xA5 sent. tx_done asserted.");
        check_result(1'b1, 1'b0, 1'b1);

        // ---- Second byte transmit ----
        @(negedge clk);
        $display("\nSending byte 0x5A...");
        tx_data_in = 8'h5A;
        tx_en = 1;
        @(posedge clk);
        tx_en = 0;

        wait (tx_done == 1);
        $display("Byte 0x5A sent. tx_done asserted.");
        check_result(1'b1, 1'b0, 1'b1);

        $display("Simulation Finished: Correct=%0d, Errors=%0d", correct_count, error_count);
       
        $stop;
    end

//assert reset task
task assert_reset;
    begin 
        arst_n = 0;
        @(negedge clk);
        if (tx_serial !== 1'b1 || tx_busy !== 1'b0 || tx_done !== 1'b0) begin
            $display("Reset failed: tx_serial=%b, tx_busy=%b, tx_done=%b", tx_serial, tx_busy, tx_done);
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
        if (tx_serial !== expected_serial || tx_busy !== expected_busy || tx_done !== expected_done) begin
            $display("Check failed: tx_serial=%b (expected %b), tx_busy=%b (expected %b), tx_done=%b (expected %b)", 
                     tx_serial, expected_serial, tx_busy, expected_busy, tx_done, expected_done);
            error_count = error_count + 1;
        end else begin
            $display("Check successful: tx_serial=%b, tx_busy=%b, tx_done=%b", tx_serial, tx_busy, tx_done);
            correct_count = correct_count + 1;
        end
    end
endtask

endmodule
