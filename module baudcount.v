module baudcount 
#(

parameter fclk= 50_000_000,
parameter baudrate = 9600

)(

input  wire clk,
input  wire nrst,
output reg  baudtick

);


localparam baud_load= (fclk/baudrate)-1;
reg [$clog2(baud_load)] counter=0;

always @(posedge clk, posedge rst)
begin
  
  if (~nrst)
  begin
    counter <= baud_load;
    baudtick=0;
  end
  else 
  begin
    if (counter == 0)
      begin
        counter=0;
        baudtick=1;
      end
    else
      begin
        counter = counter - 1;
        baudtick=0;
      end
  end

end


endmodule