module tb;
  reg sysclk;
  reg reset;

  wire CS;
  wire RST;
  wire DCX;
  wire WRX;
  wire [15:0] Data;

  // instantiate your DUT
  scope my_scope (
    .sysclk(sysclk),
    .reset(reset),
	.LCD_CS(CS),
	.LCD_RST(RST),
	.LCD_DCX(DCX),
	.LCD_WRX(WRX),
	.LCD_Data(Data)
  );

  // Clock generator (for reference)
  initial sysclk = 0;
  always #40 sysclk = ~sysclk;  // 50/4 MHz clock (period = 80 ns)

  // Stimulus: pulse wr high briefly
  initial begin
    #50;               // wait 50 ns
    reset = 1;
    #50;               // stay high for 20 ns
    reset = 0;
    // stay low forever
  end

  wire [2:0] state;
  assign state = tb.my_scope.state;
  wire [5:0] counter;
  assign counter = tb.my_scope.swreset_counter;

endmodule

